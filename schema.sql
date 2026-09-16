-- =====================================================================
--  Salas Livres · Medicina CESMAC — banco de dados (Supabase)
--  Cole este arquivo inteiro no SQL Editor do Supabase e clique em "Run".
--  Pode rodar de novo sem problema: ele não apaga dados existentes.
-- =====================================================================

-- ---------- Funções auxiliares ----------
create or replace function public.meu_email() returns text
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

-- ---------- Membros autorizados ----------
create table if not exists public.membros (
  email          text primary key check (email = lower(email) and position('@' in email) > 1),
  nome           text check (char_length(nome) <= 60),
  admin          boolean not null default false,
  mural_lido_em  timestamptz,
  criado_em      timestamptz not null default now()
);

create or replace function public.eh_membro() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.membros where email = public.meu_email())
$$;

create or replace function public.eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.membros where email = public.meu_email() and admin)
$$;

-- Usada na tela de login (antes de entrar) para avisar se o e-mail não está na lista.
create or replace function public.email_autorizado(e text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.membros where email = lower(trim(e)))
$$;

create or replace function public.definir_meu_nome(n text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if char_length(trim(coalesce(n, ''))) = 0 then
    raise exception 'Nome vazio';
  end if;
  update public.membros set nome = left(trim(n), 60) where email = public.meu_email();
end $$;

create or replace function public.marcar_mural_lido(t timestamptz) returns void
language sql security definer set search_path = public as $$
  update public.membros
     set mural_lido_em = greatest(coalesce(mural_lido_em, '-infinity'::timestamptz), least(t, now()))
   where email = public.meu_email()
$$;

alter table public.membros enable row level security;
drop policy if exists membros_ler on public.membros;
drop policy if exists membros_admin_inserir on public.membros;
drop policy if exists membros_admin_atualizar on public.membros;
drop policy if exists membros_admin_apagar on public.membros;
create policy membros_ler             on public.membros for select to authenticated using (public.eh_membro());
create policy membros_admin_inserir   on public.membros for insert to authenticated with check (public.eh_admin());
create policy membros_admin_atualizar on public.membros for update to authenticated using (public.eh_admin()) with check (public.eh_admin());
create policy membros_admin_apagar    on public.membros for delete to authenticated using (public.eh_admin() and email <> public.meu_email());

-- ---------- Reservas ----------
create table if not exists public.reservas (
  id                   uuid primary key default gen_random_uuid(),
  sala                 text not null check (char_length(sala) between 1 and 20),
  data                 date not null,
  ini                  integer not null check (ini between 0 and 11),
  fim                  integer not null check (fim between 0 and 11 and fim >= ini),
  atividade            text not null check (char_length(atividade) between 1 and 120),
  responsavel          text check (char_length(responsavel) <= 80),
  reservado_por_nome   text not null check (char_length(reservado_por_nome) between 1 and 60),
  reservado_por_email  text not null default public.meu_email(),
  criado_em            timestamptz not null default now(),
  status               text not null default 'ativa' check (status in ('ativa', 'cancelada')),
  cancelado_por_nome   text,
  cancelado_por_email  text,
  cancelado_em         timestamptz,
  motivo_cancelamento  text check (char_length(motivo_cancelamento) <= 120)
);
-- tipo: 'reserva' (uso extra de uma sala) ou 'liberacao' (aula da grade que não vai acontecer naquele dia)
alter table public.reservas add column if not exists tipo text not null default 'reserva';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'reservas_tipo_valido') then
    alter table public.reservas add constraint reservas_tipo_valido check (tipo in ('reserva', 'liberacao'));
  end if;
end $$;
drop index if exists public.reservas_sala_data;
create index if not exists reservas_sala_data_tipo on public.reservas (sala, data, tipo) where status = 'ativa';

-- Impede dois registros ativos do mesmo tipo sobrepostos na mesma sala (mesmo com cliques simultâneos).
create or replace function public.reservas_antes_inserir() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.reservado_por_email := public.meu_email();
  new.criado_em := now();
  new.status := 'ativa';
  new.cancelado_por_nome := null; new.cancelado_por_email := null; new.cancelado_em := null; new.motivo_cancelamento := null;
  perform pg_advisory_xact_lock(hashtext(new.sala || '|' || new.data::text));
  if exists (
    select 1 from public.reservas r
     where r.status = 'ativa' and r.tipo = new.tipo and r.sala = new.sala and r.data = new.data
       and r.ini <= new.fim and new.ini <= r.fim
  ) then
    raise exception 'Horário já reservado nesta sala' using errcode = '23P01';
  end if;
  return new;
end $$;

