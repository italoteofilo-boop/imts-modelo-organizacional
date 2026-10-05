# Plano mestre do IMTS.OS: runtime, documentos e projeção externa

Situação em 04/10/2026, depois da auditoria completa pedida às 10:20. Base: o que está no Supabase (projeto rzkfolkqdgtounqjjzss), no motor documental e nas páginas publicadas. Números conferidos no banco no mesmo dia.

## 1. Alvo

Um runtime único que roda o modelo organizacional aprovado (9 círculos, 75 jornadas, 299 etapas, 1.586 tarefas, 411 trocas) para várias empresas do ecossistema, com:

- cada tarefa executada por quem o modelo manda (pessoa, agente, automação, outro círculo, assessoria), com prazo, registro e alçada;
- documentos formais emitidos pelo próprio runtime, com a marca da empresa, gates editoriais e decisão em duas mãos;
- clientes e parceiros acompanhando o que é deles, sem ver nada interno;
- agentes residentes com dono, orçamento, memória editável e trilha;
- administração sem código: conexões, parâmetros, aprovações, saúde e histórico;
- segurança por padrão: serviço só pelo servidor, leitura por empresa e círculo, trilhas que não se apagam.

## 2. Arquitetura

| Camada | O que é | Onde está |
|---|---|---|
| Modelo (`org`) | O modelo aprovado como dado: círculos, jornadas, etapas, tarefas, trocas, alçadas, fontes, decisões | 001 a 004 |
| Runtime dos runtimes (`rt`) | Nove motores (um por círculo) sob uma versão de base comum; instâncias, tokens, eventos, trocas | 003, 005, 014 |
| Mesa de trabalho | Cartões de fluxo, avulsas, delegação a colega ou agente, decisão, aceite | 010 |
| Acesso | Login, papéis, níveis (ler, operar, aprovar, administrar) por empresa e círculo, incompatibilidade de papéis, direitos do titular | 017, 041 |
| Multiempresa | Empresa em instância, cartão e evento; cabeçalho x-empresa conferido; leitura por empresa | 038 |
| Canal de pessoas | Telegram (Bot API), fila de envio com limites, autodestruição, conversa | 019 a 021 |
| Integrações | Adaptadores simulados de ERP, fiscal, bancos e IA, ligados às tarefas | 014 |
| Motor documental (`doc`) | Catálogo de 38 tipos, 10 modelos, 4 marcas; fila e worker (Chromium); gates; duas mãos | 025, documentos/ |
| Administração (`adm`) | 16 conexões, 19 parâmetros, mudanças com duas mãos, histórico, saúde, rotinas | 028, 040 |
| Projeção externa e portal (`ext`) | Regras do que sai, títulos externos, publicações, pedidos, aceites, oportunidades, documentos | 030 |
| Agentes residentes | 3 agentes com modo, orçamento, memória e execução registrada | 033 |
| Segurança | Serviço fail-closed, políticas, trilhas append-only, execução só para service_role | 035, 041 |
| Páginas | Administração, portal externo, biblioteca de documentos, Mesa, painel e cérebro vivo | artefatos publicados |

Decisões de padrão tomadas sem resposta explícita e declaradas: um portal só para o ecossistema, com a marca da empresa dentro; login por link no e-mail em produção (no protótipo, usuário simulado escolhido na página); pilotos simulados, com o parceiro inspirado na rede regional de escritórios da Onni.

## 3. Requisitos do runtime

Cada requisito tem como prova um teste que roda em `select adm.testar_tudo()` (102 testes, nada gravado) ou no `testar_motor.py` (30 testes).

