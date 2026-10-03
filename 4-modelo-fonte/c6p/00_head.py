# -*- coding: utf-8 -*-
"""Círculo 6 · Integração. Fechado em 03/10/2026: oito jornadas.
Regra do círculo: a Integração decide o que é do seu ofício (o método de projetos, a arquitetura e a plataforma, a ficha
técnica da capacidade, a liberação do agente pelos casos de teste e a mudança em sistemas), ouvidos os donos. O executivo
decide a prioridade dos projetos da sua empresa; o líder do círculo dono decide o redesenho da jornada do seu círculo;
a Inteligência diz o que o agente precisa saber; a Governança define a alçada e audita."""
from dsl import configurar, T, PAR, S, D, E, I, F, TODOS

NUM, NOME, SIGLA, PREF = 6, 'Integração', 'IT', 'IT'
LANES, PARTES = configurar(NOME, SIGLA, PREF)
SLUG = 'circulo6-integracao'
FECHADO = True
STATUS = 'Fechado em 03/10/2026 · propostas dos círculos 7 e 9 aplicadas em 03/10/2026 · auditoria de execução aplicada em 03/10/2026'
LEAD = ('A Integração faz o todo funcionar como um só. É o escritório de projetos do Ecossistema: mantém a carteira de '
        'projetos, implanta os clientes, coordena o lançamento das ofertas e a saída de ofertas e empresas. Mantém o '
        'catálogo de capacidades e as jornadas ponta a ponta, monta, testa, libera e monitora agentes e automações e opera '
        'a tecnologia. Não decide o que o agente precisa saber, não roda a entrega recorrente e não define as regras. '
        'São oito jornadas.')
PRINCIPIO = ('Regra do círculo, aprovada às 09:30 de 03/10/2026: a Integração decide o que é do seu ofício (o método de projetos, a '
             'arquitetura e a plataforma, a ficha técnica de cada capacidade, a liberação do agente pelos casos de teste e '
             'a mudança em sistemas), ouvidos os donos. O executivo decide a prioridade dos projetos da sua empresa, como '
             'diz o documento-base; o líder do círculo dono decide o redesenho da jornada do seu círculo e aceita a '
             'capacidade e o agente; a Inteligência diz o que o agente precisa saber e mede se ele acertou; a Governança '
             'define a alçada, confere a segurança e audita.')
MUDOU_INTRO = ('Comparação com o catálogo da rodada 2 (49 jornadas e 216 workflows), que continua no documento do '
               'projeto até cada círculo ser fechado. Azul: acrescentado. Verde: ajustado. Vermelho: retirado.')
COBERTURA_TXT = ('Processos do APQC PCF 7.4 ligados às funções da Integração, grupo a grupo: onde cada um está neste '
                 'modelo. Os nomes estão como no referencial.')

P, A, R = 'ITP', 'ITA', 'ITR'

