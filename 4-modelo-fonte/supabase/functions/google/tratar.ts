// Função google (B21): Drive do acervo e Agenda com Meet, pela conta de serviço com delegação no domínio.
// Contrato: app/CONTRATO.md. Permissão: adm.servidor_autorizar. Registro: adm.servidor_registrar.
// Segredo no cofre: google_conta_servico (JSON da chave da conta de serviço).
// P6 (084): ação docs_criar e a fila dos Google Docs (processarFilaDocs, usada pela função docs), com o mesmo código de geração.
import { autorizar, b64, deB64, Deps, googleToken, json, lerUsuario, limparErro, Recusa, registrar, segredo, CORS } from "../_comum/servidor.ts";

const DRIVE = "https://www.googleapis.com/drive/v3";
const UPLOAD = "https://www.googleapis.com/upload/drive/v3";
const AGENDA = "https://www.googleapis.com/calendar/v3";
const ESC_DRIVE = ["https://www.googleapis.com/auth/drive"];
const ESC_AGENDA = ["https://www.googleapis.com/auth/calendar.events"];
const PASTA = "application/vnd.google-apps.folder";
const DOC = "application/vnd.google-apps.document";
const MAX_BYTES = 25 * 1024 * 1024;
const ID = /^[A-Za-z0-9_-]{10,}$/;

export type Ctx = { deps: Deps; token: string };
async function g(ctx: Ctx, url: string, init: RequestInit = {}) {
  const r = await ctx.deps.fetch(url, { ...init, headers: { Authorization: "Bearer " + ctx.token, ...(init.headers || {}) } });
  if (!r.ok) {
    const j = await r.json().catch(() => ({}));
    throw new Recusa("Google respondeu " + r.status + ": " + (j?.error?.message || r.statusText), r.status === 404 ? 404 : 502);
  }
  return r;
}
const q = (s: string) => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'");

// Acha (ou cria) uma pasta pelo nome dentro da mãe
async function pastaFilha(ctx: Ctx, mae: string, nome: string): Promise<string> {
  const busca = `name = '${q(nome)}' and '${q(mae)}' in parents and mimeType = '${PASTA}' and trashed = false`;
  const r = await (await g(ctx, `${DRIVE}/files?supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id)&q=${encodeURIComponent(busca)}`)).json();
  if (r.files?.length) return r.files[0].id;
  const c = await (await g(ctx, `${DRIVE}/files?supportsAllDrives=true&fields=id`, { method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: nome, mimeType: PASTA, parents: [mae] }) })).json();
  return c.id;
}

// Garante raiz da empresa e a pasta do acervo; registra no banco o que criou
// deno-lint-ignore no-explicit-any
export async function garantirPasta(ctx: Ctx, a: any): Promise<string> {
  if (a.pasta_id) return a.pasta_id;
  let raiz = a.raiz_id as string | null;
  if (!raiz) {
    if (!a.drive_raiz) throw new Recusa("Drive ainda não configurado: falta o parâmetro google.drive_raiz", 503);
    raiz = await pastaFilha(ctx, a.drive_raiz, a.empresa_nome);
    await ctx.deps.sql`select adm.servidor_pasta(${a.empresa}::uuid, 'raiz', ${raiz})`;
  }
  if (a.pasta === "raiz") return raiz;
  const id = await pastaFilha(ctx, raiz, a.pasta_nome);
  await ctx.deps.sql`select adm.servidor_pasta(${a.empresa}::uuid, ${a.pasta}, ${id})`;
  return id;
}

// Corpo multipart/related do upload do Drive: metadados em JSON e o conteúdo do arquivo
function multipart(meta: Record<string, unknown>, mime: string, bytes: Uint8Array): { corpo: Uint8Array<ArrayBuffer>; tipo: string } {
  const limite = "imts" + crypto.randomUUID().replace(/-/g, "");
  const ini = new TextEncoder().encode(`--${limite}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(meta)}\r\n--${limite}\r\nContent-Type: ${mime}\r\n\r\n`);
  const fim = new TextEncoder().encode(`\r\n--${limite}--`);
  const corpo = new Uint8Array(new ArrayBuffer(ini.length + bytes.length + fim.length)); corpo.set(ini); corpo.set(bytes, ini.length); corpo.set(fim, ini.length + bytes.length);
  return { corpo, tipo: `multipart/related; boundary=${limite}` };
}

