// Função verificar: verificação pública de uma assinatura eletrônica avançada do IMTS.OS, sem login.
// Como o papel anon não executa nada no banco, a verificação passa por aqui: a função lê o registro com a credencial do servidor
// (doc.assinatura_verificacao) e confere o selo ECDSA P-256 com a chave pública. Devolve só o necessário: nome e e-mail mascarado
// de quem assinou, datas, hashes, situação da trilha e do selo. IP, navegador e o manifesto completo não saem daqui.
// Entrada (POST JSON): { codigo, hash? } ou { codigo, arquivo? (base64, até 25 MB) }. O ideal é a página mandar só o hash,
// calculado no navegador: o arquivo não precisa sair do computador de quem verifica.
import { CORS, deB64, Deps, json, limparErro, Recusa, registrar } from "../_comum/servidor.ts";
import { conferirTexto, sha256Hex } from "../_comum/selo.ts";

const MAX_BYTES = 25 * 1024 * 1024;

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  let codigo = "";
  try {
    // deno-lint-ignore no-explicit-any
    const d: any = await req.json().catch(() => { throw new Recusa("corpo inválido"); });
    codigo = String(d.codigo || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    if (codigo.length !== 12) throw new Recusa("código de verificação inválido: são 12 letras e números, como ABCD-EFGH-JKMN");
    let hash: string | null = typeof d.hash === "string" && /^[0-9a-fA-F]{64}$/.test(d.hash) ? d.hash.toLowerCase() : null;
    if (!hash && typeof d.arquivo === "string" && d.arquivo) {
      if (d.arquivo.length > Math.ceil(MAX_BYTES / 3) * 4 + 8) throw new Recusa("arquivo acima de 25 MB", 413);
      let b: Uint8Array; try { b = deB64(d.arquivo); } catch { throw new Recusa("arquivo inválido (base64)"); }
      hash = await sha256Hex(b);
    }
    const [{ r }] = await deps.sql`select doc.assinatura_verificacao(${codigo}, ${hash}) as r`;
    if (!r.encontrado) {
      await registrar(deps.sql, "verificar", "verificar", null, null, codigo.slice(0, 12), true, "código não encontrado");
      return json({ encontrado: false, valido: false, motivos: ["código não encontrado"] }, 404);
    }
    const motivos: string[] = [], avisos: string[] = [];
    const seloConfere = r.manifesto && r.assinatura && r.chave_publica ? await conferirTexto(r.chave_publica, r.manifesto, r.assinatura) : null;
    // deno-lint-ignore no-explicit-any
    let m: any = null; try { m = r.manifesto ? JSON.parse(r.manifesto) : null; } catch { m = null; }
    const manifestoCoerente = !!m && m.codigo === r.codigo && m.documento?.sha256 === r.hash_documento && m.trilha?.hash_final === r.trilha?.hash_conclusao;
    if (r.exige_icp) motivos.push("pedido que exige assinatura qualificada (ICP-Brasil): as assinaturas foram feitas fora e só registradas aqui; confira a assinatura qualificada no próprio PDF assinado");
    else if (r.situacao !== "concluido") motivos.push("pedido " + r.situacao + ": não há assinatura concluída");
    else if (!r.manifesto) motivos.push("assinaturas concluídas, mas o selo do IMTS ainda não foi gerado; tente de novo em alguns minutos");
    else {
      if (seloConfere !== true) motivos.push("o selo não confere com a chave pública do IMTS");
      if (r.manifesto_confere !== true || !manifestoCoerente) motivos.push("o manifesto selado não corresponde ao registro");
    }
    if (!r.trilha?.integra) motivos.push("a trilha de eventos não confere (hash encadeado)");
    if (r.confere_arquivo === "diferente") motivos.push("o arquivo informado não é o documento assinado: o SHA-256 é diferente");
    if (r.hash_documento_atual_confere === false) avisos.push("o PDF guardado no motor documental mudou depois do pedido; vale o original identificado pelo SHA-256 abaixo");
    const valido = motivos.length === 0;
    await registrar(deps.sql, "verificar", "verificar", null, null, r.codigo, true, valido ? "válido" : "inválido: " + motivos.join("; "));
    return json({
      encontrado: true, valido, motivos, avisos, codigo: r.codigo, titulo: r.titulo, empresa: r.empresa, situacao: r.situacao, exige_icp: r.exige_icp,
      pedido_em: r.pedido_em, concluido_em: r.concluido_em,
      signatarios: (r.signatarios || []).map((s: Record<string, unknown>) => ({ ordem: s.ordem, nome: s.nome, email: s.email, tipo: s.tipo, situacao: s.situacao, assinado_em: s.assinado_em, autenticacao: s.autenticacao })),
      documento: { sha256_original: r.hash_documento, sha256_assinado: r.hash_pdf_assinado, formato: r.formato },
      arquivo: r.confere_arquivo, hash_informado: hash,
      trilha: { integra: r.trilha?.integra, eventos: r.trilha?.eventos_conclusao ?? r.trilha?.eventos, hash_final: r.trilha?.hash_conclusao ?? r.trilha?.hash_final },
      selo: { presente: !!r.manifesto, confere: seloConfere, algoritmo: r.algoritmo, kid: r.kid, chave_publica: r.chave_publica, selado_em: r.selado_em },
    });
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "verificar", "verificar", null, null, codigo.slice(0, 12) || null, false, limparErro(e));
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na verificação", codigo: status }, status);
  }
}