-- Cancelar reserva / desfazer liberação = marcar como cancelada. Registra quem fez e quando; nada mais pode mudar.
create or replace function public.reservas_antes_atualizar() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.status <> 'ativa' or new.status <> 'cancelada' then
    raise exception 'Só é possível cancelar um registro ativo';
  end if;
  if old.tipo = 'liberacao' and exists (
    select 1 from public.reservas r
     where r.status = 'ativa' and r.tipo = 'reserva' and r.sala = old.sala and r.data = old.data
       and r.ini <= old.fim and old.ini <= r.fim
  ) then
    raise exception 'Há reserva neste horário; cancele a reserva antes de desfazer a liberação';
  end if;
  if (new.id, new.tipo, new.sala, new.data, new.ini, new.fim, new.atividade, new.responsavel,
      new.reservado_por_nome, new.reservado_por_email, new.criado_em)
     is distinct from
     (old.id, old.tipo, old.sala, old.data, old.ini, old.fim, old.atividade, old.responsavel,
      old.reservado_por_nome, old.reservado_por_email, old.criado_em) then
    raise exception 'Os dados da reserva não podem ser alterados';
  end if;
  new.cancelado_por_email := public.meu_email();
  new.cancelado_em := now();
  new.cancelado_por_nome := coalesce(
    (select nome from public.membros where email = public.meu_email()),
    nullif(trim(new.cancelado_por_nome), ''),
    public.meu_email());
  return new;
end $$;

drop trigger if exists reservas_inserir on public.reservas;
create trigger reservas_inserir before insert on public.reservas
  for each row execute function public.reservas_antes_inserir();
drop trigger if exists reservas_atualizar on public.reservas;
create trigger reservas_atualizar before update on public.reservas
  for each row execute function public.reservas_antes_atualizar();

alter table public.reservas enable row level security;
drop policy if exists reservas_ler on public.reservas;
drop policy if exists reservas_criar on public.reservas;
drop policy if exists reservas_liberar on public.reservas;
create policy reservas_ler     on public.reservas for select to authenticated using (public.eh_membro());
create policy reservas_criar   on public.reservas for insert to authenticated with check (public.eh_membro());
create policy reservas_liberar on public.reservas for update to authenticated using (public.eh_membro() and status = 'ativa') with check (public.eh_membro());
-- Não há política de DELETE: reservas nunca são apagadas, só liberadas (fica o histórico).

-- ---------- Mural ----------
create table if not exists public.mural (
  id           uuid primary key default gen_random_uuid(),
  texto        text not null check (char_length(texto) between 1 and 1000),
  sala         text check (char_length(sala) <= 20),
  data         date,
  autor_nome   text not null check (char_length(autor_nome) between 1 and 60),
  autor_email  text not null default public.meu_email(),
  criado_em    timestamptz not null default now()
);

create or replace function public.mural_antes_inserir() returns trigger
language plpgsql as $$
begin
  new.autor_email := public.meu_email();
  new.criado_em := now();
  return new;
end $$;
drop trigger if exists mural_inserir on public.mural;
create trigger mural_inserir before insert on public.mural
  for each row execute function public.mural_antes_inserir();

alter table public.mural enable row level security;
drop policy if exists mural_ler on public.mural;
drop policy if exists mural_criar on public.mural;
drop policy if exists mural_apagar on public.mural;
create policy mural_ler    on public.mural for select to authenticated using (public.eh_membro());
create policy mural_criar  on public.mural for insert to authenticated with check (public.eh_membro());
create policy mural_apagar on public.mural for delete to authenticated using (autor_email = public.meu_email() or public.eh_admin());

-- ---------- Permissões ----------
revoke all on public.membros, public.reservas, public.mural from anon;
grant select, insert, update, delete on public.membros to authenticated;
grant select, insert, update on public.reservas to authenticated;
grant select, insert, delete on public.mural to authenticated;
revoke execute on function public.definir_meu_nome(text), public.marcar_mural_lido(timestamptz) from public, anon;
grant execute on function public.email_autorizado(text) to anon, authenticated;
grant execute on function public.definir_meu_nome(text), public.marcar_mural_lido(timestamptz), public.eh_membro(), public.eh_admin(), public.meu_email() to authenticated;

-- ---------- Atualização ao vivo ----------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'reservas') then
      alter publication supabase_realtime add table public.reservas;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'mural') then
      alter publication supabase_realtime add table public.mural;
    end if;
  end if;
end $$;

-- ---------- Primeiro administrador ----------
-- Troque o e-mail abaixo se quiser outro administrador inicial.
insert into public.membros (email, nome, admin)
values ('rosamaria.rg@gmail.com', 'Rosamaria', true)
on conflict (email) do update set admin = true;