// ---------- Google Docs como terceira saída dos documentos emitidos (P6, migração 084) ----------
// O HTML emitido pelo motor sobe por upload multipart com o mimeType do Google Docs nos metadados: o Drive converte na hora e o arquivo
// nasce como Google Doc editável. Documentação oficial do Drive API v3, "Upload file data", seção de importação para tipos do Google
// Workspace: o mimeType dos metadados é o tipo de destino e HTML está entre os formatos aceitos para Google Docs (a lista vale para a
// conta em about.importFormats): https://developers.google.com/workspace/drive/api/guides/manage-uploads
// deno-lint-ignore no-explicit-any
export async function criarDocGoogle(ctx: Ctx, item: any): Promise<{ id: string; link: string }> {
  const bytes = deB64(String(item.html || ""));
  if (!bytes.length) throw new Recusa("emissão sem o HTML para converter");
  if (bytes.length > MAX_BYTES) throw new Recusa("HTML acima de 25 MB");
  const pasta = await garantirPasta(ctx, item);
  const { corpo, tipo } = multipart({ name: String(item.nome || "Documento emitido").slice(0, 200), parents: [pasta], mimeType: DOC }, "text/html; charset=UTF-8", bytes);
  const f = await (await g(ctx, `${UPLOAD}/files?uploadType=multipart&supportsAllDrives=true&fields=id,webViewLink,mimeType`, { method: "POST",
    headers: { "Content-Type": tipo }, body: corpo })).json();
  if (!ID.test(String(f.id || ""))) throw new Recusa("o Drive não devolveu o id do Google Doc", 502);
  if (f.mimeType && f.mimeType !== DOC) throw new Recusa("o Drive guardou o HTML sem converter para Google Docs (" + f.mimeType + ")", 502);
  return { id: f.id, link: /^https:\/\/(docs|drive)\.google\.com\//.test(String(f.webViewLink || "")) ? f.webViewLink : `https://docs.google.com/document/d/${f.id}/edit` };
}

// Fila (função docs, chamada pelo banco com X-IMTS-Chave): toma os pedidos vencidos, gera cada Doc e devolve o resultado ao banco.
// Falha de um não para os outros: doc.gdoc_falhar devolve à fila com espera ou, esgotadas as tentativas, abre o alerta de operação.
export async function processarFilaDocs(deps: Deps, limite = 5) {
  const conta = await segredo(deps.sql, "google_conta_servico");
  if (!conta) throw new Recusa("Google ainda não configurado: falta o segredo google_conta_servico no cofre", 503);
  let lote;
  try { lote = (await deps.sql`select doc.gdoc_proximos(${limite}::int) as r`)[0].r; }
  catch (e) { throw new Recusa(limparErro(e), 503); }
  const gerados: { emissao: number; id: string }[] = [], falhas: { emissao: number; erro: string; situacao: string }[] = [];
  // deno-lint-ignore no-explicit-any
  const itens: any[] = lote.itens || [];
  if (!itens.length) return { gerados, falhas };
  let ctx: Ctx | null = null, erroToken: string | null = null;
  try { ctx = { deps, token: await googleToken(deps, conta, lote.usuario_sistema, ESC_DRIVE) }; } catch (e) { erroToken = limparErro(e); }
  for (const item of itens) {
    try {
      if (!ctx) throw new Recusa(erroToken || "sem token do Google", 502);
      const d = await criarDocGoogle(ctx, { ...item, drive_raiz: lote.drive_raiz });
      await deps.sql`select doc.gdoc_concluir(${item.emissao}::bigint, ${d.id}, ${d.link}, null::uuid)`;
      gerados.push({ emissao: item.emissao, id: d.id });
    } catch (e) {
      const erro = limparErro(e);
      const f = (await deps.sql`select doc.gdoc_falhar(${item.emissao}::bigint, ${erro}, null::uuid) as r`)[0].r;
      falhas.push({ emissao: item.emissao, erro, situacao: f.situacao });
    }
  }
  return { gerados, falhas };
}

// Texto de um arquivo: Docs exporta; texto lê direto; PDF e Office passam por uma cópia convertida (com OCR) que é apagada em seguida
async function textoDe(ctx: Ctx, id: string, mime: string): Promise<string | null> {
  if (mime === DOC) return await (await g(ctx, `${DRIVE}/files/${id}/export?mimeType=text/plain`)).text();
  if (mime.startsWith("text/") || mime === "application/json" || mime.endsWith("xml")) return await (await g(ctx, `${DRIVE}/files/${id}?alt=media&supportsAllDrives=true`)).text();
  if (mime === "application/pdf" || mime.includes("officedocument") || mime === "application/msword" || mime.startsWith("image/")) {
    const copia = await (await g(ctx, `${DRIVE}/files/${id}/copy?supportsAllDrives=true&fields=id&ocrLanguage=pt`, { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ mimeType: DOC, name: "texto-temporario-imts" }) })).json();
    try { return await (await g(ctx, `${DRIVE}/files/${copia.id}/export?mimeType=text/plain`)).text(); }
    finally { await ctx.deps.fetch(`${DRIVE}/files/${copia.id}?supportsAllDrives=true`, { method: "DELETE", headers: { Authorization: "Bearer " + ctx.token } }).catch(() => {}); }
  }
  return null;
}

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  let acao = "?", alvo: string | null = null, pessoa: string | null = null, usuario: string | null = null, jaRegistrado = false;
  try {
    const u = lerUsuario(req, (deps.agora ?? Date.now)());
    // deno-lint-ignore no-explicit-any
    const d: any = await req.json().catch(() => { throw new Recusa("corpo inválido"); });
    acao = String(d.acao || "");
    const a = await autorizar(deps.sql, u, req.headers.get("x-empresa"), "google", acao, d);
    pessoa = a.pessoa ?? null; usuario = a.usuario ?? null;
    const conta = await segredo(deps.sql, "google_conta_servico");
    if (!conta) throw new Recusa("Google ainda não configurado: falta o segredo google_conta_servico no cofre", 503);
    const emNome = acao.startsWith("agenda_") ? a.organizador : a.usuario_sistema;
    if (!emNome) throw new Recusa("sem conta do Workspace para agir", 503);
    const ctx: Ctx = { deps, token: await googleToken(deps, conta, emNome, acao.startsWith("agenda_") ? ESC_AGENDA : ESC_DRIVE) };
    let saida: Record<string, unknown>;

    switch (acao) {
      case "drive_enviar": {
        const bytes = deB64(String(d.conteudo || ""));
        if (!bytes.length) throw new Recusa("arquivo vazio");
        if (bytes.length > MAX_BYTES) throw new Recusa("arquivo acima de 25 MB");
        const nome = String(d.nome || "arquivo").slice(0, 200), mime = String(d.mime || "application/octet-stream");
        const pasta = await garantirPasta(ctx, a);
        const { corpo, tipo } = multipart({ name: nome, parents: [pasta], mimeType: mime }, mime, bytes);
        const f = await (await g(ctx, `${UPLOAD}/files?uploadType=multipart&supportsAllDrives=true&fields=id,webViewLink`, { method: "POST",
          headers: { "Content-Type": tipo }, body: corpo })).json();
        alvo = f.id;
        let texto: string | null = null;
        try { texto = await textoDe(ctx, f.id, mime); } catch { texto = null; }   // sem texto, o banco decide o que fazer
        saida = { id: f.id, link: f.webViewLink, pasta: a.pasta, texto };
        break;
      }
      case "drive_ler": {
        if (!ID.test(a.id)) throw new Recusa("id de arquivo inválido");
        alvo = a.id;
        const m = await (await g(ctx, `${DRIVE}/files/${a.id}?supportsAllDrives=true&fields=id,name,mimeType,size`)).json();
        saida = { nome: m.name, mime: m.mimeType, texto: await textoDe(ctx, a.id, m.mimeType) };
        break;
      }
      case "drive_lixeira": {
        alvo = a.id;
        await g(ctx, `${DRIVE}/files/${a.id}?supportsAllDrives=true`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ trashed: true }) });
        saida = { ok: true };
        break;
      }
      case "drive_renomear": {
        alvo = a.id; const nome = String(d.nome || "").slice(0, 200);
        if (!nome) throw new Recusa("informe o nome");
        await g(ctx, `${DRIVE}/files/${a.id}?supportsAllDrives=true`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: nome }) });
        saida = { ok: true };
        break;
      }
      case "drive_mover": {
        alvo = a.id;
        const destino = await garantirPasta(ctx, a);
        const m = await (await g(ctx, `${DRIVE}/files/${a.id}?supportsAllDrives=true&fields=parents`)).json();
        await g(ctx, `${DRIVE}/files/${a.id}?supportsAllDrives=true&addParents=${destino}&removeParents=${(m.parents || []).join(",")}`, {
          method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(d.nome ? { name: String(d.nome).slice(0, 200) } : {}) });
        saida = { ok: true, pasta_id: destino };
        break;
      }
      case "drive_pasta": {
        const id = await garantirPasta(ctx, a); alvo = id; saida = { id };
        break;
      }
      case "drive_listar": {
        alvo = a.pasta_id;
        const r = await (await g(ctx, `${DRIVE}/files?supportsAllDrives=true&includeItemsFromAllDrives=true&pageSize=200&fields=files(id,name,mimeType,size,modifiedTime)&q=${encodeURIComponent(`'${q(a.pasta_id)}' in parents and trashed = false`)}`)).json();
        saida = { arquivos: (r.files || []).map((f: Record<string, unknown>) => ({ id: f.id, nome: f.name, mime: f.mimeType, tamanho: Number(f.size || 0), alterado_em: f.modifiedTime })) };
        break;
      }
      case "drive_baixar": {
        if (!ID.test(String(d.id || ""))) throw new Recusa("id de arquivo inválido");
        alvo = d.id;
        // confere os pais do arquivo contra o acervo das empresas da pessoa
        const m = await (await g(ctx, `${DRIVE}/files/${d.id}?supportsAllDrives=true&fields=parents,name,mimeType,size`)).json();
        await autorizar(deps.sql, u, req.headers.get("x-empresa"), "google", "drive_baixar", { id: d.id, pais: m.parents || [] });
        if (Number(m.size || 0) > MAX_BYTES) throw new Recusa("arquivo acima de 25 MB");
        const bytes = new Uint8Array(await (await g(ctx, `${DRIVE}/files/${d.id}?alt=media&supportsAllDrives=true`)).arrayBuffer());
        saida = { nome: m.name, mime: m.mimeType, conteudo: b64(bytes) };
        break;
      }
      case "docs_criar": {
        // a permissão já veio do banco (doc._gdoc_autorizar); aqui o pedido entra na fila e é tomado na hora (doc.gdoc_tomar)
        let t;
        try { t = (await deps.sql`select doc.gdoc_tomar(${a.emissao}::bigint, ${pessoa}::uuid) as r`)[0].r; }
        catch (e) { throw new Recusa(limparErro(e), 409); }
        jaRegistrado = true;   // sucesso e falha ficam registrados pelo banco (doc.gdoc_concluir e doc.gdoc_falhar)
        if (t.pronto) { alvo = t.id; saida = { emissao: a.emissao, id: t.id, link: t.link, ja_existia: true }; break; }
        try {
          const gd = await criarDocGoogle(ctx, { ...t, drive_raiz: a.drive_raiz ?? t.drive_raiz });
          await deps.sql`select doc.gdoc_concluir(${a.emissao}::bigint, ${gd.id}, ${gd.link}, ${pessoa}::uuid)`;
          alvo = gd.id; saida = { emissao: a.emissao, id: gd.id, link: gd.link };
        } catch (e) {
          const erro = limparErro(e);
          const f = (await deps.sql`select doc.gdoc_falhar(${a.emissao}::bigint, ${erro}, ${pessoa}::uuid) as r`)[0].r;
          const quando = f.proxima_em ? new Date(f.proxima_em).toLocaleTimeString("pt-BR", { timeZone: "America/Fortaleza", hour: "2-digit", minute: "2-digit" }) : null;
          throw new Recusa(erro + (f.situacao === "falhou" ? "; tentativas esgotadas: virou alerta de operação" : quando ? `; nova tentativa automática às ${quando}` : ""),
            e instanceof Recusa && e.status < 500 ? e.status : 502);
        }
        break;
      }
      case "agenda_evento": {
        const ini = new Date(String(d.inicio)), fim = new Date(String(d.fim));
        if (isNaN(+ini) || isNaN(+fim) || fim <= ini) throw new Recusa("início e fim inválidos");
        const convidados = (Array.isArray(d.convidados) ? d.convidados : []).map(String).filter((e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)).slice(0, 50);
        const ev = await (await g(ctx, `${AGENDA}/calendars/primary/events?conferenceDataVersion=1&sendUpdates=all`, { method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ summary: String(d.titulo || "Reunião").slice(0, 200), description: String(d.descricao || "").slice(0, 4000),
            start: { dateTime: ini.toISOString() }, end: { dateTime: fim.toISOString() }, attendees: convidados.map((email: string) => ({ email })),
            conferenceData: { createRequest: { requestId: crypto.randomUUID(), conferenceSolutionKey: { type: "hangoutsMeet" } } } }) })).json();
        alvo = ev.id;
        const link = ev.hangoutLink || ev.conferenceData?.entryPoints?.find((p: { entryPointType: string }) => p.entryPointType === "video")?.uri || null;
        saida = { evento_id: ev.id, link };
        break;
      }
      case "agenda_cancelar": {
        const id = String(d.evento_id || ""); if (!/^[A-Za-z0-9_-]{5,}$/.test(id)) throw new Recusa("evento inválido");
        alvo = id;
        const r = await deps.fetch(`${AGENDA}/calendars/primary/events/${id}?sendUpdates=all`, { method: "DELETE", headers: { Authorization: "Bearer " + ctx.token } });
        if (!r.ok && r.status !== 410 && r.status !== 404) throw new Recusa("Google respondeu " + r.status, 502);
        saida = { ok: true };
        break;
      }
      default: throw new Recusa("ação desconhecida: " + acao);
    }
    if (!jaRegistrado) await registrar(deps.sql, "google", acao, pessoa, usuario, alvo, true, null);
    return json(saida);
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    const msg = e instanceof Recusa ? e.message : "falha interna na função google";
    if (status >= 500 && !jaRegistrado) await registrar(deps.sql, "google", acao, pessoa, usuario, alvo, false, limparErro(e));
    if (!(e instanceof Recusa)) console.error(e);
    return json({ erro: msg, codigo: status }, status);
  }
}
