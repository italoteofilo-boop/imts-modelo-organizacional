# Auditoria de execução

Conferência das 73 jornadas, 290 etapas e 1.482 tarefas dos nove círculos pelo modo de execução: quem faz cada tarefa (pessoa, agente, automação) e se o modo declarado de cada etapa bate com o que as tarefas fazem. Feita em 03/10/2026 sobre o modelo aprovado às 11:50. Script: modelo/auditar.py; dados: saida/auditoria.json. As correções propostas (seção 6) foram aprovadas e aplicadas (seção 7).

## 1. Critério

Os quatro modos do modelo, com a regra que os testes já cobram em cada círculo:

| Modo | Regra do modelo |
|---|---|
| Assistido | Pessoa conduz; pode ter ou não apoio de máquina |
| Copiloto | Agente ou automação e uma pessoa no caminho |
| Autopiloto | Agente ou automação; nenhuma pessoa do círculo no caminho principal |
| Autômato | Só automação; nenhuma pessoa nem agente do círculo |

Risco alto só admite Assistido ou Copiloto.

A auditoria lê as tarefas e dá a cada etapa uma classe real:
- Exclusivamente humana: nenhuma tarefa de máquina.
- Assistida: pessoa e máquina no caminho principal, pessoa com mais tarefas.
- Copiloto: pessoa e máquina no caminho principal, máquina com tantas tarefas quanto a pessoa ou mais.
- Autopiloto: há agente; pessoa só fora do caminho principal ou nenhuma.
- Autômata: só automação.
- Conduzida por outros círculos: o caminho principal é todo de outros círculos.

Contam como pessoa: a pessoa do círculo, a de fora do círculo (sócio, executivo, líder, cliente) e a assessoria. Tarefa de outro círculo não conta como pessoa nem como máquina, porque o modo dela é decidido no círculo que a executa.

A divisão Assistida/Copiloto por maioria de tarefas é critério desta auditoria. O modelo não a define (ver 6.3).

## 2. Quem faz as tarefas

| Círculo | Tarefas | Pessoa do círculo | Pessoa de fora ou assessoria | Agente | Automação | Outro círculo |
|---|---|---|---|---|---|---|
| Identidade | 99 | 27 | 7 | 26 | 21 | 18 |
| Estratégia | 198 | 50 | 17 | 33 | 73 | 25 |
| Inteligência | 287 | 56 | 13 | 55 | 115 | 48 |
| Relações | 188 | 48 | 16 | 34 | 67 | 23 |
| Negócios | 172 | 29 | 20 | 22 | 67 | 34 |
| Integração | 161 | 27 | 10 | 25 | 76 | 23 |
| Operações | 123 | 27 | 8 | 34 | 49 | 5 |
| Gestão | 150 | 36 | 22 | 39 | 51 | 2 |
| Governança | 104 | 27 | 7 | 25 | 42 | 3 |
| **Total** | **1.482** | **327** | **120** | **293** | **561** | **181** |

Das 1.301 tarefas que cada círculo faz com os próprios meios (sem contar as de outro círculo), 854 são de máquina (66%): 561 de automação e 293 de agente. As outras 447 são de pessoa (34%).

## 3. Etapas por modo: declarado e real

| Declarado → real | Copiloto | Assistida | Autopiloto | Autômata | Exclusivamente humana | Outros círculos | Total |
|---|---|---|---|---|---|---|---|
| Copiloto | 127 | 35 | 1 | – | – | – | 163 |
| Assistido | 9 | 13 | – | – | 5 | 2 | 29 |
| Autopiloto | – | – | 62 | 20 | – | – | 82 |
| Autômato | – | – | – | 16 | – | – | 16 |
| **Total real** | **136** | **48** | **63** | **36** | **5** | **2** | **290** |

O que a tabela mostra:
- **Copiloto declarado e Assistida real (35)** e **Assistido declarado e Copiloto real (9)**: as duas leituras cabem na regra do modelo. Divergem só no critério de maioria desta auditoria (6.3).
- **Autopiloto declarado e Autômata real (20)**: cabe na regra do modelo, porque Autopiloto aceita só automação. O rótulo Autômato seria mais preciso (6.3).
- **Copiloto declarado e Autopiloto real (1)**: ES-03 etapa 3. É a única etapa em que o modo declarado não confere pela própria regra (4.2).