| Área | Requisito | Prova |
|---|---|---|
| Execução | Toda tarefa do modelo ligada a um sistema; motor avança tokens, gera cartões, respeita raias e trocas | runtime 10, motor 9 |
| Mesa | Cartão de fluxo visível a quem lê o círculo; avulsa só ao dono ou a quem recebeu; delegação respeita o modo da etapa | Mesa 12 |
| Acesso | Nível e escopo por empresa e círculo; empresa ou círculo nulos exigem acesso sem restrição nos objetos globais | acesso 10, segurança S9 e S11 |
| Canal | Uma mensagem por segundo por chat, na ordem; nada sensível pelo Telegram; atualização repetida ignorada | Telegram 12, segurança S8 |
| Documentos | Pedido validado; worker com chave; hash conferido; quem pediu não decide; quem analisou não aprova; só externo e aprovado vai para fora | documental 8, motor 30, externo |
| Administração | Validação, duas mãos nos sensíveis, histórico de toda regra que muda o comportamento | administração 10 |
| Externo | Cliente e parceiro veem só a própria organização e o próprio perfil; aceite só de gestor ou fiscal; exclusividade de oportunidade; prazos da administração | externo 10, segurança S10 |
| Agentes | Nada age com a chave geral desligada; orçamento respeitado; rascunho do copiloto só sai aprovado por pessoa | agentes 10 |
| Trilhas | Histórico, eventos de documento, execuções de agente e aprovações não se alteram nem se apagam | segurança |
| Operação | Rotinas agendadas com saúde visível; falha de gatilho registrada sem parar a operação | adm.saude_rotinas, adm.erro |

## 4. Ondas executadas em 04/10/2026

| Onda | Conteúdo | Situação |
|---|---|---|
| 1. Segurança | Serviço fail-closed, políticas de leitura, trilhas append-only, revogação de execução, direitos do titular externo, observabilidade | Feita |
| 2. Motor documental | Gates de conteúdo e de PDF, capa no mesmo PDF, PDF determinístico, worker resiliente, recusa de pedido inválido | Feita |
| 3. Multiempresa e regras | Empresa no runtime; correção das regressões M10 e A9; rodada única de testes; histórico de regras; escopo estrito de acesso; leitura externa por empresa | Feita |
| 4. Documentação | Números atualizados, F02 a F19 aplicados, migrações 025 a 041 documentadas | Feita, menos F01 (aprovação) |
| 5. Páginas | Portal externo ao vivo; administração com agentes e saúde, acessibilidade das abas e do painel; biblioteca reemitida pelo motor novo | Feita |

Incidente registrado: às 11:05 sete suítes de teste foram chamadas sem o envelope que desfaz; os efeitos foram identificados pelo identificador de transação e limpos com aprovação de Ítalo, com os valores anteriores restaurados do histórico. Prevenção: `adm.testar_tudo()` e aviso no LEIA-ME.

## 5. Achados da auditoria e o que foi feito

| Achado | Correção |
|---|---|
| Leitura de cartão mais larga depois da 038 (M10) | Regra de 017 restaurada, dentro da empresa (039) |
| Limites do worker voltavam fixos ao reimplantar a 025 (A9) | `doc._param` lê a administração; fonte única (025) |
| Acesso com empresa ou círculo nulos valia como "qualquer um" | `rt.pode_estrito` na administração global e na decisão de documento (041) |
| Pessoa de uma empresa lia contrapartes de outra no `ext` | `ext._le` pela empresa da contraparte (041) |
| Documento interno podia ser publicado para fora | `ext.publicar_documento` exige alcance externo (030) |
| Portal mostrava notas internas da marca (inferências, razão social a confirmar) | Portal só com nome, cores, logos e tipografia (030, teste S10) |
| Mudança de regra externa, catálogo e agentes sem histórico | Gatilho de histórico (040) |
| Pedidos de documento antigos sem empresa | Empresa pela marca; coluna obrigatória (041) |
| Funções novas nasciam executáveis por public | Privilégio padrão revogado (041) |
| Página de administração sem agentes e saúde; abas sem teclado | Abas Agentes e Saúde, rascunhos para aprovar, memória editável; setas, foco preso no painel |
| Biblioteca com PDFs do motor anterior e contagens antigas | Reemitida; 162 saídas e 127 tarefas ligadas |
| Números e afirmações desatualizados (F02 a F19) | Corrigidos nos documentos (seção 4 do LEIA-ME e revisão) |

## 6. Decisões fechadas em 04/10/2026, às 12:16 ("resolva tudo")

