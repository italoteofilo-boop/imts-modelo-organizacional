import { createRequire } from 'module';
const require = createRequire('/usr/lib/node_modules/');
let pw; try { pw = require('playwright'); } catch { pw = require('/usr/lib/node_modules/playwright'); }
const S = process.argv[2];
const b = await pw.chromium.launch();
const erros = [];
async function pagina(opts) { const p = await b.newPage(opts); p.on('pageerror', e => erros.push(e.message)); p.on('console', m => { if (m.type() === 'error' && !/fonts|ERR_|net::/.test(m.text())) erros.push(m.text()); });
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort()); await p.goto('file://' + S + '/mesa/mesa.html'); return p; }
const p = await pagina({ viewport: { width: 1440, height: 950 } });
const txt = async s => (await p.locator(s).innerText()).replace(/\s+/g, ' ');
console.log('resumo:', await txt('#resumo'));
console.log('cartoes:', await p.locator('.cartao').count());
await p.screenshot({ path: '/tmp/mesa_1_desktop.png' });
// abrir um cartão de fluxo a fazer, começar e concluir
const c = p.locator('.celula[data-col="a_fazer"] .cartao').first(); const tit = await c.locator('.titulo').innerText(); await c.click();
await p.screenshot({ path: '/tmp/mesa_2_foco.png' });
console.log('dial desabilitados:', await p.locator('.dial button:disabled').count(), 'tit', tit);
await p.locator('[data-mover="fazendo"]').click();
console.log('recibo1:', await txt('#recibos .recibo:first-child'));
await p.locator('#f-concluir').click();
console.log('recibo2:', await txt('#recibos .recibo:first-child'));
await p.locator('#f-fechar').click().catch(()=>{});
// fluxo para esperando (deve recusar)
const c2 = p.locator('.celula[data-col="a_fazer"] .cartao').first(); await c2.click();
const n = await p.locator('.dial button:disabled').count(); console.log('teto dial', n);
await p.locator('.dial button:not(:disabled)').last().click();
console.log('recibo3:', await txt('#recibos .recibo:first-child'));
await p.keyboard.press('Escape');
// decidir
const d = p.locator('.celula[data-col="decidir"] .cartao').first(); await d.click(); await p.locator('[data-op="0"]').click();
console.log('recibo4:', await txt('#recibos .recibo:first-child'));
await p.keyboard.press('Escape');
// captura com sugestão
await p.fill('#texto', 'registrar a versão e a data de vigência da declaração'); await p.waitForTimeout(400);
console.log('sugestao:', await txt('#sugestao'));
await p.screenshot({ path: '/tmp/mesa_3_sugestao.png' });
await p.locator('#s-iniciar').click().catch(e => console.log('sem iniciar'));
console.log('recibo5:', await txt('#recibos .recibo:first-child'));
await p.fill('#texto', 'Comprar café para a oficina'); await p.locator('#captura button[type=submit]').click();
console.log('recibo6:', await txt('#recibos .recibo:first-child'));
// delegar avulsa a colega
const av = p.locator('.cartao', { hasText: 'Comprar café' }); await av.click();
const opt = await p.locator('#f-para option').nth(1).getAttribute('value'); await p.selectOption('#f-para', opt); await p.locator('#f-delegar').click();
console.log('recibo7:', await txt('#recibos .recibo:first-child'));
await p.keyboard.press('Escape');
// trocar para o líder e ver o círculo
const lider = await p.locator('#persona option', { hasText: 'Ítalo' }).getAttribute('value'); await p.selectOption('#persona', lider);
await p.locator('.aba[data-aba="circulo"]').click(); await p.selectOption('#sel-raia', 'jornada');
console.log('carga:', await txt('#b-carga'));
await p.screenshot({ path: '/tmp/mesa_4_circulo_lider.png', fullPage: true });
const m = await pagina({ viewport: { width: 390, height: 844 }, colorScheme: 'dark' });
await m.screenshot({ path: '/tmp/mesa_5_movel_escuro.png' });
const sw = await m.evaluate(() => document.documentElement.scrollWidth); console.log('scrollWidth movel', sw);
await m.locator('.celula.ativa .cartao').first().click(); await m.screenshot({ path: '/tmp/mesa_6_movel_foco.png' });
console.log('ERROS:', JSON.stringify(erros));
await b.close();
