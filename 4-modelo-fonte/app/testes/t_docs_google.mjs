// Teste de navegador do Google Docs como terceira saída (084), no Acervo, aba Emitidos.
// A função `google` não existe em 127.0.0.1:3398 no ensaio: a rota é interceptada e, para docs_criar, faz no banco o que a função faz
// (doc.gdoc_tomar e doc.gdoc_concluir, pela chave de serviço) e devolve o que o contrato promete.
import { abrir, axe, caso, confere, fim } from './apoio.mjs';
import { execFileSync } from 'node:child_process';

const PG = 'postgresql:///app_ensaio?port=5499';
const sql = q => execFileSync('psql', [PG, '-v', 'ON_ERROR_STOP=1', '-Atc', q], { encoding: 'utf8' }).trim().split('\n').filter(l => !/^(INSERT|UPDATE|DELETE) \d/.test(l))[0] ?? '';
const ALFA = sql("select id from org.empresa where nome = 'Empresa Alfa'");
const n = Date.now().toString(36);
const semRecurso = es => es.filter(e => !/Failed to load resource/.test(e));
sql(`update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema'`);

// emissão de ensaio da Empresa Alfa com PDF de verdade (cópia de um PDF emitido) e HTML
function emitir(titulo) {
  const ped = sql(`insert into doc.pedido (tipo, marca, empresa, conteudo, situacao) values ('contrato-cliente', (select min(id) from doc.marca), '${ALFA}', jsonb_build_object('titulo', '${titulo}'), 'emitido') returning id`);
  const em = sql(`insert into doc.emissao (pedido, situacao, paginas, registro, worker) values (${ped}, 'emitido', 1, '{}', 'teste-navegador') returning id`);
  sql(`insert into doc.arquivo select ${em}, 'pdf', a.conteudo, a.sha256, a.bytes from doc.arquivo a join doc.emissao e on e.id = a.emissao where a.formato = 'pdf' and e.worker is distinct from 'teste-navegador' and substring(a.conteudo from 1 for 5) = '\\x255044462d'::bytea and a.bytes > 900 order by a.emissao desc limit 1`);
  sql(`insert into doc.arquivo values (${em}, 'html', convert_to('<h1>${titulo}</h1>', 'UTF8'), 'h', 20)`);
  return em;
}
const COM_DOC = emitir('Contrato com Doc ' + n), SEM_DOC = emitir('Contrato sem Doc ' + n), FORA = emitir('Contrato Google fora ' + n);
const LINK = `https://docs.google.com/document/d/docEnsaioPronto${n}/edit`;
sql(`select doc.gdoc_tomar(${COM_DOC}, null)`); sql(`select doc.gdoc_concluir(${COM_DOC}, 'docEnsaioPronto${n}', '${LINK}')`);

async function google(p, modo) {
  const chamadas = [];
  await p.route('http://127.0.0.1:3398/google', async r => {
    const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
    if (r.request().method() === 'OPTIONS') return r.fulfill({ status: 204, headers: cors });
    const corpo = JSON.parse(r.request().postData() || '{}'); chamadas.push(corpo);
    if (corpo.acao === 'docs_criar' && modo === 'ok') {
      const id = `docEnsaioNovo${n}x${corpo.emissao}`, link = `https://docs.google.com/document/d/${id}/edit`;
      sql(`select doc.gdoc_tomar(${Number(corpo.emissao)}, null)`); sql(`select doc.gdoc_concluir(${Number(corpo.emissao)}, '${id}', '${link}')`);
      return r.fulfill({ status: 200, headers: cors, contentType: 'application/json', body: JSON.stringify({ emissao: corpo.emissao, id, link }) });
    }
    if (corpo.acao === 'docs_criar') {
      sql(`select doc.gdoc_tomar(${Number(corpo.emissao)}, null)`); sql(`select doc.gdoc_falhar(${Number(corpo.emissao)}, 'Google respondeu 500: ensaio')`);
      return r.fulfill({ status: 502, headers: cors, contentType: 'application/json', body: JSON.stringify({ erro: 'Google respondeu 500: ensaio; nova tentativa automática às 10:00', codigo: 502 }) });
    }
    return r.fulfill({ status: 501, headers: cors, contentType: 'application/json', body: JSON.stringify({ erro: 'ação não simulada', codigo: 501 }) });
  });
  return chamadas;
}
async function aba(p, id) { await p.click('#t-' + id); await p.waitForSelector(`#conteudo[aria-labelledby="t-${id}"]`); }
async function recibo(p, re) { await p.waitForFunction(r => [...document.querySelectorAll('.recibo')].some(d => new RegExp(r).test(d.textContent)), re.source, { timeout: 8000 }); }