Etapas exclusivamente humanas (5). Todas estão declaradas Assistido, e todas são por desenho:

| Etapa | Por quê |
|---|---|
| ID-04 etapa 3 · Validar o posicionamento com Estratégia, Relações, Gestão e executivos | Validação entre pessoas |
| RE-04 etapa 3 · Validar com clientes e decidir a estratégia de experiência | Conversa com cliente e decisão |
| GE-08 etapa 3 · Conectar a pessoa à comunidade | Relação entre pessoas |
| GE-10 etapa 3 · Realizar o ritual | Ritual presencial |
| GO-09 etapa 2 · Apurar o relato e decidir a medida | Denúncia: só pessoa apura e decide |

Etapas conduzidas por outros círculos (2): ES-05 etapas 3 e 7. Ver 4.1.

## 4. Achados

60 achados: 4 graves, 1 médio, 55 leves. Abaixo, com o meu julgamento de cada um: se é defeito ou se é por desenho.

### 4.1 Graves

| Onde | Achado | Julgamento |
|---|---|---|
| ES-05 etapa 3 · Apurar a empresa ou o negócio e negociar | Risco alto. No caminho principal estão só Governança e Gestão. A pessoa da Estratégia só entra nos ramos condicionais (negociar, propor arquivar). | **Defeito.** A Estratégia é dona da etapa e não tem tarefa sua no caminho principal que consolide a apuração. |
| ES-05 etapa 7 · Executar o mandato | Risco alto. O caminho principal é de Integração, Governança e Gestão. | **Por desenho.** A execução do mandato é coordenada pela Integração (IT-04), onde há pessoa no caminho principal. A Estratégia acompanha pelo informe da Integração. |
| IT-08 etapa 1 · Medir a jornada e achar o gargalo | O agente escolhe as jornadas a medir. | **Defeito de atribuição.** Escolher é julgamento. O risco é baixo, mas no resto do modelo nenhuma tarefa de agente ou automação escolhe ou decide (seção 5). |
| OP-08 etapa 3 · Liberar os recursos e guardar o conhecimento | O verbo "Liberar" na automação. | **Defeito de redação.** A decisão de encerrar já foi tomada nas etapas anteriores; a automação só executa e registra. |

### 4.2 Médio

| Onde | Achado | Julgamento |
|---|---|---|
| ES-03 etapa 3 · Conferir com a Gestão e a Integração se os alvos cabem nos recursos | Declarada Copiloto; no caminho principal só há Gestão, Integração e o agente. A pessoa da Estratégia só entra se não couber e não houver acordo. | **Defeito.** Pela regra do modelo, Copiloto pede pessoa no caminho. Ou entra uma tarefa de pessoa no caminho principal, ou o modo passa a Autopiloto. Recomendo a tarefa de pessoa: a conferência fecha os alvos do ciclo. |

### 4.3 Leves

**Decisão do caminho tomada pelo agente em etapa de risco médio ou alto (46).** Separei em dois grupos.

Regra objetiva, por desenho (41). São conferências contra um padrão publicado, cálculos ou verificações de existência. Exemplos: "está conforme os padrões de identidade?", "há resposta registrada e válida?", "os valores batem?", "o produto passou no teste?".

Julgamento, a corrigir (5):

| Onde | Decisão | Por quê |
|---|---|---|
| OP-07 etapa 1 | O defeito relatado pode pôr em risco a saúde ou a segurança? | Erro aqui atrasa recall e comunicação à autoridade. É o mais forte dos cinco. |
| OP-07 etapa 1 | O pedido está coberto? | Negar garantia ao cliente é decisão com efeito para o cliente. A negativa deve passar por pessoa. |
| RE-08 etapa 1 | O sinal pode virar crise pelo critério do protocolo? | O critério de crise ainda não está escrito (Parâmetros em aberto). Até lá, é julgamento. |
| RE-03 etapa 1 | O contato tem base legal para ser abordado? | Base legal da LGPD (art. 7º) em caso não óbvio é julgamento jurídico. |
| GO-05 etapa 1 | Há cláusula fora do modelo ou risco relevante? | "Risco relevante" não tem critério objetivo no modelo. |

**Copiloto em que a pessoa no caminho é de fora do círculo (5)**: IN-08 etapa 3, OP-02 etapa 3, GE-04 etapa 3, GE-08 etapas 2 e 4. **Por desenho.** Quem acompanha a máquina é o cliente, o líder ou o executivo que recebe ou aprova; o modelo admite pessoa de fora como a pessoa do Copiloto.

