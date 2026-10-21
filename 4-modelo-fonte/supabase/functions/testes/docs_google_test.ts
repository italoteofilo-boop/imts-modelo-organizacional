// Testes do Google Docs como terceira saída (084): ação docs_criar da função google e a função docs (fila), contra o banco de ensaio
// (app_ensaio), com o Google simulado. Rodar: DENO_DIR=... deno test -A functions/testes/docs_google_test.ts
import postgres from "npm:postgres@3.4.4";
import { PDFDocument, StandardFonts } from "npm:pdf-lib@1.17.1";
import { tratar as google } from "../google/tratar.ts";
import { tratar as docs } from "../docs/tratar.ts";
import { b64, b64url, limparCacheGoogle } from "../_comum/servidor.ts";

const sql = postgres(Deno.env.get("IMTS_DB_URL") || "postgres://postgres:ensaio-local@127.0.0.1:5499/app_ensaio", { max: 2, prepare: false });
const U = { olga: "00000000-0000-4000-8000-000000000002", clara: "00000000-0000-4000-8000-000000000005" };
const tok = (sub: string) => b64url(JSON.stringify({ alg: "HS256" })) + "." + b64url(JSON.stringify({ sub, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 600 })) + ".x";
const pedir = (corpo: unknown, quem: string | null) =>
  new Request("http://local/google", { method: "POST", headers: { "content-type": "application/json", ...(quem ? { authorization: "Bearer " + tok(quem) } : {}) }, body: JSON.stringify(corpo) });
const fila = (chave: string | null) => new Request("http://local/docs", { method: "POST", headers: { "content-type": "application/json", ...(chave ? { "x-imts-chave": chave } : {}) }, body: '{"acao":"fila"}' });
function ok(c: unknown, m: string) { if (!c) throw new Error(m); }

// Google simulado: o upload responde como o Drive responde a uma importação (mimeType de destino nos metadados)
type Chamada = { url: string; metodo: string; corpo: string };
const chamadas: Chamada[] = [];
let modo: "ok" | "fora" | "sem_conversao" = "ok", n = 0;
const marcador = Date.now().toString(36);
async function simulado(input: string | URL | Request, init?: RequestInit): Promise<Response> {
  const url = String(input); const metodo = init?.method || "GET";
  const corpo = init?.body instanceof Uint8Array ? new TextDecoder().decode(init.body) : init?.body instanceof URLSearchParams ? init.body.toString() : String(init?.body ?? "");
  chamadas.push({ url, metodo, corpo });
  const J = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } });
  if (url.startsWith("https://oauth2.googleapis.com/token")) return J({ access_token: "tok-docs", expires_in: 3600 });
  if (url.includes("/upload/drive/v3/files")) {
    if (modo === "fora") return J({ error: { message: "Backend Error" } }, 500);
    const metadados = JSON.parse(corpo.split("\r\n\r\n")[1].split("\r\n")[0]);
    const id = "docSimulado" + marcador + "x" + (++n);
    return J({ id, mimeType: modo === "sem_conversao" ? "text/html" : metadados.mimeType, webViewLink: `https://docs.google.com/document/d/${id}/edit` });
  }
  if (url.includes("/drive/v3/files?") && metodo === "GET") return J({ files: [] });
  if (url.includes("/drive/v3/files?") && metodo === "POST") return J({ id: "pastaSimuladaDocs" + (++n) });
  return J({ error: { message: "rota não simulada: " + url } }, 500);
}
const deps = { sql, fetch: simulado as typeof fetch };
const uploads = () => chamadas.filter((c) => c.url.includes("/upload/drive/v3/files"));

let alfa = "", beta = "", marca = "", chave = "";
const HTML = "<!doctype html><html><body><h1>Contrato de teste " + marcador + "</h1><p>Cláusula primeira: o objeto.</p></body></html>";
async function emitir(empresa: string, titulo: string, tipo = "contrato-cliente"): Promise<number> {
  const [{ id: ped }] = await sql`insert into doc.pedido (tipo, marca, empresa, conteudo, situacao, worker)
    values (${tipo}, ${marca}, ${empresa}, ${sql.json({ titulo })}, 'em_emissao', 'w-teste-docs') returning id`;
  const [{ id: em }] = await sql`insert into doc.emissao (pedido, situacao, registro) values (${ped}, 'emitido', '{}') returning id`;
  // PDF de verdade: outras suítes (assinatura) podem escolher esta emissão e selar o PDF
  const d = await PDFDocument.create(); const f = await d.embedFont(StandardFonts.Helvetica);
  d.addPage().drawText(titulo.replace(/[^\x20-\x7E]/g, "?"), { x: 50, y: 760, size: 14, font: f });
  const pdf = new Uint8Array(await d.save()), html = new TextEncoder().encode(HTML);
  const hpdf = [...new Uint8Array(await crypto.subtle.digest("SHA-256", pdf))].map((x) => x.toString(16).padStart(2, "0")).join("");
  const hhtml = [...new Uint8Array(await crypto.subtle.digest("SHA-256", html))].map((x) => x.toString(16).padStart(2, "0")).join("");
  await sql`update doc.emissao set hash_pdf = ${hpdf}, hash_html = ${hhtml}, paginas = 1 where id = ${em}`;
  await sql`insert into doc.arquivo values (${em}, 'pdf', ${pdf}, ${hpdf}, ${pdf.length}), (${em}, 'html', ${html}, ${hhtml}, ${html.length})`;
  await sql`update doc.pedido set situacao = 'emitido', worker = null where id = ${ped}`;
  return Number(em);
}
async function contaDeServico() {
  const k = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", k.privateKey));
  const pem = "-----BEGIN PRIVATE KEY-----\n" + b64(pkcs8).replace(/(.{64})/g, "$1\n") + "\n-----END PRIVATE KEY-----\n";
  return JSON.stringify({ client_email: "imts@projeto.iam.gserviceaccount.com", private_key: pem, token_uri: "https://oauth2.googleapis.com/token" });
}

