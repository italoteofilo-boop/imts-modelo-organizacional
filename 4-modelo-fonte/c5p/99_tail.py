
# -------------------------------------------------------------- domínios
DOMINIOS = [
    ('Preço e plano comercial', 'Manter a tabela de preços e a política comercial, planejar as vendas e prever a receita.'),
    ('Venda', 'Aceitar a oportunidade, fazer a proposta, negociar e fechar o contrato, e disputar licitações.'),
    ('Contas e contratos', 'Renovar, ampliar, aditar e encerrar os contratos dos clientes.'),
    ('Venda conjunta', 'Vender com parceiros e em oferta conjunta entre as empresas do Ecossistema.'),
]

ONDAS = {
    1: 'O que os círculos fechados já esperam de Negócios e o que transforma oportunidade em contrato e cuida dos contratos',
    2: 'O que amplia o alcance da venda: parceiros de venda e oferta conjunta entre as empresas',
}

# ------------------------------------------------- o que usamos de cada fonte
USO = {
    'apqc': 'PCF 7.4. Os processos de Negócios estão em quatro grupos da categoria 3: 3.2.2 e 3.3.3, estratégia e gestão de preços, e 3.3.9, material de produto (NE-01); 3.2.3, estratégia de canais, e 3.4, estratégia de vendas, com previsão, alvos e orçamento de vendas (NE-02); e 3.5, planos de venda, com oportunidades, contas, propostas e cotações, pedidos e parceiros (NE-03 a NE-07). A tabela de cobertura, na aba Método, mostra onde cada um foi parar.',
    'l14133': 'Fases do processo de licitação, em sequência: preparatória, divulgação do edital, apresentação de propostas e lances, quando for o caso, julgamento, habilitação, recursal e homologação (art. 17, caput); a habilitação pode vir antes das propostas e do julgamento, por ato motivado, se o edital prever (§ 1º); a forma eletrônica é a preferida (§ 2º). A NE-05 começa na divulgação do edital (art. 17, II); a fase preparatória, caracterizada pelo planejamento (art. 18, caput), não tem tarefa de Negócios, salvo responder a pedido de cotação. Sistema de registro de preços, ata de registro de preços e órgão participante e não participante (art. 6º, incisos XLV, XLVI, XLVIII e XLIX). Base das etapas da NE-05. Lidos em 03/10/2026, em transcrição secundária: esclarecimento e impugnação pedidos até três dias úteis antes da abertura, com resposta em até três dias úteis (art. 164); intenção de recorrer manifestada de imediato, recurso e contrarrazões em três dias úteis e decisão da autoridade superior em até dez dias úteis (art. 165); convocação para assinar no prazo do edital, prorrogável uma vez (art. 90). Na NE-06: a ata vale um ano, prorrogável por igual período se o preço for vantajoso (art. 84); a adesão de órgão não participante exige justificativa, preço compatível com o mercado e aceite do gerenciador e do fornecedor, até 50% dos quantitativos por órgão e, no total, até o dobro de cada item (art. 86). No desenho, os prazos seguem “nos prazos da lei e do edital”; a contratação direta não foi conferida.',
    'dmn': 'Notação de regras de decisão. Base das tarefas de regra que aplicam a tabela de preços, a política comercial e as alçadas de concessão na NE-01, na NE-03, na NE-04 e na NE-06; a tabela de alçadas é da Governança.',
    'bpmn': 'Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, manual, serviço, regra de negócio, script e recebimento, além da atividade de chamada.',
    'camunda': 'Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.',
    'sipoc': 'Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.',
}

