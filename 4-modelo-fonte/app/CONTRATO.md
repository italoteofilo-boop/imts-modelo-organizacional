# Aplicativo IMTS.OS · contrato das telas

Aplicativo estático (HTML, CSS e JavaScript sem etapa de build) servido em www.imts.global. Cada módulo é uma página.

## Ordem dos scripts em toda página

```html
<link rel="stylesheet" href="comum/base.css">
...
<header id="imts-barra"></header>   <!-- barra de módulos, desenhada pelo núcleo -->
...
<script src="vendor/supabase.js"></script>
<script src="config.js"></script>
<script src="comum/imts.js"></script>
<script> /* código do módulo */ </script>
```

## Núcleo (`comum/imts.js`, objeto `window.IMTS`)

| Chamada | O que faz |
| --- | --- |
| `await IMTS.iniciar({ exige: 'interno' \| 'externo', modulo: 'mesa', admin: false })` | Exige sessão e o tipo certo de usuário; senão volta à entrada. Desenha a barra. Devolve `quem` (resultado de `rt.quem_sou`). |
| `await IMTS.chamar('esquema.funcao', { p_arg: valor })` | Porta única: `public.imts(p_fn, p_args)` com o login de quem usa. Argumentos só por nome, só os da assinatura, nunca `p_como`. Erro: `Error` com a mensagem do banco em português. |
| `IMTS.empresa()` / `IMTS.escolherEmpresa(id)` | Empresa em uso (vai no cabeçalho `x-empresa`; o banco confere a permissão). A troca dispara o evento `imts:empresa` no `document`: a tela recarrega os dados. |
| `await IMTS.google(acao, dados)` | Função do servidor `google` (conta de serviço do Workspace). Ações abaixo. |
| `await IMTS.ia(acao, dados)` | Função do servidor `ia` (chave da API no cofre, com orçamento). Ações abaixo. |
| `IMTS.esc(texto)` | Escapa HTML. Todo texto vindo do banco passa por aqui antes de entrar em `innerHTML`. |
| `IMTS.sair()` | Encerra a sessão. |

`quem` (de `rt.quem_sou`):
- interno: `{ tipo, pessoa, nome, papel, circulo, acessos[], administra, empresas[{id,nome}], pessoas[{pessoa,nome,papel,circulo}], governanca }`
- externo: `{ tipo, nome, perfil, contraparte{nome,tipo} }`

## Regras das telas

1. Nenhum SQL, nenhum dado embutido (retratos, pessoas simuladas), nenhum seletor de "você é".
2. Ações só pela porta única; a lista de funções permitidas está em `adm.api_funcao` (veja `api.txt` gerado na implantação).
3. Sem `localStorage` para dado de negócio. Preferências de tela, se houver, por `IMTS.guardar` (falha em silêncio).
4. Acessibilidade WCAG 2.2 AA: zero violação no axe-core em 1280 px claro, 1280 px escuro e 390 px; sem rolagem horizontal da página.
5. Função do servidor indisponível (Google ou IA): a tela mostra o motivo e segue funcionando no resto.

## Função do servidor `google` (supabase/functions/google)

POST `/functions/v1/google` com o token do usuário. Corpo `{ acao, ... }`. Resposta JSON; erro `{ erro, codigo }`.

| acao | entrada | saída | quem |
| --- | --- | --- | --- |
| `drive_enviar` | `empresa`, `pasta` (código do acervo, ex. `01`), `nome`, `mime`, `conteudo` (base64, até 25 MB) | `{ id, link, pasta, texto }` (texto extraído quando der: texto, Docs, PDF e Office por conversão com OCR) | interno com operar na empresa; externo: empresa e pasta saem do login (07 parceiro, 08 cliente), o que vier no pedido é ignorado |
| `drive_ler` | `id` | `{ nome, mime, texto }` (texto extraído quando houver) | interno com acesso |
| `drive_lixeira` | `id` | `{ ok: true }` | interno com acesso |
| `drive_mover` | `id`, `pasta`, `empresa` (se o arquivo ainda não estiver no acervo), `nome` (opcional) | `{ ok, pasta_id }` | interno com operar; arquivo do acervo dele ou enviado por ele na última hora |
| `drive_renomear` | `id`, `nome` | `{ ok: true }` | quem enviou o arquivo na última hora, ou interno com operar na empresa do arquivo |
| `drive_listar` | `pasta_id` | `{ arquivos[{ id, nome, mime, tamanho, alterado_em }] }` | interno; pasta registrada numa empresa em que opera |
| `drive_baixar` | `id` | `{ nome, mime, conteudo }` (base64) | interno; o arquivo precisa estar numa pasta registrada de empresa em que opera |
| `drive_pasta` | `empresa`, `pasta` | `{ id }` (cria se faltar e registra em `acervo.pasta_drive`) | interno com acesso |
| `agenda_evento` | `titulo`, `inicio` (ISO), `fim` (ISO), `convidados[]`, `descricao` | `{ evento_id, link }` (Google Meet; o organizador é quem marcou) | interno |
| `agenda_cancelar` | `evento_id` | `{ ok: true }` | interno |
| `docs_criar` | `emissao` (nº da emissão) | `{ emissao, id, link }` (Google Doc editável convertido do HTML emitido, na pasta do acervo do tipo); `ja_existia: true` se o Doc já existia | interno com operar na empresa da emissão; só emissão pronta (emitido ou emitido com alertas) com HTML |

