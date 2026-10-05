// Assinatura eletrônica avançada de ponta a ponta: pedido na Central, código por e-mail (função assinatura de verdade, com o Gmail
// simulado), assinatura na ordem pela Central e pelo Portal, selo e página de manifesto, verificação pública sem login,
// cancelamento, pedido que exige ICP-Brasil, recusas e acessibilidade.
// As funções do servidor rodam localmente (supabase/functions/testes/servir_ensaio.ts, porta 3398) contra o banco app_ensaio.
import { abrir, axe, caso, confere, fim, token, U } from './apoio.mjs';
import { execFileSync, spawn } from 'node:child_process'; import crypto from 'node:crypto'; import fs from 'node:fs';

const FUNCOES = 'http://127.0.0.1:3398';
const MARCA = Date.now().toString(36);
const DB = 'postgresql:///app_ensaio?port=5499';
const psql = q => execFileSync('psql', [DB, '-Atc', q]).toString().trim();
const DENO = process.env.DENO || '/tmp/pgt/npm/node_modules/.bin/deno';

// funções do servidor locais
const servidor = spawn(DENO, ['run', '-A', new URL('../../supabase/functions/testes/servir_ensaio.ts', import.meta.url).pathname],
  { env: { ...process.env, DENO_DIR: process.env.DENO_DIR || '/tmp/pgt/deno' }, stdio: ['ignore', 'pipe', 'pipe'] });
await new Promise((ok, falha) => { const t = setTimeout(() => falha(new Error('funções locais não subiram')), 90000);
  servidor.stdout.on('data', d => { if (String(d).includes('pronto')) { clearTimeout(t); ok(); } }); servidor.on('exit', c => falha(new Error('funções locais saíram: ' + c))); });
const emails = async () => (await (await fetch(FUNCOES + '/_emails')).json());
const ultimoCodigo = async para => { const e = (await emails()).filter(x => x.para === para).at(-1); confere(e?.codigo, 'nenhum e-mail para ' + para); return e.codigo; };

async function porta(quem, fn, args) {
  const r = await fetch('http://127.0.0.1:3399/rpc/imts', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token(U[quem]) }, body: JSON.stringify({ p_fn: fn, p_args: args }) });
  const j = await r.json(); if (!r.ok) throw new Error(fn + ': ' + j.message); return j;
}
const ignoraRede = m => /Failed to load resource/.test(m);
async function semErros(p) { const e = p.erros.filter(m => !ignoraRede(m)); confere(e.length === 0, 'erros de console: ' + e.join(' | ')); }
const empAlfa = async () => (await porta('rui', 'rt.quem_sou', {})).empresas.find(e => e.nome === 'Empresa Alfa').id;
async function central(quem, opc) {
  const p = await abrir('central.html', quem, opc); await p.waitForSelector('.resumo span');
  const sel = await p.$('#imts-empresa');
  if (sel) { const v = await p.$eval('#imts-empresa', s => [...s.options].find(o => o.textContent === 'Empresa Alfa')?.value); if (v && v !== await p.inputValue('#imts-empresa')) { await p.selectOption('#imts-empresa', v); await p.waitForLoadState('networkidle'); } }
  await p.click('#t-assinaturas'); await p.waitForSelector('#t-assinaturas[aria-selected="true"]'); await p.waitForSelector('h2.secao:has-text("Pedidos de assinatura")');
  return p;
}
async function portal(quem, opc) {
  const p = await abrir('portal.html', quem, opc); await p.waitForSelector('#b-novo:not([disabled])');
  await p.click('#t-assinaturas'); await p.waitForSelector('#t-assinaturas[aria-selected="true"]'); return p;
}
const emp = await empAlfa();
const P0 = await porta('rui', 'doc.painel_assinaturas', { p_empresa: emp });
const olga = P0.internos.find(i => i.nome === 'Olga Operações').pessoa, clara = P0.externos.find(u => u.nome === 'Clara Cliente').usuario;
const doc0 = P0.documentos[0]; confere(doc0, 'a Empresa Alfa não tem documento emitido no ensaio');
let pedido = null;

