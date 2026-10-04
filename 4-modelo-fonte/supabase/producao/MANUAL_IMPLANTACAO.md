# IMTS.OS · Manual de implantação em produção

Para o time de tecnologia. Execute na ordem. Cada etapa diz quem faz, o que entra e como conferir.

**Regras gerais**
- Segredo só no cofre do Supabase (Vault). Nunca em chat, e-mail, planilha, repositório ou variável de ambiente do aplicativo.
- Nada aqui altera o protótipo. Tudo vai para um projeto Supabase NOVO.

## Visão geral

| Peça | Onde roda | O que é |
| --- | --- | --- |
| Banco | Supabase (Postgres) | Modelo, motor de processos, acessos, portal, acervo, alertas. Migrações `supabase/001` a `068` e o perfil `producao/090`. |
| Aplicativo | Hospedagem estática em www.imts.global | Páginas HTML e JavaScript (`app/`). Login Google para a equipe e link por e-mail para clientes e parceiros. |
| Funções do servidor | Supabase Edge Functions | `google` (Drive e Agenda), `ia` (rascunho de ata), `alertas` (e-mail), `telegram` (bot). |
| Worker de documentos | Contêiner Docker | Emite os PDFs da fila (`documentos/Dockerfile`). |
| Google Workspace | imts.com.br | Login, Drive do acervo, Agenda com Meet e Gmail dos alertas. |

## Responsáveis

| Item | Etapa | Dono |
| --- | --- | --- |
| E01 | Workspace mínimo | Ítalo |
| E02 | Projeto Supabase pago, região São Paulo | Time |
| E03 | Hospedagem e DNS de www.imts.global | Time |
| E04 | Conta de serviço com delegação no Workspace | Time e Ítalo (administrador do Workspace) |
| E05 | Login Google no Supabase | Time |
| E06 | Envio de e-mail (SMTP) | Time |
| E07 | Bot do Telegram | Ítalo |
| E08 | Chave da API de IA e orçamento | Ítalo |
| E09 | Hospedar o worker | Time |
| E10, E11, E13 | Cadastro: pessoas, empresas, regras de comissão | Ítalo e Negócios |
| E12 | LGPD | Governança e jurídico |
| E14 | Implantar e homologar | Time |
| E15 | Treinamento por círculo | Líderes de círculo |

## 0. Ferramentas no computador de quem implanta

