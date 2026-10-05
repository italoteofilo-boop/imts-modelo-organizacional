// Função selo: sela os pedidos de assinatura concluídos que ainda não têm selo (até 5 por chamada).
// Chamada pelo banco ao concluir um pedido (doc._ass_pedir_selo, pela fila do pg_net) e pela rotina imts-assinatura,
// sempre com o cabeçalho X-IMTS-Chave = segredo imts_funcao_chave. Sem login de pessoa: implantar com verify_jwt desligado.
import { CORS, Deps, iguais, json, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";
import { selarPendentes } from "../_comum/selar.ts";

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  try {
    const chave = await segredo(deps.sql, "imts_funcao_chave");
    if (!iguais(req.headers.get("x-imts-chave"), chave)) throw new Recusa("não autorizado", 401);
    const r = await selarPendentes(deps, null);
    if (r.selados.length) await registrar(deps.sql, "assinatura", "selar", null, null, null, true, "selado: " + r.selados.map((s) => s.codigo).join(", "));
    return json(r);
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "assinatura", "selar", null, null, null, false, limparErro(e));
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função selo", codigo: status }, status);
  }
}
