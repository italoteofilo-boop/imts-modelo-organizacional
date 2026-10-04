# Base de dados do modelo organizacional (Supabase)

Esquema `org`, em Postgres. Guarda o modelo como foi aprovado em 03/10/2026, com as correções da auditoria geral (16:05) e as mudanças aprovadas às 21:05 (GE-14, GE-15, NE-04 e GE-02): os 9 círculos, as 75 jornadas com etapas, tarefas, decisões, entradas e saídas, as trocas entre círculos, as cadeias, as fontes, as decisões registradas, os parâmetros e os gates de implantação.

## Onde está

Projeto Supabase **imts-modelo-organizacional** (código rzkfolkqdgtounqjjzss), na organização IMTS.OS, região São Paulo. Carregado em 03/10/2026 e recarregado às 17h, depois das correções da auditoria geral; as contagens no banco batem com o modelo, e o verificador de segurança do Supabase não aponta nada.

## Arquivos

- `001_esquema.sql`: tipos, tabelas, índices, visões e segurança.
- `002_carga.sql`: a carga, gerada dos arquivos do modelo.
- `carga_compacta.py` e `lotes/`: a mesma carga em 26 lotes, a forma usada para carregar o Supabase.
- `gerar_tipos.py` e `tipos.ts`: os tipos TypeScript do esquema `org`.
- `003_runtime.sql`: fase 2, o runtime dos runtimes (esquema `rt`) e o registro de eventos. Aplicado no Supabase em 03/10/2026, às 18h40.
- `testar_runtime.sql`: 10 testes do runtime dos runtimes, numa transação desfeita no fim. Também rodaram no Supabase: 10 testes, 0 falhas. Seis defeitos plantados foram detectados, um a um.
- `gerar_grafos.py` e `004_grafos.sql`: o grafo executável das 75 jornadas, lido dos fluxos BPMN (2.816 nós, 3.238 fluxos). Cada uma das 1.586 tarefas do BPMN aponta para a tarefa do modelo; a carga para se faltar alguma ou se o nome divergir.
- `005_motor.sql`: os sistemas e o vínculo das 1.586 tarefas (G7), as 61 pessoas simuladas e o motor (`rt.executar_simulada`).
- `006_modelos.sql`: o registro dos modelos de ML (`rt.modelo`), gerado por `ml/treinar.py`.
- `testar_motor.sql` e `007_testes.sql`: 9 testes do motor; o 007 traz os testes do runtime e do motor como funções, para rodar no Supabase sem gravar nada.
- `008_painel.sql`: a função `rt.painel()`, que devolve em JSON tudo o que o painel da operação mostra. Só lê.
- `009_painel_detalhe.sql`: `rt.painel_detalhe(jornada, n)` e `rt.painel_execucao(id)`, o detalhe de jornada, etapa e execução do painel. Só leem.
- `010_mesa.sql`: a Mesa de trabalho (E11). O motor passa a rodar em modo interativo: tarefa de gente vira cartão e decisão de gente vira cartão para decidir. Cartões de fluxo, avulsas e pedidos de ajuda (`rt.cartao`), delegação ao agente com teto no modo da etapa e a colega com aceite, sugestão da jornada existente e quadros (`rt.quadro`, `rt.quadro_circulo`).
- `testar_mesa.sql` e `011_testes_mesa.sql`: 12 testes da Mesa (M1 a M12); o 011 traz a função `rt._testar_mesa()`, para rodar no Supabase sem gravar nada.
- `012_sincronizar_modelo.sql`, `012a_org_novo.sql` e `preparar_versao.py`: migração versionada do modelo. A versão nova é carregada em `org_novo` e `org.sincronizar_modelo()` atualiza `org` no lugar, casando círculo, jornada, etapa, tarefa e troca pela chave natural: os ids que o runtime usa ficam. Se algo que saiu do modelo ainda é usado pelo runtime, para e nada muda.
- `013_grafos_versao.sql` (gerado pelo `gerar_grafos.py`): troca só os grafos das jornadas que mudaram e marca os fluxos de volta (`volta`) e as saídas de decisão que abrem laço (`laco`).
- `014_versao_2.sql`: versão 2026-10-03.2 publicada pelo runtime dos runtimes e aplicada nos nove motores; os oito motores que estavam em desenho passam a piloto (E10); sistemas contábil, fiscal e bancário com adaptador simulado e o contrato de interface (`rt.adaptador_operacao`).
- `015_motor_ajuste.sql`: o teto das voltas passa a valer por laço, não por nó (ponto de junção alcançado por caminhos diferentes travava a ES-01).
- `016_simulacao_continua.sql`: uma execução simulada a cada 5 minutos (pg_cron) e limpeza diária do dado simulado com mais de 30 dias.
- `017_acesso.sql`, `testar_acesso.sql` e `018_testes_acesso.sql`: empresas (quatro simuladas até o G1), login ligado ao pseudônimo, permissões por pessoa, empresa, círculo, papel e nível, papéis incompatíveis barrados, funções do app (`rt.app_*`) e direitos do titular (exportar e eliminar). 10 testes.
- `019_telegram.sql`, `testar_telegram.sql`, `020_testes_telegram.sql`, `021_telegram_agenda.sql` e `functions/telegram/index.ts`: canal Telegram (E5) e conversa (E9). 12 testes.
- `022_simulador.sql`: esquema `sim`, onde o simulador de cenários (E7) deixa as propostas para a ID-04. Nunca escreve no motor.
- `023_modelos_v2.sql`: modelos de ML retreinados com os nove motores (fora de uso).
- `024_painel_ajuste.sql`: `rt.painel()` com execução interativa ainda aberta e só os eventos de execução de tarefa nas medidas.
- `gerar_sql.py`: refaz os dois arquivos a partir de `saida/`, a pasta que os scripts do modelo criam ao rodar (no repositório, a cópia publicada dos dados está em `dados-gerados/`). Rode depois de qualquer mudança no modelo: `python3 supabase/gerar_sql.py`.

