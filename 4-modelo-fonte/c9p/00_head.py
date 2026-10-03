# -*- coding: utf-8 -*-
"""Círculo 9 · Governança. Fechado em 03/10/2026, aprovado às 11:50: dez jornadas.
Regra do círculo: a Governança decide o que é do seu ofício (a redação e a publicação das regras, a revisão jurídica, a
guarda dos contratos, a amostra e o julgamento da auditoria, a resposta ao titular de dados e a comunicação à autoridade),
dentro da alçada. Os sócios decidem as regras gerais, as alçadas dos executivos e o que a lei reserva a eles; o
executivo, com a Governança, responde à crise; os círculos donos executam e corrigem."""
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
             'as regras gerais, as alçadas dos executivos e o que a lei reserva a eles; o executivo, com a Governança, '
             'responde à crise; os círculos donos executam e corrigem.')
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
