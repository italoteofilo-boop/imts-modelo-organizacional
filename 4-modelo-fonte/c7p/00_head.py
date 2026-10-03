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
