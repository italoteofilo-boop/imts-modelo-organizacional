# -*- coding: utf-8 -*-
"""Círculo 8 · Gestão. Fechado em 03/10/2026, aprovado às 11:50: treze jornadas.
Regra do círculo: a Gestão decide o que é do seu ofício (o desdobramento e o controle do orçamento aprovado, o ritual de
acompanhamento, a cobrança, a compra, o fechamento das contas, a aplicação do rateio e os processos de pessoas), dentro
da alçada. Os sócios aprovam alvos e orçamento; o executivo decide o que passa da alçada da Gestão e o líder decide a
contratação na sua equipe; a Governança define as alçadas, o critério de rateio e as regras e guarda os contratos. O desligamento é decidido pelo executivo, com o líder."""
from dsl import configurar, T, PAR, S, D, E, I, F, TODOS

NUM, NOME, SIGLA, PREF = 8, 'Gestão', 'GE', 'GE'
LANES, PARTES = configurar(NOME, SIGLA, PREF)
SLUG = 'circulo8-gestao'
FECHADO = True
STATUS = 'Fechado em 03/10/2026, aprovado às 11:50 · auditoria de execução aplicada em 03/10/2026'
LEAD = ('A Gestão garante os recursos e a rotina. Desdobra e controla o orçamento aprovado, roda o ritual de acompanhamento '
        'dos alvos, fatura e recebe, compra e paga, fecha as contas e os impostos, aplica o rateio entre as empresas e '
        'cuida das pessoas: provê, integra à cultura, avalia, desenvolve, paga, reconhece e comunica para dentro. Cuida '
        'também dos ativos. Não define as regras nem escolhe o rumo. São treze jornadas.')
PRINCIPIO = ('Regra do círculo, aprovada por você às 11:50 de 03/10/2026: a Gestão decide o que é do seu ofício '
             '(o desdobramento e o controle do orçamento aprovado, o ritual de acompanhamento, a cobrança, a compra, o '
             'fechamento das contas, a aplicação do rateio e os processos de pessoas), dentro da alçada. Os sócios aprovam '
             'alvos e orçamento; o executivo decide o que passa da alçada da Gestão; o líder decide a contratação na sua '
             'equipe; o desligamento é decidido pelo executivo, com o líder; a Governança define as alçadas, o critério de '
             'rateio e as regras e guarda os contratos.')
MUDOU_INTRO = ('Comparação com o catálogo da rodada 2 (49 jornadas e 216 workflows), que continua no documento do '
               'projeto até cada círculo ser fechado. Azul: acrescentado. Verde: ajustado. Vermelho: retirado.')
COBERTURA_TXT = ('Processos do APQC PCF 7.4 ligados às funções da Gestão (categorias 7.0, 9.0 e 10.0 e o grupo 4.2), '
                 'grupo a grupo: onde cada um está neste modelo. Os nomes estão como no referencial.')

P, A, R = 'GEP', 'GEA', 'GER'

# produtos da Gestão esperados pelos círculos fechados (nomes exatos)
PESQUISA = 'Resultado da pesquisa de cultura e dados de pessoas'
DESVIOS = 'Desvios e decisões do ritual de acompanhamento'
EXEC_ORC = 'Execução do orçamento e da alocação por empresa, oferta e aposta'
CAIXA = 'Posição e projeção de caixa'
RESULTADO = 'Resultado por empresa e consolidado'
MARGENS = 'Custos e margens por empresa e oferta'
ORC_DEM = 'Orçamento de demanda do ciclo'
RESP_REC = 'Resposta ao pedido de recurso adicional'
SIT_FAT = 'Situação de faturas e pagamentos do cliente'
COMPRADOS = 'Materiais e serviços comprados, com a data de entrega'
RECURSOS_OK = 'Pessoas, compras e ativos do plano confirmados'
# pedidos aceitos pelos círculos fechados de qualquer origem
PED_TEC = 'Pedido, incidente ou risco de tecnologia'
CONSULTA = 'Consulta sobre caso não coberto'
# produtos internos usados em mais de uma jornada
ORC_VIG = 'Orçamento vigente por empresa, círculo, oferta e aposta'
RATEIO = 'Rateio do custo dos círculos por empresa'
CONTRATADA = 'Pessoa contratada, com papel e líder'
MUD_PESSOAS = 'Mudança de pessoas registrada'
INTEGRADA = 'Integração cultural concluída, com o resultado da verificação'
RECONHEC = 'Reconhecimentos concedidos'
PARTICIP = 'Registro de participação em rituais'
HISTORIAS = 'Histórias e reconhecimentos a comunicar'
RECEITAS = 'Receitas faturadas e recebidas'
PAGOS = 'Pagamentos a fornecedores e parceiros realizados'
FOLHA = 'Folha e encargos pagos'
ATIVOS = 'Registro de ativos atualizado, com depreciação e baixas'
PED_COMPRA = 'Pedido de compra'
MUD_REMUN = 'Mudanças de remuneração aprovadas'
# produtos de outros círculos
KIT = 'Kit de cultura e pessoas'
VENCIDOS = 'Aviso de materiais vencidos'
LACUNAS_EXEC = 'Lacunas de execução apontadas'
MARCA_RET = 'Marca retirada de uso'
PACOTE_MARCA = 'Pacote de marca publicado'
MUD_DECL = 'Mudança na declaração a comunicar'
MUD_PADROES = 'Mudança nos padrões a comunicar'
POSIC = 'Posicionamento e casa de mensagens vigentes'
RESUMO_PAD = 'Resumo da avaliação dos padrões'
PADROES_ID = 'Padrões de identidade vigentes'
RESPOSTA_ID = 'Resposta à consulta'
ALOCACAO = 'Alocação de recursos por empresa, oferta e aposta'
ALVOS = 'Alvos e iniciativas do ciclo'
AP_ESPERA = 'Aposta em espera ou devolvida'
AP_MANTIDA = 'Aposta mantida depois da revisão'
CORRECOES = 'Correções de execução publicadas, com dono e prazo'
DATA_SAIDA = 'Data de saída confirmada da aposta ou da oferta encerrada'
DEC_ALOC = 'Decisão de alocação e de destino do resultado'
DEC_SOCIOS = 'Decisão dos sócios sobre alvos e orçamento'
LISTA_ADQ = 'Lista de pessoas da empresa adquirida'
MANDATO = 'Mandato da empresa'
MUD_EST = 'Mudança na estratégia a comunicar'
METODO_EST = 'Método de estratégia vigente: critérios dos portões, regras de realocação e calendário'
PED_CORRECAO = 'Pedido de plano de correção'
PORTFOLIO = 'Portfólio de empresas atualizado'
REC_APOSTA = 'Recursos aprovados para a aposta'
REC_DEVOLVER = 'Recursos da aposta encerrada a devolver'
REV_SEM = 'Revisão sem correção registrada'
OFERTA_FORA = 'Aposta ou oferta encerrada e fora do catálogo de ofertas'
AP_DEVOLVIDA = 'Aviso de aposta devolvida, com recursos e projeto suspensos até a decisão da Estratégia'
INDICADORES = 'Indicadores e análises por empresa, oferta e aposta'
REV_IND = 'Resultado da revisão dos indicadores, com as contestações de indicador de alvo vigente'
PAINEL = 'Painel de indicadores de cada círculo, com dono e análise'
CONT_EXT = 'Conteúdo externo publicado'
PED_REC = 'Pedido de recurso adicional para demanda'
PLANO_DEM = 'Plano de demanda do ciclo: públicos, ofertas, canais, ações, alvos e orçamento'
ACORDO_CONJ = 'Acordo de oferta conjunta entre as empresas'
ATA = 'Ata de registro de preços vigente, com saldo e órgãos participantes'
CONTRATO = 'Contrato de cliente assinado, com o escopo vendido'
CONTR_FIM = 'Contrato encerrado, com a data de fim'
CONTR_SAIDA = 'Contratos encerrados ou transferidos na saída'
DESVIO_PREV = 'Desvio da previsão contra os alvos, com as ações'
PLANO_VENDAS = 'Plano de vendas do ciclo: alvos por empresa, oferta e canal'
PREVISAO = 'Previsão de receita e de vendas'
TABELA = 'Tabela de preços e política comercial vigentes'
VENCIMENTO = 'Vencimento do contrato e resultado da renovação'
CLI_IMPL = 'Cliente implantado e aceito, passado à entrega'
CUSTO_TEC = 'Custo de tecnologia por empresa e por círculo'
IMPEDIMENTO = 'Impedimento do lançamento, com as opções'
OFERTA_LANCADA = 'Oferta lançada'
PLANO_IMPL = 'Plano de implantação do cliente'
PLANO_LANC = 'Plano de lançamento da oferta'
SAIDA_CLI = 'Plano de saída de clientes e contratos'
PROJ_ENC = 'Projeto encerrado, com o resultado'
REC_LIB_IT = 'Recursos liberados de projeto suspenso ou encerrado'
SITUACAO = 'Situação das iniciativas na carteira de projetos'
CREDITO = 'Crédito ou reembolso aprovado para o cliente'
DESEMP_FORN = 'Desempenho dos fornecedores na entrega e na qualidade'
FATURAR = 'Entregas confirmadas para faturar, com a medição dos níveis de serviço'
COBRANCA_FORN = 'Pedido de cobrança do fornecedor pela falha'
PED_COMPRA_OP = 'Pedido de compra de materiais e serviços'
PLANO_CAP = 'Plano de capacidade de entrega: pessoas, parceiros, materiais e ativos'
REC_LIB_OP = 'Recursos da operação liberados, com a data'
ALCADAS = 'Regras e alçadas vigentes'
SIGILO = 'Regras de sigilo e de dados pessoais'
CRITERIO_RATEIO = 'Critério de rateio do custo dos círculos'

JORNADAS = []

