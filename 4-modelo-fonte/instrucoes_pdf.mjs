// Gera um PDF A4 por instrução de trabalho (saida/instrucoes/html/*.html -> saida/instrucoes/pdf/*.pdf).
// Uso: node instrucoes_pdf.mjs   (precisa do Playwright com Chromium)
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import { readdirSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const base = join(dirname(fileURLToPath(import.meta.url)), 'saida', 'instrucoes');
mkdirSync(join(base, 'pdf'), { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage();
let n = 0;
for (const f of readdirSync(join(base, 'html')).filter(f => f.endsWith('.html')).sort()) {
  await page.goto('file://' + join(base, 'html', f), { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.emulateMedia({ media: 'print' });
  await page.pdf({ path: join(base, 'pdf', f.replace('.html', '.pdf')), format: 'A4', printBackground: true,
                   displayHeaderFooter: true, headerTemplate: '<span></span>',
                   footerTemplate: `<div style="font-size:8px;width:100%;padding:0 13mm;color:#58666F;display:flex;justify-content:space-between"><span>${f.replace('.html', '')} · Instrução de trabalho · versão 2026-10-03</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>`,
                   margin: { top: '14mm', bottom: '16mm', left: '13mm', right: '13mm' } });
  n++;
}
await browser.close();
console.log('pdfs', n);
