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

# ============================================================ PROJETOS
JORNADAS.append(dict(
    code='IT-01',
    nome='Gerir a carteira de projetos do Ecossistema e das empresas',
    dominio='Projetos e implantação', classe='essencial', onda=1,
    objetivo='Fazer cada projeto, interno ou de cliente, entrar numa carteira única com objetivo, dono, prazo, custo e empresa; ser priorizado contra a capacidade; ser acompanhado com o desvio apontado a tempo; e ser encerrado com a entrega conferida e as lições registradas. O executivo decide a prioridade dos projetos da sua empresa; a Integração decide a dos projetos corporativos e o método; o conflito de capacidade entre empresas sobe à Estratégia. A Integração informa a situação da carteira à Estratégia e à Gestão.',
    frequencia='Por evento: iniciativa aprovada, decisão de portão, oferta para lançamento, implantação de cliente, capacidade nova, plano de saída, aposta devolvida ou encerrada; e a cada ciclo de acompanhamento (cadência: mensal)',
    automacao=('média', 'Registrar, estimar, simular a carga, coletar a situação e apontar desvios são de agente e automação; definir objetivo e dono, priorizar os projetos corporativos e decidir a correção são de pessoa da Integração; a prioridade dos projetos de cada empresa é do executivo.'),
    base=['iso21502', 'apqc'],
    lanes=['EST', 'INT', 'EXE', P, A, R],
    inicios=[I('Iniciativa, decisão de portão ou de encerramento recebida', 'EST', 'message'),
             I('Projeto aberto por outra jornada da Integração', R, 'message'),
             I('Aposta devolvida ou encerrada avisada', 'INT', 'message'),
             I('Ciclo de acompanhamento da carteira iniciado', R, 'timer')],
    fins=[F('Projeto encerrado, com a entrega conferida e as lições registradas', R),
          F('Projeto suspenso ou encerrado antes da entrega, com recursos liberados', R),
          F('Situação da carteira informada', R),
          F('Projeto não priorizado, em espera', R),
          F('Projeto atualizado com a decisão do portão', R)],
    etapas=[
        E('Registrar o projeto e o que ele pede', 'Integração', 'Copiloto', 'baixo',
          [(ALVOS, 'Estratégia'), (METODO_EST, 'Estratégia'), (DEC_PORTAO, 'Estratégia'), (DEC_ENCERRAR, 'Estratégia'),
           (AP_DEVOLVIDA, 'Inteligência'), (PREVISAO, 'Negócios'), (PROJETO, 'IT-02'), (PROJETO, 'IT-03'), (PROJETO, 'IT-04'),
           (PROJETO, 'IT-05'), (PROJETO, 'IT-08'),
           ('Projeto suspenso ou encerrado por outra jornada', 'IT-02'), ('Projeto suspenso ou encerrado por outra jornada', 'IT-03'),
           ('Projeto suspenso ou encerrado por outra jornada', 'IT-04'),
           ('Projeto suspenso ou encerrado por outra jornada', 'IT-08'), ('Projeto reativado', 'IT-03')],
          [T('Registrar o que abriu o trabalho, a empresa e o projeto afetado', R),
           D('O que abriu o trabalho?', R,
             [S('Projeto novo ou reativado: iniciativa, implantação, lançamento, capacidade, redesenho ou saída', 'seg'),
              S('Aposta devolvida ou encerrada, oferta encerrada, ou projeto suspenso por outra jornada', 'F2',
                via=[T('Suspender ou encerrar o projeto e avisar a Gestão dos recursos liberados', R)]),
              S('Decisão do portão sobre aposta que já está na carteira, ou ciclo de acompanhamento', 'E3')]),
           T('Estimar prazo, custo, pessoas, agentes e dependências do projeto', A),
           T('Definir o objetivo, o dono e o alvo ou o contrato a que o projeto se liga', P)],
          [('Projeto registrado, com estimativa', ['etapa 2']),
           ('Recursos liberados de projeto suspenso ou encerrado', ['Gestão'])]),
        E('Priorizar o projeto na carteira', 'Integração; o executivo, nos projetos da sua empresa; o conflito entre empresas, a Estratégia', 'Copiloto', 'médio',
          [('Projeto registrado, com estimativa', 'etapa 1')],
          [T('Simular a carga da carteira com o projeto novo e apontar os conflitos de capacidade', A),
           T('Propor a ordem dos projetos pela regra de prioridade e pelos alvos', P),
           D('De quem é a prioridade?', R,
             [S('Projeto de uma empresa', 'seg', via=[T('Decidir a prioridade dos projetos da sua empresa', 'EXE')]),
              S('Projeto corporativo ou de círculo', 'seg',
                via=[T('Decidir a prioridade dos projetos corporativos, pelos alvos e pelo método de estratégia', P)])]),
           D('Há conflito de capacidade entre empresas?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Decidir o conflito de capacidade entre empresas, pelos alvos e pela alocação', 'EST', 'call')])]),
           D('O projeto entra agora?', P,
             [S('Sim', 'prox', via=[T('Fechar a carteira priorizada e avisar os donos dos projetos', P)]),
              S('Não: espera capacidade ou prioridade', 'F4',
                via=[T('Registrar o projeto em espera, com a condição para entrar, e avisar o dono', R)])])],
          [('Projeto priorizado, com início e marcos', ['etapa 3'])]),
        E('Acompanhar o projeto e corrigir o desvio', 'Integração, com o dono do projeto', 'Autopiloto', 'médio',
          [('Projeto priorizado, com início e marcos', 'etapa 2'), ('Situação, marco ou desvio informado pelo dono do projeto', 'Líderes dos círculos')],
          [D('O que chegou à etapa?', R,
             [S('Ciclo de acompanhamento da carteira', 'F3',
                via=[T('Rever os projetos em espera e devolver à priorização os que já cabem', A),
                     T('Informar a situação da carteira à Estratégia, à Gestão e aos executivos', R)]),
              S('Decisão do portão sobre aposta da carteira', 'F5', via=[T('Atualizar o projeto com a decisão do portão', R)]),
              S('Projeto priorizado', 'seg')]),
           T('Receber a situação, o marco, o desvio ou a conclusão de cada projeto', R, 'receive'),
           T('Comparar prazo, custo e entrega com o plano e apontar o desvio', A),
           D('Como está o projeto?', P,
             [S('Em andamento, sem desvio', 'E3', via=[T('Atualizar a situação da carteira', R)]),
              S('Em andamento, com desvio', 'E3',
                via=[T('Decidir a correção com o dono do projeto e avisar o executivo quando o desvio é dele', P)]),
              S('Concluído', 'prox')])],
          [(SITUACAO, ['Estratégia', 'Gestão', 'Executivos'])]),
        E('Encerrar o projeto e registrar as lições', 'Integração, com o dono do projeto', 'Assistido', 'baixo',
          [('Entrega do projeto', 'Líderes dos círculos'), ('Entrega do projeto', 'IT-02'), ('Entrega do projeto', 'IT-03'),
           ('Entrega do projeto', 'IT-04')],
          [T('Conferir a entrega com o objetivo, o prazo e o custo do projeto', P),
           T('Confirmar o aceite do dono do projeto: cliente, executivo ou líder do círculo', P),
           T('Registrar o encerramento, o resultado e as lições do projeto', R)],
          [(LICOES, ['Inteligência']),
           (REGISTROS, ['Inteligência']),
           ('Projeto encerrado, com o resultado', ['Gestão', 'Executivos']),
           ('Entrega do projeto a quem o pediu', ['IT-08'])]),
    ]))

