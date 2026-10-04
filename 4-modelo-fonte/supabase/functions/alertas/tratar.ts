// Função alertas (B23): leva por e-mail os alertas de operação ainda não enviados (o Telegram já sai pela fila do bot).
// Chamada pela rotina imts-alertas-email (pg_cron + pg_net) com o cabeçalho X-IMTS-Chave = segredo imts_funcao_chave.
// Envia pelo Gmail da conta do sistema (google.usuario_sistema), com a mesma conta de serviço da função google.
import { b64url, CORS, Deps, googleToken, iguais, json, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";

const GMAIL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send";
const assunto = (s: string) => "=?UTF-8?B?" + btoa(String.fromCharCode(...new TextEncoder().encode(s))) + "?=";

export function montarEmail(de: string, para: string[], alertas: { tipo: string; detalhe: string; primeiro_em: string; vezes: number }[]) {
  const linhas = alertas.map((a) => `- [${a.tipo}] ${a.detalhe} (desde ${new Date(a.primeiro_em).toLocaleString("pt-BR", { timeZone: "America/Fortaleza" })}, ${a.vezes} vez(es))`);
  const corpo = `Alertas de operação do IMTS.OS ainda abertos:\n\n${linhas.join("\n")}\n\nVeja e resolva em Administração > Alertas. Este e-mail sai uma vez por alerta.`;
  const msg = [`From: IMTS.OS <${de}>`, `To: ${para.join(", ")}`, `Subject: ${assunto(`IMTS.OS: ${alertas.length} alerta(s) de operação`)}`,
    "MIME-Version: 1.0", "Content-Type: text/plain; charset=UTF-8", "Content-Transfer-Encoding: base64", "", btoa(String.fromCharCode(...new TextEncoder().encode(corpo)))].join("\r\n");
  return b64url(msg);
}

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  try {
    const chave = await segredo(deps.sql, "imts_funcao_chave");
    if (!iguais(req.headers.get("x-imts-chave"), chave)) throw new Recusa("não autorizado", 401);
    const p = (await deps.sql`select adm.alertas_para_email() as r`)[0].r;
    const para: string[] = (p.para || []).filter((e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e));
    if (!p.alertas.length) return json({ enviados: 0 });
    if (!para.length || !p.remetente) throw new Recusa("e-mail de alertas não configurado (alerta.emails e google.usuario_sistema)", 503);
    const conta = await segredo(deps.sql, "google_conta_servico");
    if (!conta) throw new Recusa("falta o segredo google_conta_servico no cofre", 503);
    const token = await googleToken(deps, conta, p.remetente, ["https://www.googleapis.com/auth/gmail.send"]);
    const r = await deps.fetch(GMAIL, { method: "POST", headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
      body: JSON.stringify({ raw: montarEmail(p.remetente, para, p.alertas) }) });
    if (!r.ok) throw new Recusa("Gmail respondeu " + r.status, 502);
    const ids = p.alertas.map((a: { id: number }) => a.id);
    await deps.sql`select adm.alertas_email_enviado(${ids}::bigint[])`;
    await registrar(deps.sql, "alertas", "email", null, null, para.join(","), true, ids.length + " alerta(s)");
    return json({ enviados: ids.length });
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "alertas", "email", null, null, null, false, limparErro(e));
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função alertas", codigo: status }, status);
  }
}