Deno.test({ name: "Google Docs como terceira saída", sanitizeResources: false, sanitizeOps: false, async fn(t) {
  limparCacheGoogle();
  [{ id: alfa }] = await sql`select id from org.empresa where nome = 'Empresa Alfa'`;
  [{ id: beta }] = await sql`select id from org.empresa where nome = 'Empresa Beta'`;
  [{ id: marca }] = await sql`select min(id) as id from doc.marca`;
  [{ v: chave }] = await sql`select rt._segredo('imts_funcao_chave') as v`;
  await sql`update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema'`;
  await sql`update adm.parametro set valor = '"raizCompartilhada123"' where chave = 'google.drive_raiz'`;
  await sql`update adm.parametro set valor = '5' where chave = 'documentos.google_docs_tentativas'`;
  await sql`update adm.parametro set valor = '""' where chave = 'servidor.url_funcoes'`;
  await sql`update doc.google_doc set situacao = 'falhou' where situacao in ('na_fila', 'gerando')`;   // sobras de outras rodadas não entram na conta
  const semConta = !(await sql`select 1 from vault.secrets where name = 'google_conta_servico'`).length;   // o cofre é de todos os testes: aqui só se lê
  const e1 = await emitir(alfa, "Contrato Docs " + marcador);

  await t.step("docs_criar sem login: 401", async () => {
    const r = await google(pedir({ acao: "docs_criar", emissao: e1 }, null), deps); ok(r.status === 401, "status " + r.status);
  });
  await t.step("fila sem a chave: 401; sem a conta de serviço no cofre (quando faltar): 503 sem tocar na fila", async () => {
    ok((await docs(fila("errada"), deps)).status === 401, "aceitou chave errada");
    ok((await docs(fila(null), deps)).status === 401, "aceitou sem chave");
    if (semConta) { const r = await docs(fila(chave), deps); const j = await r.json(); ok(r.status === 503 && j.erro.includes("google_conta_servico"), JSON.stringify(j)); }
  });
  if (semConta) await sql`select vault.create_secret(${await contaDeServico()}, 'google_conta_servico')`;

  await t.step("pessoa que opera gera o Doc: HTML convertido para Google Docs na pasta do acervo, id e link no registro da emissão", async () => {
    const r = await google(pedir({ acao: "docs_criar", emissao: e1 }, U.olga), deps);
    const j = await r.json(); ok(r.status === 200 && j.link?.startsWith("https://docs.google.com/document/d/") && j.emissao === e1, JSON.stringify(j));
    const up = uploads().at(-1)!; const partes = up.corpo.split("\r\n\r\n");
    const metadados = JSON.parse(partes[1].split("\r\n")[0]);
    ok(metadados.mimeType === "application/vnd.google-apps.document" && metadados.name.startsWith("Contrato Docs " + marcador), "metadados " + JSON.stringify(metadados));
    ok(/Content-Type: text\/html; charset=UTF-8/.test(up.corpo) && up.corpo.includes("Cláusula primeira") && up.url.includes("uploadType=multipart"), "corpo do upload");
    const [p06] = await sql`select drive_id from acervo.pasta_drive where empresa = ${alfa} and pasta = '06'`;
    ok(p06 && metadados.parents[0] === p06.drive_id, "não foi para 06 Contratos: " + JSON.stringify(metadados.parents));
    const [em] = await sql`select google_doc_id, google_doc_link from doc.emissao where id = ${e1}`;
    ok(em.google_doc_id === j.id && em.google_doc_link === j.link, JSON.stringify(em));
    const [g] = await sql`select situacao, origem, tentativas from doc.google_doc where emissao = ${e1}`;
    ok(g.situacao === "pronto" && g.origem === "pessoa" && g.tentativas === 1, JSON.stringify(g));
    const log = await sql`select ok, pessoa from adm.registro_servidor where funcao = 'google' and acao = 'docs_criar' and alvo = ${j.id}`;
    ok(log.length === 1 && log[0].ok && log[0].pessoa, "registro: " + JSON.stringify(log));
  });
  await t.step("pedir de novo devolve o mesmo Doc, sem subir outro", async () => {
    const antes = uploads().length;
    const j = await (await google(pedir({ acao: "docs_criar", emissao: e1 }, U.olga), deps)).json();
    ok(j.ja_existia === true && uploads().length === antes, JSON.stringify(j));
  });
  await t.step("cliente e empresa sem acesso: 403 e nada no Drive", async () => {
    const eb = await emitir(beta, "Contrato Beta " + marcador);
    const antes = chamadas.length;
    const r1 = await google(pedir({ acao: "docs_criar", emissao: e1 }, U.clara), deps);
    const r2 = await google(pedir({ acao: "docs_criar", emissao: eb }, U.olga), deps);
    ok(r1.status === 403 && r2.status === 403 && chamadas.length === antes, `status ${r1.status} ${r2.status}`);
  });
  const e2 = await emitir(alfa, "Termo Docs " + marcador);
  await t.step("Google fora: 502 com a nova tentativa marcada; PDF intacto; falha registrada", async () => {
    modo = "fora";
    const r = await google(pedir({ acao: "docs_criar", emissao: e2 }, U.olga), deps); const j = await r.json();
    modo = "ok";
    ok(r.status === 502 && j.erro.includes("nova tentativa automática"), JSON.stringify(j));
    const [g] = await sql`select situacao, tentativas, proxima_em > now() as espera from doc.google_doc where emissao = ${e2}`;
    ok(g.situacao === "na_fila" && g.tentativas === 1 && g.espera, JSON.stringify(g));
    const [a] = await sql`select count(*)::int as n from doc.arquivo where emissao = ${e2} and formato = 'pdf'`; ok(a.n === 1, "PDF sumiu");
    const log = await sql`select ok from adm.registro_servidor where funcao = 'google' and acao = 'docs_criar' and alvo = ${"emissao:" + e2}`;
    ok(log.length === 1 && !log[0].ok, "falha sem registro");
  });
  await t.step("fila: a nova tentativa vencida é gerada pela função docs", async () => {
    await sql`update doc.google_doc set proxima_em = now() - interval '1 second' where emissao = ${e2}`;
    const r = await docs(fila(chave), deps); const j = await r.json();
    ok(r.status === 200 && j.gerados.some((x: { emissao: number }) => x.emissao === e2) && !j.falhas.length, JSON.stringify(j));
    const [g] = await sql`select situacao, tentativas, link from doc.google_doc where emissao = ${e2}`;
    ok(g.situacao === "pronto" && g.tentativas === 2 && g.link.startsWith("https://docs.google.com/"), JSON.stringify(g));
    const log = await sql`select pessoa from adm.registro_servidor where funcao = 'google' and acao = 'docs_criar' and ok and alvo = ${g.link.split("/")[5]}`;
    ok(log.length === 1, "fila sem registro");
  });
  await t.step("emissão nova com a saída ligada: o banco enfileira e a fila gera", async () => {
    await sql`update adm.parametro set valor = 'true' where chave = 'documentos.saida_google_docs'`;
    const e3 = await emitir(alfa, "Contrato automático " + marcador);
    await sql`update adm.parametro set valor = 'false' where chave = 'documentos.saida_google_docs'`;
    const [g0] = await sql`select situacao, origem from doc.google_doc where emissao = ${e3}`; ok(g0?.situacao === "na_fila" && g0.origem === "emissao", JSON.stringify(g0));
    const j = await (await docs(fila(chave), deps)).json();
    ok(j.gerados.some((x: { emissao: number }) => x.emissao === e3), JSON.stringify(j));
    const [em] = await sql`select google_doc_link from doc.emissao where id = ${e3}`; ok(em.google_doc_link?.startsWith("https://docs.google.com/"), "sem link");
  });
  await t.step("Drive sem conversão: falha; esgotadas as tentativas, alerta de operação e o PDF segue valendo", async () => {
    await sql`update adm.parametro set valor = '1' where chave = 'documentos.google_docs_tentativas'`;
    await sql`update adm.parametro set valor = 'true' where chave = 'documentos.saida_google_docs'`;
    const e4 = await emitir(alfa, "Contrato sem conversão " + marcador);
    await sql`update adm.parametro set valor = 'false' where chave = 'documentos.saida_google_docs'`;
    modo = "sem_conversao";
    const j = await (await docs(fila(chave), deps)).json();
    modo = "ok";
    const f = j.falhas.find((x: { emissao: number }) => x.emissao === e4);
    ok(f && f.situacao === "falhou" && f.erro.includes("sem converter"), JSON.stringify(j));
    const [al] = await sql`select tipo from adm.alerta where chave = ${"docs_google:" + e4} and resolvido_em is null`; ok(al?.tipo === "erro", "sem alerta");
    const [a] = await sql`select situacao from doc.emissao where id = ${e4}`; ok(a.situacao === "emitido", "emissão mexida");
    await sql`update adm.alerta set resolvido_em = now() where chave = ${"docs_google:" + e4} and resolvido_em is null`;
    await sql`update adm.parametro set valor = '5' where chave = 'documentos.google_docs_tentativas'`;
  });
  await sql`delete from acervo.pasta_drive where drive_id like 'pastaSimuladaDocs%'`;
  await sql.end();
} });