# ----------------------------------- cobertura do referencial (APQC PCF 7.4)
COBERTURA = [
    ('3.2.2', 'Define pricing strategy', 'NE-01, etapa 2: preço de tabela, descontos e alçada de desconto. O preço-base de cada oferta é da Inteligência (IN-07)'),
    ('3.2.3', 'Define and manage channel strategy', 'NE-02, etapa 2, para os canais de venda; os canais de demanda são de Relações (RE-01)'),
    ('3.3.3', 'Develop and manage pricing', 'NE-01: executar, avaliar, refinar e comunicar os preços (3.3.3.4 a 3.3.3.6 e 3.3.3.9)'),
    ('3.3.9', 'Manage product marketing material', 'NE-01, etapa 3, para o material de venda; o material das ações de demanda é de Relações (RE-02)'),
    ('3.4.1', 'Develop sales forecast', 'NE-02, etapa 1'),
    ('3.4.2', 'Develop sales partner/alliance relationships', 'Fora: Relações (RE-06). Negócios vende com o parceiro ativo (NE-07)'),
    ('3.4.3', 'Establish overall sales budgets', 'NE-02: a previsão de receita vai à Gestão, que monta o orçamento'),
    ('3.4.4', 'Establish sales goals and measures', 'NE-02, etapa 2: alvos de venda por oferta e canal, desdobrados dos alvos do ciclo'),
    ('3.4.5', 'Establish customer management measures', 'Fora: Relações mede a saúde do cliente (RE-05), com os indicadores da Inteligência'),
    ('3.5.1', 'Manage leads/opportunities', 'Até a qualificação (3.5.1.1 a 3.5.1.3), Relações (RE-03). Daí em diante, NE-03 (aceite, quem conduz a venda, solução e proposta) e NE-02 (funil e previsão)'),
    ('3.5.2', 'Manage customers and accounts', 'NE-02, etapa 2: clientes-chave e plano de conta de venda; NE-06 para os contratos. O relacionamento e o plano de sucesso são de Relações (RE-05) e os dados mestres, da base de relacionamento (RE-03)'),
    ('3.5.3', 'Develop and manage sales proposals, bids, and quotes', 'NE-03 (propostas e cotações) e NE-05 (licitações)'),
    ('3.5.4', 'Manage sales orders', 'NE-04, etapa 3, e NE-06, etapa 4 (contratação pela ata); o atendimento do pedido é de Operações e o faturamento, da Gestão'),
    ('3.5.5', 'Manage sales partners and alliances', 'Capacitação e material do parceiro: Relações (RE-06). Resultado da venda com o parceiro: NE-07, etapa 3'),
    ('3.5.6 a 3.5.8', 'Perform sales at physical outlets; Perform field sales; Perform digital sales', 'Não desenhados como jornadas próprias: o canal de venda é atributo da oportunidade e da proposta (NE-03)'),
]

