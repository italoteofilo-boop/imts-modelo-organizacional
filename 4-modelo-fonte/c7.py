# -*- coding: utf-8 -*-
"""Círculo 7 · Operações. Fechado em 03/10/2026, aprovado às 11:50: oito jornadas.
Regra do círculo: Operações decide o que é do seu ofício (o plano de capacidade, o plano de entrega de cada cliente, os
procedimentos e os níveis de serviço, a solução da reclamação dentro da alçada e a ação corretiva). O executivo decide o
que passa da alçada de Operações e o recall; Relações define os padrões de experiência; a Gestão compra e fatura; a
Governança define a alçada e avalia o dever de comunicar a autoridade."""
from dsl import configurar, T, PAR, S, D, E, I, F, TODOS

NUM, NOME, SIGLA, PREF = 7, 'Operações', 'OP', 'OP'
LANES, PARTES = configurar(NOME, SIGLA, PREF)
SLUG = 'circulo7-operacoes'
FECHADO = True
STATUS = 'Fechado em 03/10/2026, aprovado às 11:50 · auditoria de execução aplicada em 03/10/2026'
LEAD = ('Operações cumpre a promessa feita ao cliente. Planeja a capacidade de entrega, assume cada cliente implantado e '
        'roda a entrega recorrente, atende pedidos e problemas, trata reclamações, garante a qualidade e os níveis de '
        'serviço e encerra as entregas no fim do contrato ou na saída. Onde há produto físico, cuida da cadeia de '
        'suprimentos e do pós-venda. Não muda o desenho, não compra e não fatura. São oito jornadas.')
PRINCIPIO = ('Regra do círculo, aprovada por você às 11:50 de 03/10/2026: Operações decide o que é do seu ofício '
             '(o plano de capacidade, o plano de entrega de cada cliente, os procedimentos e os níveis de serviço, a solução '
             'da reclamação dentro da alçada e a ação corretiva). O executivo decide o que passa da alçada de Operações e o '
             'recall; Relações define os padrões de experiência; a Integração muda jornadas, sistemas e agentes; a Gestão '
             'compra e fatura; a Governança define a alçada e avalia o dever de comunicar a autoridade.')
MUDOU_INTRO = ('Comparação com o catálogo da rodada 2 (49 jornadas e 216 workflows), que continua no documento do '
               'projeto até cada círculo ser fechado. Azul: acrescentado. Verde: ajustado. Vermelho: retirado.')
COBERTURA_TXT = ('Processos do APQC PCF 7.4 ligados às funções de Operações (categorias 4.0, 5.0 e 6.0), grupo a grupo: '
                 'onde cada um está neste modelo. Os nomes estão como no referencial.')

P, A, R = 'OPP', 'OPA', 'OPR'

# produtos de Operações esperados pelos círculos fechados (nomes exatos)
REG_OP = 'Registros de entrega, atendimento e qualidade'
PED_RECL = 'Pedidos, reclamações e incidentes de clientes'
RECL_CAUSA = 'Reclamações e incidentes de clientes, com a causa'
REG_CLI = 'Registros de entrega, atendimento e reclamações do cliente'
# pedidos aceitos pelos círculos fechados de qualquer origem
LICAO_AP = 'Lição apontada'
PED_AJUSTE = 'Pedido de ajuste ou de revisão de oferta em uso'
CONTEUDO_AP = 'Conteúdo novo apontado'
LAC_EXP = 'Lacuna de experiência apontada'
FATO = 'Fato a comunicar'
CONSULTA = 'Consulta sobre caso não coberto'
PED_TEC = 'Pedido, incidente ou risco de tecnologia'
NEC_CAP = 'Necessidade de capacidade nova ou mudada'
# produtos internos usados em mais de uma jornada
PLANO_CAP = 'Plano de capacidade de entrega: pessoas, parceiros, materiais e ativos'
PROCED = 'Procedimentos e níveis de serviço vigentes'
ACAO_AB = 'Ação corretiva aberta'
RECL_REG = 'Reclamação registrada'
FATURAR = 'Entregas confirmadas para faturar, com a medição dos níveis de serviço'
CREDITO = 'Crédito ou reembolso aprovado para o cliente'
AUTORIDADE = 'Incidente ou risco a comunicar à autoridade'
# produtos de outros círculos
PREVISAO = 'Previsão de receita e de vendas'
ATA = 'Ata de registro de preços vigente, com saldo e órgãos participantes'
TABELA = 'Tabela de preços e política comercial vigentes'
CONTRATO = 'Contrato de cliente assinado, com o escopo vendido'
CONTR_FIM = 'Contrato encerrado, com a data de fim'
OFERTA_CAT = 'Oferta no catálogo de ofertas: escopo, método, conteúdo-base, preço-base e indicadores'
OFERTA_FORA = 'Aposta ou oferta encerrada e fora do catálogo de ofertas'
OFERTA_LANC = 'Oferta aprovada para lançamento'
DEC_ENCERRAR = 'Decisão de encerrar aposta em desenvolvimento ou oferta em uso'
DATA_SAIDA = 'Data de saída confirmada da aposta ou da oferta encerrada'
MANDATO = 'Mandato da empresa'
CORRECOES = 'Correções de execução publicadas, com dono e prazo'
PLANO_LANC = 'Plano de lançamento da oferta'
OFERTA_LANCADA = 'Oferta lançada'
PLANO_IMPL = 'Plano de implantação do cliente'
CLI_IMPL = 'Cliente implantado e aceito, passado à entrega'
SAIDA_CLI = 'Plano de saída de clientes e contratos'
CATALOGO = 'Catálogo de capacidades atualizado'
CX = 'Estratégia de experiência do cliente: personas, mapa da jornada e padrões de experiência'
PLANO_SUC = 'Plano de sucesso do cliente: resultados esperados, marcos e contatos'
PLANO_REC = 'Plano de recuperação do cliente'
CLI_SAIDA = 'Clientes avisados da saída, com a transição combinada'
LAC_PERC = 'Lacunas de percepção encaminhadas ao dono'
AVAL_SEM = 'Avaliação da experiência sem mudança'
PARCERIA = 'Parceria ativa, com plano de ativação'
LACUNAS_EXEC = 'Lacunas de execução apontadas'
PACOTE_MARCA = 'Pacote de marca publicado'
MARCA_RET = 'Marca retirada de uso'
PADROES_ID = 'Padrões de identidade vigentes'
RESPOSTA_ID = 'Resposta à consulta'
PAINEL = 'Painel de indicadores de cada círculo, com dono e análise'
BASE_PUB = 'Base de conhecimento publicada'
METODO_PUB = 'Método publicado, com versão e data de revisão'
METODO_RET = 'Método retirado de uso'
RESP_OFERTA = 'Resposta ao pedido sobre oferta em uso'
ALCADAS = 'Regras e alçadas vigentes'
SIGILO = 'Regras de sigilo e de dados pessoais'
COMPRADOS = 'Materiais e serviços comprados, com a data de entrega'
RISCO_DEF = 'Defeito com risco à saúde ou à segurança, com o lote'
RECURSOS_OK = 'Pessoas, compras e ativos do plano confirmados'

JORNADAS = []

