# Motor documental (E12)

Um motor para todos os documentos formais, internos e externos, das empresas do Ecossistema. É multiempresa, multitipo e multimodelo. Saídas: PDF e HTML. Google Docs entra quando o Drive da IMTS for conectado. Não sai nenhum formato Microsoft.

## Como funciona

1. **Pedido.** Um JSON com tipo, marca, título, data, local, blocos, anexos, parte final e assinaturas. Entra pela fila do Supabase (`doc.pedir`) ou direto por `motor.py pedido.json`.
2. **Validação e gates de conteúdo.** Um pedido inválido é recusado antes de renderizar. Bloqueiam a emissão:
   - campo pendente `[●`;
   - travessão longo;
   - sinal de modelo `{{ }}` ou `{% %}`;
   - número de versão;
   - marca provisória em documento externo.
3. **HTML.** Sai de um template único (`modelos/documento.html.j2`), no modelo do tipo, com a marca do pacote. As fontes vão embutidas, então o HTML é autocontido.
4. **Regra do terço** (`modelos/ajuste.js`). Roda no Chromium, na largura da coluna impressa, nesta ordem:
   - espaçamento entre letras até 0,2 pt;
   - espaço entre palavras de −0,5 a +1,0 pt;
   - até quatro palavras puxadas para a última linha, com a penúltima mantendo 85% da linha.

   O que não se resolve vira alerta, para ser corrigido na redação.
5. **PDF em duas passagens.** A segunda escreve o sumário com as páginas lidas dos marcadores do PDF. Os modelos premium têm capa própria, sem cabeçalho.
6. **Metadados institucionais.** O autor é a marca, nunca uma pessoa. Título e assunto vêm do tipo.
7. **Gates do PDF:**
   - texto do PDF igual ao dos blocos;
   - sumário íntegro e crescente;
   - título sozinho no fim da página;
   - página em branco;
   - metadados;
   - sinais proibidos.
8. **Registro.** Guarda a situação (`emitido`, `emitido_com_alertas`, `bloqueado` ou `recusado`), os hashes do pedido, do PDF e do HTML, os gates e os alertas.

## Gates e saída (04/10/2026)

**Gates novos.**

- Conteúdo: travessão; marcador `[●`; hífen invisível; `{{`; número de versão.
- Contratual: duas testemunhas e nota de assinatura; remissões internas; definições em ordem alfabética (alerta); numeração de quadros (alerta); referências verificadas há mais de 30 dias (alerta).
- PDF: texto visível; página e orientação pelo modelo; âncoras de assinatura; sumário que confere com o índice do PDF; título sozinho no fim da página; página em branco; metadados.

**Capa.** Nos modelos premium (institucional, proposta, relatório e demonstrativo), a capa sai no mesmo PDF, marcada para acessibilidade.

**Cabeçalho e rodapé.** Os modelos formais usam o cabeçalho e o rodapé de controle do Chromium.

**Certificado.** Sai em A4 paisagem.

**PDF determinístico.** As datas do PDF vêm do pedido. O /ID sai do md5 do HTML.

**Worker.** Quando a emissão falha, o worker tenta de novo, com espera crescente até 5 minutos.

**Registro.** Também guarda as versões (hash) de `base.css`, do template, de `ajuste.js`, de `marca.json` e de `motor.py`.

## Peças

| Peça | O que é |
|---|---|
| `tipos/catalogo.json` (`catalogar.py`) | Catálogo fechado, com 38 tipos em 10 famílias, ligado a 169 das 690 saídas do modelo e a 106 tarefas. A ligação foi feita por regra de texto e está marcada para revisão da ID-04. |
| `marcas/<id>/marca.json` | IMTS (oficial, com logos), Onni (oficial; Poppins no lugar da Nexa, declarado; sem logo), TRON (provisória, com tokens neutros e marca d'água) e neutra |
| `modelos/` | `base.css` (tokens da marca e regras do Legal.OS), `documento.html.j2`, `ajuste.js` |
| `fontes/` | Open Sans, Michroma e Poppins em TTF (OFL 1.1) |
| `motor.py` | Emissão. `python3 motor.py pedido.json --saida DIR`; `--instalar-fontes` |
| `worker.py` | Lê a fila do Supabase, emite e registra. Configuração por ambiente: `SUPABASE_URL`, `SUPABASE_CHAVE_PUB` e `DOC_WORKER_CHAVE` (o mesmo valor do segredo `doc_worker_chave` no Vault) |
| `amostras/*.json`, `emitir_amostras.py` | Uma amostra por modelo |
| `testar_motor.py` | 30 testes que emitem de verdade |
| `gerar_sql.py`, `doc_funcoes.sql` | Geram `supabase/025_motor_documental.sql` |

## Modelos

| Modelo | Família | Traço |
|---|---|---|
| contratual | formal | Quadro de controle, sumário, cláusulas em barras, assinaturas com duas testemunhas e âncoras invisíveis, anexo abrindo página, glossário e referências |
| licitação | formal | Dados do certame, sumário, preços e condições |
| ata | formal | Campos da reunião, deliberações numeradas, assinaturas |
| ofício | formal | Referência, local e data, destinatário, assunto, assinatura única |
| política | formal | Aprovação e vigência, sumário, regras numeradas, papéis |
| institucional | premium | Capa, sumário, seções |
| proposta | premium | Capa, proposta em uma página, indicadores, investimento |
| relatório | premium | Capa, sumário, indicadores, análise |
| demonstrativo | premium | Capa, quadros numéricos com total, assinaturas do contador e do administrador |
| certificado | premium | A4 paisagem, uma página, moldura da marca |

Nos modelos formais vale uma família tipográfica só. Nos modelos premium, a fonte display da marca entra nos títulos: na IMTS, a Michroma.

## Fila no Supabase (esquema `doc`)

O fluxo é `doc.pedir`, depois `public.doc_worker_proximo`, `doc_worker_registrar` ou `doc_worker_falhar`, e por fim `doc.decidir`.

- **Decisão em duas mãos:**
  - quem pediu não decide o próprio documento;
  - quem analisou não aprova;
  - alerta mantido exige justificativa;
  - emissão bloqueada não se submete.
- **Parâmetros do motor:** o limite de tentativas e o tempo para destravar a fila vêm de `adm.parametro`.
- **Vínculos:** as automações que publicam, emitem, respondem ou enviam proposta (21 tarefas) passaram ao sistema `motor-documental`.

## Pendências

- Código do `contract_engine` e do motor de propostas: absorver no motor único.
- Arquivos da fonte Nexa (Onni).
- Manual da marca TRON.
- Razão social e CNPJ da IMTS.
- Conectar o Drive da IMTS (saída Google Docs).
- Escolher o serviço do worker em produção.
- Mover os arquivos para o Storage (hoje ficam em `doc.arquivo`, bytea).
- Conectar a DocuSign.
