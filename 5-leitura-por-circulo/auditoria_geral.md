# Auditoria geral da versão inicial

Feita em 03/10/2026, a seu comando, sobre o repositório `imts-modelo-organizacional` (commit 3381fa7). Três revisores independentes, que não participaram do desenho, fizeram cada um uma parte:

- **Revisor 1:** coerência entre os arquivos.
- **Revisor 2:** fontes e afirmações, com conferência na web, no texto oficial.
- **Revisor 3:** desenho organizacional.

Conferi cada achado grave no arquivo ou no dado de origem antes de registrá-lo aqui. Nada foi mudado. As correções estão na seção 5, para sua aprovação.

## 1. Conclusão

A versão inicial **ainda não está em 100%**. O que já está certo:

- **Estrutura:** todas as contagens batem entre os dados, as páginas, os fluxos BPMN, o cruzamento, a consolidação e a base no Supabase. São 73 jornadas, 290 etapas, 1.490 tarefas, 406 trocas, 26 cadeias e 47 elos.
- **Leis e normas:** nenhuma foi inventada. Todos os prazos legais conferidos no texto oficial batem: Resolução CD/ANPD nº 15/2024, Lei 14.133, CLT, Código Civil e Lei do FGTS.
- **Vocabulário:** não há uma única ocorrência de "meta" no sentido de alvo.

O que falta:

- **Desenho:** a revisão encontrou quatro defeitos graves numa camada que nenhum teste cobria. O teste verificava se há pessoa na etapa. Não verificava qual pessoa é, nem se ela fiscaliza a si mesma.
- **Textos desatualizados:** parte dos textos ainda diz que coisas aprovadas hoje estão em aberto, e parte das fontes cita mais artigos do que o registro declara como lidos.

## 2. Desenho: defeitos graves (Revisor 3, conferidos)

| # | Defeito | Evidência |
|---|---|---|
| D1 | **Os sócios não estão definidos.** A raia "Sócios" não distingue os sócios do Ecossistema dos sócios de cada empresa. A pendência foi passada ao círculo 9, que fechou sem resolvê-la. | c2.md, limite 894: "Quem delibera o quê fica para o círculo 9". Não há tratamento em c9.md, nos parâmetros nem nas propostas. |
| D2 | **Não há dono acima dos círculos.** Os círculos atendem a todas as empresas e são rateados, mas toda escalada vai ao "executivo da empresa". Uma decisão sobre recurso de um círculo compartilhado não tem a quem subir. | Alçada GE-01: "Entre círculos: executivo". Não existe executivo do Ecossistema. |
| D3 | **Dinheiro sai com uma pessoa só, contra a alçada aprovada** ("quem lança não aprova; todo pagamento com duas pessoas"). | GE-04: a mesma raia Gestão · pessoa escolhe o fornecedor (etapa 2) e aprova o pagamento (etapa 5). GE-13: só a Gestão confere e aprova a folha. A GE-09 decide mudanças de remuneração que entram na folha que a própria Gestão aprova. GE-05, etapa 3, de risco alto: mudança de contas sem a Governança. GE-03: o reembolso é pago pela automação, sem aprovação na Gestão. |
| D4 | **O canal de relatos não é independente quando a denúncia é contra a Governança.** | GO-09, etapas 1 e 2: a pessoa da Governança confirma a classificação, decide "Quem está envolvido no relato?" e apura os fatos. |

## 3. Desenho: defeitos médios e leves (Revisor 3)

**Médios (11)**
- **M1. Alçadas aprovadas que não viraram ramo no fluxo:**
  - aumento do orçamento (GE-01);
  - compra acima da reserva (GE-04);
  - desligamento de executivo ou de líder (GE-07);
  - risco de 15 ou mais aos sócios (GO-03);
  - regras de contrato que vão aos sócios (GO-05 e NE-04);
  - a Governança na compensação acima da alçada (OP-04).
- **M2. A Governança define a própria alçada.** Ela classifica quem decide cada regra (GO-01) e define a alçada das pessoas do próprio círculo.
- **M3. Não há terceira linha.** A Governança audita inclusive o próprio trabalho. O agente classifica como conformes entregas que nenhuma pessoa revê (GO-06). O agente também decide se outro agente tem desvio (IT-06, etapa 4).
- **M4. A crise tem dono duplo.** A cadeia C11 diz que a Governança decide; o fluxo da GO-08 diz que o executivo aprova.
- **M5. Os limites dos agentes têm três donos:** a ID-02, a GO-01 e os sócios.
- **M6. A comissão sai do contrato vendido, e não da receita recebida.** A GE-13 não recebe o recebimento, contra a regra aprovada no item 2.5.
- **M7. A suspensão por atraso não tem ramo.** A GE-03 não prevê a suspensão nem avisa Operações.
- **M8. Escaladas não voltam.** Seis saídas para executivos ou sócios não têm retorno, entre elas a remediação na GO-03 e o pedido do titular de dados na GO-07, que tem prazo da LGPD.
- **M9. O "desvio grave" não tem critério.** Ele abre a ES-06, mas o método aprovado não o define e a GE-02 não o aponta.
- **M10. A alçada da ES-04 é só por recurso.** Encerrar uma oferta com contratos vigentes fica com a Estratégia sozinha.
- **M11. Os gates estão fora de ordem.** O G6 (ratificação pelos sócios) vem depois do G3, que já usa as alçadas ratificadas.