# --------------------------------------------------- o que Negócios não faz
FRONTEIRAS = [
    ('Gerar a demanda, qualificar os contatos e acompanhar o sucesso do cliente', 'Relações',
     'O aceite ou a devolução de cada oportunidade (NE-03), a tabela de preços (NE-01), o contrato assinado com o escopo vendido (NE-04, NE-05 e NE-06) e o vencimento e o resultado de cada renovação (NE-06).'),
    ('Desenhar a oferta, o modelo de negócio e o preço-base', 'Inteligência',
     'O pedido de ajuste ou de revisão de oferta em uso, quando o escopo não cabe no catálogo (NE-03) ou o preço de tabela ficaria abaixo do preço-base (NE-01); os motivos de ganho e de perda e os registros de propostas, vendas e contratos (NE-03 a NE-06).'),
    ('Decidir o portfólio e a oferta nova', 'Estratégia',
     'A ideia de oferta nova que nasce de uma necessidade de cliente fora do catálogo (NE-03, etapa 2).'),
    ('Definir os padrões, a marca e o posicionamento', 'Identidade',
     'Confere com os padrões o material de venda (NE-01), a proposta (NE-03), a parte livre da proposta de licitação (NE-05) e a proposta de renovação (NE-06) e consulta a Identidade no caso não coberto.'),
    ('Implantar o cliente e coordenar o plano de saída', 'Integração',
     'O contrato assinado (NE-04, NE-05 e NE-06), a previsão para a capacidade de implantação (NE-02) e a parte de Negócios do plano de saída (NE-06, etapa 3).'),
    ('Entregar e atender', 'Operações',
     'A confirmação de capacidade antes da proposta e do edital (NE-03 e NE-05), o contrato e a ata assinados e a previsão de vendas.'),
    ('Faturar, cobrar, montar o orçamento e pagar a remuneração de parceiros e de quem vende', 'Gestão',
     'O contrato e a ata assinados, a previsão de receita, o desvio contra os alvos e a margem conferida da política comercial e da oferta conjunta.'),
    ('Manter os modelos e as alçadas, aprovar a faixa de desconto, revisar o que foge do modelo, conferir os poderes de quem assina e guardar; conduzir esclarecimentos, impugnações, recursos e contrarrazões', 'Governança',
     'A faixa de desconto e as condições que mexem nos modelos (NE-01), a proposta e o contrato com cláusula fora do modelo, o termo de encerramento (NE-06), a concessão acima da alçada do executivo (aos sócios), a habilitação e os recursos em licitação (NE-05) e o acordo de oferta conjunta entre as empresas (NE-07).'),
    ('Desenhar e validar a oferta, com o piloto', 'Inteligência',
     'Negócios prepara, fecha e encerra o termo de piloto e redige os termos comerciais da oferta e dos ajustes como tarefas da IN-07, nos modelos da Governança e com a tabela (NE-01). Não há jornada própria de Negócios para isso.'),
    ('Formar, ativar e capacitar o parceiro de venda', 'Relações',
     'O resultado da venda com o parceiro e, quando for o caso, o pedido de encerramento da parceria (NE-07, etapa 3).'),
]

# -------------------------------------------------------- pontos para decidir
PONTOS = []
DECISOES = [
    ('Negócios decide o seu ofício; o executivo opina, aprova a concessão acima da alçada de quem vende e assina',
     'Ponto 1, aprovado por você (20:11)',
     'Acima da alçada do executivo, decidem os sócios. A faixa de desconto de quem vende é aprovada pela Governança. A oportunidade de parceiro de venda é conferida por Negócios com o critério combinado com Relações, sem passar pela qualificação de Relações.'),
    ('O preço de tabela fica no preço-base ou acima dele',
     'Ponto 2, aprovado por você (20:11)',
     'Abaixo, Negócios pede à Inteligência a revisão do preço-base e mantém a oferta no preço vigente até a resposta (NE-01). Você confirmou também que mudar o preço-base de oferta em uso é revisão, que volta ao portão de entrada.'),
    ('Licitação é jornada própria; Negócios decide participar e recorrer, ouvidos o executivo e a Governança',
     'Ponto 3, aprovado por você (20:11)',
     'NE-05, nas fases da Lei 14.133. A Governança confere a habilitação e conduz esclarecimentos, impugnações, recursos e contrarrazões; o executivo assina.'),
    ('A divisão na oferta conjunta é dos executivos das duas empresas',
     'Ponto 4, aprovado por você (20:11)',
     'Exceção declarada à regra de que o executivo opina. A Gestão confere o efeito no resultado de cada empresa e a Governança formaliza o acordo antes da proposta (NE-07).'),
    ('A previsão de receita e o desdobramento dos alvos de venda são de Negócios',
     'Ponto 5, aprovado por você (20:11)',
     'NE-02, a partir dos alvos do ciclo, do funil e dos contratos; a previsão vai à Gestão, a Operações, à Integração e ao executivo.'),
    ('O pedido de cancelamento é tratado por Negócios, como retenção',
     'Ponto 6, aprovado por você (20:11)',
     'NE-06, etapa 2. Relações trata o risco de perda antes do pedido (RE-05).'),
    ('Sete jornadas',
     'Ponto 7, aprovado por você (20:11)',
     'NE-01 a NE-07, como propostas.'),
    ('Auditoria de execução: modo de cada etapa e nível de automação pelo que as tarefas fazem',
     'Itens 1 a 14 da auditoria, aprovados por você (12:33 de 03/10/2026)',
     'De Assistido para Copiloto, pelas tarefas: NE-05 etapa 4. De Autopiloto para Autômato, pelas tarefas: NE-03 etapa 4. De Copiloto para Assistido, pelas tarefas: NE-02 etapa 2, NE-03 etapa 2, NE-06 etapa 2, NE-06 etapa 3, NE-07 etapa 2.'),
    ('A regra de remuneração de quem vende e de parceiros é decidida pelos sócios',
     'Decidido por você (13:09 de 03/10/2026)',
     'Negócios propõe com a Gestão; os sócios decidem, porque mexe em custo e incentivo de todas as empresas. Também: prazos da Lei 14.133 (arts. 84, 86, 90, 164 e 165) lidos em transcrição secundária e registrados nas fontes.'),
    ('Alçada de concessão comercial',
     'Aprovado por você (13:51 de 03/10/2026)',
     'A NE-01 fixa, por oferta, a faixa entre o preço de tabela e o preço-base. Quem vende concede até metade da faixa; o executivo, até o preço-base e a condição de pagamento fora da política; os sócios decidem preço abaixo do preço-base, exclusividade e prazo maior que o ciclo estratégico. No contrato público, a concessão é a que o edital permite. A fração é escolha de desenho, a recalibrar com dados.'),
    ('Cadências e conteúdos validados; gates de implantação',
     'Validado por você (14:07 de 03/10/2026)',
     'NE-01 semestral; NE-02 trimestral, com previsão mensal; NE-07 semestral; estrutura dos modelos de contrato e regra de remuneração. O que depende de dado real ficou nos gates G1 a G9.'),
]