# ========================================================== PLANEJAMENTO E CONTROLE
JORNADAS.append(dict(
    code='GE-01',
    nome='Desdobrar o orçamento aprovado e controlar as mudanças de recurso',
    dominio='Planejamento e controle', classe='essencial', onda=1,
    objetivo='Fazer o orçamento aprovado pelos sócios ser desdobrado por empresa, círculo, oferta, aposta e conta, com um dono por linha; os planos de demanda, de vendas, de capacidade e de lançamento caberem nele ou terem a diferença apontada; cada pedido de recurso, liberação, congelamento ou devolução ser decidido na alçada, pela Gestão ou, acima dela, pelo executivo (recurso da empresa), pelo Administrador do IMTS.OS (recurso dos círculos compartilhados) ou pelos sócios (aumento do total aprovado); e o orçamento vigente ser publicado a quem executa. Os sócios aprovam; a Gestão desdobra e controla; a realocação entre empresas fica na revisão do portfólio da Estratégia.',
    frequencia='A cada ciclo de orçamento, depois da aprovação dos sócios, e por evento: pedido de recurso, aposta aprovada, devolvida ou encerrada, projeto suspenso, recurso liberado',
    automacao=('média', 'Desdobrar, conferir os planos com o orçamento, calcular o efeito e publicar são de agente e automação; fechar o desdobramento e decidir dentro da alçada são de pessoa da Gestão; acima da alçada, do executivo, do Administrador do IMTS.OS ou dos sócios.'),
    base=['apqc'],
    lanes=['EST', 'SOC', 'ADM', 'EXE', P, A, R],
    inicios=[I('Alvos e orçamento aprovados pelos sócios', 'EST', 'message'),
             I('Pedido de recurso, liberação ou devolução recebido', R, 'message')],
    fins=[F('Orçamento vigente publicado', R)],
    etapas=[
        E('Desdobrar o orçamento aprovado e conferir os planos', 'Gestão', 'Copiloto', 'médio',
          [(DEC_SOCIOS, 'Estratégia'), (ALVOS, 'Estratégia'), (ALOCACAO, 'Estratégia'), (METODO_EST, 'Estratégia'),
           (PLANO_VENDAS, 'Negócios'), (PREVISAO, 'Negócios'), (PLANO_DEM, 'Relações'), (PLANO_CAP, 'Operações'),
           (SITUACAO, 'Integração'), (CUSTO_TEC, 'Integração'), (PLANO_LANC, 'Integração'), (RATEIO, 'GE-06')],
          [D('O que iniciou o trabalho?', R,
             [S('Orçamento do ciclo aprovado', 'seg'),
              S('Pedido de recurso, liberação ou devolução', 'E2')]),
           T('Desdobrar o orçamento por empresa, círculo, oferta, aposta e conta, com um dono por linha', A),
           T('Conferir os planos de demanda, vendas, capacidade e lançamento com o orçamento', A),
           T('Fechar o orçamento desdobrado e apontar a cada dono o que não coube', P),
           D('Há pedido de recurso em aberto para decidir agora?', R,
             [S('Não', 'E3'),
              S('Sim', 'prox')])],
          [('Orçamento desdobrado, com dono por linha', ['etapa 3']),
           (ORC_DEM, ['Relações']),
           (RECURSOS_OK, ['Operações'])]),
        E('Decidir pedidos de recurso, liberações e devoluções', 'Gestão; acima da alçada, o executivo, o Administrador do IMTS.OS ou os sócios', 'Copiloto', 'médio',
          [(PED_REC, 'Relações'), (REC_APOSTA, 'Estratégia'), (REC_DEVOLVER, 'Estratégia'), (AP_ESPERA, 'Estratégia'),
           (AP_MANTIDA, 'Estratégia'), (DATA_SAIDA, 'Estratégia'), (AP_DEVOLVIDA, 'Inteligência'),
           (OFERTA_FORA, 'Inteligência'), (IMPEDIMENTO, 'Integração'), (REC_LIB_IT, 'Integração'),
           (REC_LIB_OP, 'Operações'), (ALCADAS, 'Governança'), (PED_REC, 'GE-02')],
          [T('Registrar o pedido, a liberação ou a decisão e a linha do orçamento afetada', R),
           T('Calcular o efeito no orçamento e no caixa', A),
           T('Conferir o efeito e a alçada do pedido', P),
           D('Quem decide o pedido?', P,
             [S('A Gestão: cabe na alçada, ou é liberação, congelamento ou devolução já decidida', 'seg',
                via=[T('Decidir o pedido dentro da alçada da Gestão', P)]),
              S('O executivo: recurso da empresa acima da alçada da Gestão', 'seg',
                via=[T('Decidir o pedido acima da alçada da Gestão', 'EXE')]),
              S('O Administrador do IMTS.OS: recurso de círculo compartilhado, ou entre círculos, acima da alçada da Gestão', 'seg',
                via=[T('Decidir o pedido de recurso dos círculos acima da alçada da Gestão', 'ADM')]),
              S('Os sócios: aumenta o total do orçamento aprovado', 'seg',
                via=[T('Decidir o aumento do total do orçamento aprovado', 'SOC')]),
              S('A Estratégia: mexe na alocação entre empresas', 'seg',
                via=[T('Registrar o pedido para a revisão do portfólio e avisar quem pediu', R)])]),
           D('O pedido foi atendido?', P,
             [S('Sim, no todo ou em parte', 'seg', via=[T('Ajustar o orçamento', R)]),
              S('Não', 'seg')]),
           T('Responder a quem pediu, com o motivo', R)],
          [(RESP_REC, ['Relações']),
           ('Decisão sobre o recurso pedido, com o motivo', ['Executivos', 'Líderes dos círculos', 'Administrador do IMTS.OS']),
           ('Orçamento ajustado', ['etapa 3'])]),
        E('Publicar o orçamento vigente', 'Gestão', 'Autômato', 'baixo',
          [('Orçamento desdobrado, com dono por linha', 'etapa 1'), ('Orçamento ajustado', 'etapa 2')],
          [T('Publicar o orçamento vigente a cada dono e aos registros de compra e de pagamento', R)],
          [(ORC_VIG, ['Executivos', 'Líderes dos círculos', 'GE-02', 'GE-04', 'GE-05', 'GE-07', 'GE-12'])]),
    ]))

JORNADAS.append(dict(
    code='GE-02',
    nome='Rodar o ritual de acompanhamento dos alvos e cobrar as ações',
    dominio='Planejamento e controle', classe='essencial', onda=1,
    objetivo='Fazer cada período ter os resultados reunidos contra os alvos, com a execução do orçamento, os desvios e as causas prováveis; cada desvio ser discutido com o dono no ritual e ter uma ação com dono e prazo, decidida na alçada; cada pedido de plano de correção e cada correção publicada pela Estratégia entrar na pauta; e cada ação ser cobrada até concluir, com o atraso levado ao executivo. A Gestão roda o ritual; os donos decidem as ações; a Estratégia decide a correção de rumo.',
    frequencia='No calendário do método de estratégia (cadência: mensal) e por evento: pedido de plano de correção',
    automacao=('alta', 'Reunir, apontar desvios, registrar e cobrar são de agente e automação; conduzir o ritual é de pessoa da Gestão; propor e decidir as ações é dos líderes e do executivo.'),
    base=['apqc'],
    lanes=['EST', 'LCI', 'EXE', P, A, R],
    inicios=[I('Período do ritual de acompanhamento iniciado', R, 'timer'),
             I('Pedido de plano de correção recebido', 'EST', 'message')],
    fins=[F('Ritual realizado e ações acompanhadas', R),
          F('Ritual realizado, com ação em atraso levada ao executivo', R)],
    etapas=[
        E('Reunir os resultados do período contra os alvos', 'Gestão, com a Inteligência', 'Autopiloto', 'baixo',
          [(ALVOS, 'Estratégia'), (METODO_EST, 'Estratégia'), (INDICADORES, 'Inteligência'), (REV_IND, 'Inteligência'),
           (PAINEL, 'Inteligência'), (DESVIO_PREV, 'Negócios'), (SITUACAO, 'Integração'), (PROJ_ENC, 'Integração'),
           (ORC_VIG, 'GE-01'), (EXEC_ORC, 'GE-05'), ('Ações em atraso do ritual', 'etapa 3')],
          [T('Reunir indicadores, execução do orçamento, iniciativas e desvios do período', R),
           T('Apontar os desvios, as causas prováveis e os donos', A)],
          [('Pauta do ritual com os desvios e os donos', ['etapa 2'])]),
        E('Conduzir o ritual e registrar as decisões', 'Gestão conduz; o líder decide na alçada; acima dela, o executivo; mudança de alvo, a Estratégia; recurso novo, a GE-01', 'Copiloto', 'médio',
          [('Pauta do ritual com os desvios e os donos', 'etapa 1'), (PED_CORRECAO, 'Estratégia'), (CORRECOES, 'Estratégia'),
           (REV_SEM, 'Estratégia')],
          [T('Incluir na pauta os pedidos de plano de correção e as correções publicadas', R),
           T('Conduzir o ritual com os donos dos alvos', P),
           T('Apresentar os desvios e propor as ações', 'LCI'),
           D('A ação cabe na alçada do líder do círculo?', P,
             [S('Sim', 'seg', via=[T('Decidir a ação na sua alçada', 'LCI')]),
              S('Não: passa do orçamento ou da alçada do círculo', 'seg', via=[T('Decidir a ação acima da alçada do líder', 'EXE')]),
              S('Não: a ação muda alvo', 'seg', via=[T('Levar a mudança de alvo à revisão da execução pela Estratégia', R)]),
              S('Não: a ação pede recurso novo', 'seg', via=[T('Abrir o pedido de recurso no orçamento', R)])]),
           T('Registrar desvios, decisões, donos e prazos', R),
           D('Há desvio grave pelo critério do método de estratégia?', R,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Apontar o desvio grave à Estratégia, que abre a revisão da execução', R)])])],
          [(DESVIOS, ['Estratégia']),
           ('Desvio grave ou mudança de alvo apontados pelo ritual', ['Estratégia']),
           (PED_REC, ['GE-01']),
           ('Ações do ritual, com dono e prazo', ['etapa 3'])]),
        E('Cobrar as ações até concluir', 'Gestão', 'Autômato', 'baixo',
          [('Ações do ritual, com dono e prazo', 'etapa 2')],
          [T('Lembrar cada dono e acompanhar o prazo das ações', R),
           D('A ação foi concluída no prazo?', A,
             [S('Sim', 'prox'),
              S('Não', 'F2', via=[T('Levar o atraso ao próximo ritual e ao executivo', R)])])],
          [('Situação das ações do ritual', ['Executivos', 'Líderes dos círculos']),
           ('Ações em atraso do ritual', ['etapa 1'])]),
    ]))

# ========================================================== FINANÇAS
JORNADAS.append(dict(
    code='GE-03',
    nome='Faturar os clientes e receber e cobrar o que é devido',
    dominio='Finanças', classe='essencial', onda=1,
    objetivo='Fazer cada cliente ter o cadastro de cobrança conforme o contrato, a tabela, a ata e a divisão da oferta conjunta; cada entrega confirmada por Operações virar fatura, com a medição dos níveis de serviço e os créditos aprovados; cada recebimento ser conciliado e cada atraso cobrado, com a negociação acima do limite decidida pela Gestão, ouvido o executivo, e a suspensão das novas entregas do cliente privado na segunda fatura vencida decidida pelo executivo; o reembolso pago só depois de aprovado pelo líder do círculo; e a situação de faturas e pagamentos de cada cliente ir a Relações e a Negócios. Operações confirma a entrega; a Gestão fatura e recebe.',
    frequencia='Por evento: contrato, oferta ou cliente novo, mudado ou encerrado; entregas confirmadas; vencimento de fatura',
    automacao=('média', 'Cadastrar, calcular, emitir, conciliar, cobrar e informar são de agente e automação; aprovar a fatura fora do padrão, decidir a negociação do atraso e propor a suspensão são de pessoa da Gestão; aprovar o reembolso é do líder do círculo; decidir a suspensão é do executivo.'),
    base=['apqc'],
    lanes=['NEG', 'OPE', 'EXE', 'LCI', P, A, R],
    inicios=[I('Contrato, oferta ou cliente novo, mudado ou encerrado recebido', 'NEG', 'message'),
             I('Entregas confirmadas para faturar recebidas', 'OPE', 'message'),
             I('Vencimento de fatura', R, 'timer')],
    fins=[F('Fatura recebida ou cobrada e situação informada', R),
          F('Cadastro de cobrança atualizado, sem fatura a emitir agora', R),
          F('Fatura emitida, à espera do vencimento', R)],
    etapas=[
        E('Cadastrar o cliente e as condições de cobrança', 'Gestão', 'Autopiloto', 'baixo',
          [(CONTRATO, 'Negócios'), (ATA, 'Negócios'), (TABELA, 'Negócios'), (ACORDO_CONJ, 'Negócios'), (CONTR_FIM, 'Negócios'),
           (CONTR_SAIDA, 'Negócios'), (VENCIMENTO, 'Negócios'), (CLI_IMPL, 'Integração'), (PLANO_IMPL, 'Integração'),
           (OFERTA_LANCADA, 'Integração'), (PLANO_LANC, 'Integração'), (SAIDA_CLI, 'Integração')],
          [D('O que iniciou o trabalho?', R,
             [S('Contrato, oferta ou cliente novo, mudado ou encerrado', 'seg'),
              S('Entregas confirmadas para faturar', 'E2'),
              S('Vencimento de fatura', 'E3')]),
           T('Cadastrar ou atualizar cliente, contrato, preços, calendário de cobrança e divisão da receita', R),
           T('Conferir o cadastro contra o contrato, a tabela e a ata', A),
           D('Há entregas confirmadas a faturar agora?', R,
             [S('Não', 'F2'),
              S('Sim', 'prox')])],
          [('Cadastro de cobrança do cliente', ['etapa 2'])]),
        E('Calcular e emitir a fatura', 'Gestão', 'Autopiloto', 'médio',
          [('Cadastro de cobrança do cliente', 'etapa 1'), (FATURAR, 'Operações'), (CREDITO, 'Operações')],
          [D('Há crédito ou reembolso aprovado para o cliente?', R,
             [S('Não', 'seg'),
              S('Crédito na próxima fatura', 'seg', via=[T('Lançar o crédito na próxima fatura', R)]),
              S('Reembolso, ou cliente sem fatura futura', 'seg',
                via=[T('Aprovar o pagamento do reembolso na alçada', 'LCI'),
                     T('Pagar o reembolso ao cliente e registrar', R)])]),
           T('Calcular a fatura pelas entregas confirmadas, os níveis de serviço e os créditos', A),
           D('A fatura foge do padrão ou tem glosa ou ajuste?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Conferir e aprovar a fatura fora do padrão', P)])]),
           T('Emitir a fatura e os documentos fiscais e enviá-los ao cliente', R),
           D('O pagamento já foi recebido na emissão?', R,
             [S('Não', 'F3'),
              S('Sim', 'prox')])],
          [('Fatura emitida', ['etapa 3', 'Clientes']),
           ('Reembolso pago ao cliente', ['Clientes'])]),
        E('Receber e cobrar', 'Gestão', 'Autopiloto', 'médio',
          [('Fatura emitida', 'etapa 2')],
          [T('Conciliar os recebimentos com as faturas', R),
           D('A fatura foi paga no vencimento?', R,
             [S('Sim', 'prox'),
              S('Não', 'seg', via=[T('Cobrar o cliente pelos canais combinados', A)])]),
           D('O atraso passa do limite da política de cobrança?', R,
             [S('Não', 'prox'),
              S('Sim', 'seg', via=[T('Decidir a negociação ou a cobrança do atraso, ouvido o executivo', P)])]),
           D('O cliente é privado e já tem a segunda fatura vencida?', R,
             [S('Não, ou é contrato público', 'prox'),
              S('Sim', 'prox', via=[T('Propor ao executivo a suspensão das novas entregas', P),
                                    T('Decidir a suspensão das novas entregas do cliente', 'EXE')])])],
          [('Recebimentos conciliados e atrasos tratados', ['etapa 4']),
           ('Suspensão de novas entregas por atraso, decidida pelo executivo', ['Operações'])]),
        E('Informar a situação de cada cliente', 'Gestão', 'Autopiloto', 'baixo',
          [('Recebimentos conciliados e atrasos tratados', 'etapa 3')],
          [T('Atualizar a situação de faturas e pagamentos de cada cliente', R),
           T('Apontar clientes com atraso recorrente', A)],
          [(SIT_FAT, ['Relações', 'Negócios']),
           (RECEITAS, ['GE-05', 'GE-13'])]),
    ]))

