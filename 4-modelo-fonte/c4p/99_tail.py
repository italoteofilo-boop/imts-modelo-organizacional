
# -------------------------------------------------------------- domínios
DOMINIOS = [
    ('Demanda', 'Planejar e executar a geração de demanda e entregar a Negócios oportunidades qualificadas.'),
    ('Clientes', 'Desenhar a experiência do cliente e cuidar do sucesso de cada cliente depois da venda.'),
    ('Parcerias e instituições', 'Formar e cuidar de parcerias e relações institucionais e decidir o uso da marca por terceiros.'),
    ('Comunicação e reputação', 'Comunicar para fora e vigiar como os públicos percebem as marcas.'),
]

ONDAS = {
    1: 'O que os círculos fechados já esperam de Relações e o que gera demanda e cuida dos clientes',
    2: 'O que amplia o alcance: parcerias, relações institucionais e uso da marca por terceiros',
}

# ------------------------------------------------- o que usamos de cada fonte
USO = {
    'apqc': 'PCF 7.4. Os processos das funções de Relações estão em quatro blocos: 1.2.8, estratégia de experiência do cliente; 3.2 e 3.3, estratégia e planos de marketing; 3.4.2, 3.5.1, 3.5.2 e 3.5.5, oportunidades, clientes e parceiros; 12.2 e 12.5, relações com governo, entidades e imprensa. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.',
    'barcelona': 'Sete princípios de medição da comunicação, de 2020. Os que usamos: fixar alvos é pré-requisito do planejamento e da medição; medir resultado e efeito, e não só a entrega; medir de forma qualitativa e quantitativa; a equivalência em valor de anúncio (AVE) não é o valor da comunicação. Base dos alvos e das medidas de cada ação na RE-01 e na RE-02, da medição do efeito de cada tema na RE-07 e da leitura da percepção na RE-08. Os princípios tratam de comunicação; usá-los também nas ações de demanda é leitura nossa.',
    'nng_journey': 'O mapa da jornada é a visualização do processo que uma pessoa percorre para atingir um objetivo. Cinco elementos: o ator, o cenário e as expectativas, as fases da jornada, as ações, os modos de pensar (mindsets) e as emoções, e as oportunidades. Base do mapa da jornada na RE-04.',
    'nng_blueprint': 'Mapa de serviço com quatro elementos: ações do cliente, ações à vista do cliente, ações de bastidor e processos. Base do desenho dos pontos de contato com Operações na etapa 2 da RE-04.',
    'iso44001': 'Norma de requisitos para identificar, desenvolver e gerir relações de negócio colaborativas dentro das organizações ou entre elas. Lemos só o resumo; a norma completa é paga e está em revisão. Usada como referência do ciclo de vida da parceria na RE-06, do encaixe à saída; as etapas da jornada vêm do APQC (3.4.2, 3.5.5 e 12.2.3).',
    'reptrak': 'Sete fatores de reputação, que formam a dimensão “Think” do modelo da RepTrak: produtos e serviços, desempenho, inovação, liderança, conduta, cidadania e ambiente de trabalho. Usados como temas para agrupar os sinais e a percepção dos públicos na RE-08.',
    'iso22361': 'Diretrizes para a capacidade de gestão de crises. Base do protocolo de crise da Identidade, que a RE-08 usa para classificar o sinal e acionar o comitê da Governança. Lemos só o resumo.',
    'lgpd': 'Bases legais do tratamento, entre elas o consentimento, a execução de contrato e o legítimo interesse (art. 7º); consentimento por escrito ou por meio que demonstre a vontade do titular, revogável a qualquer momento (art. 8º); acesso facilitado às informações do tratamento (art. 9º); direitos do titular, entre eles confirmar a existência do tratamento, acessar, corrigir, anonimizar, bloquear ou eliminar dados desnecessários ou excessivos, portar, eliminar os dados tratados com consentimento e revogar o consentimento (art. 18, I a VI e IX). Base do registro com a base legal, da saída do contato e da execução dos pedidos dos titulares na RE-03. Quem define a regra é a Governança.',
    'bpmn': 'Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, manual, serviço, regra de negócio, script e recebimento, além da atividade de chamada.',
    'camunda': 'Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.',
    'sipoc': 'Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.',
}