# ========================================================== CAPACIDADE E ENTREGA
JORNADAS.append(dict(
    code='OP-01',
    nome='Planejar a capacidade de entrega de cada oferta e cobrir as faltas',
    dominio='Capacidade e entrega', classe='essencial', onda=1,
    objetivo='Fazer a capacidade de pessoas, agentes, parceiros, materiais e ativos acompanhar a demanda prevista: cada oferta lançada, mudada ou retirada, cada previsão de vendas, ata, parceria e mandato traduzidos em trabalho; cada falta coberta (remanejar, contratar, usar parceiro, automatizar ou recusar) por decisão de Operações ou, acima da alçada, do executivo; e um plano publicado, usado para confirmar propostas, implantações e lançamentos. Operações planeja e decide; a Gestão contrata e compra; a Integração cria a capacidade que falta.',
    frequencia='A cada ciclo de planejamento (cadência: trimestral) e por evento: previsão de vendas, oferta aprovada, lançada ou retirada, parceria ativa ou mandato de empresa',
    automacao=('alta', 'Reunir, traduzir a demanda em trabalho, comparar com a capacidade e pedir recursos são de agente e automação; decidir o plano é de pessoa de Operações; o que passa da alçada é do executivo.'),
    base=['apqc'],
    lanes=['NEG', 'INT', 'EST', 'ITG', 'REL', 'GES', 'EXE', P, A, R],
    inicios=[I('Ciclo de planejamento da capacidade iniciado', R, 'timer'),
             I('Previsão de vendas ou ata recebida', 'NEG', 'message'),
             I('Oferta, parceria ou mandato que muda a capacidade recebido', R, 'message')],
    fins=[F('Plano de capacidade decidido e publicado', R)],
    etapas=[
        E('Reunir a demanda prevista e o que cada oferta exige', 'Operações', 'Autopiloto', 'baixo',
          [(PREVISAO, 'Negócios'), (ATA, 'Negócios'), (OFERTA_CAT, 'Inteligência'), (OFERTA_FORA, 'Inteligência'),
           (PAINEL, 'Inteligência'), (OFERTA_LANC, 'Estratégia'), (MANDATO, 'Estratégia'), (PLANO_LANC, 'Integração'),
           (OFERTA_LANCADA, 'Integração'), (CATALOGO, 'Integração'), (PARCERIA, 'Relações'), (RECURSOS_OK, 'Gestão')],
          [T('Reunir previsão de vendas, atas, ofertas, lançamentos, parcerias, mandatos e recursos confirmados', R),
           T('Traduzir a demanda prevista em trabalho por oferta, perfil e recurso', A),
           T('Comparar a demanda com a capacidade de pessoas, agentes, parceiros e ativos', A)],
          [('Demanda e capacidade comparadas, com as faltas e as sobras', ['etapa 2'])]),
        E('Decidir como cobrir as faltas e usar as sobras', 'Operações; acima da alçada, o executivo', 'Copiloto', 'médio',
          [('Demanda e capacidade comparadas, com as faltas e as sobras', 'etapa 1'), (ALCADAS, 'Governança')],
          [T('Propor como cobrir cada falta: remanejar, contratar, usar parceiro, automatizar ou recusar', A),
           D('A cobertura cabe na alçada de Operações?', P,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Decidir a cobertura acima da alçada de Operações', 'EXE')])]),
           T('Decidir o plano de capacidade do ciclo', P)],
          [('Plano de capacidade decidido', ['etapa 3'])]),
        E('Pedir os recursos e publicar o plano', 'Operações', 'Autômato', 'baixo',
          [('Plano de capacidade decidido', 'etapa 2')],
          [D('O plano pede capacidade nova, agente ou automação?', R,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Pedir à Integração a capacidade nova ou mudada', R)])]),
           T('Pedir à Gestão as pessoas, as compras e os ativos do plano', R),
           T('Publicar o plano e o mapa de capacidade usados para confirmar propostas e implantações', R)],
          [(PLANO_CAP, ['Gestão', 'Executivos', 'OP-06']),
           (NEC_CAP, ['Integração'])]),
    ]))

JORNADAS.append(dict(
    code='OP-02',
    nome='Entregar o serviço a cada cliente, ciclo a ciclo',
    dominio='Capacidade e entrega', classe='essencial', onda=1,
    objetivo='Fazer cada cliente implantado ter um plano de entrega com escopo, nível de serviço, equipe, agentes e contatos; cada entrega feita pelo método da oferta, conferida contra o escopo e o padrão e aceita pelo cliente; cada ciclo confirmado conforme o contrato, com a medição dos níveis de serviço, e passado à Gestão para faturar; cada impasse sobre a entrega virar reclamação tratada; e cada plano de recuperação de Relações virar ajuste do plano de entrega. Operações entrega; o cliente aceita; a Gestão fatura.',
    frequencia='Por cliente: ao receber o cliente implantado (novo, renovado ou ampliado) ou o plano de recuperação, e a cada ciclo de entrega do contrato (cadência do contrato)',
    automacao=('alta', 'Programar, conferir, confirmar e registrar são de agente e automação; a entrega é de pessoa ou de agente, conforme o método da oferta; aprovar o plano e corrigir a entrega são de pessoa de Operações.'),
    base=['apqc', 'l14133'],
    lanes=['ITG', 'REL', 'CLI', P, A, R],
    inicios=[I('Cliente implantado recebido', 'ITG', 'message'),
             I('Plano de recuperação do cliente recebido', 'REL', 'message'),
             I('Ciclo de entrega do cliente iniciado', R, 'timer')],
    fins=[F('Ciclo de entrega confirmado, passado a faturar e registrado', R),
          F('Entregas do cliente suspensas por atraso, registradas', R)],
    etapas=[
        E('Assumir o cliente e planejar a entrega', 'Operações', 'Copiloto', 'médio',
          [(CLI_IMPL, 'Integração'), (PLANO_IMPL, 'Integração'), (CONTRATO, 'Negócios'), (TABELA, 'Negócios'),
           (PLANO_SUC, 'Relações'), (PLANO_REC, 'Relações'), (CX, 'Relações'), (OFERTA_CAT, 'Inteligência'),
           (METODO_PUB, 'Inteligência'), (PACOTE_MARCA, 'Identidade'), (MARCA_RET, 'Identidade'), (PROCED, 'OP-05')],
          [D('O que iniciou a entrega?', R,
             [S('Cliente implantado, novo, renovado ou ampliado, ou plano de recuperação', 'seg'),
              S('Ciclo de entrega de cliente já assumido', 'E2')]),
           T('Conferir o escopo vendido, os termos e o nível de serviço do contrato', A),
           T('Montar ou ajustar o plano de entrega: entregas, nível de serviço, equipe, agentes e contatos', A),
           T('Aprovar o plano de entrega e designar o responsável pelo cliente', P)],
          [('Plano de entrega do cliente', ['etapa 2'])]),
        E('Executar as entregas do ciclo', 'Operações', 'Copiloto', 'médio',
          [('Plano de entrega do cliente', 'etapa 1'), (BASE_PUB, 'Inteligência'), (PADROES_ID, 'Identidade'),
           ('Suspensão de novas entregas por atraso, decidida pelo executivo', 'Gestão')],
          [D('As novas entregas do cliente estão suspensas por atraso?', R,
             [S('Não', 'seg'),
              S('Sim', 'F2', via=[T('Registrar a suspensão e avisar o cliente e o responsável pelo cliente', R)])]),
           T('Programar as entregas do ciclo e alocar pessoas, agentes e parceiros', A),
           PAR([T('Executar as entregas feitas por agentes e automações', A)],
               [T('Executar as entregas feitas por pessoas', P)]),
           T('Conferir cada entrega contra o escopo e o padrão de qualidade', A),
           D('A entrega passou na conferência?', A,
             [S('Sim', 'prox'),
              S('Não', 'E2', via=[T('Corrigir a entrega e registrar a não conformidade', P)])])],
          [('Entregas do ciclo conferidas', ['etapa 3'])]),
        E('Confirmar a entrega com o cliente e passar a faturar', 'Operações, com o aceite do cliente', 'Copiloto', 'médio',
          [('Entregas do ciclo conferidas', 'etapa 2')],
          [T('Aceitar as entregas do ciclo', 'CLI'),
           D('O cliente aceitou as entregas?', P,
             [S('Sim', 'seg'),
              S('Não, com correção possível', 'E2', via=[T('Registrar o motivo da recusa e replanejar a entrega', A)]),
              S('Não, sem acordo sobre a entrega', 'E4', via=[T('Abrir a reclamação sobre a entrega não aceita', R)])]),
           T('Confirmar a entrega conforme os termos do contrato e medir os níveis de serviço do ciclo', R)],
          [(FATURAR, ['Gestão']),
           ('Entrega do ciclo confirmada', ['etapa 4']),
           ('Entrega não aceita, com a reclamação aberta', ['etapa 4']),
           (RECL_REG, ['OP-04'])]),
        E('Registrar o ciclo e apontar o que ensina', 'Operações', 'Autopiloto', 'baixo',
          [('Entrega do ciclo confirmada', 'etapa 3'), ('Entrega não aceita, com a reclamação aberta', 'etapa 3')],
          [T('Registrar entregas, prazos, não conformidades e esforço do ciclo', R),
           T('Apontar a lição do ciclo e os sinais de ampliação ou de risco do cliente', A)],
          [(REG_OP, ['Inteligência']),
           (REG_CLI, ['Relações']),
           (LICAO_AP, ['Inteligência'])]),
    ]))

JORNADAS.append(dict(
    code='OP-08',
    nome='Encerrar as entregas no fim do contrato ou na saída da oferta ou da empresa',
    dominio='Capacidade e entrega', classe='essencial', onda=1,
    objetivo='Fazer cada contrato encerrado e cada saída de oferta ou de empresa virar um fim de entregas planejado: no fim do contrato, de imediato; na saída, preparado pelo plano de saída da Integração e executado na data confirmada pela Estratégia. As entregas são concluídas ou transferidas na transição combinada por Relações; o último ciclo é passado a faturar; os dados e materiais do cliente são devolvidos ou eliminados, com aprovação de pessoa, guardado só o que a lei ou o contrato mandam guardar; os recursos são liberados à Gestão; e a conclusão vai à Integração e as lições à Inteligência.',
    frequencia='Por evento: contrato encerrado, plano de saída, data de saída confirmada ou mandato de empresa',
    automacao=('média', 'Listar o que está em curso, executar a devolução ou a eliminação aprovada, liberar recursos e arquivar são de agente e automação; planejar, concluir as entregas e aprovar o destino dos dados são de pessoa de Operações; o cliente confirma.'),
    base=['apqc', 'lgpd'],
    lanes=['NEG', 'ITG', 'EST', 'CLI', P, A, R],
    inicios=[I('Contrato encerrado recebido', 'NEG', 'message'),
             I('Plano de saída de clientes e contratos recebido', 'ITG', 'message'),
             I('Data de saída ou mandato recebido', 'EST', 'message')],
    fins=[F('Entregas encerradas e recursos liberados', R),
          F('Fim das entregas preparado, à espera da data ou do plano de saída', R)],
    etapas=[
        E('Planejar o fim das entregas', 'Operações', 'Copiloto', 'médio',
          [(CONTR_FIM, 'Negócios'), (SAIDA_CLI, 'Integração'), (CLI_SAIDA, 'Relações'), (DEC_ENCERRAR, 'Estratégia'),
           (DATA_SAIDA, 'Estratégia'), (MANDATO, 'Estratégia'), (OFERTA_FORA, 'Inteligência')],
          [D('O que iniciou o encerramento?', R,
             [S('Contrato encerrado', 'seg'),
              S('Data de saída ou mandato, com o plano de saída já recebido', 'seg'),
              S('Plano de saída, ainda sem a data', 'F2',
                via=[T('Preparar o fim das entregas pelo plano e aguardar a data de saída', A)]),
              S('Decisão de encerrar ou data, ainda sem o plano de saída', 'F2',
                via=[T('Registrar a decisão e aguardar o plano de saída da Integração', R)])]),
           T('Listar as entregas em curso, os compromissos e os dados e materiais do cliente', A),
           T('Planejar o fim, a transição combinada e o destino de dados e materiais', P)],
          [('Plano de fim das entregas', ['etapa 2'])]),
        E('Concluir as entregas e devolver o que é do cliente', 'Operações, com o cliente', 'Assistido', 'médio',
          [('Plano de fim das entregas', 'etapa 1'), (SIGILO, 'Governança')],
          [T('Concluir ou transferir as entregas em curso conforme o plano', P),
           T('Aprovar o que devolver, o que eliminar e o que a lei ou o contrato mandam guardar', P),
           T('Devolver ou eliminar os dados e materiais do cliente como aprovado', R),
           T('Confirmar o fim das entregas', 'CLI')],
          [('Entregas encerradas', ['etapa 3'])]),
        E('Liberar os recursos e guardar o conhecimento', 'Operações', 'Autopiloto', 'baixo',
          [('Entregas encerradas', 'etapa 2')],
          [T('Passar o último ciclo a faturar', R),
           T('Registrar a liberação de pessoas, agentes, parceiros e ativos alocados ao cliente ou à oferta', R),
           T('Arquivar os registros que devem ser guardados e atualizar os sistemas', R),
           T('Apontar as lições do encerramento', A)],
          [(FATURAR, ['Gestão']),
           ('Recursos da operação liberados, com a data', ['Gestão']),
           ('Entregas encerradas na saída', ['Integração']),
           (REG_CLI, ['Relações']),
           (REG_OP, ['Inteligência']),
           (LICAO_AP, ['Inteligência'])]),
    ]))

# ========================================================== ATENDIMENTO E QUALIDADE
JORNADAS.append(dict(
    code='OP-03',
    nome='Atender o cliente: pedidos, dúvidas e problemas, do contato à solução',
    dominio='Atendimento e qualidade', classe='essencial', onda=1,
    objetivo='Fazer cada contato de cliente ser registrado, classificado pelo nível de serviço que vale, resolvido pela base de conhecimento ou por pessoa e respondido; cada problema de tecnologia ir à Integração; cada caso sem padrão ir à Identidade e cada dúvida sobre a oferta em uso à Inteligência; cada reclamação, e cada caso que não se resolve, ir ao tratamento de reclamações; cada pedido comercial ir a Negócios; e cada atendimento deixar registro e o conteúdo que faltou. Operações atende; Negócios trata o pedido comercial.',
    frequencia='Por evento: cada contato do cliente, em qualquer canal',
    automacao=('alta', 'Registrar, classificar, responder o que a base cobre, consultar e registrar são de agente e automação; resolver o caso que o agente não resolve é de pessoa de Operações, só quando a resposta não resolveu.'),
    base=['apqc'],
    lanes=['CLI', 'NEG', P, A, R],
    inicios=[I('Pedido, dúvida ou problema do cliente recebido', 'CLI', 'message')],
    fins=[F('Contato resolvido, respondido e registrado', R),
          F('Reclamação passada ao tratamento de reclamações', R),
          F('Pedido comercial passado a Negócios', R)],
    etapas=[
        E('Receber e classificar o contato do cliente', 'Operações', 'Autopiloto', 'baixo',
          [('Pedido, dúvida ou problema do cliente', 'Clientes'), (PLANO_SUC, 'Relações'), (PROCED, 'OP-05'),
           (SIGILO, 'Governança')],
          [T('Registrar o contato, o cliente, o contrato e o canal', R),
           T('Classificar o tipo, a urgência e o nível de serviço que vale', A),
           D('O que o cliente pede?', A,
             [S('Pedido, dúvida ou problema da entrega', 'prox'),
              S('Reclamação', 'F2', via=[T('Abrir a reclamação no tratamento de reclamações', R)]),
              S('Pedido comercial: ampliação, preço ou cancelamento', 'F3',
                via=[T('Receber o pedido comercial do cliente e tratá-lo na proposta ou no contrato', 'NEG')])])],
          [('Contato classificado', ['etapa 2']),
           (RECL_REG, ['OP-04'])]),
        E('Resolver e responder ao cliente', 'Operações', 'Autopiloto', 'médio',
          [('Contato classificado', 'etapa 1'), (BASE_PUB, 'Inteligência'), (RESP_OFERTA, 'Inteligência'),
           (RESPOSTA_ID, 'Identidade')],
          [D('O problema é de tecnologia?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Abrir o pedido ou o incidente na Integração e acompanhar até a solução', R)])]),
           D('Falta padrão ou regra para responder?', A,
             [S('Não', 'seg'),
              S('Falta padrão de identidade', 'seg', via=[T('Consultar a Identidade sobre o caso não coberto', R)]),
              S('Falta regra da oferta em uso', 'seg', via=[T('Pedir à Inteligência a resposta sobre a oferta em uso', R)])]),
           T('Responder o que a base de conhecimento e as respostas recebidas cobrem', A),
           D('A resposta resolveu?', A,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Analisar e resolver o caso que o agente não resolve', P)])]),
           D('O caso foi resolvido?', A,
             [S('Sim', 'seg'),
              S('Não', 'F2', via=[T('Abrir a reclamação pelo caso não resolvido', R)])]),
           T('Responder ao cliente e confirmar que resolveu', R)],
          [('Contato resolvido', ['etapa 3']),
           (PED_TEC, ['Integração']),
           (CONSULTA, ['Identidade']),
           (PED_AJUSTE, ['Inteligência']),
           (RECL_REG, ['OP-04'])]),
        E('Registrar o atendimento e o que ele ensina', 'Operações', 'Autopiloto', 'baixo',
          [('Contato resolvido', 'etapa 2')],
          [T('Registrar o atendimento, o tempo, a causa e a avaliação do cliente', R),
           T('Apontar sinais de ampliação e de risco de perda e o conteúdo que faltou na base', A)],
          [(REG_OP, ['Inteligência']),
           (PED_RECL, ['Inteligência']),
           (REG_CLI, ['Relações']),
           (CONTEUDO_AP, ['Inteligência'])]),
    ]))

