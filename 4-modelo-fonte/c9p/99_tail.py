
# -------------------------------------------------------------- domínios
DOMINIOS = [
    ('Regras e decisões', 'Regras, políticas e alçadas de pessoas e agentes e a secretaria das decisões dos sócios.'),
    ('Riscos e conformidade', 'Riscos, controles internos, conformidade e obrigações legais em dia.'),
    ('Contratos e auditoria', 'Revisão, guarda e acompanhamento dos contratos e auditoria das entregas de pessoas e agentes.'),
    ('Dados, crises e relatos', 'Titulares de dados, comitê de crise, canal de relatos, comunicação às autoridades e relato de impacto.'),
]

ONDAS = {
    1: 'O que os círculos fechados já esperam da Governança: regras, decisões dos sócios, riscos, obrigações, contratos, auditoria, titulares, crise e relatos',
    2: 'O que presta contas para fora sem ser pedido por outro círculo: o relato anual de impacto',
}

# ------------------------------------------------- o que usamos de cada fonte
USO = {
    'apqc': 'PCF 7.4. Os processos da Governança estão na categoria 11.0 (risco, conformidade, remediação e resiliência), base da GO-03, da GO-04, da GO-06 (auditoria interna, 11.2.1.3), da GO-07 e da GO-09; nos grupos 12.3 (relação com o conselho, aqui os sócios) e 12.4 (questões legais e éticas), base da GO-01, da GO-02, da GO-04 e da GO-05; no grupo 9.8 (controles internos), base da GO-03; e no elemento 13.9.2.3 (relato de sustentabilidade), base da GO-10. O PCF não tem elemento próprio de comitê de crise: a GO-08 usa o 11.4.5 (compartilhar o conhecimento de riscos) nas lições. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.',
    'lgpd': 'Na GO-01: as regras de sigilo e de dados pessoais seguem os princípios de finalidade, adequação e necessidade (art. 6º, I a III), e as de guarda e eliminação seguem o término do tratamento e a eliminação dos dados (arts. 15 e 16). Na GO-07: o titular tem direito a obter do controlador o que a lei lista (art. 18); a declaração completa sobre os dados é fornecida em até quinze dias do requerimento (art. 19, II); o controlador indica o encarregado (art. 41), que aceita reclamações e comunicações dos titulares e recebe as da autoridade nacional (art. 41, § 2º, I e II); aqui, o papel de encarregado fica na Governança. Na GO-09: o incidente de segurança que possa acarretar risco ou dano relevante aos titulares é comunicado à autoridade nacional e ao titular (art. 48).',
    'bpmn': 'Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, serviço e script; a tarefa de outro círculo ou papel aparece como tarefa simples.',
    'camunda': 'Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.',
    'sipoc': 'Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.',
    'anpd15': 'Na GO-09: o incidente que pode acarretar risco ou dano relevante é o que pode afetar significativamente interesses e direitos fundamentais dos titulares e, ao mesmo tempo, envolve ao menos um destes critérios: dados sensíveis; de crianças, adolescentes ou idosos; financeiros; de autenticação; protegidos por sigilo; ou em larga escala (art. 5º). A comunicação à autoridade e ao titular é feita em três dias úteis contados do conhecimento de que o incidente afetou dados pessoais (arts. 6º e 9º); o agente de pequeno porte conta os prazos em dobro (art. 6º, § 8º, e art. 9º, § 6º); as informações podem ser complementadas em vinte dias úteis (art. 6º, § 3º); o registro do incidente, comunicado ou não, é guardado por no mínimo cinco anos (art. 10).',
    'cc2002': 'Na GO-05: contratos civis e empresariais presumem-se paritários e simétricos; a alocação de riscos definida pelas partes deve ser respeitada; a revisão contratual é excepcional e limitada (art. 421-A); os contratantes guardam probidade e boa-fé (art. 422). Base da revisão de cláusula fora do modelo e do risco do contrato.',
}