**Leves (9)**
- **L1.** O texto "Muda alvo: Estratégia" da alçada da GE-02 está em desacordo com o fluxo.
- **L2.** O portfólio usa dois vocabulários: "semear, nutrir, podar, colher" e "crescer, manter, reduzir, estudar a saída".
- **L3.** O c2.md ainda diz que o método "não foi escrito".
- **L4.** A revisão do meio do ciclo da ES-01 não tem evento de início.
- **L5.** A cadência da GO-02 tem dois donos.
- **L6.** A assinatura de compra e venda de empresa pelos sócios não está escrita como exceção na regra 2 dos contratos.
- **L7.** Na GE-02 e na GE-09, o fim do fluxo não distingue o caso com pendência.
- **L8.** O ajuste dispensado da IN-07 não é avisado à Estratégia.
- **L9.** Na GO-02, um agente filtra o que chega aos sócios.

**Escolhas de desenho que o revisor confirmou como legítimas:**
- a ES-05, etapa 7, conduzida pela Integração;
- a Estratégia como dona do portão;
- a NE-05 com o executivo assinando;
- o Copiloto com pessoa de fora do círculo;
- o recebimento conferido por quem pediu (GE-04).

## 4. Coerência e fontes (Revisores 1 e 2)

**Textos desatualizados ou contraditórios**
- **Arquivos exportados do documento** (`1-situacao-do-projeto/documento-do-projeto/`: Documento-base e PDF dos Parâmetros) mostram a situação de antes das 13:09:
  - P6 aparece como aberto;
  - as alçadas aparecem sem valor;
  - as fontes aparecem como não lidas.
- **c2.md, limites 892 a 894 e alertas:** ainda dizem que o método e as alçadas "não existem".
- **c5.md, linha 708, e fontes_c5.md:** dizem que a Lei 14.133 não foi conferida, ao contrário do registro de fontes.
- **fontes_c7.md e fontes_c8.md:** não trazem o Código Civil, a CLT, o FGTS nem a Lei 14.133. O texto corrido não foi gerado de novo.
- **c9.md, limite 654:** diz que a amostra não tem regra, ao contrário da validação das 14:07.
- **auditoria_execucao.md:** ainda dá 1.482 tarefas, e o número correto é 1.490.
- **Aba de gates e parametros_em_aberto.md:** os gates ainda aparecem como "para validar", e o parâmetros conta 13 conteúdos onde os outros arquivos contam 14.
- **situacao-do-projeto.md:** a proposta da ID-03 aparece como "não aplicada", embora tenha sido aprovada e aplicada às 09:30.
- **Remissões ao círculo 9 já fechado e pequenos restos de texto:** o Revisor 1 achou 9 itens leves.
- **Caminhos `saida/` que não existem no repositório:** aparecem no COMO-RODAR, no LEIA-ME do Supabase e nos geradores.

**Fontes**
- **Citações além do que o registro declara como lido:**
  - Lei 14.133, art. 17, §§ 1º e 2º (o conteúdo confere com o texto oficial);
  - elementos do APQC das categorias 8 e 13 no círculo 6;
  - os números 10,2% e 7,8% do artigo da McKinsey, que o revisor não achou na página.
- **Leituras em transcrição secundária usadas sem a marca:** nos USO dos círculos 7, 8 e 9, em gates_implantacao.md, em parametros_em_aberto.md e em c8.md.
- **Resumos imprecisos da Lei 14.133:**
  - art. 86 sem o § 3º, que limita a adesão entre municípios e pesa nas vendas a prefeituras;
  - art. 140 sem a diferença entre compras e serviços;
  - art. 165 generalizado.
- **Faixas largas demais:** "arts. 82 a 165" e "1.179 a 1.194", quando os artigos lidos são isolados.

**Oportunidade:** o Revisor 2 abriu inteiros no texto oficial a Resolução CD/ANPD nº 15/2024 (Diário Oficial) e a Lei 14.133, o Código Civil e a CLT (Planalto). Com isso, dá para trocar as transcrições pelas fontes oficiais e fechar o gate G5 nos artigos conferidos.

## 5. Correções propostas, para aprovação

