// Mesa no Telegram (Mini App, app/tg.html): o Telegram.WebApp é simulado (o script oficial é trocado por um que entrega o initData
// assinado aqui com um token de ensaio, pelo algoritmo da documentação), e a função telegram_app roda de verdade
// (supabase/functions/testes/servir_ensaio.ts, numa porta própria) contra o banco app_ensaio.
// Casos: abrir e ver a Mesa sem ids internos, concluir, aceitar, recusar, decidir com cancelamento, sem vínculo, assinatura inválida,
// fora do Telegram, e acessibilidade (axe) em 390 e 1280, claro e escuro, sem rolagem horizontal.
import { axe, caso, confere, fim, pw, U } from './apoio.mjs';
import { execFileSync, spawn } from 'node:child_process'; import crypto from 'node:crypto';

const BASE = process.env.IMTS_BASE || 'http://127.0.0.1:3390/';
const PORTA = Number(process.env.PORTA_TG || 3397);
const DB = process.env.IMTS_DB_URL || 'postgres://postgres:ensaio-local@127.0.0.1:5499/app_ensaio';
const psql = q => execFileSync('psql', [DB, '-Atc', q]).toString().trim();
const DENO = process.env.DENO || '/tmp/pgt/npm/node_modules/.bin/deno';
const TOKEN = '987654:token-de-ensaio-do-mini-app';
const TG_OLGA = 660000000 + Math.floor(Math.random() * 9000000);
const MARCA = Date.now().toString(36);

// ---------- ensaio: token do bot no cofre e Telegram ligado à Olga (desfeito no fim) ----------
const olga = psql(`select pseudonimo from rt_chave.login where auth_uid = '${U.olga}'`);
const lia = psql(`select pseudonimo from rt_chave.login where auth_uid = '${U.lia}'`);
const consentimento = psql(`select coalesce(consentimento_art33_em::text, '') from rt_chave.identidade where pseudonimo = '${olga}'`);
// o cofre é do banco de ensaio inteiro: outra rodada de testes pode mexer no token; por isso ele é regravado a cada abertura e restaurado no fim
const tokenAntes = psql(`select coalesce(rt._segredo('telegram_bot_token'), '')`);
const gravarToken = v => psql(`delete from vault.secrets where name = 'telegram_bot_token'` + (v ? `; select vault.create_secret('${v.replace(/'/g, "''")}', 'telegram_bot_token')` : ''));
gravarToken(TOKEN);
psql(`update rt_chave.identidade set telegram_id = ${TG_OLGA}, consentimento_art33_em = coalesce(consentimento_art33_em, now()) where pseudonimo = '${olga}'`);
const avulsa = (dono, titulo) => psql(`select rt.criar_avulsa('${dono}'::uuid, '${titulo}', now() + interval '1 day', null, 'telegram')`);
const cConcluir = avulsa(olga, 'Mini App concluir ' + MARCA);
const cAceitar = avulsa(lia, 'Mini App pedido aceitar ' + MARCA); psql(`select rt.delegar_cartao(${cAceitar}, '${lia}'::uuid, '${olga}'::uuid, false, null)`);
const cRecusar = avulsa(lia, 'Mini App pedido recusar ' + MARCA); psql(`select rt.delegar_cartao(${cRecusar}, '${lia}'::uuid, '${olga}'::uuid, false, null)`);

// ---------- função do servidor local ----------
const servidor = spawn(DENO, ['run', '-A', new URL('../../supabase/functions/testes/servir_ensaio.ts', import.meta.url).pathname],
  { env: { ...process.env, PORTA: String(PORTA), DENO_DIR: process.env.DENO_DIR || '/tmp/pgt/deno' }, stdio: ['ignore', 'pipe', 'pipe'] });
await new Promise((ok, falha) => { const t = setTimeout(() => falha(new Error('função local não subiu')), 90000);
  servidor.stdout.on('data', d => { if (String(d).includes('pronto')) { clearTimeout(t); ok(); } }); servidor.on('exit', c => falha(new Error('função local saiu: ' + c))); });

