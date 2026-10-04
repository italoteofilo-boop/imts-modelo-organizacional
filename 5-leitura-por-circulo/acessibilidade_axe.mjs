import { createRequire } from 'module'; const require = createRequire('/usr/lib/node_modules/'); const pw = require('playwright');
import fs from 'fs';
const axe = fs.readFileSync('/tmp/esb/node_modules/axe-core/axe.min.js', 'utf8');
const [P, mockPortal, mockAdmin, saida] = process.argv.slice(2);
const paginas = [['portal', P + '/portal/portal.html', fs.readFileSync(mockPortal, 'utf8')], ['administração', '/tmp/pgt/admin_teste.html', fs.readFileSync(mockAdmin, 'utf8')],
  ['biblioteca', P + '/biblioteca/biblioteca.html', ''], ['mesa', P + '/mesa/mesa.html', ''], ['painel', P + '/painel.html', '']];
const b = await pw.chromium.launch(); const rel = { data: new Date().toISOString(), axe: JSON.parse(fs.readFileSync('/tmp/esb/node_modules/axe-core/package.json', 'utf8')).version, regras: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'], resultados: [] };
for (const [nome, arq, mock] of paginas) for (const [larg, esq] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
  const p = await b.newPage({ viewport: { width: larg, height: 900 }, colorScheme: esq, reducedMotion: 'reduce' });
  if (mock) await p.addInitScript(mock);
  await p.route(/fonts\./, r => r.abort()); await p.goto('file://' + arq); await p.waitForTimeout(1200);
  await p.addScriptTag({ content: axe });
  const r = await p.evaluate(async (regras) => await axe.run(document, { runOnly: regras }), rel.regras);
  rel.resultados.push({ pagina: nome, largura: larg, tema: esq, violacoes: r.violations.map(v => ({ regra: v.id, impacto: v.impact, nos: v.nodes.length, exemplo: v.nodes[0]?.target.join(' ') })), aprovadas: r.passes.length, incompletas: r.incomplete.length });
  console.log(nome, larg, esq, 'violações', r.violations.length, r.violations.map(v => v.id + ':' + v.nodes.length).join(' '));
  await p.close();
}
await b.close(); fs.writeFileSync(saida, JSON.stringify(rel, null, 1));
