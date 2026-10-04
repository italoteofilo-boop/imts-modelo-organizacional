// Função ia (B22): rascunho de ata a partir da transcrição, pela API da Anthropic, com orçamento mensal de tokens.
// Nada é gravado aqui: a tela mostra o rascunho e uma pessoa aprova (ext.reuniao_ata_rascunho / ext.reuniao_ata_aprovar).
// Segredo no cofre: anthropic_chave. Modelo e orçamento: parâmetros ia.modelo e ia.orcamento_mensal_tokens.
import { autorizar, CORS, Deps, json, lerUsuario, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";

const API = "https://api.anthropic.com/v1/messages";
const MAX_TRANSCRICAO = 120_000;   // caracteres

const INSTRUCAO = `Você redige o rascunho da ata de uma reunião de trabalho em português do Brasil, a partir da transcrição.
Regras: use só o que está na transcrição; não invente nome, número, data nem decisão; quando algo não estiver claro, diga "não ficou claro na transcrição".
Responda APENAS com um objeto JSON, sem texto antes ou depois, no formato:
{"resumo": "até 6 frases", "decisoes": ["decisão tomada"], "encaminhamentos": [{"descricao": "o que fazer", "responsavel": "nome ou papel citado, ou vazio", "prazo": "AAAA-MM-DD ou vazio"}]}`;

export function lerAta(texto: string) {
  const ini = texto.indexOf("{"), fim = texto.lastIndexOf("}");
  if (ini < 0 || fim <= ini) throw new Recusa("a IA não devolveu uma ata legível; tente de novo ou escreva à mão", 502);
  // deno-lint-ignore no-explicit-any
  let a: any; try { a = JSON.parse(texto.slice(ini, fim + 1)); } catch { throw new Recusa("a IA não devolveu uma ata legível; tente de novo ou escreva à mão", 502); }
  const s = (v: unknown, n: number) => String(v ?? "").slice(0, n);
  return {
    resumo: s(a.resumo, 2000),
    decisoes: (Array.isArray(a.decisoes) ? a.decisoes : []).slice(0, 30).map((d: unknown) => s(d, 500)),
    encaminhamentos: (Array.isArray(a.encaminhamentos) ? a.encaminhamentos : []).slice(0, 30).map((e: Record<string, unknown>) => ({
      descricao: s(e?.descricao, 500), responsavel: s(e?.responsavel, 120), prazo: /^\d{4}-\d{2}-\d{2}$/.test(String(e?.prazo ?? "")) ? String(e.prazo) : "" })),
  };
}

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  let acao = "?", pessoa: string | null = null;
  try {
    const u = lerUsuario(req, (deps.agora ?? Date.now)());
    // deno-lint-ignore no-explicit-any
    const d: any = await req.json().catch(() => { throw new Recusa("corpo inválido"); });
    acao = String(d.acao || "");
    if (acao !== "ata_rascunho") throw new Recusa("ação desconhecida: " + acao);
    const transcricao = String(d.transcricao || "").trim();
    if (transcricao.length < 20) throw new Recusa("transcrição vazia ou curta demais");
    if (transcricao.length > MAX_TRANSCRICAO) throw new Recusa("transcrição longa demais para um rascunho (máximo de 120 mil caracteres)");
    const a = await autorizar(deps.sql, u, req.headers.get("x-empresa"), "ia", acao, { reuniao: d.reuniao });
    pessoa = a.pessoa;
    const chave = await segredo(deps.sql, "anthropic_chave");
    if (!chave) throw new Recusa("IA ainda não configurada: falta o segredo anthropic_chave no cofre", 503);
    const r = await deps.fetch(API, { method: "POST", headers: { "x-api-key": chave, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({ model: a.modelo, max_tokens: 2000, system: INSTRUCAO, messages: [{ role: "user", content: "Transcrição:\n\n" + transcricao }] }) });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Recusa("a IA respondeu " + r.status + ": " + (j?.error?.message || ""), 502);
    const texto = (j.content || []).filter((c: { type: string }) => c.type === "text").map((c: { text: string }) => c.text).join("");
    const ata = lerAta(texto);
    await registrar(deps.sql, "ia", acao, pessoa, null, "reuniao:" + d.reuniao, true, null, j.usage?.input_tokens ?? null, j.usage?.output_tokens ?? null);
    return json({ ata });
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "ia", acao, pessoa, null, null, false, limparErro(e));
    if (!(e instanceof Recusa)) console.error(e);
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função ia", codigo: status }, status);
  }
}
