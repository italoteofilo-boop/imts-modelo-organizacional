
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
