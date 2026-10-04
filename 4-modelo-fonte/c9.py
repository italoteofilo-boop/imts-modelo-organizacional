# -*- coding: utf-8 -*-
"""Círculo 9 · Governança. Fechado em 03/10/2026, aprovado às 11:50: dez jornadas.
Regra do círculo: a Governança decide o que é do seu ofício (a redação e a publicação das regras, a revisão jurídica, a
guarda dos contratos, a amostra e o julgamento da auditoria, a resposta ao titular de dados e a comunicação à autoridade),
dentro da alçada. Os sócios decidem as regras gerais, as alçadas dos executivos e o que a lei reserva a eles; o
dono da crise (executivo, Administrador do IMTS.OS ou sócios) decide a crise, com o comitê conduzido pela Governança; os círculos donos executam e corrigem."""
from dsl import configurar, T, PAR, S, D, E, I, F, TODOS

NUM, NOME, SIGLA, PREF = 9, 'Governança', 'GO', 'GO'
LANES, PARTES = configurar(NOME, SIGLA, PREF)
SLUG = 'circulo9-governanca'
FECHADO = True
STATUS = 'Fechado em 03/10/2026, aprovado às 11:50 · auditoria de execução aplicada em 03/10/2026'
LEAD = ('A Governança faz o Ecossistema decidir bem e dentro das regras. Mantém as regras, as políticas e as alçadas de '
        'pessoas e agentes, secretaria as decisões dos sócios, gere riscos, conformidade e controles, mantém as '
        'obrigações legais e os contratos em dia, audita as entregas de pessoas e agentes, responde aos titulares de '
        'dados, conduz o comitê de crise, recebe relatos, comunica às autoridades e publica o relato de impacto. Não '
        'executa a rotina nem escolhe o rumo. São dez jornadas.')
PRINCIPIO = ('Regra do círculo, aprovada por você às 11:50 de 03/10/2026: a Governança decide o que é do seu ofício '
             '(a redação e a publicação das regras, a revisão jurídica, a guarda dos contratos, a amostra e o julgamento da '
             'auditoria, a resposta ao titular de dados e a comunicação à autoridade), dentro da alçada. Os sócios decidem '
             'as regras gerais, as alçadas dos executivos e o que a lei reserva a eles; o dono da crise (executivo, '
             'Administrador do IMTS.OS ou sócios) decide a crise, com o comitê conduzido pela Governança; os círculos donos executam e corrigem.')
MUDOU_INTRO = ('Comparação com o catálogo da rodada 2 (49 jornadas e 216 workflows), que continua no documento do '
               'projeto até cada círculo ser fechado. Azul: acrescentado. Verde: ajustado. Vermelho: retirado.')
COBERTURA_TXT = ('Processos do APQC PCF 7.4 ligados às funções da Governança (categoria 11.0, grupos 12.3 e 12.4 e o '
                 'grupo 9.8), grupo a grupo: onde cada um está neste modelo. Os nomes estão como no referencial.')

P, A, R = 'GOP', 'GOA', 'GOR'

# produtos da Governança esperados pelos círculos fechados (nomes exatos)
ALCADAS = 'Regras e alçadas vigentes'
SIGILO = 'Regras de sigilo e de dados pessoais'
GUARDA = 'Regras de guarda e de eliminação de dados'
RATEIO_CRIT = 'Critério de rateio do custo dos círculos'
MODELOS = 'Modelos de proposta e de contrato'
CERTIDOES = 'Certidões e documentos de habilitação em dia'
RELATORIO = 'Relatório de riscos e conformidade'
AMOSTRA = 'Amostra de entregas de pessoas e agentes'
RES_AUDIT = 'Resultado da auditoria das entregas'
AMBIGUO = 'Padrão ambíguo apontado pela auditoria'
DESVIO_AG = 'Desvio de agente apontado pela auditoria'
LICOES_CRISE = 'Lições da crise'
DECL_CRISE = 'Declaração, posição e encerramento da crise decididos pelo comitê'
TITULAR_RESP = 'Pedido de titular, com a resposta decidida pela Governança'
# produtos internos usados em mais de uma jornada
REGRA_REVER = 'Regra a criar ou rever, com a causa'
CONTRATOS_REG = 'Contratos com vencimento e obrigações'
OBRIG_LEGAIS = 'Obrigações legais em dia ou vencendo'
RELATOS = 'Relatos tratados, com a causa'
REG_TITULARES = 'Registro de pedidos de titulares'
# produtos de outros círculos
CRITERIOS = 'Critérios de auditoria e casos de teste'
DEC_REG_ID = 'Decisão dos sócios registrada'
DEC_CRIT = 'Decisão dos sócios sobre critérios e limites'
IMPACTO_DEF = 'Definição do que conta como impacto'
LACUNAS_EXEC = 'Lacunas de execução apontadas'
MARCA_RET = 'Marca retirada de uso'
REGISTRO_MARCA = 'Pedido de registro depositado e prazos'
POSIC = 'Posicionamento e casa de mensagens vigentes'
PROTOCOLO = 'Protocolo de crise'
USO_MARCA = 'Regra de uso da marca por terceiros'
RESUMO_PAD = 'Resumo da avaliação dos padrões'
PADROES_ID = 'Padrões de identidade vigentes'
AUTORIZ = 'Autorização dos sócios para negociar, com os limites'
ARQUIVADO = 'Caso arquivado, com o motivo'
CONTR_CV = 'Contrato de compra ou venda assinado'
DEC_ALOC = 'Decisão de alocação e de destino do resultado'
DEC_PORTAO = 'Decisão do portão'
DEC_EMPRESA = 'Decisão dos sócios sobre a empresa'
DEC_ESTRAT = 'Decisão dos sócios sobre a estratégia'
DEC_SOCIOS = 'Decisão dos sócios sobre alvos e orçamento'
DIAG = 'Diagnóstico e decisão de manter a estratégia'
MANDATO = 'Mandato da empresa'
METODO_EST = 'Método de estratégia vigente: critérios dos portões, regras de realocação e calendário'
PORTFOLIO = 'Portfólio de empresas atualizado'
REV_EST = 'Resultado da revisão da estratégia'
CAT_DADOS = 'Catálogo de dados, com dono e classificação de cada dado'
DADO_RET = 'Dado retirado do catálogo de dados'
DADO_OK = 'Dado confiável publicado no catálogo de dados'
PAINEL = 'Painel de indicadores de cada círculo, com dono e análise'
ALERTA_CRISE = 'Alerta de crise, com os fatos apurados'
AUT_MARCA = 'Autorizações de uso da marca por terceiros, com prazo'
TITULAR_OK = 'Pedido do titular cumprido, com a data'
ACORDO_CONJ = 'Acordo de oferta conjunta entre as empresas'
CONTRATO_NEG = 'Contrato para conferir e guardar'
AG_SUSPENSO = 'Agente suspenso, com o motivo'
CONTRATO_TEC = 'Contrato de tecnologia para guardar'
PLANO_LANC = 'Plano de lançamento da oferta'
SAIDA_CLI = 'Plano de saída de clientes e contratos'
REG_ENTREGAS = 'Registros de entregas de pessoas e agentes'
AUTORIDADE = 'Incidente ou risco a comunicar à autoridade'
REL_RECALL = 'Relatórios do recall para a autoridade'
APORTES = 'Aportes, distribuição ou mudanças de contas executados'
CONTESTACAO = 'Contestação do critério de rateio'
CONTRATO_FORN = 'Contrato de fornecedor para revisar e guardar'
DEMONSTRACOES = 'Demonstrações e obrigações fiscais do período'

JORNADAS = []