JORNADAS.append(dict(
    code='IT-02',
    nome='Implantar o cliente, do contrato assinado à operação',
    dominio='Projetos e implantação', classe='essencial', onda=1,
    objetivo='Fazer cada contrato assinado virar um cliente implantado e aceito, com um plano combinado com o cliente e com Operações, ambiente, acessos, pessoas e materiais prontos, e passado a Operações para a entrega recorrente. A Integração coordena; Operações confirma a capacidade e assume a entrega; a Gestão compra o que falta; o cliente aceita.',
    frequencia='Por evento: contrato de cliente assinado ou com escopo novo',
    automacao=('média', 'Montar o cronograma e os riscos, configurar acessos, conferir requisitos, os padrões e acompanhar são de agente e automação; combinar o plano com o cliente, implantar e conferir o aceite são de pessoas.'),
    base=['iso21502', 'apqc'],
    lanes=['NEG', 'CLI', 'OPE', 'GES', 'IDE', P, A, R],
    inicios=[I('Contrato de cliente assinado recebido', 'NEG', 'message')],
    fins=[F('Cliente implantado, aceito e passado a Operações', R),
          F('Impasse da implantação levado ao executivo', R)],
    etapas=[
        E('Planejar a implantação com o cliente e com Operações', 'Integração, com o cliente e Operações', 'Assistido', 'médio',
          [(CONTRATO, 'Negócios'), (CX, 'Relações')],
          [T('Montar o cronograma, os riscos e a lista de requisitos a partir do escopo vendido', A),
           T('Combinar o plano de implantação com o cliente', P, 'manual'),
           PAR([T('Confirmar o plano de implantação e os responsáveis do cliente', 'CLI')],
               [T('Confirmar a capacidade de entrega e quem assume o cliente', 'OPE')]),
           D('Operações confirmou a capacidade?', P,
             [S('Sim', 'seg'),
              S('Não: rever prazo ou recursos', 'E1', via=[T('Rever o cronograma e os recursos com Operações', A)])]),
           T('Decidir o plano de implantação e abri-lo na carteira de projetos', P)],
          [(PLANO_IMPL, ['Relações', 'Operações', 'Gestão', 'etapa 2']),
           (PROJETO, ['IT-01'])]),
        E('Preparar o ambiente, os acessos, as pessoas e os materiais', 'Integração, com Operações e Gestão', 'Autopiloto', 'médio',
          [(PLANO_IMPL, 'etapa 1'), (PADROES_ID, 'Identidade'), (RESPOSTA_ID, 'Identidade'),
           ('Agente liberado para quem pediu', 'IT-06'), ('Item de tecnologia resolvido para quem pediu', 'IT-07'),
           ('Agente ou acesso não entregue, com o motivo', 'IT-06'), ('Agente ou acesso não entregue, com o motivo', 'IT-07')],
          [T('Pedir a configuração dos agentes e os acessos do cliente', R),
           T('Preparar os materiais e as comunicações da implantação', A),
           D('Os materiais estão conforme os padrões de identidade?', A,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Corrigir os materiais no que não está conforme os padrões', P)]),
              S('Há ponto que os padrões não cobrem', 'seg',
                via=[T('Responder à consulta sobre os materiais de implantação não cobertos pelos padrões', 'IDE', 'call')])]),
           D('Falta pessoa, compra ou assessoria para a implantação?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Contratar ou comprar o que falta para a implantação', 'GES')])]),
           T('Receber os agentes liberados e os acessos configurados, ou o motivo de não estarem', R, 'receive'),
           D('Os agentes e os acessos ficaram prontos?', A,
             [S('Sim', 'seg'),
              S('Não', 'F2', via=[T('Levar ao executivo o que impede a implantação e suspender o projeto na carteira', R)])]),
           T('Conferir a lista de requisitos atendida', A)],
          [('Ambiente, acessos, pessoas e materiais prontos', ['etapa 3']),
           ('Projeto suspenso ou encerrado por outra jornada', ['IT-01']),
           (PED_AGENTE, ['IT-06']),
           (PED_ACESSO, ['IT-07']),
           (CONSULTA, ['Identidade'])]),
        E('Implantar e conferir o aceite do cliente', 'Integração, com Operações e o cliente', 'Assistido', 'médio',
          [('Ambiente, acessos, pessoas e materiais prontos', 'etapa 2')],
          [T('Implantar com Operações: configurar, migrar, treinar e testar com o cliente', P, 'manual'),
           T('Conferir a implantação com o cliente', 'CLI'),
           T('Registrar o andamento e as pendências da implantação', R),
           D('O cliente aceitou a implantação?', P,
             [S('Sim', 'prox'),
              S('Não: há pendência a corrigir', 'E3', via=[T('Corrigir a pendência apontada pelo cliente', P)]),
              S('Impasse: a pendência não se resolve na implantação', 'F2',
                via=[T('Levar o impasse ao executivo, com o que falta e as opções, e suspender o projeto na carteira', R)])])],
          [('Implantação aceita pelo cliente', ['etapa 4']),
           ('Impasse da implantação, com as opções', ['Executivos']),
           ('Projeto suspenso ou encerrado por outra jornada', ['IT-01'])]),
        E('Passar o cliente a Operações e encerrar a implantação', 'Integração', 'Autômato', 'baixo',
          [('Implantação aceita pelo cliente', 'etapa 3')],
          [T('Passar o cliente a Operações com o registro do que foi implantado', R),
           T('Avisar a Gestão do início da entrega e mandar à carteira a entrega, com as lições', R)],
          [('Cliente implantado e aceito, passado à entrega', ['Operações', 'Gestão']),
           ('Entrega do projeto', ['IT-01'])]),
    ]))

JORNADAS.append(dict(
    code='IT-03',
    nome='Coordenar o lançamento da oferta aprovada',
    dominio='Projetos e implantação', classe='essencial', onda=1,
    objetivo='Fazer cada oferta aprovada no portão de lançamento chegar ao mercado com um plano único: quem faz o quê em Relações, Negócios, Operações, Gestão e Governança, com marcos e riscos, a prontidão conferida antes de lançar e os primeiros resultados acompanhados. A Integração coordena com o executivo da empresa; cada círculo executa a sua parte.',
    frequencia='Por evento: oferta aprovada para lançamento',
    automacao=('média', 'Montar o plano, coletar a prontidão e acompanhar os primeiros indicadores são de agente e automação; fechar o plano e decidir lançar são de pessoa da Integração, ouvido o executivo.'),
    base=['iso21502', 'apqc'],
    lanes=['EST', 'REL', 'NEG', 'OPE', 'GES', 'GOV', 'EXE', P, A, R],
    inicios=[I('Oferta aprovada para lançamento recebida', 'EST', 'message'),
             I('Lançamento retomado pelo executivo', 'EXE', 'message')],
    fins=[F('Oferta lançada e primeiros resultados acompanhados', R),
          F('Lançamento suspenso, com o impedimento levado ao executivo', R)],
    etapas=[
        E('Montar o plano de lançamento com o executivo e os círculos', 'Integração, ouvido o executivo', 'Assistido', 'médio',
          [(OFERTA_LANC, 'Estratégia'), (OFERTA_CAT, 'Inteligência'), (CAPAC_OFERTA, 'Inteligência'), (PLANO_DEM, 'Relações')],
          [D('O que abriu o trabalho?', R,
             [S('Oferta aprovada para lançamento', 'seg'),
              S('Lançamento retomado depois de impedimento', 'E2',
                via=[T('Reativar o projeto na carteira e propor a nova data, com o que impedia resolvido', A)])]),
           T('Propor o plano: marcos, a parte de cada círculo, capacidades, riscos e data', A),
           PAR([T('Confirmar a parte de demanda e comunicação do lançamento', 'REL')],
               [T('Confirmar a tabela, o material de venda e quem vende', 'NEG')],
               [T('Confirmar a capacidade de entrega e o atendimento', 'OPE')],
               [T('Confirmar o orçamento e a cobrança', 'GES')],
               [T('Confirmar os termos e as regras da oferta', 'GOV')]),
           T('Opinar sobre o plano e a data de lançamento da sua empresa', 'EXE'),
           T('Decidir o plano de lançamento, ouvido o executivo', P)],
          [(PLANO_LANC, ['Relações', 'Negócios', 'Operações', 'Gestão', 'Governança', 'Executivos', 'etapa 2']),
           (PROJETO, ['IT-01'])]),
        E('Conferir a prontidão e decidir lançar', 'Integração, ouvido o executivo', 'Copiloto', 'médio',
          [(PLANO_LANC, 'etapa 1'), ('Prontidão de cada círculo para o lançamento', 'Líderes dos círculos')],
          [T('Receber a prontidão de cada círculo no marco combinado', R, 'receive'),
           T('Conferir a prontidão contra o plano e apontar o que falta', A),
           T('Conferir a prontidão com o executivo da empresa', P, 'manual'),
           D('A oferta está pronta para lançar?', P,
             [S('Sim', 'prox'),
              S('Falta item com prazo de solução', 'E2', via=[T('Cobrar o item que falta do círculo dono, com o novo prazo', R)]),
              S('Falta o que impede o lançamento', 'F2',
                via=[T('Levar o impedimento ao executivo e à Gestão e suspender o projeto na carteira', R)])])],
          [('Lançamento autorizado', ['etapa 3']),
           ('Projeto reativado', ['IT-01']),
           ('Impedimento do lançamento, com as opções', ['Executivos', 'Gestão']),
           ('Projeto suspenso ou encerrado por outra jornada', ['IT-01'])]),
        E('Lançar e acompanhar os primeiros resultados', 'Integração', 'Autopiloto', 'baixo',
          [('Lançamento autorizado', 'etapa 2'), (PAINEL, 'Inteligência')],
          [T('Avisar os círculos e o executivo do lançamento na data', R),
           T('Acompanhar os primeiros indicadores e apontar os problemas de entrega, venda ou demanda', A),
           T('Mandar à carteira a entrega do lançamento, com as lições', R)],
          [('Oferta lançada', ['Operações', 'Gestão', 'Executivos']),
           ('Entrega do projeto', ['IT-01'])]),
    ]))

