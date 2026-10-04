# Fase 2 · Plano para aprovação

Plano de 03/10/2026; o andamento está na seção 7. Traz as suas decisões das 17:42, 18:29 e 18:34. Cada item tem o que entra, o que sai e quem decide. Os fatos externos têm fonte no fim; o que não tem fonte é proposta minha.

## 1. Decisões suas incorporadas

| Tema | Sua decisão | Como entra no plano |
| --- | --- | --- |
| Motor | Nove motores, um por círculo, customizáveis e reaproveitáveis | Nove motores independentes, cada um com código, configuração, DKP, pasta do Drive e repositório próprios. Todos nascem do mesmo modelo-base, que guarda o que for comum |
| Machine learning | Desde já, com modelo já treinado para evoluir a plataforma | A base de ML nasce com os motores: registro de eventos, variáveis e registro de modelos. Os primeiros modelos são treinados já, com os usuários simulados, e retreinados quando entrar dado real |
| Telegram | Canal padrão para 99% das interações; a governança não precisa ser tão alta | Autodestruição por padrão, armazenamento obrigatório na nossa base, pseudonimização e anonimização |
| Usuários simulados | Sim, inclusive no Telegram | Um usuário simulado por papel de cada raia, no ambiente de teste do Telegram e no motor |
| Acessos externos | Mantidos | Contingência já feita: retrato literal das fontes, conferidor nos testes e reconferência mensal agendada |

## 2. Cuidados que entram no desenho (já decidido)

- **Nove motores:** o runtime dos runtimes (E0) leva cada correção do modelo-base aos nove motores, por versão, com os testes de cada círculo rodando antes.
- **Modelo treinado com simulação:** cada versão de modelo registra com que dado foi treinada. As versões treinadas só com dado simulado servem para evoluir a plataforma; o painel mostra simulado e real separados.
- **Telegram:** um bot não vê a mensagem de outro bot. Os agentes não conversam entre si pelo grupo; o runtime dos runtimes é a porta única do Telegram e entrega cada mensagem ao motor certo (seção 4).

## 3. O que você pode estar esquecendo

- **Identidade e acesso:** a mesma pessoa no Telegram, no Drive, no GitHub e no motor, com entrada e saída pela GE-07 (desligamento revoga tudo no mesmo dia).
- **Segredos:** chaves de bots, do Supabase e do Drive num cofre, nunca em mensagem nem em repositório.
- **Transferência internacional:** não conferi onde o Telegram guarda os dados. Se os dados saírem do Brasil, a LGPD só permite a transferência nos casos do art. 33. Cabe à Governança conferir e escolher a base: por exemplo, o consentimento específico e em destaque do inciso VIII.
- **Versão do modelo e do motor:** mudar uma jornada (ID-04) muda o motor em produção. Isso exige migração versionada e volta atrás testada.
- **Cópia e restauração testadas:** a redundância só vale se a restauração tiver sido testada.
- **Custo:** um limite por motor e por modelo de IA, acompanhado no painel.

## 4. Telegram: fatos que mudam o desenho

| Fato verificado | Consequência no desenho |
| --- | --- |
| Grupos e conversas comuns são "cloud chats", com criptografia servidor-cliente. Só os chats secretos têm criptografia ponta a ponta | Sigilo vem do que não vai ao Telegram e da autodestruição, não da criptografia |
| Bots não veem mensagens de outros bots, em nenhum modo | Agentes não se coordenam pelo grupo. O motor orquestra, e cada grupo tem um bot de entrada |
| Em grupo, o bot em modo privacidade só recebe comandos, menções e respostas a ele | O bot de entrada é administrador do grupo, ou as tarefas são abertas por comando |
| As atualizações ficam no servidor no máximo 24 horas | O motor consome sem parar (webhook) e grava tudo na nossa base antes de qualquer outra coisa |
| Um bot só apaga mensagens enviadas há menos de 48 horas | Autodestruição feita pelo bot tem de rodar antes de 48 horas. O temporizador nativo do chat (24 horas ou 7 dias; opções vistas em 2021, blog do Telegram, 23/02/2021) é configurado pelo administrador |
| Limites de envio: 1 mensagem por segundo por chat, 20 por minuto por grupo, cerca de 30 por segundo no total | Fila de envio no motor; avisos em massa vão por resumo, não um a um |
| O Telegram tem ambiente de teste próprio para bots e usuários | Os usuários simulados rodam lá, sem misturar com o ambiente real |

**O 1% fora do Telegram:** você definiu os 99%, mas não disse o que fica no 1%. Entram estes três, até você trocar algum:
- Senhas, chaves e códigos de acesso nunca vão pelo Telegram.
- Os relatos da GO-09 (canal de denúncia) vão por formulário próprio, para proteger quem relata.
- Aprovações de pagamento (GE-04, GE-05) têm confirmação fora do Telegram, para manter a segregação.

