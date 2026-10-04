// Teste de navegador do módulo Acervo (acervo.html). Ensaio local: a função do servidor `google` não existe em 127.0.0.1:3398;
// quando o caso precisa dela, a rota é interceptada e devolve o que o contrato promete.
import { abrir, axe, caso, confere, fim } from './apoio.mjs';
import { execFileSync } from 'node:child_process';

const PG = 'postgresql:///app_ensaio?port=5499';
const sql = q => execFileSync('psql', [PG, '-Atc', q], { encoding: 'utf8' }).trim();
const ALFA = sql("select id from org.empresa where nome = 'Empresa Alfa'");
const n = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
const DRIVE_ID = 'arquivoDeTeste123456';
const semRecurso = es => es.filter(e => !/Failed to load resource/.test(e));

function cnpj() {
  const b = Array.from({ length: 8 }, () => Math.floor(Math.random() * 10)).concat([0, 0, 0, 1]);
  const dv = s => { const w = s.length === 12 ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2] : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const r = s.reduce((a, d, i) => a + d * w[i], 0) % 11; return r < 2 ? 0 : 11 - r; };
  const d = [...b, dv(b)]; d.push(dv(d)); const s = d.join('');
  return `${s.slice(0, 2)}.${s.slice(2, 5)}.${s.slice(5, 8)}/${s.slice(8, 12)}-${s.slice(12)}`;
}
const CNPJ = cnpj();

// função do servidor `google` simulada: drive_enviar sempre; drive_mover só quando pedido (ação proposta, fora do contrato atual)
async function google(p, opc = {}) {
  const chamadas = [];
  await p.route('http://127.0.0.1:3398/google', async r => {
    const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
    if (r.request().method() === 'OPTIONS') return r.fulfill({ status: 204, headers: cors });
    const corpo = JSON.parse(r.request().postData() || '{}'); chamadas.push(corpo);
    if (corpo.acao === 'drive_enviar') return r.fulfill({ status: 200, headers: cors, contentType: 'application/json', body: JSON.stringify({ id: DRIVE_ID, link: 'https://drive.google.com/x' }) });
    if (corpo.acao === 'drive_mover' && opc.mover) return r.fulfill({ status: 200, headers: cors, contentType: 'application/json', body: '{"ok":true}' });
    return r.fulfill({ status: 501, headers: cors, contentType: 'application/json', body: JSON.stringify({ erro: 'ação ainda não implantada', codigo: 'acao' }) });
  });
  return chamadas;
}
async function subir(p, nome, texto, mime = 'text/plain') {
  const antes = await p.$$eval('.passo', d => d.length);
  await p.setInputFiles('#arquivos', { name: nome, mimeType: mime, buffer: Buffer.from(texto) });
  await p.click('#b-subir');
  await p.waitForFunction(([t, k]) => { const ds = document.querySelectorAll('.passo'); return ds.length > k && ds[0].querySelector('.t')?.textContent === t && !ds[0].classList.contains('and'); }, [nome, antes], { timeout: 10000 });
  await p.waitForFunction(() => !document.getElementById('b-subir').disabled || !document.getElementById('arquivos').value);
  await p.waitForLoadState('networkidle');
  return p.$eval('.passo', d => d.textContent);
}
async function aba(p, id) { await p.click('#t-' + id); await p.waitForSelector(`#conteudo[aria-labelledby="t-${id}"]`); }
async function recibo(p, re) { await p.waitForFunction(r => [...document.querySelectorAll('.recibo')].some(d => new RegExp(r).test(d.textContent)), re.source, { timeout: 8000 }); }

