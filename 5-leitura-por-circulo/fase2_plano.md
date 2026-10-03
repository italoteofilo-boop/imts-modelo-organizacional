# Fase 2 · Plano para aprovação

Proposta de 03/10/2026, com as suas decisões das 17:42, 18:29 e 18:34. Nada aqui foi construído. Cada item tem o que entra, o que sai e quem decide. Os fatos externos têm fonte no fim; o que não tem fonte é proposta minha.

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
| Um bot só apaga mensagens enviadas há menos de 48 horas | Autodestruição feita pelo bot tem de rodar antes de 48 horas. O temporizador nativo do chat (24 horas ou 7 dias, desde 2021) é configurado pelo administrador |
| Limites de envio: 1 mensagem por segundo por chat, 20 por minuto por grupo, cerca de 30 por segundo no total | Fila de envio no motor; avisos em massa vão por resumo, não um a um |
| O Telegram tem ambiente de teste próprio para bots e usuários | Os usuários simulados rodam lá, sem misturar com o ambiente real |

**O 1% fora do Telegram:** você definiu os 99%, mas não disse o que fica no 1%. Entram estes três, até você trocar algum:
- Senhas, chaves e códigos de acesso nunca vão pelo Telegram.
- Os relatos da GO-09 (canal de denúncia) vão por formulário próprio, para proteger quem relata.
- Aprovações de pagamento (GE-04, GE-05) têm confirmação fora do Telegram, para manter a segregação.

**Armazenamento e anonimização (LGPD):**
- Na nossa base, a identidade é pseudonimizada. A chave que liga o pseudônimo à pessoa fica separada, em ambiente controlado (art. 13, § 4º). Dado pseudonimizado continua sendo dado pessoal.
- Para ML e para o painel agregado, o dado é anonimizado. Ele só deixa de ser dado pessoal se a anonimização não puder ser revertida com meios razoáveis (art. 12).

## 5. Entregas

| # | Entrega | O que é | Depende de |
| --- | --- | --- | --- |
| E0 | Runtime dos runtimes | Plano de controle acima dos nove motores: registra cada motor e a versão dele; distribui as atualizações do modelo-base; leva as 410 trocas de um círculo a outro; é a porta única do Telegram; junta os eventos para o painel e o ML; acompanha saúde e custo | — |
| E1 | Registro de eventos | Cada tarefa executada vira um evento: jornada, etapa, tarefa, raia, executor, modo, início, fim, resultado e marca simulado ou real. Fica no Supabase, ao lado do modelo | — |
| E2 | Usuários simulados | Uma pessoa simulada por papel de raia (sócios, executivo, Administrador do IMTS.OS, líderes, pessoas dos círculos, assessorias), com contas no ambiente de teste do Telegram | E1 |
| E3 | Instruções de trabalho | Uma instrução por jornada (73), geradas da fonte do modelo: impressa (PDF) e digital (página). Mesma fonte, nenhuma divergência | — |
| E4 | Modelo-base e motor piloto | O modelo-base dos motores e o primeiro motor, que executa as jornadas de um círculo. Piloto: Identidade (5 jornadas, você é o líder). É o G7 | E1, sua escolha da tecnologia do motor |
| E5 | Canal Telegram | Bot de entrada por motor, webhook, fila de envio, autodestruição e gravação na base | E1, E4 |
| E6 | Painel | Visão de toda a operação: por círculo, jornada, etapa e alçada; trocas entre círculos; modo de execução; saúde das DKPs; desempenho dos modelos | E1 |
| E7 | Simulador de cenários | Separado do motor: lê uma cópia do modelo e dos parâmetros, roda carga sintética e devolve propostas de mudança, que seguem a ID-04. Nunca escreve no motor | E1, E3 |
| E8 | ML | Primeiros modelos: risco de atraso por etapa, promoção de modo (Copiloto → Autopiloto) e anomalia de cadência. Treinados já com os usuários simulados, retreinados com dado real; avaliação no painel | E1, E2 |
| E9 | Interface conversacional | Uma camada de conversa sobre Telegram e página web: intenção → tarefa, com a pessoa decidindo o que é de alçada | E4, E5 |
| E10 | Os outros oito motores | Criados do modelo-base e customizados por círculo | E4 a E6 estáveis |

**Ordem proposta:** E0, E1 e E3 começam já: não dependem de escolha e custam pouco. Depois vêm E2 e E8, com o modelo treinado na simulação, e então E4, E5 e E6 no piloto, E7, E9 e E10.

## 6. O que preciso de você

1. Escolher a tecnologia dos motores (G7). Posso trazer a comparação das opções, com fonte.
2. Confirmar o piloto: Identidade.

## Fontes

- Telegram FAQ, criptografia de cloud chats e chats secretos: https://telegram.org/faq
- Telegram Bot FAQ, bots não veem mensagens de outros bots e limites de envio: https://core.telegram.org/bots/faq
- Telegram Bot Features, modo privacidade e ambiente de teste: https://core.telegram.org/bots/features
- Telegram Bot API, atualizações guardadas no máximo 24 horas: https://core.telegram.org/bots/api
- deleteMessage, limite de 48 horas: documentação do método na Bot API, conferida na reprodução da aiogram, https://docs.aiogram.dev/en/latest/api/methods/delete_message.html. A página oficial veio truncada na leitura.
- Telegram, temporizador de autodestruição em todos os chats (24 horas ou 7 dias), 23/02/2021: https://telegram.org/blog/autodelete-inv2
- Lei 13.709/2018 (LGPD), arts. 5º, III e XI; 12; 13, § 4º; e 33, I e VIII: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
