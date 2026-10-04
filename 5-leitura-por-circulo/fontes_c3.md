# Fontes do Círculo 3 · Inteligência: para conferência independente


## anthropic_evals
- Referência (como será publicada): Anthropic, Define success criteria and build evaluations (documentação da plataforma Claude)
- O que dizemos que a fonte contém e como a usamos: Critério de sucesso específico, mensurável, alcançável e relevante; avaliações que espelham a tarefa real e são automatizadas quando possível; três formas de correção: por código, por pessoa e por modelo. Base das perguntas de teste da IN-05 e do critério de sucesso e dos casos de teste da IN-06.
- Como dizemos que foi conferida: Página oficial aberta em platform.claude.com.
- Links:
  - platform.claude.com: https://platform.claude.com/docs/en/test-and-evaluate/develop-tests

## apqc
- Referência (como será publicada): APQC, Process Classification Framework (PCF), cross-industry
- O que dizemos que a fonte contém e como a usamos: PCF 7.4. Os processos das funções da Inteligência estão em dez grupos de cinco categorias: 1.4, modelos de negócio; 2.1 a 2.3, desenvolvimento de produtos e serviços; 3.1 e parte do 3.2, mercados, clientes e estratégia de marketing; 8.4, gestão da informação; e 13.5 a 13.7, gestão do conhecimento, medição e análise. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.
- Como dizemos que foi conferida: PDF da versão 7.4 (agosto de 2024) aberto em dois endereços e lido por inteiro em 01/10/2026, por extração do texto das 35 páginas, que cobrem as 13 categorias. Conferidos um a um os elementos das categorias 1, 3 e 7 (por mim e por um revisor independente) e os da categoria 2 e dos grupos 8.4, 12.4, 12.5, 13.5, 13.6 e 13.7 (por mim e por um segundo revisor, no desenho do círculo 3). Em 03/10/2026, os elementos citados das categorias 4, 5, 6, 7, 9, 10, 11 e 12 e o 13.9.2.3 (por mim e por um revisor independente em cada um dos círculos 7, 8 e 9). Também em 03/10/2026, os 18 elementos das categorias 8 e 13 citados no círculo 6, conferidos código e nome contra o texto do PDF 7.4, e os grupos de nível 2 das categorias 8 e 13, conferidos por um revisor independente no mesmo PDF. A versão 8.0 (27/02/2026) foi conferida só nas 13 categorias, na página da coleção de definições da APQC.
- Links:
  - PCF 7.4 (PDF, cópia 1): https://www.business-analysis.com.au/wp-content/uploads/2025/04/K014750_APQC-Process-Classification-Framework-PCF-Cross-Industry-PDF-Version-7.4_January-2025.pdf
  - PCF 7.4 (PDF, cópia 2): https://solutions.ifrc.org/sites/default/files/2024-10/K014750_APQC%20Process%20Classification%20Framework%20(PCF)%20-%20Cross%20Industry%20-%20PDF%20Version%207.4.pdf
  - PCF 8.0 (página oficial): https://www.apqc.org/resource-library/resource-listing/apqc-process-classification-framework-pcf-cross-industry-excel-12
  - PCF 8.0, 13 categorias: https://www.apqc.org/resource-library/resource-collection/pcf-version-80-process-definitions-and-key-measures-collection

## apqc_km
- Referência (como será publicada): APQC, Knowledge Flow Process Framework (23/08/2023), e Lynda Braksiek, Managing Knowledge Starts with Knowledge Flow, blog da APQC (30/08/2023)
- O que dizemos que a fonte contém e como a usamos: Fluxo do conhecimento em sete passos: criar, identificar, coletar, revisar, compartilhar, acessar e usar. Base da sequência da IN-05 e da IN-06.
- Como dizemos que foi conferida: Página do recurso (descrição) e artigo do blog abertos no site da APQC; o documento completo do framework não foi lido.
- Links:
  - apqc.org (recurso): https://www.apqc.org/resource-library/resource-listing/apqcs-knowledge-flow-process-framework
  - apqc.org (blog): https://www.apqc.org/blog/managing-knowledge-starts-knowledge-flow