# ========================================================== REGRAS E DECISÕES
JORNADAS.append(dict(
    code='GO-01',
    nome='Manter as regras, as políticas e as alçadas de pessoas e agentes',
    dominio='Regras e decisões', classe='essencial', onda=1,
    objetivo='Fazer cada regra, política, alçada de pessoa ou de agente, regra de sigilo e de dados pessoais, regra de guarda, critério de rateio e modelo de proposta e de contrato nascer de um pedido, de uma decisão dos sócios ou de uma causa achada pela conformidade; ser redigida ouvidos os donos e, no rateio, a Estratégia; ser decidida pela Governança, dentro da sua alçada, ou pelos sócios; e ser publicada, versionada, a quem a usa. A Governança redige e publica; os sócios decidem as regras gerais e as alçadas dos executivos.',
    frequencia='Por evento: pedido, decisão dos sócios, mudança no catálogo de dados, contestação ou causa achada pela conformidade; e a cada revisão periódica (cadência: anual, e por evento)',
    automacao=('média', 'Registrar, levantar o que vale, redigir, versionar e publicar são de agente e automação; revisar o risco jurídico e decidir dentro da alçada são de pessoa da Governança; as regras gerais, dos sócios.'),
    base=['apqc', 'lgpd'],
    lanes=['SOL', 'SOC', 'EST', P, A, R],
    inicios=[I('Regra, alçada, critério ou modelo pedido', 'SOL', 'message'),
             I('Revisão periódica das regras iniciada', R, 'timer'),
             I('Decisão dos sócios ou causa da conformidade recebida', R, 'message')],
    fins=[F('Regras vigentes publicadas', R),
          F('Regra mantida, com o motivo avisado a quem pediu', R)],
    etapas=[
        E('Receber o pedido e levantar o que vale', 'Governança', 'Autopiloto', 'baixo',
          [('Pedido de regra, de alçada ou de modelo', 'Solicitante'), (DEC_CRIT, 'Identidade'), (USO_MARCA, 'Identidade'),
           (DEC_ESTRAT, 'Estratégia'), (METODO_EST, 'Estratégia'), (PORTFOLIO, 'Estratégia'), (CAT_DADOS, 'Inteligência'),
           (DADO_RET, 'Inteligência'), (CONTESTACAO, 'Gestão'), (REGRA_REVER, 'GO-03')],
          [T('Registrar o pedido e as regras, as alçadas e os modelos afetados', R),
           T('Levantar a lei, os contratos e as decisões dos sócios que valem', A)],
          [('Pedido de regra analisado', ['etapa 2'])]),
        E('Redigir e decidir a regra', 'Governança, pela lista de matérias; as regras gerais, as alçadas dos executivos e as da própria Governança, os sócios', 'Copiloto', 'médio',
          [('Pedido de regra analisado', 'etapa 1')],
          [T('Redigir a regra, a alçada, o critério ou o modelo, ouvidos os donos', A),
           T('Revisar a redação e o risco jurídico', P),
           D('Quem decide, pela lista de matérias aprovada pelos sócios?', R,
             [S('A Governança: regra que aplica regra geral aprovada, modelo de proposta ou de contrato, sigilo, dados e guarda, alçada de pessoas de outro círculo, matriz no apetite ou amostra', 'seg',
                via=[T('Decidir a regra dentro da alçada da Governança', P)]),
              S('A Governança, com a Estratégia: critério de rateio', 'seg',
                via=[T('Definir o critério de rateio com a Governança', 'EST'),
                     T('Decidir o critério de rateio', P)]),
              S('Os sócios: regra geral, alçada dos executivos, exceção, alçada da Governança ou das pessoas da Governança', 'seg',
                via=[T('Levar a regra à decisão dos sócios', P),
                     T('Decidir a regra', 'SOC')])]),
           D('A regra foi aprovada?', P,
             [S('Sim', 'prox'),
              S('Não', 'F2', via=[T('Manter a regra vigente e avisar quem pediu, com o motivo', R)])])],
          [('Regra decidida', ['etapa 3'])]),
        E('Publicar as regras vigentes', 'Governança', 'Autômato', 'baixo',
          [('Regra decidida', 'etapa 2')],
          [T('Versionar e publicar as regras, as alçadas, os critérios e os modelos', R),
           T('Avisar os donos do que mudou', R)],
          [(ALCADAS, [TODOS]),
           (SIGILO, [TODOS]),
           (GUARDA, ['Inteligência']),
           (RATEIO_CRIT, ['Gestão']),
           (MODELOS, ['Negócios'])]),
    ]))

JORNADAS.append(dict(
    code='GO-02',
    nome='Secretariar as decisões dos sócios e cumprir os atos societários',
    dominio='Regras e decisões', classe='essencial', onda=1,
    objetivo='Fazer cada matéria que vai aos sócios chegar completa e dentro das regras, numa pauta convocada; cada decisão ser registrada em ata, com votos, responsável e prazo; cada ato societário (constituição, alteração ou encerramento de empresa) ser registrado nos órgãos; e cada decisão ter o cumprimento acompanhado e cobrado. Os círculos levam as matérias; os sócios decidem; a Governança secretaria, registra e acompanha.',
    frequencia='No calendário dos sócios (cadência: trimestral, e por evento) e por evento: matéria levada à decisão',
    automacao=('média', 'Registrar a matéria, conferir se está completa, lavrar a ata e acompanhar o cumprimento são de agente e automação; fechar a pauta, conferir a ata e fazer os registros são de pessoa da Governança; decidir é dos sócios.'),
    base=['apqc'],
    lanes=['SOL', 'SOC', P, A, R],
    inicios=[I('Matéria para decisão dos sócios recebida', 'SOL', 'message'),
             I('Reunião dos sócios do calendário', R, 'timer')],
    fins=[F('Decisões registradas e cumprimento acompanhado', R)],
    etapas=[
        E('Montar a pauta e preparar as matérias', 'Governança', 'Copiloto', 'baixo',
          [('Matéria para decisão dos sócios', 'Solicitante'), (METODO_EST, 'Estratégia')],
          [T('Registrar a matéria, quem a propõe e o prazo', R),
           T('Conferir se a matéria está completa e dentro das regras', A),
           D('A matéria está completa e dentro das regras?', P,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Decidir a devolução da matéria, com o que falta', P),
                                   T('Devolver a matéria a quem propôs, com o que falta', R)])]),
           T('Fechar a pauta e convocar os sócios', P)],
          [('Pauta e matérias preparadas', ['etapa 2'])]),
        E('Registrar as decisões dos sócios', 'Sócios decidem; a Governança registra', 'Assistido', 'médio',
          [('Pauta e matérias preparadas', 'etapa 1'), (DEC_REG_ID, 'Identidade'), (DEC_CRIT, 'Identidade'),
           (DEC_ESTRAT, 'Estratégia'), (DIAG, 'Estratégia'), (DEC_SOCIOS, 'Estratégia'), (DEC_ALOC, 'Estratégia'),
           (DEC_PORTAO, 'Estratégia'), (AUTORIZ, 'Estratégia'), (DEC_EMPRESA, 'Estratégia'), (ARQUIVADO, 'Estratégia'),
           (REV_EST, 'Estratégia')],
          [D('A decisão já foi tomada na jornada dona?', R,
             [S('Sim', 'seg', via=[T('Juntar a decisão já tomada ao livro de atas', R)]),
              S('Não: matéria da pauta', 'seg', via=[T('Decidir as matérias da pauta', 'SOC'),
                                                    T('Lavrar a ata com as decisões, os votos, os responsáveis e os prazos', A)])]),
           T('Conferir a ata e colher as assinaturas', P)],
          [('Decisões dos sócios registradas, com responsável e prazo', ['Executivos', 'Líderes dos círculos', 'etapa 3'])]),
        E('Cumprir os atos societários e acompanhar as decisões', 'Governança', 'Copiloto', 'médio',
          [('Decisões dos sócios registradas, com responsável e prazo', 'etapa 2'), (MANDATO, 'Estratégia'),
           (PORTFOLIO, 'Estratégia'), (CONTR_CV, 'Estratégia'), (APORTES, 'Gestão')],
          [D('A decisão pede ato societário fora de um mandato?', A,
             [S('Não, ou o ato é do mandato e é registrado na ES-05', 'seg'),
              S('Sim', 'seg', via=[T('Registrar a alteração societária nos órgãos', P)])]),
           T('Acompanhar o cumprimento de cada decisão e cobrar o responsável', R),
           T('Conferir o cumprimento e apontar aos sócios o que atrasou', P)],
          [('Situação do cumprimento das decisões dos sócios', ['Sócios', 'Executivos'])]),
    ]))

