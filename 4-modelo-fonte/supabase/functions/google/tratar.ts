// Função google (B21): Drive do acervo e Agenda com Meet, pela conta de serviço com delegação no domínio.
// Contrato: app/CONTRATO.md. Permissão: adm.servidor_autorizar. Registro: adm.servidor_registrar.
// Segredo no cofre: google_conta_servico (JSON da chave da conta de serviço).
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

type Ctx = { deps: Deps; token: string };
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
async function garantirPasta(ctx: Ctx, a: any): Promise<string> {
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
  let acao = "?", alvo: string | null = null, pessoa: string | null = null, usuario: string | null = null;
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
        const limite = "imts" + crypto.randomUUID().replace(/-/g, "");
        const meta = JSON.stringify({ name: nome, parents: [pasta], mimeType: mime });
        const ini = new TextEncoder().encode(`--${limite}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${meta}\r\n--${limite}\r\nContent-Type: ${mime}\r\n\r\n`);
        const fim = new TextEncoder().encode(`\r\n--${limite}--`);
        const corpo = new Uint8Array(ini.length + bytes.length + fim.length); corpo.set(ini); corpo.set(bytes, ini.length); corpo.set(fim, ini.length + bytes.length);
        const f = await (await g(ctx, `${UPLOAD}/files?uploadType=multipart&supportsAllDrives=true&fields=id,webViewLink`, { method: "POST",
          headers: { "Content-Type": `multipart/related; boundary=${limite}` }, body: corpo })).json();
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
    await registrar(deps.sql, "google", acao, pessoa, usuario, alvo, true, null);
    return json(saida);
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    const msg = e instanceof Recusa ? e.message : "falha interna na função google";
    if (status >= 500) await registrar(deps.sql, "google", acao, pessoa, usuario, alvo, false, limparErro(e));
    if (!(e instanceof Recusa)) console.error(e);
    return json({ erro: msg, codigo: status }, status);
  }
}