JORNADAS.append(dict(
    code='GE-04',
    nome='Comprar e pagar: do pedido de compra ao fornecedor e ao parceiro pagos',
    dominio='Finanças', classe='essencial', onda=1,
    objetivo='Fazer cada pedido de compra ser conferido contra o orçamento e a alçada; cada fornecedor ser escolhido por preço, prazo, qualidade e risco, com o contrato revisado e guardado pela Governança; cada compra ser recebida e conferida por quem pediu; cada fatura de fornecedor ser conferida com o pedido e o recebimento e paga com a aprovação do líder do círculo, que não é quem escolhe o fornecedor; cada fornecedor ser avaliado e cobrado pelas falhas; a remuneração de cada parceiro ser apurada pelo contrato e paga; e os contratos de fornecedor serem encerrados ou transferidos na saída. Quem precisa pede, inclusive a Integração nas compras da implantação e de tecnologia; a Gestão compra e paga; a Governança revisa e guarda o contrato.',
    frequencia='Por evento: pedido de compra, fatura de fornecedor, falha ou desempenho de fornecedor apontado',
    automacao=('média', 'Conferir orçamento e alçada, cotar, emitir o pedido, registrar o recebimento, conferir a fatura e pagar são de agente e automação; escolher o fornecedor, resolver divergências e cobrar a falha são de pessoa da Gestão; aprovar o pagamento é do líder do círculo.'),
    base=['apqc'],
    lanes=['SOL', 'EST', 'GOV', 'SOC', 'EXE', 'LCI', P, A, R],
    inicios=[I('Pedido de compra recebido', 'SOL', 'message'),
             I('Fatura de fornecedor recebida', R, 'message'),
             I('Falha ou desempenho de fornecedor apontado', R, 'message'),
             I('Período de remuneração de parceiros iniciado', R, 'timer'),
             I('Saída com contratos de fornecedor recebida', 'EST', 'message')],
    fins=[F('Compra paga e fornecedor avaliado', R),
          F('Fornecedor avaliado, sem pagamento a fazer', R)],
    etapas=[
        E('Receber e conferir o pedido de compra', 'Gestão; acima da alçada, o executivo; acima da reserva de contingência, os sócios', 'Autopiloto', 'baixo',
          [(PED_COMPRA_OP, 'Operações'), (PED_COMPRA, 'Solicitante'), (PED_COMPRA, 'GE-12'), (PLANO_CAP, 'Operações'),
           (ORC_VIG, 'GE-01'), (ALCADAS, 'Governança'), (COBRANCA_FORN, 'Operações'), (DESEMP_FORN, 'Operações'),
           (CONTRATO, 'Negócios'), (ACORDO_CONJ, 'Negócios'), (DATA_SAIDA, 'Estratégia'), (MANDATO, 'Estratégia')],
          [D('O que iniciou o trabalho?', R,
             [S('Pedido de compra', 'seg'),
              S('Fatura de fornecedor', 'E5'),
              S('Falha ou desempenho de fornecedor', 'E4'),
              S('Remuneração de parceiros do período', 'E5',
                via=[T('Apurar a remuneração de cada parceiro pelo contrato e pela divisão acordada', A)]),
              S('Saída de oferta ou de empresa', 'E4',
                via=[T('Encerrar ou transferir os contratos de fornecedor da saída', P)])]),
           T('Registrar o pedido e conferir o orçamento e a alçada', R),
           D('O pedido tem orçamento e cabe na alçada de quem pediu?', A,
             [S('Sim', 'prox'),
              S('Não, fora do orçamento ou acima da alçada', 'prox', via=[T('Aprovar o pedido fora do orçamento ou acima da alçada', 'EXE')]),
              S('Não, acima da reserva de contingência', 'prox', via=[T('Aprovar o pedido acima da reserva de contingência', 'SOC')])])],
          [('Pedido de compra aprovado', ['etapa 2']),
           ('Falha ou desempenho de fornecedor registrado', ['etapa 4'])]),
        E('Escolher o fornecedor e emitir o pedido', 'Gestão; o contrato, com a Governança', 'Copiloto', 'médio',
          [('Pedido de compra aprovado', 'etapa 1'), ('Fornecedores avaliados', 'etapa 4')],
          [T('Cotar com fornecedores cadastrados e comparar preço, prazo, qualidade e risco', A),
           T('Escolher o fornecedor', P),
           D('A compra pede contrato?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Revisar o contrato com o fornecedor e guardá-lo', 'GOV')])]),
           T('Emitir o pedido ao fornecedor e informar a data de entrega a quem pediu', R)],
          [('Pedido emitido ao fornecedor', ['etapa 3', 'etapa 5']),
           (COMPRADOS, ['Operações']),
           ('Contrato de fornecedor para revisar e guardar', ['Governança'])]),
        E('Receber o que foi comprado', 'Gestão, com quem pediu', 'Copiloto', 'baixo',
          [('Pedido emitido ao fornecedor', 'etapa 2')],
          [T('Receber e conferir o que foi entregue', 'SOL'),
           T('Registrar o recebimento e a pontualidade do fornecedor', R)],
          [('Compra recebida', ['etapa 4', 'etapa 5'])]),
        E('Avaliar o fornecedor e cobrar as falhas', 'Gestão', 'Copiloto', 'médio',
          [('Compra recebida', 'etapa 3'), ('Falha ou desempenho de fornecedor registrado', 'etapa 1')],
          [T('Consolidar o desempenho do fornecedor em prazo, qualidade e custo', A),
           D('Há falha a cobrar do fornecedor?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Cobrar do fornecedor a falha, conforme o contrato', P)])]),
           T('Decidir manter, desenvolver ou trocar o fornecedor', P)],
          [('Fornecedores avaliados', ['etapa 2', 'etapa 5'])]),
        E('Conferir a fatura e pagar', 'Gestão', 'Copiloto', 'médio',
          [('Fornecedores avaliados', 'etapa 4'), ('Pedido emitido ao fornecedor', 'etapa 2'), ('Compra recebida', 'etapa 3')],
          [D('Há fatura ou remuneração a pagar?', R,
             [S('Sim', 'seg'),
              S('Não', 'F2')]),
           T('Conferir a fatura com o pedido e o recebimento, ou a remuneração com o contrato', A),
           D('Os valores batem?', A,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Resolver a divergência com o fornecedor ou o parceiro', P)])]),
           T('Aprovar o pagamento na alçada', 'LCI'),
           T('Programar e fazer o pagamento e registrá-lo', R)],
          [(PAGOS, ['GE-05'])]),
    ]))