| # | Bloco | O que muda |
|---|---|---|
| 1 | Coerência | Exportar de novo o Documento-base e os Parâmetros. Gerar de novo c1.md a c9.md e fontes_c3.md a fontes_c9.md. Corrigir os textos desatualizados da seção 4, os caminhos `saida/` e os números da auditoria de execução. |
| 2 | Fontes | Trocar as transcrições pelas fontes oficiais nos artigos conferidos. Registrar os artigos efetivamente lidos e marcar como secundário só o que continuar secundário. Completar os resumos dos arts. 86, 140 e 165. Localizar os números da McKinsey ou retirá-los. Conferir os elementos do APQC no círculo 6. Fechar o G5 no que estiver conferido. |
| 3 | D1 e D2: sócios e dono acima dos círculos | Criar uma tabela "matéria × órgão": sócios da holding ou sócios de cada empresa. Criar o papel de executivo do Ecossistema, dono dos recursos dos círculos compartilhados. Ou declarar que esse papel é dos sócios da holding: decisão sua. |
| 4 | D3: segregação no dinheiro | Na Gestão, quem prepara e quem aprova passam a ser papéis diferentes. A folha e a remuneração da própria Gestão passam a ter o executivo como segundo aprovador. A mudança de contas passa a ter sempre o executivo com a Governança. O reembolso passa pela aprovação de pagamento. Novo teste: ato de saída de dinheiro não pode ser preparado e aprovado pela mesma raia. |
| 5 | D4: relatos | Na GO-09, quando a denúncia cita a Governança, a classificação e a apuração vão à assessoria externa ou a quem os sócios designarem. |
| 6 | Médios M1 a M10 | Acrescentar os ramos de alçada que faltam. Novo teste: cada linha da tabela de alçadas precisa ter uma tarefa no fluxo. Também: roteamento da GO-01 por regra objetiva; auditoria externa periódica da Governança, com amostra dos conformes do agente revista por pessoa; dono único da crise e dos limites dos agentes; comissão sobre a receita recebida; ramo de suspensão por atraso; retorno das escaladas; critério de desvio grave no método; alçada por tipo de decisão na ES-04. |
| 7 | M11 e leves | O G6 passa para antes do G3. Os 9 itens leves de desenho são corrigidos. |

Os blocos 1 e 2 não mudam o desenho. Os blocos 3 a 7 mudam fluxos já aprovados: depois de aplicá-los, rodo de novo os testes, o cruzamento, a auditoria de execução e a base no Supabase.

## 6. Aplicação (aprovada por você em 03/10/2026, às 16:05)

Você aprovou os sete blocos e assumiu o papel de **Administrador do IMTS.OS**, dono acima dos círculos compartilhados.