JORNADAS.append(dict(
    code='OP-04',
    nome='Tratar reclamações e incidentes de clientes e corrigir a causa',
    dominio='Atendimento e qualidade', classe='essencial', onda=1,
    objetivo='Fazer cada reclamação ou incidente de cliente ser registrado com o prazo de resposta, classificado pela gravidade e pelo risco legal, investigado até a causa e resolvido por decisão de Operações ou, acima da alçada, do executivo; quando o cliente é consumidor, oferecidas as alternativas da lei; a resposta, inclusive a de improcedência, dada por escrito e registrada; o caso sem acordo encerrado com a informação de onde mais o cliente pode recorrer; e cada causa virar ação corretiva, pedido de ajuste da oferta ou lacuna de experiência. Operações trata; a Governança avalia o dever de comunicar a autoridade; Relações recebe a reclamação com a causa.',
    frequencia='Por evento: reclamação aberta no atendimento ou na entrega, ou recebida de outro canal',
    automacao=('média', 'Registrar, classificar, confirmar o recebimento, propor a solução, analisar a causa e registrar são de agente e automação; conferir a classificação, decidir a solução e aplicá-la são de pessoa de Operações; o que passa da alçada é do executivo, com a avaliação da Governança.'),
    base=['apqc', 'iso10002', 'cdc'],
    lanes=['SOL', 'GOV', 'EXE', P, A, R],
    inicios=[I('Reclamação aberta no atendimento ou na entrega', R, 'message'),
             I('Reclamação ou incidente recebido de outro canal', 'SOL', 'message')],
    fins=[F('Reclamação resolvida ou respondida, com a causa tratada', R)],
    etapas=[
        E('Receber e classificar a reclamação', 'Operações; o risco legal, com a Governança', 'Copiloto', 'médio',
          [(RECL_REG, 'OP-03'), (RECL_REG, 'OP-02'), ('Reclamação ou incidente de cliente', 'Solicitante'),
           (SIGILO, 'Governança'), (ALCADAS, 'Governança')],
          [T('Registrar a reclamação ou o incidente, o cliente, o contrato e o prazo de resposta', R),
           T('Classificar a gravidade, o risco legal e quem deve resolver', A),
           T('Conferir a classificação de gravidade e de risco legal', P),
           D('Há risco à saúde ou à segurança, ou dever de comunicar a autoridade?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Avaliar o risco e o dever de comunicar a autoridade', 'GOV')])]),
           T('Confirmar o recebimento ao cliente, com o prazo de resposta', R)],
          [('Reclamação classificada', ['etapa 2']),
           (AUTORIDADE, ['Governança'])]),
        E('Investigar e decidir a solução', 'Operações; acima da alçada, o executivo com a Governança', 'Copiloto', 'médio',
          [('Reclamação classificada', 'etapa 1')],
          [T('Investigar o fato e achar a causa provável', A),
           T('Propor a solução e, se o cliente é consumidor, as alternativas da lei', A),
           T('Conferir a solução proposta e a alçada que ela pede', P),
           D('A solução cabe na alçada de Operações?', P,
             [S('Sim', 'seg', via=[T('Decidir a solução da reclamação', P)]),
              S('Não', 'seg', via=[T('Avaliar a responsabilidade e o risco da solução acima da alçada', 'GOV'),
                                   T('Decidir a solução acima da alçada de Operações', 'EXE')])]),
           D('A reclamação procede?', P,
             [S('Sim', 'prox'),
              S('Não', 'E4', via=[T('Responder ao cliente por escrito com o motivo da improcedência', R)])])],
          [('Solução decidida', ['etapa 3']),
           ('Reclamação improcedente respondida', ['etapa 4'])]),
        E('Aplicar a solução e confirmar com o cliente', 'Operações', 'Copiloto', 'médio',
          [('Solução decidida', 'etapa 2')],
          [T('Aplicar a solução: refazer ou corrigir a entrega, ou pedir o crédito ou o reembolso', P),
           T('Responder ao cliente por escrito com a solução', R),
           D('O cliente aceitou a solução?', P,
             [S('Sim', 'prox'),
              S('Não, com outra solução possível', 'E2', via=[T('Registrar a objeção do cliente e rever a solução', A)]),
              S('Não, sem acordo', 'prox',
                via=[T('Encerrar a reclamação e informar ao cliente onde mais pode recorrer', R)])])],
          [('Reclamação resolvida ou encerrada', ['etapa 4']),
           (CREDITO, ['Gestão'])]),
        E('Tratar a causa e entregar o aprendizado', 'Operações', 'Copiloto', 'médio',
          [('Reclamação resolvida ou encerrada', 'etapa 3'), ('Reclamação improcedente respondida', 'etapa 2')],
          [T('Analisar a causa raiz e a recorrência das reclamações', A),
           T('Decidir como tratar a causa', P),
           D('A causa pede mudança?', P,
             [S('Não', 'seg'),
              S('Na operação', 'seg', via=[T('Abrir a ação corretiva na qualidade', R)]),
              S('Na oferta', 'seg', via=[T('Pedir o ajuste da oferta em uso à Inteligência', R)]),
              S('Na experiência', 'seg', via=[T('Apontar a lacuna de experiência a Relações', R)])]),
           T('Registrar a reclamação, a causa, a solução e o prazo cumprido', R)],
          [(RECL_CAUSA, ['Relações']),
           (PED_RECL, ['Inteligência']),
           (ACAO_AB, ['OP-05']),
           (PED_AJUSTE, ['Inteligência']),
           (LAC_EXP, ['Relações'])]),
    ]))

