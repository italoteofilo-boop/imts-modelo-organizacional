// Testes dos complementos da assinatura (080) nas funções do servidor, contra o banco de ensaio (app_ensaio), com Google e Gmail simulados:
// função avisos (vez de assinar, falha e esgotamento com alerta), limite de consultas da função verificar e rotação da chave do selo.
// Rodar: IMTS_DB_URL=postgres://postgres:<senha>@127.0.0.1:5499/app_ensaio deno test -A functions/testes/avisos_test.ts
import postgres from "npm:postgres@3.4.4";
import { PDFDocument, StandardFonts } from "npm:pdf-lib@1.17.1";
import { tratar as assinatura } from "../assinatura/tratar.ts";
import { textoDoAviso, tratar as avisos } from "../avisos/tratar.ts";
import { tratar as selo } from "../selo/tratar.ts";
import { tratar as verificar } from "../verificar/tratar.ts";
import { limparTexto } from "../_comum/selar.ts";
import { sha256Hex } from "../_comum/selo.ts";
import { b64, b64url, b64urlDecode, deB64, emailTexto, ipDe, limparCacheGoogle } from "../_comum/servidor.ts";

const sql = postgres(Deno.env.get("IMTS_DB_URL") || "postgres://postgres:ensaio-local@127.0.0.1:5499/app_ensaio", { max: 2, prepare: false });
const U = { adm: "00000000-0000-4000-8000-000000000001", olga: "00000000-0000-4000-8000-000000000002", rui: "00000000-0000-4000-8000-000000000004", clara: "00000000-0000-4000-8000-000000000005" };
const tok = (sub: string) => b64url(JSON.stringify({ alg: "HS256" })) + "." + b64url(JSON.stringify({ sub, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 600 })) + ".x";
const pedir = (corpo: unknown, quem: string | null, extra: Record<string, string> = {}) =>
  new Request("http://local/f", { method: "POST", headers: { "content-type": "application/json", ...(quem ? { authorization: "Bearer " + tok(quem) } : {}), ...extra }, body: JSON.stringify(corpo) });
function ok(c: unknown, m: string) { if (!c) throw new Error(m); }
const IPV = { "x-forwarded-for": "192.0.2." + (Math.floor(Math.random() * 250) + 1) };   // IP de documentação, para não somar com outros testes no limite por minuto

