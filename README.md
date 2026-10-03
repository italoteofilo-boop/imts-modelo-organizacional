# Ecossistema IMTS · Estrutura organizacional e operacional — pacote completo (03/10/2026)

Este pacote reúne o que foi produzido no projeto até 03/10/2026. Os nove círculos estão fechados: os círculos 1 a 6 com as
decisões do dono do projeto e os círculos 7 a 9 desenhados por delegação dele e aprovados por ele em 03/10/2026, às 11:50. São 73 jornadas; as 26 jornadas cross da rodada 2 viraram cadeias de jornadas conferidas nos dados.

## O que há em cada pasta

1-situacao-do-projeto/
  situacao-do-projeto.md ...... decisões, situação, consolidação das cross, alertas, jornadas, como o desenho foi
                                conferido e limites. Gerado da fonte do modelo.
  enderecos.txt ............... endereço do documento vivo do projeto e das nove páginas publicadas.
  documento-do-projeto/ ....... as sete abas do documento vivo em PDF compacto, num zip com MANIFESTO (SHA-256),
                                LEIA-ME e o conferidor. O texto atual das abas está em 5-leitura-por-circulo/.

2-paginas/ .................... as nove páginas publicadas: jornadas, etapas, tarefas, entradas, saídas, fluxos,
                                fronteiras, decisões, método, fontes e o que mudou. Abra no navegador. Os fluxos e as
                                letras são carregados da internet (bpmn-js e fontes); sem conexão, o texto aparece e os
                                diagramas não.

