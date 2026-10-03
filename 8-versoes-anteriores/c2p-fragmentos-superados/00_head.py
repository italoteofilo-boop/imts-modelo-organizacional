# -*- coding: utf-8 -*-
"""Círculo 2 · Estratégia. Fechado em 01/10/2026, com as 18 mudanças aprovadas às 20:02: seis jornadas.
Regra: a Estratégia formula e propõe a direção, o portfólio, os alvos e a alocação, que os sócios aprovam;
decide com o executivo, dentro da alçada, a aposta que entra e a oferta que é lançada; e acompanha se as
hipóteses se confirmam. Na formulação, o executivo e o líder do círculo propõem e participam, mas não decidem."""
from dsl import configurar, T, PAR, S, D, E, I, F, TODOS

NUM, NOME, SIGLA, PREF = 2, 'Estratégia', 'ES', 'ES'
LANES, PARTES = configurar(NOME, SIGLA, PREF)
SLUG = 'circulo2-estrategia'
FECHADO = True
STATUS = 'Fechado em 01/10/2026 · mudanças aprovadas aplicadas em 02/10/2026'
LEAD = ('A Estratégia faz o trabalho de estratégia de ponta a ponta: formula, propõe, desdobra em alvos, decide os '
        'portões dentro da alçada e acompanha as hipóteses. Na formulação, o executivo e o líder do círculo propõem e '
        'participam, mas não decidem. Os sócios aprovam. A Gestão opera a rotina: orçamento e ritual de '
        'acompanhamento. A Integração é o PMO corporativo e coordena projetos, implantações e lançamentos. '
        'São seis jornadas.')
PRINCIPIO = None
MUDOU_INTRO = ('Comparação com o catálogo da rodada 2 (49 jornadas e 216 workflows), que continua no documento do '
               'projeto até cada círculo ser fechado, e com a versão fechada às 15:48. As linhas marcadas “aprovada às '
               '20:02” incluem os acertos feitos em 02/10/2026, depois da revisão independente, para cada proposta '
               'funcionar. Azul: acrescentado. Verde: ajustado. Vermelho: retirado.')

# produtos usados em mais de uma jornada
ESTRAT = 'Estratégia vigente do Ecossistema e das empresas'
DIRECAO = 'Direção estratégica e públicos prioritários'
PORTALVO = 'Portfólio-alvo: papel de cada empresa, oferta e aposta'
HIPOT = 'Hipóteses da estratégia e sinais a vigiar'
METODO = 'Método de estratégia vigente: critérios dos portões, regras de realocação e calendário'
MANTIDA = 'Diagnóstico e decisão de manter a estratégia'
ALOC = 'Alocação de recursos por empresa, oferta e aposta'
ALVOS = 'Alvos e iniciativas do ciclo'
ALVOS_PROP = 'Alvos propostos, para definição das fichas dos indicadores'
CARTEIRA = 'Situação da carteira de apostas'
SAIDA = 'Estudo de saída pedido para empresa, oferta ou aposta'
PORTF = 'Portfólio de empresas atualizado'
CAUSAS = 'Desvios com causa concluída'
AP_OFERTA = 'Aposta aprovada para desenho e validação da oferta, com recursos'
AP_EMPRESA = 'Aposta aprovada para empresa própria, com recursos'
OFERTA_LANC = 'Oferta aprovada para lançamento'
DEC_ENCERRAR = 'Decisão de encerrar aposta em desenvolvimento ou oferta em uso'
DATA_SAIDA = 'Data de saída confirmada da aposta ou da oferta encerrada'
PEDIDO_OFERTA = 'Pedido de ajuste ou de revisão de oferta em uso'
REVISAO_AP = 'Pedido de revisão da aposta ou da oferta'
CASO = 'Caso de criação, aquisição, venda ou encerramento'
ARQUIVADO = 'Caso arquivado, com o motivo'
LICAO_CASO = 'Lição do caso arquivado, sem dado sigiloso'
MANDATO = 'Mandato da empresa'
PERGUNTA = 'Pergunta de decisão, com a decisão apoiada, o risco e o prazo'
CONSULTA = 'Consulta sobre caso não coberto'
# produtos de outros círculos
DECL = 'Declaração de identidade vigente'
PADROES_ID = 'Padrões de identidade vigentes'
RESPOSTA_ID = 'Resposta à consulta'
RELAT = 'Relatório de alinhamento'
RESULT = 'Resultado por empresa e consolidado'
EXEC_ORC = 'Execução do orçamento e da alocação por empresa, oferta e aposta'
CAIXA = 'Posição e projeção de caixa'
INDIC = 'Indicadores e análises por empresa, oferta e aposta'
FICHAS_IND = 'Fichas dos indicadores decididas e confirmadas pelos donos'
RISCOS = 'Relatório de riscos e conformidade'
ALCADAS = 'Regras e alçadas vigentes'
LEITURA = 'Leitura de mercado, clientes e concorrentes'
RESPOSTA_IN = 'Resposta com evidência, fonte e grau de confiança'
DEVOLVIDA_IN = 'Aposta devolvida com evidência e recomendação'
PLANO_SAIDA = 'Plano de saída: clientes, contratos e pessoas'

JORNADAS = []
