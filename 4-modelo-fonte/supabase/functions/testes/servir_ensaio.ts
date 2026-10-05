// Só para os testes de navegador (ensaio local). Nunca publicar.
// Serve as funções assinatura, selo e verificar de verdade, contra o banco app_ensaio, com o Google e o Gmail simulados.
// O que o Gmail "enviaria" fica em GET /_emails (para o teste ler o código que chegaria ao e-mail da pessoa).
// Rodar: DENO_DIR=... deno run -A functions/testes/servir_ensaio.ts   (porta 3398, a mesma de testes/config.ensaio.js)
import postgres from "npm:postgres@3.4.4";
import { tratar as assinatura } from "../assinatura/tratar.ts";
import { tratar as selo } from "../selo/tratar.ts";
import { tratar as verificar } from "../verificar/tratar.ts";
import { b64urlDecode, CORS, deB64 } from "../_comum/servidor.ts";

const sql = postgres(Deno.env.get("IMTS_DB_URL") || "postgres://postgres:ensaio-local@127.0.0.1:5499/app_ensaio", { max: 3, prepare: false });
const emails: { para: string; codigo: string | null; em: string }[] = [];
function simulado(input: string | URL | Request, init?: RequestInit): Promise<Response> {
  const url = String(input);
  const J = (b: unknown, s = 200) => Promise.resolve(new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } }));
  if (url.startsWith("https://oauth2.googleapis.com/token")) return J({ access_token: "tok-ensaio", expires_in: 3600 });
  if (url.startsWith("https://gmail.googleapis.com/")) {
    const raw = new TextDecoder().decode(b64urlDecode(JSON.parse(String(init?.body)).raw));
    const corpo = new TextDecoder().decode(deB64(raw.split("\r\n\r\n")[1] || ""));
    emails.push({ para: raw.match(/^To: (.+)$/m)?.[1] || "", codigo: corpo.match(/\b(\d{6})\b/)?.[1] || null, em: new Date().toISOString() });
    return J({ id: "msg" + emails.length });
  }
  return J({ error: { message: "rota não simulada no ensaio: " + url } }, 500);
}
const deps = { sql, fetch: simulado as typeof fetch };
Deno.serve({ port: Number(Deno.env.get("PORTA") || 3398), hostname: "127.0.0.1", onListen: () => console.log("pronto") }, (req) => {
  const p = new URL(req.url).pathname;
  if (p === "/_emails") return new Response(JSON.stringify(emails), { headers: { ...CORS, "content-type": "application/json" } });
  if (p === "/assinatura") return assinatura(req, deps);
  if (p === "/selo") return selo(req, deps);
  if (p === "/verificar") return verificar(req, deps);
  return new Response(JSON.stringify({ erro: "função não servida no ensaio", codigo: 404 }), { status: 404, headers: { ...CORS, "content-type": "application/json" } });
});