JORNADAS.append(dict(
    code='GO-03',
    nome='Gerir os riscos, a conformidade e os controles internos',
    dominio='Riscos e conformidade', classe='essencial', onda=1,
    objetivo='Fazer os riscos de cada círculo, empresa, oferta, contrato e agente serem reunidos, avaliados pela matriz e tratados por decisão; os controles internos e a conformidade serem testados; cada falha de controle ou não conformidade virar plano de remediação com dono e prazo e, quando a causa pede, regra nova ou revista; e o relatório de riscos e conformidade ir aos sócios e à Estratégia. A Governança avalia, testa e relata; os donos tratam os riscos e remediam.',
    frequencia='A cada ciclo de riscos e conformidade (cadência: trimestral) e por evento: risco, falha de controle ou mudança relevante',
    automacao=('média', 'Reunir, avaliar pela matriz, testar controles e consolidar o relatório são de agente e automação; decidir o tratamento e montar a remediação são de pessoa da Governança, com os donos; o tratamento dos riscos de nota 15 ou mais é dos sócios.'),
    base=['apqc'],
    lanes=['SOC', P, A, R],
    inicios=[I('Ciclo de riscos e conformidade iniciado', R, 'timer'),
             I('Risco, falha de controle ou mudança relevante recebida', R, 'message')],
    fins=[F('Relatório de riscos e conformidade publicado', R)],
    etapas=[
        E('Identificar e avaliar os riscos', 'Governança, com os donos; nota 15 ou mais, os sócios', 'Copiloto', 'médio',
          [(PLANO_LANC, 'Integração'), (SAIDA_CLI, 'Integração'), (AG_SUSPENSO, 'Integração'), (DEMONSTRACOES, 'Gestão'),
           (PORTFOLIO, 'Estratégia'), (LACUNAS_EXEC, 'Identidade'), (PAINEL, 'Inteligência'), (RES_AUDIT, 'GO-06'),
           (RELATOS, 'GO-09'), (CONTRATOS_REG, 'GO-05'), (OBRIG_LEGAIS, 'GO-04'), (REG_TITULARES, 'GO-07'),
           (LICOES_CRISE, 'GO-08')],
          [T('Reunir os riscos de cada círculo, empresa, oferta, contrato e agente', R),
           T('Avaliar probabilidade, impacto e controles de cada risco pela matriz', A),
           T('Decidir o tratamento de cada risco: aceitar, mitigar, transferir ou evitar, com o dono', P),
           D('Algum risco tem nota 15 ou mais na matriz?', R,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Levar aos sócios os riscos de nota 15 ou mais, com a proposta de tratamento', P),
                                    T('Decidir o tratamento dos riscos de nota 15 ou mais', 'SOC')])])],
          [('Riscos avaliados, com o tratamento', ['etapa 2'])]),
        E('Testar os controles e a conformidade', 'Governança', 'Copiloto', 'médio',
          [('Riscos avaliados, com o tratamento', 'etapa 1')],
          [T('Testar os controles internos e a conformidade com a lei e as regras', A),
           T('Conferir os achados dos testes com os donos', P),
           T('Testar uma amostra dos indicadores publicados contra a fonte', A),
           D('Há falha de controle ou não conformidade?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Montar o plano de remediação com o dono, o prazo e a causa', P)])]),
           D('A causa pede regra nova ou revista?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Abrir a revisão da regra', R)])])],
          [(REGRA_REVER, ['GO-01']),
           ('Plano de remediação, com dono e prazo', ['Executivos', 'Líderes dos círculos']),
           ('Resultado dos testes de controle', ['etapa 3'])]),
        E('Relatar os riscos e a conformidade', 'Governança', 'Autopiloto', 'baixo',
          [('Resultado dos testes de controle', 'etapa 2'), ('Remediação executada, com a evidência', 'Executivos'),
           ('Remediação executada, com a evidência', 'Líderes dos círculos')],
          [T('Conferir a evidência das remediações e apontar as vencidas', A),
           T('Consolidar o relatório de riscos, conformidade e remediações', A),
           T('Publicar o relatório aos sócios e à Estratégia', R)],
          [(RELATORIO, ['Estratégia', 'Sócios'])]),
    ]))

JORNADAS.append(dict(
    code='GO-04',
    nome='Manter em dia as obrigações legais: registros, certidões, marcas, procurações e seguros',
    dominio='Riscos e conformidade', classe='essencial', onda=1,
    objetivo='Fazer cada licença, certidão, registro de empresa e de marca, procuração e seguro estar no calendário com o prazo; cada obrigação ser cumprida antes de vencer, com as exigências do órgão atendidas e o indeferimento levado ao executivo; e as certidões e os documentos de habilitação estarem em dia para Negócios. A Governança mantém e cumpre; a Identidade decide a marca.',
    frequencia='Por prazo de cada obrigação e por evento: registro de marca, marca retirada, mandato, compra ou venda de empresa',
    automacao=('média', 'Manter o calendário, apontar o que vence, preparar o pedido e registrar são de agente e automação; conferir, protocolar e cumprir as exigências são de pessoa da Governança.'),
    base=['apqc'],
    lanes=['SOL', 'EXE', P, A, R],
    inicios=[I('Prazo de obrigação legal próximo', R, 'timer'),
             I('Registro, documento ou certidão pedido', 'SOL', 'message')],
    fins=[F('Obrigação cumprida e registrada', R),
          F('Obrigação indeferida, com a decisão do executivo registrada', R)],
    etapas=[
        E('Manter o calendário de obrigações', 'Governança', 'Autopiloto', 'baixo',
          [('Pedido de documento, registro ou certidão', 'Solicitante'), (REGISTRO_MARCA, 'Identidade'),
           (MARCA_RET, 'Identidade'), (MANDATO, 'Estratégia'), (PORTFOLIO, 'Estratégia'), (CONTR_CV, 'Estratégia')],
          [T('Registrar licenças, certidões, registros, marcas, procurações e seguros com o prazo', R),
           T('Apontar o que vence, o que falta e o que o mandato ou a marca retirada pedem', A)],
          [('Obrigações a cumprir', ['etapa 2'])]),
        E('Cumprir a obrigação', 'Governança', 'Copiloto', 'médio',
          [('Obrigações a cumprir', 'etapa 1')],
          [T('Preparar o pedido, a renovação, a transferência ou a baixa', A),
           T('Conferir e protocolar no órgão', P),
           D('O órgão deferiu?', P,
             [S('Sim', 'seg'),
              S('Não, com exigência', 'seg', via=[T('Cumprir a exigência do órgão e protocolar de novo', P)]),
              S('Não, indeferido', 'F2', via=[T('Levar o indeferimento ao executivo, com as opções e o efeito na habilitação', R),
                                             T('Decidir o caminho da obrigação indeferida: recorrer, refazer ou aceitar o efeito', 'EXE'),
                                             T('Registrar a decisão do executivo e o novo prazo, se houver', R)])]),
           T('Registrar o documento e o novo prazo', R)],
          [(CERTIDOES, ['Negócios']),
           (OBRIG_LEGAIS, ['GO-03'])]),
    ]))

# ========================================================== CONTRATOS E AUDITORIA
JORNADAS.append(dict(
    code='GO-05',
    nome='Revisar os contratos, guardá-los e acompanhar prazos e obrigações',
    dominio='Contratos e auditoria', classe='essencial', onda=1,
    objetivo='Fazer cada contrato de cliente, de fornecedor, de tecnologia, de parceria, de oferta conjunta e de compra ou venda de empresa ser comparado com o modelo, ter a cláusula fora dele e o risco revisados e os poderes de quem assina conferidos; ser guardado com partes, prazos, valores e obrigações registrados; e ter cada vencimento e obrigação avisados ao dono com antecedência, com o vencimento sem decisão levado ao executivo. A frente dona origina e negocia o contrato; a Governança revisa, guarda e acompanha.',
    frequencia='Por evento: contrato a revisar ou a guardar; e por prazo de cada vencimento e obrigação',
    automacao=('média', 'Comparar com o modelo, conferir poderes, guardar, registrar e avisar prazos são de agente e automação; revisar cláusulas e riscos, liberar o contrato e conferir o cumprimento são de pessoa da Governança.'),
    base=['apqc', 'cc2002'],
    lanes=['SOL', 'SOC', 'EXE', P, A, R],
    inicios=[I('Contrato para revisar ou guardar recebido', 'SOL', 'message'),
             I('Vencimento ou obrigação de contrato próximo', R, 'timer')],
    fins=[F('Vencimento ou obrigação de contrato acompanhado', R),
          F('Contrato guardado, com as obrigações registradas', R)],
    etapas=[
        E('Revisar o contrato', 'Governança; as matérias da regra 10 dos contratos, os sócios', 'Copiloto', 'médio',
          [(CONTRATO_NEG, 'Negócios'), (ACORDO_CONJ, 'Negócios'), (CONTRATO_TEC, 'Integração'), (CONTRATO_FORN, 'Gestão'),
           (CONTR_CV, 'Estratégia'), (AUT_MARCA, 'Relações'), ('Contrato para revisar ou guardar', 'Solicitante')],
          [D('O que iniciou o trabalho?', R,
             [S('Contrato a revisar', 'seg'),
              S('Contrato já revisado e assinado na jornada dona', 'E2'),
              S('Vencimento ou obrigação próxima', 'E3')]),
           T('Comparar o contrato com o modelo e apontar as cláusulas fora dele', A),
           D('Há cláusula fora do modelo ou risco relevante?', P,
             [S('Não', 'seg'),
              S('Sim, na alçada da Governança', 'seg', via=[T('Revisar a cláusula e o risco e propor a redação', P)]),
              S('Sim, matéria dos sócios: exclusividade, prazo maior que o ciclo, multa acima do modelo, foro ou arbitragem, garantia financeira', 'seg',
                via=[T('Revisar a cláusula e o risco e levar a proposta aos sócios', P),
                     T('Decidir a cláusula que vai aos sócios pela regra dos contratos', 'SOC')])]),
           T('Conferir os poderes de quem assina', A),
           T('Liberar o contrato para assinatura ou para a guarda', P)],
          [('Contrato revisado', ['etapa 2'])]),
        E('Guardar o contrato e registrar as obrigações', 'Governança', 'Autômato', 'baixo',
          [('Contrato revisado', 'etapa 1')],
          [T('Receber o contrato assinado', R, 'receive'),
           T('Guardar o contrato assinado e registrar partes, prazos, valores e obrigações', R),
           D('Há prazo ou obrigação a acompanhar agora?', R,
             [S('Não', 'F2'),
              S('Sim', 'prox')])],
          [(CONTRATOS_REG, ['GO-03', 'etapa 3'])]),
        E('Acompanhar vencimentos e obrigações', 'Governança, com o dono do contrato', 'Copiloto', 'médio',
          [(CONTRATOS_REG, 'etapa 2')],
          [T('Avisar o dono do contrato do vencimento ou da obrigação, com antecedência', R),
           T('Conferir o cumprimento ou a decisão de renovar ou encerrar', P),
           D('O dono cumpriu ou decidiu?', P,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Levar ao executivo o vencimento sem decisão', R),
                                   T('Decidir renovar ou encerrar o contrato vencido sem decisão do dono', 'EXE')])]),
           T('Registrar o cumprimento ou a decisão', R)],
          [('Vencimentos e obrigações de contratos avisados', ['Executivos', 'Líderes dos círculos'])]),
    ]))