## bmc
- Referência (como será publicada): Strategyzer, The Business Model Canvas (quadro oficial; a página o atribui ao livro Business Model Generation)
- O que dizemos que a fonte contém e como a usamos: Quadro de modelo de negócio em nove blocos: segmentos de clientes, propostas de valor, canais, relacionamento com clientes, fontes de receita, recursos-chave, atividades-chave, parcerias-chave e estrutura de custos. Base da etapa 5 da IN-07.
- Como dizemos que foi conferida: Página oficial e PDF do quadro abertos; os nove blocos foram lidos no PDF, que traz licença Creative Commons BY-SA 3.0. A página não cita os autores do livro.
- Links:
  - strategyzer.com: https://www.strategyzer.com/library/the-business-model-canvas
  - quadro (PDF): https://cdn.prod.website-files.com/64830736e7f43d491d70ef30/65d36b6f31059e94e2ff517c_A3-Business%20Model%20Canvas-2023.pdf

## bpmn
- Referência (como será publicada): OMG, Business Process Model and Notation (BPMN) 2.0.2; ISO/IEC 19510:2013
- O que dizemos que a fonte contém e como a usamos: Notação dos fluxos. A ISO/IEC 19510:2013 é idêntica ao BPMN 2.0.1. Tipos de tarefa usados: usuário, manual, serviço, regra de negócio, script e recebimento, além da atividade de chamada.
- Como dizemos que foi conferida: Páginas oficiais da OMG e da ISO abertas; a lista de tipos de tarefa foi conferida no BPMN Quick Guide; a atividade de chamada foi aceita pelo metamodelo usado nos testes. A especificação completa não foi lida.
- Links:
  - omg.org: https://www.omg.org/spec/BPMN/2.0.2/About-BPMN
  - iso.org: https://www.iso.org/standard/62652.html
  - BPMN Quick Guide: https://www.bpmnquickguide.com/quickguide/bpmn-quick-guide/tasks

## camunda
- Referência (como será publicada): Camunda, Best Practices: Naming BPMN elements
- O que dizemos que a fonte contém e como a usamos: Regra de nomes: tarefa com verbo no infinitivo e objeto; evento com objeto e estado; gateway com pergunta; raia com papel ou sistema.
- Como dizemos que foi conferida: Documentação oficial aberta.
- Links:
  - docs.camunda.io: https://docs.camunda.io/docs/components/best-practices/modeling/naming-bpmn-elements/

## cebma
- Referência (como será publicada): E. Barends, D. M. Rousseau e R. B. Briner, Evidence-Based Management: The Basic Principles, Center for Evidence-Based Management, Amsterdã, 2014
- O que dizemos que a fonte contém e como a usamos: Prática baseada em evidência: decidir com o uso consciencioso, explícito e criterioso da melhor evidência disponível, de várias fontes. A definição enumera seis habilidades: perguntar, buscar, avaliar criticamente, agregar, aplicar e avaliar o resultado da decisão. Base das quatro etapas da IN-02 e da conferência do resultado na IN-08.
- Como dizemos que foi conferida: PDF aberto no site do CEBMa.
- Links:
  - cebma.org (PDF): https://cebma.org/assets/Uploads/Evidence-Based-Practice-The-Basic-Principles.pdf

## dmn
- Referência (como será publicada): OMG, Decision Model and Notation (DMN)
- O que dizemos que a fonte contém e como a usamos: Padrão de modelagem de decisões, que inclui tabelas de decisão. Usado na IN-03 para as regras de qualidade do dado.
- Como dizemos que foi conferida: Página oficial da OMG aberta.
- Links:
  - omg.org: https://www.omg.org/spec/DMN

## doublediamond
- Referência (como será publicada): Design Council (Reino Unido), The Double Diamond
- O que dizemos que a fonte contém e como a usamos: Quatro fases em dois diamantes: descobrir e definir o problema, desenvolver e entregar a solução. Base da ordem das etapas 3 e 4 da IN-07: primeiro o problema, depois a solução.
- Como dizemos que foi conferida: Página oficial aberta.
- Links:
  - designcouncil.org.uk: https://www.designcouncil.org.uk/resources/the-double-diamond/

## dqf
- Referência (como será publicada): Government Data Quality Hub (Reino Unido), The Government Data Quality Framework, 03/12/2020
- O que dizemos que a fonte contém e como a usamos: Seis dimensões de qualidade do dado: completude, unicidade, consistência, atualidade, validade e exatidão. Ciclo de vida em seis estágios: planejar; coletar ou adquirir, e ingerir; preparar, guardar e manter; usar e processar; compartilhar e publicar; arquivar ou destruir. Base das cinco etapas da IN-03 e da marca de qualidade dos indicadores na IN-04.
- Como dizemos que foi conferida: Página oficial aberta no gov.uk.
- Links:
  - gov.uk: https://www.gov.uk/government/publications/the-government-data-quality-framework/the-government-data-quality-framework