JORNADAS.append(dict(
    code='OP-05',
    nome='Garantir a qualidade e os níveis de serviço: padrões, medida e ação corretiva',
    dominio='Atendimento e qualidade', classe='essencial', onda=1,
    objetivo='Fazer os padrões de experiência de Relações e o método de cada oferta virarem procedimentos e níveis de serviço por oferta e por segmento de cliente; a qualidade e os níveis de serviço serem medidos; cada não conformidade, reclamação recorrente ou lacuna apontada ter a causa achada e uma ação corretiva decidida, implantada e conferida; a causa que Operações não consegue eliminar ir ao executivo; e o padrão que a operação não consegue cumprir voltar a Relações como lacuna. Operações define e mede; Relações define a experiência; a Inteligência publica o painel.',
    frequencia='A cada ciclo de avaliação da qualidade (cadência: mensal) e por evento: padrão ou oferta nova ou mudada, ação corretiva aberta, lacuna de execução ou de percepção',
    automacao=('alta', 'Traduzir padrões, medir, comparar com os alvos, analisar a causa e registrar são de agente e automação; decidir procedimentos, níveis de serviço e ação corretiva e implantá-la são de pessoa de Operações.'),
    base=['apqc', 'iso9001'],
    lanes=['EXE', P, A, R],
    inicios=[I('Ciclo de avaliação da qualidade iniciado', R, 'timer'),
             I('Padrão, oferta ou método novo ou mudado recebido', R, 'message'),
             I('Ação corretiva ou lacuna recebida', R, 'message')],
    fins=[F('Ação corretiva concluída e registrada', R),
          F('Qualidade dentro dos níveis de serviço, sem ação', R)],
    etapas=[
        E('Definir os procedimentos e os níveis de serviço', 'Operações', 'Copiloto', 'médio',
          [(CX, 'Relações'), (AVAL_SEM, 'Relações'), (OFERTA_CAT, 'Inteligência'), (METODO_PUB, 'Inteligência'),
           (METODO_RET, 'Inteligência'), (PADROES_ID, 'Identidade'), (CONTRATO, 'Negócios')],
          [D('O que iniciou o trabalho?', R,
             [S('Padrão, oferta ou método novo ou mudado', 'seg'),
              S('Ciclo de avaliação', 'E2'),
              S('Ação corretiva ou lacuna apontada', 'E3')]),
           T('Traduzir os padrões de experiência e o método da oferta em procedimentos e níveis de serviço', A),
           T('Decidir os procedimentos e os níveis de serviço por oferta e por segmento de cliente', P),
           D('Algum padrão de experiência não pode ser cumprido pela operação?', P,
             [S('Não', 'prox'),
              S('Sim', 'prox', via=[T('Apontar a Relações a lacuna, com a causa e o que seria preciso', R)])])],
          [(PROCED, ['etapa 2', 'OP-02', 'OP-03']),
           (LAC_EXP, ['Relações'])]),
        E('Medir a qualidade e o cumprimento dos níveis de serviço', 'Operações', 'Autopiloto', 'baixo',
          [(PROCED, 'etapa 1'), (PAINEL, 'Inteligência')],
          [T('Medir qualidade, prazos e níveis de serviço por oferta, cliente e equipe', R),
           T('Comparar com os alvos e achar as não conformidades e as tendências', A),
           D('Há não conformidade ou tendência que pede ação?', A,
             [S('Sim', 'prox'),
              S('Não', 'F2', via=[T('Registrar a medida do ciclo', R)])])],
          [('Não conformidades e tendências, com a evidência', ['etapa 3']),
           (REG_OP, ['Inteligência'])]),
        E('Achar a causa e decidir a ação corretiva', 'Operações', 'Copiloto', 'médio',
          [('Não conformidades e tendências, com a evidência', 'etapa 2'), (ACAO_AB, 'OP-04'), (ACAO_AB, 'OP-07'),
           (LACUNAS_EXEC, 'Identidade'), (LAC_PERC, 'Relações'), (CORRECOES, 'Estratégia'),
           ('Ação que não eliminou a causa', 'etapa 4')],
          [T('Analisar a causa raiz da não conformidade ou da lacuna', A),
           T('Propor a ação corretiva, com dono, prazo e ganho esperado', A),
           T('Decidir a ação corretiva', P),
           D('A ação pede capacidade, agente ou ajuste da oferta?', P,
             [S('Não', 'prox'),
              S('Sim', 'prox', via=[T('Pedir a capacidade ou o agente à Integração, ou o ajuste da oferta à Inteligência', R)])])],
          [('Ação corretiva decidida', ['etapa 4']),
           (NEC_CAP, ['Integração']),
           (PED_AJUSTE, ['Inteligência'])]),
        E('Implantar a ação e conferir o efeito', 'Operações', 'Copiloto', 'baixo',
          [('Ação corretiva decidida', 'etapa 3')],
          [T('Implantar a ação corretiva e treinar quem executa', P),
           T('Medir de novo e conferir se a causa foi eliminada', A),
           D('A ação eliminou a causa?', P,
             [S('Sim', 'prox', via=[T('Registrar a ação e o efeito conferido', R)]),
              S('Não, há outra ação possível', 'E3'),
              S('Não, a causa passa da alçada de Operações', 'prox',
                via=[T('Decidir o que fazer com a causa não eliminada', 'EXE')])])],
          [(LICAO_AP, ['Inteligência']),
           ('Ação que não eliminou a causa', ['etapa 3'])]),
    ]))