**Armazenamento e anonimização (LGPD):**
- Na nossa base, a identidade é pseudonimizada. A chave que liga o pseudônimo à pessoa fica separada, em ambiente controlado (art. 13, § 4º). Na nossa interpretação do art. 12 e do art. 13, § 4º, dado pseudonimizado continua sendo dado pessoal; a lei não diz isso com essas palavras.
- Para ML e para o painel agregado, o dado é anonimizado. Ele só deixa de ser dado pessoal se a anonimização não puder ser revertida com meios razoáveis (art. 12).

## 5. Entregas

| # | Entrega | O que é | Depende de |
| --- | --- | --- | --- |
| E0 | Runtime dos runtimes | Plano de controle acima dos nove motores: registra cada motor e a versão dele; distribui as atualizações do modelo-base; leva as 411 trocas de um círculo a outro; é a porta única do Telegram; junta os eventos para o painel e o ML; acompanha saúde e custo | não há |
| E1 | Registro de eventos | Cada tarefa executada vira um evento: jornada, etapa, tarefa, raia, executor, modo, início, fim, resultado e marca simulado ou real. Fica no Supabase, ao lado do modelo | não há |
| E2 | Usuários simulados | Uma pessoa simulada por papel de raia (sócios, executivo, Administrador do IMTS.OS, líderes, pessoas dos círculos, assessorias), com contas no ambiente de teste do Telegram | E1 |
| E3 | Instruções de trabalho | Uma instrução por jornada (75), geradas da fonte do modelo: impressa (PDF) e digital (página). Mesma fonte, nenhuma divergência | não há |
| E4 | Modelo-base e motor piloto | O modelo-base dos motores e o primeiro motor, que executa as jornadas de um círculo. Piloto: Identidade (5 jornadas, você é o líder). É o G7 | E1, sua escolha da tecnologia do motor |
| E5 | Canal Telegram | Bot de entrada por motor, webhook, fila de envio, autodestruição e gravação na base | E1, E4 |
| E6 | Painel | Visão de toda a operação: por círculo, jornada, etapa e alçada; trocas entre círculos; modo de execução; saúde das DKPs; desempenho dos modelos | E1 |
| E7 | Simulador de cenários | Separado do motor: lê uma cópia do modelo e dos parâmetros, roda carga sintética e devolve propostas de mudança, que seguem a ID-04. Nunca escreve no motor | E1, E3 |
| E8 | ML | Primeiros modelos: risco de atraso por etapa, promoção de modo (Copiloto → Autopiloto) e anomalia de cadência. Treinados já com os usuários simulados, retreinados com dado real; avaliação no painel | E1, E2 |
| E9 | Interface conversacional | Uma camada de conversa sobre Telegram e página web: intenção → tarefa, com a pessoa decidindo o que é de alçada | E4, E5 |
| E10 | Os outros oito motores | Criados do modelo-base e customizados por círculo | E4 a E6 estáveis |

**Ordem proposta:** E0, E1 e E3 começam já: não dependem de escolha e custam pouco. Depois vêm E2 e E8, com o modelo treinado na simulação, e então E4, E5 e E6 no piloto, E7, E9 e E10.

## 6. Decidido em 03/10/2026, às 18:34

1. Motores próprios sobre o Supabase, sob o runtime dos runtimes (G7).
2. Piloto: Identidade.
3. Uso real do Telegram com o consentimento específico e em destaque do art. 33, VIII, da LGPD, colhido na entrada de cada pessoa (GE-07). A Governança responde. Pela política de privacidade do Telegram, quem desenvolve o bot responde pelos dados que ele recebe: aqui, o IMTS.
4. E0 construído: esquema `rt` no Supabase, com 10 testes verdes (4-modelo-fonte/supabase/003_runtime.sql).

## 6.1 Decidido em 03/10/2026, às 20:36: a Mesa de trabalho (E11)

