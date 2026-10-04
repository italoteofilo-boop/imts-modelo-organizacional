// Painel da operação: leitura por rt.painel, rt.painel_detalhe, rt.painel_execucao e rt.app_catalogo; ações reais por rt.app_iniciar.
import { abrir, axe, caso, confere, fim, token, U } from './apoio.mjs';
import { execFileSync } from 'node:child_process';
const REST = process.env.IMTS_REST || 'http://127.0.0.1:3399';
const BANCO = process.env.IMTS_BANCO || 'postgresql:///app_ensaio?port=5499';
const psql = q => execFileSync('psql', [BANCO, '-Atc', q]).toString().trim();   // só leitura, para conferir o efeito das ações
async function porta(quem, fn, args = {}, empresa) {
  const h = { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token(U[quem]) }; if (empresa) h['x-empresa'] = empresa;
  const r = await fetch(REST + '/rpc/imts', { method: 'POST', headers: h, body: JSON.stringify({ p_fn: fn, p_args: args }) });
  const t = await r.text(); if (!r.ok) throw new Error(t); return JSON.parse(t);
}
const pronto = p => p.waitForFunction(() => document.getElementById('nivel').children.length > 0 && !/Carregando/.test(document.getElementById('nivel-sub').textContent));
const maxId = j => +psql(`select coalesce(max(id),0) from rt.instancia where jornada='${j}'`);
const semErro = p => confere(p.erros.length === 0, 'erros ' + p.erros);

// dado de partida: olga inicia uma jornada pela porta única
const empOlga = (await porta('olga', 'rt.quem_sou')).empresas[0].id;
const inicial = await porta('olga', 'rt.app_iniciar', { p_jornada: 'OP-02' }, empOlga);
console.log('preparo: execução ' + inicial + ' da OP-02');

let p;
await caso('olga entra e vê o resumo real, o círculo com todas as jornadas e a jornada', async () => {
  p = await abrir('painel.html', 'olga'); await pronto(p);
  confere(/painel\.html/.test(p.url()), 'saiu do painel');
  confere((await p.textContent('#imts-barra')).includes('Olga'), 'barra sem a pessoa');
  confere(await p.isVisible('#kpis') && await p.isVisible('#rede') && !(await p.isVisible('#aviso')), 'resumo não lido');
  const exec = +(await p.textContent('#kpis .kpi:first-child b')).replace(/\D/g, ''); confere(exec >= 1, 'execuções ' + exec);
  confere((await p.textContent('#feed')).includes('OP-02'), 'eventos recentes sem OP-02');
  await p.click('#nivel button.lk:text-is("7 · Operações")'); await pronto(p);
  const t = await p.textContent('#nivel');
  confere(t.includes('OP-02') && t.includes('OP-08'), 'círculo sem todas as jornadas do catálogo');
  await p.click('#nivel button.lk:text-is("OP-02")'); await pronto(p);
  confere((await p.textContent('#nivel-sub')).includes('Entregar o serviço'), 'nome da jornada');
  confere((await p.textContent('#nivel')).includes('#' + inicial), 'execução ' + inicial + ' não aparece');
  semErro(p);
});

let nova;
await caso('ação 1: iniciar uma execução da jornada aberta', async () => {
  const antes = maxId('OP-02');
  await p.click('#b-iniciar');
  await p.waitForFunction(() => /iniciada/.test(document.getElementById('aviso-nivel').textContent)); await pronto(p);
  nova = maxId('OP-02'); confere(nova > antes, 'banco sem execução nova');
  confere(psql(`select estado||'|'||simulado from rt.instancia where id=${nova}`) === 'rodando|false', 'execução não é real');
  confere((await p.textContent('#aviso-nivel')).includes(`Execução ${nova} da OP-02`), 'aviso sem o número');
  confere((await p.textContent('#nivel')).includes('#' + nova), 'tabela sem a nova execução');
  semErro(p);
});

await caso('abrir a execução nova (rt.painel_execucao)', async () => {
  await p.click(`#nivel button.lk:text-is("#${nova}")`); await pronto(p);
  confere((await p.textContent('#trilha')).includes('Execução ' + nova), 'trilha');
  const t = await p.textContent('#nivel');
  confere(t.includes('iniciada na Mesa') && t.includes('cartao criado'), 'eventos da execução: ' + t.slice(0, 200));
  const v = await axe(p); confere(v.length === 0, 'axe ' + v);
});

await caso('ação 2: iniciar outra jornada escolhida no catálogo', async () => {
  await p.click('#trilha button:text-is("Ecossistema")'); await pronto(p);
  const antes = maxId('OP-04');
  await p.selectOption('#f-jornada', 'OP-04'); await p.click('#b-iniciar-cod');
  await p.waitForFunction(() => /OP-04 iniciada/.test(document.getElementById('aviso-nivel').textContent)); await pronto(p);
  const n = maxId('OP-04'); confere(n > antes, 'banco sem execução da OP-04');
  confere((await p.textContent('#trilha')).includes('OP-04') && (await p.textContent('#nivel')).includes('#' + n), 'tela sem a execução da OP-04');
  confere((await p.textContent('#feed')).includes('OP-04'), 'eventos recentes sem OP-04');
  semErro(p);
});

