// Desenha cada .bpmn de um diretório no bpmn-js e grava SVG e PNG (em faixas de 2600 px).
// Uso: node render2.mjs <dir com .bpmn> <dir de saída> [códigos]
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';
const exe = process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const browser = await chromium.launch({ executablePath: exe, args: ['--no-sandbox'] });
const lib = fs.readFileSync('node_modules/bpmn-js/dist/bpmn-navigated-viewer.production.min.js', 'utf8');
const dir = path.resolve(process.argv[2]), out = path.resolve(process.argv[3]);
const only = process.argv.slice(4);
fs.mkdirSync(out, { recursive: true });
let tot = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.bpmn')).sort()) {
  const code = f.replace('.bpmn', '');
  if (only.length && !only.includes(code)) continue;
  const xml = fs.readFileSync(path.join(dir, f), 'utf8');
  const page = await browser.newPage({ viewport: { width: 2400, height: 1500 } });
  const errs = [];
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errs.push(m.text()); });
  page.on('pageerror', e => errs.push('pageerror ' + e.message));
  await page.setContent('<html><body style="margin:0;background:#fff"><div id="c" style="width:2400px;height:1500px"></div></body></html>');
  await page.addScriptTag({ content: lib });
  const res = await page.evaluate(async (xml) => {
    const v = new BpmnJS({ container: '#c' });
    const r = await v.importXML(xml);
    const canvas = v.get('canvas');
    canvas.zoom('fit-viewport');
    const vb = canvas.viewbox();
    const { svg } = await v.saveSVG();
    return { warnings: r.warnings.map(w => w.message), inner: vb.inner, svg };
  }, xml);
  fs.writeFileSync(path.join(out, `${code}.svg`), res.svg);
  const w = Math.ceil(res.inner.width) + 40, h = Math.ceil(res.inner.height) + 40;
  const p2 = await browser.newPage({ viewport: { width: 2600, height: Math.min(h, 2000) } });
  await p2.setContent(`<html><body style="margin:0;background:#fff">${res.svg}</body></html>`);
  let k = 0;
  for (let x = 0; x < w - 40; x += 2500) {
    k++;
    await p2.screenshot({ path: path.join(out, `${code}_p${k}.png`), clip: { x, y: 0, width: Math.min(2600, w - x), height: Math.min(h, 2000) }, fullPage: true });
  }
  tot += res.warnings.length + errs.length;
  console.log(code, 'avisos', res.warnings.length, 'erros', errs.length, 'tamanho', w, 'x', h, 'faixas', k, res.warnings.slice(0, 3).join(' | '), errs.slice(0, 3).join(' | '));
  await page.close(); await p2.close();
}
await browser.close();
console.log('TOTAL de avisos e erros:', tot);
process.exit(tot ? 1 : 0);
