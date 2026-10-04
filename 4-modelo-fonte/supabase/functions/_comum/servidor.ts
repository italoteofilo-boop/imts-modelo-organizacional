// Núcleo comum das Edge Functions do IMTS.OS (google, ia, alertas).
// Regra: a função não decide permissão. Ela pergunta ao banco com o login de quem chamou (papel authenticated + claims,
// como o PostgREST faz), executa com a credencial do servidor e registra o que fez em adm.registro_servidor.
// Segredos só no cofre (Vault), lidos por rt._segredo. Nada de segredo em variável de ambiente além do SUPABASE_DB_URL.

// deno-lint-ignore no-explicit-any
export type Sql = any;
export type Fetch = typeof fetch;
export interface Deps { sql: Sql; fetch: Fetch; agora?: () => number }
export interface Usuario { sub: string; claims: Record<string, unknown> }

export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-empresa, x-imts-chave",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });
export class Recusa extends Error { constructor(msg: string, public status = 400) { super(msg); } }

// Lê o login do cabeçalho. A plataforma já conferiu a assinatura (verify_jwt); aqui conferimos papel e validade.
export function lerUsuario(req: Request, agora = Date.now()): Usuario {
  const h = req.headers.get("authorization") || "";
  const t = h.startsWith("Bearer ") ? h.slice(7) : "";
  const partes = t.split(".");
  if (partes.length !== 3) throw new Recusa("sessão ausente: entre de novo", 401);
  let claims: Record<string, unknown>;
  try { claims = JSON.parse(new TextDecoder().decode(b64urlDecode(partes[1]))); } catch { throw new Recusa("sessão inválida", 401); }
  if (claims.role !== "authenticated" || typeof claims.sub !== "string") throw new Recusa("sessão sem usuário", 401);
  if (typeof claims.exp === "number" && claims.exp * 1000 < agora) throw new Recusa("sessão vencida: entre de novo", 401);
  return { sub: claims.sub, claims };
}

// Executa no banco como quem chamou (as políticas e as funções usam rt.eu() e ext.eu()).
export async function comoUsuario<T>(sql: Sql, u: Usuario, empresa: string | null, fn: (tx: Sql) => Promise<T>): Promise<T> {
  return await sql.begin(async (tx: Sql) => {
    await tx`select set_config('request.jwt.claims', ${JSON.stringify(u.claims)}, true), set_config('request.jwt.claim.sub', ${u.sub}, true),
                    set_config('request.headers', ${JSON.stringify(empresa ? { "x-empresa": empresa } : {})}, true)`;
    await tx`set local role authenticated`;
    return await fn(tx);
  });
}

export async function autorizar(sql: Sql, u: Usuario, empresa: string | null, funcao: string, acao: string, dados: unknown) {
  try {
    return await comoUsuario(sql, u, empresa, async (tx) => (await tx`select adm.servidor_autorizar(${funcao}, ${acao}, ${tx.json(dados ?? {})}) as r`)[0].r);
  } catch (e) { throw new Recusa(limparErro(e), 403); }
}

export async function registrar(sql: Sql, funcao: string, acao: string, pessoa: string | null, usuario: string | null, alvo: string | null,
  ok: boolean, detalhe: string | null, tokensEntrada: number | null = null, tokensSaida: number | null = null) {
  try {
    await sql`select adm.servidor_registrar(${funcao}, ${acao}, ${pessoa}::uuid, ${usuario}::uuid, ${alvo}, ${ok}, ${detalhe}, ${tokensEntrada}::int, ${tokensSaida}::int)`;
  } catch (e) { console.error("registro do servidor falhou", e); }
}

export async function segredo(sql: Sql, nome: string): Promise<string | null> {
  const r = await sql`select rt._segredo(${nome}) as v`;
  return r[0]?.v ?? null;
}

export function iguais(a: string | null, b: string | null): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let d = 0; for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

export function limparErro(e: unknown): string {
  const m = String((e as { message?: string })?.message ?? e ?? "erro");
  return m.replace(/^(ERROR:\s*)?(P0001:\s*)?/, "").trim();
}

export function b64urlDecode(s: string): Uint8Array {
  const b = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  return Uint8Array.from(atob(b), (c) => c.charCodeAt(0));
}
export function b64url(bytes: Uint8Array | string): string {
  const u = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = ""; for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode(...u.subarray(i, i + 0x8000));
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
export function b64(bytes: Uint8Array): string {
  let s = ""; for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}
export function deB64(s: string): Uint8Array<ArrayBuffer> {
  const t = atob(s), u = new Uint8Array(new ArrayBuffer(t.length));
  for (let i = 0; i < t.length; i++) u[i] = t.charCodeAt(i);
  return u;
}

// ---------- Google: token da conta de serviço com delegação no domínio (age em nome de um usuário do Workspace) ----------
const cacheTokens = new Map<string, { token: string; ate: number }>();
export async function googleToken(deps: Deps, contaJson: string, emNomeDe: string, escopos: string[]): Promise<string> {
  const chave = emNomeDe + "|" + escopos.join(" ");
  const agora = (deps.agora ?? Date.now)();
  const c = cacheTokens.get(chave); if (c && c.ate > agora + 60_000) return c.token;
  const sa = JSON.parse(contaJson) as { client_email: string; private_key: string; token_uri?: string };
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const k = await crypto.subtle.importKey("pkcs8", deB64(pem), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const iat = Math.floor(agora / 1000);
  const corpo = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" })) + "." +
    b64url(JSON.stringify({ iss: sa.client_email, sub: emNomeDe, scope: escopos.join(" "), aud: sa.token_uri || "https://oauth2.googleapis.com/token", iat, exp: iat + 3600 }));
  const ass = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", k, new TextEncoder().encode(corpo)));
  const r = await deps.fetch(sa.token_uri || "https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: corpo + "." + b64url(ass) }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.access_token) throw new Recusa("Google recusou a conta de serviço: " + (j.error_description || j.error || r.status), 502);
  cacheTokens.set(chave, { token: j.access_token, ate: agora + (Number(j.expires_in) || 3600) * 1000 });
  return j.access_token;
}
export function limparCacheGoogle() { cacheTokens.clear(); }