## fabric
- Referência (como será publicada): HM Treasury, Cabinet Office, National Audit Office, Audit Commission e Office for National Statistics (Reino Unido), Choosing the right FABRIC: A Framework for Performance Information
- O que dizemos que a fonte contém e como a usamos: Seis propriedades de um sistema de informação de desempenho: focado, apropriado, equilibrado, robusto, integrado e com custo compatível. Oito critérios de uma boa medida: relevante, sem incentivo perverso, atribuível, bem definida, tempestiva, confiável, comparável e verificável. Base da ficha e da revisão dos indicadores na IN-04.
- Como dizemos que foi conferida: PDF aberto no site do National Audit Office. O documento não traz data impressa; cita a revisão de gastos de 2000, e os metadados do arquivo indicam março de 2001.
- Links:
  - nao.org.uk (PDF): https://www.nao.org.uk/wp-content/uploads/2013/02/fabric.pdf

## fair
- Referência (como será publicada): GO FAIR, FAIR Principles (resumo dos princípios publicados na revista Scientific Data em 2016)
- O que dizemos que a fonte contém e como a usamos: Princípios de localização (F1 a F4): identificador único e persistente, metadados ricos, metadados que citam o identificador do dado e registro em recurso pesquisável. Base da ficha e do catálogo de dados na IN-03.
- Como dizemos que foi conferida: PDF de resumo aberto no site da GO FAIR; o artigo de 2016 não foi lido. Os princípios foram escritos para dados de pesquisa; usá-los no catálogo de dados é escolha nossa.
- Links:
  - go-fair.org (PDF): https://www.go-fair.org/wp-content/uploads/2022/01/FAIRPrinciples_overview.pdf

## herring
- Referência (como será publicada): Jan P. Herring, Key intelligence topics: A process to identify and define intelligence needs, Competitive Intelligence Review, v. 10, n. 2, p. 4–14, 1999
- O que dizemos que a fonte contém e como a usamos: Processo de tópicos-chave de inteligência (KIT): as necessidades de inteligência são identificadas e priorizadas em diálogo com quem decide. O resumo informa que o artigo traz protocolos de exemplo de três tipos: decisões e ações estratégicas, temas de alerta antecipado e descrição dos principais atores do mercado. Base da etapa 1 da IN-01.
- Como dizemos que foi conferida: Resumo completo lido no registro do SciSpace; autor, volume, número e páginas conferidos no registro do Crossref. A página da editora (Wiley) recusou o acesso, e o artigo não foi lido.
- Links:
  - registro SciSpace: https://scispace.com/journals/competitive-intelligence-review-1ve3qz6m/1999
  - registro Crossref: https://api.crossref.org/works/10.1002/(sici)1520-6386(199932)10:2%3C4::aid-cir3%3E3.0.co;2-c

## horizon
- Referência (como será publicada): Government Office for Science (Reino Unido), The Futures Toolkit, versão de 2024 (página publicada em 08/07/2014 e atualizada em 29/08/2024)
- O que dizemos que a fonte contém e como a usamos: Horizon scanning: coleta sistemática de percepções sobre tendências emergentes e sinais fracos de mudança, para identificar ameaças, riscos e oportunidades. Cinco passos: formar o grupo, identificar as fontes, reunir e guardar os dados de forma organizada, analisar e redigir os resultados. Base das etapas 2 e 3 da IN-01.
- Como dizemos que foi conferida: Página oficial e versão em HTML abertas no gov.uk; lida a ferramenta Horizon Scanning.
- Links:
  - gov.uk: https://www.gov.uk/government/publications/futures-toolkit-for-policy-makers-and-analysts
  - versão em HTML: https://www.gov.uk/government/publications/futures-toolkit-for-policy-makers-and-analysts/the-futures-toolkit-html

## jaakkola
- Referência (como será publicada): Elina Jaakkola, Unraveling the practices of “productization” in professional service firms, Scandinavian Journal of Management, v. 27, n. 2, p. 221–230, junho de 2011
- O que dizemos que a fonte contém e como a usamos: Três práticas de produtização em pequenas empresas de serviços profissionais: especificar e padronizar a oferta; tornar tangíveis a oferta e a competência profissional; sistematizar e padronizar processos e métodos. Base da etapa 7 da IN-07 e da IN-06. O estudo descreve práticas relatadas por gestores; usá-las como roteiro é leitura nossa.
- Como dizemos que foi conferida: Resumo lido no registro do RePEc (IDEAS); o artigo completo não foi lido. Segundo o resumo, o estudo analisa o discurso de profissionais de pequenas empresas de serviços profissionais.
- Links:
  - registro RePEc: https://ideas.repec.org/a/eee/scaman/v27y2011i2p221-230.html