# ----------------------------------- cobertura do referencial (APQC PCF 7.4)
COBERTURA = [
    ('9.8.1', 'Establish internal controls, policies, and procedures', 'GO-01 (regras e alçadas) e GO-03'),
    ('9.8.2', 'Operate controls and monitor compliance with internal controls policies and procedures', 'GO-03, etapa 2'),
    ('9.8.3', 'Report on internal controls compliance', 'GO-03, etapa 3'),
    ('11.1', 'Manage enterprise risk', 'GO-03, etapa 1'),
    ('11.2.1', 'Establish compliance framework and policies', 'GO-01; a auditoria interna (11.2.1.3, Manage internal audits) é a GO-06'),
    ('11.2.2', 'Manage regulatory compliance', 'GO-03, etapa 2, e GO-04'),
    ('11.3', 'Manage remediation efforts', 'GO-03, etapa 2 (plano de remediação) e GO-09, etapa 2'),
    ('11.4', 'Manage business resiliency', 'Em parte: as lições da crise são levadas à conformidade e à Identidade (GO-08), como pede o 11.4.5. A estratégia de resiliência (11.4.1) e a continuidade dos negócios (11.4.2 a 11.4.4) não têm etapa própria: ficam como limite'),
    ('12.1', 'Build investor relationships', 'Fora: no Ecossistema, os investidores são os sócios (GO-02); credores e analistas não foram desenhados'),
    ('12.2', 'Manage government and industry relationships', 'Fora: relações institucionais são de Relações (RE-06)'),
    ('12.3', 'Manage relations with board of directors', 'GO-02, com os sócios no papel do conselho; relatório de riscos (GO-03) e de auditoria (GO-06). O resultado financeiro (12.3.1) vai aos sócios pela Estratégia, a partir da Gestão (GE-05)'),
    ('12.4.1', 'Create ethics policies', 'GO-01'),
    ('12.4.2', 'Manage corporate governance policies', 'GO-01 e GO-02'),
    ('12.4.3', 'Develop and perform preventive law programs', 'Em parte: a revisão de contratos (GO-05) e das regras (GO-01)'),
    ('12.4.4', 'Ensure compliance', 'GO-03'),
    ('12.4.5', 'Manage outside counsel', 'Limite: a assessoria externa não tem etapa própria'),
    ('12.4.6', 'Protect intellectual property', 'GO-04 (registro de marcas) e tarefas da Governança na IN-06 e na IN-07'),
    ('12.4.7', 'Resolve disputes and litigations', 'Limite: litígios não foram desenhados'),
    ('12.4.8', 'Provide legal advice/counseling', 'Tarefas da Governança nas jornadas dos outros círculos'),
    ('12.4.9', 'Negotiate and document agreements/contracts', 'GO-05; a frente dona negocia'),
    ('12.5', 'Manage public relations program', 'Fora: Relações (RE-07)'),
    ('13.9.2.3', 'Perform sustainability reporting', 'GO-10, como relato anual de impacto'),
]

# --------------------------------------------------- o que a Governança não faz
FRONTEIRAS = [
    ('Escolher o rumo e decidir as matérias dos sócios', 'Sócios e Estratégia',
     'O relatório de riscos e conformidade (GO-03) e a situação do cumprimento das decisões (GO-02). A Governança leva as matérias à decisão dos sócios como tarefa nas jornadas dos outros círculos.'),
    ('Executar a rotina e corrigir', 'Os círculos donos',
     'As regras e alçadas vigentes e as regras de sigilo e de dados pessoais, a todos (GO-01); o plano de remediação (GO-03), a correção pedida ao dono da entrega (GO-06) e o aviso de vencimento de contrato (GO-05).'),
    ('Definir os padrões, os critérios de auditoria, o protocolo de crise e a marca', 'Identidade',
     'O resultado da auditoria e o padrão ambíguo (GO-06) e as lições da crise (GO-08). O registro e a baixa da marca são da Governança (GO-04).'),
    ('Monitorar a reputação e comunicar na crise', 'Relações',
     'A declaração, a posição e o encerramento da crise (GO-08) e a resposta decidida ao titular de dados (GO-07).'),
    ('Originar e negociar contratos', 'A frente dona de cada contrato',
     'A revisão, a guarda e o acompanhamento (GO-05). As tarefas de revisar, conferir poderes e guardar que a Governança já faz nas jornadas donas (NE-04, NE-05, NE-06, RE-06, IT-07, GE-04 e ES-05) entram na GO-05 como contrato já revisado e assinado, só para guarda e acompanhamento. Os modelos de proposta e de contrato e as certidões vão a Negócios (GO-01 e GO-04).'),
    ('Comunicar o recall à autoridade', 'Governança, como tarefa na OP-07',
     'A comunicação do risco do produto e os relatórios do recall são feitos pela Governança dentro da OP-07; a GO-09 só os registra e leva a causa à conformidade.'),
    ('Registrar o ato societário do mandato', 'Governança, como tarefa na ES-05, etapa 7',
     'A GO-02 registra só a alteração societária que não vem de um mandato.'),
    ('Corrigir o agente', 'Integração', 'O desvio de agente apontado pela auditoria (GO-06), que a IT-06 trata.'),
    ('Avaliar o método pelo resultado', 'Inteligência', 'A amostra única de entregas e o resultado da auditoria (GO-06); as regras de guarda e de eliminação (GO-01).'),
    ('Aplicar o rateio e executar aportes', 'Gestão', 'O critério de rateio (GO-01).'),
]

