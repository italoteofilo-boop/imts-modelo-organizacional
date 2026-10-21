import { abrir, axe, caso, confere, fim, BASE, U } from './apoio.mjs';
import { execFileSync } from 'node:child_process';
const sql = q => execFileSync('psql', ['postgresql:///app_ensaio?port=5499', '-v', 'ON_ERROR_STOP=1', '-Atc', q], { encoding: 'utf8' }).trim();
const pronta = p => p.waitForSelector('body[data-pronto="1"]', { timeout: 10000 });
const titulo = 'Conferir planilha de entregas ' + Date.now().toString(36);
const cartao = (p, t) => p.locator('#grade .cartao', { hasText: t });
async function recibo(p, txt) { await p.waitForFunction(t => document.querySelector('#recibos .recibo')?.textContent.includes(t), txt, { timeout: 8000 }); return p.textContent('#recibos .recibo'); }

await caso('olga vê o próprio quadro com dados reais e a etiqueta assistida', async () => {
  const p = await abrir('mesa.html', 'olga'); await pronta(p);
  confere((await p.textContent('#imts-barra')).includes('Olga'), 'barra sem nome');
  confere(await cartao(p, 'O que iniciou a entrega?').count() >= 1, 'cartão de decisão ausente');
  confere(await p.locator('#grade .etq.assistida').count() >= 1, 'sem etiqueta assistida');
  confere(!(await p.textContent('#grade')).includes('(assistida:'), 'título com o sufixo bruto');
  confere((await p.textContent('#resumo')).includes('Operações'), 'resumo sem círculo');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('olga cria avulsa, move para fazendo e delega à Lia', async () => {
  const p = await abrir('mesa.html', 'olga'); await pronta(p);
  await p.fill('#texto', titulo); await p.click('#captura button[type=submit]');
  await recibo(p, 'Criar'); confere((await p.textContent('#recibos .recibo .tipo')) === 'Feito', 'criação recusada: ' + await p.textContent('#recibos .recibo'));
  await cartao(p, titulo).waitFor();
  confere(await p.locator(`.celula[data-col="a_fazer"] .cartao:has-text("${titulo}")`).count() === 1, 'não está em a fazer');
  await cartao(p, titulo).click(); await p.click('#foco [data-mover="fazendo"]');
  await p.locator(`.celula[data-col="fazendo"] .cartao:has-text("${titulo}")`).waitFor({ timeout: 8000 });
  await p.selectOption('#f-para', { label: 'Lia Líder · Líder do círculo' }); await p.click('#f-delegar');
  await recibo(p, 'Delegar'); confere((await p.textContent('#recibos .recibo .tipo')) === 'Feito', 'delegação recusada: ' + await p.textContent('#recibos .recibo'));
  await p.waitForFunction(t => [...document.querySelectorAll('#grade .cartao')].some(c => c.textContent.includes(t) && c.textContent.includes('aguardando aceite de Lia')), titulo);
  const v = await axe(p); confere(v.length === 0, 'axe com foco aberto ' + v);
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('lia aceita o pedido e conclui', async () => {
  const p = await abrir('mesa.html', 'lia'); await pronta(p);
  const item = p.locator('#precisa button', { hasText: titulo }); await item.waitFor();
  confere((await item.textContent()).includes('aceitar ou recusar'), 'pedido sem aceite');
  await item.click(); await p.click('#f-aceitar');
  await p.waitForFunction(t => [...document.querySelectorAll('#grade .cartao')].some(c => c.textContent.includes(t) && c.textContent.includes('delegada a você por Olga')), titulo, { timeout: 8000 });
  await p.click('#f-concluir');
  await p.locator(`.celula[data-col="feito"] .cartao:has-text("${titulo}")`).waitFor({ timeout: 8000 });
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('lia vê o círculo com a carga (só para quem aprova)', async () => {
  const p = await abrir('mesa.html', 'lia'); await pronta(p);
  await p.click('#aba-circulo'); confere(await p.isVisible('#b-carga'), 'carga oculta');
  confere((await p.textContent('#carga')).includes('Olga'), 'carga sem Olga');
  confere(await p.locator('#grade .cartao[data-ro]').count() >= 1, 'quadro do círculo vazio');
  const v = await axe(p); confere(v.length === 0, 'axe ' + v); await p.close(); });

await caso('olga: círculo sem carga e filtro por jornada', async () => {
  const p = await abrir('mesa.html', 'olga'); await pronta(p);
  await p.click('#aba-circulo'); confere(!(await p.isVisible('#b-carga')), 'carga visível para quem não aprova');
  await p.click('#aba-jornada'); confere(await p.isVisible('#sel-jornada'), 'seletor de jornada oculto');
  await p.selectOption('#sel-jornada', 'OP-02');
  const ts = await p.$$eval('#grade .cartao', a => a.map(x => x.textContent));
  confere(ts.length >= 1 && ts.every(t => t.includes('OP-02')), 'filtro de jornada: ' + ts.length); await p.close(); });

await caso('iniciar jornada OP-02 pelo catálogo cria execução e cartão', async () => {
  const p = await abrir('mesa.html', 'olga'); await pronta(p);
  const ops = await p.$$eval('#ini-jornada option', o => o.map(x => x.value));
  confere(ops.includes('OP-02') && ops.every(v => v.startsWith('OP-')), 'opções: ' + ops);
  const antes = await p.locator('#grade .cartao', { hasText: 'OP-02' }).count();
  await p.selectOption('#ini-jornada', 'OP-02'); await p.click('#ini-btn');
  const r = await recibo(p, 'OP-02'); confere(r.startsWith('Feito') && r.includes('Execução'), 'recibo: ' + r);
  await p.waitForFunction(n => [...document.querySelectorAll('#grade .cartao')].filter(c => c.textContent.includes('OP-02')).length > n, antes, { timeout: 8000 });
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('captura sugere a jornada existente e permite criar avulsa', async () => {
  const p = await abrir('mesa.html', 'olga'); await pronta(p);
  const t = 'Registrar reclamação do cliente e o contrato ' + Date.now().toString(36);
  await p.fill('#texto', t); await p.click('#captura button[type=submit]');
  await p.waitForSelector('#sugestao:not([hidden])', { timeout: 8000 });
  const box = await p.textContent('#sugestao'); confere(box.includes('OP-04') && box.includes('Iniciar OP-04'), 'sugestão: ' + box);
  confere((await recibo(p, 'Criar')).includes('já existe na jornada'), 'captura não parou na sugestão');
  confere(await cartao(p, t).count() === 0, 'criou sem confirmar');
  const v = await axe(p); confere(v.length === 0, 'axe com sugestão ' + v);
  await p.click('#s-avulsa'); await cartao(p, t).waitFor({ timeout: 8000 });
  confere(await p.isHidden('#sugestao'), 'sugestão ficou aberta');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

// ---------- cartão de revisão do agente de IA (086): o rascunho entra como texto puro ----------
const marcaIA = Date.now().toString(36);
const RASCUNHO = `Classificação proposta ${marcaIA}\nGravidade: média\n<img src=x onerror="window.__xss=1"> <b>não é negrito</b>\nRisco legal: baixo`;
const lit = t => "'" + t.replace(/'/g, "''") + "'";
function semearRevisao() {
  return sql(`with base as (
      select c.* from rt.cartao c join rt_chave.login l on l.pseudonimo = c.dono
       where l.auth_uid = '${U.olga}' and c.tipo = 'fluxo' and c.tarefa is not null and c.instancia is not null order by c.id desc limit 1),
    novo as (
      insert into rt.cartao (tipo, titulo, circulo, instancia, no, jornada, etapa, tarefa, papel, dono, criado_por, origem, prazo, simulado, empresa)
      select 'fluxo', 'Revisar rascunho da IA: teste ${marcaIA}', circulo, instancia, no, jornada, etapa, tarefa, papel, dono, dono, 'agente', now() + interval '1 day', false, empresa from base
      returning *),
    fila as (
      insert into rt.fila_ia (instancia, no, tarefa, circulo, jornada, etapa, prompt, na_fila, estado, tentativas, resultado, provedor, modelo, tokens_entrada, tokens_saida, desfecho, cartao, iniciado_em, concluido_em)
      select instancia, no, tarefa, circulo, jornada, etapa, 'prompt de ensaio', true, 'feito', 1, ${lit(RASCUNHO)}, 'anthropic', 'modelo-de-ensaio', 10, 20, 'revisao', id, now(), now() from novo
      returning cartao)
    select cartao from fila`);
}
const limparRevisao = id => sql(`delete from rt.fila_ia where cartao = ${+id}; delete from rt.cartao where id = ${+id}`);
let cartaoIA = null;
try { cartaoIA = semearRevisao(); } catch (e) { console.log('     (semente do cartão de revisão falhou: ' + e.message + ')'); }
const tituloIA = `Revisar rascunho da IA: teste ${marcaIA}`;
async function abrirRevisao(p) { await cartao(p, tituloIA).click(); await p.waitForSelector('#f-rasc-texto', { timeout: 8000 }); }

await caso('cartão de revisão da IA mostra o rascunho como texto puro, com rótulo e botão copiar', async () => {
  confere(cartaoIA, 'sem cartão semeado');
  const p = await abrir('mesa.html', 'olga'); await pronta(p);
  await p.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: BASE.replace(/\/$/, '') });
  confere((await cartao(p, tituloIA).textContent()).includes('rascunho da IA'), 'cartão sem a etiqueta de IA');
  await abrirRevisao(p);
  const txt = await p.textContent('#f-rasc-texto'); confere(txt === RASCUNHO, 'texto diferente: ' + JSON.stringify(txt));
  confere(await p.locator('#f-rasc-texto img, #f-rasc-texto b').count() === 0, 'rascunho virou HTML');
  confere(await p.evaluate(() => window.__xss === undefined), 'script do rascunho rodou');
  const aviso = await p.textContent('#f-rasc-aviso'); confere(aviso.includes('Gerado por IA') && aviso.includes('revisão'), 'rótulo: ' + aviso);
  confere((await p.textContent('#f-rasc')).includes('modelo-de-ensaio'), 'sem provedor e modelo');
  await p.click('#f-copiar'); await p.waitForFunction(() => document.getElementById('f-rasc-st')?.textContent === 'Copiado.', null, { timeout: 5000 });
  confere(await p.evaluate(() => navigator.clipboard.readText()) === RASCUNHO, 'área de transferência diferente');
  const v = await axe(p); confere(v.length === 0, 'axe com rascunho ' + v);
  await p.click('#f-fechar');
  const chamadas = []; p.on('request', r => { if ((r.postData() || '').includes('agente_ia_rascunho')) chamadas.push(r.url()); });
  await cartao(p, 'O que iniciou a entrega?').first().click(); await p.waitForSelector('#foco:not([hidden])');
  await p.waitForTimeout(300); confere(!(await p.$('#f-rasc')) && chamadas.length === 0, 'cartão comum com seção de rascunho');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('líder vê o rascunho pelo quadro do círculo', async () => {
  confere(cartaoIA, 'sem cartão semeado');
  const p = await abrir('mesa.html', 'lia'); await pronta(p);
  await p.click('#aba-circulo'); await abrirRevisao(p);
  confere(await p.textContent('#f-rasc-texto') === RASCUNHO, 'líder sem o rascunho');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

await caso('rascunho da IA: axe em 390 e 1280, claro e escuro, sem rolagem horizontal', async () => {
  confere(cartaoIA, 'sem cartão semeado');
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light'], [390, 'dark']]) {
    const p = await abrir('mesa.html', 'olga', { largura: l, esquema: e }); await pronta(p);
    if (l === 390) { await p.click('#colnav button[data-col="a_fazer"]'); }
    await abrirRevisao(p);
    const v = await axe(p); confere(v.length === 0, `${l} ${e} axe ` + v);
    const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} rolagem horizontal ${larg}`);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); } });
if (cartaoIA) limparRevisao(cartaoIA);

await caso('cliente não entra na Mesa', async () => {
  const p = await abrir('mesa.html', 'clara'); await p.waitForURL(u => !/mesa\.html/.test(u.toString()), { timeout: 8000 });
  confere(!/mesa\.html/.test(p.url()), 'ficou na mesa'); await p.close(); });

await caso('sem violação no escuro e no celular, sem rolagem horizontal', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const p = await abrir('mesa.html', 'olga', { largura: l, esquema: e }); await pronta(p);
    const v = await axe(p); confere(v.length === 0, l + e + ' axe ' + v);
    const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, l + ' rolagem horizontal ' + larg);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); } });
await fim('mesa');