JORNADAS.append(dict(
    code='GE-05',
    nome='Gerir o caixa, fechar as contas e os impostos e prestar contas',
    dominio='Finanças', classe='essencial', onda=1,
    objetivo='Fazer cada recebimento e pagamento ser registrado e conciliado; o caixa ser projetado com a previsão de receita, os compromissos e o orçamento e informado à Estratégia; cada período ser fechado por empresa e consolidado, com os impostos apurados e as obrigações entregues, o resultado, os custos e margens e a execução do orçamento publicados; e cada aporte, distribuição ou mudança de contas decidido pelos sócios ou pelo mandato ser executado com dupla aprovação: a Gestão prepara e confere; o líder do círculo, o executivo ou o Administrador do IMTS.OS aprovam; as contas e os poderes bancários são conferidos pela Governança. Os sócios decidem; a Governança recebe as demonstrações para prestar contas.',
    frequencia='A cada período de fechamento (cadência: fechamento mensal; balanço anual) e por evento: decisão de alocação ou de destino do resultado, mandato ou mudança no portfólio',
    automacao=('média', 'Registrar, conciliar, projetar, fechar e apurar são de agente e automação; conferir o fechamento e os impostos e conferir a execução de aportes e distribuições são de pessoa da Gestão; aprovar o fechamento, os impostos e a execução é do líder do círculo ou, acima da alçada, do executivo; as contas do IMTS.OS, do Administrador; a conferência das contas, da Governança.'),
    base=['apqc', 'cc2002'],
    lanes=['EST', 'GOV', 'ADM', 'EXE', 'LCI', P, A, R],
    inicios=[I('Fechamento do período iniciado', R, 'timer'),
             I('Decisão de alocação, de destino do resultado ou mandato recebido', 'EST', 'message')],
    fins=[F('Aportes, distribuição ou mudanças de contas executados e registrados', R),
          F('Período fechado e informado, sem execução pendente', R)],
    etapas=[
        E('Registrar e conciliar o movimento e projetar o caixa', 'Gestão', 'Autopiloto', 'baixo',
          [(RECEITAS, 'GE-03'), (PAGOS, 'GE-04'), (FOLHA, 'GE-13'), (PREVISAO, 'Negócios'), (ORC_VIG, 'GE-01')],
          [D('O que iniciou o trabalho?', R,
             [S('Fechamento do período', 'seg'),
              S('Decisão de alocação, de destino do resultado ou mandato', 'E3')]),
           T('Registrar e conciliar contas, recebimentos e pagamentos', R),
           T('Projetar o caixa com a previsão de receita, os compromissos e o orçamento', A)],
          [(CAIXA, ['Estratégia']),
           ('Movimento do período conciliado', ['etapa 2'])]),
        E('Fechar as contas, apurar o resultado e os impostos', 'Gestão', 'Copiloto', 'médio',
          [('Movimento do período conciliado', 'etapa 1'), (RATEIO, 'GE-06'), (ATIVOS, 'GE-12')],
          [T('Fechar a contabilidade do período por empresa e consolidar', A),
           T('Apurar os impostos do período e preparar as obrigações fiscais', A),
           T('Conferir o fechamento e os impostos', P),
           T('Aprovar o fechamento e o recolhimento dos impostos', 'LCI'),
           T('Recolher os impostos e entregar as obrigações', R),
           T('Apurar o resultado, os custos e margens e a execução do orçamento', A),
           D('Há aporte, distribuição ou mudança de contas a executar?', R,
             [S('Não', 'F2'),
              S('Sim', 'prox')])],
          [(RESULTADO, ['Estratégia', 'Inteligência']),
           (MARGENS, ['Inteligência']),
           (EXEC_ORC, ['Estratégia', 'GE-02']),
           ('Demonstrações e obrigações fiscais do período', ['Governança']),
           ('Período fechado', ['etapa 3'])]),
        E('Executar aportes, distribuição e mudanças de contas', 'Gestão prepara; o líder do círculo, o executivo ou o Administrador do IMTS.OS aprovam; a Governança confere as contas', 'Copiloto', 'alto',
          [('Período fechado', 'etapa 2'), (DEC_ALOC, 'Estratégia'), (ALOCACAO, 'Estratégia'), (MANDATO, 'Estratégia'),
           (PORTFOLIO, 'Estratégia'), (ALCADAS, 'Governança')],
          [T('Preparar a execução do aporte, da distribuição ou da mudança de contas da empresa', A),
           T('Conferir a execução com a decisão e a alçada', P),
           D('O que será executado?', P,
             [S('Aporte ou distribuição dentro da alçada da Gestão', 'seg',
                via=[T('Aprovar a execução do aporte ou da distribuição', 'LCI')]),
              S('Aporte ou distribuição acima da alçada da Gestão', 'seg',
                via=[T('Autorizar a execução acima da alçada da Gestão', 'EXE')]),
              S('Abertura, encerramento ou mudança de poderes de contas da empresa', 'seg',
                via=[T('Autorizar a mudança de contas da empresa', 'EXE'),
                     T('Conferir os poderes e a mudança de contas', 'GOV')]),
              S('Contas do IMTS.OS ou dos círculos compartilhados', 'seg',
                via=[T('Autorizar a mudança de contas do IMTS.OS', 'ADM'),
                     T('Conferir os poderes e a mudança de contas do IMTS.OS', 'GOV')])]),
           T('Executar e registrar a movimentação', R)],
          [('Aportes, distribuição ou mudanças de contas executados', ['Executivos', 'Governança'])]),
    ]))

JORNADAS.append(dict(
    code='GE-06',
    nome='Aplicar o rateio do custo dos círculos entre as empresas',
    dominio='Finanças', classe='essencial', onda=1,
    objetivo='Fazer o custo dos círculos do Ecossistema central ser repartido entre as empresas pelo critério definido pela Governança com a Estratégia: custo e uso apurados, critério aplicado, rateio conferido, aberto à opinião de cada executivo, publicado e lançado nas contas; e cada contestação do critério ir à Governança. A Governança define o critério; a Gestão aplica.',
    frequencia='A cada período de fechamento (cadência: mensal, com o fechamento)',
    automacao=('média', 'Reunir o custo e o uso, aplicar o critério, publicar e lançar são de agente e automação; conferir e tratar a contestação são de pessoa da Gestão; o executivo opina.'),
    base=['apqc'],
    lanes=['EXE', P, A, R],
    inicios=[I('Período de rateio iniciado', R, 'timer')],
    fins=[F('Rateio publicado e lançado', R)],
    etapas=[
        E('Apurar o custo dos círculos e o uso de cada empresa', 'Gestão', 'Autopiloto', 'baixo',
          [(CRITERIO_RATEIO, 'Governança'), (CUSTO_TEC, 'Integração'), (PORTFOLIO, 'Estratégia')],
          [T('Reunir o custo de cada círculo e o uso dos serviços por empresa', R),
           T('Aplicar o critério de rateio e calcular a parte de cada empresa', A)],
          [('Rateio calculado', ['etapa 2'])]),
        E('Conferir e publicar o rateio', 'Gestão; o executivo opina', 'Assistido', 'médio',
          [('Rateio calculado', 'etapa 1')],
          [T('Conferir o rateio com o critério', P),
           T('Opinar sobre o rateio da sua empresa', 'EXE'),
           D('Há contestação do rateio?', P,
             [S('Não', 'seg'),
              S('Do cálculo', 'seg', via=[T('Rever o cálculo e responder ao executivo', P)]),
              S('Do critério', 'seg', via=[T('Levar a contestação do critério à Governança', R)])]),
           T('Publicar e lançar o rateio nas contas de cada empresa', R)],
          [(RATEIO, ['GE-01', 'GE-05', 'Executivos']),
           ('Contestação do critério de rateio', ['Governança'])]),
    ]))

# ========================================================== PESSOAS E CULTURA
JORNADAS.append(dict(
    code='GE-07',
    nome='Prover pessoas: vaga, seleção, contratação, movimentação e desligamento',
    dominio='Pessoas e cultura', classe='essencial', onda=1,
    objetivo='Fazer cada vaga, movimentação ou desligamento pedido pelo líder, pelo plano de capacidade ou pelo mandato ser conferido contra o orçamento, o perfil do kit de cultura e a alçada; cada vaga ser preenchida por seleção pelos comportamentos esperados, com a contratação decidida pelo líder; cada pessoa ser contratada, movimentada ou desligada com o registro, a folha e os acessos atualizados; e cada pessoa nova ir à integração. O líder decide quem entra na sua equipe; a Gestão conduz e confere; o executivo decide o que passa da alçada na empresa, e o Administrador do IMTS.OS, nos círculos; os sócios decidem o desligamento de executivo ou de líder de círculo.',
    frequencia='Por evento: pedido do líder, plano de capacidade, mandato, saída, recurso liberado',
    automacao=('média', 'Registrar, conferir orçamento e perfil, divulgar, triar e atualizar registros e acessos são de agente e automação; aprovar a abertura, conferir a decisão e fazer a proposta são de pessoa da Gestão; a escolha é do líder; o desligamento, com o executivo.'),
    base=['apqc', 'lgpd', 'clt'],
    lanes=['LID', 'PES', 'SOC', 'ADM', 'EXE', P, A, R],
    inicios=[I('Vaga, movimentação ou desligamento pedido pelo líder', 'LID', 'message'),
             I('Plano de capacidade, mandato ou recurso liberado recebido', R, 'message')],
    fins=[F('Pessoa contratada, movimentada ou desligada e registrada', R)],
    etapas=[
        E('Abrir a vaga ou decidir a movimentação', 'Gestão, com o líder; acima da alçada, o executivo', 'Copiloto', 'alto',
          [('Pedido de vaga, de movimentação ou de desligamento', 'Líderes'), (PLANO_CAP, 'Operações'),
           (REC_LIB_OP, 'Operações'), (REC_LIB_IT, 'Integração'), (LISTA_ADQ, 'Estratégia'), (MANDATO, 'Estratégia'),
           (DATA_SAIDA, 'Estratégia'), (KIT, 'Identidade'), (ORC_VIG, 'GE-01'), (ALCADAS, 'Governança')],
          [T('Registrar o pedido e conferir o orçamento, o perfil e a alçada', A),
           T('Aprovar o pedido conforme o orçamento e a alçada', P),
           D('O pedido passa da alçada da Gestão?', P,
             [S('Não', 'seg'),
              S('Sim, pessoa de uma empresa', 'seg', via=[T('Decidir o pedido acima da alçada da Gestão', 'EXE')]),
              S('Sim, pessoa dos círculos do IMTS.OS', 'seg',
                via=[T('Decidir o pedido de pessoa dos círculos acima da alçada da Gestão', 'ADM')])]),
           D('O que é pedido?', P,
             [S('Vaga nova ou reposição', 'prox'),
              S('Incorporação de pessoas da empresa adquirida', 'E4',
                via=[T('Cadastrar as pessoas da empresa adquirida conforme o mandato', R)]),
              S('Promoção, mudança de papel ou realocação', 'E4',
                via=[T('Decidir a movimentação com o líder', P)]),
              S('Desligamento', 'E4',
                via=[T('Decidir o desligamento com o líder', 'EXE'),
                     T('Fazer o desligamento, o acerto rescisório e a devolução do que é da empresa', P)]),
              S('Desligamento de executivo ou de líder de círculo', 'E4',
                via=[T('Decidir o desligamento do executivo ou do líder de círculo', 'SOC'),
                     T('Fazer o desligamento decidido pelos sócios, com o acerto rescisório', P)])])],
          [('Vaga aberta, com perfil e orçamento', ['etapa 2']),
           ('Movimentação ou desligamento feito', ['etapa 4'])]),
        E('Atrair e selecionar', 'Gestão conduz; o líder escolhe', 'Assistido', 'médio',
          [('Vaga aberta, com perfil e orçamento', 'etapa 1'), (SIGILO, 'Governança')],
          [T('Divulgar a vaga e buscar candidatos', A),
           T('Triar os candidatos pelo perfil e pelos comportamentos do kit de cultura', A),
           T('Revisar a triagem do agente antes de recusar candidatos', P),
           T('Entrevistar e avaliar os finalistas', 'LID'),
           T('Decidir a contratação', 'LID'),
           D('A escolha confere com o perfil, a política e a alçada?', P,
             [S('Sim', 'prox'),
              S('Não', 'E2', via=[T('Devolver a escolha ao líder com o motivo', P)])])],
          [('Pessoa escolhida', ['etapa 3'])]),
        E('Contratar a pessoa', 'Gestão', 'Copiloto', 'médio',
          [('Pessoa escolhida', 'etapa 2')],
          [T('Fazer a proposta e combinar as condições', P),
           D('A pessoa aceitou a proposta?', 'PES',
             [S('Sim', 'seg'),
              S('Não', 'E2', via=[T('Registrar a recusa e voltar aos finalistas', R)])]),
           T('Formalizar o contrato e cadastrar a pessoa na folha', R)],
          [(CONTRATADA, ['GE-08', 'GE-13', 'Líderes']),
           ('Contratação formalizada', ['etapa 4'])]),
        E('Registrar a mudança e avisar quem precisa', 'Gestão', 'Autômato', 'baixo',
          [('Contratação formalizada', 'etapa 3'), ('Movimentação ou desligamento feito', 'etapa 1')],
          [T('Atualizar o cadastro, a folha e a estrutura', R),
           T('Pedir à Integração os acessos novos ou a retirada de acessos', R)],
          [(PED_TEC, ['Integração']),
           (MUD_PESSOAS, ['GE-08', 'GE-13', 'Líderes'])]),
    ]))

