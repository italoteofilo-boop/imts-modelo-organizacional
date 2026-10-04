// Testes das Edge Functions google, ia e alertas contra o banco de ensaio (app_ensaio), com Google e Anthropic simulados.
// Rodar: IMTS_DB_URL=postgres://postgres:<senha>@127.0.0.1:5499/app_ensaio deno test -A functions/testes/servidor_test.ts
import postgres from "npm:postgres@3.4.4";
import { tratar as google } from "../google/tratar.ts";
import { lerAta, tratar as ia } from "../ia/tratar.ts";
import { tratar as alertas } from "../alertas/tratar.ts";
import { tratar as conexoes } from "../conexoes/tratar.ts";
import { b64, b64url, b64urlDecode, limparCacheGoogle } from "../_comum/servidor.ts";

const sql = postgres(Deno.env.get("IMTS_DB_URL") || "postgres://postgres:ensaio-local@127.0.0.1:5499/app_ensaio", { max: 2, prepare: false });
const U = { admin: "00000000-0000-4000-8000-000000000001", olga: "00000000-0000-4000-8000-000000000002", clara: "00000000-0000-4000-8000-000000000005" };
const tok = (sub: string) => b64url(JSON.stringify({ alg: "HS256" })) + "." + b64url(JSON.stringify({ sub, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 600 })) + ".x";
const pedir = (corpo: unknown, quem: string | null, extra: Record<string, string> = {}) =>
  new Request("http://local/f", { method: "POST", headers: { "content-type": "application/json", ...(quem ? { authorization: "Bearer " + tok(quem) } : {}), ...extra }, body: JSON.stringify(corpo) });
function ok(c: unknown, m: string) { if (!c) throw new Error(m); }

// Google e Anthropic simulados: registram o que receberam
type Chamada = { url: string; metodo: string; corpo: string; auth: string | null };
const chamadas: Chamada[] = [];
let pastas = 0, arquivos = 0;
async function simulado(input: string | URL | Request, init?: RequestInit): Promise<Response> {
  const url = String(input); const metodo = init?.method || "GET";
  const corpo = init?.body instanceof Uint8Array ? new TextDecoder().decode(init.body) : init?.body instanceof URLSearchParams ? init.body.toString() : String(init?.body ?? "");
  chamadas.push({ url, metodo, corpo, auth: new Headers(init?.headers).get("authorization") });
  const J = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } });
  if (url.startsWith("https://oauth2.googleapis.com/token")) return J({ access_token: "tok-" + chamadas.length, expires_in: 3600 });
  if (url.includes("/upload/drive/v3/files")) return J({ id: "arquivoSimulado" + (++arquivos), webViewLink: "https://drive.google.com/file/d/x" });
  if (url.includes("/drive/v3/files?") && metodo === "GET") return J({ files: [] });
  if (url.includes("/drive/v3/files?") && metodo === "POST") return J({ id: "pastaSimulada" + (++pastas) });
  if (url.includes("/copy?")) return J({ id: "copiaTemporaria123" });
  if (url.includes("/export?")) return new Response("CONTRATO SOCIAL texto extraído");
  if (url.includes("/drive/v3/files/") && metodo === "DELETE") return new Response(null, { status: 204 });
  if (url.includes("/calendar/v3/calendars/primary/events") && metodo === "POST") return J({ id: "eventoSimulado1", hangoutLink: "https://meet.google.com/abc-defg-hij" });
  if (url.startsWith("https://api.anthropic.com/")) return J({ content: [{ type: "text", text: 'Segue: {"resumo":"Reunião de teste.","decisoes":["Aprovar o cronograma"],"encaminhamentos":[{"descricao":"Enviar a ata","responsavel":"Operações · pessoa","prazo":"2026-10-10"}]}' }], usage: { input_tokens: 120, output_tokens: 80 } });
  if (url.startsWith("https://gmail.googleapis.com/")) return J({ id: "msg1" });
  if (/^https:\/\/api\.telegram\.org\/bot[^/]+\/getMe$/.test(url)) return J({ ok: true, result: { username: "imts_teste_bot" } });
  if (url === "https://api.anthropic.com/v1/models") return J({ data: [{ id: "modelo-a" }] });
  if (url === "https://kimi.teste/v1/models") return J({ data: [{ id: "modelo-kimi-teste" }] });
  if (url === "https://kimi.teste/v1/chat/completions") return J({ choices: [{ message: { content: '{"resumo":"Ata pela Kimi.","decisoes":["Seguir"],"encaminhamentos":[]}' } }], usage: { prompt_tokens: 50, completion_tokens: 30 } });
  return J({ error: { message: "rota não simulada: " + url } }, 500);
}
const deps = { sql, fetch: simulado as typeof fetch };
const ultimo = (trecho: string) => [...chamadas].reverse().find((c) => c.url.includes(trecho));
const sujeitoDoToken = (c: Chamada) => JSON.parse(new TextDecoder().decode(b64urlDecode(new URLSearchParams(c.corpo).get("assertion")!.split(".")[1]))).sub;