await caso('olga entra e vê o acervo da Empresa Alfa com dados reais', async () => {
  const p = await abrir('acervo.html', 'olga');
  await p.waitForSelector('#resumo span');
  confere((await p.textContent('#imts-barra')).includes('Olga'), 'barra sem o nome');
  confere(await p.getAttribute('#imts-barra a[aria-current="page"]', 'href') === 'acervo.html', 'menu sem Acervo marcado');
  confere((await p.textContent('#cab-sub')).includes('Empresa Alfa'), 'empresa não aparece');
  await aba(p, 'pastas'); confere((await p.textContent('#conteudo')).includes('01 Societário'), 'árvore de pastas não veio do banco');
  await aba(p, 'marca'); confere((await p.textContent('#conteudo')).includes('pacote que vale hoje'), 'marca não veio do banco');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('envio completo: hash, Drive (simulado), registro, classificação, local confirmado', async () => {
  const p = await abrir('acervo.html', 'olga'); const ch = await google(p, { mover: true });
  const nome = `cartao_cnpj_${n}.txt`;
  const reg = await subir(p, nome, `COMPROVANTE DE INSCRIÇÃO E DE SITUAÇÃO CADASTRAL\nNÚMERO DE INSCRIÇÃO\nCNPJ ${CNPJ}\nemitido no ensaio ${n}\n`);
  confere(/Registrado/.test(reg) && /Cartão CNPJ/.test(reg) && /Guardado em 01 Societário/.test(reg), 'registro: ' + reg);
  const env = ch.find(c => c.acao === 'drive_enviar');
  confere(env && env.empresa === ALFA && env.pasta === '00' && env.nome === nome && env.conteudo.length > 10, 'chamada drive_enviar errada');
  const linha = sql(`select situacao || '|' || drive_id || '|' || tipo from acervo.arquivo where nome_original = '${nome}'`);
  confere(linha === `organizado|${DRIVE_ID}|cartao-cnpj`, 'banco: ' + linha);
  confere(sql(`select count(*) from acervo.campo f join acervo.arquivo a on a.id = f.arquivo where a.nome_original = '${nome}' and f.chave = 'cnpj'`) === '1', 'CNPJ não proposto');
  await aba(p, 'arquivos'); confere((await p.textContent('#conteudo')).includes('Cartão CNPJ'), 'arquivo não aparece na lista');
  // mesmo arquivo de novo: duplicado, não sobe
  const dup = await subir(p, nome, `COMPROVANTE DE INSCRIÇÃO E DE SITUAÇÃO CADASTRAL\nNÚMERO DE INSCRIÇÃO\nCNPJ ${CNPJ}\nemitido no ensaio ${n}\n`);
  confere(/Já está no acervo/.test(dup), 'duplicado não detectado: ' + dup);
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('Drive indisponível: aviso na tela e registro não feito', async () => {
  const p = await abrir('acervo.html', 'olga');
  const nome = `sem_drive_${n}.txt`;
  const reg = await subir(p, nome, 'arquivo sem Drive ' + n);
  confere(/Envio ao Drive indisponível/.test(reg) && /não foi registrado/.test(reg), 'aviso: ' + reg);
  confere(sql(`select count(*) from acervo.arquivo where nome_original = '${nome}'`) === '0', 'registrou sem Drive');
  confere(semRecurso(p.erros).length === 0, 'erros ' + p.erros); await p.close();
});

await caso('triagem: arquivo não reconhecido, classificado por pessoa; mover degrada e depois conclui', async () => {
  const p = await abrir('acervo.html', 'olga'); await google(p, { mover: false });
  const nome = `anotacoes_${n}.bin`;
  const reg = await subir(p, nome, 'bytes ' + n, 'application/octet-stream');
  confere(/Na triagem/.test(reg), 'não foi para a triagem: ' + reg);
  const id = sql(`select id from acervo.arquivo where nome_original = '${nome}' and situacao = 'triagem'`); confere(id, 'banco sem triagem');
  await aba(p, 'triagem');
  await p.selectOption('#tp-' + id, 'certidao'); await p.click(`[data-classificar="${id}"]`);
  await recibo(p, /Classificado como .*Fica na entrada/);
  confere(sql(`select situacao || '|' || tipo || '|' || pasta from acervo.arquivo where id = ${id}`) === 'entrada|certidao|02', 'classificação não gravou');
  await aba(p, 'arquivos'); await p.waitForSelector(`[data-mover="${id}"]`);
  await p.unroute('http://127.0.0.1:3398/google'); await google(p, { mover: true });
  await p.click(`[data-mover="${id}"]`); await recibo(p, /Guardado em 02 Fiscal/);
  confere(sql(`select situacao from acervo.arquivo where id = ${id}`) === 'organizado', 'local não confirmado');
  confere((await p.textContent(`[data-arquivo="${id}"]`)).includes('organizado'), 'tela não mostra organizado');
  confere(semRecurso(p.erros).length === 0, 'erros ' + p.erros); await p.close();
});

await caso('dado da empresa: olga não aprova; lia aprova (1 de 2); administração recusa com motivo', async () => {
  const campo = sql(`select f.id from acervo.campo f join acervo.arquivo a on a.id = f.arquivo where a.nome_original = 'cartao_cnpj_${n}.txt' and f.chave = 'cnpj'`);
  confere(campo, 'sem campo do caso anterior');
  let p = await abrir('acervo.html', 'olga'); await aba(p, 'dados');
  if (await p.$(`[data-campo="${campo}"][data-d="aprovado"]`)) { await p.click(`[data-campo="${campo}"][data-d="aprovado"]`); await recibo(p, /Recusado: sem acesso de aprovar/); }
  else confere((await p.textContent(`[data-campo-item="${campo}"]`)).includes('divergente'), 'campo sumiu');
  confere(sql(`select jsonb_array_length(decisoes) from acervo.campo where id = ${campo}`) === '0', 'olga decidiu');
  await p.close();
  p = await abrir('acervo.html', 'lia');
  // se sobrou outro CNPJ proposto de execução anterior, a divergência é resolvida pela tela escolhendo o valor deste ensaio
  if (sql(`select situacao from acervo.campo where id = ${campo}`) === 'divergente') {
    const dv = sql(`select id from acervo.divergencia where empresa = '${ALFA}' and chave = 'cnpj' and situacao = 'aberta'`);
    await aba(p, 'divergencias'); await p.check(`input[name="dv-${dv}"][value="${campo}"]`);
    await p.fill('#dm-' + dv, 'valor do cartão CNPJ mais recente'); await p.click(`[data-divergencia="${dv}"]`); await recibo(p, /Valor escolhido/);
  }
  await aba(p, 'dados'); await p.click(`[data-campo="${campo}"][data-d="aprovado"]`); await recibo(p, /Aprovação registrada/);
  confere((await p.textContent(`[data-campo-item="${campo}"]`)).includes('1 de 2 aprovações'), 'tela sem 1 de 2');
  confere(sql(`select situacao || '|' || jsonb_array_length(decisoes) from acervo.campo where id = ${campo}`) === 'proposto|1', 'banco sem a aprovação');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  p = await abrir('acervo.html', 'admin');
  if (await p.$('#imts-empresa')) { await p.selectOption('#imts-empresa', ALFA); await p.waitForFunction(() => document.getElementById('cab-sub').textContent.includes('Empresa Alfa')); }
  await aba(p, 'dados'); await p.waitForSelector(`[data-campo="${campo}"]`);
  await p.fill('#mo-' + campo, 'CNPJ de ensaio, não é o da empresa'); await p.click(`[data-campo="${campo}"][data-d="recusado"]`); await recibo(p, /Recusa registrada/);
  confere(sql(`select situacao from acervo.campo where id = ${campo}`) === 'recusado', 'recusa não gravou');
  confere(!(await p.$(`[data-campo-item="${campo}"]`)), 'campo recusado continua na tela');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('modelo de documento: vira minuta, lia aprova, olga emite pela minuta', async () => {
  let p = await abrir('acervo.html', 'olga'); await google(p, { mover: true });
  const nome = `minuta_contrato_${n}.txt`;
  const reg = await subir(p, nome, `MINUTA DE CONTRATO DE PRESTAÇÃO DE SERVIÇOS ${n}\nCLÁUSULA PRIMEIRA DO OBJETO\n1.1 O objeto é o ensaio.\na) primeira alínea\nCLÁUSULA SEGUNDA DO PRAZO\n2.1 Doze meses.\n`);
  confere(/virou minuta/.test(reg), 'minuta não derivada: ' + reg);
  const mi = sql(`select m.id from doc.minuta m join acervo.arquivo a on a.id = m.arquivo where a.nome_original = '${nome}'`); confere(mi, 'banco sem minuta');
  await p.close();
  p = await abrir('acervo.html', 'lia'); await aba(p, 'modelos'); await p.waitForSelector(`[data-minuta="${mi}"]`);
  if (!(await p.inputValue('#mt-' + mi))) await p.selectOption('#mt-' + mi, 'contrato-cliente');
  await p.click(`[data-minuta="${mi}"][data-d="aprovado"]`); await recibo(p, /Minuta aprovada/);
  confere(sql(`select situacao from doc.minuta where id = ${mi}`) === 'aprovada', 'minuta não aprovada');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  p = await abrir('acervo.html', 'olga'); await aba(p, 'modelos'); await p.waitForSelector(`[data-emitir="${mi}"]`);
  const antes = Number(sql(`select count(*) from doc.evento where tipo = 'pedido_pela_minuta' and dados->>'minuta' = '${mi}'`));
  await p.click(`[data-emitir="${mi}"]`); await recibo(p, /Pedido na fila/);
  confere(Number(sql(`select count(*) from doc.evento where tipo = 'pedido_pela_minuta' and dados->>'minuta' = '${mi}'`)) === antes + 1, 'pedido não registrado');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('pasta do Drive associada pela tela; criar pasta degrada com aviso', async () => {
  const p = await abrir('acervo.html', 'olga'); await aba(p, 'pastas');
  const cod = 'pastaEnsaio' + n.replace(/[^A-Za-z0-9]/g, '');
  await p.selectOption('#fp-pasta', '06'); await p.fill('#fp-link', 'https://drive.google.com/drive/folders/' + cod); await p.click('#f-pasta button');
  await recibo(p, /Pasta associada/);
  confere(sql(`select drive_id from acervo.pasta_drive where empresa = '${ALFA}' and pasta = '06'`) === cod, 'pasta não gravou');
  confere(await p.$(`[data-pasta="06"] a[href*="${cod}"]`), 'tela sem o link da pasta');
  const criar = await p.$('[data-criar-pasta]');
  if (criar) { await criar.click(); await recibo(p, /Criar pasta no Drive indisponível/); }
  confere(semRecurso(p.erros).length === 0, 'erros ' + p.erros); await p.close();
});

await caso('cliente (externo) é recusado', async () => {
  const p = await abrir('acervo.html', 'clara'); await p.waitForURL(/(index|portal)\.html/, { timeout: 5000 });
  confere(!/acervo\.html/.test(p.url()), 'cliente ficou no acervo'); await p.close();
});

await caso('acessibilidade: zero violação em 1280 claro (todas as abas), 1280 escuro e 390 claro; sem rolagem horizontal', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const p = await abrir('acervo.html', 'lia', { largura: l, esquema: e }); await p.waitForSelector('#resumo span');
    const abas = l === 1280 && e === 'light' ? ['arquivos', 'triagem', 'dados', 'divergencias', 'marca', 'modelos', 'pastas'] : ['arquivos', 'modelos', 'pastas'];
    for (const a of abas) { await aba(p, a); const v = await axe(p); confere(v.length === 0, `${l} ${e} ${a} axe ${v}`);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${a} rolagem horizontal ${larg}`); }
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  }
});

await fim('acervo');
