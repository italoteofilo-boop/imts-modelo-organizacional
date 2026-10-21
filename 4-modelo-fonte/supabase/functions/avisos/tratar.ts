// Função avisos: leva por e-mail os avisos de assinatura enfileirados pelo banco (doc.assinatura_aviso):
//  * vez: chegou a vez da pessoa assinar (o pedido saiu do rascunho, ou quem vinha antes na ordem assinou);
//  * lembrete: o prazo está perto do fim e a assinatura ainda está pendente (um só por signatário).
// Chamada pelo banco (doc._ass_pedir_aviso, pela fila do pg_net) e pela rotina imts-assinatura, sempre com o cabeçalho
// X-IMTS-Chave = segredo imts_funcao_chave. Sem login de pessoa: implantar com verify_jwt desligado.
// Envia pelo Gmail da conta do sistema (google.usuario_sistema), com a conta de serviço do cofre (google_conta_servico).
// O e-mail leva título, quem pediu, prazo e o link da Central (equipe) ou do Portal (cliente e parceiro); nenhum segredo.
// Cada falha volta para a fila do banco (até 5 tentativas); esgotou, o banco abre um alerta de operação.
import { CORS, Deps, emailTexto, googleToken, iguais, json, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";

const GMAIL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send";
const LOTE = 20;

export interface Aviso {
  id: number; tipo: "vez" | "lembrete"; para: string; nome: string; titulo: string; empresa: string | null; pedido_por: string;
  prazo_texto: string; exige_icp: boolean; interno: boolean; link: string;
}

export function textoDoAviso(a: Aviso): { assunto: string; corpo: string } {
  const titulo = a.titulo.length > 80 ? a.titulo.slice(0, 77) + "..." : a.titulo;
  const assunto = a.tipo === "vez" ? `IMTS.OS: sua assinatura em "${titulo}"` : `IMTS.OS: lembrete, o prazo para assinar "${titulo}" está acabando`;
  const onde = a.interno ? "na Central do IMTS.OS, na aba Assinaturas" : "no portal do IMTS.OS, na aba Assinaturas";
  const linhas = [`Olá, ${a.nome}.`, ""];
  if (a.tipo === "vez") linhas.push(`${a.pedido_por} pediu a sua assinatura no documento "${a.titulo}"${a.empresa ? ` (${a.empresa})` : ""}. Chegou a sua vez de assinar.`);
  else linhas.push(`A sua assinatura no documento "${a.titulo}"${a.empresa ? ` (${a.empresa})` : ""}, pedida por ${a.pedido_por}, ainda está pendente e o prazo está perto do fim.`);
  linhas.push(`Prazo: ${a.prazo_texto} (horário de Brasília).`, "", `Para ler e assinar, entre com o seu login ${onde}:`, a.link, "");
  if (a.exige_icp) linhas.push("Este pedido exige assinatura qualificada (certificado ICP-Brasil): assine com o seu certificado, fora do IMTS.OS, e entregue o arquivo assinado a quem pediu.");
  else linhas.push("Na hora de assinar, o IMTS.OS manda outro e-mail com um código de 6 dígitos, que só vale para você.");
  linhas.push("Este e-mail não traz senha, código nem acesso: o link só abre o sistema depois do seu login. Se você não esperava este pedido, fale com quem pediu antes de assinar.", "", "IMTS.OS");
  return { assunto, corpo: linhas.join("\n") };
}

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  try {
    const chave = await segredo(deps.sql, "imts_funcao_chave");
    if (!iguais(req.headers.get("x-imts-chave"), chave)) throw new Recusa("não autorizado", 401);
    const [{ r }] = await deps.sql`select doc.assinatura_avisos_para_enviar(${LOTE}::int) as r`;
    const avisos: Aviso[] = r?.avisos || [];
    if (!avisos.length) return json({ enviados: 0, falhas: 0, esgotados: 0 });
    // configuração faltando conta como falha de cada aviso: depois de 5 tentativas vira alerta de operação
    let token: string | null = null, falhaGeral: string | null = null;
    if (!r.remetente) falhaGeral = "e-mail do sistema não configurado: falta o parâmetro google.usuario_sistema";
    else {
      const conta = await segredo(deps.sql, "google_conta_servico");
      if (!conta) falhaGeral = "e-mail do sistema não configurado: falta o segredo google_conta_servico no cofre";
      else { try { token = await googleToken(deps, conta, r.remetente, ["https://www.googleapis.com/auth/gmail.send"]); } catch (e) { falhaGeral = limparErro(e); } }
    }
    let enviados = 0, falhas = 0, esgotados = 0, ultimoErro: string | null = null;
    for (const a of avisos) {
      let erro = falhaGeral;
      if (!erro && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(a.para || "")) erro = "e-mail do signatário inválido";
      if (!erro) {
        try {
          const t = textoDoAviso(a);
          const resp = await deps.fetch(GMAIL, { method: "POST", headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
            body: JSON.stringify({ raw: emailTexto(r.remetente, a.para, t.assunto, t.corpo) }) });
          if (!resp.ok) erro = "Gmail respondeu " + resp.status;
        } catch (e) { erro = "o Gmail não respondeu: " + limparErro(e); }
      }
      const [{ s }] = await deps.sql`select doc.assinatura_aviso_resultado(${a.id}::bigint, ${!erro}, ${erro}) as s`;
      if (!erro) enviados++; else { falhas++; ultimoErro = erro; if (s === "falhou") esgotados++; }
    }
    await registrar(deps.sql, "assinatura", "aviso", null, null, "avisos:" + avisos.map((a) => a.id).join(","), falhas === 0,
      `${enviados} aviso(s) enviado(s), ${falhas} com falha${esgotados ? ` (${esgotados} esgotado(s), viraram alerta)` : ""}${ultimoErro ? ": " + ultimoErro : ""}`);
    return json({ enviados, falhas, esgotados });
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "assinatura", "aviso", null, null, null, false, limparErro(e));
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função avisos", codigo: status }, status);
  }
}
