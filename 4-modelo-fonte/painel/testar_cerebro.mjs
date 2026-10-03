import { createRequire } from 'module';
const require = createRequire('/usr/lib/node_modules/');
const pw = require('playwright');
const S = process.argv[2]; const b = await pw.chromium.launch(); const erros = [];
async function pag(o) { const p = await b.newPage(o); p.on('pageerror', e => erros.push(e.message)); p.on('console', m => { if (m.type() === 'error' && !/fonts|net::/.test(m.text())) erros.push(m.text()); });
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.abort()); await p.goto('file://' + S + '/painel/painel.html'); return p; }
const p = await pag({ viewport: { width: 1440, height: 950 } });
await p.waitForTimeout(9000);
await p.locator('#cx-rede').screenshot({ path: '/tmp/painel_v_cerebro.png' });
console.log('alertas:', await p.locator('#alertas li').count(), (await p.locator('#alertas').innerText()).slice(0, 300));
const n = await p.evaluate(() => [Object.keys(neur).length, MODELO.sinapses.length, impulsos.length]); console.log('neur/sin/impulsos', n);
await p.locator('#v-rede').click(); await p.waitForTimeout(800); await p.locator('#cx-rede').screenshot({ path: '/tmp/painel_v_rede.png' });
await p.locator('#v-cerebro').click();
const m = await pag({ viewport: { width: 390, height: 844 } }); await m.waitForTimeout(3000);
await m.locator('#cx-rede').screenshot({ path: '/tmp/painel_v_cerebro_movel.png' });
console.log('sw', await m.evaluate(() => document.documentElement.scrollWidth));
console.log('ERROS', JSON.stringify(erros)); await b.close();