1. **Mesa de trabalho (E11):** a tela onde cada pessoa recebe, faz, decide, delega e acompanha as suas tarefas. Parte da moldura do protótipo da interface humano-IA: chão comum, foco, periferia e entrada por voz ou texto, com os oito momentos (chegada, captura de intenção, trabalho, delegação, decisão, colaboração, memória e confiança, encerramento). A E9, interface conversacional, passa a ser o canal de conversa da Mesa.
2. **Modos:** o controle "Nesta tarefa, eu vou" fica ligado aos quatro modos: só informar = Assistido; propor = Copiloto; fazer e você aprova = Autopiloto; fazer e enviar = Autômato. A pessoa não passa do modo aprovado para a etapa (a alçada).
3. **Formatos:** Telegram na conversa e Telegram Mini App como principais; navegador para trabalho longo; sala de situação para leitura coletiva; impresso para estudo. Um aplicativo só.
4. **Kanban:** vista de quadro da Mesa, com cinco colunas (a fazer, fazendo, esperando, decidir, feito); três quadros (meu, do círculo, da jornada); raias à escolha da pessoa. O cartão de fluxo anda pelo motor; o foco é onde se trabalha.
5. **Tarefas avulsas e delegação:** três tipos de cartão (de fluxo, avulsa, pedido de ajuda). Delegação a agente (com o modo), a colega do círculo (com aceite), a outro círculo (com aceite e o líder dele vendo) e de tarefa de fluxo só dentro da mesma raia (fora dela, o líder decide). Regras: todo cartão tem dono e prazo; alçada não se contorna (a captura sugere a jornada que já existe); avulsa que se repete vira proposta à ID-04; todo cartão gera evento.
6. **Privacidade:** a avulsa é vista só por quem é dono e por quem recebeu; o líder vê a carga em números, não o conteúdo.
7. **Ordem:** motor com estado das tarefas e avulsas; protótipo da Mesa da Identidade; cérebro vivo na sala de situação.

## 6.2 Decidido em 03/10/2026, às 21:05: o dia a dia no modelo e o backlog até o fim

1. **Texto de limites dos nove círculos:** "Os fluxos rodam no motor próprio sobre o Supabase, por enquanto em simulação (piloto: Identidade). Falta trocar os adaptadores simulados pelos sistemas reais."
2. **Jornadas novas na Gestão:** GE-14 (dívidas tributárias: parcelamentos, transações, negociações e renegociações) e GE-15 (plano de contas, centros de custo por empresa, círculo e projeto, e plano tributário do grupo).
3. **Etapas novas:** racional financeiro do contrato na NE-04 (etapa 2) e planejado x realizado por contrato na GE-02 (etapa 2). Balancete, DRE e balanço nomeados na GE-05.
4. **Multiempresa e acesso:** empresas na base (simuladas até o G1), login, permissões e direitos do titular.
5. **Contábil e fiscal:** integrar um sistema de contabilidade e emissão fiscal, com o motor orquestrando; a escolha do fornecedor fica para a stack de produção.
6. **Ritmo da simulação contínua:** uma execução a cada 5 minutos (escolha minha, por custo; com "tudo aprovado", não houve escolha explícita entre 1 e 5 minutos).

## 6.3 Decidido em 04/10/2026, às 08:53: motor documental (E12) e administração geral (E13)

1. **E12 Motor documental:** um motor só, para todos os documentos formais internos e externos das empresas. Ele absorve o motor de contratos e o de propostas, cujo código falta receber. Tem catálogo de tipos tirado das saídas do modelo, marca como arquivo de dados por empresa, dez modelos de design, gates editoriais do Legal.OS, registro com hash e aprovação em duas mãos.
2. **Worker próprio:** fila no Supabase e worker com Chromium. No protótipo, o worker roda no ambiente de trabalho; em produção, num serviço a escolher.
3. **Marcas primeiro:** IMTS, Onni e TRON, a partir das identidades que já existem. A TRON fica provisória, sem manual.
4. **Saídas:** PDF e HTML agora. Google Docs quando o Drive da IMTS for conectado. Nenhum formato Microsoft.
5. **E13 Administração geral:** um registro único das conexões externas, que guarda só o nome do segredo no Vault. Todos os parâmetros num lugar só, com validação, histórico, propagação ao destino e duas mãos nos sensíveis. Uma página de administração ao vivo.

## 7. Andamento (04/10/2026, 10h)

