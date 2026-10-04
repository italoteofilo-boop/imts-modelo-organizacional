import { abrir, axe, caso, confere, fim } from './apoio.mjs';
await caso('sem sessão mostra a entrada', async () => { const p = await abrir('index.html'); confere(await p.isVisible('#entrar'), 'entrada oculta'); confere((await axe(p)).length === 0, 'axe ' + (await axe(p))); await p.close(); });
await caso('pessoa de dentro vê os módulos, sem Administração', async () => {
  const p = await abrir('index.html', 'olga'); await p.waitForSelector('#inicio:not([hidden])');
  const mods = await p.$$eval('#modulos a b', a => a.map(x => x.textContent));
  confere(mods.includes('Mesa') && !mods.includes('Administração'), 'módulos: ' + mods); confere((await p.textContent('#imts-barra')).includes('Olga'), 'barra sem nome');
  const v = await axe(p); confere(v.length === 0, 'axe ' + v); confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });
await caso('administrador vê Administração', async () => { const p = await abrir('index.html', 'admin'); await p.waitForSelector('#inicio:not([hidden])');
  confere((await p.$$eval('#modulos a b', a => a.map(x => x.textContent))).includes('Administração'), 'sem admin'); await p.close(); });
await caso('cliente vai para o Portal', async () => { const p = await abrir('index.html', 'clara'); await p.waitForURL(/portal\.html/, { timeout: 5000 }); await p.close(); });
await caso('sem cadastro não entra', async () => { const p = await abrir('index.html', 'curioso'); await p.waitForSelector('#sem:not([hidden])');
  confere((await p.textContent('#sem-texto')).includes('curioso@gmail.com'), 'texto'); const v = await axe(p); confere(v.length === 0, 'axe ' + v); await p.close(); });
await caso('escuro e celular sem violação', async () => { for (const [l, e] of [[1280, 'dark'], [390, 'light']]) { const p = await abrir('index.html', 'admin', { largura: l, esquema: e });
  await p.waitForSelector('#inicio:not([hidden])'); const v = await axe(p); confere(v.length === 0, l + e + ' axe ' + v);
  const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, 'rolagem horizontal ' + larg); await p.close(); } });
await fim('entrada');