Erros: `401` sessão, `403` recusa do banco (mensagem em português), `503` configuração faltando (segredo ou parâmetro), `502` Google fora. Toda ação fica em `adm.registro_servidor`.

### Google Docs como terceira saída (084)

Ao emitir, se o parâmetro `documentos.saida_google_docs` estiver ligado e o tipo tiver `doc.tipo.google_docs`, o banco põe o pedido na fila `doc.google_doc` e chama a função `docs` (verify_jwt desligado, só cabeçalho `X-IMTS-Chave`) pelo pg_net; a rotina `imts-docs-google` (10 min) repete enquanto houver pedido vencido. Falha não toca no PDF: volta à fila com espera de 5, 10, 20 minutos (até 6 horas); esgotadas `documentos.google_docs_tentativas`, abre alerta de operação `docs_google:<emissão>`. A tela lê `doc.painel_docs_google(p_empresa)` (`{ ligado, automatico, pode_operar, tentativas, emissoes[{ emissao, titulo, tipo_nome, situacao, emitido_em, paginas, pasta, google{ situacao, link, tentativas, erro, proxima_em, gerado_em } }] }`), mostra "Abrir no Google Docs" quando há link (só endereço `https://docs.google.com/` ou `https://drive.google.com/`) e "Gerar Google Doc" (`docs_criar`) para quem opera a empresa. O id e o link ficam em `doc.emissao.google_doc_id` e `google_doc_link`.

## Função do servidor `ia` (supabase/functions/ia)

| acao | entrada | saída |
| --- | --- | --- |
| `ata_rascunho` | `reuniao` (id), `transcricao` (texto) | `{ ata: { resumo, decisoes[], encaminhamentos[{ descricao, responsavel, prazo }] } }` |

Orçamento: parâmetro `ia.orcamento_mensal_tokens`; passou, `403` até o mês virar. Modelo: parâmetro `ia.modelo`.

Nada que a IA devolve é gravado sem aprovação de pessoa: a tela mostra o rascunho e quem aprova chama `ext.reuniao_ata_rascunho` ou `ext.reuniao_ata_aprovar`.

## Funções do servidor da assinatura eletrônica avançada (supabase/functions/assinatura, selo e verificar)

Base: Lei 14.063/2020, art. 4º, II, e MP 2.200-2/2001, art. 10, § 2º. Não substitui a assinatura qualificada (ICP-Brasil) quando a lei ou o órgão exigir: nesse caso o pedido é marcado `exige ICP-Brasil` e só registra a assinatura feita fora.

| função | acao | entrada | saída | quem |
| --- | --- | --- | --- | --- |
| `assinatura` (verify_jwt ligado) | `codigo` | `signatario` | `{ enviado, para (e-mail mascarado), validade_min, tentativas }` (o código vai ao e-mail pelo Gmail da conta do sistema) | o próprio signatário, na sua vez |
| `assinatura` | `selar` | `pedido` | `{ selados[] }` | quem lê o pedido |
| `selo` (verify_jwt desligado) | (nenhuma) | cabeçalho `X-IMTS-Chave` | `{ selados[] }` | o banco e a rotina `imts-assinatura` |
| `verificar` (verify_jwt desligado) | (nenhuma) | `codigo`, `hash` (SHA-256 calculado no navegador) ou `arquivo` (base64) | `{ encontrado, valido, motivos[], signatarios[nome, e-mail mascarado, data], documento, arquivo, trilha, selo{ confere, chave_publica } }` | qualquer pessoa, sem login |

