// Testes da função telegram_app (Mini App do Telegram) contra o banco de ensaio (app_ensaio), com o Telegram simulado:
// o initData é montado e assinado aqui com um token de teste, pelo algoritmo da documentação oficial.
// Rodar: IMTS_DB_URL=postgres://postgres:<senha>@127.0.0.1:5499/app_ensaio deno test -A functions/testes/telegram_app_test.ts
import postgres from "npm:postgres@3.4.4";
import { tratar, validarInitData } from "../telegram_app/tratar.ts";
import { ajustarBotoes, menuMesa } from "../telegram/botoes.ts";

const sql = postgres(Deno.env.get("IMTS_DB_URL") || "postgres://postgres:ensaio-local@127.0.0.1:5499/app_ensaio", { max: 2, prepare: false });
const TOKEN = "123456:token-de-teste-do-mini-app";
const OLGA = "00000000-0000-4000-8000-000000000002";
const TG_OLGA = 770000000 + Math.floor(Math.random() * 9_000_000);
const TG_ESTRANHO = TG_OLGA + 10_000_000;
const IP = "198.51.100." + (1 + Math.floor(Math.random() * 250));
function ok(c: unknown, m: string) { if (!c) throw new Error(m); }

const enc = new TextEncoder();
async function hmac(chave: Uint8Array, msg: string) {
  const k = await crypto.subtle.importKey("raw", chave as BufferSource, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, enc.encode(msg)));
}
const hex = (b: Uint8Array) => [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
// initData como o Telegram entrega: query string com hash = hex(HMAC_SHA256(data_check_string, HMAC_SHA256(token, "WebAppData")))
async function initData(tg: number, opc: { idade?: number; token?: string; mexer?: boolean } = {}) {
  const campos: Record<string, string> = {
    auth_date: String(Math.floor(Date.now() / 1000) - (opc.idade ?? 5)),
    query_id: "AAH" + tg,
    user: JSON.stringify({ id: tg, first_name: "Teste", language_code: "pt-br" }),
    signature: "assinatura-ed25519-de-terceiros",
  };
  const dcs = Object.keys(campos).sort().map((k) => k + "=" + campos[k]).join("\n");
  const hash = hex(await hmac(await hmac(enc.encode("WebAppData"), opc.token ?? TOKEN), dcs));
  const p = new URLSearchParams({ ...campos, hash });
  if (opc.mexer) p.set("user", JSON.stringify({ id: tg + 1, first_name: "Outro" }));
  return p.toString();
}
const pedir = (corpo: unknown, ip = IP) => new Request("http://local/telegram_app", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": ip }, body: JSON.stringify(corpo) });
const deps = { sql, fetch: (() => { throw new Error("a função não deveria chamar a rede"); }) as unknown as typeof fetch };
const chama = async (corpo: unknown, ip?: string) => { const r = await tratar(pedir(corpo, ip), deps); return { status: r.status, j: await r.json() }; };

let pessoaOlga = "", consentimentoAntes: Date | null = null, tokenAntes: string | null = null;
async function preparar() {
  [{ pseudonimo: pessoaOlga }] = await sql`select pseudonimo from rt_chave.login where auth_uid = ${OLGA}`;
  [{ c: consentimentoAntes }] = await sql`select consentimento_art33_em as c from rt_chave.identidade where pseudonimo = ${pessoaOlga}`;
  // pessoa real com Telegram precisa do consentimento (LGPD, art. 33): o ensaio registra e desfaz no fim
  await sql`update rt_chave.identidade set telegram_id = ${TG_OLGA}, consentimento_art33_em = coalesce(consentimento_art33_em, now()) where pseudonimo = ${pessoaOlga}`;
  [{ v: tokenAntes }] = await sql`select rt._segredo('telegram_bot_token') as v`;
  await sql`delete from vault.secrets where name = 'telegram_bot_token'`;
}
async function limpar() {
  await sql`update rt_chave.identidade set telegram_id = null, consentimento_art33_em = ${consentimentoAntes} where pseudonimo = ${pessoaOlga} and telegram_id = ${TG_OLGA}`;
  await sql`delete from vault.secrets where name = 'telegram_bot_token'`;
  if (tokenAntes) await sql`select vault.create_secret(${tokenAntes}, 'telegram_bot_token')`;   // o cofre volta como estava
  await sql`update adm.parametro set valor = '10' where chave = 'telegram_app.tentativas_max'`;
}

Deno.test("validação do initData (algoritmo oficial)", async () => {
  const agora = Math.floor(Date.now() / 1000);
  const a = await validarInitData(await initData(42), TOKEN, agora, 3600); ok(a.usuario.id === 42, "id");
  for (const [nome, d, tok, val] of [["token errado", await initData(42, { token: "999:outro" }), TOKEN, 3600], ["campo alterado", await initData(42, { mexer: true }), TOKEN, 3600],
    ["vencido", await initData(42, { idade: 7200 }), TOKEN, 3600], ["vazio", "", TOKEN, 3600], ["sem hash", "auth_date=1&user=%7B%7D", TOKEN, 3600]] as [string, string, string, number][]) {
    let recusou = false; try { await validarInitData(d, tok, agora, val); } catch (e) { recusou = (e as { status?: number }).status === 401; }
    ok(recusou, "aceitou: " + nome);
  }
});

Deno.test("botões do bot: web_app só em conversa privada; menu da Mesa", () => {
  const b = [[{ text: "Concluir #1", callback_data: "c:1" }], [{ text: "Abrir a Mesa", web_app: { url: "https://www.imts.global/tg.html" } }]];
  ok(ajustarBotoes(b, "123") === b, "privado mudou");
  const g = ajustarBotoes(b, "-100123") as Record<string, unknown>[][];
  ok(g[1][0].url === "https://www.imts.global/tg.html" && !("web_app" in g[1][0]) && g[0][0].callback_data === "c:1", JSON.stringify(g));
  ok(menuMesa("https://homolog.imts.global/tg.html").menu_button.type === "web_app" && menuMesa(null).menu_button.type === "commands", "menu");
});

Deno.test({ name: "função telegram_app contra o banco de ensaio", sanitizeResources: false, sanitizeOps: false, async fn(t) {
  await preparar();
  try {
    await t.step("sem o token do bot no cofre: 503 com o motivo", async () => {
      const { status, j } = await chama({ initData: await initData(TG_OLGA), acao: "mesa" });
      ok(status === 503 && j.erro.includes("telegram_bot_token"), JSON.stringify(j));
    });
    await sql`select vault.create_secret(${TOKEN}, 'telegram_bot_token')`;

    await t.step("initData válido: a Mesa da pessoa, sem ids internos", async () => {
      const { status, j } = await chama({ initData: await initData(TG_OLGA), acao: "mesa" });
      ok(status === 200 && j.nome === "Olga Operações" && Array.isArray(j.cartoes) && j.cartoes.length >= 1, JSON.stringify(j).slice(0, 300));
      const texto = JSON.stringify(j);
      ok(!texto.includes(pessoaOlga) && !texto.includes(OLGA) && !/"dono"|"delegado_pessoa"|"tarefa"|"para"/.test(texto), "vazou id interno");
      ok(j.cartoes.every((c: { coluna: string }) => c.coluna !== "feito"), "trouxe feito");
      const dec = j.cartoes.find((c: { coluna: string }) => c.coluna === "decidir");
      ok(!dec || (Array.isArray(dec.opcoes) && dec.opcoes.every((o: unknown) => typeof o === "string")), "opções com destino interno");
      const [reg] = await sql`select ok, pessoa, usuario, alvo from adm.registro_servidor where funcao = 'telegram_app' and acao = 'mesa' order by id desc limit 1`;
      ok(reg.ok && reg.pessoa === pessoaOlga && reg.usuario === OLGA && /^tg:[0-9a-f]{32}$/.test(reg.alvo) && !reg.alvo.includes(String(TG_OLGA)), JSON.stringify(reg));
    });

    await t.step("assinatura inválida: 401 e registro pelo hash do IP", async () => {
      const { status, j } = await chama({ initData: await initData(TG_OLGA, { token: "999:outro" }), acao: "mesa" });
      ok(status === 401 && j.erro.includes("assinatura"), JSON.stringify(j));
      const [reg] = await sql`select ok, alvo, pessoa from adm.registro_servidor where funcao = 'telegram_app' order by id desc limit 1`;
      ok(!reg.ok && /^ip:[0-9a-f]{32}$/.test(reg.alvo) && !reg.alvo.includes(IP) && reg.pessoa === null, JSON.stringify(reg));
    });

    await t.step("dados alterados depois de assinados: 401", async () => {
      const { status } = await chama({ initData: await initData(TG_OLGA, { mexer: true }), acao: "mesa" }); ok(status === 401, "status " + status);
    });

    await t.step("abertura vencida (auth_date antigo): 401", async () => {
      const { status, j } = await chama({ initData: await initData(TG_OLGA, { idade: 7200 }), acao: "mesa" });
      ok(status === 401 && j.erro.includes("vencida"), JSON.stringify(j));
    });

    await t.step("Telegram sem vínculo: 403 com a instrução de vincular pelo bot", async () => {
      const { status, j } = await chama({ initData: await initData(TG_ESTRANHO), acao: "mesa" });
      ok(status === 403 && j.codigo === "sem_vinculo" && j.instrucao.includes("/vincular") && j.instrucao.includes("GE-07") && !("cartoes" in j), JSON.stringify(j));
    });

    await t.step("ação autorizada: concluir uma tarefa avulsa da pessoa", async () => {
      const [{ id }] = await sql`select rt.criar_avulsa(${pessoaOlga}::uuid, ${"Mini App: conferir " + Date.now().toString(36)}, now() + interval '1 day', null, 'telegram') as id`;
      const { status, j } = await chama({ initData: await initData(TG_OLGA), acao: "concluir", cartao: Number(id) });
      ok(status === 200 && j.texto.startsWith("Feito: #" + id), JSON.stringify(j));
      const [c] = await sql`select coluna from rt.cartao where id = ${id}`; ok(c.coluna === "feito", "não concluiu: " + c.coluna);
      const [reg] = await sql`select ok, detalhe from adm.registro_servidor where funcao = 'telegram_app' and acao = 'concluir' order by id desc limit 1`;
      ok(reg.ok && reg.detalhe === "cartão #" + id, JSON.stringify(reg));
    });

    await t.step("ação recusada pelo banco: concluir o cartão de outra pessoa", async () => {
      const [alheio] = await sql`select c.id from rt.cartao c where c.dono <> ${pessoaOlga}::uuid and c.coluna not in ('feito', 'decidir')
        and c.delegado_pessoa is distinct from ${pessoaOlga}::uuid order by c.id limit 1`;
      ok(alheio, "ensaio sem cartão de outra pessoa");
      const { status, j } = await chama({ initData: await initData(TG_OLGA), acao: "concluir", cartao: Number(alheio.id) });
      ok(status === 403 && j.erro, JSON.stringify(j));
      const [c] = await sql`select coluna from rt.cartao where id = ${alheio.id}`; ok(c.coluna !== "feito", "concluiu o cartão alheio");
      const [reg] = await sql`select ok from adm.registro_servidor where funcao = 'telegram_app' and acao = 'concluir' order by id desc limit 1`; ok(!reg.ok, "sem registro da recusa");
    });

    await t.step("decidir com opção inexistente: 403 sem mexer no fluxo", async () => {
      const [dec] = await sql`select id from rt.cartao where dono = ${pessoaOlga}::uuid and coluna = 'decidir' order by id limit 1`;
      if (!dec) return;
      const { status, j } = await chama({ initData: await initData(TG_OLGA), acao: "decidir", cartao: Number(dec.id), opcao: 49 });
      ok(status === 403 && j.erro.includes("opção inválida"), JSON.stringify(j));
    });

    await t.step("pedido mal formado conta como tentativa: ação desconhecida 400", async () => {
      const { status } = await chama({ initData: await initData(TG_OLGA), acao: "apagar_tudo" }); ok(status === 400, "status " + status);
    });

    await t.step("limite de tentativas: assinatura inválida repetida vira 429", async () => {
      await sql`update adm.parametro set valor = '3' where chave = 'telegram_app.tentativas_max'`;
      const ip = "203.0.113." + (1 + Math.floor(Math.random() * 250));
      const ruim = await initData(TG_OLGA, { token: "999:outro" });
      const s: number[] = [];
      for (let i = 0; i < 4; i++) s.push((await chama({ initData: ruim, acao: "mesa" }, ip)).status);
      ok(s.join(",") === "401,401,401,429", "sequência " + s);
      await sql`update adm.parametro set valor = '10' where chave = 'telegram_app.tentativas_max'`;
      // quem tem assinatura válida não é barrado pelo IP
      const { status } = await chama({ initData: await initData(TG_OLGA), acao: "mesa" }, ip); ok(status === 200, "válido barrado: " + status);
    });
  } finally {
    await limpar();
    await sql.end();
  }
} });