await caso('rui pede a assinatura na Central: olga e depois clara, com o SHA-256 do PDF', async () => {
  const p = await central('rui');
  await p.click('[data-asnovo]'); await p.waitForSelector('#f-ass');
  await p.selectOption('#as-doc', String(doc0.emissao)); await p.fill('#as-tit', 'Termo de teste ' + MARCA);
  await p.selectOption('#as-sigs .as-sig:nth-child(1) select', 'p:' + olga);
  await p.click('[data-asmais]'); await p.selectOption('#as-sigs .as-sig:nth-child(2) select', 'u:' + clara);
  const v = await axe(p); confere(v.length === 0, 'axe formulário ' + v);
  await p.click('#f-ass button[type="submit"]');
  await p.waitForSelector(`article[data-assped]:has-text("Termo de teste ${MARCA}")`);
  const t = (await p.textContent(`article[data-assped]:has-text("Termo de teste ${MARCA}")`)).replace(/\s+/g, ' ');
  pedido = (await porta('rui', 'doc.painel_assinaturas', { p_empresa: emp })).pedidos.find(x => x.titulo === 'Termo de teste ' + MARCA);
  const h = psql(`select encode(extensions.digest(conteudo, 'sha256'), 'hex') from doc.arquivo where emissao = ${Number(doc0.emissao)} and formato = 'pdf'`);
  confere(pedido && pedido.hash_documento === h && t.includes(pedido.codigo) && t.includes(h) && t.includes('aguardando') && t.includes('Olga Operações') && t.includes('da vez'), 'pedido na tela: ' + t);
  await semErros(p); await p.close();
});

await caso('clara não assina antes da vez; paulo, de outra organização, não vê o pedido', async () => {
  const p = await portal('clara');
  const a = `article[data-ass="${pedido.id}"]`; await p.waitForSelector(a);
  confere((await p.textContent(a)).includes('Aguardando quem assina antes de você') && !(await p.$(a + ' [data-asscodigo]')), 'clara pode assinar fora da vez');
  await semErros(p); await p.close();
  const q = await portal('paulo'); await q.waitForTimeout(300);
  confere(!(await q.$(`article[data-ass="${pedido.id}"]`)), 'paulo vê o pedido da Prefeitura'); await semErros(q); await q.close();
});

await caso('olga recebe o código no e-mail, erra uma vez (conta a tentativa) e assina na Central', async () => {
  const p = await central('olga');
  const a = `article[data-comigo="${pedido.id}"]`; await p.waitForSelector(a);
  const sid = await p.getAttribute(a + ' [data-ascodigo]', 'data-ascodigo');
  await p.click(a + ' [data-ascodigo]'); await p.waitForFunction(s => /Código enviado para ol\*\*\*@imts\.com\.br/.test(document.getElementById('asav-' + s)?.textContent || ''), sid);
  const cod = await ultimoCodigo('olga@imts.com.br');
  await p.check('#asok-' + sid); await p.fill('#ascod-' + sid, cod === '000000' ? '111111' : '000000'); await p.click(a + ' [data-asassinar]');
  await p.waitForFunction(s => /restam 4/.test(document.getElementById('asav-' + s)?.textContent || ''), sid);
  confere(psql(`select tentativas from doc.assinatura_codigo where signatario = ${Number(sid)} order by id desc limit 1`) === '1', 'tentativa não contada');
  await p.fill('#ascod-' + sid, cod); await p.check('#asok-' + sid); await p.click(a + ' [data-asassinar]');
  await p.waitForSelector('#recibos .recibo.feito:has-text("Assinado")');
  const ev = JSON.parse(psql(`select evidencia from doc.assinatura_signatario where id = ${Number(sid)}`));
  confere(ev.agente && /Chrome/.test(ev.agente) && ev.hash_documento === pedido.hash_documento && ev.consentimento.includes('14.063/2020'), 'evidências ' + JSON.stringify(ev).slice(0, 300));
  await semErros(p); await p.close();
});

await caso('clara assina no portal; o pedido conclui, recebe o selo e o PDF assinado tem a página de manifesto', async () => {
  const p = await portal('clara');
  const a = `article[data-ass="${pedido.id}"]`; await p.waitForSelector(a + ' [data-asscodigo]');
  const sid = await p.getAttribute(a + ' [data-asscodigo]', 'data-asscodigo');
  await p.click(a + ' [data-asscodigo]'); await p.waitForFunction(s => /Código enviado para cl\*\*\*@/.test(document.getElementById('aav-' + s)?.textContent || ''), sid);
  const v = await axe(p); confere(v.length === 0, 'axe assinatura no portal ' + v);
  await p.fill('#acod-' + sid, await ultimoCodigo('clara@prefeitura-exemplo.gov.br')); await p.check('#aok-' + sid); await p.click(a + ' [data-assassinar]');
  await p.waitForSelector('#recibos .recibo.feito:has-text("Todos assinaram")');
  await p.waitForSelector(a + ' [data-assdoc]:has-text("Baixar PDF assinado")');
  const [d] = await Promise.all([p.waitForEvent('download'), p.click(a + ' [data-assdoc]')]);
  const pdf = fs.readFileSync(await d.path()); fs.writeFileSync('/tmp/assinado-' + MARCA + '.pdf', pdf);
  confere(pdf.subarray(0, 5).toString() === '%PDF-' && crypto.createHash('sha256').update(pdf).digest('hex') === psql(`select hash_pdf from doc.assinatura_selo where pedido = ${pedido.id}`), 'PDF assinado não é o do selo');
  confere(psql(`select situacao from doc.assinatura_pedido where id = ${pedido.id}`) === 'concluido', 'não concluiu');
  await semErros(p); await p.close();
});