JORNADAS.append(dict(
    code='GE-08',
    nome='Integrar pessoas novas à cultura',
    dominio='Pessoas e cultura', classe='essencial', onda=1,
    objetivo='Fazer cada pessoa nova, ou que mudou de papel, e cada pessoa de empresa adquirida entender o propósito, os valores e os comportamentos esperados, e sentir-se parte, antes de responder sozinha pelo seu papel: trilha montada pelo papel, conduzida com o líder, vínculos iniciais e verificação de entendimento e de pertencimento, com reforço combinado quando falta. A Identidade define o kit; a Gestão integra; o líder acompanha.',
    frequencia='Por pessoa: contratação, mudança de papel ou incorporação de empresa adquirida',
    automacao=('média', 'Abrir, montar a trilha, conduzir as dúvidas, verificar e registrar são de agente e automação; combinar o reforço é de pessoa da Gestão; conversar e confirmar os comportamentos é do líder.'),
    base=['apqc'],
    lanes=['LID', 'PES', P, A, R],
    inicios=[I('Pessoa contratada ou com papel novo', R, 'message'),
             I('Pessoas de empresa adquirida recebidas', R, 'message')],
    fins=[F('Integração cultural concluída e registrada', R)],
    etapas=[
        E('Preparar a trilha de integração', 'Gestão', 'Autopiloto', 'baixo',
          [(CONTRATADA, 'GE-07'), (MUD_PESSOAS, 'GE-07'), (LISTA_ADQ, 'Estratégia'), (KIT, 'Identidade'),
           (PADROES_ID, 'Identidade')],
          [T('Abrir a integração e agendar os marcos', R),
           T('Montar a trilha conforme o papel', A)],
          [('Trilha de integração', ['etapa 2', 'Pessoas', 'Líderes'])]),
        E('Apresentar propósito, valores e comportamentos', 'Gestão, com o líder', 'Assistido', 'baixo',
          [('Trilha de integração', 'etapa 1')],
          [T('Conduzir a trilha e tirar dúvidas', A),
           T('Conversar sobre como os valores aparecem no dia a dia da função', 'LID'),
           T('Concluir a trilha', 'PES')],
          [('Trilha concluída', ['etapa 3'])]),
        E('Conectar a pessoa à comunidade', 'Líder', 'Assistido', 'baixo',
          [('Trilha concluída', 'etapa 2')],
          [T('Indicar um padrinho ou uma madrinha', 'LID'),
           T('Participar do primeiro ritual', 'PES')],
          [('Vínculos iniciais registrados', ['etapa 4'])]),
        E('Verificar a integração e registrar', 'Gestão, com o líder', 'Copiloto', 'médio',
          [('Vínculos iniciais registrados', 'etapa 3')],
          [T('Aplicar a verificação de entendimento e de pertencimento', A),
           T('Confirmar os comportamentos observados', 'LID'),
           D('A pessoa se integrou?', 'LID',
             [S('Sim', 'seg'),
              S('Não, com reforço possível', 'E2', via=[T('Combinar o reforço com o líder', P)]),
              S('Não, sem condição de seguir no papel', 'seg',
                via=[T('Levar ao líder e ao executivo a decisão sobre a permanência', R)])]),
           T('Registrar a conclusão, avisar o líder e enviar os dados agregados à pesquisa', R)],
          [(INTEGRADA, ['Líderes', 'GE-09'])]),
    ]))

JORNADAS.append(dict(
    code='GE-09',
    nome='Avaliar e desenvolver as pessoas e medir a cultura',
    dominio='Pessoas e cultura', classe='essencial', onda=1,
    objetivo='Fazer cada pessoa ser avaliada pelos alvos e pelos comportamentos do kit de cultura, com as avaliações calibradas, as mudanças de remuneração propostas na política pela Gestão e aprovadas pelo executivo ou, nos círculos do IMTS.OS, pelo Administrador, e um plano de desenvolvimento combinado com o líder; quem quiser, ligar o seu propósito ao seu papel, com participação voluntária, a declaração guardada pela pessoa e o ajuste de papel só com o acordo dela; e a cultura e o engajamento serem medidos sem identificar quem respondeu e entregues à Identidade e à Inteligência. O líder avalia; a Gestão calibra, desenvolve e mede.',
    frequencia='A cada ciclo de avaliação e desenvolvimento e a cada pesquisa de cultura (cadências: avaliação semestral; pesquisa de cultura anual)',
    automacao=('média', 'Preparar a avaliação, guiar a reflexão, acompanhar o treino e aplicar e analisar a pesquisa são de agente e automação; calibrar, propor a remuneração, aprovar treinos e apresentar o resultado são de pessoa da Gestão; avaliar é do líder; aprovar a remuneração é do executivo ou do Administrador do IMTS.OS.'),
    base=['apqc', 'lgpd'],
    lanes=['LID', 'PES', 'EXE', 'ADM', P, A, R],
    inicios=[I('Ciclo de avaliação e desenvolvimento iniciado', R, 'timer'),
             I('Pesquisa de cultura e engajamento iniciada', R, 'timer')],
    fins=[F('Pesquisa de cultura aplicada e resultado entregue', R),
          F('Ciclo de avaliação e desenvolvimento concluído', R)],
    etapas=[
        E('Avaliar o desempenho e decidir a remuneração na política', 'Gestão calibra; o líder avalia', 'Assistido', 'médio',
          [(KIT, 'Identidade'), (LACUNAS_EXEC, 'Identidade'), (RESUMO_PAD, 'Identidade'), (ALVOS, 'Estratégia'),
           (INTEGRADA, 'GE-08')],
          [D('Qual ciclo iniciou?', R,
             [S('Avaliação e desenvolvimento', 'seg'),
              S('Pesquisa de cultura e engajamento', 'E3')]),
           T('Preparar a avaliação pelos alvos e pelos comportamentos do kit', A),
           T('Avaliar a pessoa e combinar o plano de desenvolvimento', 'LID'),
           T('Fazer a autoavaliação e combinar o plano', 'PES'),
           T('Calibrar as avaliações e propor as mudanças de remuneração na política', P),
           D('De quem é a mudança de remuneração?', R,
             [S('Pessoas de uma empresa', 'seg', via=[T('Aprovar as mudanças de remuneração da empresa', 'EXE')]),
              S('Pessoas dos círculos do IMTS.OS, inclusive da Gestão', 'seg',
                via=[T('Aprovar as mudanças de remuneração dos círculos', 'ADM')])]),
           T('Lançar as mudanças de remuneração aprovadas na próxima folha', R)],
          [('Avaliações e planos de desenvolvimento', ['etapa 2']),
           (MUD_REMUN, ['GE-13'])]),
        E('Ligar o propósito ao papel e desenvolver as pessoas', 'Gestão, com a pessoa e o líder', 'Copiloto', 'baixo',
          [('Avaliações e planos de desenvolvimento', 'etapa 1')],
          [T('Convidar a pessoa a ligar o seu propósito ao papel, com participação voluntária', R),
           D('A pessoa aceitou o convite?', 'PES',
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Guiar a reflexão sobre histórias, valores e forças', A),
                                   T('Escrever a declaração de propósito e escolher o que compartilha', 'PES'),
                                   T('Conversar com o líder sobre propósito e papel e fechar o plano', 'PES'),
                                   T('Avaliar o ajuste de papel, com o acordo da pessoa', P)])]),
           T('Oferecer e acompanhar o treino e o desenvolvimento do plano', A),
           T('Aprovar os treinos que pedem orçamento', P),
           D('O desenvolvimento do ciclo foi registrado?', R,
             [S('Sim', 'F2'),
              S('Não', 'F2', via=[T('Registrar o plano e os treinos do ciclo', R)])])],
          [('Plano de desenvolvimento ligado ao propósito', ['Líderes'])]),
        E('Medir a cultura e o engajamento', 'Gestão', 'Copiloto', 'baixo',
          [(PARTICIP, 'GE-10'), (INTEGRADA, 'GE-08'), (SIGILO, 'Governança')],
          [T('Aplicar a pesquisa de cultura e de engajamento', R),
           T('Analisar os resultados com os dados de pessoas, sem identificar quem respondeu', A),
           T('Conferir e apresentar o resultado aos líderes', P)],
          [(PESQUISA, ['Identidade', 'Inteligência'])]),
    ]))

JORNADAS.append(dict(
    code='GE-13',
    nome='Calcular e pagar a folha e os encargos',
    dominio='Pessoas e cultura', classe='essencial', onda=1,
    objetivo='Fazer cada folha ter o ponto, as variáveis, as comissões de quem vende sobre a receita recebida, os reconhecimentos e as mudanças de remuneração do período apurados a partir dos registros de pessoas, conferida pela Gestão, aprovada pelo executivo ou, nos círculos do IMTS.OS, pelo Administrador, paga no prazo e com os encargos recolhidos. A Gestão apura, confere e paga; quem aprova é outra pessoa.',
    frequencia='A cada período de folha (cadência: mensal; salário até o quinto dia útil do mês seguinte; FGTS até o dia 20)',
    automacao=('média', 'Apurar, pagar e recolher são de agente e automação; conferir a folha é de pessoa da Gestão; aprovar é do executivo ou do Administrador do IMTS.OS.'),
    base=['apqc', 'clt', 'fgts'],
    lanes=['EXE', 'ADM', P, A, R],
    inicios=[I('Período da folha iniciado', R, 'timer')],
    fins=[F('Folha paga e encargos recolhidos', R)],
    etapas=[
        E('Apurar a folha do período', 'Gestão', 'Autopiloto', 'baixo',
          [(CONTRATADA, 'GE-07'), (MUD_PESSOAS, 'GE-07'), (MUD_REMUN, 'GE-09'), (RECONHEC, 'GE-10'),
           (CONTRATO, 'Negócios'), (RECEITAS, 'GE-03'), (SIGILO, 'Governança')],
          [T('Reunir o ponto, as mudanças de pessoas, as receitas recebidas e os reconhecimentos', R),
           T('Apurar salários, variáveis, comissões sobre a receita recebida e reconhecimentos', A)],
          [('Folha apurada', ['etapa 2'])]),
        E('Aprovar e pagar a folha', 'Gestão', 'Copiloto', 'médio',
          [('Folha apurada', 'etapa 1')],
          [T('Conferir a folha', P),
           D('De quem é a folha?', R,
             [S('De uma empresa', 'seg', via=[T('Aprovar a folha da empresa', 'EXE')]),
              S('Dos círculos do IMTS.OS', 'seg', via=[T('Aprovar a folha dos círculos', 'ADM')])]),
           T('Pagar a folha e recolher os encargos', R)],
          [(FOLHA, ['GE-05'])]),
    ]))

