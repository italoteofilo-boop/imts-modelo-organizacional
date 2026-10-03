# -*- coding: utf-8 -*-
"""Referências conferidas. ref: a referência; conf: o que foi lido de fato; links.
O uso de cada fonte é declarado por círculo (USO)."""

FONTES_BASE = {'apqc': {'ref': 'APQC, Process Classification Framework (PCF), cross-industry',
          'conf': 'PDF da versão 7.4 (agosto de 2024) aberto em dois endereços e lido por inteiro em 01/10/2026, por extração do texto das 35 páginas, '
                  'que cobrem as 13 categorias. Conferidos um a um os elementos das categorias 1, 3 e 7 (por mim e por um revisor independente) e os da '
                  'categoria 2 e dos grupos 8.4, 12.4, 12.5, 13.5, 13.6 e 13.7 (por mim e por um segundo revisor, no desenho do círculo 3). Em 03/10/2026, os elementos citados das categorias 4, 5, 6, 7, 9, 10, 11 e 12 e o 13.9.2.3 (por mim e por um revisor independente em cada um dos círculos 7, 8 e 9). Também em 03/10/2026, os 18 elementos das categorias 8 e 13 citados no círculo 6, conferidos código e nome contra o texto do PDF 7.4, e os grupos de nível 2 das categorias 8 e 13, conferidos por um revisor independente no mesmo PDF. A versão '
                  '8.0 (27/02/2026) foi conferida só nas 13 categorias, na página da coleção de definições da APQC.',
          'links': [('PCF 7.4 (PDF, cópia 1)',
                     'https://www.business-analysis.com.au/wp-content/uploads/2025/04/K014750_APQC-Process-Classification-Framework-PCF-Cross-Industry-PDF-Version-7.4_January-2025.pdf'),
                    ('PCF 7.4 (PDF, cópia 2)',
                     'https://solutions.ifrc.org/sites/default/files/2024-10/K014750_APQC%20Process%20Classification%20Framework%20(PCF)%20-%20Cross%20Industry%20-%20PDF%20Version%207.4.pdf'),
                    ('PCF 8.0 (página oficial)',
                     'https://www.apqc.org/resource-library/resource-listing/apqc-process-classification-framework-pcf-cross-industry-excel-12'),
                    ('PCF 8.0, 13 categorias',
                     'https://www.apqc.org/resource-library/resource-collection/pcf-version-80-process-definitions-and-key-measures-collection')]},
 'collins': {'ref': 'Jim Collins e Jerry Porras, Building Your Company’s Vision, Harvard Business Review, set.–out. 1996',
             'conf': 'Página oficial do artigo aberta; o texto completo é pago, a definição citada está visível.',
             'links': [('hbr.org', 'https://hbr.org/1996/09/building-your-companys-vision')]},
 'iso37000': {'ref': 'ISO 37000:2021, Governance of organizations — Guidance',
              'conf': 'Página do comitê ISO/TC 309 aberta; a norma completa é paga e não foi lida.',
              'links': [('committee.iso.org', 'https://committee.iso.org/ISO_37000_Governance')]},
 'pas808': {'ref': 'BSI, PAS 808:2022, Purpose-driven organizations. Worldviews, principles and behaviours for delivering sustainability. Guide',
            'conf': 'Página oficial da BSI aberta (publicada em 30/07/2022); o texto completo é pago e não foi lido.',
            'links': [('knowledge.bsigroup.com',
                       'https://knowledge.bsigroup.com/products/purpose-driven-organizations-worldviews-principles-and-behaviours-for-delivering-sustainability-guide')]},
 'quinn': {'ref': 'Robert Quinn e Anjan Thakor, Creating a Purpose-Driven Organization, Harvard Business Review, jul.–ago. 2018',
           'conf': 'Página oficial aberta (título, autores e data); os oito passos foram conferidos em cópia do artigo hospedada pela FAO.',
           'links': [('hbr.org', 'https://hbr.org/2018/07/creating-a-purpose-driven-organization'),
                     ('cópia (FAO)', 'https://www.fao.org/fileadmin/templates/library/pdf/Harvard_Business_Review.pdf')]},
 'hatch': {'ref': 'Mary Jo Hatch e Majken Schultz, Are the Strategic Stars Aligned for Your Corporate Brand?, Harvard Business Review, fev. 2001, v. 79, n. 2, '
                  'p. 129–134',
           'conf': 'Página oficial aberta (texto pago); o resumo com as três lacunas foi conferido no registro da Copenhagen Business School.',
           'links': [('hbr.org', 'https://hbr.org/2001/02/are-the-strategic-stars-aligned-for-your-corporate-brand'),
                     ('registro CBS', 'https://research.cbs.dk/en/publications/are-the-strategic-stars-aligned-for-your-corporate-brand/')]},
 'aaker': {'ref': 'David Aaker e Erich Joachimsthaler, The Brand Relationship Spectrum, California Management Review, v. 42, n. 4, 2000',
           'conf': 'Registro do artigo aberto na Case Centre; estratégias e perguntas conferidas em cópia do artigo hospedada por terceiro. As páginas não são '
                   'citadas: a cópia mostra 8–22 e há citação como 8–23.',
           'links': [('The Case Centre', 'https://www.thecasecentre.org/products/view?id=5390'),
                     ('cópia do artigo', 'https://ngovietliem.com/wp-content/uploads/2022/12/Reading-4.2-Brand-relationship-spectrum.pdf')]},
 'wheeler': {'ref': 'Alina Wheeler, Designing Brand Identity',
             'conf': 'As cinco fases foram conferidas em entrevista da autora; o livro não foi lido.',
             'links': [('entrevista (Logo Geek)', 'https://logogeek.uk/podcast/design-a-brand-identity-with-alina-wheeler/')]},
 'inpi': {'ref': 'INPI, serviço de prorrogação de registro de marca (gov.br)',
          'conf': 'Página oficial do serviço aberta. O artigo da Lei 9.279/1996 não foi conferido no texto da lei.',
          'links': [('gov.br', 'https://www.gov.br/pt-br/servicos/solicitar-a-prorrogacao-de-registro-de-marca-e-expedicao-de-certificado-de-registro')]},
 'iso20671': {'ref': 'ISO 20671-1:2021, Brand evaluation — Part 1: Principles and fundamentals',
              'conf': 'Página oficial da ISO aberta (resumo); a norma completa é paga e não foi lida.',
              'links': [('iso.org', 'https://www.iso.org/standard/81739.html')]},
 'iso10010': {'ref': 'ISO 10010:2022, Quality management — Guidance to understand, evaluate and improve organizational quality culture',
              'conf': 'Página oficial da ISO aberta (resumo); a norma completa é paga e não foi lida. O foco da norma é cultura de qualidade; usamos a '
                      'sequência entender, avaliar e melhorar, que está no título, não o conteúdo.',
              'links': [('iso.org', 'https://www.iso.org/standard/38457.html')]},
 'mckinsey': {'ref': 'Tessa Basford e Bill Schaninger, The four building blocks of change, McKinsey, 11/04/2016',
              'conf': 'Artigo aberto no site da McKinsey.',
              'links': [('mckinsey.com',
                         'https://www.mckinsey.com/capabilities/people-and-organizational-performance/our-insights/the-four-building-blocks--of-change')]},
 'schein': {'ref': 'Edgar Schein, modelo de cultura organizacional em três níveis',
            'conf': 'Fonte secundária: verbete da Wikipédia. O livro não foi lido.',
            'links': [('Wikipédia', 'https://en.wikipedia.org/wiki/Edgar_Schein')]},
 'craig': {'ref': 'Nick Craig e Scott Snook, From Purpose to Impact, Harvard Business Review, v. 92, n. 5, maio de 2014',
           'conf': 'Registro do artigo aberto no site da Harvard Business School e página do artigo na HBR (resumo); o texto completo não foi lido. As páginas '
                   'não são citadas: os registros divergem entre 104–111 e 105–111.',
           'links': [('hbs.edu', 'https://www.hbs.edu/faculty/Pages/item.aspx?num=47372'), ('hbr.org', 'https://hbr.org/2014/05/from-purpose-to-impact')]},
 'reptrak': {'ref': 'RepTrak, Global RepTrak 100 (2026)',
             'conf': 'Página oficial aberta.',
             'links': [('reptrak.com', 'https://www.reptrak.com/globalreptrak/')]},
 'iso22361': {'ref': 'ISO 22361:2022, Security and resilience — Crisis management — Guidelines',
              'conf': 'Página oficial da ISO aberta (resumo); a norma completa é paga e não foi lida.',
              'links': [('iso.org', 'https://www.iso.org/standard/50267.html')]},
 'nng': {'ref': 'Kate Moran, The Four Dimensions of Tone of Voice, Nielsen Norman Group, 17/07/2016',
         'conf': 'Artigo aberto no site da NN/g.',
         'links': [('nngroup.com', 'https://www.nngroup.com/articles/tone-of-voice-dimensions/')]},
 'google_persona': {'ref': 'Google, Conversation Design: Create a persona',
                    'conf': 'Página oficial aberta. A plataforma a que o guia se refere foi descontinuada em 13/06/2023; o método de persona continua '
                            'aplicável.',
                    'links': [('developers.google.com', 'https://developers.google.com/assistant/conversation-design/create-a-persona')]},
 'impact': {'ref': 'Impact Frontiers, Five Dimensions of Impact (Impact Management Norms)',
            'conf': 'Página oficial aberta.',
            'links': [('impactfrontiers.org', 'https://impactfrontiers.org/norms/five-dimensions-of-impact/')]},
 'bpmn': {'ref': 'OMG, Business Process Model and Notation (BPMN) 2.0.2; ISO/IEC 19510:2013',
          'conf': 'Páginas oficiais da OMG e da ISO abertas; a lista de tipos de tarefa foi conferida no BPMN Quick Guide; a atividade de chamada foi aceita '
                  'pelo metamodelo usado nos testes. A especificação completa não foi lida.',
          'links': [('omg.org', 'https://www.omg.org/spec/BPMN/2.0.2/About-BPMN'),
                    ('iso.org', 'https://www.iso.org/standard/62652.html'),
                    ('BPMN Quick Guide', 'https://www.bpmnquickguide.com/quickguide/bpmn-quick-guide/tasks')]},
 'camunda': {'ref': 'Camunda, Best Practices: Naming BPMN elements',
             'conf': 'Documentação oficial aberta.',
             'links': [('docs.camunda.io', 'https://docs.camunda.io/docs/components/best-practices/modeling/naming-bpmn-elements/')]},
 'dmn': {'ref': 'OMG, Decision Model and Notation (DMN)', 'conf': 'Página oficial da OMG aberta.', 'links': [('omg.org', 'https://www.omg.org/spec/DMN')]},
 'sipoc': {'ref': 'ASQ, SIPOC+CM Diagram', 'conf': 'Página oficial da ASQ aberta.', 'links': [('asq.org', 'https://asq.org/quality-resources/sipoc')]},
 'iia': {'ref': 'The Institute of Internal Auditors, The IIA’s Three Lines Model: An Update of the Three Lines of Defense (2020; versão lida atualizada em '
                'setembro de 2024)',
         'conf': 'Documento oficial aberto no site do IIA. O modelo trata de governança e gestão de riscos; aplicá-lo à separação de papéis entre os '
                 'círculos é analogia nossa.',
         'links': [('theiia.org',
                    'https://www.theiia.org/globalassets/documents/resources/the-iias-three-lines-model-an-update-of-the-three-lines-of-defense-july-2020/three-lines-model-updated-english.pdf')]},
 'kaplan': {'ref': 'Robert Kaplan e David Norton, Mastering the Management System, Harvard Business Review, janeiro de 2008',
            'conf': 'Página oficial aberta (resumo; o texto completo é pago). Os nomes dos cinco estágios e a diferença entre reunião operacional e reunião de '
                    'estratégia foram conferidos em cópia do artigo hospedada por terceiro.',
            'links': [('hbr.org', 'https://hbr.org/2008/01/mastering-the-management-system'),
                      ('cópia do artigo', 'https://www.strimgroup.com/wp-content/uploads/pdf/KaplanNorton_HBR_MasteringTheManagementSystem.pdf')]},
 'rumelt': {'ref': 'Richard Rumelt, The perils of bad strategy, McKinsey Quarterly, 01/06/2011',
            'conf': 'Artigo aberto no site da McKinsey.',
            'links': [('mckinsey.com', 'https://www.mckinsey.com/capabilities/strategy-and-corporate-finance/our-insights/the-perils-of-bad-strategy')]},
 'okr': {'ref': 'Google re:Work, Guide: Set goals with OKRs',
         'conf': 'Guia oficial aberto.',
         'links': [('rework.withgoogle.com', 'https://rework.withgoogle.com/intl/en/guides/set-goals-with-okrs')]},
 'lei': {'ref': 'Lean Enterprise Institute, Lean Lexicon: Strategy Deployment (hoshin kanri)',
         'conf': 'Verbete oficial aberto.',
         'links': [('lean.org', 'https://www.lean.org/lexicon-terms/strategy-deployment/')]},
 'horizons': {'ref': 'McKinsey, Enduring Ideas: The three horizons of growth, McKinsey Quarterly, 01/12/2009',
              'conf': 'Artigo aberto no site da McKinsey.',
              'links': [('mckinsey.com',
                         'https://www.mckinsey.com/capabilities/strategy-and-corporate-finance/our-insights/enduring-ideas-the-three-horizons-of-growth')]},
 'parenting': {'ref': 'Andrew Campbell, Michael Goold e Marcus Alexander, Corporate Strategy: The Quest for Parenting Advantage, Harvard Business Review, '
                      'mar.–abr. 1995',
               'conf': 'Página oficial aberta; o texto completo é pago. Só as duas perguntas do trecho de abertura, visível na página, foram conferidas.',
               'links': [('hbr.org', 'https://hbr.org/1995/03/corporate-strategy-the-quest-for-parenting-advantage')]},
 'realloc': {'ref': 'Stephen Hall, Dan Lovallo e Reinier Musters, How to put your money where your strategy is, McKinsey Quarterly, março de 2012',
             'conf': 'Artigo aberto no site da McKinsey em 03/10/2026. O texto diz que o terço que mais realocou teve, em média, retorno total ao acionista 30% maior por ano que o terço que menos realocou; os valores 10,2% e 7,8% ao ano (1990 a 2005, 1.616 empresas) estão no Exhibit 2 do artigo, não no texto corrido. Os números são dos autores, sobre a amostra deles; não foram reproduzidos por nós.',
             'links': [('mckinsey.com',
                        'https://www.mckinsey.com/capabilities/strategy-and-corporate-finance/our-insights/how-to-put-your-money-where-your-strategy-is'),
                       ('PDF',
                        'https://www.mckinsey.com/~/media/McKinsey/Business%20Functions/Strategy%20and%20Corporate%20Finance/Our%20Insights/How%20to%20put%20your%20money%20where%20your%20strategy%20is/How%20to%20put%20your%20money%20where%20your%20strategy%20is.pdf')]},
 'stagegate': {'ref': 'Stage-Gate International, The Stage-Gate Model: An Overview (página do blog, com o nome de Robert G. Cooper)',
               'conf': 'Página oficial aberta. Os metadados da página indicam publicação em 15/12/2025 e outra autora; por isso a data e a autoria não '
                       'entram na referência.',
               'links': [('stage-gate.com', 'https://www.stage-gate.com/blog/the-stage-gate-model-an-overview/')]}}