## Tabelas

| Tabela | O que guarda | Linhas na carga |
|---|---|---|
| circulo | Os 9 círculos | 9 |
| dominio | Domínios de cada círculo | por círculo |
| jornada | As 75 jornadas, com objetivo, cadência e nível de automação | 75 |
| evento | Eventos de início e de fim de cada jornada | por jornada |
| etapa | As 299 etapas, com dono, modo (Copiloto 143, Autopiloto 64, Assistido 58, Autômato 34), risco e o tipo que as tarefas dão à etapa | 299 |
| tarefa | As 1.586 tarefas, com executor (P, A, R, H, C, X), raia e condição | 1.586 |
| decisao_caminho | As perguntas que decidem o caminho em cada etapa | por etapa |
| entrada, saida | O que cada etapa recebe e entrega, e de quem ou para quem | por etapa |
| troca | As 411 trocas entre círculos | 411 |
| cadeia, cadeia_elo | As 26 cadeias que substituem as jornadas cross, com 47 elos | 26 e 47 |
| fonte, fonte_uso, jornada_fonte | As fontes, o uso de cada uma em cada círculo e em cada jornada | 66 fontes |
| decisao_registrada | As decisões registradas por círculo | 121 |
| limite | Os limites declarados por círculo | por círculo |
| parametro | Alçadas, cadências, conteúdos e fontes, com o valor aprovado | 72 |
| gate | Os 9 gates de implantação, com a situação | 9 |
| achado_auditoria | Os apontamentos que ficaram da auditoria de execução | 52 |
| empresa, pessoa, atribuicao | Implantação: nascem vazias e são preenchidas nos gates G1 e G2 | 0 |

Visões: `v_etapa` (tarefas de pessoa e de máquina em cada etapa) e `v_jornada` (etapas, tarefas e percentual de máquina em cada jornada).

## Segurança

- A segurança por linha (RLS) está ligada em todas as tabelas.
- Usuário autenticado só lê.
- Só o papel de serviço escreve.
- O papel anônimo não tem acesso.