# ========================================================== PRODUTO FÍSICO
JORNADAS.append(dict(
    code='OP-06',
    nome='Abastecer e entregar o produto físico: demanda, materiais, produção, estoque e transporte',
    dominio='Produto físico', classe='recomendada', onda=2,
    objetivo='Onde a oferta tem produto físico, fazer a previsão de vendas e os contratos virarem plano de produção e de materiais; cada material ser pedido à Gestão, recebido e inspecionado, e o não conforme recusado e reposto; cada produto ser produzido ou montado, testado pelo procedimento padrão e registrado por lote; cada defeito com risco à saúde ou à segurança ir ao pós-venda; e cada pedido ser guardado, expedido, transportado, recebido pelo cliente e passado à Gestão para faturar. Operações planeja, produz e entrega; a Gestão compra.',
    frequencia='A cada ciclo de planejamento de suprimentos (cadência: mensal) e por contrato com produto assinado',
    automacao=('média', 'Prever, calcular a necessidade, pedir a compra, programar, testar, controlar o estoque, acompanhar o transporte e registrar são de agente e automação; decidir o plano, receber materiais, produzir e expedir são de pessoa de Operações.'),
    base=['apqc'],
    lanes=['NEG', 'GES', 'CLI', P, A, R],
    inicios=[I('Ciclo de planejamento de suprimentos iniciado', R, 'timer'),
             I('Contrato com produto assinado', 'NEG', 'message')],
    fins=[F('Produto entregue, passado a faturar e registrado', R)],
    etapas=[
        E('Prever a demanda e planejar materiais e produção', 'Operações', 'Copiloto', 'médio',
          [(PREVISAO, 'Negócios'), (CONTRATO, 'Negócios'), (OFERTA_CAT, 'Inteligência'), (PLANO_CAP, 'OP-01')],
          [T('Montar a previsão de demanda por produto e conferir com a previsão de vendas e os contratos', A),
           T('Calcular a necessidade de materiais e a capacidade de produção e de estoque', A),
           T('Decidir o plano de produção e de materiais do ciclo', P)],
          [('Plano de produção e de materiais', ['etapa 2', 'etapa 3'])]),
        E('Pedir e receber os materiais e serviços', 'Operações; a compra, com a Gestão', 'Copiloto', 'médio',
          [('Plano de produção e de materiais', 'etapa 1'), (COMPRADOS, 'Gestão')],
          [T('Pedir à Gestão a compra dos materiais e serviços do plano', R),
           T('Fazer a compra e informar a data de entrega', 'GES'),
           T('Receber e inspecionar os materiais e guardá-los', P),
           D('O material recebido está conforme?', P,
             [S('Sim', 'prox'),
              S('Não', 'E2', via=[T('Recusar o material, registrar a falha do fornecedor e pedir a reposição', R)])])],
          [('Pedido de compra de materiais e serviços', ['Gestão']),
           ('Desempenho dos fornecedores na entrega e na qualidade', ['Gestão']),
           ('Materiais disponíveis', ['etapa 3'])]),
        E('Produzir ou montar o produto e testá-lo', 'Operações', 'Copiloto', 'médio',
          [('Plano de produção e de materiais', 'etapa 1'), ('Materiais disponíveis', 'etapa 2')],
          [T('Programar a produção e liberar as ordens por lote', R),
           T('Produzir ou montar o produto', P),
           T('Testar o produto pelo procedimento padrão e registrar o resultado', A),
           D('O produto passou no teste?', A,
             [S('Sim', 'prox'),
              S('Não', 'E3', via=[T('Separar o item, refazer ou descartar e registrar a não conformidade', P)]),
              S('Não: defeito com risco à saúde ou à segurança', 'E3',
                via=[T('Bloquear o lote e levar o defeito ao pós-venda', R)])])],
          [('Produto pronto, com o lote registrado', ['etapa 4']),
           (RISCO_DEF, ['OP-07'])]),
        E('Guardar o produto e entregá-lo ao cliente', 'Operações, com o cliente', 'Copiloto', 'médio',
          [('Produto pronto, com o lote registrado', 'etapa 3')],
          [T('Guardar o produto e controlar o estoque', R),
           T('Preparar e expedir o pedido', P),
           T('Acompanhar o transporte até a entrega', A),
           T('Confirmar o recebimento do produto', 'CLI'),
           T('Registrar a entrega, o lote e o prazo cumprido e passar a faturar', R)],
          [(FATURAR, ['Gestão']),
           (REG_OP, ['Inteligência']),
           (REG_CLI, ['Relações'])]),
    ]))

