# Verificação independente das fontes do Círculo 4 · Relações

Data: 02/10/2026. bpmn, camunda e sipoc fora do escopo (já conferidas).
Resultado: 5 CONFIRMADAS, 3 CONFIRMADAS EM PARTE, 0 NÃO CONFIRMADAS. Tabela de cobertura: 17 linhas certas, 1 errada.

## apqc — CONFIRMADA EM PARTE
- Cópias 1 e 2 do PDF baixadas (HTTP 200, 35 páginas). As duas dizem "Version 7.4 • August 2024"; o texto é o mesmo (só muda a ordem de extração). O nome do arquivo da cópia 1 diz "January-2025", mas o documento é o de agosto de 2024. A referência está certa.
- Números e nomes dos grupos citados no uso conferem com o PDF: 1.2.8 Develop customer experience strategy; 3.2 Develop marketing strategy; 3.3 Develop and manage marketing plans; 3.4.2 Develop sales partner/alliance relationships; 3.5.1 Manage leads/opportunities; 3.5.2 Manage customers and accounts; 3.5.5 Manage sales partners and alliances; 12.2 Manage government and industry relationships; 12.5 Manage public relations program. 12.2.3 (citado na fonte iso44001) é "Manage relations with trade or industry groups": confere.
- Corrigir a contagem: o texto diz "cinco grupos", mas enumera quatro blocos separados por ponto e vírgula (1.2.8; 3.2 e 3.3; 3.4.2/3.5.x; 12.2 e 12.5). Redação sugerida: "Os processos das funções de Relações estão em quatro blocos: …".
- Os dois links da versão 8.0 (apqc.org) NÃO ABRIRAM: o WebFetch teve a permissão retirada sem resposta e o curl recebeu HTTP 403. Não confirmo a data 27/02/2026 nem as 13 categorias da 8.0. Que a 7.4 tem 13 categorias está no próprio PDF ("13 enterprise-level categories").

## barcelona — CONFIRMADA
- amecorg.com abriu: AMEC, lançamento em julho de 2020; a página não traz o texto dos princípios, só links e anexos — exatamente como declarado.
- mepra.org abriu (notícia de 23/07/2020) e lista sete princípios. Conferem os quatro usados: 1 ("Setting goals is an absolute prerequisite to communications planning, measurement, and evaluation"); 2 (outputs, outcomes and potential impact); 4 (qualitative and quantitative); 5 ("AVEs are not the value of communication").
- A separação está feita: "usá-los também nas ações de demanda é leitura nossa". Nota menor: o princípio 1 inclui "evaluation"; "e não só a entrega" é paráfrase aceitável de "outputs, outcomes, and potential impact".

## iso22361 — CONFIRMADA
- iso.org abriu: ISO 22361:2022, "Security and resilience — Crisis management — Guidelines", publicada em 19/10/2022, edição 1. Resumo: orientação para planejar, estabelecer, manter, revisar e melhorar uma "strategic crisis management capability". Confere com "diretrizes para a capacidade de gestão de crises". O uso no protocolo da RE-08 está declarado como nosso, e a leitura só do resumo está dita.

## iso44001 — CONFIRMADA
- iso.org abriu: ISO 44001:2017, título exato confere, publicada em março de 2017; resumo fala em "identification, development and management of collaborative business relationships within or between organizations". A página marca a norma como "to be revised", com ISO/DIS 44001 em elaboração: confere com "em revisão". Separação entre o resumo da ISO e a origem das etapas (APQC) está feita.

## lgpd — CONFIRMADA EM PARTE
- planalto.gov.br abriu via WebFetch (o curl direto falhou). Lei nº 13.709, de 14 de agosto de 2018: confere.
- Art. 7º: I consentimento, V execução de contrato, IX legítimo interesse — confere. Art. 8º caput (por escrito ou outro meio que demonstre a vontade) e § 5º (revogável a qualquer momento) — confere. Art. 9º caput (acesso facilitado às informações sobre o tratamento) — confere. Art. 18, incisos I a VI e IX — confere.
- Também conferem os demais citados como lidos: art. 5º I, II, III, VI, VII e X (dado pessoal, sensível, anonimizado, controlador, operador, tratamento); art. 6º I–III (finalidade, adequação, necessidade); art. 15 caput (término do tratamento); art. 16 caput (eliminação após o término); art. 37 caput (registro das operações).
- Ajuste: a lista do art. 18 omite os incisos VII e VIII (informação sobre compartilhamento e sobre a possibilidade de não consentir) e não avisa que é parcial. O art. 18, IV fala de anonimizar, bloquear ou eliminar dados "desnecessários, excessivos ou tratados em desconformidade", não de quaisquer dados. Redação sugerida: "direitos do titular, entre eles confirmar a existência do tratamento, acessar, corrigir, anonimizar, bloquear ou eliminar dados desnecessários ou excessivos, portar, eliminar os dados tratados com consentimento e revogar o consentimento (art. 18, I a VI e IX)".