## kcs
- Referência (como será publicada): Consortium for Service Innovation, KCS v6 Practices Guide (versão 6, de 21/04/2016)
- O que dizemos que a fonte contém e como a usamos: Oito práticas em dois ciclos. No ciclo de solução: capturar, estruturar, reusar e melhorar. No ciclo de evolução: saúde do conteúdo, integração ao processo, avaliação de desempenho, e liderança e comunicação. O ciclo de evolução aprende com os padrões de reuso. Base das etapas da IN-05 e do cruzamento de lições na IN-08. O guia nasceu no atendimento (suporte ao cliente e help desk) e, na versão 6, declara aplicação além do suporte; usá-lo em bases para agentes é leitura nossa.
- Como dizemos que foi conferida: Guia oficial aberto na biblioteca do Consortium for Service Innovation; lidos o índice, a seção 1, Knowledge-Centered Service, e a seção 2, The KCS Practices. A seção 1 diz que a maior parte da experiência dos membros vem do suporte a clientes e das centrais de atendimento internas; usar o guia nas bases de conhecimento de toda a empresa é escolha nossa.
- Links:
  - serviceinnovation.org: https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide
  - seção 1: https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/020
  - seção 2: https://library.serviceinnovation.org/KCS/KCS_v6/KCS_v6_Practices_Guide/030

## leanstartup
- Referência (como será publicada): The Lean Startup, Methodology (página /principles do site do método; a página cita Eric Ries)
- O que dizemos que a fonte contém e como a usamos: Construir, medir e aprender: transformar ideias em produto, medir a resposta dos clientes e aprender se é o caso de mudar o rumo ou perseverar. O produto mínimo viável serve para começar a aprender o mais cedo possível. Base do piloto na etapa 6 da IN-07.
- Como dizemos que foi conferida: Página aberta em theleanstartup.com.
- Links:
  - theleanstartup.com: https://theleanstartup.com/principles

## lgpd
- Referência (como será publicada): Brasil, Lei nº 13.709, de 14 de agosto de 2018 (Lei Geral de Proteção de Dados Pessoais)
- O que dizemos que a fonte contém e como a usamos: Definições de dado pessoal, dado pessoal sensível, dado anonimizado e tratamento (art. 5º); princípios da finalidade, da adequação e da necessidade (art. 6º); término do tratamento e eliminação dos dados, com as finalidades para as quais a conservação é autorizada (arts. 15 e 16); dever de manter registro das operações de tratamento (art. 37). Base da classificação, da recusa e da retirada de dado na IN-03. Quem define a regra é a Governança.
- Como dizemos que foi conferida: Texto aberto no site do Planalto; conferidos o art. 5º (incisos I, II, III, VI, VII e X), o art. 6º (caput e incisos I a III), o art. 7º (caput e incisos I, V e IX), o art. 8º (caput e § 5º), o art. 9º (caput), os arts. 15 e 16 (término do tratamento e eliminação dos dados), o art. 18 (caput e incisos I a IX) e o caput do art. 37. Em 03/10/2026, também o caput do art. 19 e o inciso II, o caput do art. 20, o caput do art. 41 e o § 2º, incisos I e II, e o caput do art. 48.
- Links:
  - planalto.gov.br: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm

## nist_airmf
- Referência (como será publicada): National Institute of Standards and Technology (NIST), Artificial Intelligence Risk Management Framework (AI RMF 1.0), 2023
- O que dizemos que a fonte contém e como a usamos: O núcleo tem quatro funções: governar, mapear, medir e gerir. Medir usa ferramentas e métodos quantitativos, qualitativos ou mistos para analisar, avaliar, comparar e monitorar. Base da avaliação do método em uso por agentes, na etapa 5 da IN-06. O framework trata de risco de IA; usá-lo para a qualidade do resultado é leitura nossa.
- Como dizemos que foi conferida: Página do núcleo do framework aberta no site do NIST (AI Resource Center); o documento completo não foi lido. A página avisa que a versão 1.0 está em atualização.
- Links:
  - airc.nist.gov: https://airc.nist.gov/airmf-resources/airmf/5-sec-core/

