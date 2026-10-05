# IMTS.OS · Guia de montagem dos ambientes

Dois ambientes iguais, cada um com as suas contas e chaves:

| Ambiente | Banco (Supabase, São Paulo) | Endereço | Para quê |
| --- | --- | --- | --- |
| Homologação | projeto `imts-os-homologacao` | homolog.imts.global | Testar de verdade, com integrações reais e dados de teste |
| Produção | projeto `imts-os-producao` | www.imts.global | Uso diário dos 100 |

O protótipo (`imts-modelo-organizacional`) continua como está, para simular e treinar.

**Regra dos segredos:** chave, token e JSON de conta de serviço nunca passam pelo chat. Você cola direto no SQL Editor do Supabase, no comando pronto de cada passo. A mim você passa só o que não é segredo: ids de pasta, nomes de usuário de bot, nome do modelo.

## Ordem e quem faz

| Nº | Etapa | Quem | Tempo estimado |
| --- | --- | --- | --- |
| 1 | Criar os 2 projetos Supabase | Ítalo | **feito** |
| 2 | Banco, funções e conferência nos 2 projetos | Claude | **feito** |
| 3 | Workspace em imts.email: domínio, conta do sistema e drive do acervo | Ítalo | 40 min |
| 4 | Google Cloud: APIs, login e contas de serviço | Ítalo | 40 min |
| 5 | Supabase: login Google, URLs e e-mail | Ítalo ou time | 20 min |
| 6 | Site em imts.global: Cloudflare Pages e DNS no GoDaddy | Ítalo ou time | 30 min |
| 7 | Telegram: 2 bots | Ítalo | 10 min |
| 8 | Anthropic e Kimi: chaves e limites | Ítalo | 20 min |
| 9 | Teste ponta a ponta real em homologação | Claude, com você entrando no app | 1 h |

## 1. Projetos Supabase (feito)

Organização **IMTS.OS** (plano Pro), região `sa-east-1` (São Paulo).

| Ambiente | Ref do projeto | Endereço da API |
| --- | --- | --- |
| Homologação | `eaaycpeenahiengutfic` | `https://eaaycpeenahiengutfic.supabase.co` |
| Produção | `jloyxteijsnrwnnwfhyk` | `https://jloyxteijsnrwnnwfhyk.supabase.co` |

## 2. Banco e funções (feito)

Nos dois projetos:
- extensões, migrações 000 a 073, primeiro administrador `italo.teofilo@imts.email`, perfil de produção e endurecimento de permissões;
- parâmetros: `login.dominios = ["imts.email"]`, `google.usuario_sistema = sistema@imts.email`, `alerta.emails = ["italo.teofilo@imts.email"]`, `servidor.url_funcoes` do próprio projeto;
- funções publicadas: `google`, `ia` e `conexoes` (exigem login) e `alertas` e `telegram` (protegidas pela chave do cofre);
- conferência: `internos_ok = true`; o que falta é externo (passos 3 a 8).

## 3. Google Workspace (Ítalo, como superadministrador)

O Workspace usa **imts.email**; o site usa **imts.global**. Os dois domínios estão registrados no GoDaddy. O domínio imts.com.br não é usado.

No Admin Console (admin.google.com):