Uma aplicação que precise escrever, como o cadastro de empresas e pessoas, ganha uma política própria quando for criada.

## Conferência

Testado em 03/10/2026 em Postgres 16 local, antes de cada carga no Supabase. As contagens da carga batem com o modelo. Números atuais (04/10/2026):

| Item | Contagem |
|---|---|
| Círculos | 9 |
| Jornadas | 75 |
| Etapas | 299 |
| Tarefas | 1.586 |
| Trocas entre círculos | 411 |
| Cadeias e elos | 26 e 47 |
| Parâmetros | 72 (14 alçadas, 39 cadências, 15 conteúdos, 4 fontes) |
| Gates | 9 |

## Para as aplicações lerem

O esquema `org` está liberado na API do projeto desde 03/10/2026. O acesso anônimo é recusado (conferido: "permission denied for schema org"); usuário autenticado lê.

Tipos TypeScript: `tipos.ts`, gerado por `gerar_tipos.py` a partir do `001_esquema.sql` (o gerador do Supabase só cobre o esquema `public`). Uso: `createClient<Database>(url, chave, { db: { schema: 'org' } })`. Os tipos passaram no `tsc --strict`.

## Runtime dos runtimes (esquema rt, fase 2)

Plano de controle acima dos nove motores. Decisões de 03/10/2026, 18:34: motores próprios sobre o Supabase; piloto Identidade; para uso real do Telegram, consentimento do art. 33, VIII, da LGPD.

| Peça | O que faz |
|---|---|
| `rt.motor` | Os nove motores, um por círculo. Os nove estão em piloto desde a 014 |
| `rt.config` | O que customiza cada motor: jornadas, raias, limites e regras do Telegram, lidos do esquema `org` |
| `rt.versao_base`, `rt.atualizacao`, `rt.publicar_versao`, `rt.concluir_atualizacao` | Uma correção comum vira versão. Cada motor só a aplica com os testes do seu círculo verdes; com teste vermelho, a atualização é recusada e o motor fica na versão anterior |
| `rt.troca_envio`, `rt.enviar_troca`, `rt.v_rota_troca` | Leva cada uma das 411 trocas ao motor que a recebe |
| `rt.rota_chat`, `rt.mensagem`, `rt.receber_mensagem`, `rt.v_a_apagar` | Porta única do Telegram: grava toda mensagem e a entrega ao motor do chat. A autodestruição tem prazo máximo de 47 horas, porque o bot só apaga mensagens com menos de 48 horas |
| `rt.evento` | Registro de eventos (E1), com a marca simulado ou real obrigatória |
| `rt.pessoa` e `rt_chave.identidade` | O motor vê só o pseudônimo; o nome e o Telegram ficam em `rt_chave`, que só o service_role lê. Pessoa real no Telegram sem consentimento registrado é recusada |

O verificador do Supabase aponta, como informação, que `rt_chave.identidade` tem RLS sem política. É de propósito: só o service_role, que ignora o RLS, pode ler essa tabela.

## Motor (fase 2)

| Peça | O que faz |
|---|---|
| `rt.no`, `rt.fluxo` | O grafo de cada jornada, lido do BPMN |
| `rt.sistema`, `rt.vinculo` | Nove sistemas: canal das pessoas (P, H), agentes de IA (A), automações (R), trocas entre círculos (C), canal das assessorias (X), contábil, fiscal, bancário (014) e o `motor-documental`. As 1.586 tarefas estão ligadas, por enquanto com adaptador simulado |
| `rt.pessoa` | 61 pessoas simuladas: uma por papel, e os papéis genéricos (líder do círculo, pessoa, líder da equipe, solicitante) um por círculo |
| `rt.executar_simulada` | Roda uma instância de ponta a ponta. Sorteia as decisões; uma volta fica menos provável a cada visita e é cortada na terceira; ramos paralelos rodam em sequência no relógio simulado; entrega as trocas ao motor do outro círculo |
| `rt.parametro_simulacao` | Tempo de cada executor, de A (2 a 20 minutos) a X (1 a 5 dias). São hipóteses do protótipo, a calibrar no G9 |
| `rt.instancia`, `rt.evento` | Cada execução e cada passo, marcados como simulados |
| `rt.v_cobertura` | Quantas tarefas de cada motor já rodaram |