// ---------- Telegram simulado ----------
function initData(tg, token = TOKEN) {
  const campos = { auth_date: String(Math.floor(Date.now() / 1000) - 3), query_id: 'AAE' + MARCA, user: JSON.stringify({ id: tg, first_name: 'Olga', language_code: 'pt-br' }) };
  const dcs = Object.keys(campos).sort().map(k => k + '=' + campos[k]).join('\n');
  const chave = crypto.createHmac('sha256', 'WebAppData').update(token).digest();
  return new URLSearchParams({ ...campos, hash: crypto.createHmac('sha256', chave).update(dcs).digest('hex') }).toString();
}
const TEMAS = {   // cores padrão dos aplicativos do Telegram (o botão claro não tem contraste AA: a página corrige)
  light: { bg_color: '#ffffff', text_color: '#000000', hint_color: '#999999', link_color: '#2481cc', button_color: '#40a7e3', button_text_color: '#ffffff', secondary_bg_color: '#f1f1f1', destructive_text_color: '#ff3b30' },
  dark: { bg_color: '#212121', text_color: '#ffffff', hint_color: '#aaaaaa', link_color: '#8774e1', button_color: '#8774e1', button_text_color: '#ffffff', secondary_bg_color: '#181818', destructive_text_color: '#ff595a' },
};
const simulador = (dados, esquema, confirma) => `window.__tg = { confirmacoes: [], vibracoes: [], prontos: 0 };
  window.Telegram = { WebApp: { initData: ${JSON.stringify(dados)}, initDataUnsafe: {}, version: '8.0', platform: 'ensaio', colorScheme: ${JSON.stringify(esquema)},
    themeParams: ${JSON.stringify(TEMAS[esquema])}, isVersionAtLeast: () => true, ready() { window.__tg.prontos++; }, expand() {}, close() { window.__tg.fechou = true; },
    onEvent() {}, setHeaderColor() {}, setBackgroundColor() {}, openLink(u) { window.__tg.link = u; },
    showConfirm(m, cb) { window.__tg.confirmacoes.push(m); setTimeout(() => cb(${confirma ? 'true' : 'false'}), 0); },
    HapticFeedback: { notificationOccurred(t) { window.__tg.vibracoes.push(t); }, impactOccurred() {} } } };`;