**Nível de automação da jornada não bate com a parcela de tarefas de máquina (4).** A parcela conta as tarefas da própria jornada:

| Jornada | Declarado | Tarefas de máquina | Julgamento |
|---|---|---|---|
| IT-04 | baixa | 64% | Rótulo errado: passa a média |
| IN-03 | alta | 62% | Dentro da faixa de média |
| IT-07 | alta | 58% | Dentro da faixa de média |
| GE-06 | alta | 57% | Dentro da faixa de média |

O modelo não define faixas para baixa, média e alta. A comparação foi feita com as outras jornadas: cada uma dessas fica fora da faixa observada no seu nível. Ver 6.3.

## 5. O que está bem

- Nenhuma etapa de risco alto em Autopiloto ou Autômato. Os testes já cobram isso nos nove círculos.
- Nenhuma tarefa de agente ou automação começa com verbo de decisão (Decidir, Aprovar, Julgar, Escolher, Autorizar, Calibrar, Liberar), fora os dois casos de 4.1.
- Das 47 etapas de risco alto, 45 têm pessoa no caminho principal. As duas que não têm são as de ES-05 (4.1).
- 36 etapas são automação pura e 63 são autopiloto: um terço das etapas roda sem pessoa no caminho principal, todas de risco baixo ou médio.

## 6. Propostas para aprovação

Aprovadas às 12:33 de 03/10/2026 e aplicadas. O que saiu diferente na aplicação está na seção 7.

### 6.1 Defeitos

| # | Onde | Mudança |
|---|---|---|
| 1 | ES-05 etapa 3 | Acrescentado: tarefa da pessoa da Estratégia no caminho principal, depois das apurações: "Consolidar a apuração e decidir se o caso segue para negociação ou para arquivo". |
| 2 | ES-03 etapa 3 | Acrescentado: tarefa da pessoa da Estratégia no caminho principal: "Confirmar que os alvos e as iniciativas cabem nos recursos". O modo segue Copiloto. |
| 3 | IT-08 etapa 1 | Ajustado: o agente "Propor as jornadas do ciclo pela recomendação, pela lacuna e pelos indicadores". Acrescentado: a pessoa da Integração "Decidir as jornadas do ciclo". O modo passa de Autopiloto a Copiloto. |
| 4 | OP-08 etapa 3 | Ajustado: "Liberar pessoas, agentes, parceiros e ativos…" passa a "Registrar a liberação de pessoas, agentes, parceiros e ativos alocados ao cliente ou à oferta". |

### 6.2 Decisões de julgamento que saem do agente

| # | Onde | Mudança |
|---|---|---|
| 5 | OP-07 etapa 1, risco à saúde ou à segurança | Ajustado: a decisão passa à pessoa de Operações. O agente faz a triagem e aponta. Sem certeza, a resposta é "Sim". |
| 6 | OP-07 etapa 1, cobertura | Acrescentado: quando o agente aponta "não coberto", a pessoa de Operações confirma antes da resposta ao cliente. |
| 7 | RE-08 etapa 1 | Acrescentado: ramo "Dúvida" que leva o sinal à pessoa de Relações. |
| 8 | RE-03 etapa 1 | Acrescentado: ramo "Dúvida" que leva à pessoa de Relações, com consulta à Governança. |
| 9 | GO-05 etapa 1 | Ajustado: a decisão "Há cláusula fora do modelo ou risco relevante?" passa à pessoa da Governança. O agente aponta as diferenças em relação ao modelo. |

### 6.3 Rótulos e critérios (decisão sua)

| # | Ponto | Proposta |
|---|---|---|
| 10 | Nível de automação de IT-04 | Ajustado: baixa → média. |
| 11 | Nível de automação de IN-03, IT-07 e GE-06 | Ajustado: alta → média. |
| 12 | Critério de nível de automação | Acrescentado ao documento-base: baixa até 1/3 das tarefas de máquina, média até 2/3, alta acima de 2/3. É critério novo, sem fonte externa. Se você aprovar, o teste passa a cobrar e eu reviso as 73 jornadas pelo critério. |
| 13 | Copiloto x Assistido | Acrescentado ao documento-base: "Copiloto: a máquina faz a maior parte e a pessoa confere ou decide. Assistido: a pessoa faz a maior parte com apoio da máquina". Se você aprovar, 44 etapas mudam de rótulo (35 de Copiloto para Assistido e 9 de Assistido para Copiloto). O que as tarefas fazem não muda. |
| 14 | Autopiloto só com automação | Ajustado: as 20 etapas em Autopiloto sem agente passam a Autômato. O que as tarefas fazem não muda. |

