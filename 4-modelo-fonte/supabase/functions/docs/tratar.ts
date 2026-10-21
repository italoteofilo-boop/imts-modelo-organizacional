// Função docs (P6, migração 084): fila dos Google Docs dos documentos emitidos. Toma até 5 pedidos vencidos de doc.google_doc,
// sobe o HTML emitido para o Drive com conversão para Google Docs (mesmo código da ação docs_criar da função google) e devolve
// o resultado ao banco (doc.gdoc_concluir ou doc.gdoc_falhar, que registram em adm.registro_servidor).
// Chamada pelo banco ao emitir (doc._gdoc_chamar, pela fila do pg_net) e pela rotina imts-docs-google, sempre com o cabeçalho
// X-IMTS-Chave = segredo imts_funcao_chave. Sem login de pessoa: implantar com verify_jwt desligado.
import { CORS, Deps, iguais, json, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";
import { processarFilaDocs } from "../google/tratar.ts";

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  try {
    const chave = await segredo(deps.sql, "imts_funcao_chave");
    if (!iguais(req.headers.get("x-imts-chave"), chave)) throw new Recusa("não autorizado", 401);
    return json(await processarFilaDocs(deps, 5));
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "google", "docs_fila", null, null, null, false, limparErro(e));
    if (!(e instanceof Recusa)) console.error(e);
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função docs", codigo: status }, status);
  }
}