# -------------------------------------------------------- pontos para decidir
PONTOS = []
DECISOES = [
    ('A Governança decide o seu ofício dentro da alçada; os sócios decidem as regras gerais e as alçadas dos executivos',
     'Ponto 1, aprovado por você (11:50 de 03/10/2026)',
     'GO-01, etapa 2. Mesma regra dos outros círculos. O critério de rateio é definido pela Governança com a Estratégia, como a fronteira do círculo 2 diz; a Gestão aplica.'),
    ('Uma amostra única de entregas serve à auditoria e à avaliação dos métodos',
     'Ponto 2, aprovado por você (11:50)',
     'GO-06, etapa 1: a mesma amostra vai à Inteligência (IN-06, etapa 5). Encaminha o alerta do círculo 3: quem sorteia e para onde vai está definido; os estratos (inclusive as entregas com método publicado) e o tamanho ficam em aberto.'),
    ('O comitê de crise é conduzido pela Governança, com o executivo',
     'Ponto 3, aprovado por você (11:50)',
     'GO-08, como a transferência do círculo 1 e a RE-08 já diziam: Relações monitora e comunica; a Governança propõe e o executivo aprova a declaração, a posição e o encerramento; a Identidade tem assento no comitê.'),
    ('O papel de encarregado de dados pessoais fica na Governança',
     'Ponto 4, aprovado por você (11:50)',
     'GO-07: a Governança decide a resposta ao titular; Relações executa na base de relacionamento (RE-03) e quem guarda o dado executa o resto.'),
    ('O relato sobre o executivo é decidido com os sócios',
     'Ponto 5, aprovado por você (11:50)',
     'GO-09, etapa 2: a medida é decidida com o executivo; se ele, a Governança ou um sócio estiver envolvido, decidem os sócios não envolvidos.'),
    ('As auditorias de identidade e de agentes viram uma só',
     'Ponto 6, aprovado por você (11:50)',
     'GO-06 junta a ID-11 transferida e a I-GO3, com a causa encaminhada a quem corrige. A Identidade julga os casos de fronteira, como decidido no fechamento do círculo 1.'),
    ('Dez jornadas', 'Ponto 7, aprovado por você (11:50)', 'GO-01 a GO-10.'),
    ('A IT-06 recebe da Governança o desvio de agente apontado pela auditoria', 'Proposta ao círculo 6, aprovada por você (11:50)',
     'IT-06, etapa 4.'),
    ('Auditoria de execução: modo de cada etapa e nível de automação pelo que as tarefas fazem',
     'Itens 1 a 14 da auditoria, aprovados por você (12:33 de 03/10/2026)',
     'GO-05 etapa 1: a decisão sobre cláusula fora do modelo ou risco relevante passa à pessoa da Governança; o agente aponta as diferenças (item 9). De Autopiloto para Autômato, pelas tarefas: GO-01 etapa 3, GO-05 etapa 2, GO-06 etapa 1, GO-07 etapa 3, GO-09 etapa 4. Nível de automação pela faixa: GO-03 média → alta; GO-06 média → alta; GO-07 média → alta; GO-08 baixa → média; GO-09 baixa → média.'),
    ('O apetite a risco é dos sócios; prazo de comunicação de incidente lido',
     'Decidido e pedido por você (13:09 de 03/10/2026)',
     'GO-03: a Governança mantém a matriz de riscos; os sócios decidem o apetite a risco. GO-09: três dias úteis para comunicar a autoridade e o titular (Resolução CD/ANPD nº 15/2024, arts. 6º e 9º), em dobro para o agente de pequeno porte (art. 6º, § 8º), conferida na ANPD e na reprodução do DOU. GO-05: Código Civil, arts. 421-A e 422.'),
    ('O que a Governança decide sozinha e as regras gerais dos contratos',
     'Aprovado por você (13:51 de 03/10/2026)',
     'A Governança decide sozinha as regras que aplicam regra geral aprovada, os modelos de proposta e contrato, sigilo, dados e guarda, a alçada de pessoas no círculo e de agentes no critério, a matriz de riscos dentro do apetite dos sócios, o rateio com a Estratégia e a amostra. Vão aos sócios as alçadas dos executivos, as regras gerais, as exceções e a alçada da própria Governança. Regras gerais dos contratos: modelo obrigatório; assina o executivo; alocação de riscos escrita (Código Civil, art. 421-A); garantia escrita; papéis de dados e aviso de incidente a tempo dos três dias úteis; reajuste anual por índice escrito (recomendado o IPCA); exclusividade, prazo longo, multa acima do modelo, foro e garantia financeira vão aos sócios; contrato público usa a minuta do edital.'),
    ('Cadências e conteúdos validados; gates de implantação',
     'Validado por você (14:07 de 03/10/2026)',
     'GO-01 anual; GO-02 e GO-03 trimestrais; GO-06 trimestral; matriz de riscos 5 por 5, desenho da amostra e regras de sigilo, dados e guarda. O que depende de dado real ficou nos gates G1 a G9.'),
    ('Correções da auditoria geral',
     'Aprovado por você (16:05 de 03/10/2026)',
     'GO-01: quem decide sai da lista de matérias, por regra; a alçada das pessoas da Governança e os limites dos agentes vão aos sócios (M2). GO-03: risco de nota 15 ou mais vai aos sócios; a remediação volta com evidência (M1, M8). GO-05: matéria da regra 10 dos contratos vai aos sócios; vencimento sem decisão do dono volta com a decisão do executivo (M1, M8). GO-06: pessoa revê amostra dos conformes do agente; correções voltam; auditoria externa anual da própria Governança, com as correções decididas pelos sócios (M3, M8). GO-07: a execução do pedido do titular volta confirmada (M8). GO-08: dono único da crise: o executivo, o Administrador do IMTS.OS ou os sócios (M4). GO-09: relato que cita a Governança vai à assessoria externa, e os sócios decidem a medida (D4). GO-02: a devolução de matéria é decidida por pessoa (L9). Tabela matéria × órgão (D1).'),
]