JORNADAS.append(dict(
    code='GO-06',
    nome='Auditar se as entregas de pessoas e agentes seguem a identidade e a alçada',
    dominio='Contratos e auditoria', classe='essencial', onda=1,
    objetivo='Fazer uma amostra única de entregas de pessoas e agentes ser sorteada por círculo e por risco e servir à auditoria e à avaliação dos métodos pela Inteligência; cada entrega ser comparada com os critérios e os casos de teste da Identidade e com a alçada; cada caso de fronteira ser julgado pela Identidade e cada não conformidade pela Governança, com a causa achada; cada causa ir a quem corrige (o dono da entrega, a Identidade no padrão ambíguo, a Integração no desvio de agente); e o resultado ser publicado; e a própria Governança ser auditada uma vez por ano por assessoria externa, com as correções decididas pelos sócios. A Identidade define os critérios e julga os casos de fronteira; a Governança sorteia, julga as não conformidades e publica.',
    frequencia='A cada ciclo de auditoria (cadência: trimestral, antes da revisão da execução (ES-06)) e por evento: agente suspenso ou lacuna de execução apontada',
    automacao=('alta', 'Sortear, comparar, classificar, achar a causa provável, calcular o índice e publicar são de agente e automação; julgar os casos, rever a amostra dos conformes e decidir a causa são de pessoa da Governança; uma vez por ano, a assessoria externa audita a própria Governança e os sócios decidem as correções.'),
    base=['apqc'],
    lanes=['IDE', 'ASS', 'SOC', P, A, R],
    inicios=[I('Ciclo de auditoria iniciado', R, 'timer'),
             I('Agente suspenso ou lacuna recebida', R, 'message'),
             I('Ciclo anual de auditoria externa da Governança iniciado', R, 'timer')],
    fins=[F('Resultado da auditoria publicado', R)],
    etapas=[
        E('Sortear a amostra', 'Governança', 'Autômato', 'baixo',
          [(CRITERIOS, 'Identidade'), (REG_ENTREGAS, 'Integração'), (AG_SUSPENSO, 'Integração'), (RESUMO_PAD, 'Identidade'),
           (LACUNAS_EXEC, 'Identidade')],
          [D('O que iniciou a auditoria?', R,
             [S('Ciclo de auditoria', 'seg'),
              S('Agente suspenso ou lacuna apontada', 'seg',
                via=[T('Separar uma amostra dirigida ao agente ou à lacuna', R)]),
              S('Auditoria externa da Governança', 'E4')]),
           T('Sortear a amostra de entregas de pessoas e agentes por círculo e por risco', R),
           T('Registrar a amostra e entregá-la à Inteligência', R)],
          [(AMOSTRA, ['Inteligência', 'etapa 2'])]),
        E('Comparar as entregas com os padrões e a alçada', 'Governança', 'Autopiloto', 'baixo',
          [(AMOSTRA, 'etapa 1'), (PADROES_ID, 'Identidade'), ('Correção feita pelo dono da entrega', 'Líderes dos círculos')],
          [T('Conferir as correções pedidas no ciclo anterior', A),
           T('Comparar cada entrega com os critérios, os casos de teste e a alçada', A),
           T('Separar conformes, não conformes e casos de fronteira', A)],
          [('Entregas classificadas', ['etapa 3'])]),
        E('Julgar os casos e achar a causa', 'Governança', 'Assistido', 'médio',
          [('Entregas classificadas', 'etapa 2')],
          [D('Há casos de fronteira?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Julgar os casos de fronteira', 'IDE')])]),
           T('Rever por amostra as entregas que o agente classificou como conformes', P),
           T('Julgar as não conformidades', P),
           T('Achar a causa provável de cada não conformidade', A),
           D('Há falha de execução?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Pedir a correção ao dono da entrega', R)])]),
           D('Há padrão ambíguo?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Apontar o padrão ambíguo à Identidade', R)])]),
           D('Há desvio de agente?', P,
             [S('Não', 'E5'),
              S('Sim', 'E5', via=[T('Apontar o desvio do agente à Integração', R)])])],
          [(AMBIGUO, ['Identidade']),
           (DESVIO_AG, ['Integração']),
           ('Correção pedida ao dono da entrega', ['Líderes dos círculos']),
           ('Casos julgados, com a causa', ['etapa 5'])]),
        E('Auditar a Governança por assessoria externa', 'Assessoria externa; as correções, os sócios', 'Assistido', 'médio',
          [(REG_ENTREGAS, 'Integração')],
          [T('Separar os registros do ano: entregas, julgamentos e decisões da Governança', R),
           T('Auditar por amostra as entregas, os julgamentos e as decisões da Governança', 'ASS'),
           T('Decidir as correções apontadas pela auditoria externa da Governança', 'SOC')],
          [('Resultado da auditoria externa da Governança, com as correções decididas', ['etapa 5', 'Sócios'])]),
        E('Publicar o resultado da auditoria', 'Governança', 'Autopiloto', 'baixo',
          [('Casos julgados, com a causa', 'etapa 3'), ('Resultado da auditoria externa da Governança, com as correções decididas', 'etapa 4')],
          [T('Calcular o índice de conformidade por círculo e por tipo de entrega', A),
           T('Publicar o resultado da auditoria', R)],
          [(RES_AUDIT, ['Identidade', 'Inteligência', 'GO-03'])]),
    ]))

