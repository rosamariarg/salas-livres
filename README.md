# Salas Livres · Medicina CESMAC 2026.2

App web para consultar salas livres, reservar e liberar salas, trocar recados no mural e exportar relatórios em PDF e Excel.
Funciona no celular e no computador. O login é feito com um link enviado por e-mail, e só entra quem estiver na lista de membros.

**Como funciona por trás:**
- **GitHub Pages:** hospeda a página, de graça.
- **Supabase:** guarda login, reservas e mural, no plano gratuito.

A configuração leva cerca de 30 minutos e é feita uma vez só.

---

## Conteúdo desta pasta

| Arquivo | Para que serve |
|---|---|
| `index.html` | O app inteiro, com a grade das salas e o calendário 2026.2. |
| `config.js` | Onde você cola as 2 chaves do Supabase (passo 3). |
| `schema.sql` | Cria as tabelas, as regras de acesso e a trava contra reserva duplicada. |
| `manifest.webmanifest`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png` | Permitem instalar o app na tela inicial do celular. |

---

## Passo 1 · Criar o banco no Supabase

1. Acesse **supabase.com** e crie uma conta. Dá para entrar com o GitHub.
2. Clique em **New project**.
   - **Name:** `salas-livres`.
   - **Database password:** crie uma senha e guarde.
   - **Region:** *South America (São Paulo)*.
3. Quando o projeto terminar de criar, abra **SQL Editor** no menu lateral e clique em **New query**.
4. Abra o arquivo `schema.sql`, copie **todo** o conteúdo, cole no editor e clique em **Run**.
   - O resultado esperado é "Success. No rows returned".
   - O script já cadastra `rosamaria.rg@gmail.com` como primeira administradora. Para trocar, edite a última linha antes de rodar.

## Passo 2 · Publicar no GitHub Pages

1. No GitHub, clique em **New repository**.
   - **Nome:** `salas-livres`.
   - **Visibilidade:** **Public**. O GitHub Pages gratuito exige repositório público. Os dados continuam protegidos pelo login; veja a seção "Segurança".
2. No repositório vazio, clique em **uploading an existing file**. Arraste **todos os arquivos desta pasta** e clique em **Commit changes**.
3. Vá em **Settings › Pages**.
   - Em *Build and deployment*, escolha **Deploy from a branch**.
   - Selecione a branch **main**, a pasta **/(root)** e clique em **Save**.
4. Em 1 a 2 minutos o endereço aparece no topo da página, algo como `https://SEU-USUARIO.github.io/salas-livres/`. Guarde esse endereço.

## Passo 3 · Ligar o app ao Supabase

1. No Supabase, clique em **Connect** (ou vá em **Project Settings › API**). Copie:
   - a **Project URL**, algo como `https://abcdefgh.supabase.co`;
   - a chave **anon public** (em alguns painéis ela se chama **publishable key**).
2. No GitHub, abra o arquivo `config.js`, clique no lápis (**Edit**) e cole os dois valores no lugar de `COLE_AQUI_...`. Clique em **Commit changes**.

> Se você já rodou uma versão anterior do `schema.sql`, rode o arquivo novo de novo. Ele atualiza o banco sem apagar dados.

> A chave *anon* pode ficar pública. Quem protege os dados são as regras criadas pelo `schema.sql`.
> **Nunca** cole no app a chave `service_role` (ou *secret*).

## Passo 4 · Configurar o login por e-mail

No Supabase, em **Authentication**:

1. **URL Configuration**
   - **Site URL:** cole o endereço do GitHub Pages (passo 2).
   - **Redirect URLs:** adicione o mesmo endereço.
2. **Emails › Templates:** no plano gratuito, sem SMTP próprio, o Supabase não deixa editar os modelos. O e-mail padrão traz só o **link**, então a pessoa deve abrir o e-mail **no mesmo aparelho** em que vai usar o app. Se um dia você configurar um SMTP, pode acrescentar `{{ .Token }}` ao modelo *Magic Link* para enviar também um código.
3. O envio de e-mails do próprio Supabase tem um **limite baixo por hora**. Para um grupo de 10 pessoas costuma bastar, porque o login fica salvo no aparelho. Se precisar de mais, configure um SMTP próprio em **Authentication › Emails › SMTP Settings**.

