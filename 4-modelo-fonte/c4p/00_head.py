# -*- coding: utf-8 -*-
"""Círculo 4 · Relações. Fechado em 02/10/2026: oito jornadas.
Regra do círculo: Relações decide o que é do seu ofício (o plano de demanda, a qualificação das oportunidades,
a estratégia de experiência do cliente, a pauta e o conteúdo externo e as parcerias dentro da alçada), ouvidos o
executivo e Negócios. Negócios vende e renova; Operações atende e entrega; a Identidade dá a marca e os padrões;
a Governança conduz o comitê de crise, e o dono da crise decide; a Governança cuida dos contratos e das regras de dados pessoais."""
from dsl import configurar, T, PAR, S, D, E, I, F, TODOS

NUM, NOME, SIGLA, PREF = 4, 'Relações', 'RE', 'RE'
LANES, PARTES = configurar(NOME, SIGLA, PREF)
SLUG = 'circulo4-relacoes'
FECHADO = True
STATUS = 'Fechado em 02/10/2026 · auditoria de execução aplicada em 03/10/2026'
LEAD = ('Relações constrói e cuida das relações com o mercado, os clientes, os parceiros e as instituições, antes e '
        'depois do contrato. Gera demanda e entrega a Negócios oportunidades qualificadas, desenha a experiência do '
        'cliente, acompanha o sucesso de cada cliente, forma parcerias, comunica para fora e vigia a reputação. '
        'Não vende, não atende, não define a marca e não decide a crise. São oito jornadas.')
PRINCIPIO = ('Regra do círculo, aprovada às 19:05: Relações decide o que é do seu ofício (o plano de demanda, a qualificação '
             'das oportunidades, a estratégia de experiência do cliente, a pauta e o conteúdo externo e as parcerias '
             'dentro da alçada), ouvidos o executivo da empresa e Negócios. O executivo aprova o que se diz em nome da '
             'empresa e quem fala por ela. Negócios vende e renova; Operações atende e entrega; a Identidade dá a marca e '
             'os padrões; a Governança conduz o comitê de crise, e o dono da crise decide; a Governança cuida dos contratos e das regras de dados pessoais.')
MUDOU_INTRO = ('Comparação com o catálogo da rodada 2 (49 jornadas e 216 workflows), que continua no documento do '
               'projeto até cada círculo ser fechado, e com as jornadas que o círculo 1 transferiu para Relações. '
               'Azul: acrescentado. Verde: ajustado. Vermelho: retirado.')
COBERTURA_TXT = ('Processos do APQC PCF 7.4 ligados às funções de Relações, grupo a grupo: onde cada um está neste '
                 'modelo. Os nomes estão como no referencial.')

P, A, R = 'REP', 'REA', 'RER'

# produtos de Relações usados em mais de uma jornada
PLANO_DEM = 'Plano de demanda do ciclo: públicos, ofertas, canais, ações, alvos e orçamento'
RES_DEM = 'Resultado das ações de demanda por canal e oferta'
FUNIL = 'Situação do funil: contatos, oportunidades entregues, aceitas e devolvidas'
OPORT_Q = 'Oportunidade qualificada, com o contato, a necessidade e a origem'
CRITERIO = 'Critério de oportunidade qualificada combinado com Negócios'
BASE_REL = 'Base de relacionamento atualizada, com a base legal e o histórico'
CX = 'Estratégia de experiência do cliente: personas, mapa da jornada e padrões de experiência'
PLANO_SUC = 'Plano de sucesso do cliente: resultados esperados, marcos e contatos'
INDICACAO = 'Indicação de cliente, com o consentimento do indicado'
CASO_CLI = 'Caso de cliente autorizado para comunicação'
CONTATOS_PARC = 'Contatos de parceiros e de relações institucionais'
RES_COM = 'Resultado da comunicação externa'
SINAIS_CL = 'Sinais classificados por tema de reputação, público e gravidade'
# produtos que Relações entrega a círculos já fechados (nomes que eles já esperam)
ESCUTA = 'Escuta dos públicos'
PERCEP = 'Percepção dos públicos e sinais de reputação'
SINAIS = 'Sinais de clientes, parceiros e concorrentes vistos no relacionamento'
LICOES_CLI = 'Lições de clientes perdidos, renovados e ampliados'
CONSULTA = 'Consulta sobre caso não coberto'
# produtos de outros círculos
DIRECAO = 'Direção estratégica e públicos prioritários'
ALVOS = 'Alvos e iniciativas do ciclo'
OFERTA_LANC = 'Oferta aprovada para lançamento'
DEC_ENCERRAR = 'Decisão de encerrar aposta em desenvolvimento ou oferta em uso'
DATA_SAIDA = 'Data de saída confirmada da aposta ou da oferta encerrada'
MANDATO = 'Mandato da empresa'
MUD_EST = 'Mudança na estratégia a comunicar'
OFERTA_CAT = 'Oferta no catálogo de ofertas: escopo, método, conteúdo-base, preço-base e indicadores'
OFERTA_FORA = 'Aposta ou oferta encerrada e fora do catálogo de ofertas'
POS_OFERTA = 'Posicionamento da oferta e público-alvo'
LEITURA = 'Leitura de mercado, clientes e concorrentes'
PAINEL = 'Painel de indicadores de cada círculo, com dono e análise'
DECL = 'Declaração de identidade vigente'
MUD_DECL = 'Mudança na declaração a comunicar'
PADROES_ID = 'Padrões de identidade vigentes'
RESPOSTA_ID = 'Resposta à consulta'
PROTOCOLO = 'Protocolo de crise'
REGRA_MARCA = 'Regra de uso da marca por terceiros'
MAT_VENC = 'Aviso de materiais vencidos'
PACOTE_MARCA = 'Pacote de marca publicado'
MARCA_RET = 'Marca retirada de uso'
POSIC = 'Posicionamento e casa de mensagens vigentes'
LACUNAS_EXEC = 'Lacunas de execução apontadas'
RESUMO_PAD = 'Resumo da avaliação dos padrões'
SIGILO = 'Regras de sigilo e de dados pessoais'
ALCADAS = 'Regras e alçadas vigentes'
RECLAMACOES = 'Reclamações e incidentes de clientes, com a causa'

JORNADAS = []