# ----------------------------------- cobertura do referencial (APQC PCF 7.4)
COBERTURA = [
    ('1.2.8', 'Develop customer experience strategy', 'RE-04. Avaliar (1.2.8.1) na etapa 1; personas, mapa da jornada, validação com clientes e alinhamento aos valores da marca (1.2.8.2) nas etapas 2 e 3'),
    ('3.2.3', 'Define and manage channel strategy', 'RE-01, etapa 2, para os canais de demanda. Os canais de venda são de Negócios'),
    ('3.2.5', 'Develop marketing communication strategy', 'RE-01 e RE-07. A comunicação interna (3.2.5.4) é da Gestão'),
    ('3.2.6', 'Design and manage customer loyalty program', 'Não desenhado: nenhum círculo pediu programa de fidelidade'),
    ('3.3.1', 'Establish goals, objectives, and measures for products/services by channel/segment', 'RE-01, etapa 2: alvo e medida de cada ação'),
    ('3.3.2', 'Establish marketing budgets', 'RE-01, etapa 3, com a Gestão'),
    ('3.3.4', 'Develop and manage promotional activities', 'RE-02'),
    ('3.3.5', 'Track customer management measures', 'RE-05, etapa 2 (saúde do cliente), com os indicadores da Inteligência'),
    ('3.3.6', 'Analyze and respond to customer insight', 'RE-08 (redes e menções) e RE-03 (interações); a análise de dados é da Inteligência'),
    ('3.3.8', 'Develop go-to-market strategy', 'RE-01, para cada oferta aprovada para lançamento. A coordenação do lançamento é da Integração'),
    ('3.3.9', 'Manage product marketing material', 'RE-02, etapa 1: quem usa a marca produz o material, com o pacote de marca da Identidade'),
    ('3.4.2', 'Develop sales partner/alliance relationships', 'RE-06, etapas 1 a 3'),
    ('3.5.1', 'Manage leads/opportunities', 'RE-03 até a oportunidade qualificada (3.5.1.1 a 3.5.1.3). Daí em diante (3.5.1.4 em diante), Negócios'),
    ('3.5.2', 'Manage customers and accounts', 'RE-05 (relacionamento e plano do cliente) e RE-03, etapa 5 (dados mestres do cliente). Plano de conta de venda: Negócios'),
    ('3.5.5', 'Manage sales partners and alliances', 'RE-06, etapas 3 e 4'),
    ('6.2.3 e 6.5', 'Manage customer complaints; Evaluate customer service operations and customer satisfaction', 'Fora: Operações. Relações recebe as reclamações e incidentes com a causa (RE-04, RE-08) e mede a saúde do cliente (RE-05)'),
    ('12.2', 'Manage government and industry relationships', 'RE-06, para relações institucionais e com entidades. Lobby (12.2.4) não está desenhado'),
    ('12.5', 'Manage public relations program', 'RE-07 (imprensa e comunicados) e RE-06 (comunidade)'),
]

# --------------------------------------------------- o que Relações não faz
FRONTEIRAS = [
    ('Vender: proposta, negociação, contrato e renovação comercial; tabela de preços e política comercial', 'Negócios',
     'A oportunidade qualificada (RE-03), a oportunidade de renovação ou de expansão com o histórico (RE-05) e o plano de demanda (RE-01).'),
    ('Atender o cliente, tratar reclamações e entregar', 'Operações',
     'A estratégia de experiência do cliente (RE-04), o plano de sucesso e o plano de recuperação de cada cliente (RE-05) e as lacunas de percepção (RE-08).'),
    ('Definir a marca, os padrões, o posicionamento institucional e a regra de uso da marca por terceiros', 'Identidade',
     'A escuta e a percepção dos públicos (RE-08). Confere com os padrões o material, o conteúdo, a experiência e o relatório ao cliente e consulta a Identidade no caso não coberto.'),
    ('Decidir a posição na crise e o porta-voz', 'Governança, com o executivo da empresa',
     'O alerta de crise com os fatos apurados, a comunicação da posição decidida e as lições da crise (RE-08).'),
    ('Fazer e guardar contratos, definir as regras de dados pessoais, decidir a resposta ao titular, definir as alçadas e levar aos sócios', 'Governança',
     'Os termos da parceria e a parceria acima da alçada (RE-06), a liberação do uso da marca fora da regra (RE-06, etapa 5) e a execução, na base de relacionamento, da resposta ao titular decidida pela Governança (RE-03, etapa 5).'),
    ('Responder à consulta sobre o uso da marca fora da regra', 'Identidade',
     'O pedido de uso fora da regra, conferido pelo agente (RE-06, etapa 5). Relações decide a exceção ouvida a resposta, como o círculo 1 prevê.'),
    ('Ler o mercado, tornar o dado confiável e medir os indicadores', 'Inteligência',
     'A percepção dos públicos, os sinais do relacionamento e as lições de clientes (RE-05, RE-06 e RE-08).'),
    ('Desenhar a oferta, o modelo de negócio e o preço-base', 'Inteligência',
     'Indica clientes para conversar e para o piloto e confere o desenho da entrega com a estratégia de experiência (IN-07).'),
    ('Decidir a parceria que muda o portfólio', 'Estratégia',
     'A parceria que muda o portfólio, levada como aposta ao portão de entrada com a avaliação (RE-06, etapa 2); a aprovada volta à RE-06 para ser formalizada. A parceria acima da alçada sobe aos sócios pela Governança.'),
    ('Vender com o parceiro de venda', 'Negócios',
     'O parceiro formado, ativado e capacitado nas ofertas e no uso da marca (RE-06, etapas 2 e 3).'),
    ('Montar sistemas, agentes e canais e implantar o cliente; coordenar o plano de saída', 'Integração',
     'O que os padrões de experiência pedem (RE-04), a configuração das ações nos canais (RE-02) e a transição dos clientes quando uma oferta ou empresa sai (RE-05).'),
    ('Comunicar para dentro', 'Gestão',
     'O conteúdo externo publicado (RE-07, etapa 4), para a Gestão reproduzir para as pessoas quando precisar.'),
    ('Montar o orçamento', 'Gestão',
     'O custo das ações do plano de demanda e o pedido de recurso adicional (RE-01).'),
]

