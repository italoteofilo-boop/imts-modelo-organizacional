
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