PROPOSTAS = []

ALERTAS = []

# ------------------------------------------------ relação com o catálogo da rodada 2
MUDANCAS = [
    ('Acrescentado', 'Sem equivalente', 'GO-01',
     'Regras, políticas e alçadas de pessoas e agentes, pedidas por todos os círculos.'),
    ('Ajustado', 'I-GO1 · Da pauta à decisão registrada', 'GO-02',
     'Ganha os atos societários e o acompanhamento do cumprimento.'),
    ('Ajustado', 'C9 · Do risco ao controle', 'GO-03',
     'Ganha os testes de controle, a remediação e o relatório aos sócios e à Estratégia.'),
    ('Ajustado', 'I-GO2 · Do prazo legal à obrigação cumprida', 'GO-04',
     'Ganha o registro e a baixa de marcas e as certidões de habilitação para Negócios.'),
    ('Ajustado', 'C13 · Da minuta ao contrato encerrado', 'GO-05',
     'A frente dona origina e negocia; a Governança revisa, guarda e acompanha.'),
    ('Ajustado', 'I-GO3 · Da decisão do agente à auditoria e ID-11 do círculo 1 (transferida)', 'GO-06',
     'Juntas numa auditoria com amostra única, que serve também à Inteligência.'),
    ('Acrescentado', 'Sem equivalente', 'GO-07',
     'Resposta aos titulares de dados, pedida por Relações (RE-03).'),
    ('Ajustado', 'ID-10 do círculo 1 (transferida), parte da resposta à crise', 'GO-08',
     'O comitê de crise; o monitoramento e a comunicação ficaram em Relações (RE-08).'),
    ('Ajustado', 'I-GO4 · Do relato ao tratamento', 'GO-09',
     'Ganha a comunicação às autoridades, pedida por Operações (OP-04 e OP-07) e pelo incidente com dados pessoais.'),
    ('Ajustado', 'ID-13 do círculo 1 (transferida) · Relato anual de impacto', 'GO-10',
     'Rascunho da Identidade assumido pela Governança, com a aprovação dos sócios.'),
]