JORNADAS.append(dict(
    code='IT-04',
    nome='Montar e coordenar o plano de saída de oferta ou de empresa',
    dominio='Projetos e implantação', classe='essencial', onda=1,
    objetivo='Fazer cada oferta encerrada ou empresa que sai do portfólio ter um plano de saída de clientes, contratos, pessoas, sistemas e dados, montado com os círculos que executam e entregue à Estratégia, que decide a data; e, com a data confirmada, coordenar a execução até a conclusão, apontando as pendências. No mandato de criação ou de aquisição, a Integração abre na carteira o projeto de ligar a empresa aos círculos. Cada círculo executa a sua parte; a Integração coordena.',
    frequencia='Por evento: pedido de plano de saída, mandato de empresa, data de saída confirmada ou pendência apontada',
    automacao=('média', 'Levantar o que é afetado e acompanhar são de agente e automação; montar o plano com os círculos, fechar o plano e coordenar a execução são de pessoa da Integração.'),
    base=['iso21502', 'apqc'],
    lanes=['EST', 'REL', 'NEG', 'OPE', 'GES', 'GOV', 'EXE', P, A, R],
    inicios=[I('Pedido de plano de saída recebido', 'EST', 'message'),
             I('Mandato da empresa recebido', 'EST', 'message'),
             I('Pendência da saída apontada pela Estratégia', 'EST', 'message'),
             I('Data de saída confirmada recebida', 'EST', 'message')],
    fins=[F('Saída concluída e informada à Estratégia', R),
          F('Projeto de ligação da empresa aberto na carteira', R),
          F('Pendência da saída apontada à Estratégia e ao executivo', R),
          F('Mandato registrado sob sigilo', R),
          F('Plano de saída entregue à Estratégia, à espera da data', R),
          F('Pendência apontada pela Estratégia tratada com o círculo dono', R)],
    etapas=[
        E('Montar o plano de saída com os círculos', 'Integração, com Relações, Negócios, Operações, Gestão e Governança', 'Copiloto', 'alto',
          [(PED_SAIDA_OF, 'Estratégia'), (PED_SAIDA_EMP, 'Estratégia'), (MANDATO, 'Estratégia'), (DEC_ENCERRAR, 'Estratégia'),
           (OFERTA_FORA, 'Inteligência'), (EM_CURSO_SAI, 'Inteligência'), (CONTR_AFET, 'Negócios')],
          [T('Registrar o pedido ou o mandato e o que ele alcança', R),
           D('O que abriu o trabalho?', R,
             [S('Pedido de plano de saída de oferta ou de empresa', 'seg'),
              S('Data de saída confirmada da oferta', 'E2',
                via=[T('Retomar o plano de saída já entregue, com a data confirmada', R)]),
              S('Mandato de venda ou de encerramento de empresa, com o plano conferido', 'E2',
                via=[T('Retomar o plano de saída conferido e incluído no mandato', R)]),
              S('Pendência da saída apontada pela Estratégia depois da conclusão', 'F6',
                via=[T('Coordenar com o círculo dono a pendência apontada', P, 'manual'),
                     T('Apontar ao executivo o resultado da pendência', R)]),
              S('Mandato de criação ou de aquisição de empresa', 'F2',
                via=[T('Abrir na carteira o projeto de ligar a empresa aos círculos e aos acordos de serviço', R),
                     T('Pedir os acessos e os acordos de serviço da empresa a ligar', R)]),
              S('Mandato de busca de comprador ou de mudança de mandato', 'F4',
                via=[T('Registrar o mandato sob sigilo e abrir na carteira o que ele pede', R)])]),
           T('Levantar clientes, contratos, pessoas, sistemas, dados e projetos afetados', A),
           PAR([T('Propor a transição dos clientes', 'REL')],
               [T('Propor o encerramento ou a transferência dos contratos de clientes', 'NEG')],
               [T('Propor o fim das entregas em curso', 'OPE')],
               [T('Propor o destino das pessoas, dos custos e dos contratos de fornecedores', 'GES')],
               [T('Conferir as obrigações legais e contratuais da saída', 'GOV')]),
           T('Opinar sobre o plano de saída da sua empresa', 'EXE'),
           T('Fechar o plano de saída com prazos, responsáveis e riscos', P),
           D('O plano está fechado?', P,
             [S('Sim', 'F5', via=[T('Entregar o plano à Estratégia e registrar que a saída espera a data ou o mandato', R)]),
              S('Não, falta a parte de um círculo', 'F5',
                via=[T('Completar o plano com o círculo que falta', P, 'manual'),
                     T('Entregar o plano completo à Estratégia e registrar a espera', R)])])],
          [(SAIDA_OFERTA, ['Estratégia']),
           (SAIDA_EMPRESA, ['Estratégia']),
           (PED_ACESSO, ['IT-07']),
           ('Pedido de serviço da empresa a ligar', ['IT-05']),
           (SAIDA_CLI, ['Relações', 'Negócios', 'Operações', 'Gestão', 'Governança']),
           (PROJETO, ['IT-01']),
           ('Plano de saída fechado', ['etapa 2'])]),
        E('Coordenar a execução da saída na data confirmada', 'Integração, com os círculos que executam', 'Copiloto', 'alto',
          [('Plano de saída fechado', 'etapa 1'), (DATA_SAIDA, 'Estratégia'), (MANDATO, 'Estratégia'), (PEND_SAIDA_OF, 'Estratégia'),
           (CLI_SAIDA, 'Relações'), (CONTR_ENC_SAIDA, 'Negócios'), (PEND_CONTR, 'Negócios'),
           ('Entregas encerradas na saída', 'Operações')],
          [T('Registrar a data de saída ou a data do mandato e o plano que vale', R),
           T('Avisar cada círculo da data e dos marcos da sua parte', R),
           T('Coordenar a execução entre os círculos e tratar os bloqueios', P, 'manual'),
           T('Pedir a retirada dos acessos e o destino dos dados e dos sistemas da saída', R),
           T('Receber de cada círculo a conclusão da sua parte', R, 'receive'),
           D('A saída foi concluída como planejado?', P,
             [S('Sim', 'prox'),
              S('Há pendência que o círculo dono resolve no prazo', 'E2',
                via=[T('Cobrar a pendência do círculo dono, com o novo prazo', R)]),
              S('Há pendência que não se resolve no plano', 'F3',
                via=[T('Informar à Estratégia a conclusão com a pendência, suspender o projeto e apontá-la ao executivo', R)])])],
          [(PED_ACESSO, ['IT-07']),
           (SAIDA_CONCL, ['Estratégia']),
           ('Projeto suspenso ou encerrado por outra jornada', ['IT-01']),
           ('Pendência da saída, com o efeito', ['Executivos']),
           ('Saída executada', ['etapa 3'])]),
        E('Concluir a saída e informar a Estratégia', 'Integração', 'Autômato', 'baixo',
          [('Saída executada', 'etapa 2')],
          [T('Registrar a conclusão da saída e informar a Estratégia', R),
           T('Mandar à carteira a entrega da saída, com as lições', R)],
          [(SAIDA_CONCL, ['Estratégia']),
           ('Entrega do projeto', ['IT-01'])]),
    ]))