JORNADAS.append(dict(
    code='GE-10',
    nome='Realizar os rituais de cultura e o reconhecimento de pessoas e equipes',
    dominio='Pessoas e cultura', classe='essencial', onda=1,
    objetivo='Reforçar, com cadência fixa, os comportamentos que os valores pedem: cada ritual preparado pelo padrão do kit de cultura, cada indicação de reconhecimento conferida com os critérios e decidida com os líderes, o ritual conduzido pelo líder, as histórias registradas e comunicadas e os reconhecimentos levados à folha. A Identidade define o padrão; a Gestão prepara, decide com os líderes e registra; o líder conduz.',
    frequencia='No calendário de rituais (cadência: trimestral)',
    automacao=('média', 'Colher indicações, montar o roteiro, conferir com os critérios, selecionar histórias e registrar são de agente e automação; decidir os reconhecimentos é de pessoa da Gestão, com os líderes; conduzir o ritual é do líder.'),
    base=['apqc'],
    lanes=['LID', P, A, R],
    inicios=[I('Ritual do calendário iniciado', R, 'timer')],
    fins=[F('Ritual realizado e registrado', R)],
    etapas=[
        E('Preparar o ritual', 'Gestão', 'Autopiloto', 'baixo',
          [(PADROES_ID, 'Identidade'), (KIT, 'Identidade'), ('Indicações de reconhecimento', 'Líderes'), (ALVOS, 'Estratégia')],
          [T('Abrir a preparação e colher as indicações', R),
           T('Montar o roteiro e o material do ritual', A)],
          [('Roteiro do ritual e lista de indicações', ['etapa 2'])]),
        E('Avaliar as indicações de reconhecimento', 'Gestão, com os líderes', 'Assistido', 'médio',
          [('Roteiro do ritual e lista de indicações', 'etapa 1')],
          [T('Conferir cada indicação com os critérios do kit', A),
           T('Decidir os reconhecimentos com os líderes', P),
           T('Aprovar a recompensa dentro do orçamento', P)],
          [('Reconhecimentos aprovados', ['etapa 3']),
           ('Retorno sobre as indicações', ['Líderes'])]),
        E('Realizar o ritual', 'Líder', 'Assistido', 'baixo',
          [('Reconhecimentos aprovados', 'etapa 2')],
          [T('Conduzir o ritual', 'LID'),
           T('Apoiar a condução e registrar as histórias', P)],
          [('Histórias registradas', ['etapa 4'])]),
        E('Comunicar e registrar', 'Gestão', 'Autopiloto', 'baixo',
          [('Histórias registradas', 'etapa 3')],
          [T('Selecionar as histórias e os reconhecimentos a comunicar', A),
           T('Registrar a participação e os reconhecimentos', R)],
          [(HISTORIAS, ['GE-11']),
           (PARTICIP, ['GE-09']),
           (RECONHEC, ['GE-13'])]),
    ]))

JORNADAS.append(dict(
    code='GE-11',
    nome='Planejar e publicar a comunicação interna',
    dominio='Pessoas e cultura', classe='essencial', onda=1,
    objetivo='Manter as pessoas informadas e alinhadas, com uma só voz: cada mudança na identidade, nos padrões e na estratégia, cada alvo, correção, mudança no portfólio e conteúdo externo relevante entrar na pauta; cada conteúdo ser redigido na voz e na marca vigentes, conferido, validado pela Governança quando sensível e aprovado; os materiais vencidos saírem dos canais; e o alcance e o entendimento serem medidos. A Identidade define a voz e as mensagens; a Gestão comunica para dentro; Relações, para fora.',
    frequencia='No calendário da comunicação interna (cadência: mensal) e por evento: fato ou mudança a comunicar',
    automacao=('alta', 'Propor a pauta, redigir, conferir, publicar, retirar materiais vencidos e medir são de agente e automação; decidir a pauta e aprovar o conteúdo são de pessoa da Gestão.'),
    base=['apqc'],
    lanes=['GOV', 'PES', P, A, R],
    inicios=[I('Ciclo da comunicação interna iniciado', R, 'timer'),
             I('Fato ou mudança a comunicar recebido', R, 'message')],
    fins=[F('Comunicação interna publicada e medida', R)],
    etapas=[
        E('Planejar a pauta', 'Gestão', 'Copiloto', 'baixo',
          [(MUD_DECL, 'Identidade'), (MUD_PADROES, 'Identidade'), (POSIC, 'Identidade'), (PADROES_ID, 'Identidade'),
           (MUD_EST, 'Estratégia'), (ALVOS, 'Estratégia'), (CORRECOES, 'Estratégia'), (PORTFOLIO, 'Estratégia'),
           (CONT_EXT, 'Relações'), (HISTORIAS, 'GE-10'), ('Medição da comunicação interna', 'etapa 4')],
          [T('Propor a pauta e o calendário a partir dos fatos', A),
           T('Decidir pauta, público, canal e o que é sensível', P)],
          [('Pauta e calendário aprovados', ['etapa 2'])]),
        E('Produzir o conteúdo', 'Gestão; o conteúdo sensível, com a Governança', 'Copiloto', 'baixo',
          [('Pauta e calendário aprovados', 'etapa 1'), (PACOTE_MARCA, 'Identidade'), (MARCA_RET, 'Identidade'),
           (RESPOSTA_ID, 'Identidade')],
          [T('Redigir o conteúdo na voz do Ecossistema', A),
           T('Conferir o conteúdo com o guia de voz, as mensagens e a marca vigente', A),
           D('O conteúdo está conforme os padrões?', A,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Corrigir o conteúdo reprovado', P)])]),
           D('Há caso não coberto pelos padrões?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Consultar a Identidade sobre o caso não coberto', R),
                                   T('Receber a resposta da Identidade e ajustar o conteúdo', R, 'receive')])]),
           D('O conteúdo é sensível?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Validar o conteúdo sensível', 'GOV')])]),
           T('Aprovar o conteúdo', P)],
          [('Conteúdo aprovado', ['etapa 3']),
           (CONSULTA, ['Identidade'])]),
        E('Publicar nos canais internos', 'Gestão', 'Autômato', 'baixo',
          [('Conteúdo aprovado', 'etapa 2'), (VENCIDOS, 'Identidade')],
          [T('Publicar nos canais internos', R),
           T('Retirar dos canais internos os materiais vencidos ou de marca retirada', R)],
          [('Comunicação interna publicada', ['Pessoas', 'etapa 4'])]),
        E('Medir e registrar', 'Gestão', 'Autopiloto', 'baixo',
          [('Comunicação interna publicada', 'etapa 3')],
          [T('Medir alcance e entendimento', A),
           T('Registrar a medição para o próximo ciclo', R)],
          [('Medição da comunicação interna', ['etapa 1'])]),
    ]))

# ========================================================== ATIVOS E ADMINISTRAÇÃO
JORNADAS.append(dict(
    code='GE-12',
    nome='Gerir os ativos, os espaços e os serviços administrativos',
    dominio='Ativos e administração', classe='essencial', onda=1,
    objetivo='Fazer cada pedido de ativo, de espaço ou de serviço administrativo ser atendido pela melhor opção (comprar, alugar, remanejar ativo ocioso ou recusar), decidida pela Gestão dentro do orçamento; cada ativo ser registrado com o responsável e a depreciação, mantido e inventariado; e cada ativo ocioso, perdido ou no fim da vida ser baixado (vendido, doado, reciclado ou descartado), com os dados guardados nele eliminados. A Gestão decide e controla; a compra segue a jornada de compras.',
    frequencia='Por evento: pedido de ativo, espaço ou serviço; e a cada ciclo de manutenção e inventário (cadência: inventário anual; manutenção pelo plano de cada ativo)',
    automacao=('alta', 'Avaliar o pedido, pedir a compra, registrar, programar a manutenção, inventariar e executar a baixa são de agente e automação; decidir o atendimento e o destino do ativo são de pessoa da Gestão.'),
    base=['apqc'],
    lanes=['SOL', P, A, R],
    inicios=[I('Pedido de ativo, de espaço ou de serviço administrativo recebido', 'SOL', 'message'),
             I('Ciclo de manutenção e inventário iniciado', R, 'timer')],
    fins=[F('Ativo atendido, registrado, mantido ou baixado', R),
          F('Pedido atendido ou recusado, sem ativo a registrar', R)],
    etapas=[
        E('Avaliar e atender o pedido', 'Gestão', 'Copiloto', 'médio',
          [('Pedido de ativo, de espaço ou de serviço administrativo', 'Solicitante'), (PLANO_CAP, 'Operações'),
           (REC_LIB_OP, 'Operações'), (ORC_VIG, 'GE-01'), (ALCADAS, 'Governança')],
          [D('O que iniciou o trabalho?', R,
             [S('Pedido de ativo, de espaço ou de serviço', 'seg'),
              S('Ciclo de manutenção e inventário', 'E2')]),
           T('Avaliar o pedido: comprar, alugar, remanejar ativo ocioso ou recusar', A),
           T('Decidir o atendimento do pedido', P),
           D('O atendimento pede compra ou contrato?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Pedir a compra ou o contrato pela jornada de compras', R)])]),
           D('O atendimento cria ou muda um ativo?', R,
             [S('Não: serviço atendido ou pedido recusado', 'F2', via=[T('Responder a quem pediu', R)]),
              S('Sim', 'prox')])],
          [(PED_COMPRA, ['GE-04']),
           ('Ativo ou serviço a registrar', ['etapa 2'])]),
        E('Registrar e manter os ativos e fazer o inventário', 'Gestão', 'Autopiloto', 'baixo',
          [('Ativo ou serviço a registrar', 'etapa 1')],
          [T('Registrar o ativo, o responsável e a depreciação', R),
           T('Programar e acompanhar a manutenção', A),
           T('Conferir o inventário e apontar ativo ocioso, perdido ou a baixar', A)],
          [('Ativos apontados para baixa', ['etapa 3']),
           (ATIVOS, ['GE-05'])]),
        E('Baixar o ativo', 'Gestão', 'Copiloto', 'médio',
          [('Ativos apontados para baixa', 'etapa 2')],
          [D('Há ativo a baixar?', A,
             [S('Não', 'prox'),
              S('Sim', 'seg')]),
           T('Decidir vender, doar, reciclar ou descartar o ativo', P),
           T('Eliminar os dados guardados no ativo e executar a baixa', R)],
          [(ATIVOS, ['GE-05'])]),
    ]))