No Supabase, em 03/10/2026, rodaram 2.000 instâncias simuladas da Identidade (400 por jornada). Resultado: 2.000 concluídas, 52.042 eventos, 19.071 trocas entregues e 99 de 99 tarefas da Identidade executadas. Testes: 10 do runtime e 9 do motor sem falha, no Postgres 16 local e no Supabase. Seis defeitos plantados no motor foram detectados.

Relógio simulado: as instâncias simuladas correm num relógio próprio, à frente do relógio real. Por isso `inicio` e `fim` de `rt.instancia` podem estar no futuro (até 2027). A limpeza do dado simulado e os painéis por data contam por esse relógio simulado. Para instância simulada, `ext.projetar` usa `criado_em`, a hora em que o evento foi gravado.

## Mesa de trabalho (fase 2, E11)

| Peça | O que faz |
|---|---|
| `rt.iniciar_jornada` | Inicia uma execução interativa. Recusa motor em desenho |
| `rt.cartao`, `rt.token` | Cartões (fluxo, avulsa, ajuda) em cinco colunas: a fazer, fazendo, esperando, decidir, feito. Toda tarefa tem dono e prazo |
| `rt.concluir_cartao`, `rt.decidir_cartao` | Só quem é dono ou recebeu age. Ao concluir ou decidir, o motor segue o fluxo |
| `rt.mover_cartao` | Cartão de fluxo só vai de a fazer a fazendo e volta; não vai a feito nem a decidir arrastado |
| `rt.criar_avulsa` | Avulsa ou pedido de ajuda ligado a um cartão |
| `rt.delegar_cartao`, `rt.responder_delegacao` | Ao agente, até o modo da etapa (avulsa até "fazer e você aprova"); a colega, com aceite; tarefa de fluxo só na mesma raia, salvo o líder |
| `rt.sugerir_jornada`, `rt.v_avulsas_recorrentes` | A captura sugere a jornada que já existe; avulsa repetida três vezes em 30 dias vira sinal para a ID-04 |
| `rt.quadro`, `rt.quadro_circulo`, `rt.mesa_pessoas` | Meu quadro; quadro do círculo com só os cartões de fluxo e a carga em números; pessoas por pseudônimo |

Avulsas e pedidos de ajuda não saem pela API: a política de leitura de `rt.cartao` só libera cartões de fluxo. Testes: 12 da Mesa sem falha, no Postgres 16 local e no Supabase.

O verificador de desempenho aponta, como informação, chaves estrangeiras sem índice e índices ainda sem uso. Fica para quando houver volume real.

## Versão 2026-10-03.2 (03/10/2026, 21:05)

| Medida | Antes | Agora |
|---|---|---|
| Jornadas, etapas, tarefas, trocas | 73, 292, 1.555, 410 | 75, 299, 1.586, 411 |
| Motores em piloto | 1 (Identidade) | 9 |
| Tarefas executadas pela simulação | 99 (Identidade) | 1.586 de 1.586 |
| Testes no Supabase | 31 | 53 (runtime 10, motor 9, Mesa 12, Telegram 12, acesso 10) |

Como subir uma versão nova do modelo: rode os testes do modelo (`python3 testar.py`), `python3 supabase/gerar_sql.py`, `python3 supabase/preparar_versao.py` e `python3 supabase/gerar_grafos.py`; carregue `012a_org_novo.sql`; rode `select org.sincronizar_modelo();`; apague `org_novo`; rode `013_grafos_versao.sql`; publique a versão com `rt.publicar_versao` e conclua a atualização de cada motor com `rt.concluir_atualizacao`.

