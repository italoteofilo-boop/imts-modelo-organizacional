// Função telegram_app (P6): a porta do Mini App do Telegram (app/tg.html). Implantar com verify_jwt DESLIGADO: não há login do
// Supabase aqui; quem prova a identidade é o próprio Telegram, pela assinatura do initData.
//
// Validação do initData, conforme a documentação oficial do Telegram ("Validating data received via the Mini App",
// https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app):
//   data_check_string = todos os campos recebidos, menos o hash, em ordem alfabética, no formato chave=valor, separados por "\n";
//   secret_key = HMAC_SHA256(<token do bot>, "WebAppData")   (HMAC-SHA-256 do token, com a constante "WebAppData" como chave);
//   válido se hex(HMAC_SHA256(data_check_string, secret_key)) == hash.
// A mesma página recomenda conferir o auth_date para não aceitar dados antigos: aqui, até telegram_app.validade_segundos.
//
// Depois: acha a pessoa pelo Telegram ligado (rt.tg_app_identificar) e executa COM A IDENTIDADE DELA (comoUsuario, papel authenticated),
// pela porta única (public.imts): a permissão é do banco, como na Mesa da web. Nenhum segredo vai ao navegador; a resposta não leva
// pseudônimo nem login. Limite de tentativas por hash do IP (assinatura inválida) e por hash do usuário do Telegram (adm.tg_app_limite).
// Tudo fica em adm.registro_servidor (funcao = telegram_app).
// Entrada (POST JSON): { initData, acao: mesa | concluir | decidir | aceitar | recusar, cartao?, opcao? }.
import { comoUsuario, CORS, Deps, iguais, ipDe, json, limparErro, Recusa, registrar, segredo, Usuario } from "../_comum/servidor.ts";

const ACOES = ["mesa", "concluir", "decidir", "aceitar", "recusar"];
const MAX_INITDATA = 8192;
const enc = new TextEncoder();

async function hmac(chave: Uint8Array, msg: string): Promise<Uint8Array> {
  const k = await crypto.subtle.importKey("raw", chave as BufferSource, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, enc.encode(msg)));
}
const hex = (b: Uint8Array) => [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
async function sha256Hex(s: string): Promise<string> { return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s)))); }

export interface Abertura { usuario: { id: number; first_name?: string }; auth_date: number }

// Confere o initData. Erro: Recusa 401 com o motivo em português.
export async function validarInitData(initData: string, token: string, agoraSeg: number, validadeSeg: number): Promise<Abertura> {
  if (!initData) throw new Recusa("abra pelo Telegram: faltam os dados de abertura", 401);
  if (initData.length > MAX_INITDATA) throw new Recusa("dados de abertura grandes demais", 400);
  const p = new URLSearchParams(initData);
  const hash = (p.get("hash") || "").toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(hash)) throw new Recusa("assinatura do Telegram ausente ou inválida", 401);
  const campos: [string, string][] = [];
  for (const [k, v] of p) if (k !== "hash") campos.push([k, v]);
  campos.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
  const verificar = campos.map(([k, v]) => k + "=" + v).join("\n");
  const chaveSecreta = await hmac(enc.encode("WebAppData"), token);
  if (!iguais(hex(await hmac(chaveSecreta, verificar)), hash)) throw new Recusa("assinatura do Telegram inválida", 401);
  const auth = Number(p.get("auth_date"));
  if (!Number.isFinite(auth) || auth <= 0) throw new Recusa("abertura sem data: feche e abra de novo pelo bot", 401);
  if (auth > agoraSeg + 60) throw new Recusa("abertura com data no futuro: confira o relógio do aparelho", 401);
  if (agoraSeg - auth > validadeSeg) throw new Recusa("abertura vencida: feche o Mini App e abra de novo pelo bot", 401);
  // deno-lint-ignore no-explicit-any
  let u: any; try { u = JSON.parse(p.get("user") || "null"); } catch { u = null; }
  if (!u || !Number.isSafeInteger(u.id) || u.id <= 0) throw new Recusa("abertura sem usuário do Telegram", 401);
  return { usuario: { id: u.id, first_name: typeof u.first_name === "string" ? u.first_name.slice(0, 64) : undefined }, auth_date: auth };
}

const INSTRUCAO = {
  sem_vinculo: "Este Telegram ainda não está ligado a uma pessoa do IMTS.OS. Pessoa da equipe: na Mesa da web, abra Ligar o Telegram, aceite o termo, gere o código " +
    "e envie /vincular CÓDIGO ao bot numa conversa privada (sem acesso à Mesa, peça à Gestão, GE-07, para registrar o seu Telegram no cadastro); " +
    "depois abra a Mesa de novo pelo botão do bot. Parceiro ou cliente: gere o código no portal e envie /vincular CÓDIGO ao bot.",
  externo: "Esta Mesa é da equipe do IMTS. Parceiros e clientes usam o portal (portal.html) e os comandos do bot: mande /ajuda.",
  sem_login: "Seu Telegram está ligado, mas o seu cadastro ainda não tem login no IMTS.OS. Entre uma vez em www.imts.global com a conta do Workspace e abra a Mesa de novo.",
  simulado: "Este Telegram está ligado a uma pessoa simulada (ambiente de teste). Use o bot do ambiente de teste.",
} as Record<string, string>;