# ========================================================== DADOS, CRISES E RELATOS
JORNADAS.append(dict(
    code='GO-07',
    nome='Responder aos titulares de dados pessoais',
    dominio='Dados, crises e relatos', classe='essencial', onda=1,
    objetivo='Fazer cada pedido de titular de dados ser registrado, com a identidade do titular confirmada antes de qualquer resposta; os dados dele serem localizados no catálogo de dados, com quem os guarda; a resposta ser decidida pela Governança, no papel de encarregada, pelos direitos e pelas bases legais da LGPD, com os motivos informados quando o pedido não procede no todo ou em parte; a execução ser pedida a quem guarda os dados (Relações, na base de relacionamento, e os demais círculos); e o titular receber a resposta depois de conferido o cumprimento. A Governança decide; quem guarda o dado executa.',
    frequencia='Por evento: pedido de titular',
    automacao=('alta', 'Registrar, confirmar a identidade, localizar os dados, propor a resposta, conferir o cumprimento e responder são de agente e automação; decidir a resposta é de pessoa da Governança.'),
    base=['apqc', 'lgpd'],
    lanes=['SOL', P, A, R],
    inicios=[I('Pedido de titular recebido', 'SOL', 'message')],
    fins=[F('Pedido de titular respondido e registrado', R),
          F('Pedido parado, à espera da confirmação da identidade', R)],
    etapas=[
        E('Receber o pedido e localizar os dados', 'Governança', 'Autopiloto', 'baixo',
          [('Pedido de titular de dados', 'Solicitante'), (CAT_DADOS, 'Inteligência')],
          [T('Registrar o pedido, avisar o recebimento e anotar o prazo', R),
           D('A identidade do titular foi confirmada?', A,
             [S('Sim', 'seg'),
              S('Não', 'F2', via=[T('Pedir ao titular a confirmação da identidade', R)])]),
           T('Localizar os dados do titular no catálogo de dados e quem os guarda', A)],
          [('Pedido de titular analisado', ['etapa 2'])]),
        E('Decidir a resposta ao titular', 'Governança, como encarregada', 'Copiloto', 'médio',
          [('Pedido de titular analisado', 'etapa 1')],
          [T('Propor a resposta pelos direitos do titular e pelas bases legais do tratamento', A),
           T('Decidir a resposta como encarregada', P),
           D('O pedido procede?', P,
             [S('Sim, no todo ou em parte', 'seg',
                via=[T('Pedir a execução a quem guarda os dados', R)]),
              S('Não', 'E3')])],
          [(TITULAR_RESP, ['Relações']),
           ('Pedido de execução a quem guarda os dados', ['Líderes dos círculos']),
           ('Resposta decidida, com os motivos', ['etapa 3'])]),
        E('Conferir o cumprimento e responder ao titular', 'Governança', 'Autômato', 'baixo',
          [('Resposta decidida, com os motivos', 'etapa 2'), (TITULAR_OK, 'Relações'),
           ('Execução do pedido do titular, confirmada por quem guarda os dados', 'Líderes dos círculos')],
          [D('Há execução a conferir?', R,
             [S('Não: pedido negado', 'seg'),
              S('Sim', 'seg', via=[T('Conferir o cumprimento e o prazo e cobrar quem atrasou', R)])]),
           T('Responder ao titular, com os motivos do que não procede', R),
           T('Registrar o pedido, a resposta e o cumprimento', R)],
          [('Resposta ao titular', ['Solicitante']),
           (REG_TITULARES, ['GO-03'])]),
    ]))

JORNADAS.append(dict(
    code='GO-08',
    nome='Conduzir o comitê de crise, da declaração ao encerramento',
    dominio='Dados, crises e relatos', classe='essencial', onda=1,
    objetivo='Fazer cada alerta de crise de Relações acionar o comitê pelo protocolo, com assento da Identidade; os fatos, o risco jurídico e o dever de comunicar à autoridade serem conferidos, e esse dever levado ao canal próprio; a crise ser declarada ou não, com a posição, o porta-voz e o que pode ser dito propostos pela Governança e decididos por um único dono (o executivo, na crise da empresa; o Administrador do IMTS.OS, na crise do Ecossistema; os sócios, quando a crise envolve o executivo), e a decisão avisada a Relações; a posição ser revista enquanto a crise durar e o encerramento decidido pelo mesmo dono; e as lições irem à Identidade e à conformidade. Relações monitora e comunica; a Governança conduz o comitê e propõe; o dono da crise decide.',
    frequencia='Por evento: alerta de crise',
    automacao=('média', 'Convocar, conferir fatos e obrigações, avisar e consolidar as lições são de agente e automação; propor a posição é de pessoa da Governança; decidir a posição e o encerramento é do dono da crise.'),
    base=['apqc'],
    lanes=['REL', 'IDE', 'EXE', 'ADM', 'SOC', P, A, R],
    inicios=[I('Alerta de crise recebido', 'REL', 'message')],
    fins=[F('Crise encerrada e lições registradas', R),
          F('Alerta sem crise declarada, registrado e avisado', R)],
    etapas=[
        E('Acionar o comitê e conferir os fatos', 'Governança, com a Identidade', 'Copiloto', 'alto',
          [(ALERTA_CRISE, 'Relações'), (PROTOCOLO, 'Identidade'), (POSIC, 'Identidade')],
          [T('Convocar o comitê de crise pelo protocolo, com a Identidade', R),
           T('Conferir os fatos, o risco jurídico e o dever de comunicar à autoridade', A),
           T('Avaliar o risco jurídico e o que pode ser dito', P),
           D('Há dever de comunicar à autoridade?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Abrir a comunicação à autoridade no canal próprio', R)])])],
          [('Fatos e riscos conferidos', ['etapa 2']),
           ('Dever de comunicar à autoridade apontado na crise', ['GO-09'])]),
        E('Decidir a declaração, a posição e o porta-voz', 'Governança propõe; decide o dono da crise: o executivo, o Administrador do IMTS.OS ou os sócios', 'Copiloto', 'alto',
          [('Fatos e riscos conferidos', 'etapa 1')],
          [T('Opinar sobre a posição pela identidade e pelo protocolo', 'IDE'),
           T('Propor a declaração, a posição, o porta-voz e o que pode ser dito', P),
           D('De quem é a crise?', P,
             [S('Da empresa', 'seg', via=[T('Decidir a declaração, a posição e o porta-voz da crise da empresa', 'EXE')]),
              S('Do Ecossistema', 'seg', via=[T('Decidir a declaração, a posição e o porta-voz da crise do Ecossistema', 'ADM')]),
              S('Envolve o executivo', 'seg', via=[T('Decidir a declaração, a posição e o porta-voz da crise que envolve o executivo', 'SOC')])]),
           T('Avisar Relações da decisão do comitê', R),
           D('A crise foi declarada?', P,
             [S('Não', 'F2', via=[T('Registrar o alerta e o motivo de não declarar', R)]),
              S('Sim', 'prox')])],
          [(DECL_CRISE, ['Relações']),
           ('Crise declarada', ['etapa 3'])]),
        E('Acompanhar a crise até encerrar e registrar as lições', 'Governança, com o dono da crise', 'Copiloto', 'alto',
          [('Crise declarada', 'etapa 2'), (LICOES_CRISE, 'Relações')],
          [T('Acompanhar a crise com o comitê', P),
           D('A crise pode ser encerrada?', P,
             [S('Não', 'E3', via=[T('Rever a posição com o dono da crise e avisar Relações', P)]),
              S('Sim, crise da empresa', 'seg', via=[T('Decidir o encerramento da crise da empresa', 'EXE')]),
              S('Sim, crise do Ecossistema', 'seg', via=[T('Decidir o encerramento da crise do Ecossistema', 'ADM')]),
              S('Sim, crise que envolve o executivo', 'seg', via=[T('Decidir o encerramento da crise que envolve o executivo', 'SOC')])]),
           T('Consolidar as lições e as causas', A)],
          [(DECL_CRISE, ['Relações']),
           (LICOES_CRISE, ['Identidade', 'GO-03'])]),
    ]))