Assinar e recusar vão pela porta única (`doc.assinatura_assinar`, `ext.assinatura_assinar`, `doc.assinatura_recusar`, `ext.assinatura_recusar`): o IP e o navegador saem dos cabeçalhos da requisição. Código errado não é erro: a resposta traz `{ assinado: false, motivo, restantes }`. A página pública é `verificar.html?c=CODIGO`.

## Mesa no Telegram (Mini App, `tg.html`) e função do servidor `telegram_app`

`tg.html` abre dentro do Telegram (botão de menu "Mesa", comando `/mesa` ou botão "Abrir a Mesa" do `/quadro`). Carrega o script oficial `https://telegram.org/js/telegram-web-app.js` antes de tudo e `config.js`; não usa `imts.js` nem login do Supabase. Cores do tema do Telegram (`themeParams`), corrigidas na página para contraste AA. Endereço: parâmetro `telegram_app.url` (produção `https://www.imts.global/tg.html`, homologação `https://homolog.imts.global/tg.html`).

| função | acao | entrada | saída | quem |
| --- | --- | --- | --- | --- |
| `telegram_app` (verify_jwt desligado) | `mesa` | `initData` | `{ nome, cartoes[{ id, titulo, coluna, prazo, tipo, jornada, jornada_nome, etapa_nome, de, para_aceitar, delegada, com_agente, opcoes[rótulos], so_na_web }] }` | pessoa da equipe com o Telegram ligado e login |
| `telegram_app` | `concluir`, `aceitar`, `recusar` | `initData`, `cartao` | `{ texto }` | idem; a regra é de `rt.app_*` |
| `telegram_app` | `decidir` | `initData`, `cartao`, `opcao` (posição) | `{ texto }` | idem |

A função confere a assinatura do `initData` (HMAC-SHA-256, chave derivada de `WebAppData` e do token do bot no cofre) e o `auth_date` (`telegram_app.validade_segundos`), acha a pessoa (`rt.tg_app_identificar`) e chama `rt.tg_mesa` / `rt.tg_agir` pela porta única com o login dela. Erros: `401` assinatura ou abertura vencida, `403` sem vínculo (`codigo` e `instrucao`) ou recusa do banco, `429` limite (`telegram_app.tentativas_max`, `telegram_app.janela_minutos`, `telegram_app.pedidos_minuto`), `503` sem o token do bot. Aprovação de pagamento (GE-04 e GE-05) não sai pelo Telegram: o cartão vem com `so_na_web`. Tudo em `adm.registro_servidor`, com hash do IP ou do usuário do Telegram, nunca o valor em claro.

## Ligar o Telegram na Mesa (089)

Bloco "Ligar o Telegram" na periferia de `mesa.html` (só equipe). O caminho da Gestão (GE-07) continua valendo para quem não usa a Mesa.

| chamada | uso na tela |
| --- | --- |
| `rt.tg_vinculo()` | `{ ligado, desde, origem ('mesa' ou 'cadastro'), codigo_aberto{ expira }, validade_minutos, limite_hora, restantes_hora, termo }`: estado (ligado ou desligado) e o termo; nunca o número do Telegram nem o código |
| `rt.tg_codigo_gerar(p_aceite)` | só com a caixa "Li e aceito" marcada (`p_aceite: true`; o banco recusa sem aceite e acima de `telegram.vinculo_codigos_hora`); devolve `{ codigo, comando, expira, validade_minutos, instrucao }` uma única vez; a tela mostra o código, "Copiar o comando" e "Já enviei: conferir" |
| `rt.tg_desvincular()` | "Desligar o Telegram" com confirmação na própria tela ("Sim, desligar" ou "Cancelar"); revoga o consentimento |

O bot aceita `/vincular CÓDIGO` da equipe só em conversa privada (em grupo o código é cancelado) e recusa código vencido, usado, cancelado, de pessoa já ligada a outro Telegram (desligar antes) ou enviado de um Telegram que já é de outra pessoa ou do portal. Termo, código e instrução entram por `textContent`. Parâmetros: `telegram.vinculo_codigo_minutos` (15), `telegram.vinculo_codigos_hora` (5), `telegram.vinculo_termo`.

## Testes

`testes/apoio.mjs` abre a página com um token de ensaio (sem Google) contra o PostgREST local. Cada módulo tem `testes/t_<modulo>.mjs`. Pessoas do ensaio: `admin`, `olga` (Operações), `lia` (líder de Operações), `rui` (Relações), `clara` (cliente), `paulo` (parceiro), `curioso` (sem cadastro).