## Canal Telegram (E5) e conversa (E9)

| Peça | O que faz |
|---|---|
| Edge Function `telegram` | Recebe o webhook (confere o cabeçalho secreto), entrega a `rt.receber_update`, responde ao botão e esvazia a fila. Com `?tarefa=` e a chave das tarefas: `estado`, `manutencao` (fila e autodestruição) e `configurar` (webhook e comandos) |
| `rt.receber_update` | Identifica a pessoa pelo id do Telegram, liga a conversa ao motor, grava a mensagem com autodestruição (47 horas pela configuração do motor) e põe a resposta na fila |
| `rt.interpretar` | /quadro, /concluir, /decidir, /aceitar, /recusar, /nova, /iniciar, botões e texto livre (procura a jornada que já existe antes de criar avulsa) |
| `rt.proximos_envios`, `rt.confirmar_envio` | Fila com os limites do Telegram: 1 por segundo por chat, 20 por minuto por grupo, 30 por segundo no total |
| Fora do Telegram | Senha ou chave no texto: a mensagem é apagada; aprovação de pagamento (GE-04, GE-05): só na Mesa |
| Vault | `telegram_webhook_segredo` e `imts_funcao_chave` gerados dentro da base; `telegram_ambiente` = teste. Falta `telegram_bot_token` |
| pg_cron | `imts-telegram-manutencao` a cada 10 minutos |

Para ligar o bot de teste, no editor SQL do Supabase:
```sql
select vault.create_secret('<token do BotFather>', 'telegram_bot_token');
select rt.telegram_configurar();
```

O verificador de segurança aponta o pg_net no esquema public (aviso): a troca para o esquema extensions pede apagar e recriar a extensão, e ficou para quando houver janela. As fontes novas já criam no esquema certo.

A Edge Function `teste-html` foi o teste de hospedagem do Mini App (03/10/2026): o Supabase devolveu `text/plain` para HTML no domínio padrão. Ela responde 410 e pode ser apagada no painel do Supabase.

## Motor documental (E12, esquema doc)

| Peça | O que faz |
|---|---|
| `doc.tipo`, `doc.tipo_tarefa` | Os 38 tipos de documento e a ligação com 106 tarefas do modelo (redige, revisa, emite, assina) |
| `doc.marca`, `doc.modelo` | Os pacotes de marca (IMTS, Onni, TRON provisória, neutra) e os dez modelos de design |
| `doc.pedir` | Põe o pedido na fila. Recusa tipo fora do catálogo, marca provisória em documento externo e conteúdo sem título, data ou local. Pelo app exige acesso de operar na empresa |
| `public.doc_worker_proximo`, `doc_worker_registrar`, `doc_worker_falhar` | Entrada do worker, protegida pela chave `doc_worker_chave` do Vault. Registra a emissão só com o hash do PDF conferido. Depois do limite de tentativas, o pedido para em erro |
| `doc.decidir` | Análise crítica e aprovação em duas mãos: quem pediu não decide, quem analisou não aprova, alerta mantido exige justificativa e emissão bloqueada não se submete |
| `doc.destravar` | Devolve à fila o pedido preso em emissão (cron de 30 em 30 minutos) |
| `doc.arquivo` | PDF e HTML em bytea no protótipo; em produção vão para o Storage |

O verificador de segurança do Supabase aponta as três funções `public.doc_worker_*` como chamáveis sem login. Isso é de propósito: sem a chave `doc_worker_chave` do Vault elas recusam. Em produção, com o worker usando credencial de serviço, essa entrada pública pode sair.

As automações que publicam, emitem, respondem ou enviam proposta (21 tarefas) usam o sistema `motor-documental`. O teste T1 do motor aceita esse sistema (027).

## Administração geral (E13, esquema adm)