| # | O que foi feito |
|---|---|
| D1 | Tabela matéria × órgão: sócios do Ecossistema, sócios de cada empresa, Administrador do IMTS.OS e executivo (aba Propostas de parâmetros, seção 5). Cobre todas as jornadas com decisão dos sócios; o teste de alçadas confere isso. |
| D2 | O Administrador do IMTS.OS entra como papel. Decide o recurso dos círculos compartilhados (GE-01), as contas do IMTS.OS (GE-05), e as pessoas, a remuneração e a folha dos círculos (GE-07, GE-09, GE-13). |
| D3 | Quem prepara não aprova:<br>- O líder do círculo aprova pagamento, reembolso, fechamento e impostos (GE-03, GE-04, GE-05).<br>- A folha e a remuneração têm o executivo, ou o Administrador, como segundo aprovador.<br>- A mudança de contas passa sempre pela Governança.<br>Teste novo: uma etapa com pagamento feito por máquina precisa de aprovação de outra pessoa, que não a que prepara: o líder do círculo, o executivo, o Administrador ou outro círculo. O teste tem um defeito plantado próprio, detectado nos nove círculos. O acerto rescisório é pago pela folha, com o segundo aprovador dela. |
| D4 | GO-09: o relato que cita a Governança, desde o recebimento ou quando aparece na apuração, vai à assessoria externa. A assessoria apura, comunica à autoridade e responde a quem relatou; os sócios decidem a medida; o caso fica em registro à parte, sem acesso da Governança. |
| M1 | Ramos novos:<br>- GE-01: aumento do total, aos sócios.<br>- GE-04: acima da reserva, aos sócios.<br>- GE-07: desligamento de executivo ou de líder, aos sócios.<br>- GO-03: nota 15 ou mais, aos sócios.<br>- GO-05 e NE-04: regra 10 dos contratos, aos sócios.<br>- OP-04: a Governança avalia antes do executivo.<br>Teste novo: 17 alçadas, 40 níveis, sem falta. A prova embutida detecta 4 de 4 defeitos plantados. |
| M2 | GO-01: quem decide sai da lista de matérias, por regra. A alçada das pessoas da Governança vai aos sócios. |
| M3 | GO-06: uma pessoa revê uma amostra dos conformes do agente, e há auditoria externa anual da própria Governança. IT-06: uma pessoa confirma o desvio do agente. |
| M4 | GO-08: a crise tem um único dono. É o executivo na crise da empresa, o Administrador na crise do Ecossistema e os sócios quando a crise envolve o executivo. A cadeia C11 foi alinhada. |
| M5 | Os limites dos agentes têm um único dono: os sócios, na ID-02, etapa 3. |
| M6 | A comissão é calculada sobre a receita recebida (GE-13 recebe da GE-03). |
| M7 | Na GE-03, a segunda fatura vencida leva à proposta de suspensão, que o executivo decide. A OP-02 suspende as entregas e avisa. |
| M8 | As escaladas voltam:<br>- GO-03: remediação com evidência;<br>- GO-05: decisão do executivo;<br>- GO-06: correção feita;<br>- GO-07: execução confirmada, no prazo da LGPD;<br>- IT-02: decisão sobre o impasse;<br>- IN-08: decisão do executivo. |
| M9 | O critério de desvio grave está no método. A GE-02 o aponta à ES-06. |
| M10 | ES-04: vão aos sócios o encerramento de oferta com contratos vigentes e a decisão contra o portfólio-alvo. |
| M11 | O G6 passou para antes do G3. |
| L1 a L9 | Corrigidos:<br>- GE-02: mudança de alvo e recurso novo, com fim próprio para ação em atraso;<br>- um só vocabulário de realocação;<br>- textos do c2;<br>- evento de início da revisão do meio do ciclo;<br>- cadência da GO-02 com os sócios;<br>- exceção da compra e venda na regra 2;<br>- IN-07 avisa a Estratégia;<br>- GO-02: a devolução é decidida por pessoa. |
| Fontes | Conferidos no texto oficial (Planalto):<br>- Lei 14.133: art. 17, §§ 1º e 2º, e arts. 82 a 84, 86 (com o § 3º), 90, 140, 141, 164 e 165 (com os §§ 1º e 2º);<br>- Código Civil: arts. 389, 395, 421, 421-A, 422, 441 a 446, 475, 1.179, 1.180 e 1.194;<br>- CLT: arts. 74, § 2º, 145, 459, § 1º, e 477, § 6º;<br>- Lei 8.036: art. 15.<br>McKinsey: os valores 10,2% e 7,8% estão no Exhibit 2 do artigo; o texto diz "30% maior". APQC: os 18 elementos do círculo 6 conferidos. O G5 fica aberto só para a Resolução CD/ANPD nº 15/2024: o Diário Oficial não abriu. |
| Coerência | Textos desatualizados corrigidos e arquivos de leitura gerados de novo. A auditoria de execução ganhou a seção 8, com os números atuais. |

**Números depois da aplicação**

| Item | Valor |
|---|---|
| Jornadas | 73 |
| Etapas | 292 |
| Tarefas | 1.555 |
| Trocas entre círculos | 410, sem falha |
| Testes | Todos os círculos sem problema |

## 7. Verificação independente da aplicação

Um revisor que não participou do trabalho conferiu os 33 itens nos arquivos. Depois das correções abaixo, os números passaram a 73 jornadas, 292 etapas, 1.555 tarefas e 410 trocas. Achou 21 resolvidos e 12 parciais, além de 6 defeitos novos. Os totais e os testes bateram. Corrigido em seguida:

- **Dono:**
  - GE-07: o desligamento de pessoa dos círculos vai ao Administrador.
  - GE-01: o recurso entre círculos tem um só dono no texto e no fluxo, o Administrador.
  - Os limites dos agentes vão aos sócios só pela ID-02.
- **Dinheiro:** o acerto rescisório passa pela folha, com segundo aprovador.
- **Relatos:** na GO-09, o caso da Governança fica todo com a assessoria externa, inclusive quando aparece na apuração.
- **Textos da crise:** foram alinhados ao dono único na RE-08, no c4, no c9 e na consolidação.
- **Ramos e retornos:**
  - IN-07 segue as cinco condições aprovadas do limite do ajuste.
  - GE-09 tem fim próprio para pendência.
  - GO-04 e GE-08 têm retorno das escaladas.
  - GE-03 avisa Operações da retomada quando o cliente quita.
- **Tabela matéria × órgão:** completa, conferida pelo teste.
- **Fontes:** o art. 165 foi registrado com os §§ 1º e 2º.
- **Remissões:** as remissões ao círculo 9 e os caminhos foram corrigidos.

**Depois (03/10/2026, fim da tarde):** o G5 foi cumprido. A Resolução CD/ANPD nº 15/2024 foi conferida na página oficial da ANPD e na reprodução do DOU. As fontes ganharam retrato literal e reconferência mensal. As abas do documento voltaram ao pacote em exportação compacta, com manifesto e hash.