# -------------------------------------------------------- pontos para decidir
PONTOS = []
DECISOES = [
    ('Relações decide o que é do seu ofício; o executivo e Negócios opinam',
     'Ponto 1, aprovado por você (19:05)',
     'Relações decide o plano de demanda, a qualificação de cada oportunidade, a estratégia de experiência do cliente, a pauta e o conteúdo externo e as parcerias dentro da alçada. O executivo aprova o que se diz em nome da empresa e quem fala por ela.'),
    ('O critério de oportunidade qualificada é combinado com Negócios; sem acordo, decide o executivo',
     'Ponto 2, aprovado por você (19:05)',
     'Relações e Negócios combinam o critério a cada ciclo de demanda (RE-01, etapa 2). Negócios aceita ou devolve cada oportunidade com o motivo (RE-03). É a única exceção do círculo à regra de que o executivo opina e não decide.'),
    ('Relações acompanha o sucesso do cliente; Negócios renova e amplia; Operações atende e entrega',
     'Ponto 3, aprovado por você (19:05)',
     'O plano de sucesso (RE-05) é a referência comum dos três círculos que falam com o cliente.'),
    ('O executivo aprova o que fala em nome da empresa; a Governança confere o risco jurídico',
     'Ponto 4, aprovado por você (19:05)',
     'Relações decide a pauta e aprova o conteúdo dentro dos padrões (RE-07). Na crise, a posição é do comitê da Governança, com o executivo (RE-08).'),
    ('O uso da marca por terceiros fica na RE-06, etapa 5',
     'Ponto 5, aprovado por você (19:05)',
     'A regra é da Identidade. Relações decide o uso coberto pela regra e, fora dela, a exceção ouvida a Identidade; a Governança libera antes da autorização.'),
    ('Relações forma e acompanha o parceiro de venda; Negócios vende com ele',
     'Ponto 6, aprovado por você (19:05)',
     'A relação institucional sem contrato segue a mesma jornada e a mesma alçada; a Governança confere o termo e o executivo o aprova (RE-06).'),
    ('Oito jornadas',
     'Ponto 7, decidido por mim, como você pediu (19:05)',
     'Mantive a proposta. Planejar e executar a demanda têm cadência diferente (ciclo e ação), e desenhar a experiência de todos os clientes é trabalho distinto de cuidar de cada cliente. Juntar daria seis jornadas maiores, com gatilhos misturados.'),
    ('As três propostas aos círculos 2 e 3 foram aceitas e aplicadas',
     'Decisão sua (19:05)',
     'IN-07, etapa 4, recebe a estratégia de experiência do cliente (RE-04). IN-03, etapa 2, recebe a situação do funil e a base de relacionamento (RE-03) e o resultado das ações de demanda (RE-02). ES-04 avisa Relações da aposta mantida, em espera, devolvida ou encerrada (etapa 3): a RE-05 desfaz a transição preparada e a RE-06 responde ao parceiro. A parceria aprovada no portão volta a Relações (etapa 5) e a RE-06 a formaliza.'),
    ('Auditoria de execução: modo de cada etapa e nível de automação pelo que as tarefas fazem',
     'Itens 1 a 14 da auditoria, aprovados por você (12:33 de 03/10/2026)',
     'RE-03 etapa 1: na dúvida sobre a base legal, a pessoa de Relações decide (item 8). De Assistido para Copiloto, pelas tarefas: RE-06 etapa 2. De Autopiloto para Autômato, pelas tarefas: RE-02 etapa 2, RE-03 etapa 4. De Copiloto para Assistido, pelas tarefas: RE-01 etapa 2, RE-03 etapa 3, RE-06 etapa 4. Nível de automação pela faixa: RE-02 alta na execução, média na preparação → média (alta na execução, média na preparação); RE-08 alta na coleta, baixa na crise → média (alta na coleta, baixa na crise).'),
    ('Alçada de parceria',
     'Aprovado por você (13:51 de 03/10/2026)',
     'Relações decide parceria sem exclusividade, com remuneração na regra dos sócios, marca pelo pacote, prazo até o fim do ciclo estratégico e sem obrigação além do orçamento do círculo; fora disso, os sócios.'),
    ('Cadências e conteúdos validados; gates de implantação',
     'Validado por você (14:07 de 03/10/2026)',
     'Cadências de RE-01 a RE-08; critério de oportunidade qualificada (quatro condições), regra de saúde do cliente (três sinais) e critério de crise (quatro gatilhos). O que depende de dado real ficou nos gates G1 a G9.'),
]