# ------------------- propostas de mudança em círculos já fechados (nenhuma)
PROPOSTAS = []

ALERTAS = [
    ('Integração (círculo 6)', 'Negócios espera o plano de saída de clientes e contratos e a confirmação do que a implantação pede antes da proposta. Entrega o contrato assinado, a previsão de vendas, os contratos afetados pela saída e as pendências de contrato na saída.'),
    ('Operações (círculo 7)', 'Negócios espera a confirmação de capacidade antes da proposta, do edital e da previsão. Entrega o contrato e a ata assinados, a tabela de preços e a previsão de vendas.'),
    ('Gestão (círculo 8)', 'Negócios espera a situação de faturas e pagamentos de cada cliente e a conferência de margem da política comercial e da oferta conjunta. Entrega o contrato e a ata assinados, a previsão de receita, o desvio contra os alvos e o vencimento de cada contrato. A remuneração de quem vende e de parceiros fica com a Gestão.'),
    ('Governança (círculo 9)', 'Negócios espera as regras e alçadas vigentes, os modelos de proposta e de contrato, as certidões e os documentos de habilitação em dia, a revisão do que foge do modelo, a condução de esclarecimentos, impugnações e recursos em licitação e a formalização do acordo de oferta conjunta. Entrega o contrato para conferir e guardar e o acordo entre as empresas.'),
]