let empAlfa = "", empBeta = "";
async function preparar() {
  [{ id: empAlfa }] = await sql`select id from org.empresa where nome = 'Empresa Alfa'`;
  [{ id: empBeta }] = await sql`select id from org.empresa where nome = 'Empresa Beta'`;
  await sql`delete from acervo.pasta_drive where drive_id like 'pastaSimulada%'`;
  await sql`delete from vault.secrets where name in ('google_conta_servico', 'anthropic_chave')`;
  await sql`update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema'`;
  await sql`update adm.parametro set valor = '"raizCompartilhada123"' where chave = 'google.drive_raiz'`;
  await sql`update adm.parametro set valor = '2000000' where chave = 'ia.orcamento_mensal_tokens'`;
  await sql`delete from adm.registro_servidor where funcao = 'ia' or alvo like 'arquivoSimulado%'`;
}
async function contaDeServico() {
  const k = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", k.privateKey));
  const pem = "-----BEGIN PRIVATE KEY-----\n" + b64(pkcs8).replace(/(.{64})/g, "$1\n") + "\n-----END PRIVATE KEY-----\n";
  return JSON.stringify({ client_email: "imts@projeto.iam.gserviceaccount.com", private_key: pem, token_uri: "https://oauth2.googleapis.com/token" });
}