JORNADAS.append(dict(
    code='OP-07',
    nome='Prestar o pós-venda do produto: devolução, garantia, assistência e recall',
    dominio='Produto físico', classe='recomendada', onda=2,
    objetivo='Onde a oferta tem produto físico, fazer cada pedido de devolução, garantia ou assistência ser conferido contra os termos e os prazos legais, contados pelo tipo de vício; cada vício ser sanado no prazo e, quando não for, resolvido pela escolha do cliente consumidor (troca, devolução do valor ou abatimento); cada defeito com risco à saúde ou à segurança, venha do cliente ou da própria operação, ser comunicado de imediato à autoridade e aos consumidores e virar proposta de recall decidida pelo executivo, acompanhada e encerrada; e cada causa recorrente virar ação corretiva ou cobrança do fornecedor. Operações atende e propõe; a Governança comunica a autoridade; Relações comunica o público; o executivo decide o recall.',
    frequencia='Por evento: pedido de devolução, garantia ou assistência; defeito com risco à saúde ou à segurança',
    automacao=('média', 'Registrar, conferir os termos e prazos, avaliar o risco, acompanhar o recall e analisar a recorrência são de agente e automação; investigar, sanar e cumprir a escolha do cliente são de pessoa de Operações; o recall é do executivo.'),
    base=['apqc', 'cdc', 'cc2002'],
    lanes=['CLI', 'GOV', 'EXE', P, A, R],
    inicios=[I('Pedido de devolução, garantia ou assistência recebido', 'CLI', 'message'),
             I('Defeito com risco detectado na operação', R, 'message')],
    fins=[F('Pedido de pós-venda resolvido e registrado', R),
          F('Pedido fora da garantia respondido e registrado', R)],
    etapas=[
        E('Receber o pedido e avaliar o risco', 'Operações', 'Copiloto', 'médio',
          [('Pedido de devolução, garantia ou assistência', 'Clientes'), (CONTRATO, 'Negócios'),
           (OFERTA_CAT, 'Inteligência')],
          [D('O que iniciou o trabalho?', R,
             [S('Pedido do cliente', 'seg'),
              S('Defeito com risco detectado na operação', 'E3')]),
           T('Registrar o pedido, o produto, o lote e a data de entrega', R),
           T('Triar o relato e apontar os sinais de risco à saúde ou à segurança', A),
           T('Decidir se o defeito relatado pode pôr em risco a saúde ou a segurança', P),
           D('O defeito relatado pode pôr em risco a saúde ou a segurança?', P,
             [S('Não', 'seg'),
              S('Sim, ou há dúvida', 'E3', via=[T('Levar o caso à avaliação de recall', R)])]),
           T('Conferir o pedido contra os termos e os prazos legais, pelo tipo de vício: aparente ou oculto', A),
           D('O pedido está coberto?', A,
             [S('Sim', 'prox'),
              S('Não', 'seg', via=[T('Revisar a negativa de cobertura apontada pelo agente', P)])]),
           D('A negativa de cobertura se confirma?', P,
             [S('Não', 'prox'),
              S('Sim', 'F2', via=[T('Responder ao cliente com o motivo e o caminho para contestar e registrar', R)])])],
          [('Pedido conferido', ['etapa 2']),
           ('Caso levado à avaliação de recall', ['etapa 3'])]),
        E('Sanar o vício ou cumprir a escolha do cliente', 'Operações', 'Assistido', 'médio',
          [('Pedido conferido', 'etapa 1')],
          [T('Receber o produto e investigar o defeito e a causa', P),
           T('Reparar o produto dentro do prazo legal para sanar o vício', P),
           D('O vício foi sanado no prazo?', P,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Escolher a troca, a devolução do valor ou o abatimento do preço', 'CLI'),
                                   T('Cumprir a escolha do cliente', P)])]),
           T('Atribuir o custo: garantia, cliente ou fornecedor', A)],
          [(CREDITO, ['Gestão']),
           ('Solução aplicada ao cliente', ['etapa 5'])]),
        E('Comunicar o risco e decidir o recall', 'Operações propõe; a Governança comunica; o executivo decide', 'Copiloto', 'alto',
          [('Caso levado à avaliação de recall', 'etapa 1'), (RISCO_DEF, 'OP-06'), (ALCADAS, 'Governança')],
          [T('Avaliar a probabilidade e a consequência do risco e os lotes afetados', A),
           T('Comunicar o risco à autoridade competente', 'GOV'),
           T('Pedir a Relações a comunicação aos consumidores', R),
           T('Propor o recall: lotes, clientes, comunicação e solução', P),
           T('Decidir o recall', 'EXE'),
           D('O recall foi decidido?', P,
             [S('Sim', 'prox', via=[T('Recolher os produtos afetados e repará-los ou trocá-los', P)]),
              S('Não', 'E5', via=[T('Registrar a decisão e o motivo', R)])])],
          [(AUTORIDADE, ['Governança']),
           (FATO, ['Relações']),
           ('Recall em curso', ['etapa 4']),
           ('Recall recusado, com o motivo', ['etapa 5'])]),
        E('Acompanhar a eficácia do recall e encerrá-lo', 'Operações, com a Governança', 'Copiloto', 'alto',
          [('Recall em curso', 'etapa 3')],
          [T('Acompanhar os produtos recolhidos e os clientes atendidos', R),
           T('Enviar à autoridade os relatórios do recall', 'GOV'),
           T('Avaliar a eficácia e decidir o encerramento do recall', P)],
          [('Relatórios do recall para a autoridade', ['Governança']),
           ('Recall encerrado, com a eficácia medida', ['etapa 5'])]),
        E('Registrar e tratar a causa', 'Operações', 'Autopiloto', 'baixo',
          [('Solução aplicada ao cliente', 'etapa 2'), ('Recall recusado, com o motivo', 'etapa 3'),
           ('Recall encerrado, com a eficácia medida', 'etapa 4')],
          [T('Registrar o pedido, a causa, a solução, o custo e o prazo', R),
           T('Analisar a recorrência por produto, lote e fornecedor', A),
           D('A causa é recorrente ou grave?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Abrir a ação corretiva na qualidade', R)])]),
           D('A causa vem do fornecedor?', A,
             [S('Não', 'prox'),
              S('Sim', 'prox', via=[T('Pedir à Gestão a cobrança do fornecedor pela falha', R)])])],
          [(REG_OP, ['Inteligência']),
           (PED_RECL, ['Inteligência']),
           (REG_CLI, ['Relações']),
           (ACAO_AB, ['OP-05']),
           ('Pedido de cobrança do fornecedor pela falha', ['Gestão'])]),
    ]))

# -------------------------------------------------------------- domínios
DOMINIOS = [
    ('Capacidade e entrega', 'Capacidade planejada, entrega recorrente a cada cliente e encerramento das entregas.'),
    ('Atendimento e qualidade', 'Atendimento de pedidos e problemas, tratamento de reclamações, padrões, níveis de serviço e ação corretiva.'),
    ('Produto físico', 'Cadeia de suprimentos e pós-venda, só onde a oferta tem produto físico.'),
]

ONDAS = {
    1: 'O que os círculos fechados já esperam de Operações: capacidade, entrega, atendimento, reclamações, qualidade e encerramento',
    2: 'O que só existe onde há produto físico: suprimentos, produção, logística e pós-venda',
}

# ------------------------------------------------- o que usamos de cada fonte
USO = {
    'apqc': 'PCF 7.4. Os processos de Operações estão em três categorias: 4.0, cadeia de suprimentos de produtos físicos (demanda, materiais, produção, teste, armazém e transporte), base da OP-06; 5.0, entrega de serviços (governança da entrega, recursos, início, execução e conclusão), base da OP-01, da OP-02 e da OP-08; e 6.0, atendimento ao cliente (estratégia, contatos, reclamações, devoluções, pós-venda, recall e avaliação), base da OP-03, da OP-04, da OP-05 e da OP-07. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.',
    'iso9001': 'Norma de requisitos para o sistema de gestão da qualidade; a página oficial apresenta a edição de 2026 como a vigente e a de 2015 como retirada. Lemos só a página. Referência geral da OP-05: padrão definido, medida, não conformidade, causa, ação corretiva e efeito conferido. Não usamos nenhum requisito numerado da norma.',
    'iso10002': 'Diretrizes para o tratamento de reclamações em organizações, do planejamento à melhoria. Lemos só o resumo. Referência da OP-04: registrar, confirmar o recebimento, classificar, investigar, responder e tratar a causa.',
    'cdc': 'Código de Defesa do Consumidor, quando o cliente é consumidor. Na OP-04 e na OP-07: o fornecedor responde pelos vícios de qualidade do produto (art. 18) e do serviço (art. 20); não sanado o vício do produto no prazo máximo de trinta dias, o consumidor escolhe a troca, a devolução do valor ou o abatimento (art. 18, § 1º); nesse caso, o consumidor pode usar essas alternativas de imediato quando a troca das partes comprometer o produto ou ele for essencial (art. 18, § 3º); no serviço, escolhe a reexecução, a devolução do valor ou o abatimento (art. 20); o prazo para reclamar de vício aparente é de trinta dias para serviço e produto não duráveis e de noventa dias para serviço e produto duráveis (art. 26, I e II), contado da entrega ou do fim do serviço (art. 26, § 1º) e, no vício oculto, de quando o defeito aparece (art. 26, § 3º); a reclamação obsta a decadência até a resposta negativa, que deve ser transmitida de forma inequívoca (art. 26, § 2º, I), por isso a OP-04 responde por escrito. Na OP-07: quem descobre a periculosidade depois da venda comunica imediatamente as autoridades e os consumidores (art. 10, § 1º), antes e independentemente da decisão de recall.',
    'lgpd': 'Na OP-08: o término do tratamento e a eliminação dos dados pessoais do cliente no fim do contrato (arts. 15 e 16), conforme as regras de sigilo da Governança.',
    'bpmn': 'Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, serviço e script; a tarefa de outro círculo ou papel aparece como tarefa simples.',
    'camunda': 'Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.',
    'sipoc': 'Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.',
    'cc2002': 'Na OP-07, quando o cliente é empresa e não consumidor: a coisa com vício oculto pode ser enjeitada (art. 441) ou ter o preço abatido (art. 442); o prazo para isso é de trinta dias para coisa móvel, contado da entrega, e, se o vício só puder ser conhecido mais tarde, conta da ciência, até cento e oitenta dias (art. 445); na garantia contratual os prazos não correm, mas o defeito deve ser denunciado em trinta dias da descoberta (art. 446). O contrato entre empresas presume-se paritário e a alocação de riscos combinada é respeitada (art. 421-A).',
    'l14133': 'Na OP-02, contrato público: o objeto é recebido provisoriamente pelo fiscal e definitivamente por servidor ou comissão, com termo detalhado, e pode ser rejeitado no todo ou em parte (art. 140). A OP-02 trata os dois recebimentos como aceite do cliente.',
}

