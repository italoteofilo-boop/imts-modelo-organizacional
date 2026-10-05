// Testes das Edge Functions assinatura, selo e verificar contra o banco de ensaio (app_ensaio), com Google e Gmail simulados.
// Rodar: IMTS_DB_URL=postgres://postgres:<senha>@127.0.0.1:5499/app_ensaio deno test -A functions/testes/assinatura_test.ts
import postgres from "npm:postgres@3.4.4";
import { PDFDocument, StandardFonts } from "npm:pdf-lib@1.17.1";
import { emailDoCodigo, tratar as assinatura } from "../assinatura/tratar.ts";
import { tratar as selo } from "../selo/tratar.ts";
import { tratar as verificar } from "../verificar/tratar.ts";
import { anexarManifesto, chaveDoSelo, limparTexto } from "../_comum/selar.ts";
import { assinarTexto, conferirTexto, gerarPar, chavePrivada, kidDe, sha256Hex } from "../_comum/selo.ts";
import { b64, b64url, b64urlDecode, deB64, limparCacheGoogle } from "../_comum/servidor.ts";

const sql = postgres(Deno.env.get("IMTS_DB_URL") || "postgres://postgres:ensaio-local@127.0.0.1:5499/app_ensaio", { max: 2, prepare: false });
const U = { olga: "00000000-0000-4000-8000-000000000002", rui: "00000000-0000-4000-8000-000000000004", clara: "00000000-0000-4000-8000-000000000005", paulo: "00000000-0000-4000-8000-000000000006" };
const tok = (sub: string) => b64url(JSON.stringify({ alg: "HS256" })) + "." + b64url(JSON.stringify({ sub, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 600 })) + ".x";
const pedir = (corpo: unknown, quem: string | null, extra: Record<string, string> = {}) =>
  new Request("http://local/f", { method: "POST", headers: { "content-type": "application/json", ...(quem ? { authorization: "Bearer " + tok(quem) } : {}), ...extra }, body: JSON.stringify(corpo) });
function ok(c: unknown, m: string) { if (!c) throw new Error(m); }