// Google simulado: token da conta de serviço e Gmail (guarda as mensagens); gmailFora derruba o envio
const enviados: { para: string; assunto: string; corpo: string }[] = []; let gmailFora = false;
function simulado(input: string | URL | Request, init?: RequestInit): Promise<Response> {
  const url = String(input);
  const J = (b: unknown, s = 200) => Promise.resolve(new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } }));
  if (url.startsWith("https://oauth2.googleapis.com/token")) return J({ access_token: "tok-gmail", expires_in: 3600 });
  if (url.startsWith("https://gmail.googleapis.com/")) {
    if (gmailFora) return J({ error: { message: "indisponível" } }, 503);
    const raw = new TextDecoder().decode(b64urlDecode(JSON.parse(String(init?.body)).raw));
    const sub = raw.match(/^Subject: =\?UTF-8\?B\?(.+)\?=$/m)?.[1] || "";
    enviados.push({ para: raw.match(/^To: (.+)$/m)![1], assunto: new TextDecoder().decode(deB64(sub)), corpo: new TextDecoder().decode(deB64(raw.split("\r\n\r\n")[1])) });
    return J({ id: "msg" + enviados.length });
  }
  return J({ error: { message: "rota não simulada: " + url } }, 500);
}
const deps = { sql, fetch: simulado as typeof fetch };
const comChave = async (f: typeof avisos, extra: Record<string, string> = {}) => {
  const [{ v }] = await sql`select rt._segredo('imts_funcao_chave') as v`;
  return await f(new Request("http://local/f", { method: "POST", headers: { "x-imts-chave": v, ...extra }, body: "{}" }), deps);
};
async function como<T>(uid: string, fn: (tx: postgres.TransactionSql) => Promise<T>): Promise<T> {
  return await sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claims', ${JSON.stringify({ sub: uid, role: "authenticated", amr: [{ method: "oauth", timestamp: 1 }] })}, true),
                    set_config('request.jwt.claim.sub', ${uid}, true), set_config('request.headers', '{}', true)`;
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
async function pdfEmitido(titulo: string): Promise<number> {
  const d = await PDFDocument.create(); const f = await d.embedFont(StandardFonts.Helvetica);
  d.addPage().drawText(limparTexto(titulo), { x: 50, y: 760, size: 14, font: f });
  const pdf = await d.save();
  const [{ id: emp }] = await sql`select id from org.empresa where nome = 'Empresa Alfa'`;
  const [{ id: ped }] = await sql`insert into doc.pedido (tipo, marca, empresa, conteudo, situacao) values ('nota-debito', 'imts', ${emp}, ${sql.json({ titulo })}, 'emitido') returning id`;
  const h = await sha256Hex(pdf);
  const [{ id: em }] = await sql`insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro, worker) values (${ped}, 'emitido', 1, ${h}, '{}', 'teste-deno') returning id`;
  await sql`insert into doc.arquivo values (${em}, 'pdf', ${pdf}, ${h}, ${pdf.length})`;
  return Number(em);
}
// assina com o código que chegou ao e-mail (pela função assinatura, Gmail simulado)
async function assinarComCodigo(sid: number, uid: string, externo: boolean) {
  const r = await assinatura(pedir({ acao: "codigo", signatario: sid }, uid), deps); ok(r.status === 200, "código: " + r.status + " " + await r.clone().text());
  const codigo = enviados.at(-1)!.corpo.match(/\b(\d{6})\b/)![1];
  const [{ r: a }] = await como(uid, (tx) => externo ? tx`select ext.assinatura_assinar(${sid}::bigint, ${codigo}, true) as r` : tx`select doc.assinatura_assinar(${sid}::bigint, ${codigo}, true) as r`);
  ok(a.assinado, JSON.stringify(a)); return a;
}

Deno.test({ name: "assinatura: avisos por e-mail, limite da verificação e rotação da chave", sanitizeResources: false, sanitizeOps: false, async fn(t) {
  limparCacheGoogle();
  await sql`update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema'`;
  if (!(await sql`select 1 from vault.secrets where name = 'google_conta_servico'`).length) await sql`select vault.create_secret(${await contaDeServico()}, 'google_conta_servico')`;
  const [{ base }] = await sql`select coalesce(nullif(rtrim(adm.valor('assinatura.url_app', '""') #>> '{}', '/'), ''), 'https://www.imts.global') as base`;
  const marca = Date.now().toString(36);
  const [{ olga }] = await sql`select pseudonimo as olga from rt_chave.login where auth_uid = ${U.olga}`;
  const [{ r: p1 }] = await como(U.rui, async (tx) => tx`select doc.assinatura_pedir(${await pdfEmitido("Contrato dos avisos " + marca)}::bigint, ${tx.json([{ pessoa: olga }, { usuario: U.clara }])}, now() + interval '3 days') as r`);
  const [sOlga, sClara] = (await sql`select id from doc.assinatura_signatario where pedido = ${p1.id} order by ordem`).map((s) => Number(s.id));

  await t.step("avisos sem a chave: 401 e nenhum e-mail", async () => {
    const antes = enviados.length;
    const r = await avisos(new Request("http://local/avisos", { method: "POST", headers: { "x-imts-chave": "errada" }, body: "{}" }), deps);
    ok(r.status === 401 && enviados.length === antes, "status " + r.status);
  });
  await t.step("vez de assinar: e-mail da conta do sistema com título, quem pediu, prazo e link da Central; sem segredo", async () => {
    const r = await comChave(avisos); const j = await r.json(); ok(r.status === 200 && j.enviados >= 1, JSON.stringify(j));
    const e = enviados.filter((x) => x.para === "olga@imts.com.br" && x.corpo.includes("Contrato dos avisos " + marca));
    ok(e.length === 1, "e-mails para olga: " + e.length);
    const [{ nome: rui }] = await sql`select i.nome from rt_chave.login l join rt_chave.identidade i on i.pseudonimo = l.pseudonimo where l.auth_uid = ${U.rui}`;
    ok(e[0].corpo.includes(rui) && e[0].corpo.includes(base + "/central.html#assinaturas") && /Prazo: \d{2}\/\d{2}\/\d{4} às \d{2}:\d{2}/.test(e[0].corpo), e[0].corpo);
    ok(!/\b\d{6}\b/.test(e[0].corpo) && !e[0].corpo.includes(p1.codigo) && !e[0].corpo.includes(p1.hash_documento) && !e[0].corpo.includes("\u2014") && !e[0].assunto.includes("\u2014"), "segredo ou travessão no e-mail");
    const [a] = await sql`select situacao, tentativas from doc.assinatura_aviso where signatario = ${sOlga} and tipo = 'vez'`; ok(a.situacao === "enviado" && a.tentativas === 1, JSON.stringify(a));
    const [g] = await sql`select ok, acao from adm.registro_servidor where funcao = 'assinatura' and acao = 'aviso' order by id desc limit 1`; ok(g?.ok, "sem registro do servidor");
    const j2 = await (await comChave(avisos)).json();
    ok(enviados.filter((x) => x.para === "olga@imts.com.br" && x.corpo.includes("Contrato dos avisos " + marca)).length === 1, "aviso repetido " + JSON.stringify(j2));
  });
  await t.step("olga assina: a vez passa para clara, que recebe o aviso com o link do Portal", async () => {
    await assinarComCodigo(sOlga, U.olga, false);
    await comChave(avisos);
    const e = enviados.filter((x) => x.para === "clara@prefeitura-exemplo.gov.br" && x.corpo.includes("Contrato dos avisos " + marca));
    ok(e.length === 1 && e[0].corpo.includes(base + "/portal.html#assinaturas") && e[0].corpo.includes("portal"), "aviso da clara: " + e.length);
  });
  await t.step("Gmail fora do ar: o aviso volta para a fila; na 5ª falha encerra e vira alerta de operação", async () => {
    const [{ r: p2 }] = await como(U.rui, async (tx) => tx`select doc.assinatura_pedir(${await pdfEmitido("Termo do Gmail fora " + marca)}::bigint, ${tx.json([{ pessoa: olga }])}, now() + interval '3 days') as r`);
    const [{ id }] = await sql`select id from doc.assinatura_aviso where pedido = ${p2.id}`;
    await sql`update adm.alerta set resolvido_em = now() where chave = 'assinatura:avisos' and resolvido_em is null`;
    gmailFora = true;
    try {
      for (let i = 1; i <= 5; i++) {
        await sql`update doc.assinatura_aviso set proxima_em = now() - interval '1 second' where id = ${id}`;
        const j = await (await comChave(avisos)).json(); ok(j.falhas >= 1, "tentativa " + i + " " + JSON.stringify(j));
        const [a] = await sql`select situacao, tentativas, ultimo_erro, proxima_em > now() as espera from doc.assinatura_aviso where id = ${id}`;
        ok(a.tentativas === i && a.ultimo_erro === "Gmail respondeu 503" && (i < 5 ? a.situacao === "pendente" && a.espera : a.situacao === "falhou"), "tentativa " + i + " " + JSON.stringify(a));
      }
    } finally { gmailFora = false; }
    const [al] = await sql`select detalhe from adm.alerta where chave = 'assinatura:avisos' and resolvido_em is null`;
    ok(al && al.detalhe.includes("pedido nº " + p2.id) && !al.detalhe.includes("olga@imts.com.br"), "alerta: " + JSON.stringify(al));
    const [g] = await sql`select ok, detalhe from adm.registro_servidor where funcao = 'assinatura' and acao = 'aviso' order by id desc limit 1`; ok(g && !g.ok && g.detalhe.includes("esgotado"), JSON.stringify(g));
    await sql`update adm.alerta set resolvido_em = now() where chave = 'assinatura:avisos' and resolvido_em is null`;
    await como(U.rui, (tx) => tx`select doc.assinatura_cancelar(${p2.id}::bigint, 'teste da função avisos')`);
  });
  await t.step("verificar: passou do limite por IP responde 429 com Retry-After; outro IP passa; o código também tem limite", async () => {
    const [{ antes }] = await sql`select valor as antes from adm.parametro where chave = 'verificar.limite_por_minuto'`;
    await sql`update adm.parametro set valor = '3' where chave = 'verificar.limite_por_minuto'`;
    try {
      const ip = "203.0.113." + (Math.floor(Math.random() * 200) + 20), cod = "ZZZZ-ZZZZ-" + marca.slice(-4).toUpperCase().replace(/[^A-Z2-9]/g, "Z").padEnd(4, "Z");
      for (let i = 1; i <= 3; i++) { const r = await verificar(pedir({ codigo: cod }, null, { "x-forwarded-for": ip + ", 10.0.0.1" }), deps); ok(r.status === 404, "consulta " + i + ": " + r.status); }
      const r4 = await verificar(pedir({ codigo: "QQQQ-RRRR-SSSS" }, null, { "x-forwarded-for": ip }), deps); const j4 = await r4.json();
      ok(r4.status === 429 && Number(r4.headers.get("retry-after")) >= 1 && j4.erro.includes("muitas consultas"), r4.status + " " + JSON.stringify(j4));
      const r5 = await verificar(pedir({ codigo: cod }, null, { "cf-connecting-ip": "198.51.100.201", "x-forwarded-for": ip }), deps); ok(r5.status === 429, "código passou do limite: " + r5.status);
      const r6 = await verificar(pedir({ codigo: "QQQQ-RRRR-" + marca.slice(-4).toUpperCase() }, null, { "x-real-ip": "198.51.100." + (Math.floor(Math.random() * 250) + 1) }), deps); ok(r6.status === 404, "outro IP e outro código: " + r6.status);
      ok(!(await sql`select 1 from doc.verificar_consulta where chave like ${"%" + ip + "%"}`).length, "IP em claro no banco");
      ok(ipDe(pedir({}, null, { "cf-connecting-ip": "1.1.1.1", "x-real-ip": "2.2.2.2" })) === "1.1.1.1" && ipDe(pedir({}, null, { "x-forwarded-for": " 3.3.3.3 , 4.4.4.4" })) === "3.3.3.3", "ordem dos cabeçalhos de IP");
    } finally { await sql`update adm.parametro set valor = ${antes} where chave = 'verificar.limite_por_minuto'`; }
  });
  await t.step("rotação da chave: só a administração; o selo antigo continua válido pelo kid e a selagem seguinte usa chave nova", async () => {
    ok((await (await verificar(pedir({ codigo: p1.codigo }, null, IPV), deps)).json()).situacao === "aguardando", "p1 deveria aguardar a clara");
    await assinarComCodigo(sClara, U.clara, true);
    const s1 = await (await comChave(selo)).json(); ok(s1.selados?.some((s: { pedido: number }) => s.pedido === Number(p1.id)), JSON.stringify(s1));
    const [{ kid: kidAntigo }] = await sql`select kid from doc.assinatura_selo where pedido = ${p1.id}`;
    let erro = ""; try { await como(U.rui, (tx) => tx`select adm.assinatura_chave_rotacionar('sem administrar')`); } catch (e) { erro = String(e); }
    ok(erro.includes("administração"), "rotacionou sem administrar: " + erro);
    const [{ r: rot }] = await como(U.adm, (tx) => tx`select adm.assinatura_chave_rotacionar('Rotação de teste das funções do servidor') as r`);
    ok(rot.kid_aposentada === kidAntigo, JSON.stringify(rot));
    ok(!(await sql`select 1 from vault.secrets where name = 'assinatura_chave_privada'`).length && !(await sql`select 1 from doc.assinatura_chave where ativa`).length, "chave ainda ativa ou privada no cofre");
    const v1 = await (await verificar(pedir({ codigo: p1.codigo }, null, IPV), deps)).json();
    ok(v1.valido && v1.selo.confere && v1.selo.kid === kidAntigo, "selo antigo depois da rotação: " + JSON.stringify(v1));
    const [{ r: p3 }] = await como(U.rui, async (tx) => tx`select doc.assinatura_pedir(${await pdfEmitido("Contrato depois da rotação " + marca)}::bigint, ${tx.json([{ pessoa: olga }])}, now() + interval '3 days') as r`);
    const [{ id: s3 }] = await sql`select id from doc.assinatura_signatario where pedido = ${p3.id}`;
    await assinarComCodigo(Number(s3), U.olga, false);
    const s2 = await (await comChave(selo)).json(); ok(s2.selados?.some((s: { pedido: number }) => s.pedido === Number(p3.id)), JSON.stringify(s2));
    const [{ kid: kidNovo }] = await sql`select kid from doc.assinatura_selo where pedido = ${p3.id}`;
    ok(kidNovo !== kidAntigo && (await sql`select 1 from doc.assinatura_chave where kid = ${kidNovo} and ativa`).length === 1, "selagem seguinte sem chave nova");
    const v3 = await (await verificar(pedir({ codigo: p3.codigo }, null, IPV), deps)).json(); ok(v3.valido && v3.selo.kid === kidNovo, JSON.stringify(v3));
    const v1b = await (await verificar(pedir({ codigo: p1.codigo }, null, IPV), deps)).json(); ok(v1b.valido && v1b.selo.kid === kidAntigo, "selo antigo depois da chave nova");
    const [h] = await sql`select h.por, h.depois, l.auth_uid from adm.historico h left join rt_chave.login l on l.pseudonimo = h.por
                           where h.chave = 'segredo:assinatura_chave_privada' and h.depois ? 'privada_destruida_no_cofre' order by h.id desc limit 1`;
    ok(h && h.auth_uid === U.adm && h.depois.kid === kidAntigo && h.depois.privada_destruida_no_cofre === true && !JSON.stringify(h.depois).includes('"d"'), JSON.stringify(h));
  });
  await t.step("texto do aviso: lembrete, pedido ICP-Brasil e e-mail em UTF-8 sem travessão", () => {
    const a = { id: 1, tipo: "lembrete" as const, para: "c@d.com", nome: "Joana", titulo: "Contrato nº 1", empresa: "Empresa", pedido_por: "Rui", prazo_texto: "01/12/2026 às 18:00",
      exige_icp: true, interno: false, link: "https://www.imts.global/portal.html#assinaturas" };
    const t1 = textoDoAviso(a); ok(t1.assunto.includes("lembrete") && t1.corpo.includes("ICP-Brasil") && t1.corpo.includes(a.link) && !t1.corpo.includes("\u2014"), t1.corpo);
    const raw = new TextDecoder().decode(b64urlDecode(emailTexto("a@b.com", "c@d.com", t1.assunto, t1.corpo))); ok(raw.includes("Subject: =?UTF-8?B?") && raw.includes("From: IMTS.OS <a@b.com>"), raw);
  });
  await sql.end();
} });
