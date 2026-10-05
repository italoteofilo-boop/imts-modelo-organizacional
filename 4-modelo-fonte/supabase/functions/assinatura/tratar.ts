// Função assinatura: segundo fator da assinatura eletrônica avançada (Lei 14.063/2020, art. 4º, II) e selo pedido por quem assina.
// Ações (com o login de quem usa; a permissão é do banco, por adm.servidor_autorizar):
//  * codigo { signatario }: o banco gera o código de 6 dígitos (guarda só o hash) e esta função o manda por e-mail, pelo Gmail
//    da conta do sistema (google.usuario_sistema), com a conta de serviço do cofre (google_conta_servico), como a função alertas;
//  * selar { pedido }: sela na hora o pedido concluído (o banco também pede o selo à função selo, sem depender da tela).
// Implantar com verify_jwt LIGADO. Segredos: google_conta_servico; a chave do selo nasce no cofre (assinatura_chave_privada).
import { autorizar, b64url, CORS, Deps, googleToken, json, lerUsuario, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";
import { selarPendentes } from "../_comum/selar.ts";

const GMAIL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send";
const b64utf8 = (s: string) => { const u = new TextEncoder().encode(s); let t = ""; for (let i = 0; i < u.length; i += 0x8000) t += String.fromCharCode(...u.subarray(i, i + 0x8000)); return btoa(t); };
const assunto = (s: string) => "=?UTF-8?B?" + b64utf8(s) + "?=";

export function emailDoCodigo(de: string, para: string, nome: string, titulo: string, codigo: string, validadeMin: number): string {
  const corpo = [`Olá, ${nome}.`, "", `Seu código para assinar o documento "${titulo}" no IMTS.OS é:`, "", `    ${codigo}`, "",
    `Ele vale por ${validadeMin} minutos e serve uma vez. Não repasse este código a ninguém: ele é o controle exclusivo da sua assinatura eletrônica avançada (Lei 14.063/2020, art. 4º, II).`,
    "Se você não pediu este código, ignore este e-mail: sem ele, ninguém assina em seu nome.", "", "IMTS.OS"].join("\n");
  const msg = [`From: IMTS.OS <${de}>`, `To: ${para}`, `Subject: ${assunto(`IMTS.OS: código para assinar "${titulo.slice(0, 80)}"`)}`,
    "MIME-Version: 1.0", "Content-Type: text/plain; charset=UTF-8", "Content-Transfer-Encoding: base64", "", b64utf8(corpo)].join("\r\n");
  return b64url(msg);
}

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  let acao = "?", pessoa: string | null = null, usuario: string | null = null, alvo: string | null = null;
  try {
    const u = lerUsuario(req, (deps.agora ?? Date.now)());
    // deno-lint-ignore no-explicit-any
    const d: any = await req.json().catch(() => { throw new Recusa("corpo inválido"); });
    acao = String(d.acao || "");
    const a = await autorizar(deps.sql, u, null, "assinatura", acao, d);
    pessoa = a.pessoa ?? null; usuario = a.usuario ?? null;

    if (acao === "codigo") {
      alvo = "signatario:" + a.signatario;
      if (!a.usuario_sistema) throw new Recusa("e-mail do sistema ainda não configurado: falta o parâmetro google.usuario_sistema", 503);
      const conta = await segredo(deps.sql, "google_conta_servico");
      if (!conta) throw new Recusa("e-mail do sistema ainda não configurado: falta o segredo google_conta_servico no cofre", 503);
      let c;
      try { [{ r: c }] = await deps.sql`select doc.assinatura_codigo_emitir(${a.signatario}::bigint) as r`; }
      catch (e) { throw new Recusa(limparErro(e), 409); }
      try {
        const token = await googleToken(deps, conta, a.usuario_sistema, ["https://www.googleapis.com/auth/gmail.send"]);
        const r = await deps.fetch(GMAIL, { method: "POST", headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
          body: JSON.stringify({ raw: emailDoCodigo(a.usuario_sistema, c.email, c.nome, c.titulo, c.codigo, c.validade_min) }) });
        if (!r.ok) throw new Recusa("Gmail respondeu " + r.status, 502);
      } catch (e) {
        await deps.sql`select doc.assinatura_codigo_descartar(${a.signatario}::bigint, ${limparErro(e)})`;
        throw e instanceof Recusa ? e : new Recusa("o e-mail com o código não saiu: " + limparErro(e), 502);
      }
      await registrar(deps.sql, "assinatura", "codigo", pessoa, usuario, alvo, true, "código enviado para " + c.para);
      return json({ enviado: true, para: c.para, validade_min: c.validade_min, tentativas: c.tentativas });
    }

    if (acao === "selar") {
      alvo = "pedido:" + a.pedido;
      const r = await selarPendentes(deps, Number(a.pedido));
      await registrar(deps.sql, "assinatura", "selar", pessoa, usuario, alvo, true, r.selados.length ? "selado: " + r.selados.map((s) => s.codigo).join(", ") : "nada a selar");
      return json(r);
    }
    throw new Recusa("ação desconhecida: " + acao);
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "assinatura", acao, pessoa, usuario, alvo, false, limparErro(e));
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função assinatura", codigo: status }, status);
  }
}