# ------------------------------------------------------------- fontes acrescentadas no círculo 3
FONTES_BASE.update({
 'odni_ciclo': {'ref': 'Office of the Director of National Intelligence (ODNI), How the IC Works: the six steps in the Intelligence Cycle (intelligence.gov)',
                'conf': 'Página oficial aberta em intelligence.gov; a página não traz data. O ciclo é o da comunidade de inteligência dos Estados Unidos; '
                        'aplicá-lo à leitura de mercado é analogia nossa.',
                'links': [('intelligence.gov', 'https://www.intelligence.gov/how-the-ic-works')]},
 'herring': {'ref': 'Jan P. Herring, Key intelligence topics: A process to identify and define intelligence needs, Competitive Intelligence Review, v. 10, n. 2, p. 4–14, 1999',
             'conf': 'Resumo completo lido no registro do SciSpace; autor, volume, número e páginas conferidos no registro do Crossref. A página da editora '
                     '(Wiley) recusou o acesso, e o artigo não foi lido.',
             'links': [('registro SciSpace', 'https://scispace.com/journals/competitive-intelligence-review-1ve3qz6m/1999'),
                       ('registro Crossref', 'https://api.crossref.org/works/10.1002/(sici)1520-6386(199932)10:2%3C4::aid-cir3%3E3.0.co;2-c')]},
 'horizon': {'ref': 'Government Office for Science (Reino Unido), The Futures Toolkit, versão de 2024 (página publicada em 08/07/2014 e atualizada em 29/08/2024)',
             'conf': 'Página oficial e versão em HTML abertas no gov.uk; lida a ferramenta Horizon Scanning.',
             'links': [('gov.uk', 'https://www.gov.uk/government/publications/futures-toolkit-for-policy-makers-and-analysts'),
                       ('versão em HTML', 'https://www.gov.uk/government/publications/futures-toolkit-for-policy-makers-and-analysts/the-futures-toolkit-html')]},
 'cebma': {'ref': 'E. Barends, D. M. Rousseau e R. B. Briner, Evidence-Based Management: The Basic Principles, Center for Evidence-Based Management, Amsterdã, 2014',
           'conf': 'PDF aberto no site do CEBMa.',
           'links': [('cebma.org (PDF)', 'https://cebma.org/assets/Uploads/Evidence-Based-Practice-The-Basic-Principles.pdf')]},
 'yardstick': {'ref': 'Ministry of Defence (Reino Unido), Defence Intelligence – communicating probability, 17/02/2023',
               'conf': 'Página oficial aberta no gov.uk. O texto diz que a régua divide a escala de probabilidade em sete faixas numéricas, com termos '
                       'atribuídos a cada faixa. A página não reproduz a tabela e só cita dois termos de passagem; a lista dos termos e as faixas não '
                       'foram lidas.',
               'links': [('gov.uk', 'https://www.gov.uk/government/news/defence-intelligence-communicating-probability')]},
 'dqf': {'ref': 'Government Data Quality Hub (Reino Unido), The Government Data Quality Framework, 03/12/2020',
         'conf': 'Página oficial aberta no gov.uk.',
         'links': [('gov.uk', 'https://www.gov.uk/government/publications/the-government-data-quality-framework/the-government-data-quality-framework')]},
 'fair': {'ref': 'GO FAIR, FAIR Principles (resumo dos princípios publicados na revista Scientific Data em 2016)',
          'conf': 'PDF de resumo aberto no site da GO FAIR; o artigo de 2016 não foi lido. Os princípios foram escritos para dados de pesquisa; usá-los no '
                  'catálogo de dados é escolha nossa.',
          'links': [('go-fair.org (PDF)', 'https://www.go-fair.org/wp-content/uploads/2022/01/FAIRPrinciples_overview.pdf')]},
 'l14133': {'ref': 'Brasil, Lei nº 14.133, de 1º de abril de 2021 (Lei de Licitações e Contratos Administrativos)',
            'conf': 'Texto compilado aberto no site do Planalto em 03/10/2026 e conferidos no texto oficial: art. 6º (incisos XLV, XLVI, XLVIII e XLIX); '
                    'art. 17 (caput, incisos I a VII e §§ 1º e 2º: fases em sequência, habilitação antes do julgamento só por ato motivado e prevista no edital, '
                    'forma preferencialmente eletrônica); caput do art. 18; arts. 82 a 84 (registro de preços; ata de 1 ano, prorrogável por igual período '
                    'com preço vantajoso comprovado); art. 86 (caput e §§ 2º a 8º; o § 3º, na redação da Lei 14.770/2023, deixa órgão municipal aderir a ata '
                    'federal, estadual ou distrital e a ata municipal só se o registro de preços veio de licitação); art. 90 (prazo de convocação fixado no '
                    'edital, prorrogável uma vez); art. 140 (obras e serviços: recebimento provisório pelo fiscal e definitivo por servidor ou comissão, com '
                    'termo detalhado; compras: provisório de forma sumária e definitivo com termo detalhado; prazos no regulamento ou no contrato); art. 141 '
                    '(ordem cronológica de pagamento por fonte e categoria); art. 164 (impugnação até 3 dias úteis antes da abertura, resposta em 3 dias úteis); '
                    'art. 165 (recurso em 3 dias úteis só contra os atos das alíneas a a e do inciso I, e pedido de reconsideração em 3 dias úteis; § 1º: '
                    'intenção de recorrer imediata no julgamento e na habilitação; § 2º: a autoridade reconsidera em 3 dias úteis e a superior decide em até 10 dias úteis). '
                    'Contratação direta não foi lida.',
            'links': [('planalto.gov.br', 'https://www.planalto.gov.br/ccivil_03/_ato2019-2022/2021/lei/l14133.htm')]},
 'anpd15': {'ref': 'ANPD, Resolução CD/ANPD nº 15, de 24 de abril de 2024 (Regulamento de Comunicação de Incidente de Segurança), DOU de 26/04/2024, edição 81, seção 1, p. 114',
            'conf': 'Conferida em 03/10/2026 em três fontes concordantes: (1) a página oficial da ANPD sobre comunicação de incidente (gov.br), que dá o prazo '
                    'de três dias úteis e remete ao DOU; (2) a reprodução da publicação no DOU feita pelo Governo de Mato Grosso do Sul (cabeçalho: 26/04/2024, '
                    'edição 81, seção 1, p. 114), onde foram lidos os arts. 5º, 6º (caput e §§ 1º, 3º e 8º), 9º e 10; (3) a transcrição da LegisWeb. '
                    'Art. 6º: comunicação à ANPD em três dias úteis, contados do conhecimento de que o incidente afetou dados pessoais; complemento em vinte '
                    'dias úteis (§ 3º); prazos em dobro para o agente de pequeno porte (§ 8º, pela Resolução CD/ANPD nº 2/2022). Art. 9º: comunicação ao titular '
                    'em três dias úteis. Art. 10: registro do incidente por no mínimo cinco anos. A página do DOU (in.gov.br) recusa leitura automatizada; o '
                    'endereço dela está registrado.',
            'links': [('gov.br/anpd, comunicação de incidente', 'https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis'),
                      ('DOU (in.gov.br)', 'https://www.in.gov.br/en/web/dou/-/resolucao-cd/anpd-n-15-de-24-de-abril-de-2024-556243024'),
                      ('Reprodução do DOU, Governo de MS (PDF)', 'https://www.lgpd.ms.gov.br/wp-content/uploads/2024/05/REGULAMENTO-DE-COMUNICACAO-DE-INCIDENTE-DE-SEGURANCA-ABRIL-2024-ANPD-.pdf'),
                      ('LegisWeb (transcrição)', 'https://www.legisweb.com.br/legislacao/?id=458235')]},
 'cc2002': {'ref': 'Brasil, Lei nº 10.406, de 10 de janeiro de 2002 (Código Civil)',
            'conf': 'Texto compilado aberto no site do Planalto em 03/10/2026 e conferidos no texto oficial: arts. 389 (parágrafo único: IPCA quando o índice '
                    'não foi convencionado), 395, 421, 421-A (inciso II), 422, 441 a 446 (art. 445: 30 dias para móvel e 1 ano para imóvel; art. 446: os '
                    'prazos não correm na garantia contratual, e o defeito é denunciado em 30 dias da descoberta), 475, 1.179, 1.180 e 1.194.',
            'links': [('planalto.gov.br, Código Civil compilado', 'https://www.planalto.gov.br/ccivil_03/leis/2002/l10406compilada.htm')]},
 'clt': {'ref': 'Brasil, Decreto-Lei nº 5.452, de 1º de maio de 1943 (Consolidação das Leis do Trabalho)',
         'conf': 'Texto compilado aberto no site do Planalto em 03/10/2026 e conferidos no texto oficial: art. 74, § 2º (registro de ponto obrigatório '
                 'acima de 20 trabalhadores) e § 4º (ponto por exceção); art. 145 (férias pagas até 2 dias antes do início); art. 459, § 1º (salário '
                 'até o quinto dia útil do mês seguinte); art. 477, § 6º (verbas rescisórias em até 10 dias do término).',
         'links': [('planalto.gov.br, CLT', 'https://www.planalto.gov.br/ccivil_03/decreto-lei/del5452.htm')]},
 'fgts': {'ref': 'Brasil, Lei nº 8.036, de 11 de maio de 1990 (FGTS), art. 15, na redação da Lei nº 14.438, de 24 de agosto de 2022',
          'conf': 'Texto consolidado aberto no site do Planalto em 03/10/2026: depósito até o vigésimo dia de cada mês, de 8% da remuneração do mês '
                  'anterior (art. 15, redação da Lei 14.438/2022). A data de início do FGTS Digital (1º/03/2024) só foi achada em notícia da CNI; '
                  'o ato oficial não foi localizado.',
          'links': [('planalto.gov.br, Lei 8.036 consolidada', 'https://www.planalto.gov.br/ccivil_03/leis/l8036consol.htm'),
                    ('CNI, notícia sobre o FGTS Digital (secundária)', 'https://conexaotrabalho.portaldaindustria.com.br/noticias/detalhe/trabalhista/-geral/fgts-digital-torna-se-obrigatorio-para-empregadores-partir-de-1-de-marco/')]},
 'iso21502': {'ref': 'ISO 21502:2020, Project, programme and portfolio management — Guidance on project management',
              'conf': 'Página oficial da ISO aberta em 02/10/2026: resumo lido; a norma está publicada, no estágio 90.92 (a ser revista). A norma completa é paga e não foi lida.',
              'links': [('iso.org', 'https://www.iso.org/standard/74947.html')]},
 'iso27001': {'ref': 'ISO/IEC 27001:2022, Information security, cybersecurity and privacy protection — Information security management systems — Requirements',
              'conf': 'Página oficial da ISO aberta em 02/10/2026: resumo lido. A norma completa é paga e não foi lida.',
              'links': [('iso.org', 'https://www.iso.org/standard/27001')]},
 'iso9001': {'ref': 'ISO 9001:2026, Quality management systems — Requirements',
             'conf': 'Página oficial da ISO aberta em 03/10/2026: apresenta a edição de 2026 como a vigente; a página da ISO 9001:2015 a mostra como retirada e substituída pela de 2026. Nenhum requisito numerado foi lido: a norma completa é paga.',
             'links': [('iso.org, ISO 9001', 'https://www.iso.org/9001'), ('iso.org, ISO 9001:2015 (retirada)', 'https://www.iso.org/standard/62085.html')]},
 'iso10002': {'ref': 'ISO 10002:2018, Quality management — Customer satisfaction — Guidelines for complaints handling in organizations',
              'conf': 'Página oficial da ISO aberta em 03/10/2026: resumo lido; a norma está publicada e foi confirmada em 2023. A norma completa é paga e não foi lida.',
              'links': [('iso.org', 'https://www.iso.org/standard/71580.html')]},
 'cdc': {'ref': 'Brasil, Lei nº 8.078, de 11 de setembro de 1990 (Código de Defesa do Consumidor)',
         'conf': 'Texto compilado aberto no site do Planalto em 03/10/2026; conferidos o art. 10 (caput e § 1º), o art. 18 (caput, § 1º, incisos I a III, e § 3º), o art. 20 (caput e incisos I a III) e o art. 26 (caput, incisos I e II, § 1º, § 2º, inciso I, e § 3º).',
         'links': [('planalto.gov.br', 'https://www.planalto.gov.br/ccivil_03/leis/l8078compilado.htm')]},
 'lgpd': {'ref': 'Brasil, Lei nº 13.709, de 14 de agosto de 2018 (Lei Geral de Proteção de Dados Pessoais)',
          'conf': 'Texto aberto no site do Planalto; conferidos o art. 5º (incisos I, II, III, VI, VII e X), o art. 6º (caput e incisos I a III), o art. 7º '
                  '(caput e incisos I, V e IX), o art. 8º (caput e § 5º), o art. 9º (caput), os arts. 15 e 16 (término do tratamento e eliminação dos '
                  'dados), o art. 18 (caput e incisos I a IX) e o caput do art. 37. Em 03/10/2026, também o caput do art. 19 e o inciso II, o caput do art. 20, o caput do art. 41 e o § 2º, incisos I e II, e o caput do art. 48.',
          'links': [('planalto.gov.br', 'https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm')]},
 'fabric': {'ref': 'HM Treasury, Cabinet Office, National Audit Office, Audit Commission e Office for National Statistics (Reino Unido), Choosing the right '
                   'FABRIC: A Framework for Performance Information',
            'conf': 'PDF aberto no site do National Audit Office. O documento não traz data impressa; cita a revisão de gastos de 2000, e os metadados do '
                    'arquivo indicam março de 2001.',
            'links': [('nao.org.uk (PDF)', 'https://www.nao.org.uk/wp-content/uploads/2013/02/fabric.pdf')]},
 'kcs': {'ref': 'Consortium for Service Innovation, KCS v6 Practices Guide (versão 6, de 21/04/2016)',
         'conf': 'Guia oficial aberto na biblioteca do Consortium for Service Innovation; lidos o índice, a seção 1, Knowledge-Centered Service, e a '
                 'seção 2, The KCS Practices. A seção 1 diz que a maior parte da experiência dos membros vem do suporte a clientes e das centrais de '
                 'atendimento internas; usar o guia nas bases de conhecimento de toda a empresa é escolha nossa.',
         'links': [('serviceinnovation.org', 'https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide'),
                   ('seção 1', 'https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/020'),
                   ('seção 2', 'https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/030')]},
 'apqc_km': {'ref': 'APQC, Knowledge Flow Process Framework (23/08/2023), e Lynda Braksiek, Managing Knowledge Starts with Knowledge Flow, blog da APQC '
                    '(30/08/2023)',
             'conf': 'Página do recurso (descrição) e artigo do blog abertos no site da APQC; o documento completo do framework não foi lido.',
             'links': [('apqc.org (recurso)', 'https://www.apqc.org/resource-library/resource-listing/apqcs-knowledge-flow-process-framework'),
                       ('apqc.org (blog)', 'https://www.apqc.org/blog/managing-knowledge-starts-knowledge-flow')]},
 'iso30401': {'ref': 'ISO 30401:2018, Knowledge management systems — Requirements',
              'conf': 'Página oficial da ISO aberta (resumo); a norma completa é paga e não foi lida. A página lista duas emendas (Amd 1:2022 e Amd '
                      '2:2024) e avisa que a norma está em revisão e será substituída por nova edição.',
              'links': [('iso.org', 'https://www.iso.org/standard/68683.html')]},
 'anthropic_evals': {'ref': 'Anthropic, Define success criteria and build evaluations (documentação da plataforma Claude)',
                     'conf': 'Página oficial aberta em platform.claude.com.',
                     'links': [('platform.claude.com', 'https://platform.claude.com/docs/en/test-and-evaluate/develop-tests')]},
 'nist_airmf': {'ref': 'National Institute of Standards and Technology (NIST), Artificial Intelligence Risk Management Framework (AI RMF 1.0), 2023',
                'conf': 'Página do núcleo do framework aberta no site do NIST (AI Resource Center); o documento completo não foi lido. A página avisa que '
                        'a versão 1.0 está em atualização.',
                'links': [('airc.nist.gov', 'https://airc.nist.gov/airmf-resources/airmf/5-sec-core/')]},
 'pdca': {'ref': 'ASQ, What is the Plan-Do-Check-Act (PDCA) Cycle?',
          'conf': 'Página oficial da ASQ aberta.',
          'links': [('asq.org', 'https://asq.org/quality-resources/pdca-cycle')]},
 'nng_blueprint': {'ref': 'Sarah Gibbons, Service Blueprints: Definition, Nielsen Norman Group, 27/08/2017',
                   'conf': 'Artigo aberto no site da NN/g.',
                   'links': [('nngroup.com', 'https://www.nngroup.com/articles/service-blueprints-definition/')]},
 'bmc': {'ref': 'Strategyzer, The Business Model Canvas (quadro oficial; a página o atribui ao livro Business Model Generation)',
         'conf': 'Página oficial e PDF do quadro abertos; os nove blocos foram lidos no PDF, que traz licença Creative Commons BY-SA 3.0. A página não cita os '
                 'autores do livro.',
         'links': [('strategyzer.com', 'https://www.strategyzer.com/library/the-business-model-canvas'),
                   ('quadro (PDF)', 'https://cdn.prod.website-files.com/64830736e7f43d491d70ef30/65d36b6f31059e94e2ff517c_A3-Business%20Model%20Canvas-2023.pdf')]},
 'vpc': {'ref': 'Strategyzer, The Value Proposition Canvas',
         'conf': 'Página oficial aberta.',
         'links': [('strategyzer.com', 'https://www.strategyzer.com/library/the-value-proposition-canvas')]},
 'leanstartup': {'ref': 'The Lean Startup, Methodology (página /principles do site do método; a página cita Eric Ries)',
                 'conf': 'Página aberta em theleanstartup.com.',
                 'links': [('theleanstartup.com', 'https://theleanstartup.com/principles')]},
 'doublediamond': {'ref': 'Design Council (Reino Unido), The Double Diamond',
                   'conf': 'Página oficial aberta.',
                   'links': [('designcouncil.org.uk', 'https://www.designcouncil.org.uk/resources/the-double-diamond/')]},
 'jaakkola': {'ref': 'Elina Jaakkola, Unraveling the practices of “productization” in professional service firms, Scandinavian Journal of Management, v. 27, '
                     'n. 2, p. 221–230, junho de 2011',
              'conf': 'Resumo lido no registro do RePEc (IDEAS); o artigo completo não foi lido. Segundo o resumo, o estudo analisa o discurso de '
                      'profissionais de pequenas empresas de serviços profissionais.',
              'links': [('registro RePEc', 'https://ideas.repec.org/a/eee/scaman/v27y2011i2p221-230.html')]},
 'iso44001': {'ref': 'ISO 44001:2017, Collaborative business relationship management systems — Requirements and framework',
              'conf': 'Página oficial da ISO aberta (resumo); a norma completa é paga e não foi lida. A página informa que a norma está em revisão.',
              'links': [('iso.org', 'https://www.iso.org/standard/72798.html')]},
 'barcelona': {'ref': 'AMEC (International Association for the Measurement and Evaluation of Communication), Barcelona Principles 3.0, julho de 2020',
               'conf': 'Página oficial da AMEC aberta (data de lançamento); o texto dos sete princípios foi lido na notícia da MEPRA, que os transcreve, '
                       'porque a página da AMEC só os oferece em arquivos anexos.',
               'links': [('amecorg.com', 'https://amecorg.com/barcelona-principles-3-0/'),
                         ('mepra.org (texto dos princípios)', 'https://www.mepra.org/knowledge/news/amec-launches-barcelona-principles-3-0/')]},
 'nng_journey': {'ref': 'Sarah Gibbons, Journey Mapping 101, Nielsen Norman Group, 09/12/2018',
                 'conf': 'Artigo aberto no site da NN/g.',
                 'links': [('nngroup.com', 'https://www.nngroup.com/articles/journey-mapping-101/')]},
})