# produtos da Integração esperados pelos círculos fechados (nomes exatos)
SITUACAO = 'Situação das iniciativas na carteira de projetos'
LICOES = 'Lições de projetos e implantações encerrados'
REGISTROS = 'Registros de projetos, agentes e sistemas'
PLANO_IMPL = 'Plano de implantação do cliente'
PLANO_LANC = 'Plano de lançamento da oferta'
SAIDA_OFERTA = 'Plano de saída da oferta: clientes e contratos'
SAIDA_CONCL = 'Conclusão do plano de saída da oferta'
SAIDA_EMPRESA = 'Plano de saída: clientes, contratos e pessoas'
SAIDA_CLI = 'Plano de saída de clientes e contratos'
PED_METODO = 'Pedido de método para capacidade ou agente'
RES_TESTES = 'Resultado dos testes e do monitoramento dos agentes'
CONSULTAS_AG = 'Consultas dos agentes sem resposta ou com resposta sem fonte'
PED_PADRAO = 'Pedido de padrão para agente ou canal novo'
REG_ENTREGAS = 'Registros de entregas de pessoas e agentes'
CONSULTA = 'Consulta sobre caso não coberto'
LICAO_AP = 'Lição apontada'
# produtos internos usados em mais de uma jornada
PROJETO = 'Projeto para a carteira: objetivo, dono, prazo, custo e empresa'
CATALOGO = 'Catálogo de capacidades atualizado'
FICHA = 'Ficha da capacidade: método, conhecimento, executor, ferramentas, acordo de serviço e indicador'
PED_AGENTE = 'Pedido de montagem ou de mudança de agente ou automação'
PED_ACESSO = 'Pedido de acesso, de retirada de acesso ou de mudança em sistema'
# produtos de outros círculos
ALVOS = 'Alvos e iniciativas do ciclo'
METODO_EST = 'Método de estratégia vigente: critérios dos portões, regras de realocação e calendário'
DEC_PORTAO = 'Decisão do portão'
OFERTA_LANC = 'Oferta aprovada para lançamento'
DEC_ENCERRAR = 'Decisão de encerrar aposta em desenvolvimento ou oferta em uso'
DATA_SAIDA = 'Data de saída confirmada da aposta ou da oferta encerrada'
PED_SAIDA_OF = 'Pedido de plano de saída da oferta: clientes e contratos'
PEND_SAIDA_OF = 'Pendência da saída da oferta encerrada'
MANDATO = 'Mandato da empresa'
PED_SAIDA_EMP = 'Pedido de plano de saída: clientes, contratos e pessoas'
CAT_DADOS = 'Catálogo de dados, com dono e classificação de cada dado'
DADO_RET = 'Dado retirado do catálogo de dados'
BASE_PUB = 'Base de conhecimento publicada'
PERG_TESTE = 'Perguntas de teste da base, com a resposta esperada'
METODO_REC = 'Método recusado ou não publicado, com o motivo'
KIT = 'Kit do método para agentes: passos, conhecimento, casos de teste e critério de sucesso'
METODO_PUB = 'Método publicado, com versão e data de revisão'
METODO_RET = 'Método retirado de uso'
AVAL_METODO = 'Resultado da avaliação do método'
OFERTA_FORA = 'Aposta ou oferta encerrada e fora do catálogo de ofertas'
EM_CURSO_SAI = 'Ofertas, apostas e pilotos em curso da empresa que sai'
AP_DEVOLVIDA = 'Aviso de aposta devolvida, com recursos e projeto suspensos até a decisão da Estratégia'
CAPAC_OFERTA = 'Capacidades necessárias para a oferta'
OFERTA_CAT = 'Oferta no catálogo de ofertas: escopo, método, conteúdo-base, preço-base e indicadores'
RECOMENDACAO = 'Recomendação de melhoria, com evidência, ganho esperado e dono sugerido'
PAINEL = 'Painel de indicadores de cada círculo, com dono e análise'
CRIT_AUDIT = 'Critérios de auditoria e casos de teste'
PADROES_ID = 'Padrões de identidade vigentes'
RESPOSTA_ID = 'Resposta à consulta'
PACOTE_MARCA = 'Pacote de marca publicado'
MARCA_RET = 'Marca retirada de uso'
POSIC = 'Posicionamento e casa de mensagens vigentes'
LACUNAS_EXEC = 'Lacunas de execução apontadas'
PLANO_DEM = 'Plano de demanda do ciclo: públicos, ofertas, canais, ações, alvos e orçamento'
CX = 'Estratégia de experiência do cliente: personas, mapa da jornada e padrões de experiência'
CLI_SAIDA = 'Clientes avisados da saída, com a transição combinada'
PREVISAO = 'Previsão de receita e de vendas'
CONTRATO = 'Contrato de cliente assinado, com o escopo vendido'
CONTR_AFET = 'Contratos afetados pela saída'
CONTR_ENC_SAIDA = 'Contratos encerrados ou transferidos na saída'
PEND_CONTR = 'Pendência de contrato na saída'
CONTR_FIM = 'Contrato encerrado, com a data de fim'
ALCADAS = 'Regras e alçadas vigentes'
SIGILO = 'Regras de sigilo e de dados pessoais'

JORNADAS = []