| Peça | O que faz |
|---|---|
| `adm.conexao` | Registro único das conexões externas: ambiente, endpoint, dono, estado, saúde e só o nome do segredo no Vault (a base recusa o que parece valor) |
| `adm.parametro` | Os parâmetros com escopo, tipo, validação, padrão, fonte e destino (`rt.config`, `rt.parametro_simulacao`, agenda do pg_cron) |
| `adm.alterar_parametro` | Valida, exige motivo, aplica e propaga. Se o parâmetro é sensível, abre uma mudança pendente |
| `adm.decidir_mudanca` | Aprova (aplica e propaga) ou recusa (com motivo), sempre por outra pessoa |
| `adm.alterar_conexao` | Muda só os campos de cadastro; o alvo da verificação muda por migração |
| `adm.verificar_conexoes` | SQL e Vault na hora; HTTP pelo pg_net, colhido na rodada seguinte. Roda no cron `imts-adm-verificacao` |
| `adm.painel` | O que a página de administração lê, sem alvo SQL e sem valor de segredo |
| `adm.historico` | Antes, depois, quem, como e por quê de cada alteração |

Sem login, o serviço informa como quem atua (`p_como`): é o protótipo da página via MCP, com os administradores simulados. Em produção vale o login de cada pessoa.

Achado resolvido: `rt.config` tinha duas chaves para a autodestruição. A que o código lê é `autodestruicao_horas` (47). A chave antiga `telegram` (com 24) não era lida por nada. Ítalo aprovou apagá-la em 04/10/2026, às 10:13, e a migração `031_config_legado.sql` a apagou.

## Testes

```sql
do $$ begin raise exception '%', rt._testar_runtime() || ' | ' || rt._testar_motor() || ' | ' || rt._testar_mesa() || ' | ' || rt._testar_telegram() || ' | ' || rt._testar_acesso(); end $$;
do $$ begin raise exception '%', doc._testar_documental(); end $$;
do $$ begin raise exception '%', adm._testar_administracao(); end $$;
```
Cada chamada desfaz tudo. O documental e a administração rodam separados, porque também criam login para as mesmas pessoas simuladas.

Desde a 039, `select adm.testar_tudo();` roda as 10 suítes de uma vez. Veja a seção seguinte.

## Migrações 025 a 042 (motor documental, administração, portal externo, agentes, segurança)

