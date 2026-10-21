// Mesa: "Ligar o Telegram" (089). A pessoa da equipe aceita o termo, gera o código de uso único, o bot recebe /vincular CÓDIGO
// (aqui simulado chamando rt.receber_update no banco app_ensaio, como a função telegram faz) e a tela mostra o estado e o botão desligar.
// Casos: estado desligado com o termo, sem aceite não gera, código gerado e mostrado como texto, vínculo pelo bot, desligar com confirmação,
// termo com marcação aparece como texto, e acessibilidade (axe) em 390 e 1280, claro e escuro, sem rolagem horizontal.
import { abrir, axe, caso, confere, fim, U } from './apoio.mjs';
import { execFileSync } from 'node:child_process';
const sql = q => execFileSync('psql', ['postgresql:///app_ensaio?port=5499', '-v', 'ON_ERROR_STOP=1', '-Atc', q], { encoding: 'utf8' }).trim();
const pronta = p => p.waitForSelector('body[data-pronto="1"]', { timeout: 10000 });
const estado = p => p.textContent('#tg-estado');
const TG = 650000000 + Math.floor(Math.random() * 9000000);

const olga = sql(`select pseudonimo from rt_chave.login where auth_uid = '${U.olga}'`);
const antes = sql(`select coalesce(telegram_id::text, '') || '|' || coalesce(consentimento_art33_em::text, '') from rt_chave.identidade where pseudonimo = '${olga}'`);
const termoAntes = sql(`select valor::text from adm.parametro where chave = 'telegram.vinculo_termo'`);
function zerar() {
  sql(`delete from rt_chave.tg_codigo where pessoa = '${olga}'; delete from rt.rota_chat where chat_ref = 'tg:${TG}';
       update rt_chave.identidade set telegram_id = null, consentimento_art33_em = null where pseudonimo = '${olga}'`);
}
function restaurar() {
  zerar();
  const [tg, cons] = antes.split('|');
  if (tg) sql(`update rt_chave.identidade set telegram_id = ${+tg}, consentimento_art33_em = ${cons ? `'${cons}'` : 'now()'} where pseudonimo = '${olga}'`);
  sql(`update adm.parametro set valor = '${termoAntes.replace(/'/g, "''")}'::jsonb where chave = 'telegram.vinculo_termo'`);
}
const bot = (texto, tipo = 'private') => JSON.parse(sql(`select rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 1,
  'text', ${"'" + texto.replace(/'/g, "''") + "'"}, 'from', jsonb_build_object('id', ${TG}), 'chat', jsonb_build_object('id', ${tipo === 'private' ? TG : -100777}, 'type', '${tipo}'))), false)`));
const resposta = r => sql(`select texto from rt.fila_envio where id = ${+r.fila}`);
zerar();