await caso('jornada de outro círculo: a tela não oferece iniciar e o banco também recusa', async () => {
  await p.click('#trilha button:text-is("Ecossistema")'); await pronto(p);
  await p.selectOption('#f-jornada', 'RE-01');
  confere(await p.isDisabled('#b-iniciar-cod'), 'Iniciar habilitado para RE-01');
  confere((await p.textContent('#f-jornada-dica')).includes('não pode iniciar'), 'sem explicação');
  await p.click('#nivel form.abrir button[type=submit]'); await pronto(p);
  confere(await p.isVisible('#sem-iniciar') && !(await p.$('#b-iniciar')), 'jornada RE-01 oferece iniciar');
  let recusou = false; try { await porta('olga', 'rt.app_iniciar', { p_jornada: 'RE-01' }, empOlga); } catch (e) { recusou = /sem acesso/.test(e.message); }
  confere(recusou, 'banco aceitou RE-01');
  await p.click('#nivel .bar button.lk >> nth=0'); await pronto(p);
  confere((await p.textContent('#trilha')).includes('Etapa 1') && (await p.$$('#nivel tbody tr')).length > 0, 'etapa sem tarefas');
  semErro(p); await p.close();
});

await caso('produção vazia: estado "ainda não há execução"', async () => {
  const q = await abrir('painel.html', 'olga');
  await q.route('**/rpc/imts', async r => {
    let b = null; try { b = r.request().postDataJSON(); } catch (e) { /* segue */ }
    if (b?.p_fn !== 'rt.painel') return r.continue();
    const P = await (await r.fetch()).json();   // resposta real, zerada como na produção no primeiro dia
    Object.assign(P, { jornadas: null, etapas: null, executores: null, trocas: null });
    Object.assign(P.operacao, { instancias: 0, concluidas: 0, erros: 0, eventos: 0, trocas_enviadas: 0 });
    P.motores.forEach(m => Object.assign(m, { instancias: 0, tarefas_executadas: 0, trocas_envia: 0, trocas_recebe: 0 }));
    return r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(P) });
  });
  await q.reload(); await q.waitForLoadState('networkidle'); await pronto(q);
  confere((await q.textContent('#nivel')).includes('Ainda não há execução'), 'sem estado vazio no nível');
  confere((await q.textContent('#feed')).includes('Ainda não há execução'), 'sem estado vazio nos eventos');
  await q.click('#nivel button.lk:text-is("7 · Operações")'); await pronto(q);
  confere((await q.textContent('#nivel')).includes('Ainda não há execução neste círculo') && (await q.textContent('#nivel')).includes('OP-01'), 'círculo vazio sem catálogo');
  const v = await axe(q); confere(v.length === 0, 'axe ' + v); semErro(q); await q.close();
});

await caso('administrador entra', async () => {
  const q = await abrir('painel.html', 'admin'); await pronto(q);
  confere(/painel\.html/.test(q.url()), 'saiu do painel'); confere((await q.textContent('#imts-barra')).includes('Administração'), 'barra sem Administração');
  confere(await q.isVisible('#kpis'), 'sem números'); semErro(q); await q.close();
});

await caso('parceiro (paulo) é recusado', async () => {
  const q = await abrir('painel.html', 'paulo');
  await q.waitForURL(u => !/painel\.html/.test(String(u)), { timeout: 5000 });
  confere(!(await q.$('#kpis:not([hidden])')), 'viu o painel'); await q.close();
});

await caso('sem cadastro é recusado', async () => {
  const q = await abrir('painel.html', 'curioso');
  await q.waitForURL(u => !/painel\.html/.test(String(u)), { timeout: 5000 }); await q.close();
});

await caso('acessibilidade e largura: 1280 claro, 1280 escuro, 390 claro', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const q = await abrir('painel.html', 'olga', { largura: l, esquema: e }); await pronto(q);
    let v = await axe(q); confere(v.length === 0, `${l} ${e} axe ${v}`);
    let larg = await q.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} rolagem horizontal ${larg}`);
    await q.click('#nivel button.lk:text-is("7 · Operações")'); await pronto(q);
    v = await axe(q); confere(v.length === 0, `${l} ${e} círculo axe ${v}`);
    larg = await q.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} círculo rolagem ${larg}`);
    await q.selectOption('#f-jornada', 'OP-02'); await q.click('#nivel form.abrir button[type=submit]'); await pronto(q);
    v = await axe(q); confere(v.length === 0, `${l} ${e} jornada axe ${v}`);
    await q.click('#nivel tbody button.lk >> nth=0'); await pronto(q);
    v = await axe(q); confere(v.length === 0, `${l} ${e} execução axe ${v}`);
    larg = await q.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} execução rolagem ${larg}`);
    semErro(q); await q.close();
  }
});

await fim('painel');
