// Confere, no desenho feito pelo bpmn-js, se algum rótulo de tarefa fica encoberto pelo ícone do tipo de tarefa
// ou sai da caixa. Uso: node sobrepoe.mjs <dir com .bpmn> [--lista]
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';
const exe = process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const browser = await chromium.launch({ executablePath: exe, args: ['--no-sandbox'] });
const lib = fs.readFileSync('node_modules/bpmn-js/dist/bpmn-navigated-viewer.production.min.js', 'utf8');
const dir = path.resolve(process.argv[2]);
const lista = process.argv.includes('--lista');
let tot = 0, tarefas = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.bpmn')).sort()) {
  const xml = fs.readFileSync(path.join(dir, f), 'utf8');
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
  await page.setContent('<html><body style="margin:0;background:#fff"><div id="c" style="width:1600px;height:1000px"></div></body></html>');
  await page.addScriptTag({ content: lib });
  const res = await page.evaluate(async (xml) => {
    const v = new BpmnJS({ container: '#c' });
    await v.importXML(xml);
    const reg = v.get('elementRegistry');
    const out = [];
    let n = 0;
    reg.forEach(function (el) {
      if (!/Task$|CallActivity$/.test(el.type)) return;
      n++;
      const g = reg.getGraphics(el);
      const vis = g.querySelector('.djs-visual');
      const text = vis.querySelector('text');
      if (!text) return;
      const tb = text.getBBox();
      const first = text.querySelector('tspan');
      const fb = first.getBBox ? first.getBBox() : tb;
      // ícones: todo path/circle/rect dentro do visual que não é a caixa (primeiro rect) nem o texto
      const kids = Array.from(vis.children).filter(k => k.tagName !== 'text');
      const box = kids[0];
      let hit = false, why = '';
      for (const k of kids.slice(1)) {
        const b = k.getBBox();
        if (b.width > 40 || b.height > 40) continue;      // borda dupla da atividade de chamada etc.
        // rótulo linha a linha
        for (const ts of text.querySelectorAll('tspan')) {
          const r = ts.getBBox();
          if (r.x < b.x + b.width - 1 && r.x + r.width > b.x + 1 && r.y + 2 < b.y + b.height - 1 && r.y + r.height - 2 > b.y + 1) { hit = true; why = 'ícone'; }
        }
      }
      if (tb.y < 2 || tb.y + tb.height > el.height - 2 || tb.x < 2 || tb.x + tb.width > el.width - 2) { hit = true; why = why ? why + ' e borda' : 'borda'; }
      if (hit) out.push({ id: el.id, name: el.businessObject.name, why, linhas: text.querySelectorAll('tspan').length });
    });
    return { n, out };
  }, xml);
  tarefas += res.n; tot += res.out.length;
  console.log(f, 'tarefas', res.n, 'rótulos com problema', res.out.length);
  if (lista) for (const o of res.out) console.log('   ', o.why, '|', o.linhas, 'linhas |', o.name.length, 'car. |', o.name);
  await page.close();
}
await browser.close();
console.log('TAREFAS', tarefas, '| RÓTULOS COM PROBLEMA', tot);
process.exit(tot ? 1 : 0);