JORNADAS.append(dict(
    code='GO-09',
    nome='Receber relatos, apurar com independência e comunicar às autoridades',
    dominio='Dados, crises e relatos', classe='essencial', onda=1,
    objetivo='Fazer cada relato de conduta, fraude ou descumprimento ser registrado com a identidade de quem relata protegida, classificado e apurado com independência (o relato que cita alguém da Governança vai direto à assessoria externa, sem acesso da Governança, e a medida é dos sócios não envolvidos), com a medida decidida com o executivo ou, se ele, a Governança ou um sócio estiver envolvido, pelos sócios não envolvidos; cada incidente ou risco que a lei manda comunicar ser comunicado à autoridade competente pela Governança, salvo o do recall, que a Governança já comunica dentro da OP-07 e aqui só registra; e cada causa ir à conformidade. A Governança recebe, apura e comunica; os donos corrigem.',
    frequencia='Por evento: relato no canal; incidente ou risco a comunicar à autoridade',
    automacao=('média', 'Registrar, propor a classificação, preparar a comunicação e registrar são de agente e automação; confirmar a classificação, apurar e enviar a comunicação são de pessoa da Governança.'),
    base=['apqc', 'lgpd', 'anpd15'],
    lanes=['SOL', 'EXE', 'SOC', 'ASS', P, A, R],
    inicios=[I('Relato recebido no canal', 'SOL', 'message'),
             I('Incidente ou risco a comunicar à autoridade recebido', R, 'message')],
    fins=[F('Relato tratado ou autoridade comunicada, e registrado', R),
          F('Relato que cita a Governança tratado pela assessoria e registrado à parte', 'ASS')],
    etapas=[
        E('Receber e classificar o relato ou o incidente', 'Governança', 'Copiloto', 'médio',
          [('Relato de conduta, fraude ou descumprimento', 'Solicitante'), ('Incidente de segurança com dados pessoais', 'Solicitante'),
           (AUTORIDADE, 'Operações'), (REL_RECALL, 'Operações'), ('Dever de comunicar à autoridade apontado na crise', 'GO-08')],
          [T('Registrar o relato ou o incidente, protegendo a identidade de quem relata', R),
           D('O relato cita pessoa da Governança?', R,
             [S('Não', 'seg'),
              S('Sim', 'E3', via=[T('Encaminhar o relato à assessoria externa, sem acesso da Governança', R)])]),
           T('Propor a classificação: gravidade e dever de comunicar à autoridade', A),
           T('Confirmar a classificação', P),
           D('O que é preciso fazer?', P,
             [S('Apurar o relato', 'prox'),
              S('Comunicar à autoridade', 'E4'),
              S('Registrar o que já foi comunicado na OP-07', 'E5')])],
          [('Relato ou incidente classificado', ['etapa 2', 'etapa 4']),
           ('Relato que cita a Governança, encaminhado à assessoria', ['etapa 3'])]),
        E('Apurar o relato e decidir a medida', 'Governança, com o executivo ou os sócios', 'Assistido', 'alto',
          [('Relato ou incidente classificado', 'etapa 1')],
          [T('Apurar os fatos com independência', P),
           D('Quem está envolvido no relato?', P,
             [S('Ninguém da decisão', 'seg', via=[T('Decidir a medida e a correção da causa', 'EXE')]),
              S('O executivo ou um sócio', 'seg',
                via=[T('Decidir a medida e a correção da causa pelos sócios não envolvidos', 'SOC')]),
              S('Pessoa da Governança, achada na apuração', 'E3',
                via=[T('Parar a apuração e encaminhar o relato à assessoria externa, sem acesso da Governança', R)])]),
           D('Há dever de comunicar à autoridade?', P,
             [S('Não', 'E5'),
              S('Sim', 'E4')])],
          [('Relato apurado, com a medida', ['etapa 4', 'etapa 5']),
           ('Relato que cita a Governança, encaminhado à assessoria', ['etapa 3'])]),
        E('Apurar por assessoria externa o relato que cita a Governança', 'Assessoria externa; decidem os sócios não envolvidos', 'Assistido', 'alto',
          [('Relato que cita a Governança, encaminhado à assessoria', 'etapa 1'),
           ('Relato que cita a Governança, encaminhado à assessoria', 'etapa 2')],
          [T('Classificar e apurar os fatos do relato com independência', 'ASS'),
           T('Decidir a medida e a correção da causa do relato apurado pela assessoria', 'SOC'),
           D('Os sócios apontaram dever de comunicar à autoridade?', 'SOC',
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Comunicar à autoridade e, no incidente com dados pessoais, ao titular, no prazo', 'ASS')])]),
           D('Há quem relatou e possa receber resposta?', 'ASS',
             [S('Não', 'F2', via=[T('Registrar o caso à parte, sem acesso da Governança', R)]),
              S('Sim', 'F2', via=[T('Responder a quem relatou o caso da Governança', 'ASS'),
                                  T('Registrar o caso e a resposta à parte, sem acesso da Governança', R)])])],
          [('Relato que cita a Governança, tratado e registrado à parte', ['Sócios'])]),
        E('Comunicar à autoridade', 'Governança', 'Copiloto', 'alto',
          [('Relato ou incidente classificado', 'etapa 1'), ('Relato apurado, com a medida', 'etapa 2')],
          [T('Preparar a comunicação à autoridade competente e, no incidente com dados pessoais, ao titular', A),
           T('Conferir e enviar a comunicação no prazo', P)],
          [('Comunicação à autoridade registrada', ['etapa 5'])]),
        E('Registrar e levar a causa à conformidade', 'Governança', 'Autômato', 'baixo',
          [('Relato apurado, com a medida', 'etapa 2'), ('Comunicação à autoridade registrada', 'etapa 4')],
          [T('Registrar o relato, a medida, a comunicação e a causa', R),
           D('Há quem relatou e possa receber resposta?', R,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Responder a quem relatou', R)])])],
          [(RELATOS, ['GO-03']),
           ('Resposta ao relato', ['Solicitante'])]),
    ]))

JORNADAS.append(dict(
    code='GO-10',
    nome='Apurar e publicar o relato anual de impacto',
    dominio='Dados, crises e relatos', classe='recomendada', onda=2,
    objetivo='Fazer que, a cada ano, os temas e os indicadores de impacto sejam escolhidos pela definição da Identidade; os dados sejam coletados no catálogo de dados e analisados com avanços e lacunas; e o relato seja redigido na voz do Ecossistema, validado com os dados e o risco jurídico, aprovado pelos sócios e publicado. A Identidade define o que conta como impacto; a Governança apura e publica.',
    frequencia='Anual',
    automacao=('média', 'Propor temas, coletar, analisar, redigir e publicar são de agente e automação; decidir os temas e validar são de pessoa da Governança; aprovar é dos sócios.'),
    base=['apqc'],
    lanes=['SOC', P, A, R],
    inicios=[I('Ciclo anual do relato de impacto iniciado', R, 'timer')],
    fins=[F('Relato de impacto publicado', R)],
    etapas=[
        E('Definir os temas e os indicadores', 'Governança', 'Copiloto', 'baixo',
          [(IMPACTO_DEF, 'Identidade'), (PAINEL, 'Inteligência')],
          [T('Propor os temas e os indicadores de impacto do ano pela definição', A),
           T('Decidir os temas e os indicadores', P)],
          [('Temas e indicadores do relato', ['etapa 2'])]),
        E('Coletar e analisar os dados', 'Governança', 'Autopiloto', 'baixo',
          [('Temas e indicadores do relato', 'etapa 1'), (DADO_OK, 'Inteligência')],
          [T('Coletar os dados dos indicadores no catálogo de dados', R),
           T('Analisar o impacto e apontar avanços e lacunas', A)],
          [('Análise do impacto', ['etapa 3'])]),
        E('Redigir o relato, validá-lo e publicá-lo', 'Governança; os sócios aprovam', 'Copiloto', 'médio',
          [('Análise do impacto', 'etapa 2'), (POSIC, 'Identidade')],
          [T('Redigir o relato na voz do Ecossistema', A),
           T('Validar o relato com os dados e o risco jurídico', P),
           T('Aprovar o relato', 'SOC'),
           D('Os sócios aprovaram o relato?', P,
             [S('Sim', 'seg'),
              S('Não, com ajustes', 'E3', via=[T('Registrar os ajustes pedidos pelos sócios', R)])]),
           T('Publicar o relato', R)],
          [('Relato de impacto publicado', ['Públicos externos', TODOS])]),
    ]))

# -------------------------------------------------------------- domínios
DOMINIOS = [
    ('Regras e decisões', 'Regras, políticas e alçadas de pessoas e agentes e a secretaria das decisões dos sócios.'),
    ('Riscos e conformidade', 'Riscos, controles internos, conformidade e obrigações legais em dia.'),
    ('Contratos e auditoria', 'Revisão, guarda e acompanhamento dos contratos e auditoria das entregas de pessoas e agentes.'),
    ('Dados, crises e relatos', 'Titulares de dados, comitê de crise, canal de relatos, comunicação às autoridades e relato de impacto.'),
]

ONDAS = {
    1: 'O que os círculos fechados já esperam da Governança: regras, decisões dos sócios, riscos, obrigações, contratos, auditoria, titulares, crise e relatos',
    2: 'O que presta contas para fora sem ser pedido por outro círculo: o relato anual de impacto',
}

# ------------------------------------------------- o que usamos de cada fonte
USO = {
    'apqc': 'PCF 7.4. Os processos da Governança estão na categoria 11.0 (risco, conformidade, remediação e resiliência), base da GO-03, da GO-04, da GO-06 (auditoria interna, 11.2.1.3), da GO-07 e da GO-09; nos grupos 12.3 (relação com o conselho, aqui os sócios) e 12.4 (questões legais e éticas), base da GO-01, da GO-02, da GO-04 e da GO-05; no grupo 9.8 (controles internos), base da GO-03; e no elemento 13.9.2.3 (relato de sustentabilidade), base da GO-10. O PCF não tem elemento próprio de comitê de crise: a GO-08 usa o 11.4.5 (compartilhar o conhecimento de riscos) nas lições. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.',
    'lgpd': 'Na GO-01: as regras de sigilo e de dados pessoais seguem os princípios de finalidade, adequação e necessidade (art. 6º, I a III), e as de guarda e eliminação seguem o término do tratamento e a eliminação dos dados (arts. 15 e 16). Na GO-07: o titular tem direito a obter do controlador o que a lei lista (art. 18); a declaração completa sobre os dados é fornecida em até quinze dias do requerimento (art. 19, II); o controlador indica o encarregado (art. 41), que aceita reclamações e comunicações dos titulares e recebe as da autoridade nacional (art. 41, § 2º, I e II); aqui, o papel de encarregado fica na Governança. Na GO-09: o incidente de segurança que possa acarretar risco ou dano relevante aos titulares é comunicado à autoridade nacional e ao titular (art. 48).',
    'bpmn': 'Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, serviço e script; a tarefa de outro círculo ou papel aparece como tarefa simples.',
    'camunda': 'Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.',
    'sipoc': 'Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.',
    'anpd15': 'Na GO-09: o incidente que pode acarretar risco ou dano relevante é o que pode afetar significativamente interesses e direitos fundamentais dos titulares e, ao mesmo tempo, envolve ao menos um destes critérios: dados sensíveis; de crianças, adolescentes ou idosos; financeiros; de autenticação; protegidos por sigilo; ou em larga escala (art. 5º). A comunicação à autoridade e ao titular é feita em três dias úteis contados do conhecimento de que o incidente afetou dados pessoais (arts. 6º e 9º); o agente de pequeno porte conta os prazos em dobro (art. 6º, § 8º, e art. 9º, § 6º); as informações podem ser complementadas em vinte dias úteis (art. 6º, § 3º); o registro do incidente, comunicado ou não, é guardado por no mínimo cinco anos (art. 10).',
    'cc2002': 'Na GO-05: contratos civis e empresariais presumem-se paritários e simétricos; a alocação de riscos definida pelas partes deve ser respeitada; a revisão contratual é excepcional e limitada (art. 421-A); os contratantes guardam probidade e boa-fé (art. 422). Base da revisão de cláusula fora do modelo e do risco do contrato.',
}

# ----------------------------------- cobertura do referencial (APQC PCF 7.4)
COBERTURA = [
    ('9.8.1', 'Establish internal controls, policies, and procedures', 'GO-01 (regras e alçadas) e GO-03'),
    ('9.8.2', 'Operate controls and monitor compliance with internal controls policies and procedures', 'GO-03, etapa 2'),
    ('9.8.3', 'Report on internal controls compliance', 'GO-03, etapa 3'),
    ('11.1', 'Manage enterprise risk', 'GO-03, etapa 1'),
    ('11.2.1', 'Establish compliance framework and policies', 'GO-01; a auditoria interna (11.2.1.3, Manage internal audits) é a GO-06'),
    ('11.2.2', 'Manage regulatory compliance', 'GO-03, etapa 2, e GO-04'),
    ('11.3', 'Manage remediation efforts', 'GO-03, etapa 2 (plano de remediação) e GO-09, etapa 2'),
    ('11.4', 'Manage business resiliency', 'Em parte: as lições da crise são levadas à conformidade e à Identidade (GO-08), como pede o 11.4.5. A estratégia de resiliência (11.4.1) e a continuidade dos negócios (11.4.2 a 11.4.4) não têm etapa própria: ficam como limite'),
    ('12.1', 'Build investor relationships', 'Fora: no Ecossistema, os investidores são os sócios (GO-02); credores e analistas não foram desenhados'),
    ('12.2', 'Manage government and industry relationships', 'Fora: relações institucionais são de Relações (RE-06)'),
    ('12.3', 'Manage relations with board of directors', 'GO-02, com os sócios no papel do conselho; relatório de riscos (GO-03) e de auditoria (GO-06). O resultado financeiro (12.3.1) vai aos sócios pela Estratégia, a partir da Gestão (GE-05)'),
    ('12.4.1', 'Create ethics policies', 'GO-01'),
    ('12.4.2', 'Manage corporate governance policies', 'GO-01 e GO-02'),
    ('12.4.3', 'Develop and perform preventive law programs', 'Em parte: a revisão de contratos (GO-05) e das regras (GO-01)'),
    ('12.4.4', 'Ensure compliance', 'GO-03'),
    ('12.4.5', 'Manage outside counsel', 'Limite: a assessoria externa não tem etapa própria'),
    ('12.4.6', 'Protect intellectual property', 'GO-04 (registro de marcas) e tarefas da Governança na IN-06 e na IN-07'),
    ('12.4.7', 'Resolve disputes and litigations', 'Limite: litígios não foram desenhados'),
    ('12.4.8', 'Provide legal advice/counseling', 'Tarefas da Governança nas jornadas dos outros círculos'),
    ('12.4.9', 'Negotiate and document agreements/contracts', 'GO-05; a frente dona negocia'),
    ('12.5', 'Manage public relations program', 'Fora: Relações (RE-07)'),
    ('13.9.2.3', 'Perform sustainability reporting', 'GO-10, como relato anual de impacto'),
]

# --------------------------------------------------- o que a Governança não faz
FRONTEIRAS = [
    ('Escolher o rumo e decidir as matérias dos sócios', 'Sócios e Estratégia',
     'O relatório de riscos e conformidade (GO-03) e a situação do cumprimento das decisões (GO-02). A Governança leva as matérias à decisão dos sócios como tarefa nas jornadas dos outros círculos.'),
    ('Executar a rotina e corrigir', 'Os círculos donos',
     'As regras e alçadas vigentes e as regras de sigilo e de dados pessoais, a todos (GO-01); o plano de remediação (GO-03), a correção pedida ao dono da entrega (GO-06) e o aviso de vencimento de contrato (GO-05).'),
    ('Definir os padrões, os critérios de auditoria, o protocolo de crise e a marca', 'Identidade',
     'O resultado da auditoria e o padrão ambíguo (GO-06) e as lições da crise (GO-08). O registro e a baixa da marca são da Governança (GO-04).'),
    ('Monitorar a reputação e comunicar na crise', 'Relações',
     'A declaração, a posição e o encerramento da crise (GO-08) e a resposta decidida ao titular de dados (GO-07).'),
    ('Originar e negociar contratos', 'A frente dona de cada contrato',
     'A revisão, a guarda e o acompanhamento (GO-05). As tarefas de revisar, conferir poderes e guardar que a Governança já faz nas jornadas donas (NE-04, NE-05, NE-06, RE-06, IT-07, GE-04 e ES-05) entram na GO-05 como contrato já revisado e assinado, só para guarda e acompanhamento. Os modelos de proposta e de contrato e as certidões vão a Negócios (GO-01 e GO-04).'),
    ('Comunicar o recall à autoridade', 'Governança, como tarefa na OP-07',
     'A comunicação do risco do produto e os relatórios do recall são feitos pela Governança dentro da OP-07; a GO-09 só os registra e leva a causa à conformidade.'),
    ('Registrar o ato societário do mandato', 'Governança, como tarefa na ES-05, etapa 7',
     'A GO-02 registra só a alteração societária que não vem de um mandato.'),
    ('Corrigir o agente', 'Integração', 'O desvio de agente apontado pela auditoria (GO-06), que a IT-06 trata.'),
    ('Avaliar o método pelo resultado', 'Inteligência', 'A amostra única de entregas e o resultado da auditoria (GO-06); as regras de guarda e de eliminação (GO-01).'),
    ('Aplicar o rateio e executar aportes', 'Gestão', 'O critério de rateio (GO-01).'),
]

# -------------------------------------------------------- pontos para decidir
PONTOS = []
DECISOES = [
    ('A Governança decide o seu ofício dentro da alçada; os sócios decidem as regras gerais e as alçadas dos executivos',
     'Ponto 1, aprovado por você (11:50 de 03/10/2026)',
     'GO-01, etapa 2. Mesma regra dos outros círculos. O critério de rateio é definido pela Governança com a Estratégia, como a fronteira do círculo 2 diz; a Gestão aplica.'),
    ('Uma amostra única de entregas serve à auditoria e à avaliação dos métodos',
     'Ponto 2, aprovado por você (11:50)',
     'GO-06, etapa 1: a mesma amostra vai à Inteligência (IN-06, etapa 5). Encaminha o alerta do círculo 3: quem sorteia e para onde vai está definido; os estratos (inclusive as entregas com método publicado) e o tamanho ficam em aberto.'),
    ('O comitê de crise é conduzido pela Governança, com o executivo',
     'Ponto 3, aprovado por você (11:50)',
     'GO-08, como a transferência do círculo 1 e a RE-08 já diziam: Relações monitora e comunica; a Governança propõe e o executivo aprova a declaração, a posição e o encerramento; a Identidade tem assento no comitê.'),
    ('O papel de encarregado de dados pessoais fica na Governança',
     'Ponto 4, aprovado por você (11:50)',
     'GO-07: a Governança decide a resposta ao titular; Relações executa na base de relacionamento (RE-03) e quem guarda o dado executa o resto.'),
    ('O relato sobre o executivo é decidido com os sócios',
     'Ponto 5, aprovado por você (11:50)',
     'GO-09, etapa 2: a medida é decidida com o executivo; se ele, a Governança ou um sócio estiver envolvido, decidem os sócios não envolvidos.'),
    ('As auditorias de identidade e de agentes viram uma só',
     'Ponto 6, aprovado por você (11:50)',
     'GO-06 junta a ID-11 transferida e a I-GO3, com a causa encaminhada a quem corrige. A Identidade julga os casos de fronteira, como decidido no fechamento do círculo 1.'),
    ('Dez jornadas', 'Ponto 7, aprovado por você (11:50)', 'GO-01 a GO-10.'),
    ('A IT-06 recebe da Governança o desvio de agente apontado pela auditoria', 'Proposta ao círculo 6, aprovada por você (11:50)',
     'IT-06, etapa 4.'),
    ('Auditoria de execução: modo de cada etapa e nível de automação pelo que as tarefas fazem',
     'Itens 1 a 14 da auditoria, aprovados por você (12:33 de 03/10/2026)',
     'GO-05 etapa 1: a decisão sobre cláusula fora do modelo ou risco relevante passa à pessoa da Governança; o agente aponta as diferenças (item 9). De Autopiloto para Autômato, pelas tarefas: GO-01 etapa 3, GO-05 etapa 2, GO-06 etapa 1, GO-07 etapa 3, GO-09 etapa 4. Nível de automação pela faixa: GO-03 média → alta; GO-06 média → alta; GO-07 média → alta; GO-08 baixa → média; GO-09 baixa → média.'),
    ('O apetite a risco é dos sócios; prazo de comunicação de incidente lido',
     'Decidido e pedido por você (13:09 de 03/10/2026)',
     'GO-03: a Governança mantém a matriz de riscos; os sócios decidem o apetite a risco. GO-09: três dias úteis para comunicar a autoridade e o titular (Resolução CD/ANPD nº 15/2024, arts. 6º e 9º), em dobro para o agente de pequeno porte (art. 6º, § 8º), conferida na ANPD e na reprodução do DOU. GO-05: Código Civil, arts. 421-A e 422.'),
    ('O que a Governança decide sozinha e as regras gerais dos contratos',
     'Aprovado por você (13:51 de 03/10/2026)',
     'A Governança decide sozinha as regras que aplicam regra geral aprovada, os modelos de proposta e contrato, sigilo, dados e guarda, a alçada de pessoas no círculo e de agentes no critério, a matriz de riscos dentro do apetite dos sócios, o rateio com a Estratégia e a amostra. Vão aos sócios as alçadas dos executivos, as regras gerais, as exceções e a alçada da própria Governança. Regras gerais dos contratos: modelo obrigatório; assina o executivo; alocação de riscos escrita (Código Civil, art. 421-A); garantia escrita; papéis de dados e aviso de incidente a tempo dos três dias úteis; reajuste anual por índice escrito (recomendado o IPCA); exclusividade, prazo longo, multa acima do modelo, foro e garantia financeira vão aos sócios; contrato público usa a minuta do edital.'),
    ('Cadências e conteúdos validados; gates de implantação',
     'Validado por você (14:07 de 03/10/2026)',
     'GO-01 anual; GO-02 e GO-03 trimestrais; GO-06 trimestral; matriz de riscos 5 por 5, desenho da amostra e regras de sigilo, dados e guarda. O que depende de dado real ficou nos gates G1 a G9.'),
    ('Correções da auditoria geral',
     'Aprovado por você (16:05 de 03/10/2026)',
     'GO-01: quem decide sai da lista de matérias, por regra; a alçada das pessoas da Governança e os limites dos agentes vão aos sócios (M2). GO-03: risco de nota 15 ou mais vai aos sócios; a remediação volta com evidência (M1, M8). GO-05: matéria da regra 10 dos contratos vai aos sócios; vencimento sem decisão do dono volta com a decisão do executivo (M1, M8). GO-06: pessoa revê amostra dos conformes do agente; correções voltam; auditoria externa anual da própria Governança, com as correções decididas pelos sócios (M3, M8). GO-07: a execução do pedido do titular volta confirmada (M8). GO-08: dono único da crise: o executivo, o Administrador do IMTS.OS ou os sócios (M4). GO-09: relato que cita a Governança vai à assessoria externa, e os sócios decidem a medida (D4). GO-02: a devolução de matéria é decidida por pessoa (L9). Tabela matéria × órgão (D1).'),
]

PROPOSTAS = []

ALERTAS = []

# ------------------------------------------------ relação com o catálogo da rodada 2
MUDANCAS = [
    ('Acrescentado', 'Sem equivalente', 'GO-01',
     'Regras, políticas e alçadas de pessoas e agentes, pedidas por todos os círculos.'),
    ('Ajustado', 'I-GO1 · Da pauta à decisão registrada', 'GO-02',
     'Ganha os atos societários e o acompanhamento do cumprimento.'),
    ('Ajustado', 'C9 · Do risco ao controle', 'GO-03',
     'Ganha os testes de controle, a remediação e o relatório aos sócios e à Estratégia.'),
    ('Ajustado', 'I-GO2 · Do prazo legal à obrigação cumprida', 'GO-04',
     'Ganha o registro e a baixa de marcas e as certidões de habilitação para Negócios.'),
    ('Ajustado', 'C13 · Da minuta ao contrato encerrado', 'GO-05',
     'A frente dona origina e negocia; a Governança revisa, guarda e acompanha.'),
    ('Ajustado', 'I-GO3 · Da decisão do agente à auditoria e ID-11 do círculo 1 (transferida)', 'GO-06',
     'Juntas numa auditoria com amostra única, que serve também à Inteligência.'),
    ('Acrescentado', 'Sem equivalente', 'GO-07',
     'Resposta aos titulares de dados, pedida por Relações (RE-03).'),
    ('Ajustado', 'ID-10 do círculo 1 (transferida), parte da resposta à crise', 'GO-08',
     'O comitê de crise; o monitoramento e a comunicação ficaram em Relações (RE-08).'),
    ('Ajustado', 'I-GO4 · Do relato ao tratamento', 'GO-09',
     'Ganha a comunicação às autoridades, pedida por Operações (OP-04 e OP-07) e pelo incidente com dados pessoais.'),
    ('Ajustado', 'ID-13 do círculo 1 (transferida) · Relato anual de impacto', 'GO-10',
     'Rascunho da Identidade assumido pela Governança, com a aprovação dos sócios.'),
]

LIMITES = [
    'Os fluxos rodam no motor próprio sobre o Supabase, por enquanto em simulação (piloto: Identidade). Falta trocar os adaptadores simulados pelos sistemas reais.',
    'Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado. Os únicos prazos citados são os da LGPD e da Resolução CD/ANPD nº 15/2024, com a fonte.',
    'As cadências foram validadas em 03/10/2026 (aba Parâmetros em aberto); o líder do círculo ajusta na implantação e a calibração com dados é o gate G9.',
    'As alçadas, o que a Governança decide sozinha e as regras gerais dos contratos foram aprovados em 03/10/2026 (abas Parâmetros em aberto e Propostas de parâmetros). Os rascunhos da matriz de riscos, do critério de rateio, da amostra e das regras de sigilo e guarda foram validados em 03/10/2026; o texto final é o gate G8, e o tamanho da amostra, o G9.',
    'Continuidade dos negócios (APQC 11.4.2 a 11.4.4), assessoria externa (12.4.5) e litígios (12.4.7) não têm etapa própria.',
    'Da LGPD foram conferidos os arts. 6º, 15, 16, 18, 19, 41 e 48 citados. O prazo de comunicação de incidente (três dias úteis, Resolução CD/ANPD nº 15/2024) foi conferido em 03/10/2026 na página oficial da ANPD e na reprodução do DOU (26/04/2024, edição 81, seção 1, p. 114); gate G5 cumprido. O Código Civil citado na GO-05 foi conferido no texto oficial.',
    'Cada empresa do Ecossistema é um controlador e indica o seu encarregado; o modelo põe o papel de encarregado na Governança, sem desenhar a indicação nem a divulgação.',
    'O desenho da amostra (estratos e tamanho) tem rascunho validado em 03/10/2026 (aba Gates de implantação, item 2.13); o texto final é o gate G8 e os números, o G9.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024.',
    'As trocas com os oito círculos já fechados foram conferidas dos dois lados pelo nome.',
    'A tarefa de quem não é do círculo (sócios, executivo, Relações) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As saídas estão listadas por etapa, não por caminho.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das dez jornadas, conferiu os 21 códigos e nomes do APQC PCF 7.4 (todos conferem) e as citações da LGPD no Planalto (corretas), e apontou 24 achados, 3 graves: a Governança julgando sozinha os casos de fronteira que o círculo 1 deu à Identidade, a revisão repetida de contratos já revisados nas jornadas donas e o indeferimento de obrigação legal seguindo como se estivesse cumprida.',
    'Todos foram corrigidos ou declarados como limite. A versão corrigida passou por todos os testes automáticos e não passou por nova revisão independente.',
]