## nng_blueprint
- Referência (como será publicada): Sarah Gibbons, Service Blueprints: Definition, Nielsen Norman Group, 27/08/2017
- O que dizemos que a fonte contém e como a usamos: Mapa de serviço com quatro elementos: ações do cliente, ações à vista do cliente, ações de bastidor e processos. Base do desenho da entrega na etapa 4 da IN-07.
- Como dizemos que foi conferida: Artigo aberto no site da NN/g.
- Links:
  - nngroup.com: https://www.nngroup.com/articles/service-blueprints-definition/

## odni_ciclo
- Referência (como será publicada): Office of the Director of National Intelligence (ODNI), How the IC Works: the six steps in the Intelligence Cycle (intelligence.gov)
- O que dizemos que a fonte contém e como a usamos: Ciclo de inteligência em seis passos: planejamento, coleta, processamento, análise, disseminação e avaliação. No planejamento, quem decide determina que temas precisam ser tratados e define as prioridades de inteligência; a avaliação dos produtos é contínua. Base da sequência de etapas da IN-01, incluída a avaliação de uso da leitura.
- Como dizemos que foi conferida: Página oficial aberta em intelligence.gov; a página não traz data. O ciclo é o da comunidade de inteligência dos Estados Unidos; aplicá-lo à leitura de mercado é analogia nossa.
- Links:
  - intelligence.gov: https://www.intelligence.gov/how-the-ic-works

## pdca
- Referência (como será publicada): ASQ, What is the Plan-Do-Check-Act (PDCA) Cycle?
- O que dizemos que a fonte contém e como a usamos: Ciclo de quatro passos para conduzir uma mudança: planejar, testar em pequena escala, verificar o que se aprendeu e agir, incorporando o que funcionou. Base do teste em caso real da IN-06 e da sequência da IN-08.
- Como dizemos que foi conferida: Página oficial da ASQ aberta.
- Links:
  - asq.org: https://asq.org/quality-resources/pdca-cycle

## sipoc
- Referência (como será publicada): ASQ, SIPOC+CM Diagram
- O que dizemos que a fonte contém e como a usamos: Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.
- Como dizemos que foi conferida: Página oficial da ASQ aberta.
- Links:
  - asq.org: https://asq.org/quality-resources/sipoc

## stagegate
- Referência (como será publicada): Stage-Gate International, The Stage-Gate Model: An Overview (página do blog, com o nome de Robert G. Cooper)
- O que dizemos que a fonte contém e como a usamos: Depois da descoberta e ideação, a página lista cinco estágios, cada um precedido de um portão: conceito, construir o caso de negócio, desenvolvimento, teste e validação, e lançamento. A IN-07 cobre o trabalho entre os dois portões que a Estratégia decide: a entrada na carteira e o lançamento.
- Como dizemos que foi conferida: Página oficial aberta. Os metadados da página indicam publicação em 15/12/2025 e outra autora; por isso a data e a autoria não entram na referência.
- Links:
  - stage-gate.com: https://www.stage-gate.com/blog/the-stage-gate-model-an-overview/

## vpc
- Referência (como será publicada): Strategyzer, The Value Proposition Canvas
- O que dizemos que a fonte contém e como a usamos: Perfil do cliente (tarefas, dores e ganhos) e mapa de valor (o que se oferece, as dores que alivia e os ganhos que cria). O encaixe é uma afirmação até os clientes confirmarem. Base das etapas 3 e 6 da IN-07.
- Como dizemos que foi conferida: Página oficial aberta.
- Links:
  - strategyzer.com: https://www.strategyzer.com/library/the-value-proposition-canvas

## yardstick
- Referência (como será publicada): Ministry of Defence (Reino Unido), Defence Intelligence – communicating probability, 17/02/2023
- O que dizemos que a fonte contém e como a usamos: Régua de probabilidade da inteligência de defesa britânica: a escala de probabilidade é dividida em sete faixas numéricas, com termos atribuídos a cada faixa. Usamos a ideia de termos padronizados para declarar o grau de confiança na IN-01 e na IN-02. A régua trata de probabilidade; a lista dos termos e as faixas não foram lidas.
- Como dizemos que foi conferida: Página oficial aberta no gov.uk. O texto diz que a régua divide a escala de probabilidade em sete faixas numéricas, com termos atribuídos a cada faixa. A página não reproduz a tabela e só cita dois termos de passagem; a lista dos termos e as faixas não foram lidas.
- Links:
  - gov.uk: https://www.gov.uk/government/news/defence-intelligence-communicating-probability