| Tema | Decisão | Onde ficou |
|---|---|---|
| F01, versão de documento | A versão de um documento é a sua data de vigência e de revisão; número de versão não entra; cada emissão é identificada pelo hash do PDF. O modelo aprovado não muda | parametros_em_aberto.md (F01), documentos/LEIA-ME.md, gate do motor |
| Conflitos internos do Editorial Legal.OS | Vale o SKILL.md: anexo abre página; legenda a 5 pt; ajuste de linha curta sem escala dos glifos; cor de texto da marca; margem do modelo; checklist de 1 a 11 | documentos/LEIA-ME.md; atualização do SKILL.md proposta para você salvar |
| Incidente das 11:05 | Registro no histórico da administração (objeto "incidente"); datas e origem dos parâmetros restaurados coerentes | 042_registro_incidente.sql |
| Página de administração duplicada | Apagada | artefatos |
| Alçadas da tabela | As 20 alçadas na tabela, com GE-14, GE-15, margem fora da política, risco 15 ou mais, regra 10 e crise | parametros_em_aberto.md, seção 1 |
| Acessibilidade | Relatório do axe-core 4.10.2 guardado: zero violação em portal, administração, biblioteca, Mesa e painel | acessibilidade_axe.json |

## 7. Ondas E17 a E21, aprovadas em 04/10/2026 ("Prossiga")

| Onda | Entrega | Testes |
|---|---|---|
| E17 Alimentação pelas pastas | Página do acervo: subir arquivos ou ligar uma pasta do Drive; cada arquivo é conferido por hash, lido, classificado e guardado na pasta certa da empresa (uma pasta por empresa, árvore padrão); o que não é reconhecido vai para a triagem; CNPJ, razão social e regime viram proposta com duas mãos; divergências abertas para uma pessoa escolher | 10 |
| E18 Marca e modelos | Manual de marca vira proposta de cores e fontes com duas mãos; modelo de documento vira minuta em blocos, comparada com a anterior (azul incluído, vermelho removido, verde ajustado), aprovada por quem não subiu, emitida pelo motor | 10 |
| E19 Parceiro | Portal: sala de negócio, comissões por situação, prestação de contas (nota e relatório pelo portal, conferência automática), Telegram por código. Central: decidir oportunidade, parcela recebida, aprovar e pagar (pessoas diferentes) | 12 |
| E20 Cliente | Reclamação, ordem de serviço e ouvidoria (Governança, anônima opcional); encaminhamentos datados visíveis ao cliente; encerramento confirmado pelo cliente ou por aceite tácito | 10 |
| E21 Reuniões | Marcar pela Central (Meet pela Agenda Google, verificado com evento real criado e apagado; Zoom, Teams e Webex pelo link até o registro dos apps), consentimento de gravação, transcrição no acervo, ata rascunhada por IA e aprovada por pessoa, encaminhamentos, eliminação da gravação no fim da retenção | 9 |

| E22 Simulação completa e base de produção | Aba Simulação na administração: gerar um ciclo completo pelas funções reais; zerar o movimento simulado (frase de confirmação, em lotes, corte no histórico) e desligar a simulação; religar só sem empresa real. Reuniões: Meet é a plataforma formal (Google Workspace); Zoom, Teams e Webex por convite, com a conta Google | 7 |

Padrões adotados (declarados ao aprovar): uma pasta por empresa no Drive da IMTS com a árvore padrão; ouvidoria com a Governança; regra de comissão simulada por contrato de parceria até a regra real.

Páginas: acervo, portal externo e Central de atendimento, ao vivo pelos conectores de quem abre (Supabase, Google Drive, Agenda Google). Acessibilidade: axe-core 4.10.2 sem violação nas abas novas, em tema claro, escuro e tela de 390 px.

## 8. Backlog só com pendências externas (produção)

