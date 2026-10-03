// Abre a página local de um círculo em vários tamanhos e temas e confere erros, largura e desenho do fluxo.
// Uso: node shot2.mjs <dir de saída do círculo> <prefixo de código> <abas...>
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';
const exe = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const dir = path.resolve(process.argv[2]);
const pref = process.argv[3];
const abas = process.argv.slice(4);
const browser = await chromium.launch({ executablePath: exe, args: ['--no-sandbox', '--allow-file-access-from-files'] });
const body = fs.readFileSync(path.join(dir, 'local.html'), 'utf8');
const html = '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"><style>:root{color-scheme:light}body{margin:0;font:14px system-ui;background:#fafafa}img{max-width:100%}[hidden]{display:none!important}</style></head><body>' + body + '</body></html>';
fs.writeFileSync(path.join(dir, 'teste.html'), html);
const url = 'file://' + path.join(dir, 'teste.html');
const runs = [
  ['desk-light', { width: 1440, height: 1000 }, 'light', ''],
  ['desk-dark', { width: 1440, height: 1000 }, 'dark', '#' + pref + '-02'],
  ['phone-light', { width: 400, height: 860 }, 'light', '#' + pref + '-04'],
  ['phone-dark', { width: 400, height: 860 }, 'dark', '#' + pref + '-05'],
];
for (const a of abas) runs.push(['aba-' + a, { width: 1440, height: 1000 }, 'light', '#' + a], ['aba-' + a + '-phone', { width: 400, height: 860 }, 'dark', '#' + a]);
let ruim = 0;
for (const [name, vp, scheme, hash] of runs) {
  const ctx = await browser.newContext({ viewport: vp, colorScheme: scheme, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  const errs = [];
  page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  page.on('pageerror', e => errs.push('pageerror ' + e.message));
  await page.goto(url + hash);
  await page.waitForTimeout(1300);
  const info = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth, h: document.documentElement.scrollHeight, svg: !!document.querySelector('#canvas svg'), aviso: !!document.querySelector('#canvas .aviso'), abas: document.querySelectorAll('#tabs button').length, visivel: Array.from(document.querySelectorAll('section[data-panel]')).filter(p => !p.hidden).map(p => p.getAttribute('data-panel')).join(',') }));
  await page.screenshot({ path: path.join(dir, `shot-${name}.png`), fullPage: true });
  const ok = info.sw <= info.cw && !errs.length && (info.visivel !== 'jornadas' || (info.svg && !info.aviso));
  if (!ok) ruim++;
  console.log(ok ? 'ok  ' : 'RUIM', name, JSON.stringify(info), 'erros:', errs.length, errs.slice(0, 3).join(' | '));
  await ctx.close();
}
await browser.close();
console.log('TELAS COM PROBLEMA:', ruim);
process.exit(ruim ? 1 : 0);