let navegador;
async function abrirTg(opc = {}) {
  navegador ??= await pw.chromium.launch();
  if (psql(`select coalesce(rt._segredo('telegram_bot_token'), '')`) !== TOKEN) gravarToken(TOKEN);
  const largura = opc.largura || 390, esquema = opc.esquema || 'light';
  const p = await navegador.newPage({ viewport: { width: largura, height: 860 }, colorScheme: esquema, reducedMotion: 'reduce' });
  const erros = []; p.on('pageerror', e => erros.push(String(e))); p.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) erros.push(m.text()); });
  p.erros = erros; p.pedidos = [];
  await p.route('https://telegram.org/js/telegram-web-app.js', r => r.fulfill({ status: 200, contentType: 'text/javascript',
    body: opc.semTelegram ? 'window.Telegram = { WebApp: { initData: "", initDataUnsafe: {}, ready() {}, expand() {}, onEvent() {}, themeParams: {} } };'
      : simulador(opc.dados ?? initData(TG_OLGA), esquema, opc.confirma !== false) }));
  // a página chama 127.0.0.1:3398/telegram_app (config de ensaio); aqui vai para a função desta rodada
  await p.route('http://127.0.0.1:3398/telegram_app', async r => {
    const req = r.request(); p.pedidos.push(req.postDataJSON?.() ?? null);
    const resp = await fetch(`http://127.0.0.1:${PORTA}/telegram_app`, { method: req.method(), headers: { 'content-type': 'application/json', 'x-forwarded-for': opc.ip || '192.0.2.10' }, body: req.postData() });
    await r.fulfill({ status: resp.status, headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' }, body: await resp.text() });
  });
  await p.goto(BASE + 'tg.html'); await p.waitForSelector('body[data-pronto="1"]', { timeout: 15000 });
  return p;
}
const cartao = (p, id) => p.locator(`li.cartao[data-cartao="${id}"]`);
const status = p => p.textContent('#status');

try {
  await caso('olga abre a Mesa no Telegram: tarefas abertas, grupos e nenhum id interno', async () => {
    const p = await abrirTg();
    confere((await p.textContent('#quem')).includes('Olga Operações'), 'sem o nome');
    confere(await cartao(p, cConcluir).count() === 1 && await cartao(p, cAceitar).count() === 1, 'cartões de teste ausentes');
    confere((await p.textContent('#g-aceitar')).startsWith('Pedidos para você'), 'grupo de pedidos');
    confere(await p.locator(`#lista section:first-child li.cartao[data-cartao="${cAceitar}"]`).count() === 1, 'pedido não vem primeiro');
    const html = await p.content();
    confere(!html.includes(olga) && !html.includes(U.olga) && !/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.test(await p.textContent('#lista')), 'id interno na página');
    confere((await p.evaluate(() => window.__tg.prontos)) === 1, 'não chamou ready()');
    confere(p.pedidos[0]?.initData?.includes('hash=') && p.pedidos[0]?.acao === 'mesa', 'não mandou o initData');
    confere(!(await p.evaluate(() => JSON.stringify(localStorage) + JSON.stringify(sessionStorage))).includes('token'), 'guardou segredo no navegador');
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  });

  await caso('concluir pede confirmação no Telegram e some da lista', async () => {
    const p = await abrirTg();
    await cartao(p, cConcluir).locator('button[data-acao="concluir"]').click();
    await p.waitForFunction(id => !document.querySelector(`li.cartao[data-cartao="${id}"]`), cConcluir, { timeout: 8000 });
    confere((await status(p)).startsWith('Feito: #' + cConcluir), 'status: ' + await status(p));
    confere((await p.evaluate(() => window.__tg.confirmacoes[0])).includes('Concluir'), 'sem confirmação');
    confere((await p.evaluate(() => window.__tg.vibracoes)).includes('success'), 'sem retorno tátil');
    confere(psql(`select coluna from rt.cartao where id = ${cConcluir}`) === 'feito', 'banco não concluiu');
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  });

  await caso('aceitar e recusar os pedidos da Lia', async () => {
    const p = await abrirTg();
    await cartao(p, cAceitar).locator('button[data-acao="aceitar"]').click();
    await p.waitForFunction(id => { const c = document.querySelector(`li.cartao[data-cartao="${id}"]`); return c && !c.querySelector('[data-acao="aceitar"]') && c.querySelector('[data-acao="concluir"]'); }, cAceitar, { timeout: 8000 });
    confere((await status(p)).startsWith('Aceito: #' + cAceitar), 'status: ' + await status(p));
    await cartao(p, cRecusar).locator('button[data-acao="recusar"]').click();
    await p.waitForFunction(id => !document.querySelector(`li.cartao[data-cartao="${id}"]`), cRecusar, { timeout: 8000 });
    confere((await status(p)).startsWith('Recusado: #' + cRecusar), 'status: ' + await status(p));
    confere(psql(`select aceite from rt.cartao where id = ${cAceitar}`) === 'aceita' && psql(`select aceite from rt.cartao where id = ${cRecusar}`) === 'recusada', 'banco');
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  });

  await caso('decidir mostra as opções e, cancelado, nada muda', async () => {
    const p = await abrirTg({ confirma: false });
    const op = p.locator('#g-decidir ~ ul button[data-acao="decidir"], section[aria-labelledby="g-decidir"] button[data-acao="decidir"]').first();
    const temDecisao = Number(psql(`select count(*) from rt.cartao where coluna = 'decidir' and (dono = '${olga}' or delegado_pessoa = '${olga}')`)) > 0;
    confere((await op.count() > 0) === temDecisao, 'opções de decisão: banco ' + temDecisao);
    if (!temDecisao) { await p.close(); return; }
    const id = await op.getAttribute('data-id'); const antes = psql(`select coluna from rt.cartao where id = ${id}`);
    const n = p.pedidos.length;
    await op.click(); await p.waitForFunction(() => document.getElementById('status').textContent === 'Nada foi feito.');
    confere(p.pedidos.length === n && psql(`select coluna from rt.cartao where id = ${id}`) === antes, 'decidiu sem confirmar');
    confere((await p.evaluate(() => window.__tg.confirmacoes[0])).startsWith('Decidir'), 'sem confirmação');
    await p.close();
  });

  await caso('Telegram sem vínculo: instrução de como ligar pelo bot', async () => {
    const p = await abrirTg({ dados: initData(TG_OLGA + 10000000) });
    confere(await p.isVisible('#instrucao') && (await p.textContent('#instrucao-p')).includes('/vincular'), 'sem instrução');
    confere(await p.locator('li.cartao').count() === 0 && await p.isHidden('#resumo'), 'mostrou dados');
    const v = await axe(p); confere(v.length === 0, 'axe ' + v);
    await p.click('#fechar'); confere(await p.evaluate(() => window.__tg.fechou), 'não fechou');
    await p.close();
  });

  await caso('assinatura inválida: recusa clara e nada de dados', async () => {
    const p = await abrirTg({ dados: initData(TG_OLGA, '111:outro-bot'), ip: '192.0.2.77' });
    confere(await p.isVisible('#erro') && (await p.textContent('#erro')).includes('assinatura'), 'erro: ' + await p.textContent('#erro'));
    confere(await p.locator('li.cartao').count() === 0, 'mostrou cartões');
    await p.close();
  });

  await caso('aberta fora do Telegram: orienta a abrir pelo bot', async () => {
    const p = await abrirTg({ semTelegram: true });
    confere((await p.textContent('#instrucao')).includes('Abra pelo Telegram') && p.pedidos.length === 0, 'chamou a função sem initData');
    const v = await axe(p); confere(v.length === 0, 'axe ' + v); await p.close();
  });

  await caso('acessibilidade: 390 e 1280, claro e escuro, sem rolagem horizontal', async () => {
    for (const [l, e] of [[390, 'light'], [390, 'dark'], [1280, 'light'], [1280, 'dark']]) {
      const p = await abrirTg({ largura: l, esquema: e });
      confere(await p.locator('li.cartao').count() >= 1, l + e + ' sem cartões');
      confere((await p.getAttribute('html', 'data-theme')) === e, 'tema do Telegram não aplicado');
      if (process.env.TG_FOTOS) await p.screenshot({ path: `${process.env.TG_FOTOS}/tg-${l}-${e}.png` });
      const v = await axe(p); confere(v.length === 0, l + e + ' axe ' + v);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, l + ' rolagem horizontal ' + larg);
      confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
    }
  });
} finally {
  psql(`update rt_chave.identidade set telegram_id = null, consentimento_art33_em = ${consentimento ? `'${consentimento}'` : 'null'} where pseudonimo = '${olga}' and telegram_id = ${TG_OLGA}`);
  gravarToken(tokenAntes);
  servidor.kill();
  if (navegador) await navegador.close();
}
await fim('tg');