// Google simulado: token da conta de serviço e Gmail (guarda as mensagens); gmailFora derruba o envio
const enviados: string[] = []; let gmailFora = false;
function simulado(input: string | URL | Request, init?: RequestInit): Promise<Response> {
  const url = String(input);
  const J = (b: unknown, s = 200) => Promise.resolve(new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } }));
  if (url.startsWith("https://oauth2.googleapis.com/token")) return J({ access_token: "tok-gmail", expires_in: 3600 });
  if (url.startsWith("https://gmail.googleapis.com/")) {
    if (gmailFora) return J({ error: { message: "indisponível" } }, 503);
    enviados.push(new TextDecoder().decode(b64urlDecode(JSON.parse(String(init?.body)).raw))); return J({ id: "msg" + enviados.length });
  }
  return J({ error: { message: "rota não simulada: " + url } }, 500);
}
const deps = { sql, fetch: simulado as typeof fetch };
function codigoDoUltimoEmail(): { para: string; codigo: string } {
  const raw = enviados[enviados.length - 1];
  const corpo = new TextDecoder().decode(deB64(raw.split("\r\n\r\n")[1]));
  return { para: raw.match(/^To: (.+)$/m)![1], codigo: corpo.match(/\b(\d{6})\b/)![1] };
}
// chama o banco como a pessoa (como o PostgREST faz), com IP e navegador nos cabeçalhos
async function como<T>(uid: string, fn: (tx: postgres.TransactionSql) => Promise<T>): Promise<T> {
  return await sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claims', ${JSON.stringify({ sub: uid, role: "authenticated", amr: [{ method: "oauth", timestamp: 1 }] })}, true),
                    set_config('request.jwt.claim.sub', ${uid}, true),
                    set_config('request.headers', ${JSON.stringify({ "x-forwarded-for": "198.51.100.23", "user-agent": "DenoTeste/2.0" })}, true)`;
    await tx`set local role authenticated`;
    return await fn(tx);
  }) as T;
}
async function contaDeServico() {
  const k = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", k.privateKey));
  const pem = "-----BEGIN PRIVATE KEY-----\n" + b64(pkcs8).replace(/(.{64})/g, "$1\n") + "\n-----END PRIVATE KEY-----\n";
  return JSON.stringify({ client_email: "imts@projeto.iam.gserviceaccount.com", private_key: pem, token_uri: "https://oauth2.googleapis.com/token" });
}
// um PDF de verdade, emitido na Empresa Alfa, como o motor documental guarda
async function pdfEmitido(titulo: string): Promise<{ emissao: number; pdf: Uint8Array }> {
  const d = await PDFDocument.create(); const f = await d.embedFont(StandardFonts.Helvetica);
  d.addPage().drawText(limparTexto(titulo), { x: 50, y: 760, size: 14, font: f }); d.addPage().drawText("Página 2", { x: 50, y: 760, size: 12, font: f });
  const pdf = await d.save();
  const [{ id: emp }] = await sql`select id from org.empresa where nome = 'Empresa Alfa'`;
  const [{ id: ped }] = await sql`insert into doc.pedido (tipo, marca, empresa, conteudo, situacao) values ('nota-debito', 'imts', ${emp}, ${sql.json({ titulo })}, 'emitido') returning id`;
  const h = await sha256Hex(pdf);
  const [{ id: em }] = await sql`insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro, worker) values (${ped}, 'emitido', 2, ${h}, '{}', 'teste-deno') returning id`;
  await sql`insert into doc.arquivo values (${em}, 'pdf', ${pdf}, ${h}, ${pdf.length})`;
  return { emissao: Number(em), pdf };
}

Deno.test({ name: "assinatura eletrônica avançada: funções do servidor", sanitizeResources: false, sanitizeOps: false, async fn(t) {
  limparCacheGoogle();
  await sql`update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema'`;
  if (!(await sql`select 1 from vault.secrets where name = 'google_conta_servico'`).length) await sql`select vault.create_secret(${await contaDeServico()}, 'google_conta_servico')`;
  const marca = Date.now().toString(36);
  const doc1 = await pdfEmitido("Contrato de teste da assinatura " + marca);
  let erro = ""; try { await como(U.rui, (tx) => tx`select doc.assinatura_pedir(${doc1.emissao}::bigint, ${tx.json([])})`); } catch (e) { erro = String(e); }
  ok(erro.includes("ao menos um signatário"), "pedido sem signatário: " + erro);
  const [{ olga }] = await sql`select pseudonimo as olga from rt_chave.login where auth_uid = ${U.olga}`;
  const [{ r: pedido }] = await como(U.rui, (tx) => tx`select doc.assinatura_pedir(${doc1.emissao}::bigint, ${tx.json([{ pessoa: olga }, { usuario: U.clara }])}, now() + interval '3 days') as r`);
  const sigs = await sql`select id, ordem from doc.assinatura_signatario where pedido = ${pedido.id} order by ordem`;
  const [sOlga, sClara] = sigs.map((s) => Number(s.id));

  await t.step("sem login: 401", async () => {
    const r = await assinatura(pedir({ acao: "codigo", signatario: sOlga }, null), deps); ok(r.status === 401, "status " + r.status);
  });
  await t.step("código para quem não é o signatário: 403", async () => {
    const r = await assinatura(pedir({ acao: "codigo", signatario: sOlga }, U.rui), deps); const j = await r.json();
    ok(r.status === 403 && j.erro.includes("não é sua"), JSON.stringify(j));
  });
  await t.step("cliente fora da vez: 403 e nenhum e-mail", async () => {
    const antes = enviados.length;
    const r = await assinatura(pedir({ acao: "codigo", signatario: sClara }, U.clara), deps); const j = await r.json();
    ok(r.status === 403 && j.erro.includes("não é a sua vez") && enviados.length === antes, JSON.stringify(j));
  });
  await t.step("Gmail fora do ar: 502, o código é descartado e a trilha registra", async () => {
    gmailFora = true;
    const r = await assinatura(pedir({ acao: "codigo", signatario: sOlga }, U.olga), deps); gmailFora = false;
    ok(r.status === 502, "status " + r.status);
    const [c] = await sql`select count(*)::int n from doc.assinatura_codigo where signatario = ${sOlga} and invalidado_em is null and usado_em is null`; ok(c.n === 0, "código continuou valendo");
    ok((await sql`select 1 from doc.assinatura_evento where pedido = ${pedido.id} and tipo = 'codigo_nao_enviado'`).length === 1, "trilha sem o envio falho");
    await sql`update doc.assinatura_codigo set criado_em = criado_em - interval '2 minutes' where signatario = ${sOlga}`;
  });
  let codOlga = "";
  await t.step("código por e-mail: sai da conta do sistema para o e-mail da pessoa; o banco só guarda o hash", async () => {
    const r = await assinatura(pedir({ acao: "codigo", signatario: sOlga }, U.olga), deps); const j = await r.json();
    ok(r.status === 200 && j.enviado && j.para === "ol***@imts.com.br" && j.validade_min === 10, JSON.stringify(j));
    const e = codigoDoUltimoEmail(); codOlga = e.codigo;
    ok(e.para === "olga@imts.com.br" && /^\d{6}$/.test(codOlga), "e-mail " + e.para);
    ok(enviados[enviados.length - 1].includes("From: IMTS.OS <sistema@imts.com.br>"), "remetente");
    const [c] = await sql`select hash from doc.assinatura_codigo where signatario = ${sOlga} and usado_em is null and invalidado_em is null`; ok(c && !c.hash.includes(codOlga), "código em claro");
    const [g] = await sql`select ok from adm.registro_servidor where funcao = 'assinatura' and acao = 'codigo' order by id desc limit 1`; ok(g?.ok, "sem registro do servidor");
  });
  await t.step("pedir outro código em menos de um minuto: 409", async () => {
    const r = await assinatura(pedir({ acao: "codigo", signatario: sOlga }, U.olga), deps); const j = await r.json(); ok(r.status === 409 && j.erro.includes("um minuto"), JSON.stringify(j));
  });
  await t.step("olga assina com o código; IP e navegador vêm dos cabeçalhos", async () => {
    const [{ r }] = await como(U.olga, (tx) => tx`select doc.assinatura_assinar(${sOlga}::bigint, ${codOlga}, true) as r`);
    ok(r.assinado && !r.concluido, JSON.stringify(r));
    const [s] = await sql`select evidencia from doc.assinatura_signatario where id = ${sOlga}`;
    ok(s.evidencia.ip === "198.51.100.23" && s.evidencia.agente === "DenoTeste/2.0" && s.evidencia.hash_documento === await sha256Hex(doc1.pdf), JSON.stringify(s.evidencia));
  });
  await t.step("clara recebe o código, assina pelo portal e o pedido conclui", async () => {
    const r = await assinatura(pedir({ acao: "codigo", signatario: sClara }, U.clara), deps); ok(r.status === 200, "status " + r.status + " " + await r.clone().text());
    const e = codigoDoUltimoEmail(); ok(e.para === "clara@prefeitura-exemplo.gov.br", e.para);
    const [{ r: a }] = await como(U.clara, (tx) => tx`select ext.assinatura_assinar(${sClara}::bigint, ${e.codigo}, true) as r`);
    ok(a.concluido, JSON.stringify(a));
  });
  await t.step("selo pela função selo: só com a chave; gera a chave no cofre, assina o manifesto e anexa a página ao PDF", async () => {
    const r0 = await selo(new Request("http://local/selo", { method: "POST", headers: { "x-imts-chave": "errada" }, body: "{}" }), deps); ok(r0.status === 401, "status " + r0.status);
    const [{ v: chave }] = await sql`select rt._segredo('imts_funcao_chave') as v`;
    const r = await selo(new Request("http://local/selo", { method: "POST", headers: { "x-imts-chave": chave }, body: "{}" }), deps); const j = await r.json();
    ok(r.status === 200 && j.selados.some((s: { pedido: number }) => s.pedido === Number(pedido.id)), JSON.stringify(j));
    const [sl] = await sql`select manifesto, assinatura, kid, pdf, hash_pdf, formato from doc.assinatura_selo where pedido = ${pedido.id}`;
    const [{ publica }] = await sql`select publica from doc.assinatura_chave where kid = ${sl.kid}`;
    ok(!("d" in publica) && await conferirTexto(publica, sl.manifesto, sl.assinatura), "assinatura do selo não confere com a chave pública");
    ok(!(await conferirTexto(publica, sl.manifesto.replace(pedido.codigo, "AAAA-BBBB-CCCC"), sl.assinatura)), "selo aceitou manifesto alterado");
    ok(await kidDe(publica) === sl.kid, "kid não é a impressão da chave");
    const final = await PDFDocument.load(new Uint8Array(sl.pdf));
    ok(sl.formato === "original_com_manifesto" && final.getPageCount() >= 3 && await sha256Hex(new Uint8Array(sl.pdf)) === sl.hash_pdf, "PDF final " + final.getPageCount());
    const m = JSON.parse(sl.manifesto); ok(m.documento.sha256 === await sha256Hex(doc1.pdf) && m.signatarios.length === 2 && m.trilha.integra === true, "manifesto " + sl.manifesto.slice(0, 200));
    const r2 = await (await selo(new Request("http://local/selo", { method: "POST", headers: { "x-imts-chave": chave }, body: "{}" }), deps)).json();
    ok(!r2.selados.some((s: { pedido: number }) => s.pedido === Number(pedido.id)), "selou duas vezes");
  });
  await t.step("a chave do selo nasce uma vez: a segunda leitura devolve a mesma", async () => {
    const a = await chaveDoSelo(deps), b = await chaveDoSelo(deps); ok(a.kid === b.kid, "chave trocou");
    ok((await sql`select count(*)::int n from doc.assinatura_chave where ativa`)[0].n === 1, "mais de uma chave ativa");
  });
  await t.step("verificação pública sem login: válida, sem IP nem e-mail inteiro, com a chave pública", async () => {
    const r = await verificar(pedir({ codigo: pedido.codigo.toLowerCase() }, null), deps); const j = await r.json();
    ok(r.status === 200 && j.valido && j.selo.confere && j.trilha.integra && j.signatarios.length === 2 && j.selo.chave_publica?.kty === "EC", JSON.stringify(j));
    const texto = JSON.stringify(j);
    ok(!texto.includes("198.51.100.23") && !texto.includes("DenoTeste") && !texto.includes("olga@imts.com.br") && !texto.includes("clara@prefeitura") && texto.includes("ol***@imts.com.br"), "dado pessoal na resposta");
  });
  await t.step("verificação compara o arquivo: original, assinado (enviado inteiro) e diferente", async () => {
    const j1 = await (await verificar(pedir({ codigo: pedido.codigo, hash: await sha256Hex(doc1.pdf) }, null), deps)).json(); ok(j1.valido && j1.arquivo === "original", JSON.stringify(j1));
    const [sl] = await sql`select pdf from doc.assinatura_selo where pedido = ${pedido.id}`;
    const j2 = await (await verificar(pedir({ codigo: pedido.codigo, arquivo: b64(new Uint8Array(sl.pdf)) }, null), deps)).json(); ok(j2.valido && j2.arquivo === "assinado", JSON.stringify(j2));
    const j3 = await (await verificar(pedir({ codigo: pedido.codigo, hash: "f".repeat(64) }, null), deps)).json(); ok(!j3.valido && j3.arquivo === "diferente", JSON.stringify(j3));
  });
  await t.step("código inexistente: 404; código malformado: 400", async () => {
    const r = await verificar(pedir({ codigo: "ZZZZ-ZZZZ-ZZZZ" }, null), deps); ok(r.status === 404, "status " + r.status);
    const r2 = await verificar(pedir({ codigo: "abc" }, null), deps); ok(r2.status === 400, "status " + r2.status);
  });
  await t.step("pedido ainda aguardando: verificação mostra que não está concluído", async () => {
    const doc2 = await pdfEmitido("Termo aguardando " + marca);
    const [{ r: p2 }] = await como(U.rui, (tx) => tx`select doc.assinatura_pedir(${doc2.emissao}::bigint, ${tx.json([{ pessoa: olga }])}) as r`);
    const j = await (await verificar(pedir({ codigo: p2.codigo }, null), deps)).json();
    ok(!j.valido && j.situacao === "aguardando" && j.motivos[0].includes("aguardando"), JSON.stringify(j));
    await como(U.rui, (tx) => tx`select doc.assinatura_cancelar(${p2.id}::bigint, 'teste das funções do servidor')`);
  });
  await t.step("selar pela função assinatura: só quem participa; sem pendência devolve vazio", async () => {
    const r = await assinatura(pedir({ acao: "selar", pedido: pedido.id }, U.paulo), deps); ok(r.status === 403, "parceiro selou: " + r.status);
    const j = await (await assinatura(pedir({ acao: "selar", pedido: pedido.id }, U.olga), deps)).json(); ok(Array.isArray(j.selados) && j.selados.length === 0, JSON.stringify(j));
  });
  await t.step("página de manifesto: PDF ilegível vira manifesto separado; texto fora da fonte não quebra", async () => {
    const par = await gerarPar(); const priv = await chavePrivada(par.privada);
    const m = { codigo: "ABCD-EFGH-JKMN", verificar: "https://www.imts.global/verificar.html?c=ABCD-EFGH-JKMN", titulo: "Título com \u201Caspas\u201D e emoji 😀", empresa: "Empresa", pedido: 1,
      documento: { emissao: 1, sha256: "a".repeat(64), bytes: 10, paginas: 1 }, pedido_em: new Date().toISOString(), concluido_em: new Date().toISOString(),
      signatarios: Array.from({ length: 14 }, (_, i) => ({ ordem: i + 1, nome: "Pessoa " + (i + 1), email: "pe***@x.com", tipo: "externo", autenticacao: "link", assinado_em: new Date().toISOString(), evento: i + 3, hash_evento: "b".repeat(64) })),
      trilha: { eventos: 30, hash_final: "c".repeat(64), integra: true } };
    const s = await assinarTexto(priv, JSON.stringify(m));
    const r = await anexarManifesto(new TextEncoder().encode("não é PDF"), m, s, par.kid);
    const d = await PDFDocument.load(r.pdf); ok(r.formato === "manifesto_separado" && d.getPageCount() >= 2, "manifesto separado " + d.getPageCount());
  });
  await t.step("e-mail do código: assunto em UTF-8 e sem travessão", () => {
    const raw = new TextDecoder().decode(b64urlDecode(emailDoCodigo("a@b.com", "c@d.com", "Joana", "Contrato nº 1", "123456", 10)));
    ok(raw.includes("Subject: =?UTF-8?B?") && !raw.includes("\u2014"), "e-mail");
  });
  await sql.end();
} });