await caso('verificação pública sem login: válida, com nomes e e-mails mascarados, e compara o arquivo no navegador', async () => {
  const p = await abrir('verificar.html?c=' + encodeURIComponent(pedido.codigo), null);
  await p.waitForSelector('#resultado .veredito.ok');
  const t = (await p.textContent('#resultado')).replace(/\s+/g, ' ');
  confere(t.includes('Assinatura válida') && t.includes('Olga Operações') && t.includes('ol***@imts.com.br') && t.includes('cl***@prefeitura-exemplo.gov.br') && t.includes('confere') && !t.includes('olga@imts.com.br'), 'resultado ' + t.slice(0, 400));
  let v = await axe(p); confere(v.length === 0, 'axe verificação ' + v);
  // o original: o navegador calcula o SHA-256 e só manda o resumo
  const enviados = []; p.on('request', r => { if (r.url().endsWith('/verificar')) enviados.push(r.postData()); });
  const original = Buffer.from(psql(`select encode(conteudo, 'base64') from doc.arquivo where emissao = ${Number(doc0.emissao)} and formato = 'pdf'`).replace(/\s+/g, ''), 'base64');
  await p.setInputFiles('#arquivo', { name: 'original.pdf', mimeType: 'application/pdf', buffer: original }); await p.click('#b-verificar');
  await p.waitForSelector('#r-arquivo:has-text("É o documento original")');
  confere(enviados.length && !enviados.at(-1).includes(original.subarray(0, 40).toString('base64')) && JSON.parse(enviados.at(-1)).hash === crypto.createHash('sha256').update(original).digest('hex'), 'o arquivo saiu do navegador');
  await p.setInputFiles('#arquivo', { name: 'assinado.pdf', mimeType: 'application/pdf', buffer: fs.readFileSync('/tmp/assinado-' + MARCA + '.pdf') }); await p.click('#b-verificar');
  await p.waitForSelector('#r-arquivo:has-text("É o PDF assinado")');
  await p.setInputFiles('#arquivo', { name: 'outro.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.4 outro ' + MARCA) }); await p.click('#b-verificar');
  await p.waitForSelector('#r-arquivo:has-text("NÃO é o documento assinado")'); await p.waitForSelector('#resultado .veredito.nao');
  v = await axe(p); confere(v.length === 0, 'axe arquivo diferente ' + v);
  await p.fill('#codigo', 'ZZZZ-ZZZZ-ZZZZ'); await p.setInputFiles('#arquivo', []); await p.click('#b-verificar'); await p.waitForSelector('#resultado:has-text("Código não encontrado")');
  await semErros(p); await p.close();
});

await caso('cancelar: só quem pediu vê o botão e precisa de motivo', async () => {
  const r = await porta('rui', 'doc.assinatura_pedir', { p_emissao: Number(doc0.emissao), p_signatarios: [{ pessoa: olga }], p_titulo: 'Para cancelar ' + MARCA });
  const q = await central('olga'); confere(!(await q.$(`article[data-assped="${r.id}"] [data-ascancelar]`)), 'olga pode cancelar pedido de outra pessoa'); await q.close();
  const p = await central('rui'); const a = `article[data-assped="${r.id}"]`; await p.waitForSelector(a);
  await p.click(a + ' [data-ascancelar]'); await p.waitForSelector('#recibos .recibo.recusado:has-text("motivo")');
  await p.fill('#ascm-' + r.id, 'Versão nova do documento ' + MARCA); await p.click(a + ' [data-ascancelar]');
  await p.waitForSelector('#recibos .recibo.feito:has-text("cancelado")');
  await p.click('[data-asfiltro="encerrados"]'); await p.waitForSelector(`${a}:has-text("Versão nova do documento ${MARCA}")`);
  await semErros(p); await p.close();
});

