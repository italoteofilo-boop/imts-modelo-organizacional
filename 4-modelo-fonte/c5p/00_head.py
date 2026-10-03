# -*- coding: utf-8 -*-
"""Círculo 5 · Negócios. Fechado em 02/10/2026: sete jornadas.
Regra do círculo: Negócios decide o que é do seu ofício (o aceite da oportunidade, o escopo e a proposta dentro do catálogo,
a tabela de preços e a política comercial, a concessão dentro da alçada e a participação em licitação), ouvido o executivo.
O executivo aprova a concessão acima da alçada de quem vende e assina pela empresa; acima da alçada dele, decidem os sócios.
Relações gera e qualifica a demanda e acompanha o cliente; a Inteligência desenha a oferta e o preço-base; a Integração
implanta; Operações entrega; a Gestão fatura; a Governança mantém os modelos e as alçadas, revisa e guarda os contratos."""
from dsl import configurar, T, PAR, S, D, E, I, F, TODOS

NUM, NOME, SIGLA, PREF = 5, 'Negócios', 'NE', 'NE'
LANES, PARTES = configurar(NOME, SIGLA, PREF)
SLUG = 'circulo5-negocios'
FECHADO = True
STATUS = 'Fechado em 02/10/2026 · proposta do círculo 6 aplicada em 03/10/2026 · auditoria de execução aplicada em 03/10/2026'
LEAD = ('Negócios transforma oportunidade em contrato e cuida dos contratos dos clientes. Mantém a tabela de preços e a '
        'política comercial, planeja as vendas e prevê a receita, faz a proposta, negocia e fecha o contrato, disputa '
        'licitações, renova, amplia, adita e encerra contratos e vende com parceiros e em oferta conjunta entre as empresas. '
        'Não gera demanda, não desenha a oferta, não implanta, não entrega e não fatura. São sete jornadas.')
PRINCIPIO = ('Regra do círculo, aprovada às 20:11: Negócios decide o que é do seu ofício (o aceite da oportunidade, o escopo e a '
             'proposta dentro do catálogo, a tabela de preços e a política comercial, a concessão dentro da alçada de quem '
             'vende e a participação em licitação), ouvido o executivo da empresa. O executivo aprova a concessão acima da '
             'alçada de quem vende e assina pela empresa; acima da alçada dele, decidem os sócios; a faixa de desconto de quem vende é '
             'aprovada pela Governança. Relações gera e qualifica a '
             'demanda e acompanha o cliente; a Inteligência desenha a oferta e o preço-base; a Integração implanta; Operações '
             'entrega; a Gestão fatura; a Governança mantém os modelos e as alçadas e revisa e guarda os contratos.')
MUDOU_INTRO = ('Comparação com o catálogo da rodada 2 (49 jornadas e 216 workflows), que continua no documento do '
               'projeto até cada círculo ser fechado. Azul: acrescentado. Verde: ajustado. Vermelho: retirado.')
COBERTURA_TXT = ('Processos do APQC PCF 7.4 ligados às funções de Negócios, grupo a grupo: onde cada um está neste '
                 'modelo. Os nomes estão como no referencial.')

P, A, R = 'NEP', 'NEA', 'NER'

