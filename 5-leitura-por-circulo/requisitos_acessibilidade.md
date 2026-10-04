# Acessibilidade, usabilidade e portabilidade · requisitos da plataforma

Aprovado em 03/10/2026, às 21:05, como parte do cruzamento do dia a dia com o modelo. Vale para a Mesa, o painel, as instruções e o canal Telegram.

## 1. Acessibilidade

**Alvo:** WCAG 2.2, nível AA (W3C). A conferência automática usa o axe-core 4.10, com as regras dos níveis A e AA das versões 2.0, 2.1 e 2.2.

**Resultado em 03/10/2026:** zero violações na Mesa (tema claro e escuro, com o foco aberto) e no painel, com movimento reduzido.

Correções desta rodada:
- abas da Mesa separadas dos seletores (o grupo de abas só tem abas);
- nome acessível nos campos de prazo, pessoa e pedido do foco;
- idioma da página do painel declarado (pt-BR).

A conferência automática pega só uma parte dos critérios. Fica para cada versão nova, feita à mão:

| Item | Como conferir |
|---|---|
| Teclado | Toda ação da Mesa pelo teclado: abrir cartão, concluir, decidir, delegar, criar. Arrastar tem alternativa no foco |
| Leitor de tela | Cartão lido com tipo, título, prazo e situação; recibos anunciados (aria-live) |
| Zoom e celular | Página usável a 200% e a 390 px de largura, sem rolagem lateral (conferido a 390 px) |
| Contraste | 4,5:1 no texto comum, nos dois temas |
| Movimento | O cérebro vivo e o painel respeitam "reduzir movimento" do sistema |
| Telegram | Texto simples, comandos curtos e botões; nenhuma ação só por imagem ou cor |

## 2. Usabilidade

| Regra | Onde está |
|---|---|
| Um aplicativo só, em quatro formatos: Telegram e Mini App, navegador, sala de situação, impresso | Decisão de 20:36 |
| A pessoa sempre sabe o que fazer agora: "Precisa de você" e o resumo no topo | Mesa |
| Toda ação deixa recibo: pedido, feito ou recusado com o motivo | Mesa |
| A regra fica na base, e a tela só mostra: o que o motor recusa aparece como recusa, com o motivo | Mesa ao vivo, Telegram |
| A captura sugere a jornada que já existe antes de criar avulsa | Mesa, Telegram |

## 3. Portabilidade

| Item | Como |
|---|---|
| Dados da pessoa (LGPD, art. 18, II e V) | `rt.exportar_pessoa` e `rt.atender_exportacao` devolvem tudo de uma pessoa num JSON, com registro do pedido |
| Eliminação (art. 18, IV e VI) | `rt.eliminar_pessoa` desfaz o vínculo com a identidade real, apaga o conteúdo das mensagens e encerra os acessos |
| Modelo | BPMN 2.0 (ISO/IEC 19510), JSON do modelo, SQL do Postgres; nada preso a um fornecedor |
| Pacotes | Zips rastreáveis, com manifesto e conferência (zip_rastreavel.py) |
| Motor | Postgres puro (funções e tabelas); a Edge Function do Telegram é TypeScript para Deno, trocável |

## Fontes

- W3C, Web Content Accessibility Guidelines (WCAG) 2.2: https://www.w3.org/TR/WCAG22/
- Deque, axe-core: https://github.com/dequelabs/axe-core
- Lei 13.709/2018 (LGPD), art. 18, conferido no Planalto em 03/10/2026: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
