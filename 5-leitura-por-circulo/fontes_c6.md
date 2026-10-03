# Fontes do Círculo 6 · Integração — para conferência independente


## anthropic_evals
- Referência (como será publicada): Anthropic, Define success criteria and build evaluations (documentação da plataforma Claude)
- O que dizemos que a fonte contém e como a usamos: Critério de sucesso específico e mensurável; avaliações que espelham a tarefa real e são automatizadas quando possível; correção por código, por pessoa e por modelo. Base dos casos de teste, do julgamento dos casos de fronteira e do critério de liberação na IT-06.
- Como dizemos que foi conferida: Página oficial aberta em platform.claude.com.
- Links:
  - platform.claude.com: https://platform.claude.com/docs/en/test-and-evaluate/develop-tests

## apqc
- Referência (como será publicada): APQC, Process Classification Framework (PCF), cross-industry
- O que dizemos que a fonte contém e como a usamos: PCF 7.4. Os processos da Integração estão em duas categorias: 8.0, tecnologia da informação (arquitetura, portfólio de TI, segurança, identidade e acesso, criação e teste de soluções, implantação, controle de mudança e suporte), base da IT-06 e da IT-07; e 13.0, capacidades do negócio (processos, portfólio e projetos, mudança), base da IT-01 a IT-05 e da IT-08. A tabela de cobertura, na aba Método, mostra onde cada um foi parar.
- Como dizemos que foi conferida: PDF da versão 7.4 (agosto de 2024) aberto em dois endereços e lido por inteiro em 01/10/2026, por extração do texto das 35 páginas, que cobrem as 13 categorias. Conferidos um a um os elementos das categorias 1, 3 e 7 (por mim e por um revisor independente) e os da categoria 2 e dos grupos 8.4, 12.4, 12.5, 13.5, 13.6 e 13.7 (por mim e por um segundo revisor, no desenho do círculo 3). A versão 8.0 (27/02/2026) foi conferida só nas 13 categorias, na página da coleção de definições da APQC.
- Links:
  - PCF 7.4 (PDF, cópia 1): https://www.business-analysis.com.au/wp-content/uploads/2025/04/K014750_APQC-Process-Classification-Framework-PCF-Cross-Industry-PDF-Version-7.4_January-2025.pdf
  - PCF 7.4 (PDF, cópia 2): https://solutions.ifrc.org/sites/default/files/2024-10/K014750_APQC%20Process%20Classification%20Framework%20(PCF)%20-%20Cross%20Industry%20-%20PDF%20Version%207.4.pdf
  - PCF 8.0 (página oficial): https://www.apqc.org/resource-library/resource-listing/apqc-process-classification-framework-pcf-cross-industry-excel-12
  - PCF 8.0, 13 categorias: https://www.apqc.org/resource-library/resource-collection/pcf-version-80-process-definitions-and-key-measures-collection

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

## iso21502
- Referência (como será publicada): ISO 21502:2020, Project, programme and portfolio management — Guidance on project management
- O que dizemos que a fonte contém e como a usamos: Norma de orientação para gestão de projetos, aplicável a qualquer organização e a qualquer tipo de projeto; não trata de programas nem de portfólios. Lemos só o resumo; a norma está publicada e marcada para revisão. Referência do ciclo de projeto (registrar, planejar, acompanhar e encerrar com lições) na IT-01, na IT-02, na IT-03 e na IT-04; o portfólio vem do APQC (13.2.1).
- Como dizemos que foi conferida: Página oficial da ISO aberta em 02/10/2026: resumo lido; a norma está publicada, no estágio 90.92 (a ser revista). A norma completa é paga e não foi lida.
- Links:
  - iso.org: https://www.iso.org/standard/74947.html

## iso27001
- Referência (como será publicada): ISO/IEC 27001:2022, Information security, cybersecurity and privacy protection — Information security management systems — Requirements
- O que dizemos que a fonte contém e como a usamos: Norma de requisitos para o sistema de gestão da segurança da informação. Lemos só o resumo. Referência da operação segura da IT-07: acesso pela classificação, mudança testada e reversível e incidente de segurança tratado com a Governança, que define a política.
- Como dizemos que foi conferida: Página oficial da ISO aberta em 02/10/2026: resumo lido. A norma completa é paga e não foi lida.
- Links:
  - iso.org: https://www.iso.org/standard/27001

## nist_airmf
- Referência (como será publicada): National Institute of Standards and Technology (NIST), Artificial Intelligence Risk Management Framework (AI RMF 1.0), 2023
- O que dizemos que a fonte contém e como a usamos: O núcleo tem quatro funções: governar, mapear, medir e gerir. Base do monitoramento em uso e da suspensão do agente que sai da alçada na IT-06. O framework trata de risco de IA; usá-lo para a operação do agente é leitura nossa.
- Como dizemos que foi conferida: Página do núcleo do framework aberta no site do NIST (AI Resource Center); o documento completo não foi lido. A página avisa que a versão 1.0 está em atualização.
- Links:
  - airc.nist.gov: https://airc.nist.gov/airmf-resources/airmf/5-sec-core/

## sipoc
- Referência (como será publicada): ASQ, SIPOC+CM Diagram
- O que dizemos que a fonte contém e como a usamos: Fornecedor, entrada, processo, saída e cliente: a base de “quem gera a entrada” e “quem recebe a saída” em cada etapa.
- Como dizemos que foi conferida: Página oficial da ASQ aberta.
- Links:
  - asq.org: https://asq.org/quality-resources/sipoc