# ------------------- propostas de mudança em círculos já fechados (as três foram aplicadas no fechamento)
PROPOSTAS = []

ALERTAS = [
    ('Negócios (círculo 5)', 'Relações espera de Negócios: o aceite ou a devolução de cada oportunidade com o motivo e no prazo combinado, a tabela de preços para as ações, o contrato de cliente assinado com o escopo vendido e o vencimento e o resultado de cada renovação. Entrega o critério combinado, a oportunidade qualificada e a oportunidade de renovação ou de expansão.'),
    ('Integração (círculo 6)', 'Relações espera o plano de implantação de cada cliente, o plano de lançamento de cada oferta, o plano de saída de clientes e contratos e os sistemas e canais que as ações e os padrões de experiência pedem.'),
    ('Operações (círculo 7)', 'Relações espera as reclamações e os incidentes de clientes com a causa e os registros de entrega e atendimento de cada cliente. Entrega a estratégia de experiência e os planos de sucesso e de recuperação.'),
    ('Gestão (círculo 8)', 'Relações espera o orçamento de demanda do ciclo e a situação de faturas e pagamentos de cada cliente.'),
    ('Governança (círculo 9)', 'Relações espera as regras de dados pessoais, os pedidos dos titulares com a resposta decidida, as alçadas, a decisão dos sócios sobre a parceria acima da alçada, o comitê de crise da Governança (o dono da crise, executivo, Administrador do IMTS.OS ou sócios, declara, decide a posição e encerra a crise; GO-08) e os contratos de parceria. Entrega os pedidos cumpridos, as autorizações de uso da marca com prazo, o alerta de crise e as lições da crise.'),
]

# ------------------------------------------------ relação com o catálogo da rodada 2
MUDANCAS = [
    ('Ajustado', 'V2 · Do mercado à oportunidade', 'RE-01, RE-02 e RE-03',
     'Dividida em planejar a demanda, executar as ações e qualificar os contatos. A oportunidade qualificada passa a Negócios, que pode devolvê-la com o motivo.'),
    ('Ajustado', 'V7 · Do resultado à renovação', 'RE-05',
     'Vira acompanhamento do sucesso de cada cliente. A renovação e a expansão comerciais ficam com Negócios; a lição da perda vai à Inteligência.'),
    ('Ajustado', 'C4 · Do contato à parceria ativa', 'RE-06',
     'Mantida em Relações, com o contrato na Governança, a parceria acima da alçada com os sócios e a que muda o portfólio como aposta no portão de entrada da Estratégia.'),
    ('Ajustado', 'I-RE1 · Da pauta ao conteúdo publicado', 'RE-07',
     'Passa a ser a comunicação externa inteira: pauta, conteúdo, aprovação, porta-vozes, imprensa e medição do efeito.'),
    ('Ajustado', 'I-RE2 · Do contato ao relacionamento registrado', 'RE-03',
     'O registro com a base legal, a higiene da base e os pedidos dos titulares entram na jornada de contatos.'),
    ('Acrescentado', 'Transferida do círculo 1: antiga ID-09, comunicação externa', 'RE-07',
     'A comunicação interna ficou na Gestão; a externa, em Relações, como você decidiu às 12:29.'),
    ('Acrescentado', 'Transferida do círculo 1: antiga ID-10, reputação e crise', 'RE-08',
     'Relações monitora e comunica; o comitê da Governança, com o executivo, decide a posição, como você aprovou às 12:59.'),
    ('Acrescentado', 'Transferida do círculo 1: antiga ID-04, uso da marca por terceiros', 'RE-06, etapa 5',
     'O material de marca é produzido por quem usa (RE-02); o uso por terceiros é decidido por Relações, com a Governança, como você aprovou às 12:59.'),
    ('Acrescentado', 'Decisão de 01/10/2026, às 15:48: a estratégia de experiência do cliente é de Relações', 'RE-04',
     'Jornada nova, com Operações, Negócios e Integração conferindo se conseguem cumprir os padrões.'),
    ('Acrescentado', 'Sem equivalente', 'Raias e partes “Cliente”, “Parceiro” e “Públicos externos”',
     'Papéis novos no vocabulário do modelo, para as tarefas feitas por clientes e parceiros e para o que é publicado fora. Os círculos fechados não mudam.'),
    ('Acrescentado', 'Propostas aos círculos 2 e 3, aceitas às 19:05', 'RE-02, RE-03, RE-04, RE-05 e RE-06',
     'O outro lado das trocas aplicadas na IN-03, na IN-07 e na ES-04: o funil, a base de relacionamento e o resultado das ações vão à Inteligência; a estratégia de experiência também; a RE-05 desfaz a transição quando a oferta não é encerrada; a RE-06 formaliza a parceria aprovada no portão ou responde ao parceiro quando ela não é aprovada.'),
]