Deno.test({ name: "funções do servidor", sanitizeResources: false, sanitizeOps: false, async fn(t) {
  await preparar(); limparCacheGoogle();

  await t.step("sem login: 401", async () => {
    const r = await google(pedir({ acao: "drive_ler", id: "abcdefghijk" }, null), deps); ok(r.status === 401, "status " + r.status);
  });
  await t.step("Google sem segredo no cofre: 503 com o motivo", async () => {
    const r = await google(pedir({ acao: "drive_enviar", empresa: empAlfa, pasta: "01", nome: "a.txt", mime: "text/plain", conteudo: btoa("oi") }, U.olga), deps);
    const j = await r.json(); ok(r.status === 503 && j.erro.includes("google_conta_servico"), JSON.stringify(j));
  });
  await sql`select vault.create_secret(${await contaDeServico()}, 'google_conta_servico')`;

  await t.step("pessoa de dentro envia: cria raiz e pasta, registra no banco, devolve texto", async () => {
    const r = await google(pedir({ acao: "drive_enviar", empresa: empAlfa, pasta: "01", nome: "contrato.pdf", mime: "application/pdf", conteudo: btoa("%PDF-1.4 teste") }, U.olga), deps);
    const j = await r.json(); ok(r.status === 200 && j.id?.startsWith("arquivoSimulado") && j.texto?.includes("CONTRATO"), JSON.stringify(j));
    const reg = await sql`select pasta, drive_id from acervo.pasta_drive where empresa = ${empAlfa} and drive_id like 'pastaSimulada%' order by pasta`;
    ok(reg.length === 2 && reg.some((x) => x.pasta === "raiz") && reg.some((x) => x.pasta === "01"), JSON.stringify(reg));
    ok(sujeitoDoToken(ultimo("oauth2")!) === "sistema@imts.com.br", "Drive deveria agir como a conta do sistema");
    const log = await sql`select ok from adm.registro_servidor where funcao = 'google' and acao = 'drive_enviar' and alvo = ${j.id}`;
    ok(log.length === 1 && log[0].ok, "sem registro");
  });
  await t.step("cliente pede a pasta 01 e o arquivo vai para a 08 da sua empresa", async () => {
    const r = await google(pedir({ acao: "drive_enviar", empresa: empBeta, pasta: "01", nome: "nota.txt", mime: "text/plain", conteudo: btoa("nota") }, U.clara), deps);
    ok(r.status === 200, "status " + r.status + " " + await r.clone().text());
    const reg = await sql`select pasta from acervo.pasta_drive where empresa = ${empAlfa} and pasta = '08' and drive_id like 'pastaSimulada%'`;
    ok(reg.length === 1, "pasta 08 não criada na empresa do cliente");
  });
  await t.step("empresa sem acesso: 403 e nada no Drive", async () => {
    const antes = chamadas.length;
    const r = await google(pedir({ acao: "drive_enviar", empresa: empBeta, pasta: "01", nome: "x.txt", mime: "text/plain", conteudo: btoa("x") }, U.olga), deps);
    ok(r.status === 403 && chamadas.length === antes, "status " + r.status);
  });
  await t.step("cliente não apaga arquivo", async () => {
    const r = await google(pedir({ acao: "drive_lixeira", id: "arquivoSimulado2" }, U.clara), deps); ok(r.status === 403, "status " + r.status);
  });
  await t.step("reunião: evento com Meet em nome de quem marcou", async () => {
    const r = await google(pedir({ acao: "agenda_evento", titulo: "Alinhamento", inicio: "2026-10-10T10:00:00-03:00", fim: "2026-10-10T11:00:00-03:00", convidados: ["clara@prefeitura-exemplo.gov.br", "inválido"] }, U.olga), deps);
    const j = await r.json(); ok(r.status === 200 && j.link?.includes("meet.google.com") && j.evento_id, JSON.stringify(j));
    ok(sujeitoDoToken(ultimo("oauth2")!) === "olga@imts.com.br", "Agenda deveria agir como a própria pessoa");
    const ev = JSON.parse(ultimo("/calendar/v3/")!.corpo); ok(ev.attendees.length === 1 && ev.conferenceData.createRequest, "convidados ou Meet");
  });
  await t.step("cliente não marca reunião", async () => {
    const r = await google(pedir({ acao: "agenda_evento", titulo: "x", inicio: "2026-10-10T10:00:00Z", fim: "2026-10-10T11:00:00Z" }, U.clara), deps); ok(r.status === 403, "status " + r.status);
  });

  const [reu] = await sql`select id from ext.reuniao order by id desc limit 1`;
  await t.step("IA sem chave: 503", async () => {
    const r = await ia(pedir({ acao: "ata_rascunho", reuniao: reu?.id, transcricao: "Falamos do cronograma e decidimos aprovar." }, U.olga), deps);
    ok(reu ? r.status === 503 : r.status === 403, "status " + r.status);
  });
  await sql`select vault.create_secret('chave-de-teste', 'anthropic_chave')`;
  await t.step("IA: rascunho limpo e tokens contados no orçamento", async () => {
    if (!reu) return;
    const r = await ia(pedir({ acao: "ata_rascunho", reuniao: reu.id, transcricao: "Falamos do cronograma e decidimos aprovar. Operações envia a ata até dia 10." }, U.olga), deps);
    const j = await r.json(); ok(r.status === 200 && j.ata.decisoes[0] === "Aprovar o cronograma" && j.ata.encaminhamentos[0].prazo === "2026-10-10", JSON.stringify(j));
    const [u] = await sql`select tokens_entrada + tokens_saida as t from adm.registro_servidor where funcao = 'ia' and ok order by id desc limit 1`; ok(u.t === 200, "tokens " + u?.t);
    const enviado = JSON.parse(ultimo("api.anthropic.com")!.corpo); ok(enviado.model && enviado.system.includes("não invente"), "pedido à IA");
  });
  await t.step("IA: orçamento esgotado recusa sem chamar a API", async () => {
    if (!reu) return;
    await sql`update adm.parametro set valor = '100' where chave = 'ia.orcamento_mensal_tokens'`;
    const antes = chamadas.length;
    const r = await ia(pedir({ acao: "ata_rascunho", reuniao: reu.id, transcricao: "Falamos do cronograma e decidimos aprovar." }, U.olga), deps);
    ok(r.status === 403 && chamadas.length === antes && (await r.json()).erro.includes("orçamento"), "status " + r.status);
    await sql`update adm.parametro set valor = '2000000' where chave = 'ia.orcamento_mensal_tokens'`;
  });
  await t.step("IA: Kimi como principal, com o formato compatível com a OpenAI", async () => {
    if (!reu) return;
    await sql`update adm.parametro set valor = '"kimi"' where chave = 'ia.provedor'`;
    await sql`update adm.parametro set valor = '"https://kimi.teste/v1"' where chave = 'ia.kimi_url'`;
    await sql`update adm.parametro set valor = '"modelo-kimi-teste"' where chave = 'ia.kimi_modelo'`;
    await sql`delete from vault.secrets where name = 'kimi_chave'`;
    await sql`select vault.create_secret('chave-kimi-teste', 'kimi_chave')`;
    const r = await ia(pedir({ acao: "ata_rascunho", reuniao: reu.id, transcricao: "Falamos do cronograma e decidimos seguir com o plano." }, U.olga), deps);
    const j = await r.json(); ok(r.status === 200 && j.ata.resumo === "Ata pela Kimi.", JSON.stringify(j));
    const c = ultimo("kimi.teste")!; const corpo = JSON.parse(c.corpo);
    ok(c.auth === "Bearer chave-kimi-teste" && corpo.model === "modelo-kimi-teste" && corpo.messages[0].role === "system", "pedido à Kimi");
    const [u] = await sql`select detalhe, tokens_entrada + tokens_saida as t from adm.registro_servidor where funcao = 'ia' and ok order by id desc limit 1`;
    ok(u.detalhe === "kimi" && u.t === 80, JSON.stringify(u));
  });
  await t.step("IA: principal fora do ar, a reserva responde", async () => {
    if (!reu) return;
    await sql`update adm.parametro set valor = '"https://kimi-fora.teste/v1"' where chave = 'ia.kimi_url'`;
    const r = await ia(pedir({ acao: "ata_rascunho", reuniao: reu.id, transcricao: "Falamos do cronograma e decidimos aprovar." }, U.olga), deps);
    const j = await r.json(); ok(r.status === 200 && j.ata.decisoes[0] === "Aprovar o cronograma", JSON.stringify(j));
    const [u] = await sql`select detalhe from adm.registro_servidor where funcao = 'ia' and ok order by id desc limit 1`;
    ok(u.detalhe === "anthropic (reserva)", JSON.stringify(u));
    await sql`update adm.parametro set valor = '"anthropic"' where chave = 'ia.provedor'`;
    await sql`update adm.parametro set valor = '""' where chave in ('ia.kimi_url', 'ia.kimi_modelo')`;
    await sql`delete from vault.secrets where name = 'kimi_chave'`;
  });
  await t.step("ata ilegível vira recusa clara", () => { let ok2 = false; try { lerAta("sem json"); } catch { ok2 = true; } ok(ok2, "aceitou"); });

  await t.step("alertas: sem a chave, 401; com a chave, um e-mail e marca o envio", async () => {
    const r1 = await alertas(new Request("http://local/alertas", { method: "POST", headers: { "x-imts-chave": "errada" } }), deps); ok(r1.status === 401, "status " + r1.status);
    await sql`update adm.parametro set valor = '["ti@imts.com.br"]' where chave = 'alerta.emails'`;
    await sql`select adm._alertar('erro:teste.servidor', 'erro', 'alerta de teste das funções')`;
    const [{ v: chave }] = await sql`select rt._segredo('imts_funcao_chave') as v`;
    const r2 = await alertas(new Request("http://local/alertas", { method: "POST", headers: { "x-imts-chave": chave } }), deps);
    const j = await r2.json(); ok(r2.status === 200 && j.enviados >= 1, JSON.stringify(j));
    const raw = new TextDecoder().decode(b64urlDecode(JSON.parse(ultimo("gmail.googleapis.com")!.corpo).raw)); ok(raw.includes("To: ti@imts.com.br"), "destinatário");
    const [a] = await sql`select email_em from adm.alerta where chave = 'erro:teste.servidor' and resolvido_em is null`; ok(a.email_em, "não marcou");
    const r3 = await alertas(new Request("http://local/alertas", { method: "POST", headers: { "x-imts-chave": chave } }), deps); ok((await r3.json()).enviados === 0, "repetiu o e-mail");
    await sql`update adm.alerta set resolvido_em = now() where chave = 'erro:teste.servidor' and resolvido_em is null`;
  });
  await t.step("conexões: teste real de cada integração, só pela administração", async () => {
    const r0 = await conexoes(pedir({ acao: "testar", codigo: "ia-anthropic" }, U.olga), deps); ok(r0.status === 403, "olga testou: " + r0.status);
    await sql`delete from vault.secrets where name = 'telegram_ambiente'`;
    await sql`select vault.create_secret('producao', 'telegram_ambiente')`;
    await sql`delete from vault.secrets where name = 'telegram_bot_token'`;
    await sql`select vault.create_secret('123:token-de-teste', 'telegram_bot_token')`;
    const r1 = await (await conexoes(pedir({ acao: "testar", codigo: "telegram-bot-api" }, U.admin), deps)).json();
    ok(r1.ok && r1.detalhe.includes("@imts_teste_bot") && ultimo("getMe")!.url === "https://api.telegram.org/bot123:token-de-teste/getMe", JSON.stringify(r1));
    const r2 = await (await conexoes(pedir({ acao: "testar", codigo: "ia-anthropic" }, U.admin), deps)).json(); ok(r2.ok, JSON.stringify(r2));
    const [c] = await sql`select estado, saude from adm.conexao where codigo = 'ia-anthropic'`; ok(c.estado === "ativa" && c.saude === "ok", JSON.stringify(c));
    const r3 = await (await conexoes(pedir({ acao: "testar", codigo: "ia-kimi" }, U.admin), deps)).json(); ok(!r3.ok && r3.detalhe.includes("kimi"), JSON.stringify(r3));
    await sql`delete from vault.secrets where name in ('telegram_bot_token', 'telegram_ambiente')`;
    await sql`update adm.conexao set estado = 'pendente', saude = 'desconhecida' where codigo = 'ia-anthropic'`;
  });
  await sql.end();
} });