function recusaLimite(motivo: string): Response {
  return new Response(JSON.stringify({ erro: motivo, codigo: 429 }), { status: 429, headers: { ...CORS, "Content-Type": "application/json", "Retry-After": "60" } });
}

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  const sql = deps.sql;
  let acao = "?", alvo: string | null = null, pessoa: string | null = null, usuario: string | null = null, cartao: number | null = null;
  try {
    // deno-lint-ignore no-explicit-any
    const d: any = await req.json().catch(() => null);
    if (!d || typeof d !== "object") throw new Recusa("corpo inválido");
    acao = ACOES.includes(String(d.acao || "mesa")) ? String(d.acao || "mesa") : "?";

    const token = await segredo(sql, "telegram_bot_token");
    if (!token) throw new Recusa("Mesa no Telegram indisponível: falta o token do bot no cofre (telegram_bot_token)", 503);
    const [{ v: validade }] = await sql`select coalesce((adm.valor('telegram_app.validade_segundos', '3600') #>> '{}')::int, 3600) as v`;

    // 1. assinatura do Telegram; quem falha conta pelo hash do IP
    let ab: Abertura;
    try {
      ab = await validarInitData(String(d.initData || ""), token, Math.floor((deps.agora ?? Date.now)() / 1000), Number(validade));
    } catch (e) {
      alvo = "ip:" + (await sha256Hex("telegram_app|" + (ipDe(req) || "sem-ip"))).slice(0, 32);
      const [{ m }] = await sql`select adm.tg_app_limite(${alvo}) as m`;
      if (m) return recusaLimite(m);
      throw e;
    }

    // 2. limite por usuário do Telegram (hash, nunca o id em claro no registro)
    alvo = "tg:" + (await sha256Hex("telegram_app|" + ab.usuario.id)).slice(0, 32);
    const [{ m }] = await sql`select adm.tg_app_limite(${alvo}) as m`;
    if (m) return recusaLimite(m);

    // pedido bem formado (conta como tentativa de quem abriu, se não for)
    if (acao === "?") throw new Recusa("ação desconhecida");
    if (acao !== "mesa") {
      cartao = Number(d.cartao);
      if (!Number.isSafeInteger(cartao) || cartao <= 0) { cartao = null; throw new Recusa("cartão inválido"); }
    }
    const opcao = d.opcao == null ? null : Number(d.opcao);
    if (acao === "decidir" && (opcao == null || !Number.isInteger(opcao) || opcao < 0 || opcao > 50)) throw new Recusa("escolha uma opção");

    // 3. quem é
    const [{ r: id }] = await sql`select rt.tg_app_identificar(${ab.usuario.id}::bigint, false) as r`;
    pessoa = id.pessoa ?? null;
    if (id.situacao !== "ok") {
      await registrar(sql, "telegram_app", acao, pessoa, null, alvo, false, id.situacao);
      return json({ erro: "Telegram sem vínculo com uma pessoa da equipe", codigo: id.situacao, instrucao: INSTRUCAO[id.situacao] || INSTRUCAO.sem_vinculo }, 403);
    }
    usuario = id.auth_uid;
    const u: Usuario = { sub: id.auth_uid, claims: { sub: id.auth_uid, role: "authenticated", aud: "authenticated", via: "telegram_app" } };

    // 4. executa como a pessoa, pela porta única
    const [fn, args] = acao === "mesa" ? ["rt.tg_mesa", {}] : ["rt.tg_agir", { p_acao: acao, p_cartao: cartao, p_opcao: acao === "decidir" ? opcao : null }];
    let r;
    try {
      r = await comoUsuario(sql, u, null, async (tx) => (await tx`select public.imts(${fn}, ${tx.json(args)}) as r`)[0].r);
    } catch (e) { throw new Recusa(limparErro(e), 403); }
    await registrar(sql, "telegram_app", acao, pessoa, usuario, alvo, true, cartao ? "cartão #" + cartao : null);
    return json(r);
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    const msg = e instanceof Recusa ? e.message : "falha interna na Mesa do Telegram";
    if (!(e instanceof Recusa)) console.error(e);
    // a recusa entra no registro; falha de configuração (503) não conta como tentativa de quem abriu
    if (alvo || status === 503 || status === 500) await registrar(sql, "telegram_app", acao, pessoa, usuario, alvo, false, msg);
    return json({ erro: msg, codigo: status }, status);
  }
}