## Passo 5 · Primeiro acesso e membros

1. Abra o endereço do app, digite seu e-mail e toque em **Enviar link de acesso**.
2. Abra o e-mail e toque no link, ou digite o código no app. Na primeira vez, informe como seu nome deve aparecer.
3. Toque no seu nome (no canto superior do celular, ou embaixo do menu no computador). Em **Membros do grupo**, adicione o e-mail de cada pessoa. Marque "Também é administrador" para quem também puder gerenciar a lista.
4. Envie o endereço do app para o grupo. Cada pessoa entra com o próprio e-mail.

**Instalar no celular:**
- **iPhone:** abra no Safari › Compartilhar › *Adicionar à Tela de Início*.
- **Android:** abra no Chrome › menu ⋮ › *Instalar app* (ou *Adicionar à tela inicial*).

---

## Regras do app

- **Reservar um turno inteiro:** no formulário de reserva, os botões **Manhã inteira** (07h30–12h00), **Tarde inteira** (13h20–17h50) e **Dia inteiro** preenchem os horários de uma vez.
- **Reserva repetida:** em **Repetir**, escolha *Toda semana, no mesmo dia* ou *A cada 15 dias* e a data limite (por padrão, 22/12, fim do semestre). O app mostra quantas datas serão criadas e quais serão puladas por feriado, aula na grade ou reserva de outra pessoa. Ao cancelar uma delas, dá para cancelar todas as datas futuras da mesma repetição.

- **Reservar:** qualquer membro pode reservar. O app bloqueia horário com aula na grade, dia não letivo e horário já reservado. A trava vale também no banco, então dois cliques simultâneos não geram reserva duplicada.
- **Cancelar reserva:**
  - Toque numa sala **reservada** (na tela Agora, na Grade ou na Busca) ou use o botão **Cancelar** na lista de Reservas.
  - O banco registra **quem cancelou, o e-mail e a hora**, além do motivo, se informado.
- **Liberar sala:**
  - Serve para quando uma aula da grade não vai acontecer num dia específico. Toque numa sala **ocupada pela grade** e escolha **Liberar sala**.
  - Escolha o período e, se quiser, informe o motivo.
  - A sala fica livre **só naquele dia** e pode ser reservada. A grade dos outros dias não muda.
  - Para voltar atrás, use **Desfazer liberação**. Se já houver reserva no horário, é preciso cancelar a reserva antes.
- **Nada é apagado:** as salas liberadas ficam em **Reservas › Salas liberadas**, e os cancelamentos em **Reservas › Histórico**. Tudo entra nas exportações.
- **Mural:**
  - O número vermelho na aba mostra os recados não lidos. A leitura fica registrada na sua conta, então vale em todos os seus aparelhos.
  - Cada pessoa apaga os próprios recados. Administradores podem apagar qualquer um.
- **Exportar:** PDF ou Excel, por dia, mês ou período.

## Segurança

- **Protegido pelo login:** reservas, mural e lista de membros só são lidos por e-mails cadastrados. Isso vale até para quem tiver o endereço do app.
- **Visível no código da página:** a **grade fixa das turmas** e o **calendário** estão dentro do `index.html`. Quem abrir o código-fonte vê essas informações, incluindo nomes de professores que aparecem nas observações da planilha.
- **Se isso for um problema:** dá para mover a grade para o banco, com a mesma proteção das reservas. Também é possível usar repositório privado, mas o GitHub Pages em repositório privado exige plano pago do GitHub.

## Manutenção

- **Projeto pausado:** o plano gratuito do Supabase pode **pausar o projeto depois de um período sem uso**. Se o app parar de carregar os dados, entre no painel do Supabase e clique em **Restore/Resume**.
- **Próximo semestre:** a grade e o calendário precisam ser atualizados no `index.html`. Envie a nova planilha e o novo calendário ao Claude para gerar a versão atualizada e substitua o arquivo no GitHub. O `config.js` continua o mesmo.
- **Testar sem Supabase:** se o `config.js` ficar sem as chaves, o app abre em **modo local de teste**. Nesse modo as reservas ficam só naquele navegador e aparece o aviso "Modo local".
