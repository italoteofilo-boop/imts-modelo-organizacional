// Valida cada .bpmn de um diretório: leitura pelo metamodelo BPMN 2.0 (bpmn-moddle) e regras do bpmnlint.
// Uso: node validar2.mjs <diretório com .bpmn>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { BpmnModdle } = await import('bpmn-moddle');
const { Linter } = require('bpmnlint');
const NodeResolver = require('bpmnlint/lib/resolver/node-resolver');

const dir = path.resolve(process.argv[2]);
const files = fs.readdirSync(dir).filter(f => f.endsWith('.bpmn')).sort();
const linter = new Linter({ config: { extends: 'bpmnlint:recommended' }, resolver: new NodeResolver() });
let total = 0, regras = new Set();
for (const f of files) {
  const xml = fs.readFileSync(path.join(dir, f), 'utf8');
  const moddle = new BpmnModdle();
  const { rootElement, warnings } = await moddle.fromXML(xml);
  const res = await linter.lint(rootElement);
  const msgs = [];
  for (const [rule, reports] of Object.entries(res)) {
    regras.add(rule);
    for (const r of reports) msgs.push(`${r.category} ${rule}: ${r.id} ${r.message}`);
  }
  total += warnings.length + msgs.length;
  console.log(f, '| avisos de leitura:', warnings.length, '| apontamentos do lint:', msgs.length);
  for (const w of warnings) console.log('   leitura:', w.message);
  for (const m of msgs) console.log('   lint:', m);
}
const cfg = require('bpmnlint/config/recommended.js');
const ativas = Object.entries(cfg.rules || {}).filter(([k, v]) => v !== 'off' && v !== 0);
console.log('REGRAS', ativas.length);
console.log('ARQUIVOS', files.length, '| TOTAL', total);
process.exit(total ? 1 : 0);