# ================================================= CAPACIDADES E AGENTES
JORNADAS.append(dict(
    code='IT-05',
    nome='Atender pedidos de capacidade e de serviço e manter o catálogo de capacidades',
    dominio='Capacidades e agentes', classe='essencial', onda=1,
    objetivo='Fazer cada pedido de serviço de uma empresa a um círculo chegar ao círculo dono da capacidade com um acordo de serviço, e cada necessidade de capacidade nova ou mudada virar uma ficha com método, conhecimento, executor (pessoa, agente, automação ou assessoria), ferramentas, acordo de serviço, indicador e alçada, aceita pelo líder do círculo dono e publicada no catálogo, ligada às jornadas e às tarefas. A Inteligência dá o método e o conhecimento; a Governança define a alçada; o líder do círculo dono aceita a capacidade.',
    frequencia='Por evento: pedido de serviço, necessidade de capacidade, capacidades pedidas por oferta, método publicado, retirado ou recusado; e na revisão do catálogo (cadência: trimestral)',
    automacao=('alta', 'Registrar, identificar a capacidade, encaminhar, propor a ficha e versionar o catálogo são de agente e automação; decidir a ficha e o executor é de pessoa da Integração; aceitar a capacidade é do líder do círculo dono; a alçada é da Governança.'),
    base=['apqc'],
    lanes=['SOL', 'EXE', 'INT', 'GOV', 'LCI', P, A, R],
    inicios=[I('Pedido de serviço de empresa recebido', 'EXE', 'message'),
             I('Necessidade de capacidade nova ou mudada recebida', 'SOL', 'message'),
             I('Capacidades pedidas por oferta recebidas', 'INT', 'message'),
             I('Método publicado, retirado ou recusado avisado', 'INT', 'message'),
             I('Revisão do catálogo de capacidades iniciada', R, 'timer')],
    fins=[F('Capacidade publicada no catálogo', R),
          F('Pedido de serviço encaminhado ao círculo dono, com acordo de serviço', R),
          F('Capacidade retirada do catálogo', R),
          F('Capacidade sem método, à espera da Inteligência', R),
          F('Necessidade sem método publicado, devolvida a quem pediu', R),
          F('Capacidade não aceita pelo líder do círculo dono, com o motivo', R)],
    etapas=[
        E('Receber o pedido e achar a capacidade', 'Integração', 'Autopiloto', 'baixo',
          [('Pedido de serviço de empresa', 'Executivos'), ('Pedido de serviço da empresa a ligar', 'IT-04'),
           ('Necessidade de capacidade nova ou mudada', 'Solicitante'),
           (CAPAC_OFERTA, 'Inteligência'), (METODO_PUB, 'Inteligência'), (METODO_RET, 'Inteligência'), (METODO_REC, 'Inteligência'),
           (AVAL_METODO, 'Inteligência'), ('Redesenho que pede capacidade nova ou mudada', 'IT-08')],
          [T('Registrar o pedido, quem pede e a capacidade procurada no catálogo', R),
           D('O que abriu o trabalho?', A,
             [S('Pedido de serviço de capacidade que já existe', 'F2',
                via=[T('Combinar o acordo de serviço com quem pediu', 'LCI'),
                     T('Encaminhar o pedido ao círculo dono e registrar o acordo de serviço', R)]),
              S('Capacidade nova, ou que falha, ou que pode mudar de modo', 'seg'),
              S('Método publicado que muda a capacidade, ou avaliação do método', 'seg'),
              S('Método recusado ou não publicado pela Inteligência', 'F5',
                via=[T('Avisar quem pediu a capacidade que o método não foi publicado, com o motivo', R)]),
              S('Método retirado, ou capacidade sem uso na revisão', 'E3',
                via=[T('Marcar a capacidade a retirar e as jornadas e os agentes que a usam', R)])]),
           T('Estimar o ganho esperado e a prioridade da necessidade', A)],
          [('Necessidade de capacidade priorizada', ['etapa 2']),
           ('Pedido de serviço encaminhado, com acordo de serviço', ['Executivos', 'Líderes dos círculos']),
           ('Capacidade não criada, com o motivo', ['IT-08'])]),
        E('Desenhar a ficha da capacidade com o dono e a Inteligência', 'Integração, com o círculo dono, a Inteligência e a Governança', 'Assistido', 'médio',
          [('Necessidade de capacidade priorizada', 'etapa 1'), (KIT, 'Inteligência'), (BASE_PUB, 'Inteligência'),
           (PADROES_ID, 'Identidade'), (ALCADAS, 'Governança')],
          [D('Há método publicado para a capacidade?', A,
             [S('Sim', 'seg'),
              S('Não', 'F4', via=[T('Pedir à Inteligência o método para a capacidade, com a necessidade e o ganho', R)])]),
           T('Propor a ficha: método, conhecimento, executor, ferramentas, acordo de serviço e indicador', A),
           T('Decidir o executor da capacidade: pessoa, agente, automação ou assessoria', P),
           T('Definir a alçada do executor da capacidade', 'GOV'),
           T('Aceitar a ficha e assumir a capacidade no seu círculo', 'LCI'),
           D('O líder do círculo dono aceitou a ficha?', P,
             [S('Sim', 'prox'),
              S('Não, ajustar a ficha', 'E2'),
              S('Não: o dono não assume a capacidade', 'F6',
                via=[T('Registrar o motivo e avisar quem pediu a capacidade', R)])])],
          [(FICHA, ['etapa 3', 'IT-06']),
           (PED_METODO, ['Inteligência']),
           ('Capacidade não criada, com o motivo', ['IT-08'])]),
        E('Publicar ou retirar a capacidade no catálogo e pedir a construção', 'Integração', 'Autômato', 'baixo',
          [(FICHA, 'etapa 2')],
          [D('O que a capacidade pede?', R,
             [S('Agente ou automação', 'seg',
                via=[T('Pedir a montagem ou a mudança do agente ou da automação', R)]),
              S('Pessoa ou assessoria', 'seg', via=[T('Abrir na carteira o projeto de preparar pessoas ou contratar a assessoria', R)]),
              S('Retirada da capacidade', 'F3',
                via=[T('Retirar a capacidade do catálogo, pedir a retirada dos agentes e avisar os donos afetados', R)])]),
           T('Versionar a ficha e ligar a capacidade às jornadas, às tarefas e aos donos', R),
           T('Publicar a capacidade no catálogo, em construção até o agente ou a pessoa estarem prontos', R)],
          [(PED_AGENTE, ['IT-06']),
           (PROJETO, ['IT-01']),
           (CATALOGO, [TODOS]),
           (REGISTROS, ['Inteligência'])]),
    ]))

JORNADAS.append(dict(
    code='IT-06',
    nome='Cuidar dos agentes e automações: montar, testar, liberar, monitorar e corrigir',
    dominio='Capacidades e agentes', classe='essencial', onda=1,
    objetivo='Fazer cada agente ou automação ser montado pela ficha da capacidade, com o método, o conhecimento, os padrões de identidade e a alçada; passar nos casos de teste da Inteligência e da Identidade antes de entrar em uso; ser aceito pelo líder do círculo dono; e ser monitorado em uso, com o desvio corrigido, suspenso quando sai da alçada e retirado quando o método, a base ou a marca saem de uso. A Inteligência diz o que o agente precisa saber e mede se ele acertou; a Integração monta, testa, libera e mantém; a Governança define a alçada e audita.',
    frequencia='Por evento: pedido de montagem ou de mudança, método, base, padrão ou marca alterados, falha ou desvio detectado; e a cada ciclo de monitoramento (cadência: mensal)',
    automacao=('alta', 'Montar, rodar os casos de teste, medir o acerto e monitorar são de agente e automação; decidir a arquitetura, julgar os casos de fronteira, liberar e decidir a correção são de pessoa da Integração; aceitar o agente é do líder do círculo dono; a alçada é da Governança.'),
    base=['anthropic_evals', 'nist_airmf', 'apqc'],
    lanes=['INT', 'IDE', 'GOV', 'LCI', P, A, R],
    inicios=[I('Pedido de montagem, de mudança ou de retirada de agente recebido', R, 'message'),
             I('Base de conhecimento ou perguntas de teste alteradas', 'INT', 'message'),
             I('Padrão, posicionamento ou marca alterados', 'IDE', 'message'),
             I('Falha ou desvio de agente detectado', R, 'signal'),
             I('Ciclo de monitoramento dos agentes iniciado', R, 'timer')],
    fins=[F('Agente em uso, monitorado', R),
          F('Agente retirado de uso', R),
          F('Agente suspenso, com a Governança e o dono avisados', R),
          F('Falha devolvida à Inteligência: método ou base', R)],
    etapas=[
        E('Montar ou mudar o agente pela ficha', 'Integração', 'Copiloto', 'médio',
          [(PED_AGENTE, 'IT-05'), (PED_AGENTE, 'IT-02'), (FICHA, 'IT-05'), (KIT, 'Inteligência'), (BASE_PUB, 'Inteligência'),
           (PERG_TESTE, 'Inteligência'), (CRIT_AUDIT, 'Identidade'), (PADROES_ID, 'Identidade'), (POSIC, 'Identidade'),
           (PACOTE_MARCA, 'Identidade'), (MARCA_RET, 'Identidade'), (ALCADAS, 'Governança'), ('Desvio a corrigir no agente', 'etapa 4')],
          [T('Registrar o que abriu o trabalho e os agentes afetados', R),
           D('O que abriu o trabalho?', R,
             [S('Agente novo, mudança pedida, conteúdo alterado ou desvio a corrigir', 'seg'),
              S('Retirada pedida pelo catálogo, ou marca retirada de uso', 'F2',
                via=[T('Retirar o agente ou o conteúdo de uso e avisar o dono da capacidade', R)]),
              S('Ciclo de monitoramento', 'E4')]),
           D('Há padrão de identidade para o canal ou o tipo de agente?', A,
             [S('Sim', 'seg'),
              S('Não', 'seg', via=[T('Pedir à Identidade o padrão para o agente ou o canal novo', R),
                                   T('Receber os padrões e os casos de teste da Identidade', R, 'receive')])]),
           T('Decidir a arquitetura do agente: modelo, ferramentas, conhecimento e integrações', P),
           T('Montar as instruções, o conhecimento, as ferramentas, a voz e a alçada do agente', A)],
          [('Agente montado', ['etapa 2']),
           (PED_PADRAO, ['Identidade'])]),
        E('Testar o agente com os casos de teste', 'Integração, com a Inteligência', 'Copiloto', 'médio',
          [('Agente montado', 'etapa 1')],
          [T('Rodar os casos de teste do método, da base e da Identidade', R),
           T('Medir o acerto do conteúdo e julgar os casos de fronteira de conteúdo', 'INT'),
           T('Medir erro, tempo e custo e julgar os casos de fronteira de operação', P),
           D('O agente atinge o critério de sucesso?', P,
             [S('Sim', 'prox'),
              S('Não: falha do agente', 'E1', via=[T('Apontar a falha do agente e o que corrigir', A)]),
              S('Não: o método ou a base é que falha', 'F4',
                via=[T('Devolver à Inteligência o resultado dos testes, com os casos que falham', R)])])],
          [('Agente aprovado nos testes', ['etapa 3']),
           ('Agente ou acesso não entregue, com o motivo', ['IT-02']),
           (RES_TESTES, ['Inteligência'])]),
        E('Liberar o agente em uso', 'Integração; aceita o líder do círculo dono; a Governança confere a alçada', 'Assistido', 'alto',
          [('Agente aprovado nos testes', 'etapa 2')],
          [T('Conferir a alçada e os acessos do agente', 'GOV'),
           T('Aceitar o agente na capacidade do seu círculo', 'LCI'),
           D('A Governança e o líder do círculo dono aceitaram o agente?', P,
             [S('Sim', 'seg'),
              S('Não, ajustar', 'E1')]),
           T('Liberar o agente em uso', P),
           T('Registrar a versão liberada, a alçada e o dono e marcar a capacidade como em uso', R)],
          [('Agente em uso', ['etapa 4']),
           ('Agente liberado para quem pediu', ['IT-02']),
           (REGISTROS, ['Inteligência'])]),
        E('Monitorar o agente em uso e tratar o desvio', 'Integração', 'Autômato', 'médio',
          [('Agente em uso', 'etapa 3'), ('Desvio de agente apontado pela auditoria', 'Governança')],
          [T('Monitorar erro, disponibilidade, custo e consultas e mandar a amostra à Inteligência', R),
           T('Registrar as entregas dos agentes para a auditoria e para a Identidade', R),
           D('Há desvio no agente?', A,
             [S('Não', 'prox'),
              S('Sim, corrigível na montagem', 'E1', via=[T('Abrir a correção do agente', R)]),
              S('Sim: risco ou decisão fora da alçada', 'F3',
                via=[T('Suspender o agente, avisar a Governança e o dono e registrar a correção pendente', R)])])],
          [(RES_TESTES, ['Inteligência']),
           (CONSULTAS_AG, ['Inteligência']),
           (REG_ENTREGAS, ['Identidade', 'Governança']),
           ('Desvio a corrigir no agente', ['etapa 1']),
           ('Agente suspenso, com o motivo', ['Governança', 'Líderes dos círculos']),
           ('Agente ou acesso não entregue, com o motivo', ['IT-02'])]),
    ]))

