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

Erros: `401` sessão, `403` recusa do banco (mensagem em português), `503` configuração faltando (segredo ou parâmetro), `502` Google fora. Toda ação fica em `adm.registro_servidor`.

## Função do servidor `ia` (supabase/functions/ia)

| acao | entrada | saída |
| --- | --- | --- |
| `ata_rascunho` | `reuniao` (id), `transcricao` (texto) | `{ ata: { resumo, decisoes[], encaminhamentos[{ descricao, responsavel, prazo }] } }` |

Orçamento: parâmetro `ia.orcamento_mensal_tokens`; passou, `403` até o mês virar. Modelo: parâmetro `ia.modelo`.

Nada que a IA devolve é gravado sem aprovação de pessoa: a tela mostra o rascunho e quem aprova chama `ext.reuniao_ata_rascunho` ou `ext.reuniao_ata_aprovar`.

## Testes

`testes/apoio.mjs` abre a página com um token de ensaio (sem Google) contra o PostgREST local. Cada módulo tem `testes/t_<modulo>.mjs`. Pessoas do ensaio: `admin`, `olga` (Operações), `lia` (líder de Operações), `rui` (Relações), `clara` (cliente), `paulo` (parceiro), `curioso` (sem cadastro).
