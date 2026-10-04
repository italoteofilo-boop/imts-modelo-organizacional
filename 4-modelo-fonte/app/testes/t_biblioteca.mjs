import { abrir, axe, caso, confere, fim } from './apoio.mjs';
await caso('pessoa de dentro vê as amostras', async () => {
  const p = await abrir('biblioteca.html', 'olga'); await p.waitForSelector('main.pagina:not([hidden])');
  confere((await p.$$('.ficha')).length === 10, 'fichas');
  const img = await p.evaluate(() => [...document.images].filter(i => !i.complete || i.naturalWidth === 0).length); confere(img === 0, 'imagens quebradas ' + img);
  const r = await p.request.get(new URL('biblioteca/pdf/ata-imts.pdf', p.url()).href); confere(r.ok(), 'pdf');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });
await caso('quem é de fora volta à entrada', async () => { const p = await abrir('biblioteca.html', 'clara'); await p.waitForURL(/index\.html|portal\.html/, { timeout: 5000 }); await p.close(); });
await caso('axe e largura', async () => { for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
  const p = await abrir('biblioteca.html', 'olga', { largura: l, esquema: e }); await p.waitForSelector('main.pagina:not([hidden])');
  const v = await axe(p); confere(v.length === 0, l + e + ' ' + v); const w = await p.evaluate(() => document.documentElement.scrollWidth); confere(w <= l, 'rolagem ' + w); await p.close(); } });
await fim('biblioteca');