# ----------------------------------- cobertura do referencial (APQC PCF 7.4)
COBERTURA = [
    ('4.1.1', 'Develop production and materials strategies', 'Em parte: o plano de produção e de materiais do ciclo (OP-06, etapa 1). As políticas de produção não têm etapa própria: ficam como limite'),
    ('4.1.2', 'Manage demand for products', 'OP-06, etapa 1'),
    ('4.1.3', 'Create materials plan', 'OP-06, etapa 1'),
    ('4.1.4', 'Create and manage master production schedule', 'OP-06, etapas 1 e 3'),
    ('4.1.5', 'Plan distribution requirements', 'Limite: não desenhado como etapa própria'),
    ('4.1.6', 'Establish distribution planning constraints', 'Limite: não desenhado como etapa própria'),
    ('4.1.7', 'Review distribution planning policies', 'Limite: não desenhado como etapa própria'),
    ('4.1.8', 'Develop quality standards and procedures', 'OP-05, etapa 1'),
    ('4.2', 'Procure materials and services', 'Fora: a Gestão compra. Operações pede, recebe e inspeciona (OP-06, etapa 2) e informa o desempenho dos fornecedores'),
    ('4.3.1', 'Schedule production', 'OP-06, etapa 3. A manutenção preventiva e a não planejada (4.3.1.5 e 4.3.1.6) não têm etapa própria: ficam como limite'),
    ('4.3.2', 'Produce/Assemble product', 'OP-06, etapa 3'),
    ('4.3.3', 'Perform quality testing', 'OP-06, etapa 3'),
    ('4.3.4', 'Maintain production records and manage lot traceability', 'OP-06, etapas 3 e 4'),
    ('4.4.1', 'Provide logistics governance', 'Limite: não desenhado como etapa própria'),
    ('4.4.2', 'Plan and manage inbound material flow', 'OP-06, etapa 2. O fluxo de produtos devolvidos (4.4.2.4) fica na OP-07'),
    ('4.4.3', 'Operate warehousing', 'OP-06, etapas 2 e 4'),
    ('4.4.4', 'Operate outbound transportation', 'OP-06, etapa 4'),
    ('5.1.1', 'Establish service delivery governance', 'OP-05 (procedimentos, níveis de serviço e desempenho da entrega)'),
    ('5.1.2', 'Develop service delivery strategies', 'OP-01 e OP-05, etapa 1'),
    ('5.2.1', 'Manage service delivery resource demand', 'OP-01, etapa 1'),
    ('5.2.2', 'Create and manage resource plan', 'OP-01, etapas 2 e 3'),
    ('5.2.3', 'Enable service delivery resources', 'Em parte: o treino ligado à ação corretiva (OP-05, etapa 4). O desenvolvimento das pessoas é da Gestão'),
    ('5.3.1', 'Initiate service delivery', 'OP-02, etapa 1'),
    ('5.3.2', 'Execute service delivery', 'OP-02, etapa 2'),
    ('5.3.3', 'Complete service delivery', 'OP-02, etapas 3 e 4, para o ciclo; OP-08, para o fim do contrato'),
    ('6.1.1', 'Define customer service requirements across the enterprise', 'Em parte: OP-05, etapa 1, a partir da experiência definida por Relações'),
    ('6.1.2', 'Define customer service experience', 'Fora: Relações define a experiência (RE-04); Operações a traduz em procedimentos (OP-05)'),
    ('6.1.3', 'Define and manage customer service channel strategy', 'Limite: os canais de atendimento não têm etapa própria; os pontos de contato estão no mapa da jornada de Relações (RE-04)'),
    ('6.1.4', 'Define customer service policies and procedures', 'OP-05, etapa 1'),
    ('6.1.5', 'Establish target service level for each customer segment', 'OP-05, etapa 1'),
    ('6.1.6', 'Define warranty claims', 'Limite: a política de garantia faz parte dos termos da oferta (IN-07) e não tem etapa própria em Operações'),
    ('6.1.7', 'Develop recall strategy', 'Em parte: o recall de cada caso (OP-07, etapa 3). Uma estratégia de recall prévia não tem etapa própria: fica como limite'),
    ('6.2.1', 'Plan and manage customer service work force', 'OP-01, junto com o resto da capacidade'),
    ('6.2.2', 'Manage customer service problems, requests, and inquiries', 'OP-03'),
    ('6.2.3', 'Manage customer complaints', 'OP-04'),
    ('6.2.4', 'Process returns', 'OP-07, etapas 1 e 2'),
    ('6.2.5', 'Report incidents and risks to regulatory bodies', 'OP-04, etapa 1, e OP-07, etapa 3, com a Governança'),
    ('6.3.1', 'Register products', 'Limite: não desenhado como etapa própria; o lote é registrado na OP-06'),
    ('6.3.2', 'Process warranty claims', 'OP-07, etapas 1 e 2'),
    ('6.3.3', 'Manage supplier recovery', 'OP-07, etapa 5, com a Gestão'),
    ('6.3.4', 'Service products', 'OP-07, etapa 2'),
    ('6.4', 'Manage product recalls and regulatory audits', 'OP-07, etapas 3 e 4'),
    ('6.5', 'Evaluate customer service operations and customer satisfacion', 'OP-05, etapa 2; a avaliação do cliente é colhida na OP-03 e a saúde do cliente é medida por Relações (RE-05). A avaliação do recall (6.5.5) fica na OP-07, etapa 4. O nome está como no referencial, com a grafia dele'),
]

# --------------------------------------------------- o que Operações não faz
FRONTEIRAS = [
    ('Mudar jornadas, sistemas e agentes; implantar o cliente; coordenar lançamento e saída', 'Integração',
     'A necessidade de capacidade nova ou mudada (OP-01 e OP-05) e o pedido ou incidente de tecnologia (OP-03). Recebe o cliente implantado, o plano de lançamento e o plano de saída.'),
    ('Comprar, contratar pessoas e faturar', 'Gestão',
     'O plano de capacidade (OP-01), as entregas confirmadas para faturar (OP-02 e OP-06), o crédito, o reembolso ou a troca (OP-04 e OP-07), o pedido de compra e o desempenho dos fornecedores (OP-06), a cobrança do fornecedor (OP-07) e os recursos liberados (OP-08).'),
    ('Definir a experiência do cliente e acompanhar o sucesso de cada cliente', 'Relações',
     'Os registros do cliente (OP-02, OP-03, OP-06, OP-07 e OP-08), as reclamações com a causa e a lacuna de experiência (OP-04 e OP-05) e o fato a comunicar no recall (OP-07).'),
    ('Vender, renovar, ampliar e cancelar contratos', 'Negócios',
     'O pedido comercial do cliente recebido no atendimento é passado a Negócios dentro da OP-03.'),
    ('Desenhar a oferta, o método e a base de conhecimento; medir os indicadores', 'Inteligência',
     'Os registros de entrega, atendimento e qualidade, os pedidos e reclamações, o conteúdo que faltou, as lições e o pedido de ajuste de oferta em uso.'),
    ('Definir a alçada, as regras de sigilo e comunicar a autoridade', 'Governança',
     'O incidente ou risco a comunicar à autoridade (OP-04 e OP-07); a conferência do dever de comunicar no recall (OP-07).'),
    ('Decidir o que passa da alçada de Operações e o recall', 'Executivo da empresa',
     'A cobertura de capacidade (OP-01), a solução de reclamação (OP-04) e o recall (OP-07).'),
    ('Participar das jornadas de outros círculos', 'Operações, como tarefa nas jornadas de outros círculos',
     'Confirmar a capacidade (NE-02, NE-03, NE-05, NE-06, IN-07, IT-02 e IT-03), com o plano e o mapa da OP-01; dizer se a operação cumpre os padrões de experiência (RE-04); entregar o piloto ao cliente e fechar o roteiro de entrega (IN-07, etapas 6 e 7), sem abrir a OP-02; implantar junto com a Integração (IT-02); propor o fim das entregas no plano de saída (IT-04), que a OP-08 executa.'),
]