3-fluxos-bpmn/
  circulo-N-.../bpmn/ ......... um arquivo BPMN 2.0 por jornada (73 ao todo). Abre em Camunda Modeler, bpmn.io e similares.
  circulo-N-.../diagramas-svg/  o desenho de cada fluxo em SVG, para ver sem ferramenta de BPMN.
  circulo-N-.../LEIA-ME.txt ... como ler os fluxos e os testes daquela versão.
  circulo-N-.../*-fonte.json .. a mesma informação em dados.

4-modelo-fonte/
  c1.py a c9.py ............... a fonte única de cada círculo (jornadas, etapas, tarefas, entradas, saídas, textos).
  c4p/ a c9p/ ................. os fragmentos de que o c4.py a c9.py são montados (python3 <pasta>/montar.py). O c1.py, o c2.py e o c3.py são editados direto.
  dsl.py, fontes.py, circulos.py, gerar.py, testar.py, cruzar.py, consolidar.py, mutacao.py, auditar.py, rotular.py, alcadas_fluxo.py, pagina.py, revisao.py, empacotar.py
                                o gerador, os testes, o cruzamento e a consolidação entre círculos, a prova dos testes e as páginas.
  ferramentas-node/ ........... scripts de validação e desenho (bpmn-moddle, bpmnlint, bpmn-js). Rode npm install antes.
  supabase/ ................... esquema e carga do modelo para o Supabase (esquema org), com o gerador e o LEIA-ME.
  fontes_oficiais/ ............ texto literal dos dispositivos legais citados (retrato de 03/10/2026) e o conferidor de contingência.
  dados-gerados/ .............. circulo.json e testes.json de cada círculo, cruzamento.json, consolidacao.json e auditoria.json.

5-leitura-por-circulo/
  c1.md a c9.md ............... cada círculo em texto corrido, etapa a etapa, na ordem em que o fluxo roda.
  cruzamento.md ............... as trocas entre os nove círculos.
  consolidacao.md ............. as cadeias que substituem as jornadas cross da rodada 2.
  parametros_em_aberto.md ..... as alçadas, cadências, regras e fontes que faltam, com quem decide cada uma.
  auditoria_execucao.md ....... a auditoria das etapas pelo modo de execução (pessoa, agente, automação), o que foi aplicado e os números atuais (seção 8).
  auditoria_geral.md .......... a auditoria geral da versão inicial (três revisores independentes) e as correções aprovadas às 16:05.
  gates_implantacao.md ........ os nove gates de setup da implantação e os rascunhos validados das 34 cadências e dos 14 conteúdos.
  propostas_parametros.md ..... as alçadas, o método de estratégia, a alçada da Governança e as regras gerais de contrato, aprovados em 03/10/2026, com a tabela matéria × órgão (seção 5).
  fase2_plano.md .............. o plano da fase 2 (runtime por círculo, ML, Telegram, painel, simulador), para aprovação.
  fontes_c3.md a fontes_c9.md . as fontes dos círculos 3 a 9, com o que usamos de cada uma e como foi conferida.

6-revisoes-independentes/ ..... os relatórios dos revisores independentes (agentes que não participaram do desenho),
                                as verificações das correções e os pedidos feitos a eles.

7-historico/ .................. as versões superadas num zip só, com MANIFESTO (SHA-256), LEIA-ME e o conferidor: base e
                                catálogo da rodada 2, círculo 1 de treze jornadas, módulos anteriores e fragmentos do c2.

8-notas-de-trabalho/ .......... as notas das rodadas, com as respostas literais do dono do projeto e a triagem das revisões.

## O que não está no pacote

- A versão viva do documento do projeto continua no endereço em 1-situacao-do-projeto/enderecos.txt; aqui vai a exportação.
- O Soul Brand e os documentos de terceiros baixados para conferir as fontes (normas, leis e o referencial da APQC):
  não são material gerado pelo projeto. Os links de cada fonte estão na aba Fontes de cada página e em 4-modelo-fonte/fontes.py.
- As bibliotecas de terceiros (node_modules) e as capturas de tela usadas para conferir as páginas.

## Situação em 03/10/2026

- Círculos 1 a 6: fechados com as decisões do dono do projeto; todas as propostas aprovadas foram aplicadas.
- Círculos 7 (Operações, 8 jornadas), 8 (Gestão, 13) e 9 (Governança, 10): fechados e aprovados às 11:50 de 03/10/2026.
- Duas propostas ao círculo 6, aprovadas às 11:50: IT-04 recebe as entregas encerradas de Operações; IT-06 recebe o desvio de agente apontado pela auditoria.
- Em 03/10/2026, às 13:09, o dono do projeto decidiu os temas P2 (ele lidera a Identidade) e P6 (como recomendado), deu dono aos três itens sem dono e confirmou que cadências e regras de cada círculo ficam com o líder dele. As alçadas, o método de estratégia, a alçada da Governança e as regras gerais de contrato foram propostos e aprovados às 13:51 (5-leitura-por-circulo/propostas_parametros.md) e aplicados nos círculos e em parametros_em_aberto.md. O que resta de parâmetros é preenchido pelo líder de cada círculo, na implantação; a regra fiscal depende do regime de cada empresa. As quatro fontes que faltavam foram lidas; a última transcrição secundária (Resolução CD/ANPD nº 15/2024) foi conferida na fonte oficial às 17h (G5 cumprido).
- Auditoria de execução (03/10/2026): 290 etapas conferidas; as 14 propostas foram aprovadas às 12:33 e aplicadas (5-leitura-por-circulo/auditoria_execucao.md, seção 7). Os testes passaram a cobrar o modo de cada etapa e o nível de automação de cada jornada.
- Em 03/10/2026, às 14:07, o dono do projeto validou as 33 cadências e os 14 conteúdos em rascunho e os 9 gates de implantação (gates_implantacao.md); tudo foi aplicado nos círculos e em parametros_em_aberto.md. A base de dados do modelo está pronta em 4-modelo-fonte/supabase, testada em Postgres 16 local.
- Em 03/10/2026, às 16:05, o dono do projeto aprovou as correções da auditoria geral (5-leitura-por-circulo/auditoria_geral.md) e assumiu o papel de Administrador do IMTS.OS, acima dos círculos compartilhados. Aplicadas nos fluxos e nos textos, com dois testes novos: segregação na saída de dinheiro e alçadas no fluxo.
- Testes: todos os círculos sem falha; 410 trocas entre os círculos conferidas dos dois lados, sem problema; 17 alçadas com 40 níveis conferidos no fluxo, sem falta.
- As correções das 16:05 passaram por todos os testes automáticos.
- Em 03/10/2026, fim da tarde: G5 cumprido; as fontes legais ganharam retrato literal (4-modelo-fonte/fontes_oficiais), conferidor de contingência rodando nos testes e reconferência mensal agendada; as exportações do documento voltaram em PDF compacto com manifesto; as versões superadas foram compactadas em 7-historico, com manifesto e conferidor.
