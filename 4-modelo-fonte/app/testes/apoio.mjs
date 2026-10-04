// Apoio dos testes de navegador do aplicativo. Ensaio local: PostgREST em 127.0.0.1:3399 sobre o banco app_ensaio,
// páginas em 127.0.0.1:3390 com testes/config.ensaio.js como config.js. O login é um token assinado com o segredo do ensaio.
import { createRequire } from 'module'; import crypto from 'node:crypto'; import fs from 'node:fs';
const require = createRequire('/usr/lib/node_modules/'); export const pw = require('playwright');
const SEGREDO = process.env.IMTS_JWT_SEGREDO || 'segredo-de-ensaio-local-com-32-caracteres-ou-mais';
export const BASE = process.env.IMTS_BASE || 'http://127.0.0.1:3390/';
export const U = { admin: '00000000-0000-4000-8000-000000000001', olga: '00000000-0000-4000-8000-000000000002', lia: '00000000-0000-4000-8000-000000000003',
  rui: '00000000-0000-4000-8000-000000000004', clara: '00000000-0000-4000-8000-000000000005', paulo: '00000000-0000-4000-8000-000000000006', curioso: '00000000-0000-4000-8000-000000000007' };
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
export function token(sub) {
  const h = b64({ alg: 'HS256', typ: 'JWT' }), p = b64({ sub, role: 'authenticated', aud: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 });
  return h + '.' + p + '.' + crypto.createHmac('sha256', SEGREDO).update(h + '.' + p).digest('base64url');
}
const AXE = fs.readFileSync(process.env.AXE || '/tmp/esb/node_modules/axe-core/axe.min.js', 'utf8');
let navegador;
export async function abrir(pagina, quem, opc = {}) {
  navegador ??= await pw.chromium.launch();
  const p = await navegador.newPage({ viewport: { width: opc.largura || 1280, height: 900 }, colorScheme: opc.esquema || 'light', reducedMotion: 'reduce' });
  const erros = []; p.on('pageerror', e => erros.push(String(e))); p.on('console', m => { if (m.type() === 'error') erros.push(m.text()); });
  p.erros = erros;
  await p.route(/fonts\.(googleapis|gstatic)/, r => r.fulfill({ status: 200, contentType: 'text/css', body: '' }));
  if (quem) await p.addInitScript(t => { sessionStorage.setItem('imts_token_teste', t); }, token(U[quem] || quem));
  await p.goto(BASE + pagina); await p.waitForLoadState('networkidle');
  return p;
}
export async function axe(p) {
  await p.addScriptTag({ content: AXE });
  const r = await p.evaluate(async () => await axe.run(document, { runOnly: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] }));
  return r.violations.map(v => v.id + ':' + v.nodes.length + ' ' + (v.nodes[0]?.target || []).join(' '));
}
let ok = 0, falhas = 0;
export async function caso(nome, fn) {
  try { await fn(); ok++; console.log('ok   ' + nome); } catch (e) { falhas++; console.log('FALHA ' + nome + ': ' + (e?.message || e)); }
}
export function confere(cond, msg) { if (!cond) throw new Error(msg); }
export async function fim(rotulo) { console.log(`${rotulo}: ${ok} ok, ${falhas} falhas`); if (navegador) await navegador.close(); process.exitCode = falhas ? 1 : 0; }