# -------------------------------------------------------- pontos para decidir
PONTOS = []
DECISOES = [
    ('Operações decide o seu ofício; o executivo decide o que passa da alçada e o recall',
     'Ponto 1, aprovado por você (11:50 de 03/10/2026)',
     'Plano de capacidade, plano de entrega, procedimentos e níveis de serviço, solução de reclamação dentro da alçada e ação corretiva são de Operações. Segue a regra dos outros círculos: o executivo decide só o que passa da alçada.'),
    ('Relações define os padrões de experiência; Operações define os níveis de serviço',
     'Ponto 2, aprovado por você (11:50)',
     'OP-05, etapa 1: Operações traduz a experiência e o método em procedimentos e níveis de serviço por oferta e por segmento. O padrão que não consegue cumprir volta a Relações como lacuna.'),
    ('Operações trata todas as reclamações sobre entrega e atendimento',
     'Ponto 3, aprovado por você (11:50)',
     'OP-04. Relações recebe cada reclamação com a causa (RE-04 e RE-08); a Governança avalia o risco legal e o dever de comunicar a autoridade.'),
    ('Operações confirma a entrega; a Gestão fatura e compra',
     'Ponto 4, aprovado por você (11:50)',
     'Como diz o documento-base: Operações não fatura. OP-02 e OP-06 passam as entregas confirmadas a faturar; OP-06 pede a compra dos materiais.'),
    ('O pedido comercial que chega ao atendimento vai a Negócios sem passar por Relações',
     'Ponto 5, aprovado por você (11:50)',
     'OP-03, etapa 1: tarefa de Negócios, que o trata na proposta ou no contrato (NE-03 e NE-06). Nenhuma mudança nos círculos fechados.'),
    ('Produto físico em duas jornadas recomendadas',
     'Ponto 6, aprovado por você (11:50)',
     'OP-06 e OP-07 só existem onde a oferta tem produto físico. O recall é decidido pelo executivo.'),
    ('Oito jornadas', 'Ponto 7, aprovado por você (11:50)', 'OP-01 a OP-08.'),
    ('A IT-04 recebe de Operações as entregas encerradas na saída', 'Proposta ao círculo 6, aprovada por você (11:50)',
     'IT-04, etapa 2: a conclusão da parte de Operações passa a ser uma entrada, vinda da OP-08, etapa 3.'),
    ('Auditoria de execução: modo de cada etapa e nível de automação pelo que as tarefas fazem',
     'Itens 1 a 14 da auditoria, aprovados por você (12:33 de 03/10/2026)',
     'OP-08 etapa 3: a automação registra a liberação de pessoas, agentes, parceiros e ativos (item 4). OP-07 etapa 1: o agente faz a triagem e a pessoa de Operações decide se há risco à saúde ou à segurança; na dúvida, vai à avaliação de recall. A negativa de cobertura apontada pelo agente é revisada pela pessoa antes da resposta ao cliente. O modo passa de Autopiloto a Copiloto (itens 5 e 6). De Assistido para Copiloto, pelas tarefas: OP-07 etapa 3. De Autopiloto para Autômato, pelas tarefas: OP-01 etapa 3. De Copiloto para Assistido, pelas tarefas: OP-08 etapa 2, OP-07 etapa 2. Nível de automação pela faixa: OP-02 média → alta; OP-05 média → alta.'),
    ('Fontes do pós-venda entre empresas e do recebimento público',
     'Pedido seu (13:09 de 03/10/2026): pesquisar e resolver as fontes',
     'OP-07: Código Civil, arts. 421-A e 441 a 446; OP-02: Lei 14.133, art. 140. Conferidos no texto oficial (Planalto), em 03/10/2026.'),
    ('Alçadas de Operações',
     'Aprovado por você (13:51 de 03/10/2026)',
     'Falta de capacidade: Operações cobre com pessoas e parceiros já contratados, dentro do orçamento; contratação nova ou fora do orçamento vai ao executivo pela GE-01. Reclamação: Operações refaz e dá crédito até o valor faturado da entrega reclamada; acima, ou com responsabilidade e indenização, o executivo com a Governança.'),
    ('Cadências e conteúdos validados; gates de implantação',
     'Validado por você (14:07 de 03/10/2026)',
     'OP-01 trimestral; OP-05 e OP-06 mensais; procedimento, três níveis de serviço e garantia por oferta. O que depende de dado real ficou nos gates G1 a G9.'),
    ('Correções da auditoria geral',
     'Aprovado por você (16:05 de 03/10/2026)',
     'OP-02, etapa 2: as entregas do cliente suspenso por atraso, por decisão do executivo na GE-03, são suspensas e avisadas (M7). OP-04, etapa 2: acima da alçada, a Governança avalia a responsabilidade e o risco antes da decisão do executivo (M1).'),
]

PROPOSTAS = []

ALERTAS = [
    ('Gestão (círculo 8)', 'Operações espera da Gestão as pessoas, as compras e os ativos do plano de capacidade, confirmados; os materiais comprados com a data de entrega; a fatura das entregas confirmadas; o crédito ou o reembolso aprovado e a cobrança do fornecedor. Entrega o plano de capacidade, as entregas confirmadas para faturar, o pedido de compra, o desempenho dos fornecedores e os recursos liberados.'),
    ('Governança (círculo 9)', 'Operações espera as regras e alçadas vigentes e as regras de sigilo e de dados pessoais, a avaliação do risco legal da reclamação, a comunicação do risco do produto à autoridade e os relatórios do recall. Entrega o incidente ou risco a comunicar à autoridade e os relatórios do recall para a autoridade.'),
]

# ------------------------------------------------ relação com o catálogo da rodada 2
MUDANCAS = [
    ('Ajustado', 'I-OP1 · Da demanda à capacidade de entrega', 'OP-01',
     'Ganha o plano usado para confirmar propostas, implantações e lançamentos, a decisão do executivo acima da alçada e o pedido de capacidade à Integração.'),
    ('Ajustado', 'V5 · Da entrega ao recebimento', 'OP-02',
     'A entrega recorrente de cada cliente, com aceite e confirmação a faturar; o faturamento e o recebimento ficam na Gestão.'),
    ('Ajustado', 'V6 · Do chamado à solução', 'OP-03',
     'Atendimento com triagem: o problema de tecnologia vai à Integração, a reclamação à OP-04 e o pedido comercial a Negócios.'),
    ('Acrescentado', 'Sem equivalente', 'OP-04',
     'Tratamento de reclamações como jornada própria, pedido por Relações (RE-04 e RE-08) e pela Inteligência (IN-03).'),
    ('Ajustado', 'I-OP2 · Da inspeção à qualidade garantida', 'OP-05',
     'Ganha os procedimentos e os níveis de serviço tirados da experiência de Relações e a ação corretiva conferida.'),
    ('Ajustado', 'V8 · Da previsão ao produto entregue', 'OP-06',
     'Mantida só onde há produto físico, com a compra na Gestão.'),
    ('Acrescentado', 'Sem equivalente', 'OP-07',
     'Pós-venda do produto físico: devolução, garantia, assistência e recall.'),
    ('Acrescentado', 'Sem equivalente', 'OP-08',
     'Encerramento das entregas, pedido pela Integração (IT-04) e por Negócios (NE-06).'),
]

LIMITES = [
    'Os fluxos são descritivos. Para executar falta escolher o motor e ligar cada tarefa a um sistema.',
    'Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado. Os únicos prazos citados são os da lei (CDC e Código Civil), com a fonte.',
    'As cadências foram validadas em 03/10/2026 (aba Parâmetros em aberto); o líder do círculo ajusta na implantação e a calibração com dados é o gate G9.',
    'Os rascunhos de procedimentos, níveis de serviço e garantia foram validados em 03/10/2026 (aba Gates de implantação); o texto final é o gate G8, e os números que dependem de dado real ficam nos gates G3 e G9.',
    'O CDC vale quando o cliente é consumidor. Contrato entre empresas segue o que foi contratado e o Código Civil (arts. 421-A e 441 a 446), conferido no texto oficial (Planalto) em 03/10/2026.',
    'Uma estratégia de recall prévia (APQC 6.1.7), a manutenção de equipamentos (APQC 4.3.1.5 e 4.3.1.6), o planejamento da distribuição (4.1.5 a 4.1.7), a governança da logística (4.4.1), o registro de produtos (6.3.1) e a estratégia de canais de atendimento (6.1.3) não têm etapa própria.',
    'No contrato público, o recebimento provisório e o definitivo seguem o art. 140 da Lei 14.133, conferido no texto oficial: em obras e serviços, o provisório é do fiscal e o definitivo de servidor ou comissão, com termo detalhado; em compras, o provisório é sumário; os prazos ficam no contrato. A OP-02 trata os dois como aceite do cliente.',
    'Quando a ação corretiva conclui, quem apontou a lacuna (Identidade, Relações ou Estratégia) vê o efeito pelo painel da Inteligência: os círculos fechados não têm entrada para um aviso direto.',
    'A recusa de capacidade no plano chega a Negócios pela confirmação de capacidade feita nas jornadas de Negócios e ao executivo pelo plano publicado; Negócios não recebe o plano como entrada.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024. Da ISO 9001 lemos só a página oficial; da ISO 10002, só o resumo.',
    'Onde faltava o outro lado, a proposta à IT-04 foi aprovada e aplicada. Com os nove círculos fechados (03/10/2026), as trocas com os outros oito foram conferidas dos dois lados pelo nome: 409 trocas, sem problema.',
    'A tarefa de quem não é do círculo (cliente, executivo, Negócios, Gestão, Governança) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As aprovações e conferências sem decisão desenhada não têm ramo de recusa: a recusa devolve o trabalho a quem preparou.',
    'As saídas estão listadas por etapa, não por caminho: o pedido à Integração, à Identidade ou à Inteligência só sai quando a decisão pede.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das oito jornadas, conferiu os 33 códigos e nomes do APQC PCF 7.4 (todos conferem) e os artigos do CDC no Planalto, e apontou 18 achados, 3 graves: a ordem da saída invertida em relação à IT-04 e à ES-04, a comunicação à autoridade presa à decisão de recall e a escolha do consumidor no vício do produto e do serviço tratada como decisão de Operações.',
    'Todos foram corrigidos ou declarados como limite, e a versão corrigida passou por todos os testes automáticos. A segunda versão não passou por nova revisão independente.',
]