# ------------------------------------------------ relação com o catálogo da rodada 2
MUDANCAS = [
    ('Ajustado', 'I-NE1 · Da oferta à tabela e política comercial', 'NE-01',
     'Mantida, com a regra de que o preço de tabela não fica abaixo do preço-base sem revisão da Inteligência.'),
    ('Ajustado', 'I-NE2 · Do funil à previsão', 'NE-02',
     'Vira planejamento de vendas do ciclo e previsão de receita, com os alvos de venda desdobrados dos alvos do ciclo.'),
    ('Ajustado', 'V3 · Da oportunidade ao contrato', 'NE-03 e NE-04',
     'Dividida em proposta e contrato. A qualificação ficou em Relações (RE-03); Negócios começa no aceite.'),
    ('Ajustado', 'V7 · Do resultado à renovação (parte comercial)', 'NE-06',
     'A renovação, a expansão, o aditivo e a retenção comerciais; o acompanhamento do cliente ficou em Relações (RE-05).'),
    ('Ajustado', 'E2 · Da oportunidade cruzada à oferta conjunta', 'NE-07',
     'Junta a oferta conjunta entre empresas e a venda com parceiros de venda.'),
    ('Acrescentado', 'Sem equivalente', 'NE-05',
     'Jornada nova de licitações e contratação com o setor público, nas fases da Lei 14.133.'),
    ('Ajustado', 'NE-01, etapa 1: sem o plano de lançamento', 'Recebe o plano de lançamento da oferta da Integração (IT-03)',
     'Proposta do círculo 6, aprovada por você às 09:30 de 03/10/2026.'),
]

LIMITES = [
    'Os fluxos são descritivos. Para executar falta escolher o motor e ligar cada tarefa a um sistema.',
    'Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado.',
    'As cadências foram validadas em 03/10/2026 (aba Parâmetros em aberto); o líder do círculo ajusta na implantação e a calibração com dados é o gate G9.',
    'A alçada de concessão e as regras gerais dos contratos foram aprovadas em 03/10/2026 (aba Parâmetros em aberto); a estrutura dos modelos e a regra de remuneração (fixo mais variável sobre a receita recebida) foram validadas em 03/10/2026; o texto dos modelos é o gate G8 e os percentuais, o G3.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024. Da Lei 14.133 conferimos os arts. 6º (incisos XLV, XLVI, XLVIII e XLIX), 17 e 18; os prazos e o rito de esclarecimento, impugnação, recurso, adesão à ata e contratação direta não foram conferidos e estão como “no prazo do edital”.',
    'Com os nove círculos fechados (03/10/2026), as trocas com os outros oito foram conferidas dos dois lados pelo nome: 406 trocas, sem problema.',
    'A tarefa de quem não é do círculo (cliente, parceiro, executivo, sócios, outro círculo) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As aprovações e conferências sem decisão desenhada não têm ramo de recusa: a recusa devolve o trabalho a quem preparou.',
    'Contratos, aditivos e documentos de licitação seguem o modelo da Governança ou o formato do edital; a conferência com os padrões de identidade fica no material de venda, na proposta e na parte livre da proposta de licitação.',
    'As saídas estão listadas por etapa, não por caminho: na NE-05, etapa 4, o contrato só sai quando há contrato ou adesão, e a ata só quando há ata.',
    'Se o escopo de uma oferta conjunta mudar na proposta, a divisão acordada entre as empresas precisa ser revista; o desenho não tem esse retorno.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das sete jornadas e apontou 30 achados, 7 graves: laços entre jornadas, decisões tomadas duas vezes, dono duplo da alçada de desconto e conferência de identidade em uma só jornada. Todos foram tratados na segunda versão.',
    'Um verificador independente conferiu as fontes: os códigos e nomes do APQC PCF 7.4 foram confirmados letra por letra; da Lei 14.133, os arts. 6º (XLV, XLVI, XLVIII e XLIX), 17 e 18 foram confirmados no Planalto. O texto de uso foi corrigido em três pontos, e o que a lei diz sobre prazos, recursos, adesão e convocação ficou declarado como não conferido.',
    'Um segundo revisor leu a segunda versão: 18 achados resolvidos, 12 em parte, e 7 defeitos novos, 1 grave (contrato que Relações não renova terminava sem formalização). Os 7 foram corrigidos e passaram por todos os testes automáticos, mas não por nova revisão independente. Dois itens ficaram como pontos para você decidir (1 e 4) e um como limite.',
]