await caso('exige ICP-Brasil: ninguém assina aqui; quem pediu registra a assinatura feita fora e conclui sem selo do IMTS', async () => {
  const p = await central('rui');
  await p.click('[data-asnovo]'); await p.fill('#as-tit', 'Termo ICP ' + MARCA); await p.selectOption('#as-sigs .as-sig:nth-child(1) select', 'p:' + olga); await p.check('#as-icp');
  await p.click('#f-ass button[type="submit"]'); const a = `article[data-assped]:has-text("Termo ICP ${MARCA}")`; await p.waitForSelector(a);
  confere((await p.textContent(a)).includes('exige ICP-Brasil'), 'sem a marca de ICP-Brasil');
  const q = await central('olga'); const c = `article[data-comigo]:has-text("Termo ICP ${MARCA}")`; await q.waitForSelector(c);
  confere(!(await q.$(c + ' [data-ascodigo]')) && (await q.textContent(c)).includes('fora do IMTS.OS'), 'olga pode assinar aqui um pedido ICP-Brasil'); await semErros(q); await q.close();
  const sid = await p.getAttribute(a + ' [data-asfora]', 'data-asfora');
  await p.fill('#asfr-' + sid, 'PDF assinado com certificado ICP-Brasil em ' + new Date().toLocaleDateString('pt-BR')); await p.click(a + ' [data-asfora]');
  await p.waitForSelector('#recibos .recibo.feito:has-text("feita fora")'); await p.click('[data-asfiltro="concluido"]');
  await p.waitForSelector(`${a}:has-text("assinado fora (ICP-Brasil)")`);
  confere(!(await p.$(a + ' [data-asselar]')) && !(await p.$(a + ' .chip.bom:has-text("selado")')), 'pedido ICP-Brasil com selo do IMTS');
  await semErros(p); await p.close();
});

await caso('recusa no portal encerra o pedido com o motivo para quem pediu', async () => {
  const r = await porta('rui', 'doc.assinatura_pedir', { p_emissao: Number(doc0.emissao), p_signatarios: [{ usuario: clara }], p_titulo: 'Para recusar ' + MARCA });
  const p = await portal('clara'); const a = `article[data-ass="${r.id}"]`; await p.waitForSelector(a + ' [data-assrecusar]');
  const sid = await p.getAttribute(a + ' [data-assrecusar]', 'data-assrecusar');
  await p.fill('#arm-' + sid, 'Valor diferente do combinado ' + MARCA); await p.click(a + ' [data-assrecusar]');
  await p.waitForSelector('#recibos .recibo.feito:has-text("recusada")'); await p.waitForSelector(`${a} .chip:has-text("recusado")`);
  await semErros(p); await p.close();
  const x = (await porta('rui', 'doc.painel_assinaturas', { p_empresa: emp })).pedidos.find(y => y.id === r.id);
  confere(x.situacao === 'recusado' && x.encerrado_motivo.includes('Valor diferente do combinado'), 'recusa ' + JSON.stringify(x).slice(0, 200));
});

await caso('acessibilidade e largura: Central (aba e formulário), Portal e verificação; 1280 claro, 1280 escuro e 390 claro', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const p = await central('rui', { largura: l, esquema: e });
    for (const f of ['aguardando', 'concluido', 'encerrados']) {
      await p.click(`[data-asfiltro="${f}"]`); const v = await axe(p); confere(v.length === 0, `central ${l} ${e} ${f} axe ${v}`);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `central ${l} ${e} ${f} rolagem ${larg}`);
    }
    await p.click('[data-asnovo]'); await p.click('[data-asmais]');
    let v = await axe(p); confere(v.length === 0, `central ${l} ${e} formulário axe ${v}`);
    let larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `central ${l} ${e} formulário rolagem ${larg}`);
    await semErros(p); await p.close();
    const q = await central('olga', { largura: l, esquema: e }); v = await axe(q); confere(v.length === 0, `central olga ${l} ${e} axe ${v}`);
    larg = await q.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `central olga ${l} ${e} rolagem ${larg}`); await semErros(q); await q.close();
    const r = await portal('clara', { largura: l, esquema: e }); v = await axe(r); confere(v.length === 0, `portal ${l} ${e} axe ${v}`);
    larg = await r.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `portal ${l} ${e} rolagem ${larg}`); await semErros(r); await r.close();
    const s = await abrir('verificar.html?c=' + encodeURIComponent(pedido.codigo), null, { largura: l, esquema: e }); await s.waitForSelector('#resultado .veredito');
    v = await axe(s); confere(v.length === 0, `verificar ${l} ${e} axe ${v}`);
    larg = await s.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `verificar ${l} ${e} rolagem ${larg}`); await semErros(s); await s.close();
  }
});

servidor.kill();
await fim('assinatura');
