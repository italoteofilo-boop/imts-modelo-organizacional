// Função conexoes: testa de verdade cada integração, chamada pela Administração (só quem administra).
// Telegram: getMe com o token do cofre. Anthropic: lista de modelos. Kimi: lista de modelos (API compatível com a OpenAI).
// Google: token da conta de serviço em nome da conta do sistema e leitura do usuário no Drive. Outras: GET no endereço cadastrado.
// O resultado vai para adm.conexao (saúde) e adm.registro_servidor. Nenhum segredo sai daqui.
import { autorizar, CORS, Deps, googleToken, json, lerUsuario, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";

type Resultado = { ok: boolean; detalhe: string };

async function testar(deps: Deps, a: Record<string, unknown>): Promise<Resultado> {
  const f = (url: string, init?: RequestInit) => deps.fetch(url, init).catch(() => { throw new Recusa("sem conexão com " + new URL(url).host, 502); });
  switch (a.codigo) {
    case "telegram-bot-api": {
      const t = await segredo(deps.sql, "telegram_bot_token"); if (!t) return { ok: false, detalhe: "falta o token do bot no cofre" };
      const base = a.telegram_ambiente === "producao" ? `https://api.telegram.org/bot${t}` : `https://api.telegram.org/bot${t}/test`;
      const j = await (await f(`${base}/getMe`)).json().catch(() => ({}));
      return j.ok ? { ok: true, detalhe: `bot @${j.result?.username} respondeu (${a.telegram_ambiente})` } : { ok: false, detalhe: "Telegram recusou o token: " + (j.description || "sem resposta") };
    }
    case "ia-anthropic": case "edge-ia": {
      const k = await segredo(deps.sql, "anthropic_chave"); if (!k) return { ok: false, detalhe: "falta anthropic_chave no cofre" };
      const r = await f("https://api.anthropic.com/v1/models", { headers: { "x-api-key": k, "anthropic-version": "2023-06-01" } });
      return r.ok ? { ok: true, detalhe: "Anthropic aceitou a chave" } : { ok: false, detalhe: "Anthropic respondeu " + r.status };
    }
    case "ia-kimi": {
      const k = await segredo(deps.sql, "kimi_chave"); if (!k) return { ok: false, detalhe: "falta kimi_chave no cofre" };
      if (!a.kimi_url) return { ok: false, detalhe: "preencha ia.kimi_url" };
      const r = await f(a.kimi_url + "/models", { headers: { Authorization: "Bearer " + k } });
      const j = await r.json().catch(() => ({}));
      return r.ok ? { ok: true, detalhe: "Kimi aceitou a chave; modelos: " + (j.data || []).map((m: { id: string }) => m.id).slice(0, 8).join(", ") } : { ok: false, detalhe: "Kimi respondeu " + r.status };
    }
    case "edge-google": case "google-drive-imts": {
      const c = await segredo(deps.sql, "google_conta_servico"); if (!c) return { ok: false, detalhe: "falta google_conta_servico no cofre" };
      if (!a.usuario_sistema) return { ok: false, detalhe: "preencha google.usuario_sistema" };
      const tok = await googleToken(deps, c, String(a.usuario_sistema), ["https://www.googleapis.com/auth/drive"]);
      const r = await f("https://www.googleapis.com/drive/v3/about?fields=user", { headers: { Authorization: "Bearer " + tok } });
      const j = await r.json().catch(() => ({}));
      return r.ok ? { ok: true, detalhe: "Drive respondeu como " + (j.user?.emailAddress || a.usuario_sistema) } : { ok: false, detalhe: "Drive respondeu " + r.status };
    }
    default: {
      if (!a.endpoint) return { ok: false, detalhe: "sem endereço cadastrado para testar" };
      const r = await f(String(a.endpoint), { method: "GET" });
      return r.status < 500 ? { ok: true, detalhe: "endereço respondeu " + r.status } : { ok: false, detalhe: "endereço respondeu " + r.status };
    }
  }
}

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  let pessoa: string | null = null, codigo: string | null = null;
  try {
    const u = lerUsuario(req, (deps.agora ?? Date.now)());
    // deno-lint-ignore no-explicit-any
    const d: any = await req.json().catch(() => { throw new Recusa("corpo inválido"); });
    codigo = String(d.codigo || "");
    const a = await autorizar(deps.sql, u, null, "conexoes", String(d.acao || ""), { codigo });
    if (!a) throw new Recusa("conexão desconhecida: " + codigo, 404);
    pessoa = a.pessoa;
    let r: Resultado;
    try { r = await testar(deps, a); } catch (e) { r = { ok: false, detalhe: limparErro(e) }; }
    await deps.sql`select adm.conexao_saude(${codigo}, ${r.ok}, ${r.detalhe})`;
    await registrar(deps.sql, "conexoes", "testar", pessoa, null, codigo, true, (r.ok ? "ok: " : "falha: ") + r.detalhe);
    return json(r);
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "conexoes", "testar", pessoa, null, codigo, false, limparErro(e));
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função conexoes", codigo: status }, status);
  }
}