Itens 1 a 9 corrigem defeitos. Itens 10 a 14 são de precisão de rótulo e podem ficar como estão, sem risco para a operação.

## 7. Aplicação (aprovada às 12:33 de 03/10/2026)

As 14 propostas foram aprovadas e aplicadas. Os testes dos nove círculos, o cruzamento (406 trocas) e a consolidação (cadeias sem falha) passaram de novo.

Onde a aplicação saiu diferente do texto proposto:

| # | O que mudou na aplicação | Por quê |
|---|---|---|
| 1 | A tarefa ficou "Consolidar o resultado da apuração para decidir se o caso segue". | A decisão de seguir ou arquivar já existe no fim da etapa, depois da negociação; a tarefa nova prepara essa decisão. |
| 2 | "Confirmar se", no lugar de "Confirmar que". | A resposta pode ser não; a decisão seguinte já trata esse caso. |
| 5 | Entraram duas tarefas no caminho principal: o agente faz a triagem e a pessoa decide. Na dúvida, a resposta é "Sim". | A etapa OP-07 1 passou de Autopiloto a Copiloto. |
| 7 | Não mudou nada. | A RE-08 etapa 1 já manda "gravidade alta ou dúvida" para a etapa 2, onde a pessoa de Relações apura. O achado da seção 4.3 estava errado neste ponto. |
| 8 | A pessoa de Relações decide na dúvida. A consulta à Governança não virou troca formal. | Para virar troca, a Governança teria de receber um pedido novo, e isso seria mudança no círculo 9 que não foi proposta. |
| 12 | Aplicado às 73 jornadas: 27 mudaram de nível. Nos rótulos compostos, o nível da faixa vem primeiro e o rótulo antigo segue entre parênteses. | Ver a lista abaixo. |
| 14 | 19 etapas passaram a Autômato, não 20. | A vigésima era a IT-08 etapa 1, que passou a Copiloto pelo item 3. |

Níveis de automação mudados (item 12): ID-01 baixa → média; ID-02 → média (alta nas consultas, média na redação); ID-04 média → baixa; ID-05 média → alta; ES-01 baixa → média; ES-05 baixa → média; ES-06 média → alta; IN-01 média → alta; IN-03 alta → média; IN-08 média → alta; RE-02 → média (alta na execução, média na preparação); RE-08 → média (alta na coleta, baixa na crise); IT-04 baixa → média; IT-05 média → alta; IT-06 média → alta; IT-07 alta → média; IT-08 média → alta; OP-02 média → alta; OP-05 média → alta; GE-05 média → alta; GE-06 alta → média; GE-12 média → alta; GO-03 média → alta; GO-06 média → alta; GO-07 média → alta; GO-08 baixa → média; GO-09 baixa → média.

O que os testes passaram a cobrar em cada círculo:
- O modo declarado tem de ser o que as tarefas dão.
- Etapa de risco alto tem pessoa no caminho principal, salvo quando o caminho todo é de outros círculos.
- Agente e automação não têm tarefa que começa com verbo de decisão.
- O nível de automação de cada jornada tem de cair na faixa.

A prova dos testes ganhou três defeitos plantados: agente que decide, nível de automação errado e Copiloto rotulado como Assistido. Os 20 defeitos plantados são detectados em cada círculo.

Depois da aplicação:

| Modo | Etapas |
|---|---|
| Copiloto | 139 |
| Autopiloto | 61 |
| Assistido | 55 |
| Autômato | 35 |
| **Total** | **290** |

- O modo declarado bate com as tarefas em todas as 290 etapas.
- As 47 etapas de risco alto têm pessoa no caminho principal, menos a ES-05 etapa 7, que é por desenho (4.1).
- Seguem como apontamento leve, sem defeito:
  - 44 decisões de caminho na raia do agente. São 41 de regra objetiva e 3 em que o agente faz a triagem e a pessoa trata a dúvida ou a negativa: RE-03, RE-08 e a cobertura da OP-07.
  - 6 etapas de Copiloto com pessoa de fora do círculo.