1. Verifique `imts.email` e ative o e-mail. Os dois registros são criados no GoDaddy, em **Meus produtos > imts.email > DNS**:
   - **TXT de verificação:** o valor que o Admin Console mostrar (https://support.google.com/a/answer/183895);
   - **MX:** exatamente os valores que o Admin Console mostrar na ativação do Gmail (https://support.google.com/a/answer/61158). Antes, apague no GoDaddy os MX antigos que existirem;
   - confira no Admin Console que o domínio aparece como verificado e o Gmail como ativo.
2. Crie o usuário **sistema@imts.email**, com licença. Ninguém usa essa conta no dia a dia. Ela:
   - é dona do acervo no Drive;
   - envia os alertas por e-mail.
3. No Drive, crie um drive compartilhado **IMTS.OS Acervo**, com duas pastas: `Produção` e `Homologação`.
   - Ponha sistema@imts.email como **gerente de conteúdo**.
   - Me mande o id de cada pasta: o trecho da URL depois de `/folders/`.
   - Se o plano não tiver drive compartilhado, crie as duas pastas no Meu Drive da conta sistema.

## 4. Google Cloud (Ítalo, com a mesma conta de superadministrador)

Em console.cloud.google.com:

1. Crie o projeto **imts-os** dentro da organização imts.email.
2. Ative as APIs **Google Drive**, **Google Calendar** e **Gmail**.
3. Tela de consentimento OAuth (https://developers.google.com/workspace/guides/configure-oauth-consent):
   - tipo **Interno** (só contas @imts.email entram);
   - nome do app: IMTS.OS;
   - e-mail de suporte: o seu.
4. Credencial **ID do cliente OAuth**, tipo **Aplicativo da Web**:
   - URIs de redirecionamento autorizados, os dois:
     - `https://eaaycpeenahiengutfic.supabase.co/auth/v1/callback`
     - `https://jloyxteijsnrwnnwfhyk.supabase.co/auth/v1/callback`
   - guarde o ID do cliente e a chave secreta só até o passo 5.
5. **Contas de serviço**: crie duas, `imts-os-homologacao` e `imts-os-producao`, e baixe uma chave JSON de cada. Guia: https://developers.google.com/identity/protocols/oauth2/service-account
6. No Admin Console, **delegação em todo o domínio** (https://support.google.com/a/answer/162106). Para cada conta de serviço:
   - informe o Client ID (número que aparece na conta de serviço);
   - informe exatamente estes três escopos:
     - `https://www.googleapis.com/auth/drive`
     - `https://www.googleapis.com/auth/calendar.events`
     - `https://www.googleapis.com/auth/gmail.send`
7. Grave cada JSON no cofre do seu ambiente, no SQL Editor do projeto certo:
   ```sql
   select vault.create_secret('<cole aqui o conteúdo inteiro do JSON>', 'google_conta_servico', 'conta de serviço do Google');
   ```
   Depois apague os arquivos JSON do seu computador.

## 5. Supabase: login e e-mail (Ítalo ou time, em cada projeto)

1. **Authentication > Providers > Google:** ligue e cole o ID do cliente e a chave secreta do passo 4.4. Guia: https://supabase.com/docs/guides/auth/social-login/auth-google
2. **Authentication > URL Configuration** (https://supabase.com/docs/guides/auth/redirect-urls):

   | Campo | Homologação | Produção |
   | --- | --- | --- |
   | Site URL | `https://homolog.imts.global` | `https://www.imts.global` |
   | Redirect URLs | `https://homolog.imts.global/**` | `https://www.imts.global/**` |

3. **E-mail próprio (SMTP)** para o link de clientes e parceiros (https://supabase.com/docs/guides/auth/auth-smtp):
   - o time escolhe o serviço de envio;
   - remetente sugerido: `naoresponda@imts.email`.
4. **Email Templates:** textos em português (eu te passo prontos).

## 6. Hospedagem do site em imts.global (Ítalo ou time)

O DNS fica no GoDaddy; a hospedagem é o Cloudflare Pages (conta gratuita basta para páginas estáticas). As páginas são estáticas e a publicação é por envio direto (https://developers.cloudflare.com/pages/get-started/direct-upload/).

1. No Cloudflare, crie dois projetos Pages por envio direto: `imts-os` (produção) e `imts-os-homolog` (homologação). Envie a pasta de cada ambiente que eu gerar.
2. Em cada projeto, **Custom domains > Set up a domain**: `www.imts.global` e `homolog.imts.global`. O Cloudflare mostra o registro CNAME a criar (https://developers.cloudflare.com/pages/configuration/custom-domains/).
3. No GoDaddy, em **imts.global > DNS**, crie os dois CNAME exatamente como o Cloudflare mostrou:

   | Nome | Tipo | Aponta para |
   | --- | --- | --- |
   | `www` | CNAME | o endereço `.pages.dev` do projeto `imts-os` |
   | `homolog` | CNAME | o endereço `.pages.dev` do projeto `imts-os-homolog` |

4. No GoDaddy, **encaminhamento** de `imts.global` para `https://www.imts.global` (https://www.godaddy.com/help/forward-my-godaddy-domain-12123).
5. Espere o Cloudflare marcar os dois domínios como ativos (o certificado é emitido por ele).

Alternativa: mudar os servidores de nome de imts.global para o Cloudflare. Só vale se o time quiser gerir o DNS lá; para este site, os CNAME no GoDaddy bastam.

Eu gero as duas pastas publicáveis com `montar.sh`, uma por ambiente. Você, ou o time, publica.

## 7. Telegram (Ítalo, 10 min)

1. No Telegram, fale com o @BotFather e use `/newbot` duas vezes (https://core.telegram.org/bots/tutorial):
   - produção: nome `IMTS.OS`, usuário a sua escolha, terminado em `bot`;
   - homologação: nome `IMTS.OS Homologação`, outro usuário.
2. Grave cada token no cofre do projeto certo:
   ```sql
   select vault.create_secret('<token do BotFather>', 'telegram_bot_token', 'token do bot');
   ```
3. Me mande os dois usuários dos bots (não é segredo). Eu ligo o webhook e os comandos.

## 8. IA: Anthropic e Kimi (Ítalo)

**Anthropic**, no Claude Console (https://platform.claude.com/docs/en/get-api-key):
1. Crie uma chave por ambiente e defina o limite de gasto mensal no Console.
2. Grave no cofre:
   ```sql
   select vault.create_secret('<chave>', 'anthropic_chave', 'chave da API Anthropic');
   ```

**Kimi (Moonshot AI)**, na plataforma Kimi (https://platform.kimi.ai/docs/api/overview):
1. Crie a conta, ponha crédito e crie uma chave por ambiente.
2. Grave no cofre:
   ```sql
   select vault.create_secret('<chave>', 'kimi_chave', 'chave da API Kimi');
   ```
3. A API é compatível com a da OpenAI:
   - compatibilidade: https://platform.kimi.ai/docs/guide/migrating-from-openai-to-kimi
   - chamada: https://platform.kimi.ai/docs/api/chat
4. Me mande:
   - o endereço base da API, como está nessa página;
   - o nome do modelo que você quer usar.

   Eu preencho `ia.kimi_url` e `ia.kimi_modelo` e testo.

**Qual é a principal:** parâmetro `ia.provedor` (`anthropic` ou `kimi`). A outra fica de reserva automática. O teto mensal de tokens (`ia.orcamento_mensal_tokens`) vale para as duas somadas.

## 9. Teste ponta a ponta real em homologação (Claude, com você)

Sem simulador e sem dado fictício escondido. Cada item roda na integração de verdade:

- [ ] Você entra com o Google.
- [ ] Um convidado entra pelo link do e-mail.
- [ ] Um arquivo sobe ao Drive pelo Acervo e o texto é lido.
- [ ] Uma reunião é criada com Meet na sua agenda.
- [ ] A ata sai pela IA principal e também pela reserva.
- [ ] O bot responde a você no Telegram.
- [ ] Um alerta chega por e-mail e no Telegram.
- [ ] O worker emite um PDF.

Resultado esperado: a conferência mostra `pronto=true` em homologação. Só então repetimos em produção, com o cadastro real.

## Inventário: o que ainda não é integração real

Em produção, nada é sorteado nem marcado como feito sem ninguém fazer. Tarefa sem integração vira **cartão para uma pessoa** (motor assistido). A tabela diz o que falta para cada ponto virar integração de verdade.

| Ponto | No protótipo | Em produção hoje | Para ficar 100% integrado |
| --- | --- | --- | --- |
| Tarefas de automação do motor (R) | Simuladas | Cartão para a pessoa do círculo | P6: automatizar as que só registram, avisam ou calculam dentro do próprio banco |
| Tarefas e decisões de agente (A) | Simuladas e sorteadas | Cartão para a pessoa do círculo | P6: agentes com IA real (Anthropic ou Kimi), liberados pela IT-06; nada sai sem aprovação de pessoa |
| ERP contábil, emissor fiscal e bancos | Adaptadores simulados | Cartão para a pessoa (Gestão) | **Decisão sua:** quais sistemas. Depois a P6 liga cada um |
| Assinatura eletrônica | Pendente | PDF com as âncoras de assinatura; assinatura fora do sistema | **Decisão sua:** qual serviço (DocuSign ou outro) |
| Google Docs como terceira saída dos documentos | Pendente | PDF e HTML | P6, pela conta de serviço |
| Telegram Mini App | Faltava domínio | Bot por conversa | P6, em imts.global |
| Rótulo "simulado" no catálogo de sistemas (rt.sistema) | Rótulo | Rótulo herdado | P6: perfil de produção marca "assistido" ou "integrado" conforme o caso |
| Testes automáticos | Usam Google e IA simulados | Não existem em produção | Ficam assim por desenho; o teste real é o passo 9 |