# -------------------------------------------------------------- domínios
DOMINIOS = [
    ('Planejamento e controle', 'Orçamento aprovado desdobrado e controlado e ritual de acompanhamento dos alvos.'),
    ('Finanças', 'Faturamento e cobrança, compras e pagamentos, caixa, contas, impostos, prestação de contas e rateio.'),
    ('Pessoas e cultura', 'Provimento, integração à cultura, avaliação, desenvolvimento, folha, rituais, reconhecimento e comunicação interna.'),
    ('Ativos e administração', 'Ativos, espaços e serviços administrativos.'),
]

ONDAS = {
    1: 'O que os círculos fechados já esperam da Gestão: orçamento, ritual, faturamento, compras, contas, rateio, pessoas e ativos',
}

# ------------------------------------------------- o que usamos de cada fonte
USO = {
    'apqc': 'PCF 7.4. Os processos da Gestão estão em três categorias e num grupo: 7.0, capital humano (planejamento, recrutamento, integração, desempenho, desenvolvimento, recompensa, desligamento, informação e comunicação com as pessoas), base da GE-07 a GE-11 e da GE-13; 9.0, recursos financeiros (planejamento e orçamento, receita, contabilidade, folha, contas a pagar, tesouraria e impostos), base da GE-01, da GE-03 a GE-06 e da GE-13; 10.0, ativos (planejar e adquirir, manter e baixar), base da GE-12; e o grupo 4.2, compra de materiais e serviços, base da GE-04. O grupo 9.8, controles internos, fica com a Governança. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.',
    'lgpd': 'Na GE-07 e na GE-09 (e também na GE-08, na GE-10 e na GE-13, que usam dados de pessoas): os dados de candidatos e de pessoas são dados pessoais, tratados com finalidade, adequação e necessidade (art. 6º, I a III) e pelas regras de sigilo da Governança. Na GE-07, a triagem feita pelo agente é revista por pessoa antes de recusar candidatos, porque o titular pode pedir a revisão de decisão tomada só por tratamento automatizado (art. 20, caput). Na GE-09, a pesquisa de cultura é analisada sem identificar quem respondeu.',
    'bpmn': 'Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, serviço, script e recebimento; a tarefa de outro círculo ou papel aparece como tarefa simples.',
    'camunda': 'Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.',
    'sipoc': 'Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.',
    'clt': 'Na GE-13: o salário mensal é pago até o quinto dia útil do mês seguinte (art. 459, § 1º); as férias, até dois dias antes do início (art. 145); acima de vinte trabalhadores no estabelecimento, o registro de entrada e saída é obrigatório, e o ponto por exceção é permitido por acordo (art. 74, §§ 2º e 4º). Na GE-07: no desligamento, as verbas rescisórias e os documentos são entregues em até dez dias do término do contrato (art. 477, § 6º).',
    'fgts': 'Na GE-13: o depósito do FGTS é feito até o vigésimo dia de cada mês (art. 15, na redação da Lei 14.438/2022, com a arrecadação digital).',
    'cc2002': 'Na GE-05: cada empresa segue um sistema de contabilidade com escrituração uniforme e levanta todo ano o balanço patrimonial e o de resultado (art. 1.179), com o livro Diário (art. 1.180), e guarda a escrituração enquanto não houver prescrição ou decadência (art. 1.194).',
}

# ----------------------------------- cobertura do referencial (APQC PCF 7.4)
COBERTURA = [
    ('4.2.2', 'Select suppliers and develop/maintain contracts', 'GE-04, etapa 2, com a Governança no contrato'),
    ('4.2.3', 'Order materials and services', 'GE-04, etapas 1 a 3'),
    ('4.2.4', 'Manage suppliers', 'GE-04, etapa 4'),
    ('7.1', 'Develop and manage human resources planning, policies, and strategies', 'Em parte: as pessoas do plano de capacidade (OP-01) e do orçamento (GE-01). As políticas de pessoas seguem as regras e alçadas da Governança; a estratégia de pessoas não tem etapa própria: fica como limite'),
    ('7.2', 'Recruit, source, and select employees', 'GE-07, etapas 1 a 3'),
    ('7.3.1', 'Manage employee orientation and deployment', 'GE-08'),
    ('7.3.2', 'Manage employee performance', 'GE-09, etapa 1'),
    ('7.3.3', 'Manage employee career development', 'GE-09, etapa 2, e GE-07, etapa 1, na promoção'),
    ('7.3.4', 'Develop and train employees', 'GE-09, etapa 2'),
    ('7.4', 'Manage employee relations', 'Limite: relações sindicais, negociação coletiva e queixas de pessoas não têm etapa própria; o canal de relato é da Governança'),
    ('7.5.1', 'Develop and manage reward, recognition, and motivation programs', 'GE-10 e GE-09, etapa 1, na remuneração'),
    ('7.5.2', 'Manage and administer benefits', 'Limite: não desenhado como etapa própria'),
    ('7.5.3', 'Manage employee assistance and retention', 'Limite: não desenhado como etapa própria'),
    ('7.5.4', 'Administer payroll', 'GE-13'),
    ('7.6.1', 'Manage promotion and demotion process', 'GE-07, etapa 1'),
    ('7.6.2', 'Manage separation', 'GE-07, etapa 1'),
    ('7.6.4', 'Manage leave of absence', 'Limite: não desenhado como etapa própria'),
    ('7.7', 'Manage employee information and analytics', 'GE-07, etapa 4 (registro) e GE-09, etapa 3 (análise com a pesquisa)'),
    ('7.8.1', 'Develop employee communication plan', 'GE-11, etapa 1'),
    ('7.8.2', 'Conduct employee engagement surveys', 'GE-09, etapa 3'),
    ('7.8.3', 'Deliver employee communications', 'GE-11, etapas 2 a 4'),
    ('9.1.1', 'Perform planning/budgeting/forecasting', 'GE-01; a montagem do orçamento é tarefa da Gestão na ES-03, etapa 3'),
    ('9.1.2', 'Perform cost accounting and control', 'GE-05, etapa 2, e GE-06'),
    ('9.1.4', 'Evaluate and manage financial performance', 'GE-05, etapa 2, e GE-02'),
    ('9.2.1', 'Process customer credit', 'Limite: a análise de crédito do cliente não tem etapa própria'),
    ('9.2.2', 'Invoice customer', 'GE-03, etapa 2'),
    ('9.2.3', 'Process accounts receivable (AR)', 'GE-03, etapa 3'),
    ('9.2.4', 'Manage and process collections', 'GE-03, etapa 3'),
    ('9.2.5', 'Manage and process adjustments/deductions', 'GE-03, etapa 2: crédito na fatura ou reembolso ao cliente'),
    ('9.3.1', 'Manage financial policies and procedures', 'Em parte: a Gestão aplica as políticas; as regras e alçadas são da Governança'),
    ('9.3.2', 'Perform general accounting', 'GE-05, etapas 1 e 2'),
    ('9.3.3', 'Perform fixed-asset accounting', 'GE-12, etapa 2, e GE-05, etapa 2'),
    ('9.3.4', 'Perform financial reporting', 'GE-05, etapa 2'),
    ('9.5', 'Process payroll', 'GE-13'),
    ('9.6.1', 'Process accounts payable (AP)', 'GE-04, etapa 5, inclusive a remuneração de parceiros'),
    ('9.6.2', 'Process expense reimbursements', 'Limite: não desenhado como etapa própria'),
    ('9.7.2', 'Manage cash', 'GE-05, etapa 1'),
    ('9.7.4', 'Manage debt and investment', 'Em parte: aportes e distribuição decididos pelos sócios (GE-05, etapa 3). Dívida e aplicações não têm etapa própria'),
    ('9.7.6', 'Manage financial fraud/dispute cases', 'Fora: Governança, pelo canal de relato'),
    ('9.8', 'Manage internal controls', 'Fora: Governança'),
    ('9.9.1', 'Develop tax strategy and plan', 'Limite: não desenhado como etapa própria'),
    ('9.9.2', 'Process taxes', 'GE-05, etapa 2'),
    ('10.1', 'Plan and acquire assets', 'GE-12, etapa 1'),
    ('10.2', 'Design and construct assets', 'Limite: obras não foram desenhadas'),
    ('10.3', 'Maintain assets', 'GE-12, etapa 2'),
    ('10.4', 'Manage asset end-of-life', 'GE-12, etapa 3'),
]

# --------------------------------------------------- o que a Gestão não faz
FRONTEIRAS = [
    ('Escolher o rumo, aprovar alvos e orçamento e realocar entre empresas', 'Estratégia e sócios',
     'A posição e a projeção de caixa (GE-05), o resultado por empresa (GE-05), a execução do orçamento (GE-05) e os desvios e decisões do ritual (GE-02). A montagem do orçamento é tarefa da Gestão dentro da ES-03.'),
    ('Definir alçadas, políticas, o critério de rateio e as regras de sigilo; guardar contratos; auditar', 'Governança',
     'O contrato de fornecedor (GE-04), as demonstrações e obrigações fiscais (GE-05), os aportes e distribuições executados (GE-05), a contestação do critério de rateio (GE-06) e o conteúdo interno sensível (GE-11).'),
    ('Definir a cultura, o kit de pessoas, a voz e a marca', 'Identidade',
     'O resultado da pesquisa de cultura e os dados de pessoas (GE-09) e a consulta sobre caso não coberto (GE-11).'),
    ('Confirmar a entrega e pedir compras de materiais', 'Operações',
     'A Gestão fatura as entregas confirmadas (GE-03), compra o que foi pedido (GE-04) e confirma os recursos do plano de capacidade (GE-01).'),
    ('Vender, fixar preço e fechar contrato com o cliente', 'Negócios',
     'A situação de faturas e pagamentos de cada cliente (GE-03). A Gestão confere margem e caixa como tarefa nas jornadas de Negócios (NE-01 e NE-07).'),
    ('Comunicar para fora', 'Relações', 'O orçamento de demanda e a resposta ao pedido de recurso adicional (GE-01); a situação de faturas e pagamentos (GE-03).'),
    ('Dar e retirar acessos e comprar tecnologia', 'Integração',
     'O pedido de acesso ou de retirada de acesso (GE-07). As tarefas de compra que a Integração dá à Gestão (licença e fornecedor de tecnologia na IT-07; o que falta para a implantação na IT-02) são feitas pela GE-04, como pedido de compra de quem pede.'),
    ('Escolher quem entra na equipe e avaliar a pessoa', 'Líder da equipe',
     'O líder decide a contratação (GE-07), avalia (GE-09), acompanha a integração cultural (GE-08), decide as ações do ritual na sua alçada (GE-02) e conduz o ritual de cultura (GE-10); a Gestão conduz, confere e registra.'),
]