## nng_blueprint — CONFIRMADA
- Abriu. Sarah Gibbons, "Service Blueprints: Definition", 27/08/2017. Quatro elementos-chave: Customer actions, Frontstage actions, Backstage actions, Processes — confere. ("Ações à vista do cliente" traduz bem "frontstage".)

## nng_journey — CONFIRMADA EM PARTE
- Abriu. Sarah Gibbons, "Journey Mapping 101", 09/12/2018. A definição confere ao pé da letra. São cinco elementos: Actor; Scenario + Expectations; Journey Phases; Actions, Mindsets, and Emotions; Opportunities.
- Ajuste de tradução: "Mindsets" não é "pensamentos". Redação sugerida: "as ações, os modos de pensar (mindsets) e as emoções".

## reptrak — CONFIRMADA
- Abriu. A página é a "2026 Global RepTrak 100". Lista sete "Drivers of Reputation": Products & Services, Performance, Innovation, Leadership, Conduct, Citizenship, Workplace — confere com a tradução. Observação: na página, os sete fatores formam a dimensão "Think" de um modelo com três dimensões (Feel, Think, Do). Se quiser precisão, escrever "Sete fatores de reputação (a dimensão 'Think' do modelo)".

## Tabela de cobertura (c4.md) contra o PDF 7.4

| Linha | Resultado | Observação |
|---|---|---|
| 1.2.8 Develop customer experience strategy | certa | 1.2.8.1 Assess customer experience; 1.2.8.2 Design customer experience. Personas (1.2.8.2.1), journey maps (.2), validate with customers (.5) e align with brand values (.6) conferem |
| 3.2.3 Define and manage channel strategy | certa | |
| 3.2.5 Develop marketing communication strategy | certa | 3.2.5.4 Define internal marketing communication strategy: confere |
| 3.2.6 Design and manage customer loyalty program | certa | |
| 3.3.1 Establish goals, objectives, and measures for products and services | **errada** | O nome no PDF é "Establish goals, objectives, and measures for products/services by channel/segment". Corrigir para esse nome |
| 3.3.2 Establish marketing budgets | certa | |
| 3.3.4 Develop and manage promotional activities | certa | |
| 3.3.5 Track customer management measures | certa | |
| 3.3.6 Analyze and respond to customer insight | certa | |
| 3.3.8 Develop go-to-market strategy | certa | |
| 3.3.9 Manage product marketing material | certa | |
| 3.4.2 Develop sales partner/alliance relationships | certa | |
| 3.5.1 Manage leads/opportunities | certa | 3.5.1.1 a 3.5.1.3 (identificar clientes, receber e qualificar leads) e 3.5.1.4 (Match opportunities to business strategy) conferem com a divisão |
| 3.5.2 Manage customers and accounts | certa | 3.5.2.4 Manage customer relationships, 3.5.2.5 Manage customer master data e 3.5.2.2/3.5.2.3 (key account plan) conferem com a divisão |
| 3.5.5 Manage sales partners and alliances | certa | |
| 6.2.3 Manage customer complaints; 6.5 Evaluate customer service operations and customer satisfaction | certa | O PDF grafa "satisfacion" (erro do original); manter a grafia correta é aceitável |
| 12.2 Manage government and industry relationships | certa | 12.2.4 Manage lobby activities: confere |
| 12.5 Manage public relations program | certa | 12.5.1 community relations, 12.5.2 media relations, 12.5.4/12.5.5 press releases: conferem com imprensa, comunicados e comunidade |

Limite desta verificação: as páginas da APQC sobre a versão 8.0 não abriram (permissão de acesso não respondida; HTTP 403).
