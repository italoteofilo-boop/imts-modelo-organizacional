// Função ia (B22): rascunho de ata a partir da transcrição, pela API da Anthropic, com orçamento mensal de tokens.
// Nada é gravado aqui: a tela mostra o rascunho e uma pessoa aprova (ext.reuniao_ata_rascunho / ext.reuniao_ata_aprovar).
// Provedores: Anthropic (segredo anthropic_chave, parâmetro ia.modelo) e Kimi (segredo kimi_chave, parâmetros ia.kimi_url e ia.kimi_modelo);
// ia.provedor escolhe o principal e o outro é a reserva. Orçamento: ia.orcamento_mensal_tokens (soma dos dois).
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


type Resposta = { texto: string; entrada: number | null; saida: number | null; provedor: string };

// deno-lint-ignore no-explicit-any
async function anthropic(deps: Deps, a: any, transcricao: string): Promise<Resposta> {
  const chave = await segredo(deps.sql, "anthropic_chave");
  if (!chave) throw new Recusa("falta o segredo anthropic_chave no cofre", 503);
  const r = await deps.fetch(API, { method: "POST", headers: { "x-api-key": chave, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: a.modelo, max_tokens: 2000, system: INSTRUCAO, messages: [{ role: "user", content: "Transcrição:\n\n" + transcricao }] }) })
    .catch(() => { throw new Recusa("sem conexão com a API da Anthropic", 502); });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Recusa("respondeu " + r.status + ": " + (j?.error?.message || ""), 502);
  const texto = (j.content || []).filter((c: { type: string }) => c.type === "text").map((c: { text: string }) => c.text).join("");
  return { texto, entrada: j.usage?.input_tokens ?? null, saida: j.usage?.output_tokens ?? null, provedor: "anthropic" };
}

// Kimi (Moonshot AI): API compatível com Chat Completions da OpenAI
// deno-lint-ignore no-explicit-any
async function kimi(deps: Deps, a: any, transcricao: string): Promise<Resposta> {
  if (!a.kimi_url || !a.kimi_modelo) throw new Recusa("Kimi não configurada: preencha ia.kimi_url e ia.kimi_modelo", 503);
  const chave = await segredo(deps.sql, "kimi_chave");
  if (!chave) throw new Recusa("falta o segredo kimi_chave no cofre", 503);
  const r = await deps.fetch(a.kimi_url + "/chat/completions", { method: "POST", headers: { Authorization: "Bearer " + chave, "Content-Type": "application/json" },
    body: JSON.stringify({ model: a.kimi_modelo, max_tokens: 2000, messages: [{ role: "system", content: INSTRUCAO }, { role: "user", content: "Transcrição:\n\n" + transcricao }] }) })
    .catch(() => { throw new Recusa("sem conexão com a API Kimi", 502); });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Recusa("respondeu " + r.status + ": " + (j?.error?.message || ""), 502);
  return { texto: String(j.choices?.[0]?.message?.content ?? ""), entrada: j.usage?.prompt_tokens ?? null, saida: j.usage?.completion_tokens ?? null, provedor: "kimi" };
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
    // provedor principal e reserva (parâmetro ia.provedor); a reserva só entra se o principal falhar
    const ordem = a.provedor === "kimi" ? ["kimi", "anthropic"] : ["anthropic", "kimi"];
    const falhas: string[] = [];
    let saida: Resposta | null = null;
    for (const p of ordem) {
      try { saida = p === "kimi" ? await kimi(deps, a, transcricao) : await anthropic(deps, a, transcricao); break; }
      catch (e) { if (e instanceof Recusa && e.status >= 500) { falhas.push(p + ": " + e.message); continue; } throw e; }
    }
    if (!saida) throw new Recusa("IA indisponível: " + falhas.join("; "), 503);
    const ata = lerAta(saida.texto);
    await registrar(deps.sql, "ia", acao, pessoa, null, "reuniao:" + d.reuniao, true, saida.provedor + (falhas.length ? " (reserva)" : ""), saida.entrada, saida.saida);
    return json({ ata });
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "ia", acao, pessoa, null, null, false, limparErro(e));
    if (!(e instanceof Recusa)) console.error(e);
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função ia", codigo: status }, status);
  }
}