LIMITES = [
    'Os fluxos rodam no motor próprio sobre o Supabase, por enquanto em simulação (piloto: Identidade). Falta trocar os adaptadores simulados pelos sistemas reais.',
    'Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado. Os únicos prazos citados são os da LGPD e da Resolução CD/ANPD nº 15/2024, com a fonte.',
    'As cadências foram validadas em 03/10/2026 (aba Parâmetros em aberto); o líder do círculo ajusta na implantação e a calibração com dados é o gate G9.',
    'As alçadas, o que a Governança decide sozinha e as regras gerais dos contratos foram aprovados em 03/10/2026 (abas Parâmetros em aberto e Propostas de parâmetros). Os rascunhos da matriz de riscos, do critério de rateio, da amostra e das regras de sigilo e guarda foram validados em 03/10/2026; o texto final é o gate G8, e o tamanho da amostra, o G9.',
    'Continuidade dos negócios (APQC 11.4.2 a 11.4.4), assessoria externa (12.4.5) e litígios (12.4.7) não têm etapa própria.',
    'Da LGPD foram conferidos os arts. 6º, 15, 16, 18, 19, 41 e 48 citados. O prazo de comunicação de incidente (três dias úteis, Resolução CD/ANPD nº 15/2024) foi conferido em 03/10/2026 na página oficial da ANPD e na reprodução do DOU (26/04/2024, edição 81, seção 1, p. 114); gate G5 cumprido. O Código Civil citado na GO-05 foi conferido no texto oficial.',
    'Cada empresa do Ecossistema é um controlador e indica o seu encarregado; o modelo põe o papel de encarregado na Governança, sem desenhar a indicação nem a divulgação.',
    'O desenho da amostra (estratos e tamanho) tem rascunho validado em 03/10/2026 (aba Gates de implantação, item 2.13); o texto final é o gate G8 e os números, o G9.',
    'O referencial de processos é o APQC PCF 7.4, de agosto de 2024.',
    'As trocas com os oito círculos já fechados foram conferidas dos dois lados pelo nome.',
    'A tarefa de quem não é do círculo (sócios, executivo, Relações) está desenhada como participação; o detalhe dela fica no círculo dono.',
    'As saídas estão listadas por etapa, não por caminho.',
    'Os números descrevem este desenho, não a operação atual.',
]

REVISAO_TXT = [
    'Um revisor independente (agente que não participou do desenho) leu a primeira versão das dez jornadas, conferiu os 21 códigos e nomes do APQC PCF 7.4 (todos conferem) e as citações da LGPD no Planalto (corretas), e apontou 24 achados, 3 graves: a Governança julgando sozinha os casos de fronteira que o círculo 1 deu à Identidade, a revisão repetida de contratos já revisados nas jornadas donas e o indeferimento de obrigação legal seguindo como se estivesse cumprida.',
    'Todos foram corrigidos ou declarados como limite. A versão corrigida passou por todos os testes automáticos e não passou por nova revisão independente.',
]
