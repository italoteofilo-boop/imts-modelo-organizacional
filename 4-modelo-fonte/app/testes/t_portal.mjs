import crypto from 'node:crypto';
import { abrir, axe, caso, confere, fim, token, U } from './apoio.mjs';
import { execFileSync } from 'node:child_process'; import fs from 'node:fs';
const GOOGLE = 'http://127.0.0.1:3398/google';
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const pronto = p => p.waitForSelector('#b-novo:not([disabled])');
const marca = 'teste ' + Date.now().toString(36);
const rpc = p => { const l = []; p.on('request', r => { if (r.url().endsWith('/rpc/imts')) { try { l.push(JSON.parse(r.postData())); } catch (e) { /* nada */ } } }); return l; };

await caso('cliente vê o portal do cliente com dados reais, sem seletor', async () => {
  const p = await abrir('portal.html', 'clara'); await pronto(p);
  confere((await p.textContent('#titulo')) === 'Portal do cliente', 'título ' + await p.textContent('#titulo'));
  confere((await p.textContent('#org')).includes('Prefeitura Exemplo'), 'org');
  confere(!(await p.$('select#usuario')), 'seletor de usuário presente');
  confere(await p.isHidden('#t-oportunidades') && await p.isHidden('#t-carteira') && await p.isHidden('#t-prestacao'), 'abas de parceiro visíveis');
  await p.click('#t-pedidos'); confere((await p.textContent('#conteudo')).includes('Acesso ao relatório'), 'pedido semeado ausente');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('cliente abre pedido e ele aparece na lista', async () => {
  const p = await abrir('portal.html', 'clara'); await pronto(p);
  await p.click('#b-novo'); await p.selectOption('#f-tipo', 'chamado');
  await p.fill('#f-assunto', 'Chamado ' + marca); await p.fill('#f-texto', 'Descrição do chamado de teste.');
  await p.click('#f-novo button[type="submit"]');
  await p.waitForSelector(`#conteudo .item:has-text("Chamado ${marca}")`);
  confere((await p.getAttribute('#t-pedidos', 'aria-selected')) === 'true', 'não foi para a aba Pedidos');
  confere((await p.textContent('#recibos')).includes('registrado'), 'sem recibo');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('cliente envia ouvidoria anônima', async () => {
  const p = await abrir('portal.html', 'clara'); await pronto(p); const chamadas = rpc(p);
  await p.click('#b-novo'); await p.selectOption('#f-tipo', 'ouvidoria');
  confere(await p.isVisible('#f-anonimo'), 'opção anônima oculta'); await p.check('#f-anonimo');
  await p.fill('#f-assunto', 'Ouvidoria ' + marca); await p.fill('#f-texto', 'Relato anônimo de teste.');
  await p.click('#f-novo button[type="submit"]');
  await p.waitForSelector('#recibos .recibo.feito');
  const c = chamadas.find(x => x.p_fn === 'ext.ouvidoria');
  confere(c && c.p_args.p_anonimo === true && !('p_como' in c.p_args), 'chamada ' + JSON.stringify(c));
  const n = (await p.textContent('#recibos')).match(/nº (\d+)/)?.[1]; confere(n, 'sem número');
  const item = await p.textContent(`[data-pedido="${n}"]`);
  confere(item.includes('Ouvidoria ' + marca) && item.includes('Ouvidoria anônima'), 'não aparece na lista como anônima: ' + item);
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('cliente gera código do Telegram', async () => {
  const p = await abrir('portal.html', 'clara'); await pronto(p);
  await p.click('#b-telegram'); await p.click('#b-tg-gerar'); await p.waitForSelector('#tg-codigo .codigo');
  const t = await p.textContent('#tg-codigo'); confere(/Envie ao bot: \/vincular [A-Z0-9]+/.test(t) && t.includes('serve uma vez'), 'texto ' + t);
  const v = await axe(p); confere(v.length === 0, 'axe painel ' + v);
  await p.keyboard.press('Escape'); confere(await p.isHidden('#painel'), 'painel não fechou');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('parceiro vê oportunidade e fala na sala', async () => {
  const p = await abrir('portal.html', 'paulo'); await pronto(p);
  confere((await p.textContent('#titulo')) === 'Portal do parceiro', 'título');
  confere(await p.isVisible('#t-oportunidades') && await p.isVisible('#t-carteira') && await p.isVisible('#t-prestacao'), 'abas do parceiro ocultas');
  await p.click('#t-oportunidades'); confere((await p.textContent('#conteudo')).includes('Prefeitura Vizinha'), 'oportunidade ausente');
  const id = await p.getAttribute('#conteudo [data-oportunidade]', 'data-oportunidade');
  await p.fill('#sm-' + id, 'Sala ' + marca); await p.click(`[data-sala="${id}"]`);
  await p.waitForSelector(`.sala .msg.parceiro:has-text("Sala ${marca}")`);
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('parceiro registra nova oportunidade pelo pedido', async () => {
  const p = await abrir('portal.html', 'paulo'); await pronto(p);
  await p.click('#b-novo'); await p.selectOption('#f-tipo', 'oportunidade');
  await p.fill('#f-cliente', 'Cliente ' + marca); await p.fill('#f-assunto', 'Oportunidade ' + marca); await p.fill('#f-texto', 'Registro de teste.');
  await p.click('#f-novo button[type="submit"]'); await p.waitForSelector('#recibos .recibo');
  const r = await p.textContent('#recibos'); confere(r.includes('registrado'), 'recibo ' + r);
  await p.waitForSelector('#t-oportunidades[aria-selected="true"]', { timeout: 5000 });
  await p.waitForSelector(`#conteudo [data-oportunidade]:has-text("Cliente ${marca}")`, { timeout: 5000 });
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('parceiro envia nota: hash no navegador, Drive pela função do servidor, registro com o id', async () => {
  const p = await abrir('portal.html', 'paulo'); await pronto(p); const chamadas = rpc(p);
  let corpo = null; const idDrive = 'drv-' + marca.replace(/\W/g, '');
  await p.route(GOOGLE, r => { if (r.request().method() === 'OPTIONS') return r.fulfill({ status: 204, headers: CORS });
    corpo = JSON.parse(r.request().postData()); return r.fulfill({ status: 200, headers: CORS, contentType: 'application/json', body: JSON.stringify({ id: idDrive, link: 'https://drive.google.com/x' }) }); });
  // nota sem comissão adquirida: a conferência a marca como divergente e mostra os pontos
  await p.click('#t-prestacao'); await p.click('#b-prestar'); await p.selectOption('#f-prt', 'nf');
  const conteudo = 'NOTA FISCAL DE SERVIÇO ' + marca;
  await p.setInputFiles('#f-pra', { name: 'nota-' + marca.replace(/\W/g, '') + '.txt', mimeType: 'text/plain', buffer: Buffer.from(conteudo) });
  const resp = p.waitForResponse(r => r.url().endsWith('/rpc/imts') && r.request().postData().includes('ext.prestacao_enviar'));
  await p.click('#f-pr button[type="submit"]'); const reg = await (await resp).json(); await p.waitForSelector('#painel', { state: 'hidden' });
  confere(corpo && corpo.acao === 'drive_enviar' && corpo.pasta === '07' && Buffer.from(corpo.conteudo, 'base64').toString() === conteudo, 'corpo Drive ' + JSON.stringify(corpo)?.slice(0, 200));
  const c = chamadas.find(x => x.p_fn === 'ext.prestacao_enviar');
  const h = crypto.createHash('sha256').update(conteudo).digest('hex');
  confere(c && c.p_args.p_hash === h && c.p_args.p_drive_id === idDrive && c.p_args.p_texto === conteudo, 'registro ' + JSON.stringify(c));
  const item = await p.textContent(`[data-prestacao="${reg.prestacao}"]`);
  confere(item.includes('divergente') && item.includes('Não confere'), 'prestação não listada com a conferência: ' + item);
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('Drive indisponível: mostra o motivo, nada é registrado e a tela segue', async () => {
  const p = await abrir('portal.html', 'paulo'); await pronto(p); const chamadas = rpc(p);
  await p.route(GOOGLE, r => r.request().method() === 'OPTIONS' ? r.fulfill({ status: 204, headers: CORS })
    : r.fulfill({ status: 503, headers: CORS, contentType: 'application/json', body: JSON.stringify({ erro: 'Google Drive indisponível', codigo: 'google' }) }));
  p.erros.length = 0;
  await p.click('#t-prestacao'); const antes = await p.$$eval('[data-prestacao]', a => a.length);
  await p.click('#b-prestar'); await p.selectOption('#f-prt', 'relatorio');
  await p.setInputFiles('#f-pra', { name: 'falha-' + Date.now() + '.txt', mimeType: 'text/plain', buffer: Buffer.from('falha ' + Date.now()) });
  await p.click('#f-pr button[type="submit"]'); await p.waitForFunction(() => document.getElementById('f-prm')?.textContent);
  const m = await p.textContent('#f-prm'); confere(m.includes('Google Drive indisponível') && m.includes('Nada foi registrado'), 'mensagem ' + m);
  confere(!chamadas.some(x => x.p_fn === 'ext.prestacao_enviar'), 'registrou sem arquivo');
  await p.click('#p-cancelar'); confere((await p.$$eval('[data-prestacao]', a => a.length)) === antes, 'lista mudou');
  await p.click('#t-oportunidades'); confere((await p.textContent('#conteudo')).includes('Prefeitura Vizinha'), 'resto da tela parou');
  const outros = p.erros.filter(e => !/503|Failed to load resource/.test(e)); confere(outros.length === 0, 'erros ' + outros); await p.close(); });

// ---------- notas de débito: preparo pela porta única (rui cria, lia aprova, rui emite; o worker do motor gera o PDF; rui publica) ----------
async function porta(quem, fn, args) {
  const r = await fetch('http://127.0.0.1:3399/rpc/imts', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token(U[quem]) }, body: JSON.stringify({ p_fn: fn, p_args: args }) });
  const j = await r.json(); if (!r.ok) throw new Error(fn + ': ' + j.message); return j;
}
function rodarWorker() {
  const b = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const h = b({ alg: 'HS256', typ: 'JWT' }), c = b({ role: 'anon', exp: Math.floor(Date.now() / 1000) + 600 });
  const anon = h + '.' + c + '.' + crypto.createHmac('sha256', process.env.IMTS_JWT_SEGREDO || 'segredo-de-ensaio-local-com-32-caracteres-ou-mais').update(h + '.' + c).digest('base64url');
  const chave = execFileSync('psql', ['postgresql:///app_ensaio?port=5499', '-Atc', "select decrypted_secret from vault.decrypted_secrets where name = 'doc_worker_chave'"]).toString().trim();
  return execFileSync('python3', ['worker.py', '--uma-vez'], { cwd: new URL('../../documentos/', import.meta.url).pathname, timeout: 240000, stdio: ['ignore', 'pipe', 'ignore'],
    env: { ...process.env, SUPABASE_URL: 'http://127.0.0.1:3399', SUPABASE_REST: 'http://127.0.0.1:3399', SUPABASE_CHAVE_PUB: anon, DOC_WORKER_CHAVE: chave, DOC_WORKER_NOME: 'ensaio-app' } }).toString();
}

await caso('cliente vê a nota de débito publicada para ela, com o PDF; o parceiro não vê', async () => {
  const emp = (await porta('rui', 'rt.quem_sou', {})).empresas.find(e => e.nome === 'Empresa Alfa').id;
  const cp = (await porta('rui', 'doc.painel_notas_debito', { p_empresa: emp })).contrapartes.find(c => c.nome === 'Prefeitura Exemplo').id;
  const hoje = new Date().toISOString().slice(0, 10), venc = new Date(Date.now() + 15 * 864e5).toISOString().slice(0, 10);
  const n = await porta('rui', 'doc.nota_debito_salvar', { p_empresa: emp, p_contraparte: cp, p_vencimento: venc, p_referencia: 'Portal ' + marca, p_local: 'Fortaleza/CE',
    p_itens: [{ descricao: 'Taxa de cartório ' + marca, data: hoje, valor: 45.9 }, { descricao: 'Cópias autenticadas', data: hoje, valor: 12 }] });
  await porta('lia', 'doc.nota_debito_aprovar', { p_nota: n.id }); await porta('rui', 'doc.nota_debito_emitir', { p_nota: n.id });
  rodarWorker(); const pub = await porta('rui', 'doc.nota_debito_publicar', { p_nota: n.id });
  const p = await abrir('portal.html', 'clara'); await pronto(p);
  await p.click('#t-notas'); await p.waitForSelector(`#conteudo article[data-nd="${n.id}"]`);
  const t = (await p.textContent(`article[data-nd="${n.id}"]`)).replace(/\s+/g, ' ');
  confere(t.includes(n.numero) && t.includes('R$ 57,90') && t.includes('em aberto') && t.includes('Portal ' + marca), 'nota no portal: ' + t);
  const [d] = await Promise.all([p.waitForEvent('download'), p.click(`article[data-nd="${n.id}"] [data-baixar="${pub.emissao}"]`)]);
  confere(fs.readFileSync(await d.path()).subarray(0, 5).toString() === '%PDF-', 'PDF não baixou');
  await p.click(`article[data-nd="${n.id}"] summary`); const v = await axe(p); confere(v.length === 0, 'axe ' + v);
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  const q = await abrir('portal.html', 'paulo'); await pronto(q); await q.click('#t-notas'); await q.waitForSelector('#t-notas[aria-selected="true"]');
  confere(!(await q.$(`article[data-nd="${n.id}"]`)), 'parceiro vê a nota da Prefeitura');
  confere(q.erros.length === 0, 'erros ' + q.erros); await q.close();
  await porta('lia', 'doc.nota_debito_cancelar', { p_nota: n.id, p_motivo: 'Conferência do teste do portal ' + marca });   // não deixa cobrança aberta no ensaio
});

await caso('pessoa de dentro é recusada e volta à entrada', async () => {
  const p = await abrir('portal.html', 'olga'); await p.waitForURL(/index\.html/, { timeout: 5000 }); await p.waitForSelector('#inicio:not([hidden])'); await p.close(); });
await caso('sem cadastro é recusado', async () => {
  const p = await abrir('portal.html', 'curioso'); await p.waitForURL(/index\.html/, { timeout: 5000 }); await p.waitForSelector('#sem:not([hidden])'); await p.close(); });

await caso('acessibilidade e largura: 1280 claro, 1280 escuro, 390 claro', async () => {
  for (const quem of ['clara', 'paulo']) for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const p = await abrir('portal.html', quem, { largura: l, esquema: e }); await pronto(p);
    for (const aba of quem === 'paulo' ? ['andamentos', 'pedidos', 'oportunidades', 'carteira', 'prestacao', 'notas'] : ['andamentos', 'pedidos', 'reunioes', 'notas']) {
      await p.click('#t-' + aba); const v = await axe(p); confere(v.length === 0, `${quem} ${l} ${e} ${aba} axe ${v}`);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${quem} ${aba} rolagem horizontal ${larg}`);
    }
    await p.click('#b-novo'); const v = await axe(p); confere(v.length === 0, `${quem} ${l} ${e} novo pedido axe ${v}`);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); } });

await fim('portal');