# produtos de Negócios usados em mais de uma jornada ou esperados pelos círculos fechados
TABELA = 'Tabela de preços e política comercial vigentes'
PLANO_VEN = 'Plano de vendas do ciclo: alvos por empresa, oferta e canal'
PREVISAO = 'Previsão de receita e de vendas'
ACEITE = 'Aceite ou devolução da oportunidade, com o motivo'
CONTRATO = 'Contrato de cliente assinado, com o escopo vendido'
VENC = 'Vencimento do contrato e resultado da renovação'
REGISTROS = 'Registros de propostas, vendas e contratos'
MOTIVOS = 'Motivos de ganho e de perda de propostas'
DESEMP_PRECO = 'Desempenho de preço: descontos dados e perdas por preço'
PROP_NEG = 'Proposta aceita ou em negociação'
MUD_ESCOPO = 'Mudança de escopo pedida na negociação'
PED_CARTEIRA = 'Pedido de cliente com contrato vigente'
EDITAL = 'Edital ou pedido de cotação de órgão público'
ATA = 'Ata de registro de preços vigente, com saldo e órgãos participantes'
OPORT_PARC = 'Oportunidade de parceiro ou de oferta conjunta passada à proposta'
# produtos que Negócios entrega a círculos fechados por porta de pedido (nomes que eles já recebem)
CONSULTA = 'Consulta sobre caso não coberto'
PED_OFERTA = 'Pedido de ajuste ou de revisão de oferta em uso'
IDEIA = 'Ideia ou aposta nova'
CONTATO = 'Contato de interessado'
ENC_PARC = 'Pedido de encerramento de parceria'
# produtos de outros círculos
PORTALVO = 'Portfólio-alvo: papel de cada empresa, oferta e aposta'
ALVOS = 'Alvos e iniciativas do ciclo'
OFERTA_LANC = 'Oferta aprovada para lançamento'
DEC_ENCERRAR = 'Decisão de encerrar aposta em desenvolvimento ou oferta em uso'
DATA_SAIDA = 'Data de saída confirmada da aposta ou da oferta encerrada'
MANDATO = 'Mandato da empresa'
OFERTA_CAT = 'Oferta no catálogo de ofertas: escopo, método, conteúdo-base, preço-base e indicadores'
OFERTA_FORA = 'Aposta ou oferta encerrada e fora do catálogo de ofertas'
EM_CURSO_SAI = 'Ofertas, apostas e pilotos em curso da empresa que sai'
RESP_OFERTA = 'Resposta ao pedido sobre oferta em uso'
LEITURA = 'Leitura de mercado, clientes e concorrentes'
PAINEL = 'Painel de indicadores de cada círculo, com dono e análise'
PADROES_ID = 'Padrões de identidade vigentes'
RESPOSTA_ID = 'Resposta à consulta'
PACOTE_MARCA = 'Pacote de marca publicado'
MARCA_RET = 'Marca retirada de uso'
MAT_VENC = 'Aviso de materiais vencidos'
POSIC = 'Posicionamento e casa de mensagens vigentes'
LACUNAS_EXEC = 'Lacunas de execução apontadas'
PLANO_DEM = 'Plano de demanda do ciclo: públicos, ofertas, canais, ações, alvos e orçamento'
CRITERIO = 'Critério de oportunidade qualificada combinado com Negócios'
OPORT_Q = 'Oportunidade qualificada, com o contato, a necessidade e a origem'
OPORT_SEM = 'Oportunidade sem resposta no prazo'
FUNIL = 'Situação do funil: contatos, oportunidades entregues, aceitas e devolvidas'
BASE_REL = 'Base de relacionamento atualizada, com a base legal e o histórico'
CX = 'Estratégia de experiência do cliente: personas, mapa da jornada e padrões de experiência'
PLANO_SUC = 'Plano de sucesso do cliente: resultados esperados, marcos e contatos'
OPORT_REN = 'Oportunidade de renovação ou de expansão, com o histórico'
CLI_SAIDA = 'Clientes avisados da saída, com a transição combinada'
PARC_ATIVA = 'Parceria ativa, com plano de ativação'
RES_PARC = 'Resultado da parceria'
LACUNAS_PERC = 'Lacunas de percepção encaminhadas ao dono'
ALCADAS = 'Regras e alçadas vigentes'
MODELOS = 'Modelos de proposta e de contrato'
HABILIT = 'Certidões e documentos de habilitação em dia'
PLANO_SAIDA = 'Plano de saída de clientes e contratos'
FATURAS = 'Situação de faturas e pagamentos do cliente'

JORNADAS = []
