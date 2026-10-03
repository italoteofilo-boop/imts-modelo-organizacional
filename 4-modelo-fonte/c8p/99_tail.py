
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
    'Da área trabalhista e contábil foram lidos os prazos da folha, das férias e da rescisão (CLT), o depósito do FGTS e a escrituração (Código Civil), parte em transcrição secundária. A regra fiscal não foi citada: os tributos dependem do regime de cada empresa, que não está no modelo (empresas e pessoas ficaram para depois). A apuração segue a lei vigente, com a assessoria.',
    'Estratégia e políticas de pessoas (APQC 7.1), relações sindicais e queixas (7.4), benefícios (7.5.2), reembolso de despesas (9.6.2), dívida e aplicações (9.7.4) não têm etapa própria.',
    'O fornecedor não é uma parte do vocabulário do modelo: as trocas com ele aparecem como tarefas da Gestão.',
    'A cobrança judicial e a recusa de pedido de compra pelo executivo não têm ramo desenhado: a recusa devolve o pedido a quem pediu.',
    'O pedido de recurso que mexe na alocação entre empresas fica registrado para a revisão do portfólio: a ES-02 não tem entrada para um pedido direto e lê a execução do orçamento.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024.',
    'Com os nove círculos fechados (03/10/2026), as trocas com os outros oito foram conferidas dos dois lados pelo nome: 406 trocas, sem problema.',
    'A tarefa de quem não é do círculo (líder, pessoa, executivo, outro círculo) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As saídas estão listadas por etapa, não por caminho.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das doze jornadas, conferiu os 38 códigos e nomes do APQC PCF 7.4 (todos conferem) e o art. 6º da LGPD, e apontou 22 achados, 4 graves: caminhos que caíam na etapa seguinte sem ter o que processar (orçamento, faturamento e ativos), a remuneração de parceiros sem jornada, a compra pedida pela Integração por fora da jornada de compras e o reembolso ao cliente sem pagamento.',
    'Todos foram corrigidos ou declarados como limite; a folha virou jornada própria (GE-13). A versão corrigida passou por todos os testes automáticos e não passou por nova revisão independente.',
]