# -------------------------------------------------------- pontos para decidir
PONTOS = []
DECISOES = [
    ('A Gestão decide o seu ofício dentro da alçada; o executivo decide o que passa dela',
     'Ponto 1, aprovado por você (11:50 de 03/10/2026)',
     'Mesma regra dos outros círculos. Os sócios aprovam alvos e orçamento (ES-03) e decidem alocação e destino do resultado (ES-02); a Gestão desdobra, controla e executa.'),
    ('O líder decide quem entra na sua equipe; a Gestão conduz e confere',
     'Ponto 2, aprovado por você (11:50)',
     'GE-07, etapa 2. O desligamento é decidido pelo executivo, com o líder, como exceção declarada na regra do círculo.'),
    ('As quatro jornadas vindas da Identidade ficam como jornadas da Gestão, com o propósito pessoal dentro do desenvolvimento',
     'Ponto 3, aprovado por você (11:50)',
     'Integração cultural (GE-08), rituais e reconhecimento (GE-10) e comunicação interna (GE-11), como transferidas em 01/10/2026; o propósito pessoal, que o destino da transferência já punha “dentro do ciclo de desenvolvimento”, virou etapa voluntária da GE-09, com o ajuste de papel só com o acordo da pessoa.'),
    ('O rateio é aplicado pela Gestão pelo critério da Governança',
     'Ponto 4, aprovado por você (11:50)',
     'GE-06, como a fronteira da Estratégia já dizia. O executivo opina; a contestação do critério vai à Governança.'),
    ('A Gestão confirma ao plano de capacidade os recursos que cabem no orçamento',
     'Ponto 5, aprovado por você (11:50)',
     'GE-01, etapa 1. A contratação e a compra seguem na GE-07 e na GE-04.'),
    ('A realocação entre empresas não é decidida na Gestão',
     'Ponto 6, aprovado por você (11:50)',
     'O pedido acima da alçada vai ao executivo; entre empresas, fica registrado para a revisão do portfólio (ES-02), que lê a execução do orçamento.'),
    ('A folha é jornada própria; a remuneração de parceiros é paga na jornada de compras e pagamentos', 'Ponto 7, aprovado por você (11:50)',
     'GE-13 e GE-04, como Negócios pediu: a remuneração de quem vende e de parceiros fica com a Gestão.'),
    ('Treze jornadas', 'Ponto 8, aprovado por você (11:50)', 'GE-01 a GE-13.'),
    ('Auditoria de execução: modo de cada etapa e nível de automação pelo que as tarefas fazem',
     'Itens 1 a 14 da auditoria, aprovados por você (12:33 de 03/10/2026)',
     'De Assistido para Copiloto, pelas tarefas: GE-02 etapa 2. De Autopiloto para Autômato, pelas tarefas: GE-01 etapa 3, GE-02 etapa 3, GE-07 etapa 4, GE-11 etapa 3. De Copiloto para Assistido, pelas tarefas: GE-06 etapa 2, GE-07 etapa 2, GE-08 etapa 2, GE-09 etapa 1, GE-10 etapa 2. Nível de automação pela faixa: GE-05 média → alta; GE-06 alta → média; GE-12 média → alta.'),
    ('A regra de remuneração é dos sócios; fontes da folha e da escrituração',
     'Decidido e pedido por você (13:09 de 03/10/2026)',
     'A Gestão aplica a regra que os sócios decidem. GE-13 e GE-07: CLT (arts. 74, 145, 459 e 477) e FGTS (art. 15); GE-05: Código Civil (arts. 1.179, 1.180 e 1.194). A regra fiscal depende do regime de cada empresa, que não está no modelo.'),
    ('Alçadas da Gestão',
     'Aprovado por você (13:51 de 03/10/2026)',
     'Remanejamento dentro do círculo e da empresa sem mudar o total: Gestão; entre círculos, executivo; entre empresas, Estratégia; aumento do total, sócios. Cobrança privada: na segunda fatura vencida, proposta de suspensão ao executivo; contrato público segue a lei e o contrato. Pagamento só com pedido, recebimento e nota conferidos; quem lança não aprova; fora do orçamento, executivo; acima da reserva de contingência, sócios. Aportes e distribuição: só o que os sócios decidiram; contas e poderes bancários com o executivo e a Governança. Vaga no orçamento: Gestão com o líder; fora, executivo; desligamento de executivo ou líder, sócios.'),
    ('Cadências e conteúdos validados; gates de implantação',
     'Validado por você (14:07 de 03/10/2026)',
     'Cadências da Gestão (fechamento, rateio, folha, avaliação, cultura, comunicação, inventário); políticas de cobrança, compras, remuneração e desenvolvimento; critério de rateio. O que depende de dado real ficou nos gates G1 a G9.'),
    ('Correções da auditoria geral',
     'Aprovado por você (16:05 de 03/10/2026)',
     'Administrador do IMTS.OS (você) decide acima dos círculos compartilhados: recurso (GE-01), contas do IMTS.OS (GE-05), pessoas, remuneração e folha dos círculos (GE-07, GE-09, GE-13) (D2). Quem prepara não aprova: o líder do círculo aprova pagamento, reembolso, fechamento e impostos (GE-03, GE-04, GE-05); a folha e a remuneração têm o executivo ou o Administrador como segundo aprovador (D3). Aumento do orçamento e compra acima da reserva vão aos sócios; desligamento de executivo ou de líder também (M1). A comissão sai da receita recebida (M6); a segunda fatura vencida leva à proposta de suspensão ao executivo (M7). GE-02: desvio grave à ES-06, mudança de alvo à Estratégia, recurso novo à GE-01, e fim próprio para ação em atraso (M9, L1, L7).'),
]

PROPOSTAS = []

ALERTAS = [
    ('Governança (círculo 9)', 'A Gestão espera da Governança as regras e alçadas vigentes, as regras de sigilo e de dados pessoais, o critério de rateio do custo dos círculos, a revisão e a guarda dos contratos de fornecedor e a validação do conteúdo interno sensível. Entrega o contrato de fornecedor, as demonstrações e obrigações fiscais do período, os aportes e distribuições executados e a contestação do critério de rateio.'),
]

# ------------------------------------------------ relação com o catálogo da rodada 2
MUDANCAS = [
    ('Acrescentado', 'Sem equivalente', 'GE-01',
     'Desdobramento e controle do orçamento aprovado, pedido pela Estratégia (ES-02 e ES-03), por Relações (RE-01) e por Operações (OP-01).'),
    ('Acrescentado', 'Sem equivalente', 'GE-02',
     'Ritual de acompanhamento dos alvos, que a Estratégia deixou com a Gestão no fechamento do círculo 2.'),
    ('Ajustado', 'V5 · Da entrega ao recebimento (parte de faturar e receber)', 'GE-03',
     'A Gestão fatura as entregas confirmadas por Operações (OP-02) e informa a situação de cada cliente a Relações e a Negócios.'),
    ('Ajustado', 'C7 · Da compra ao pagamento', 'GE-04',
     'Ganha a avaliação e a cobrança do fornecedor e o contrato revisado pela Governança.'),
    ('Ajustado', 'I-GE1 · Do extrato ao caixa projetado e C8 · Do registro à prestação de contas', 'GE-05',
     'Juntas numa jornada: caixa, fechamento, impostos, resultado, prestação de contas e execução de aportes e distribuição.'),
    ('Ajustado', 'E3 · Do custo corporativo ao rateio', 'GE-06',
     'A Gestão aplica o critério definido pela Governança com a Estratégia.'),
    ('Ajustado', 'C6 · Da vaga ao talento', 'GE-07',
     'Provimento, movimentação e desligamento, com a escolha pelo líder.'),
    ('Ajustado', 'ID-05 do círculo 1 (transferida) · Integrar pessoas novas à cultura', 'GE-08',
     'Rascunho da Identidade assumido pela Gestão, com a verificação e o registro numa etapa.'),
    ('Ajustado', 'ID-07 do círculo 1 (transferida) · Propósito pessoal', 'GE-09',
     'Avaliação, desenvolvimento, propósito pessoal voluntário e pesquisa de cultura.'),
    ('Ajustado', 'I-GE2 · Da folha ao pagamento das pessoas', 'GE-13',
     'Folha com variáveis, comissões de quem vende, reconhecimentos e mudanças de remuneração.'),
    ('Ajustado', 'ID-06 do círculo 1 (transferida) · Rituais e reconhecimento', 'GE-10',
     'Rascunho da Identidade assumido pela Gestão.'),
    ('Ajustado', 'ID-09 do círculo 1 (transferida) · Comunicação interna e institucional', 'GE-11',
     'Só a parte interna; a externa é de Relações (RE-07).'),
    ('Ajustado', 'I-GE3 · Do ativo adquirido ao ativo baixado', 'GE-12',
     'Ganha os espaços e os serviços administrativos e a eliminação de dados guardados no ativo baixado.'),
]

LIMITES = [
    'Os fluxos são descritivos. Para executar falta escolher o motor e ligar cada tarefa a um sistema.',
    'Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado. O alerta do círculo 1 sobre a carga humana das jornadas transferidas continua sem medida.',
    'O ritual de acompanhamento é mensal, pelo método de estratégia aprovado em 03/10/2026. As outras cadências (fechamento, folha, avaliação, rituais de cultura, comunicação interna, rateio e inventário) são decididas pelo líder do círculo, na implantação.',
    'Os rascunhos de políticas de cobrança, compras, remuneração e desenvolvimento foram validados em 03/10/2026 (aba Gates de implantação); o texto final é o gate G8, e os números que dependem de dado real ficam nos gates G3 e G9.',
    'Da área trabalhista e contábil foram lidos os prazos da folha, das férias e da rescisão (CLT), o depósito do FGTS e a escrituração (Código Civil), conferidos no texto oficial (Planalto) em 03/10/2026. A regra fiscal não foi citada: os tributos dependem do regime de cada empresa, que não está no modelo (empresas e pessoas ficaram para depois). A apuração segue a lei vigente, com a assessoria.',
    'Estratégia e políticas de pessoas (APQC 7.1), relações sindicais e queixas (7.4), benefícios (7.5.2), reembolso de despesas (9.6.2), dívida e aplicações (9.7.4) não têm etapa própria.',
    'O fornecedor não é uma parte do vocabulário do modelo: as trocas com ele aparecem como tarefas da Gestão.',
    'A cobrança judicial e a recusa de pedido de compra pelo executivo não têm ramo desenhado: a recusa devolve o pedido a quem pediu.',
    'O pedido de recurso que mexe na alocação entre empresas fica registrado para a revisão do portfólio: a ES-02 não tem entrada para um pedido direto e lê a execução do orçamento.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024.',
    'Com os nove círculos fechados (03/10/2026), as trocas com os outros oito foram conferidas dos dois lados pelo nome: 409 trocas, sem problema.',
    'A tarefa de quem não é do círculo (líder, pessoa, executivo, outro círculo) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As saídas estão listadas por etapa, não por caminho.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das doze jornadas, conferiu os 38 códigos e nomes do APQC PCF 7.4 (todos conferem) e o art. 6º da LGPD, e apontou 22 achados, 4 graves: caminhos que caíam na etapa seguinte sem ter o que processar (orçamento, faturamento e ativos), a remuneração de parceiros sem jornada, a compra pedida pela Integração por fora da jornada de compras e o reembolso ao cliente sem pagamento.',
    'Todos foram corrigidos ou declarados como limite; a folha virou jornada própria (GE-13). A versão corrigida passou por todos os testes automáticos e não passou por nova revisão independente.',
]