| Item | O que falta | Quem |
|---|---|---|
| G1 Empresas | Empresas reais com regime, porte e situação na ANPD; a partir daí instância real sem empresa é recusada | Ítalo |
| G2 Pessoas | Pessoa em cada papel, encarregado de dados por empresa | Ítalo e sócios |
| G6 Ratificação | Ata dos sócios (GO-02) ratificando métodos, regras, alçadas e critérios dos agentes | Sócios |
| G3 Valores | Orçamentos, limites, reservas e preços-base do primeiro ciclo | Estratégia e Gestão |
| G4 Fiscal e folha | Calendário fiscal e de folha por empresa; convenção coletiva | Assessorias |
| G8 Textos | Modelos de contrato e políticas finais; código do contract_engine e do motor de propostas para integrar | Governança, Gestão, jurídico |
| G9 Calibração | Depois de dois ciclos reais | Inteligência e Integração |
| LGPD art. 33 | Base para transferência internacional (provedores fora do Brasil) | Governança e jurídico |
| Telegram | Criar o bot e gravar o token no Vault; rodar `rt.telegram_configurar()` | Ítalo |
| Domínio | Domínio próprio para o portal e o Mini App | Ítalo |
| Login de produção | Construído (P1 e P3): login Google da equipe, link por e-mail para clientes e parceiros, perfil de produção sem `_como` nem simulação. Falta implantar: E05 e E06 do manual | Integração |
| Projeto de produção | Projeto Supabase separado, com PITR e backup confirmados; pg_net fora do esquema public | Integração |
| Worker | Construído (P4): contêiner `documentos/Dockerfile`, testado no ensaio. Falta implantar: E09 do manual | Integração |
| Arquivos | B25 aprovado em 04/10/2026: os PDFs ficam no banco com alerta acima de 2 GB; a ida ao Storage é feita quando o alerta disparar | Integração |
| Sistemas | ERP, emissor fiscal, bancos e provedor de IA no lugar dos adaptadores simulados | Gestão e Integração |
| Assinatura | DocuSign ligado às âncoras /ass_A/, /ass_B/, /ass_T1/, /ass_T2/ | Governança |
| Google Drive | Terceira saída do motor (Google Docs) | Integração |
| Marcas | Fonte Nexa (Onni); manual da TRON; razão social e CNPJ de IMTS e Onni confirmados no contrato social | Ítalo |
| Comissões | Regra real de cada contrato de parceria comercial (percentual, base, parcelas) no lugar da simulada; não há regra no Drive (busca de 04/10/2026). Escritório de advocacia não recebe comissão (decisão de set/2026): é remunerado pela OS-Cliente | Negócios e Gestão |
| Vídeo | Nada a registrar: Zoom, Teams e Webex por participação no convite. Na produção, a agenda do Meet passa da conta Gmail para o Workspace IMTS (conectar o Google Calendar com a conta @imts.email) | Integração e Ítalo |
| Prazos de atendimento | Valores em vigor, mais rigorosos que as referências conferidas (Decreto 11.034/2022, art. 13; Lei 13.460/2017, art. 16); mudar só se a operação pedir | Relações, Operações e Governança |
| Arquivos de fora | Construído (P4): o arquivo do portal vai ao Drive pela função `google`. Falta implantar: E04 do manual | Integração |

Nada fora desta tabela depende de construção no protótipo.

## 9. Ondas P1 a P5: produção (04/10/2026)

Plano, backlog (B01 a B28 internos, E01 a E15 externos) e manual no documento "IMTS.OS · Plano de produção".

| Onda | Entregue | Prova |
|---|---|---|
| P1 Base de produção | Login ligado à pessoa, convite, importação com prévia, porta única, índices, retenção, alertas, perfil de produção | Rodada única 19 de 19 |
| P2 Ensaio e script | Banco vazio com 001 a 068 idêntico ao protótipo; `producao/aplicar.sh` com conferência; homologação do banco | Ensaio local: `internos_ok=true`; homologação 7 de 7 |
| P3 Aplicativo | `app/`: entrada, Mesa, Painel, Central, Acervo, Biblioteca, Administração, Portal, pela porta única | 69 testes de navegador; axe-core sem violação |
| P4 Servidor | Funções google, ia e alertas; worker em contêiner; alerta de armazenamento | 13 testes das funções; imagem construída e PDFs emitidos no ensaio |
| P5 Manual | Manual de implantação, roteiro de homologação por círculo, runbook | Conferido contra o que foi construído |

Achados do ensaio, corrigidos:
- o motor registrava tarefas de máquina como feitas e sorteava decisões em instância real; agora vira cartão de pessoa (motor assistido);
- funções executáveis sem login;
- importação que recusava todo papel sem o cadastro simulado;
- pedido de fora sem pessoa na raia;
- endereço do protótipo escrito no código;
- índices que só existiam no protótipo.

B25 (PDFs no Storage): entregue o alerta de armazenamento. A migração para o Storage fica como proposta: no ensaio, cada documento emitido ocupou cerca de 380 KB no banco (PDF e HTML); o alerta avisa quando o total passar de documentos.limite_mb (2 GB), antes de pesar.