| Arquivo | O que faz |
|---|---|
| `025_motor_documental.sql` | Gerado por `documentos/gerar_sql.py` a partir de `documentos/doc_funcoes.sql`. Cria o esquema `doc`: tipo, modelo, marca, tipo_tarefa, pedido, emissao, arquivo, aprovacao e evento. Fila com worker. `doc.pedir` exige empresa. O registro confere o hash do PDF e do HTML. Duas mãos: análise crítica e aprovação; quem pediu não decide e quem analisou não aprova. Os limites do worker vêm da administração por `doc._param` (`documental.tentativas_maximas` e `documental.destravar_minutos`) |
| `026_testes_documental.sql` | 8 testes do motor documental |
| `027_teste_motor_documental.sql` | Teste ponta a ponta do motor documental |
| `028_administracao.sql` | Esquema `adm`: conexão, parâmetro, mudança (duas mãos nos parâmetros sensíveis), histórico e verificação de saúde |
| `029_testes_administracao.sql` | 10 testes da administração |
| `030_externo.sql` | Esquema `ext`, a projeção externa e o portal: empresa_marca, contraparte, usuario, regra (a lista do que sai para fora), jornada_externa (os títulos externos), vinculo, publicacao, documento, pedido e oportunidade |
| `031_config_legado.sql` | Apaga a chave legada `telegram` de `rt.config` (aprovado por Ítalo em 04/10/2026, às 10:13) |
| `032_testes_externo.sql` | 10 testes do portal externo |
| `033_agentes_residentes.sql` | `rt.agente_residente`, `rt.agente_memoria` e `rt.agente_execucao`. Modos Assistido, Copiloto e Autopiloto. Orçamento de ações por mês. Chave geral `agentes.ligados`. O rascunho do copiloto só sai com aprovação de uma pessoa (`rt.agente_aprovar_rascunho`). Três agentes: o guardião de prazos de Operações, o vigia de vencimentos e o atendente do portal externo |
| `034_testes_agentes.sql` | 10 testes dos agentes |
| `035_seguranca.sql` | `rt.chamada_servico` (fecha em caso de falha) e `rt.interno`. Políticas de leitura só para quem é de dentro. Trilhas só de acréscimo: `adm.historico`, `doc.evento`, `rt.agente_execucao` e `doc.aprovacao`. Update do Telegram repetido é descartado. Direitos do titular externo (`ext.exportar_usuario` e `ext.eliminar_usuario`). `adm.saude_rotinas`. Execução das funções só para o service_role |
| `036_testes_seguranca.sql` | 11 testes de segurança |
| `037_ajustes_dados.sql` | Ajuste de datas simuladas que estavam no futuro |
| `038_multiempresa.sql` | Empresa na instância, no cartão e no evento. O cabeçalho `x-empresa` é conferido. Leitura por empresa. Vínculo externo só na mesma empresa |
| `039_correcao_regressoes.sql` | O cartão volta à regra da 017, dentro da empresa. `adm.testar_tudo()` roda as 10 suítes sem gravar nada |
| `040_versao_regras.sql` | Mudanças em `ext.regra`, `ext.jornada_externa`, `doc.tipo` e na configuração dos agentes ficam no histórico |
| `041_escopo_acesso.sql` | `rt.pode_estrito`: empresa ou círculo nulos exigem acesso sem restrição. Vale na administração global e na decisão de documento (pelo círculo da tarefa). O `ext` é lido pela empresa da contraparte (`ext._le`). Funções novas nascem sem execução para public. `doc.pedido.empresa` passa a ser obrigatório |
| `042_registro_incidente.sql` | Registro do incidente de 04/10/2026, 11:05, no `adm.historico` (objeto `incidente`): causa, efeitos, limpeza, o que não teve recuperação e a prevenção. Datas e origem dos parâmetros restaurados coerentes com o valor de antes. |

Prazos do portal externo, em `adm.parametro`: resposta em 48 horas, aceite em 24 horas, pedido do titular em 15 dias (LGPD, art. 19, II) e exclusividade de 90 dias. Só vai para fora documento de alcance externo e aprovado. Da marca, o portal mostra só nome, cores, logos e tipografia.

## Migrações 043 a 052 (alimentação pelas pastas, parceiros, clientes e reuniões)

| Arquivo | O que faz |
|---|---|
| `043_acervo.sql` | E17. Esquema `acervo`: árvore padrão de pastas por empresa no Drive (00 a 09 e 99 Triagem), 14 tipos de documento com regra de reconhecimento, registro de cada arquivo por hash (o mesmo arquivo não entra duas vezes), versão por número ou por tipo, extração de CNPJ (com dígito verificador), razão social e regime. Dado sensível da empresa só vale com duas pessoas diferentes; valores diferentes abrem divergência e uma pessoa escolhe com motivo |
| `044_testes_acervo.sql` | 10 testes do acervo |
| `045_marca_modelos.sql` | E18. Manual de marca vira proposta de cores e fontes; duas pessoas escolhem os papéis (a segunda não muda o que a primeira escolheu). Modelo de documento vira minuta em blocos; aprova quem não subiu; a aprovada substitui a anterior do mesmo tipo e emite pelo motor. CNPJ e razão social aprovados entram no pacote de marca |
| `046_testes_marca_modelos.sql` | 10 testes de marca e minutas |
| `047_parceiro.sql` | E19. Contrato de parceria (regra de comissão, no protótipo SIMULADA: 10% sobre o recebido), sala de negócio por oportunidade, carteira de comissões (prevista, adquirida, a pagar, paga), prestação de contas com conferência da nota (CNPJ do parceiro, número único, valor igual às comissões), aprovação por uma pessoa e pagamento por outra, Telegram de quem é de fora por código de uso único. Cartões de pedidos de fora passam a levar a empresa |
| `048_testes_parceiro.sql` | 12 testes do parceiro |
| `049_atendimento.sql` | E20. Reclamação, ordem de serviço e ouvidoria (Governança, pode ser anônima; dentro só a Governança lê, fora só quem escreveu). Encaminhamentos com responsável e prazo, que o cliente vê com as datas. Encerrar: a equipe propõe com tudo fechado; o cliente confirma (com nota) ou reabre; sem resposta, aceite tácito pela rotina `imts-atendimento-tacito` |
| `050_testes_atendimento.sql` | 10 testes do atendimento |
| `051_reunioes.sql` | E21. Reunião com contrato comum de adaptador (`ext.reuniao_registrar_externa`, `ext.reuniao_transcricao`); Meet pela Agenda Google; Zoom, Teams e Webex como conexões pendentes. Gravação só com consentimento registrado; transcrição no acervo (pasta 09); ata rascunhada por IA ou pessoa, válida só aprovada por pessoa; a aprovação cria os encaminhamentos. Retenção da gravação por parâmetro |
| `052_testes_reunioes.sql` | 8 testes das reuniões |