## Agente de IA das tarefas de agente (086, função do servidor `agente`)

No modo assistido, a tarefa de agente (executor A) vai à fila `rt.fila_ia` e a função `agente` a executa pela IA (Anthropic ou Kimi, com reserva). Por padrão o rascunho vira cartão de revisão na Mesa ("Revisar rascunho da IA: ..."), que se conclui como qualquer cartão de fluxo; com `motor.agente_ia_autonomo` ligado o agente conclui sozinho. Sem IA disponível, a tarefa vira o cartão assistido de antes.

| função | acao | entrada | saída | quem |
| --- | --- | --- | --- | --- |
| `agente` (verify_jwt desligado) | `agente_executar` | cabeçalho `X-IMTS-Chave`, `lote` (opcional, até 20) | `{ processados, revisao, autonomos, cartoes_humanos, novas_tentativas, erros, degradados }` | o banco (pg_net) e a rotina `imts-agente-ia` |

Porta única: `rt.agente_ia_rascunho(p_cartao)` devolve `{ cartao, tarefa, desfecho, rascunho, provedor, modelo, gerado_em, motivo, aviso }` para quem é dono do cartão, recebeu a tarefa ou aprova no círculo; `adm.agente_ia_resumo()` é da administração.

Na Mesa (`mesa.html`): o cartão com `origem = 'agente'` (ou título "Revisar rascunho da IA: ...") ganha a etiqueta "rascunho da IA"; ao abrir o foco, a tela chama `rt.agente_ia_rascunho` e mostra a seção "Rascunho gerado por IA" com o rótulo "Gerado por IA: precisa de revisão" (mais o `aviso` do banco), o texto do rascunho e o botão "Copiar rascunho". O rascunho entra só por `textContent` (nunca `innerHTML`): marcação vinda da IA aparece como texto. Sem rascunho ligado, a seção diz isso; com `motivo` e sem texto, mostra o motivo. A conclusão continua a do cartão de fluxo (`rt.app_concluir`).

## Automação das tarefas R (078) e agentes de IA (086) na Administração

Aba "Automação e IA" de `admin.html` (só administração):

| chamada | uso na tela |
| --- | --- |
| `adm.automacao_r_resumo()` | `{ ligado, modo_assistido, tarefas_r, por_modo{ registrar, encaminhar, avisar, humano }, automaticas, humanas, compostas_humanas, verbos_sem_regra[] }`: totais e tabela por modo |
| `adm.automacao_r_definir(p_verbo, p_modo, p_motivo)` | formulário "Definir o modo de um verbo": verbo de uma palavra, modo `registrar`, `encaminhar`, `avisar` ou `humano`, motivo obrigatório; a tela abre a confirmação antes de gravar e o banco recusa quem não administra; fica em `adm.historico` (objeto `automacao_r`) |
| `adm.automacao_r_regras()` (091) | `{ total, por_modo{ registrar, encaminhar, avisar, humano }, regras[{ verbo, modo, descricao, tarefas_r, compostas_com_pessoa, atualizado_em, atualizado_por, atualizado_por_nome }] }`, ordem: mais tarefas R primeiro, depois o verbo. Só administração (`adm._so_admin`) ou chamada de serviço; leitura. Seção "Regras por verbo": tabela Verbo, Modo, Descrição, Tarefas R (com quantas compostas ficam com a pessoa), Atualizado (quando e por quem; sem autor, "carga inicial"), Ação. Filtro por modo (`#rg-modo`) e busca por verbo (`#rg-busca`) redesenham só o corpo da tabela (`#tb-regras-r`) e a contagem (`#rg-n`). "Trocar modo" (`data-regra-verbo`) pré-preenche o formulário "Definir o modo de um verbo" com o verbo e o modo atual e leva o foco ao modo; gravar segue pela mesma confirmação de `adm.automacao_r_definir` |
| `adm.agente_ia_resumo()` | leitura: ligado, autônomo ou com revisão, modo assistido, disponível (ou `motivo_indisponivel`), provedor e chaves, uso de hoje contra os limites, fila por estado e por desfecho, revisões abertas na Mesa, tokens em 30 dias, motivos de queda para o cartão humano |

Os parâmetros (`motor.automacao_r`, `motor.agente_ia*`) mudam na aba Parâmetros; as chaves da IA, na aba Integrações. O painel de Google Docs (`doc.painel_docs_google`, 084) fica no Acervo (`acervo.html`).
