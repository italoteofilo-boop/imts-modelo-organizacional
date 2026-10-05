// Selo dos pedidos de assinatura concluídos (funções assinatura e selo).
// 1. pega no banco o manifesto canônico (texto JSON gerado por doc._ass_manifesto) e o PDF original;
// 2. assina o texto do manifesto com a chave do IMTS (ECDSA P-256 com SHA-256), gerando a chave na primeira vez direto no cofre;
// 3. anexa ao PDF original uma página de manifesto com o código de verificação, o QR e o link da verificação pública
//    (se o PDF original não abrir, o manifesto sai como PDF separado, ligado ao original pelo hash);
// 4. grava o selo (doc.assinatura_selar confere que o manifesto é o mesmo do banco).
import { PDFDocument, PDFFont, PDFPage, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";
import qrcode from "npm:qrcode-generator@1.4.4";
import { b64, deB64, Deps, Recusa, segredo } from "./servidor.ts";
import { assinarTexto, chavePrivada, gerarPar } from "./selo.ts";

// deno-lint-ignore no-explicit-any
type Manifesto = any;

// chave do selo: lê do cofre; se ainda não existir, gera o par e grava (privada no cofre, pública na tabela de leitura)
export async function chaveDoSelo(deps: Deps): Promise<{ kid: string; privada: CryptoKey }> {
  for (let tentativa = 0; tentativa < 2; tentativa++) {
    const priv = await segredo(deps.sql, "assinatura_chave_privada");
    const [{ r: pub }] = await deps.sql`select doc.assinatura_chave_ativa() as r`;
    if (priv && pub) return { kid: pub.kid, privada: await chavePrivada(JSON.parse(priv)) };
    if (priv || pub) throw new Recusa("chave do selo incompleta: o cofre e a tabela doc.assinatura_chave não batem; fale com a administração", 500);
    const par = await gerarPar();
    const [{ ok }] = await deps.sql`select doc.assinatura_chave_gravar(${par.kid}, ${deps.sql.json(par.publica)}, ${JSON.stringify(par.privada)}) as ok`;
    if (ok) return { kid: par.kid, privada: await chavePrivada(par.privada) };
    // outra chamada gravou primeiro: lê a dela
  }
  throw new Recusa("não foi possível obter a chave do selo", 500);
}

// texto que a fonte padrão do PDF (WinAnsi) consegue desenhar; o resto vira equivalente simples
export function limparTexto(s: unknown): string {
  return String(s ?? "").replace(/[\u2018\u2019]/g, "'").replace(/[\u201C\u201D]/g, '"').replace(/[\u2013\u2014]/g, "-").replace(/\u2026/g, "...")
    .replace(/•/g, "·").replace(/\s+/g, " ").replace(/[^\x20-\x7E\xA0-\xFF]/g, "?");
}
function quebrar(texto: string, fonte: PDFFont, tam: number, largura: number): string[] {
  const linhas: string[] = []; let atual = "";
  for (const palavra of texto.split(" ")) {
    let p = palavra;
    while (fonte.widthOfTextAtSize(p, tam) > largura) {   // palavra maior que a linha (hash, assinatura): corta
      let n = p.length; while (n > 1 && fonte.widthOfTextAtSize(p.slice(0, n), tam) > largura) n--;
      if (atual) { linhas.push(atual); atual = ""; }
      linhas.push(p.slice(0, n)); p = p.slice(n);
    }
    const teste = atual ? atual + " " + p : p;
    if (fonte.widthOfTextAtSize(teste, tam) > largura && atual) { linhas.push(atual); atual = p; } else atual = teste;
  }
  if (atual) linhas.push(atual);
  return linhas;
}
const quandoBR = (iso: string) => iso ? new Date(iso).toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", second: "2-digit" }) : "";

export async function anexarManifesto(original: Uint8Array | null, m: Manifesto, assinatura: string, kid: string): Promise<{ pdf: Uint8Array; formato: string }> {
  let doc: PDFDocument, formato = "original_com_manifesto";
  try {
    if (!original) throw new Error("sem original");
    doc = await PDFDocument.load(original, { updateMetadata: false });
  } catch {
    doc = await PDFDocument.create(); formato = "manifesto_separado";
  }
  const f = await doc.embedFont(StandardFonts.Helvetica), fb = await doc.embedFont(StandardFonts.HelveticaBold), fm = await doc.embedFont(StandardFonts.Courier);
  const L = 595.28, A = 841.89, M = 48, QR = 112, tinta = rgb(0.1, 0.12, 0.14), apoio = rgb(0.35, 0.38, 0.42);
  let pg: PDFPage = doc.addPage([L, A]); let y = A - M; let paginas = 1;
  const rodape = () => pg.drawText(limparTexto(`Manifesto de assinatura · código ${m.codigo} · página ${paginas} do manifesto`), { x: M, y: 24, size: 7.5, font: f, color: apoio });
  rodape();
  const nova = () => { pg = doc.addPage([L, A]); y = A - M; paginas++; rodape(); };
  const escrever = (t: unknown, o: { fonte?: PDFFont; tam?: number; cor?: ReturnType<typeof rgb>; largura?: number; antes?: number } = {}) => {
    const fonte = o.fonte ?? f, tam = o.tam ?? 9.5;
    y -= o.antes ?? 0;
    for (const l of quebrar(limparTexto(t), fonte, tam, o.largura ?? L - 2 * M)) {
      if (y - tam < M) nova();
      pg.drawText(l, { x: M, y: y - tam, size: tam, font: fonte, color: o.cor ?? tinta }); y -= tam * 1.38;
    }
  };
  const secao = (t: string) => { if (y < M + 80) nova(); escrever(t, { fonte: fb, tam: 11.5, antes: 8 }); pg.drawLine({ start: { x: M, y: y + 3 }, end: { x: L - M, y: y + 3 }, thickness: 0.5, color: apoio }); y -= 4; };

  // QR do endereço de verificação, no canto superior direito
  const q = qrcode(0, "M"); q.addData(String(m.verificar)); q.make();
  const n = q.getModuleCount(), cel = QR / (n + 8), x0 = L - M - QR, y0 = A - M - QR;
  pg.drawRectangle({ x: x0, y: y0, width: QR, height: QR, color: rgb(1, 1, 1) });
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) {
    if (q.isDark(r, c)) pg.drawRectangle({ x: x0 + (c + 4) * cel, y: y0 + QR - (r + 5) * cel, width: cel + 0.05, height: cel + 0.05, color: rgb(0, 0, 0) });
  }
  const estreito = L - 2 * M - QR - 16;
  escrever("Manifesto de assinatura eletrônica", { fonte: fb, tam: 17, largura: estreito });
  escrever("Assinatura eletrônica avançada (Lei 14.063/2020, art. 4º, II), com selo do IMTS.OS", { tam: 10, cor: apoio, largura: estreito });
  escrever(`Código de verificação: ${m.codigo}`, { fonte: fb, tam: 13, largura: estreito, antes: 8 });
  escrever(`Verifique em ${m.verificar}`, { tam: 9, largura: estreito });
  escrever("Leia o QR ou abra o endereço, informe o código e, se quiser, escolha o PDF: o resumo é calculado no seu navegador e comparado com o registrado.", { tam: 8.5, cor: apoio, largura: estreito });
  y = Math.min(y, y0 - 10);

  secao("Documento");
  escrever(`Título: ${m.titulo}`);
  escrever(`Empresa: ${m.empresa} · pedido de assinatura nº ${m.pedido} · emissão nº ${m.documento?.emissao} do motor documental`);
  escrever(`Páginas do original: ${m.documento?.paginas ?? "não informado"} · tamanho: ${m.documento?.bytes} bytes · pedido em ${quandoBR(m.pedido_em)} · concluído em ${quandoBR(m.concluido_em)} (horário de Brasília)`);
  escrever("SHA-256 do PDF original (as páginas antes deste manifesto):", { antes: 2 });
  escrever(m.documento?.sha256, { fonte: fm, tam: 8.5 });

  secao("Signatários");
  for (const s of m.signatarios || []) {
    escrever(`${s.ordem}. ${s.nome} (${s.email}), ${s.tipo === "interno" ? "equipe do IMTS" : "cliente ou parceiro"}`, { fonte: fb, tam: 10, antes: 3 });
    escrever(`Assinou em ${quandoBR(s.assinado_em)} (horário de Brasília). Autenticação: ${s.autenticacao || "não informada"}.`);
    if (s.ip || s.agente) escrever(`${s.ip ? "IP: " + s.ip : ""}${s.ip && s.agente ? " · " : ""}${s.agente ? "navegador: " + s.agente : ""}`, { tam: 8.5, cor: apoio });
    escrever(`Evento ${s.evento} da trilha · hash ${s.hash_evento}`, { fonte: fm, tam: 7.5, cor: apoio });
  }

  secao("Trilha de eventos");
  escrever(`${m.trilha?.eventos} eventos encadeados por SHA-256 do pedido até a conclusão (cada evento guarda o hash do anterior; o primeiro elo é o hash do documento). Hash final:`);
  escrever(m.trilha?.hash_final, { fonte: fm, tam: 8.5 });

  secao("Selo do IMTS");
  escrever("Algoritmo: ECDSA P-256 com SHA-256 sobre o texto canônico do manifesto (JSON). A chave pública aparece na verificação.");
  escrever(`Chave: ${kid}`, { fonte: fm, tam: 8 });
  escrever("Assinatura do manifesto:", { antes: 2 });
  escrever(assinatura, { fonte: fm, tam: 7.5 });

  secao("Base legal e limite");
  escrever("Lei 14.063/2020, art. 4º, II: assinatura eletrônica avançada, associada ao signatário de maneira unívoca, com dados de criação sob o seu controle exclusivo (login e código de uso único enviado ao e-mail) e relacionada ao documento de modo que qualquer modificação posterior seja detectável (SHA-256, trilha encadeada e selo).", { tam: 8.5 });
  escrever("MP 2.200-2/2001, art. 10, § 2º: meio de comprovação de autoria e integridade admitido pelas partes, que aceitaram o texto de consentimento ao assinar.", { tam: 8.5 });
  escrever("Esta assinatura não substitui a assinatura qualificada (certificado ICP-Brasil) quando a lei ou o órgão público a exigir.", { fonte: fb, tam: 8.5 });
  if (formato === "manifesto_separado") escrever("O PDF original não pôde receber esta página: este manifesto acompanha o original, identificado pelo SHA-256 acima.", { fonte: fb, tam: 8.5, antes: 4 });

  doc.setTitle(limparTexto(`${m.titulo} (assinado)`)); doc.setProducer("IMTS.OS"); doc.setCreator("IMTS.OS · assinatura eletrônica avançada");
  return { pdf: await doc.save({ useObjectStreams: false }), formato };
}

// sela um pedido (ou os pendentes, até 5 por vez) e devolve o que fez
export async function selarPendentes(deps: Deps, pedido: number | null) {
  const lista: { pedido: number; codigo: string; manifesto: string; pdf: string | null }[] = (await deps.sql`select doc.assinatura_para_selar(${pedido}::bigint) as r`)[0].r || [];
  if (!lista.length) return { selados: [] as { pedido: number; codigo: string; hash_pdf: string; formato: string }[] };
  const chave = await chaveDoSelo(deps);
  const selados = [];
  for (const it of lista) {
    const m = JSON.parse(it.manifesto);
    const assinatura = await assinarTexto(chave.privada, it.manifesto);
    const { pdf, formato } = await anexarManifesto(it.pdf ? deB64(it.pdf) : null, m, assinatura, chave.kid);
    const [{ r }] = await deps.sql`select doc.assinatura_selar(${it.pedido}::bigint, ${it.manifesto}, ${assinatura}, ${chave.kid}, ${b64(pdf)}, ${formato}) as r`;
    selados.push({ pedido: it.pedido, codigo: it.codigo, hash_pdf: r.hash_pdf, formato });
  }
  return { selados };
}