# ========================================================== TECNOLOGIA
JORNADAS.append(dict(
    code='IT-07',
    nome='Operar a tecnologia: pedidos, incidentes, acessos, mudanças e fornecedores',
    dominio='Tecnologia e jornadas', classe='essencial', onda=1,
    objetivo='Fazer cada pedido, incidente ou risco de tecnologia ser resolvido no prazo; cada acesso a dados e sistemas ser dado e retirado pela classificação do dado e pelo pedido; cada mudança em sistema ser testada, aprovada e reversível; cada incidente de segurança ou de dados pessoais ser tratado com a Governança; e cada fornecedor e licença de tecnologia ser escolhido, contratado e controlado com a Gestão e a Governança. A Integração opera e protege; a Governança define a política e verifica; a Gestão compra e paga.',
    frequencia='Por evento: pedido, incidente ou risco de tecnologia, contrato de cliente encerrado, pedido de acesso ou de retirada vindo de outra jornada, pedido de fornecedor ou licença, renovação próxima',
    automacao=('média', 'Receber, classificar, resolver o que é conhecido, conceder e retirar acessos pela regra, testar e implantar mudanças padrão e registrar são de agente e automação; resolver o caso novo, aprovar mudança e escolher fornecedor são de pessoa da Integração.'),
    base=['iso27001', 'apqc'],
    lanes=['SOL', 'INT', 'NEG', 'GOV', 'GES', P, A, R],
    inicios=[I('Pedido, incidente ou risco de tecnologia recebido', 'SOL', 'message'),
             I('Contrato de cliente encerrado', 'NEG', 'message'),
             I('Renovação de licença ou de contrato de tecnologia próxima', R, 'timer'),
             I('Pedido de acesso ou de mudança vindo de outra jornada', R, 'message')],
    fins=[F('Item de tecnologia resolvido ou contratado e registrado', R),
          F('Mudança desfeita, com o motivo', R)],
    etapas=[
        E('Receber e classificar o pedido, o incidente ou o risco', 'Integração', 'Autopiloto', 'baixo',
          [('Pedido, incidente ou risco de tecnologia', 'Solicitante'), (CAT_DADOS, 'Inteligência'), (DADO_RET, 'Inteligência'),
           (CONTR_FIM, 'Negócios'), (PED_ACESSO, 'IT-02'), (PED_ACESSO, 'IT-04'), (PED_ACESSO, 'IT-08'), (SIGILO, 'Governança')],
          [T('Registrar o item, quem pede, o sistema e o dado afetados', R),
           T('Classificar o tipo, a urgência, o risco e o prazo', A),
           D('É incidente de segurança ou de dados pessoais?', A,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Tratar o incidente de segurança ou de dados pessoais com a Governança', 'GOV', 'call')])]),
           D('O que o item pede?', R,
             [S('Acesso, retirada de acesso, solução conhecida ou mudança', 'prox'),
              S('Fornecedor, licença ou serviço de tecnologia novo, ou renovação', 'E3')])],
          [('Item classificado e priorizado', ['etapa 2', 'etapa 3'])]),
        E('Resolver o item e implantar a mudança', 'Integração; a mudança de risco, com a Governança', 'Copiloto', 'médio',
          [('Item classificado e priorizado', 'etapa 1')],
          [D('O item pede mudança em sistema?', R,
             [S('Não: acesso ou solução conhecida', 'seg',
                via=[T('Conceder ou retirar o acesso pela classificação do dado, ou aplicar a solução conhecida', R)]),
              S('Sim', 'seg', via=[T('Preparar e testar a mudança, com o caminho de volta', A),
                                   T('Aprovar a mudança e a janela de implantação', P)])]),
           D('A mudança mexe em dado pessoal, acesso privilegiado ou segurança?', P,
             [S('Não, ou não há mudança', 'seg'),
              S('Sim', 'seg', via=[T('Conferir a mudança contra a política de segurança e de dados pessoais', 'GOV')])]),
           T('Resolver o caso novo que o agente não resolve', P),
           T('Implantar a mudança ou fechar o item e avisar quem pediu', R),
           D('O item foi resolvido?', P,
             [S('Sim', 'E4'),
              S('Não: a mudança falhou', 'F2', via=[T('Desfazer a mudança, voltar ao estado anterior e registrar o motivo', R)])])],
          [('Item resolvido', ['etapa 4']),
           ('Agente ou acesso não entregue, com o motivo', ['IT-02'])]),
        E('Escolher e contratar fornecedor ou licença de tecnologia', 'Integração, com a Gestão e a Governança', 'Copiloto', 'médio',
          [('Item classificado e priorizado', 'etapa 1')],
          [T('Comparar fornecedores e licenças, ou o uso da que vence: requisito, segurança, custo e saída', A),
           T('Escolher o fornecedor ou a licença, ou decidir renovar', P),
           T('Revisar o contrato de tecnologia, licença ou dados e a segurança', 'GOV'),
           T('Conferir o custo e o orçamento', 'GES'),
           D('A contratação foi aprovada?', P,
             [S('Sim', 'seg'),
              S('Não', 'E3', via=[T('Rever a escolha com o motivo da recusa', A)])]),
           T('Fazer a compra ou a renovação', 'GES'),
           T('Registrar o fornecedor, a licença, o custo e a data de renovação', R)],
          [('Fornecedor ou licença contratado', ['etapa 4']),
           ('Contrato de tecnologia para guardar', ['Governança'])]),
        E('Registrar e medir o serviço de tecnologia', 'Integração', 'Autômato', 'baixo',
          [('Item resolvido', 'etapa 2'), ('Fornecedor ou licença contratado', 'etapa 3')],
          [T('Registrar o item, o tempo, a causa e o custo', R),
           T('Medir disponibilidade, erros, custo e prazo dos serviços de tecnologia', R)],
          [(REGISTROS, ['Inteligência']),
           ('Item de tecnologia resolvido para quem pediu', ['IT-02']),
           ('Custo de tecnologia por empresa e por círculo', ['Gestão'])]),
    ]))

# ===================================================== JORNADAS PONTA A PONTA
JORNADAS.append(dict(
    code='IT-08',
    nome='Medir e redesenhar as jornadas ponta a ponta e manter o catálogo de jornadas',
    dominio='Tecnologia e jornadas', classe='essencial', onda=2,
    objetivo='Fazer cada jornada ponta a ponta ser medida, ter o gargalo achado com evidência, ser redesenhada com o círculo dono e com os círculos por onde passa, ter o redesenho decidido pelo líder do círculo dono e conferido pela Governança quando mexe em alçada, regra ou contrato, ser implantada e ter o ganho conferido; e manter o catálogo de jornadas, etapas e tarefas íntegro e versionado. A Integração mede, propõe e implanta; o líder do círculo dono decide.',
    frequencia='A cada ciclo de melhoria (cadência: trimestral) e por evento: recomendação de melhoria, lacuna de execução ou mudança aprovada em outra jornada',
    automacao=('alta', 'Medir, achar o gargalo, versionar o catálogo e conferir o ganho são de agente e automação; propor o redesenho é de pessoa da Integração; decidir é do líder do círculo dono.'),
    base=['apqc'],
    lanes=['INT', 'IDE', 'GOV', 'LCI', P, A, R],
    inicios=[I('Ciclo de melhoria das jornadas iniciado', R, 'timer'),
             I('Capacidade do redesenho não criada', R, 'message'),
             I('Recomendação de melhoria recebida', 'INT', 'message'),
             I('Lacunas de execução apontadas recebidas', 'IDE', 'message'),
             I('Projeto do redesenho entregue', R, 'message')],
    fins=[F('Jornada redesenhada, implantada e com o ganho conferido', R),
          F('Redesenho não aprovado, com o motivo', R),
          F('Jornada sem gargalo que justifique mudança', R),
          F('Redesenho à espera do projeto', R),
          F('Redesenho sem a capacidade pedida, com o motivo', R)],
    etapas=[
        E('Medir a jornada e achar o gargalo', 'Integração, com a Inteligência', 'Copiloto', 'baixo',
          [(PAINEL, 'Inteligência'), (RECOMENDACAO, 'Inteligência'), (LACUNAS_EXEC, 'Identidade'), (CX, 'Relações'),
           ('Entrega do projeto a quem o pediu', 'IT-01'), ('Capacidade não criada, com o motivo', 'IT-05')],
          [D('O que abriu o trabalho?', R,
             [S('Ciclo, recomendação ou lacuna', 'seg'),
              S('Entrega do projeto de um redesenho aprovado', 'E3', via=[T('Retomar o redesenho com a entrega do projeto', R)]),
              S('Capacidade pedida pelo redesenho não foi criada', 'F5',
                via=[T('Suspender o projeto do redesenho e avisar o líder do círculo dono, com o motivo', R)])]),
           T('Propor as jornadas do ciclo pela recomendação, pela lacuna e pelos indicadores', A),
           T('Decidir as jornadas do ciclo', P),
           T('Medir volume, custo, qualidade, tempo e resultado da jornada', R),
           T('Analisar tempos, filas e retrabalho e apontar o gargalo, com a causa provável', A),
           D('Há gargalo que justifica mudar a jornada?', A,
             [S('Sim', 'prox'),
              S('Não', 'F3', via=[T('Registrar a medida da jornada e responder a quem recomendou', R)])])],
          [('Gargalo da jornada, com evidência', ['etapa 2']),
           ('Projeto suspenso ou encerrado por outra jornada', ['IT-01'])]),
        E('Redesenhar a jornada com o círculo dono', 'Integração; decide o líder do círculo dono', 'Assistido', 'médio',
          [('Gargalo da jornada, com evidência', 'etapa 1'), (ALCADAS, 'Governança')],
          [T('Propor o redesenho: etapas, tarefas, executores, entradas e saídas e o ganho esperado', P),
           T('Montar o fluxo do redesenho e conferir as trocas com os outros círculos', A),
           D('O redesenho mexe em alçada, regra ou contrato?', P,
             [S('Não', 'seg'),
              S('Sim', 'seg', via=[T('Conferir o redesenho contra as alçadas, as regras e os contratos', 'GOV')])]),
           T('Confirmar a parte do redesenho que passa por cada círculo afetado', 'LCI'),
           T('Decidir o redesenho da jornada do seu círculo', 'LCI'),
           D('O líder do círculo dono aprovou o redesenho?', P,
             [S('Sim', 'prox'),
              S('Não, ajustar', 'E2'),
              S('Não: fica como está', 'F2', via=[T('Registrar o motivo e responder a quem recomendou', R)])])],
          [('Redesenho aprovado', ['etapa 3'])]),
        E('Implantar o redesenho e atualizar o catálogo de jornadas', 'Integração', 'Autômato', 'baixo',
          [('Redesenho aprovado', 'etapa 2')],
          [D('O redesenho pede capacidade, agente, sistema ou projeto ainda não entregue?', R,
             [S('Não, ou o projeto já foi entregue', 'seg'),
              S('Sim', 'F4', via=[T('Abrir o projeto do redesenho e pedir a capacidade, o agente ou a mudança em sistema', R)])]),
           T('Versionar a jornada no catálogo e refazer as ligações com etapas, tarefas e donos', R),
           T('Avisar os círculos por onde a jornada passa', R)],
          [(PROJETO, ['IT-01']),
           ('Redesenho que pede capacidade nova ou mudada', ['IT-05']),
           (PED_ACESSO, ['IT-07']),
           ('Catálogo de jornadas atualizado', [TODOS]),
           ('Jornada implantada', ['etapa 4'])]),
        E('Conferir o ganho do redesenho', 'Integração, com a Inteligência', 'Copiloto', 'baixo',
          [('Jornada implantada', 'etapa 3'), (PAINEL, 'Inteligência')],
          [T('Medir a jornada depois do redesenho e comparar com o ganho esperado', A),
           T('Concluir se o ganho veio e o que aprender', P),
           D('O ganho esperado veio?', P,
             [S('Sim', 'prox', via=[T('Registrar o ganho conferido', R)]),
              S('Não', 'prox', via=[T('Registrar a lição e levar à Inteligência', R)])])],
          [(LICAO_AP, ['Inteligência'])]),
    ]))

# -------------------------------------------------------------- domínios
DOMINIOS = [
    ('Projetos e implantação', 'Carteira de projetos, implantação de clientes, lançamento de ofertas e saída de ofertas e empresas: a Integração como escritório de projetos.'),
    ('Capacidades e agentes', 'Catálogo de capacidades, pedidos de serviço entre empresas e círculos, e agentes e automações do desenho ao uso.'),
    ('Tecnologia e jornadas', 'Operação da tecnologia e melhoria das jornadas ponta a ponta.'),
]

ONDAS = {
    1: 'O que os círculos fechados já esperam da Integração: projetos, implantação, lançamento, saída, capacidades, agentes e tecnologia',
    2: 'O que melhora o todo com o tempo: medir e redesenhar as jornadas ponta a ponta',
}

# ------------------------------------------------- o que usamos de cada fonte
USO = {
    'apqc': 'PCF 7.4. Os processos da Integração estão em duas categorias: 8.0, tecnologia da informação (arquitetura, portfólio de TI, segurança, identidade e acesso, criação e teste de soluções, implantação, controle de mudança e suporte), base da IT-06 e da IT-07; e 13.0, capacidades do negócio (processos, portfólio e projetos, mudança), base da IT-01 a IT-05 e da IT-08. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.',
    'iso21502': 'Norma de orientação para gestão de projetos, aplicável a qualquer organização e a qualquer tipo de projeto; não trata de programas nem de portfólios. Lemos só o resumo; a norma está publicada e marcada para revisão. Referência do ciclo de projeto (registrar, planejar, acompanhar e encerrar com lições) na IT-01, na IT-02, na IT-03 e na IT-04; o portfólio vem do APQC (13.2.1).',
    'iso27001': 'Norma de requisitos para o sistema de gestão da segurança da informação. Lemos só o resumo. Referência da operação segura da IT-07: acesso pela classificação, mudança testada e reversível e incidente de segurança tratado com a Governança, que define a política.',
    'anthropic_evals': 'Critério de sucesso específico e mensurável; avaliações que espelham a tarefa real e são automatizadas quando possível; correção por código, por pessoa e por modelo. Base dos casos de teste, do julgamento dos casos de fronteira e do critério de liberação na IT-06.',
    'nist_airmf': 'O núcleo tem quatro funções: governar, mapear, medir e gerir. Base do monitoramento em uso e da suspensão do agente que sai da alçada na IT-06. O framework trata de risco de IA; usá-lo para a operação do agente é leitura nossa.',
    'bpmn': 'Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, manual, serviço, script e recebimento, além da atividade de chamada.',
    'camunda': 'Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.',
    'sipoc': 'Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.',
}

# ----------------------------------- cobertura do referencial (APQC PCF 7.4)
COBERTURA = [
    ('8.1', 'Develop and manage IT customer relationships', 'IT-05 (pedido de serviço e acordo de serviço) e IT-07 (pedidos de tecnologia)'),
    ('8.2.3', 'Define and maintain enterprise architecture', 'Em parte: a arquitetura de cada agente (IT-06, etapa 1) e a mudança em sistema (IT-07, etapa 2). A arquitetura da plataforma como um todo não tem jornada própria: fica como limite'),
    ('8.2.6', 'Manage IT value portfolio', 'IT-01: os projetos de tecnologia entram na carteira única'),
    ('8.3.3', 'Control IT risk, compliance, and security', 'IT-07, com a Governança, que define a política e verifica'),
    ('8.3.4', 'Plan and manage IT continuity', 'Não desenhado como etapa própria: fica como limite'),
    ('8.3.5', 'Develop and manage IT security, privacy, and data protection', 'IT-07, etapas 1 e 2: incidente de segurança ou de dados pessoais e mudança que mexe em dado pessoal, com a Governança'),
    ('8.3.8', 'Manage IT user identity and authorization', 'IT-07, etapa 2: acesso pela classificação do dado (IN-03) e pelo pedido'),
    ('8.4', 'Manage information', 'Fora: a Inteligência define e cataloga o dado (IN-03); a Integração conecta, guarda e dá o acesso, como tarefas da IN-03 e na IT-07'),
    ('8.5.4', 'Execute IT service/solution creation and testing', 'IT-06, etapas 1 e 2'),
    ('8.6.2', 'Plan service and solution implementation', 'IT-02, etapa 1, para o cliente; IT-06, etapa 3, para o agente'),
    ('8.6.3', 'Manage change deployment control', 'IT-07, etapa 2'),
    ('8.6.5', 'Perform service and solution rollout', 'IT-02, etapas 2 e 3; IT-06, etapa 3'),
    ('8.7.8', 'Operate IT user support', 'IT-07'),
    ('13.1', 'Manage business processes', 'IT-08: catálogo de jornadas (13.1.2), medida (13.1.4) e melhoria (13.1.5)'),
    ('13.2.1', 'Manage portfolio', 'IT-01, etapas 2 e 3'),
    ('13.2.3', 'Manage projects', 'IT-01 (registrar, acompanhar e encerrar), IT-02 (implantação), IT-03 (lançamento) e IT-04 (saída)'),
    ('13.4', 'Manage change', 'IT-03 e IT-08, para a mudança que o lançamento e o redesenho pedem aos círculos'),
    ('13.5', 'Develop and manage enterprise-wide knowledge management (KM) capability', 'Fora: Inteligência (IN-05). A Integração serve as bases aos agentes (IT-06)'),
]

# --------------------------------------------------- o que a Integração não faz
FRONTEIRAS = [
    ('Decidir o que o agente precisa saber e medir se ele acertou; definir e catalogar o dado', 'Inteligência',
     'O pedido de método (IT-05), o resultado dos testes e do monitoramento, as consultas sem resposta (IT-06), os registros de projetos, agentes e sistemas e as lições dos projetos encerrados.'),
    ('Rodar a entrega recorrente e atender', 'Operações',
     'O plano de implantação e o cliente implantado e aceito (IT-02), o plano de lançamento e a oferta lançada (IT-03) e o plano de saída (IT-04).'),
    ('Definir a política, as alçadas e a segurança; guardar os contratos; auditar', 'Governança',
     'A alçada da capacidade e do agente (IT-05 e IT-06), a conferência de mudança que mexe em dado pessoal ou segurança e o incidente de segurança (IT-07), o contrato de tecnologia (IT-07) e o redesenho que mexe em alçada (IT-08).'),
    ('Comprar, pagar e montar o orçamento', 'Gestão',
     'O que falta para a implantação (IT-02), a compra de fornecedor e licença (IT-07), o custo de tecnologia, a situação da carteira e os recursos liberados de projeto suspenso.'),
    ('Decidir o portfólio, a aposta, o lançamento e a data de saída', 'Estratégia',
     'A situação da carteira (IT-01), o conflito de capacidade entre empresas (IT-01, etapa 2), o plano de saída e a sua conclusão (IT-04).'),
    ('Definir os padrões, a marca e a voz', 'Identidade',
     'O pedido de padrão para agente ou canal novo e os registros de entregas de pessoas e agentes (IT-06); a consulta sobre materiais de implantação não cobertos (IT-02).'),
    ('Vender e cuidar do cliente', 'Negócios e Relações',
     'Relações recebe o plano de implantação (IT-02), o plano de lançamento (IT-03) e o plano de saída de clientes e contratos (IT-04); Negócios recebe o plano de lançamento (IT-03) e o plano de saída (IT-04).'),
    ('Medir o acerto do agente e incluir o método na ficha', 'Inteligência',
     'A Inteligência mede o acerto de conteúdo nos testes e na amostra em uso (IT-06). O agente de teste de um método ainda não publicado é montado como tarefa da IN-06, sem ficha; a ficha da capacidade vem com o método publicado (IT-05). A tarefa da IN-06 de incluir o método na ficha é feita pela IT-05, com a decisão da Integração e o aceite do líder do círculo dono.'),
    ('Coordenar a execução do mandato e informar a Estratégia', 'Integração, como tarefa da ES-05, etapa 7',
     'O mandato de venda ou de encerramento usa o plano de saída da IT-04; o de criação ou de aquisição abre na carteira o projeto de ligar a empresa (IT-04 e IT-01). A situação da execução é informada dentro da ES-05.'),
    ('Executar cada projeto no círculo dono', 'O círculo dono do projeto',
     'A Integração registra, prioriza, acompanha e encerra na carteira (IT-01); o trabalho do projeto roda na jornada do círculo dono.'),
]

# -------------------------------------------------------- pontos para decidir
PONTOS = []
DECISOES = [
    ('A Integração decide o seu ofício; o executivo decide a prioridade dos projetos da sua empresa', 'Ponto 1, aprovado por você (09:30 de 03/10/2026)',
     'Método de projetos, arquitetura e plataforma, ficha técnica da capacidade, liberação do agente pelos testes e mudança em sistemas são da Integração, ouvidos os donos. A prioridade dos projetos de cada empresa é do executivo, exceção declarada que vem do documento-base.'),
    ('O conflito de capacidade entre empresas sobe à Estratégia', 'Ponto 2, aprovado por você (09:30)', 'IT-01, etapa 2.'),
    ('A Integração libera o agente depois dos testes; a Governança confere a alçada; o líder do círculo dono aceita', 'Ponto 3, aprovado por você (09:30)', 'IT-06, etapa 3. A Inteligência mede o acerto de conteúdo.'),
    ('O líder do círculo dono decide o redesenho da jornada', 'Ponto 4, aprovado por você (09:30)', 'IT-08. Os círculos por onde a jornada passa confirmam a sua parte; a Governança confere quando mexe em alçada, regra ou contrato.'),
    ('A Integração decide o plano e a data do lançamento, ouvido o executivo', 'Ponto 5, aprovado por você (09:30)', 'IT-03. O lançamento só sai com a prontidão conferida.'),
    ('O pedido de serviço de uma empresa aos círculos fica na IT-05', 'Ponto 6, aprovado por você (09:30)', 'Com acordo de serviço combinado com o líder do círculo dono. O rateio fica para a consolidação das jornadas entre empresas.'),
    ('Oito jornadas', 'Ponto 7, aprovado por você (09:30)', 'IT-01 a IT-08, como propostas.'),
    ('A NE-01 recebe o plano de lançamento', 'Proposta aprovada por você (09:30)', 'Aplicada no círculo 5: a IT-03 entrega o plano a Negócios.'),
    ('A IT-04 recebe de Operações as entregas encerradas na saída', 'Proposta do círculo 7, aprovada por você às 11:50 de 03/10/2026',
     'IT-04, etapa 2: a conclusão da parte de Operações na saída passa a ser uma entrada, vinda da OP-08.'),
    ('A IT-06 recebe da Governança o desvio de agente apontado pela auditoria', 'Proposta do círculo 9, aprovada por você às 11:50 de 03/10/2026',
     'IT-06, etapa 4: o desvio achado na auditoria (GO-06) entra no tratamento de desvio, como o achado pelo monitoramento.'),
    ('Auditoria de execução: modo de cada etapa e nível de automação pelo que as tarefas fazem',
     'Itens 1 a 14 da auditoria, aprovados por você (12:33 de 03/10/2026)',
     'IT-08 etapa 1: o agente propõe as jornadas do ciclo e a pessoa da Integração decide; o modo passa de Autopiloto a Copiloto (item 3). De Autopiloto para Autômato, pelas tarefas: IT-05 etapa 3, IT-06 etapa 4, IT-08 etapa 3. De Copiloto para Assistido, pelas tarefas: IT-01 etapa 4, IT-02 etapa 1, IT-02 etapa 3, IT-03 etapa 1, IT-05 etapa 2, IT-06 etapa 3, IT-08 etapa 2. Nível de automação pela faixa: IT-04 baixa → média; IT-05 média → alta; IT-06 média → alta; IT-07 alta → média; IT-08 média → alta.'),
    ('Cadências e conteúdos validados; gates de implantação',
     'Validado por você (14:07 de 03/10/2026)',
     'IT-01 mensal; IT-05 trimestral; IT-06 mensal; IT-08 trimestral; método de projetos, prioridade da carteira, critério de liberação de agente (cinco testes) e política de segurança. O que depende de dado real ficou nos gates G1 a G9.'),
]

# ------------------- propostas de mudança em círculos já fechados (nenhuma aplicada)
PROPOSTAS = []

ALERTAS = [
    ('Operações (círculo 7)', 'A Integração espera de Operações a confirmação de capacidade antes da implantação e do lançamento, a implantação feita em conjunto e o fim das entregas na saída. Entrega o cliente implantado e aceito, o plano de implantação, o plano de lançamento, a oferta lançada e o plano de saída.'),
    ('Gestão (círculo 8)', 'A Integração entrega também os planos de implantação, de lançamento e de saída. Espera que a Gestão compre o que falta para a implantação, compre fornecedores e licenças de tecnologia, confira o orçamento do lançamento e proponha o destino das pessoas e dos custos na saída. Entrega a situação da carteira, os recursos liberados, o custo de tecnologia por empresa e por círculo e o cliente implantado para iniciar a cobrança.'),
    ('Governança (círculo 9)', 'A Integração entrega também os planos de lançamento e de saída. Espera as regras e alçadas vigentes, as regras de sigilo e de dados pessoais, a alçada de cada capacidade e de cada agente, a conferência de mudança que mexe em dado pessoal ou segurança, o tratamento do incidente de segurança, a revisão do contrato de tecnologia e as obrigações legais da saída. Entrega o contrato de tecnologia para guardar, os registros de entregas de pessoas e agentes e o agente suspenso, com o motivo.'),
]

# ------------------------------------------------ relação com o catálogo da rodada 2
MUDANCAS = [
    ('Ajustado', 'I-IT3 · Da carteira de projetos à entrega', 'IT-01',
     'Carteira única de projetos internos e de clientes, com a prioridade dos projetos de cada empresa decidida pelo executivo e o conflito entre empresas levado à Estratégia.'),
    ('Ajustado', 'V4 · Do contrato à operação', 'IT-02',
     'Mantida na Integração, com Operações confirmando a capacidade, implantando junto e assumindo a entrega.'),
    ('Acrescentado', 'Sem equivalente', 'IT-03',
     'Coordenação do lançamento da oferta, decidida em 01/10/2026: a Integração coordena com o executivo depois do portão de lançamento.'),
    ('Acrescentado', 'Sem equivalente', 'IT-04',
     'Plano de saída de oferta ou de empresa, pedido pela Estratégia (ES-04 e ES-05) e confirmado por você às 20:11 de 02/10/2026.'),
    ('Ajustado', 'C5 · Da necessidade à capacidade, I-IT1 · Da mudança ao catálogo atualizado e E1 · Do pedido ao serviço', 'IT-05',
     'Juntas numa jornada: pedido de serviço com acordo, necessidade de capacidade, ficha aceita pelo líder do círculo dono e catálogo versionado.'),
    ('Ajustado', 'I-IT2 · Do desenho ao agente liberado', 'IT-06',
     'Ganha o padrão de identidade para canal novo, a aceitação pelo líder do círculo dono, o monitoramento em uso e a suspensão do agente que sai da alçada.'),
    ('Ajustado', 'C10 · Do pedido de tecnologia ao serviço estável', 'IT-07',
     'Ganha o acesso pela classificação do dado, o incidente de segurança com a Governança e o contrato de tecnologia.'),
    ('Ajustado', 'I-IT4 · Da jornada medida à jornada melhorada', 'IT-08',
     'O redesenho passa a ser decidido pelo líder do círculo dono, e o catálogo de jornadas entra na mesma jornada.'),
]

LIMITES = [
    'Os fluxos são descritivos. Para executar falta escolher o motor e ligar cada tarefa a um sistema.',
    'Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado.',
    'As cadências foram validadas em 03/10/2026 (aba Parâmetros em aberto); o líder do círculo ajusta na implantação e a calibração com dados é o gate G9.',
    'Os rascunhos de método de projetos, regra de prioridade, critério de liberação de agente e política de segurança foram validados em 03/10/2026 (aba Gates de implantação); o texto final é o gate G8, e os números que dependem de dado real ficam nos gates G3 e G9.',
    'Continuidade de TI (APQC 8.3.4) e recuperação de desastre não estão desenhadas como etapa própria.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024. Da ISO 21502 e da ISO/IEC 27001 lemos só o resumo.',
    'Onde faltava o outro lado, as propostas à NE-01, à IT-04 e à IT-06 foram aprovadas e aplicadas. Com os nove círculos fechados (03/10/2026), as trocas com os outros oito foram conferidas dos dois lados pelo nome: 406 trocas, sem problema.',
    'A tarefa de quem não é do círculo (cliente, executivo, líder do círculo dono, outro círculo) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As aprovações e conferências sem decisão desenhada não têm ramo de recusa: a recusa devolve o trabalho a quem preparou.',
    'O rateio do custo dos círculos entre as empresas (E3) e o acordo de serviço como jornada entre empresas (E1) ficam para a consolidação das jornadas entre empresas.',
    'O método de projetos, a regra de prioridade da carteira e a arquitetura da plataforma, pelos quais o líder corporativo da Integração responde, não têm jornada própria: são mantidos como documentos do círculo e mudam pela IT-08 ou por projeto na IT-01.',
    'As saídas estão listadas por etapa, não por caminho: na IT-04, etapa 1, sai o plano de saída de oferta ou o de empresa, conforme o pedido.',
    'O agente suspenso volta por novo pedido de correção (IT-06); o lançamento suspenso volta quando o executivo o retoma (IT-03). A Estratégia não é avisada do impedimento de lançamento: a ES-04 não tem essa entrada.',
    'A capacidade feita por pessoa ou por assessoria fica “em construção” no catálogo até o projeto aberto na carteira ser entregue; a marcação como “em uso” nesse caso não tem tarefa desenhada.',
    'Na saída de empresa, a conclusão do plano é informada à Estratégia dentro da ES-05, etapa 7, pela tarefa da Integração; a “Conclusão do plano de saída da oferta” vale para a ES-04.',
    'A amostra de acerto do agente em uso vai à Inteligência, que avalia o método (IN-06, etapa 5); o veredito volta como mudança de método ou de base, não como decisão dentro da IT-06.',
    'O projeto em espera que passa a caber volta à priorização por novo registro na IT-01, aberto pelo ciclo de acompanhamento.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das oito jornadas e apontou 30 achados, 7 graves: a coordenação da saída de empresa sem gatilho, a pendência sem resposta à Estratégia, o mandato que remontava o plano, a medida do acerto do agente feita pela Integração e não pela Inteligência, e o ciclo entre método, ficha e agente.',
    'Um verificador independente conferiu as fontes: os 21 códigos e nomes do APQC PCF 7.4 e as páginas da ISO 21502 e da ISO/IEC 27001 foram confirmados; as páginas da Anthropic e do NIST, que ele não conseguiu abrir, eu conferi.',
    'O mesmo revisor leu a segunda e a terceira versões. Na segunda, 21 achados resolvidos, 9 em parte e 8 defeitos novos, 2 graves; na terceira, 1 defeito novo grave (a saída de empresa executada antes do mandato) e 2 médios. Todos foram corrigidos e passaram por todos os testes automáticos, mas o último acerto não passou por nova revisão independente.',
]