await caso('aba Emitidos: link "Abrir no Google Docs" quando existe; botão "Gerar Google Doc" quando não', async () => {
  const p = await abrir('acervo.html', 'olga'); await p.waitForSelector('#resumo span'); await aba(p, 'emitidos');
  const a = await p.$(`[data-emissao="${COM_DOC}"] a[data-gdoc-link]`);
  confere(a && (await a.textContent()) === 'Abrir no Google Docs' && (await a.getAttribute('href')) === LINK, 'link do Doc ausente ou errado');
  confere((await a.getAttribute('target')) === '_blank' && /noopener/.test(await a.getAttribute('rel')), 'link sem nova aba segura');
  confere(!(await p.$(`[data-gdoc="${COM_DOC}"]`)), 'botão em documento que já tem Doc');
  confere(await p.$(`[data-gdoc="${SEM_DOC}"]`), 'sem o botão Gerar Google Doc');
  confere(!(await p.$(`[data-emissao="${SEM_DOC}"] a[data-gdoc-link]`)), 'link em documento sem Doc');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('Gerar Google Doc: chama docs_criar com a emissão e a lista passa a mostrar o link gravado no banco', async () => {
  const p = await abrir('acervo.html', 'olga'); const ch = await google(p, 'ok'); await aba(p, 'emitidos');
  await p.click(`[data-gdoc="${SEM_DOC}"]`); await recibo(p, /Google Doc gerado/);
  confere(ch.length === 1 && ch[0].acao === 'docs_criar' && ch[0].emissao === Number(SEM_DOC), 'chamada errada: ' + JSON.stringify(ch));
  await p.waitForSelector(`[data-emissao="${SEM_DOC}"] a[data-gdoc-link]`);
  confere(sql(`select google_doc_link from doc.emissao where id = ${SEM_DOC}`).startsWith('https://docs.google.com/'), 'banco sem o link');
  confere(!(await p.$(`[data-gdoc="${SEM_DOC}"]`)), 'botão continuou');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('Google fora: aviso na tela, o pedido fica na fila com nova tentativa e o botão segue disponível', async () => {
  const p = await abrir('acervo.html', 'olga'); await google(p, 'fora'); await aba(p, 'emitidos');
  await p.click(`[data-gdoc="${FORA}"]`); await recibo(p, /Google Doc não gerado: .*nova tentativa/);
  confere(sql(`select situacao || '|' || tentativas from doc.google_doc where emissao = ${FORA}`) === 'na_fila|1', 'fila não registrou a nova tentativa');
  await p.waitForFunction(id => /tentativa 1 falhou/.test(document.querySelector(`[data-emissao="${id}"]`)?.textContent || ''), FORA);
  confere(await p.$(`[data-gdoc="${FORA}"]`), 'botão sumiu depois da falha');
  confere(semRecurso(p.erros).length === 0, 'erros ' + p.erros); await p.close();
});

await caso('Google não configurado: a aba avisa e não oferece o botão', async () => {
  sql(`update adm.parametro set valor = '""' where chave = 'google.usuario_sistema'`);
  try {
    const p = await abrir('acervo.html', 'olga'); await p.waitForSelector('#resumo span'); await aba(p, 'emitidos');
    confere(/Google Docs indisponível/.test(await p.textContent('#conteudo')), 'sem aviso');
    confere(!(await p.$('[data-gdoc]')), 'botão sem Google configurado');
    confere(await p.$(`[data-emissao="${COM_DOC}"] a[data-gdoc-link]`), 'link já gerado sumiu');
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  } finally { sql(`update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema'`); }
});

await caso('acessibilidade da aba Emitidos: zero violação em 1280 claro, 1280 escuro e 390; sem rolagem horizontal', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const p = await abrir('acervo.html', 'olga', { largura: l, esquema: e }); await p.waitForSelector('#resumo span'); await aba(p, 'emitidos');
    const v = await axe(p); confere(v.length === 0, `${l} ${e} axe ${v}`);
    const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `rolagem horizontal ${larg}`);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  }
});

await fim('docs google');