Parâmetros novos: `parceiro.prazo_aprovacao_horas` (48), `parceiro.prazo_pagamento_dias` (10), `parceiro.codigo_telegram_minutos` (15), `atendimento.aceite_tacito_dias` (5), `atendimento.prazo_os_horas` (72), `atendimento.prazo_ouvidoria_dias` (10), `reuniao.retencao_gravacao_dias` (90), `reuniao.prazo_encaminhamento_dias` (7). Os valores são de partida, a confirmar pelos círculos indicados na coluna fonte.

### Ordem de implantação

001 a 024, depois 025 → 026 → 027 → 028 → 029 → 030 → 031 → 032 → 033 → 034 → 035 → 036 → 037 → 038 → 039 → 040 → 041 → 042 → 043 → 044 → 045 → 046 → 047 → 048 → 049 → 050 → 051 → 052.

Se reimplantar algum arquivo anterior, reaplique a 035 depois. Ela revoga a execução das funções e troca as políticas.

### Testes

```sql
select adm.testar_tudo();
```

Roda as 15 suítes, cada uma numa subtransação desfeita: runtime 10, motor 9, Mesa 12, acesso 10, Telegram 12, documental 8, administração 10, externo 10, agentes 10, segurança 11, acervo 10, marca e minutas 10, parceiro 12, atendimento 10 e reuniões 8. Total: 152 testes.

> **Aviso.** Nunca chame as funções `_testar_*` com `select` direto. Assim elas gravam os efeitos no banco. Isso aconteceu em 04/10/2026 e foi limpo no mesmo dia. Para rodar uma suíte sozinha, use sempre o bloco que desfaz tudo:
>
> ```sql
> do $$ begin raise exception '%', rt._testar_mesa(); end $$;
> ```

Motor local: `python3 documentos/testar_motor.py` (30 testes).

### Rotinas (pg_cron)

| Rotina | Agenda |
|---|---|
| `imts-simulacao-continua` | `*/5 * * * *` |
| `imts-limpeza-simulado` | `17 3 * * *` |
| `imts-telegram-manutencao` | `*/10 * * * *` |
| `imts-adm-verificacao` | `*/30 * * * *` (também destrava a fila de documentos) |
| `imts-externo-simulado` | `*/10 * * * *` |
| `imts-agentes` | `*/5 * * * *` |
| `imts-limpeza-updates` | `41 3 * * *` |

### Números vivos (04/10/2026)

| Item | Quantidade |
|---|---|
| Parâmetros da administração | 19 |
| Conexões | 16 |
| Tipos de documento | 38 |
| Modelos de design | 10 |
| Marcas | 4 |
| Ligações tipo × tarefa | 127 |
| Contrapartes simuladas | 4 |
| Usuários externos simulados | 7 |
| Regras de projeção | 51 |
| Títulos externos | 8 |
| Agentes | 3 |
| Empresas simuladas | 4 |