let codigo = '';
try {
  await caso('desligado: mostra o termo; sem aceite, o botão não gera', async () => {
    const p = await abrir('mesa.html', 'olga'); await pronta(p);
    await p.waitForSelector('#tg-termo');
    confere((await estado(p)).includes('Desligado'), 'estado: ' + await estado(p));
    confere((await p.textContent('#tg-termo')).includes('art. 33, VIII'), 'termo sem a base legal');
    confere(await p.isDisabled('#tg-gerar'), 'gerar habilitado sem aceite');
    await p.check('#tg-aceite'); confere(!(await p.isDisabled('#tg-gerar')), 'gerar desabilitado com aceite');
    await p.uncheck('#tg-aceite'); confere(await p.isDisabled('#tg-gerar'), 'gerar habilitado depois de tirar o aceite');
    const v = await axe(p); confere(v.length === 0, 'axe ' + v);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

  await caso('aceite e código: mostrado uma vez, com a instrução; o banco guarda só o hash', async () => {
    const p = await abrir('mesa.html', 'olga'); await pronta(p);
    await p.waitForSelector('#tg-aceite'); await p.check('#tg-aceite'); await p.click('#tg-gerar');
    await p.waitForSelector('#tg-codigo', { timeout: 8000 });
    codigo = (await p.textContent('#tg-codigo')).trim();
    confere(/^[0-9A-F]{8}$/.test(codigo), 'código: ' + codigo);
    confere((await p.textContent('#tg-instrucao')).includes('/vincular ' + codigo), 'instrução sem o comando');
    confere((await p.textContent('#recibos .recibo')).includes('Código gerado'), 'sem recibo');
    confere(sql(`select count(*) from rt_chave.tg_codigo where pessoa = '${olga}' and codigo_hash = encode(extensions.digest('${codigo}', 'sha256'), 'hex') and usado_em is null`) === '1', 'hash não gravado');
    confere(sql(`select count(*) from rt_chave.tg_codigo k where pessoa = '${olga}' and to_jsonb(k)::text like '%${codigo}%'`) === '0', 'código em claro no banco');
    await p.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: new URL(p.url()).origin });
    await p.click('#tg-copiar'); await p.waitForFunction(() => document.getElementById('tg-copia-st')?.textContent === 'Copiado.', null, { timeout: 5000 });
    confere(await p.evaluate(() => navigator.clipboard.readText()) === '/vincular ' + codigo, 'área de transferência diferente');
    for (const [l, e] of [[1280, 'light'], [1280, 'dark']]) {
      await p.setViewportSize({ width: l, height: 900 }); await p.emulateMedia({ colorScheme: e });
      const v = await axe(p); confere(v.length === 0, `${l} ${e} axe com código ` + v);
    }
    await p.setViewportSize({ width: 390, height: 900 });
    const v = await axe(p); confere(v.length === 0, '390 axe com código ' + v);
    const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= 390, '390 rolagem horizontal ' + larg);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

  await caso('reabrir a Mesa: o código não volta, só a validade do que está em aberto', async () => {
    const p = await abrir('mesa.html', 'olga'); await pronta(p);
    await p.waitForSelector('#tg-aberto');
    confere(!(await p.textContent('#b-telegram')).includes(codigo), 'código reapareceu');
    confere(await p.$('#tg-codigo') === null, 'caixa do código sem ter gerado');
    await p.close(); });

  await caso('bot: grupo recusa sem ligar; conversa privada liga e a Mesa mostra ligado', async () => {
    const p = await abrir('mesa.html', 'olga'); await pronta(p);
    await p.waitForSelector('#tg-aceite'); await p.check('#tg-aceite'); await p.click('#tg-gerar');
    await p.waitForSelector('#tg-codigo', { timeout: 8000 }); codigo = (await p.textContent('#tg-codigo')).trim();
    const g = bot('/vincular ' + codigo, 'group');
    confere(!g.vinculou && resposta(g).includes('conversa privada'), 'grupo: ' + resposta(g));
    await p.check('#tg-aceite'); await p.click('#tg-gerar');
    await p.waitForFunction(c => { const t = document.getElementById('tg-codigo')?.textContent; return t && t !== c; }, codigo, { timeout: 8000 });
    codigo = (await p.textContent('#tg-codigo')).trim();
    const r = bot('/vincular ' + codigo);
    confere(r.vinculou && resposta(r).startsWith('Pronto, Olga'), 'vínculo: ' + resposta(r));
    await p.click('#tg-conferir');
    await p.waitForFunction(() => document.getElementById('tg-estado')?.textContent.includes('Ligado desde'), null, { timeout: 8000 });
    confere(await p.isVisible('#tg-desligar'), 'sem botão desligar');
    confere(!(await p.textContent('#b-telegram')).includes(String(TG)), 'número do Telegram na tela');
    confere(sql(`select telegram_id = ${TG} and consentimento_art33_em is not null from rt_chave.identidade where pseudonimo = '${olga}'`) === 't', 'identidade sem vínculo');
    const q = bot('/quadro'); confere(q.pessoa === olga, 'bot não reconhece a Olga');
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

  await caso('ligado: axe em 390 e 1280, claro e escuro, sem rolagem horizontal', async () => {
    for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light'], [390, 'dark']]) {
      const p = await abrir('mesa.html', 'olga', { largura: l, esquema: e }); await pronta(p);
      await p.waitForSelector('#tg-desligar');
      let v = await axe(p); confere(v.length === 0, `${l} ${e} axe ` + v);
      await p.click('#tg-desligar'); await p.waitForSelector('#tg-sim');
      v = await axe(p); confere(v.length === 0, `${l} ${e} axe na confirmação ` + v);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} rolagem horizontal ${larg}`);
      await p.click('#tg-nao'); await p.waitForSelector('#tg-desligar');
      confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); } });

  await caso('desligar com confirmação: volta a desligado e o bot não reconhece mais', async () => {
    const p = await abrir('mesa.html', 'olga'); await pronta(p);
    await p.waitForSelector('#tg-desligar'); await p.click('#tg-desligar'); await p.click('#tg-sim');
    await p.waitForFunction(() => document.getElementById('tg-estado')?.textContent.includes('Desligado'), null, { timeout: 8000 });
    confere((await p.textContent('#recibos .recibo')).includes('Telegram desligado'), 'sem recibo do desligamento');
    confere(sql(`select telegram_id is null and consentimento_art33_em is null from rt_chave.identidade where pseudonimo = '${olga}'`) === 't', 'vínculo continua');
    const r = bot('oi'); confere(r.pessoa === null && resposta(r).includes('Ligar o Telegram'), 'bot: ' + resposta(r));
    const u = bot('/vincular ' + codigo); confere(!u.vinculou && resposta(u).includes('já foi usado'), 'código usado: ' + resposta(u));
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close(); });

  await caso('termo com marcação aparece como texto', async () => {
    sql(`update adm.parametro set valor = to_jsonb('Termo de teste <img src=x onerror="window.__xss=1"> <b>sem negrito</b>'::text) where chave = 'telegram.vinculo_termo'`);
    const p = await abrir('mesa.html', 'olga'); await pronta(p); await p.waitForSelector('#tg-termo');
    confere((await p.textContent('#tg-termo')).includes('<b>sem negrito</b>'), 'termo não veio como texto');
    confere(await p.locator('#tg-termo img, #tg-termo b').count() === 0, 'termo virou HTML');
    confere(await p.evaluate(() => window.__xss === undefined), 'script do termo rodou');
    await p.close(); });
} finally { restaurar(); }
await fim('mesa telegram');