- `psql` 16 ou mais novo.
- Supabase CLI (https://supabase.com/docs/reference/cli/supabase-functions).
- Docker.
- Git, com acesso ao repositório `imts-modelo-organizacional`.

## 1. Workspace mínimo (E01, Ítalo)

1. Domínio `imts.com.br` verificado no Google Workspace.
2. Cada pessoa da equipe com conta `@imts.com.br`. O login do aplicativo aceita só os domínios do parâmetro `login.dominios`, que vem com `["imts.com.br"]`.
3. Uma conta de sistema, por exemplo `sistema@imts.com.br`. É a dona do acervo no Drive e a remetente dos alertas. Ninguém usa essa conta no dia a dia.
4. Uma pasta raiz do acervo:
   - num drive compartilhado, se o plano contratado tiver;
   - senão, no Meu Drive da conta de sistema.
   - Dê à conta de sistema acesso de gerente de conteúdo, ou de dono.
   - Anote o id da pasta: é o trecho final da URL depois de `/folders/`.
5. Confira no plano contratado se a gravação e a transcrição do Meet estão disponíveis. A Central usa a transcrição quando ela existe; sem ela, a ata é escrita à mão.

## 2. Projeto Supabase (E02, Time)

1. Crie um projeto novo, em plano pago, na região São Paulo (`sa-east-1`). Guarde a senha do banco no cofre de senhas do time.
2. Anote:
   - **Project ref** (o `<ref>` de `https://<ref>.supabase.co`);
   - **chave publicável** (anon ou `sb_publishable_...`), que é pública por desenho;
   - **string de conexão direta do banco** (em *Connect*).
3. Leia o checklist de produção do Supabase: https://supabase.com/docs/guides/deployment/going-into-prod

## 3. Banco (E14, Time)

```bash
cd imts-modelo-organizacional/<pasta>/supabase/producao
export DB_URL='postgresql://postgres:<senha>@db.<ref>.supabase.co:5432/postgres'
export ADMIN_NOME='Nome do primeiro administrador' ADMIN_EMAIL='nome@imts.com.br'
./aplicar.sh
```

**O que o script faz, nesta ordem:**
1. Habilita as extensões (`000_extensoes.sql`: pg_cron, pgcrypto, pg_net e Vault).
2. Aplica as migrações `001` a `068`, pulando `012a`, que só serve para trocar a versão do modelo.
3. Cadastra o primeiro administrador.
4. Aplica o perfil de produção (`090`). O perfil:
   - desliga a simulação;
   - apaga o cadastro simulado;
   - passa os agentes para o administrador;
   - gera a chave do worker no cofre;
   - liga o modo assistido do motor;
   - remove as funções de simulação e de teste;
   - deixa pendentes as conexões que apontavam para o protótipo.
5. Imprime a conferência.

O script recusa banco que já tenha o esquema `rt`: a implantação é só para projeto novo.

**Conferir:** no fim deve sair `internos_ok=true`. Os itens marcados `(externo)` fecham nas etapas seguintes. Para conferir de novo a qualquer momento, rode `./aplicar.sh --conferir`.

**Homologação do banco, sem deixar rastro (tudo é desfeito):**

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f homologar_banco.sql      # deve imprimir: homologação do banco: 7 de 7 ok
```

## 4. Login (E05 e E06, Time)

**Google, para a equipe** (guia oficial: https://supabase.com/docs/guides/auth/social-login/auth-google):
1. No Google Cloud do Workspace do IMTS:
   - tela de consentimento OAuth do tipo **interno**, assim só contas do Workspace entram;
   - cliente OAuth do tipo **aplicativo da Web**;
   - URI de redirecionamento: `https://<ref>.supabase.co/auth/v1/callback`.
2. No Supabase, em Authentication > Providers > Google: cole o id e o segredo do cliente.
3. Em Authentication > URL Configuration (https://supabase.com/docs/guides/auth/redirect-urls):
   - Site URL: `https://www.imts.global`;
   - Redirect URLs: `https://www.imts.global/**`.

**Link por e-mail, para clientes e parceiros:**
1. Configure SMTP próprio: https://supabase.com/docs/guides/auth/auth-smtp. O envio padrão do Supabase não serve para produção.
2. Traduza os modelos de e-mail de Authentication > Email Templates para português.
3. Quem não tem convite recebe o link, mas entra como "sem cadastro" e não vê nada.

## 5. Conta de serviço do Google (E04, Time e Ítalo)

Referências oficiais:
- https://developers.google.com/identity/protocols/oauth2/service-account
- https://support.google.com/a/answer/162106

1. No mesmo projeto do Google Cloud, ative as APIs **Google Drive**, **Google Calendar** e **Gmail**.
2. Crie uma conta de serviço e uma chave JSON. Baixe o arquivo uma vez e apague-o depois do passo 4.
3. No Admin Console do Workspace, Ítalo dá delegação em todo o domínio ao *Client ID* da conta, com exatamente estes escopos:
   - `https://www.googleapis.com/auth/drive`
   - `https://www.googleapis.com/auth/calendar.events`
   - `https://www.googleapis.com/auth/gmail.send`
4. Grave a chave no cofre pelo SQL Editor do Supabase (https://supabase.com/docs/guides/database/vault). Cole o conteúdo do JSON:
   ```sql
   select vault.create_secret('<conteúdo do JSON>', 'google_conta_servico', 'conta de serviço do Google (Drive, Agenda, Gmail)');
   ```
5. Preencha os parâmetros (pela Administração > Parâmetros, ou por SQL na implantação):
   ```sql
   update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema';
   update adm.parametro set valor = '"<id da pasta raiz>"'  where chave = 'google.drive_raiz';
   ```

**Como a função age:**
- **Drive:** sempre em nome da conta de sistema.
- **Agenda:** em nome de quem marcou a reunião, que vira o organizador e recebe o Meet na própria agenda.
- **Gmail:** em nome da conta de sistema.

## 6. Funções do servidor (E14, Time)

```bash
cd imts-modelo-organizacional/<pasta>          # a pasta que contém supabase/
supabase login
supabase link --project-ref <ref>
supabase functions deploy google
supabase functions deploy ia
supabase functions deploy alertas  --no-verify-jwt   # chamada pela rotina, com a chave X-IMTS-Chave
supabase functions deploy telegram --no-verify-jwt   # chamada pelo Telegram (webhook), com o segredo do webhook
```

Guia de publicação: https://supabase.com/docs/guides/functions/deploy

**O que as funções usam:**
- `SUPABASE_DB_URL`, que o Supabase fornece às funções.
- Os segredos do cofre.
- Nenhuma variável de ambiente nova.

Depois de publicar:
```sql
update adm.parametro set valor = '"https://<ref>.supabase.co/functions/v1"' where chave = 'servidor.url_funcoes';
update adm.parametro set valor = '["ti@imts.com.br"]' where chave = 'alerta.emails';      -- quem recebe os alertas
```

Na Administração > Conexões, preencha o endereço de produção e marque como ativa cada conexão pendente:
- `supabase-api`, `supabase-postgres`, `edge-telegram`;
- `edge-google`, `edge-ia`, `edge-alertas`;
- `google-drive-imts`.

## 7. Bot do Telegram (E07, Ítalo)

1. No Telegram, fale com o @BotFather e use `/newbot` (https://core.telegram.org/bots/tutorial). Guarde o token só até o passo 2.
2. Grave o token e passe o bot para o ambiente de produção:
   ```sql
   select vault.create_secret('<token do BotFather>', 'telegram_bot_token', 'token do bot do IMTS.OS');
   select vault.update_secret((select id from vault.secrets where name = 'telegram_ambiente'), 'producao');
   select rt.telegram_configurar();     -- registra o webhook e os comandos do bot
   ```
3. Alertas no Telegram:
   - crie um grupo do time de Integração e ponha o bot nele;
   - preencha `alerta.chat_ref` com `tg:<id do grupo>`;
   - para achar o id: uma pessoa cadastrada escreve ao bot no grupo; o bot responde que o grupo ainda não está ligado, e o `chat_ref` dessa resposta aparece em `select chat_ref, texto from rt.fila_envio order by id desc limit 5;`.
4. LGPD: uso real do Telegram exige o consentimento do art. 33, VIII, registrado por pessoa (decisão de 03/10/2026). O banco recusa vínculo real sem ele.

## 8. IA (E08, Ítalo)

1. Crie uma chave da API da Anthropic no Console (documentação: https://docs.claude.com).
2. Grave no cofre:
   ```sql
   select vault.create_secret('<chave>', 'anthropic_chave', 'chave da API de IA');
   ```
3. Ajuste o teto mensal de tokens em `ia.orcamento_mensal_tokens` (vem com 2.000.000) e o modelo em `ia.modelo`.
4. Passou do teto, a função recusa até o mês virar. O uso fica em `adm.registro_servidor`.

## 9. Worker de documentos (E09, Time)

```bash
cd imts-modelo-organizacional/<pasta>/documentos
docker build -t imts-worker-documentos .
docker run -d --restart=always --name imts-worker \
  -e SUPABASE_URL=https://<ref>.supabase.co -e SUPABASE_CHAVE_PUB=<chave publicável> \
  -e DOC_WORKER_CHAVE=<valor do segredo doc_worker_chave> -e DOC_WORKER_NOME=worker-1 imts-worker-documentos
```

- **A chave:** o administrador lê uma vez no SQL Editor com `select rt._segredo('doc_worker_chave');` e a coloca só no ambiente do contêiner.
- **Onde rodar:** qualquer hospedagem de contêiner sempre ligada (máquina virtual ou serviço de contêiner). O worker só faz chamadas de saída; não precisa de porta aberta.
- **Conferir:** pedidos de documento saem da fila em segundos. Se a fila parar por mais de 30 minutos, o alerta `fila:documentos` dispara.

## 10. Aplicativo em www.imts.global (E03, Time)

```bash
cd imts-modelo-organizacional/<pasta>/app
SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<chave publicável> ./montar.sh
```

Publique a pasta `dist/` em qualquer hospedagem estática com HTTPS.
- **DNS:** `www.imts.global` apontando para a hospedagem (CNAME, conforme o provedor). O domínio sem `www` redireciona para `www`.
- **Cabeçalhos recomendados na hospedagem:**
  - `Strict-Transport-Security`;
  - `X-Content-Type-Options: nosniff`;
  - `Referrer-Policy: strict-origin-when-cross-origin`;
  - `Content-Security-Policy` liberando só o próprio site, `https://<ref>.supabase.co`, `https://fonts.googleapis.com` e `https://fonts.gstatic.com`.

## 11. Cadastro (E10, E11, E13, Ítalo e Negócios)

1. Entre como o primeiro administrador. Em Administração > Cadastro, baixe os cinco modelos CSV:
   - empresas;
   - pessoas;
   - clientes e parceiros;
   - usuários de fora;
   - contratos de parceria.
2. Preencha na ordem dos modelos e envie. A **prévia** aponta erro por aba e linha. A carga só é confirmada sem erro, e é tudo ou nada.
3. O papel de cada pessoa é uma raia do modelo (ex.: `Operações · pessoa`, `Líder do círculo`). Administração > Implantação mostra os papéis que ainda não têm pessoa: todo papel com tarefa precisa de pelo menos uma.
4. A regra de comissão de cada parceiro (E13) entra no modelo de contratos de parceria, com a fonte (o contrato).
5. A equipe entra com o Google. Clientes e parceiros recebem convite e entram pelo link do e-mail.

## 12. LGPD (E12, Governança e jurídico)

Antes de abrir para clientes e parceiros:
- encarregado nomeado e publicado;
- aviso de privacidade no portal;
- relatório de impacto do tratamento;
- base legal da transferência internacional do Telegram (art. 33).

Prazos que o sistema já aplica, com fonte registrada em `adm.parametro.fonte`:
- resposta ao titular;
- ouvidoria (Lei 13.460/2017);
- retenção de gravações.

## 13. Conferência final e entrada em produção (E14)

1. `./aplicar.sh --conferir` mostra `pronto=true`: nenhum item falta, nem os externos.
2. Execute o roteiro de homologação por círculo (`ROTEIRO_HOMOLOGACAO.md`). Cada passo tem o resultado esperado.
3. Semana em paralelo (E15): cada círculo usa o sistema e o processo atual juntos; os líderes registram as diferenças.
4. Entrada: avise a equipe e mantenha o runbook (`RUNBOOK_OPERACAO.md`) com o time de Integração.

**Volta atrás:** antes da carga do cadastro, basta apagar o projeto e repetir. Depois da carga, use o backup do Supabase (ver runbook). O protótipo continua intocado.