LIMITES = [
    'Os fluxos são descritivos. Para executar falta escolher o motor e ligar cada tarefa a um sistema.',
    'Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado.',
    'As cadências foram validadas em 03/10/2026 (aba Parâmetros em aberto); o líder do círculo ajusta na implantação e a calibração com dados é o gate G9.',
    'Os rascunhos de critério de oportunidade qualificada, regra de saúde do cliente e critério de crise foram validados em 03/10/2026 (aba Gates de implantação); o texto final é o gate G8, e os números que dependem de dado real ficam nos gates G3 e G9.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024. Da ISO 44001 e da ISO 22361 lemos só o resumo; o texto dos Barcelona Principles 3.0 foi lido numa transcrição da MEPRA, porque a página da AMEC só os oferece em anexos.',
    'Onde faltava o outro lado, as três propostas aos círculos 2 e 3 foram aceitas e aplicadas às 19:05. Com os nove círculos fechados (03/10/2026), as trocas com os outros oito foram conferidas dos dois lados pelo nome: 410 trocas, sem problema.',
    'A tarefa de quem não é do círculo (cliente, parceiro, executivo, outro círculo) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As aprovações e conferências sem decisão desenhada não têm ramo de recusa: a recusa devolve o trabalho a quem preparou.',
    'Programa de fidelidade e lobby não estão desenhados: nenhum círculo pediu.',
    'As autorizações de uso da marca têm prazo registrado, mas o vencimento não tem vigia desenhada: só a marca retirada de uso revoga as autorizações.',
    'Quando Relações indica clientes para conversar e para o piloto (IN-07), usa a base de relacionamento da RE-03; o detalhe dessa tarefa fica no círculo 3.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das oito jornadas e apontou 30 achados, 6 graves. Todos foram tratados na segunda versão.',
    'Um verificador independente reabriu as 8 fontes do círculo: 5 confirmadas e 3 confirmadas em parte. As correções de texto foram aplicadas.',
    'Um segundo revisor leu a segunda versão: 17 achados resolvidos, 9 em parte, nenhum grave, e 8 defeitos médios novos. Os 8 foram tratados: 7 no fluxo e 1 como proposta à ES-04, aceita e aplicada no fechamento.',
    'Um terceiro revisor conferiu esses 8 e deu 6 por resolvidos e 2 em parte. Apontou 5 defeitos novos, 1 grave: a exceção ao uso da marca estava com a Identidade, contra o círculo 1, que a dá a Relações com a Governança. Os 5 foram corrigidos e passaram por todos os testes automáticos, mas não por nova revisão independente.',
    'No fechamento, às 19:05, um quarto revisor conferiu as três trocas aplicadas nos círculos 2 e 3 e os textos de fechamento. Apontou 6 defeitos, nenhum grave: a parceria não aprovada no portão e a oferta posta em espera não voltavam a Relações, e a base de relacionamento tinha ficado fora da IN-03. Os 6 foram corrigidos e passaram por todos os testes automáticos.',
]