| Entrega | Situação |
| --- | --- |
| E0 Runtime dos runtimes | Pronto. Publicou a versão 2026-10-03.2 do modelo-base e a aplicou nos nove motores, com os testes de cada círculo verdes |
| G7 Tarefas ligadas a sistemas | As 1.586 tarefas ligadas a 9 sistemas: canal das pessoas, agentes, automações, trocas, assessorias, ERP contábil, emissor fiscal e bancos, com adaptador simulado e contrato de interface, e o motor-documental (21 tarefas) |
| E1 Registro de eventos | Pronto, com os eventos de cartão, conversa e titular |
| E2 Usuários simulados | 61 na base, com id fictício de Telegram para a simulação. Falta o bot no ambiente de teste (token) |
| E3 Instruções de trabalho | Refeitas para 75 jornadas: 75 PDFs (as 1.586 tarefas conferidas nos PDFs) e página digital com 672 ligações |
| E4 Motor piloto | Pronto; ajuste do teto das voltas, que passa a valer por laço |
| E5 Canal Telegram | Pronto e no ar (Edge Function, fila com os limites, autodestruição a cada 10 minutos, segredos no Vault): 12 testes verdes. Falta só o token do bot de teste |
| E6 Painel e cérebro vivo | Nove lobos acesos; leitura ao vivo de 30 em 30 segundos |
| E7 Simulador de cenários | Pronto: fila por papel, três cenários, 6 testes, 6 propostas para a ID-04 no esquema sim |
| E8 ML | Modelos retreinados com os nove motores (versão 2026-10-03.2), fora de uso: dado simulado |
| E9 Conversa | Pronta sobre o Telegram: comandos, botões e texto livre que procura a jornada existente |
| E10 Os outros oito motores | Os nove em piloto, cada um com a sua configuração; 10.215 execuções, 211.066 eventos, 0 erros; 1.586 de 1.586 tarefas executadas; simulação contínua a cada 5 minutos |
| E11 Mesa de trabalho | Pronta; sem violação nas regras automáticas do axe-core (níveis A e AA), a 1.280 px; a conferência manual de acessibilidade é parcial (requisitos_acessibilidade.md) |
| Acesso e multiempresa | Login, permissões, papéis incompatíveis barrados, direitos do titular (LGPD, art. 18): 10 testes verdes |
| E12 Motor documental | Pronto no protótipo. Catálogo de 38 tipos em 10 famílias, ligado a 162 saídas e a 127 tarefas do modelo (por regra de texto, para revisão da ID-04). Quatro pacotes de marca, dez modelos, regra do terço automática e gates no PDF. Fila, worker, emissão registrada com hash e decisão em duas mãos no esquema doc. Ponta a ponta conferida: pedido no Supabase, emissão pelo worker, PDF e HTML gravados com o hash conferido. 21 automações passaram ao sistema motor-documental. 30 testes do motor e 8 no Supabase |
| E13 Administração geral | Pronta. 16 conexões e 19 parâmetros (eram 15 às 10h) com destino, validação, histórico e duas mãos nos sensíveis. Verificação de saúde a cada 30 minutos (SQL, Vault e HTTP pelo pg_net): 7 saudáveis, 1 falha real (token do bot ausente), 8 pendentes ou simuladas. Página ao vivo pelo conector do Supabase. 9 testes no Supabase |

**Testes no Supabase:** 102 verdes em 04/10/2026, rodados por `select adm.testar_tudo()`, que não grava nada (runtime 10, motor 9, Mesa 12, Telegram 12, acesso 10, documental 8, administração 10, externo 10, agentes 10, segurança 11), mais os 30 do motor documental, os testes do modelo (testar.py: nove círculos, 411 trocas, 20 alçadas) e do simulador (6).

**O que fica de fora do meu alcance:** o token do bot de teste (você, no BotFather); o termo do art. 33 (Governança); os gates de implantação com dado real (G1 a G9); a escolha do sistema contábil e fiscal e dos sistemas reais de cada adaptador; o código do contract_engine e do motor de propostas, para absorver no motor único; os arquivos da fonte Nexa; o manual da marca TRON; a razão social e o CNPJ da IMTS; a conexão do Drive da IMTS e da DocuSign; o serviço do worker em produção; a hospedagem do Mini App: precisa de um endereço público, e conferi em 03/10/2026 que o Supabase entrega HTML de Edge Function como texto simples no domínio padrão, então ele não serve para isso sem domínio próprio.

## Fontes

- Telegram FAQ, criptografia de cloud chats e chats secretos: https://telegram.org/faq
- Telegram Bot FAQ, bots não veem mensagens de outros bots e limites de envio: https://core.telegram.org/bots/faq
- Telegram Bot Features, modo privacidade e ambiente de teste: https://core.telegram.org/bots/features
- Telegram Bot API, atualizações guardadas no máximo 24 horas: https://core.telegram.org/bots/api
- deleteMessage, limite de 48 horas: documentação do método na Bot API, conferida na reprodução da aiogram, https://docs.aiogram.dev/en/latest/api/methods/delete_message.html. A página oficial veio truncada na leitura.
- Telegram, temporizador de autodestruição em todos os chats (24 horas ou 7 dias), 23/02/2021: https://telegram.org/blog/autodelete-inv2
- Lei 13.709/2018 (LGPD), arts. 5º, III e XI; 12; 13, § 4º; e 33, I e VIII: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Telegram, política de privacidade (bots independentes do Telegram; quem desenvolve responde pelos dados): https://telegram.org/privacy
- Telegram Bots (plataforma de bots gratuita): https://core.telegram.org/bots
