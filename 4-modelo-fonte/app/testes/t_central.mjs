// Central de atendimento: carga com a pessoa certa, dados reais da porta única, ações de ponta a ponta,
// Google (Agenda, Drive) e IA interceptados para provar o caminho completo, degradação sem eles, recusa e acessibilidade.
import { abrir, axe, caso, confere, fim, token, U } from './apoio.mjs';
import { execFileSync } from 'node:child_process'; import crypto from 'node:crypto'; import fs from 'node:fs';

const MARCA = Date.now().toString(36);
const ALFA = 'Empresa Alfa';
const TRANSCRICAO = 'Rui: bom dia, Clara. Clara: o relatório de setembro não abre. Rui: a Operações reenvia o arquivo até sexta. Clara: combinado. Decisão: reenviar o relatório em PDF.';
const ignoraRede = m => /Failed to load resource|ERR_CONNECTION_REFUSED|127\.0\.0\.1:3398/.test(m);

// Funções do servidor simuladas (Google e IA). Guarda o que a página pediu.
async function servidor(p) {
  const pedidos = [];
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
  const responde = (r, corpo) => r.fulfill({ status: 200, headers: { ...cors, 'Content-Type': 'application/json' }, body: JSON.stringify(corpo) });
  await p.route('http://127.0.0.1:3398/google', async r => {
    if (r.request().method() === 'OPTIONS') return r.fulfill({ status: 204, headers: cors });
    const c = r.request().postDataJSON(); pedidos.push({ f: 'google', ...c });
    if (c.acao === 'agenda_evento') return responde(r, { evento_id: 'ev-' + MARCA + '-' + pedidos.length, link: 'https://meet.google.com/abc-defg-hij' });
    if (c.acao === 'agenda_cancelar') return responde(r, { ok: true });
    if (c.acao === 'drive_ler') return responde(r, { nome: 'transcricao-' + MARCA + '.txt', mime: 'text/plain', texto: TRANSCRICAO });
    if (c.acao === 'drive_enviar') return responde(r, { id: 'arq' + MARCA, link: 'https://drive.google.com/file/d/arq' + MARCA + '/view' });
    return r.fulfill({ status: 400, headers: cors, body: JSON.stringify({ erro: 'ação desconhecida' }) });
  });
  await p.route('http://127.0.0.1:3398/ia', async r => {
    if (r.request().method() === 'OPTIONS') return r.fulfill({ status: 204, headers: cors });
    const c = r.request().postDataJSON(); pedidos.push({ f: 'ia', ...c });
    return responde(r, { ata: { resumo: 'Reunião sobre o relatório de setembro que não abria. Ficou combinado o reenvio. ' + MARCA, decisoes: ['Reenviar o relatório em PDF'],
      encaminhamentos: [{ descricao: 'Reenviar relatório de setembro ' + MARCA, responsavel: 'Operações · pessoa', prazo: 5 }] } });
  });
  return pedidos;
}
// leitura direta pela porta única (fora do navegador), para conferir o banco
async function porta(quem, fn, args, emp) {
  const h = { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token(U[quem]) }; if (emp) h['x-empresa'] = emp;
  const r = await fetch('http://127.0.0.1:3399/rpc/imts', { method: 'POST', headers: h, body: JSON.stringify({ p_fn: fn, p_args: args }) });
  return r.json();
}
const empAlfa = async () => (await porta('rui', 'rt.quem_sou', {})).empresas.find(e => e.nome === ALFA).id;
async function semErros(p, ignora) { const e = p.erros.filter(m => !(ignora && ignora(m))); confere(e.length === 0, 'erros de console: ' + e.join(' | ')); }
const carregada = p => p.waitForSelector('#resumo span');
async function aba(p, nome) { await p.click('#t-' + nome); await p.waitForSelector(`#t-${nome}[aria-selected="true"]`); }
async function recibo(p, texto) {
  try { await p.waitForSelector(`.recibo:has-text("${texto}")`, { timeout: 8000 }); }
  catch (e) { throw new Error(`recibo "${texto}" não apareceu; na tela: ` + (await p.$$eval('.recibo', r => r.map(x => x.textContent))).join(' | ')); }
}

await caso('rui (Relações) abre a Central com os pedidos de clara e a oportunidade de paulo', async () => {
  const p = await abrir('central.html', 'rui'); await carregada(p);
  confere((await p.textContent('#imts-barra')).includes('Rui'), 'barra sem o nome');
  confere(await p.isVisible('#imts-barra a[aria-current="page"]:has-text("Central")'), 'módulo não marcado na barra');
  const txt = await p.textContent('#conteudo');
  confere(txt.includes('Prefeitura Exemplo') && txt.includes('Clara Cliente'), 'pedidos de clara ausentes');
  confere(!(await p.content()).includes('Atuando como'), 'sobrou o seletor de persona');
  await aba(p, 'parceiros');
  confere((await p.textContent('#conteudo')).includes('Representante Regional Exemplo'), 'oportunidade de paulo ausente');
  const v = await axe(p); confere(v.length === 0, 'axe ' + v); await semErros(p); await p.close();
});

await caso('encaminhar, responder e concluir encaminhamento gravam no banco e aparecem', async () => {
  const p = await abrir('central.html', 'rui'); await carregada(p);
  const art = p.locator('article[data-pedido]').filter({ hasText: 'Clara Cliente' }).first();
  const id = Number(await art.getAttribute('data-pedido'));
  const desc = 'Verificar o acesso ' + MARCA;
  await p.fill('#nd-' + id, desc);
  const olga = await p.$eval('#nr-' + id, s => [...s.options].find(o => o.textContent.includes('Olga')).value);
  await p.selectOption('#nr-' + id, olga);
  await p.click(`[data-encaminhar="${id}"]`); await recibo(p, 'Encaminhado');
  await p.waitForSelector(`article[data-pedido="${id}"] .encs li:has-text("${desc}")`);
  const resp = 'Estamos verificando ' + MARCA;
  await p.fill('#rr-' + id, resp); await p.click(`[data-responder="${id}"][data-s="em_atendimento"]`); await recibo(p, 'Resposta enviada');
  await p.waitForSelector(`article[data-pedido="${id}"]:has-text("${resp}")`);
  const ped = (await porta('rui', 'ext.painel_atendimento', { p_empresa: await empAlfa() })).pedidos.find(x => x.id === id);
  confere(ped.resposta === resp && ped.encaminhamentos.some(e => e.descricao === desc && e.situacao === 'aberto'), 'banco não confere');
  const enc = ped.encaminhamentos.find(e => e.descricao === desc).id;
  await p.fill('#ec-' + enc, 'Acesso liberado ' + MARCA); await p.click(`[data-enc="${enc}"][data-d="concluido"]`); await recibo(p, 'Encaminhamento concluído');
  await p.waitForSelector(`article[data-pedido="${id}"] .encs li:has-text("Acesso liberado ${MARCA}")`);
  await semErros(p); await p.close();
});

await caso('sala do negócio e decisão da oportunidade de paulo', async () => {
  const p = await abrir('central.html', 'rui'); await carregada(p); await aba(p, 'parceiros');
  const art = p.locator('article[data-oportunidade]').filter({ hasText: 'Representante Regional Exemplo' }).first();
  const id = Number(await art.getAttribute('data-oportunidade'));
  const msg = 'Podemos conversar na quinta? ' + MARCA;
  await p.fill('#sr-' + id, msg); await p.click(`[data-sala="${id}"]`); await recibo(p, 'Mensagem enviada');
  await p.waitForSelector(`article[data-oportunidade="${id}"] .msg.imts:has-text("${MARCA}")`);
  if (await p.isVisible('#os-' + id)) {
    await p.selectOption('#os-' + id, 'em_negociacao'); await p.click(`[data-oport="${id}"]`); await recibo(p, 'Situação registrada');
    await p.waitForSelector(`article[data-oportunidade="${id}"] .chip:has-text("em negociação")`);
  }
  await semErros(p); await p.close();
});

await caso('convite ao portal grava; publicação inválida é recusada com o motivo do banco', async () => {
  const p = await abrir('central.html', 'rui'); await carregada(p);
  await p.selectOption('#cv-cp', { label: 'Prefeitura Exemplo (cliente)' });
  await p.fill('#cv-nome', 'Fiscal Ensaio'); await p.fill('#cv-email', `fiscal.${MARCA}@exemplo.gov.br`); await p.selectOption('#cv-perfil', 'fiscal');
  await p.click('#f-convite button[type="submit"]'); await recibo(p, 'Convite registrado');
  await p.fill('#pb-emissao', '999999'); await p.click('#f-publicar button[type="submit"]'); await recibo(p, 'Não publicou: o documento e a contraparte');
  await semErros(p, m => /status of 400/.test(m)); await p.close();
});

await caso('reunião com Meet: Agenda, consentimento, transcrição do Drive, ata pela IA, rascunho e aprovação', async () => {
  const p = await abrir('central.html', 'rui'); const chamadas = await servidor(p); await carregada(p); await aba(p, 'reunioes');
  const titulo = 'Alinhamento ' + MARCA;
  await p.fill('#fr-titulo', titulo); await p.selectOption('#fr-plat', 'meet');
  await p.selectOption('#fr-cp', { label: 'Prefeitura Exemplo' });
  confere(await p.inputValue('#fr-conv') === 'clara@prefeitura-exemplo.gov.br', 'convidados não preenchidos pela contraparte: ' + await p.inputValue('#fr-conv'));
  await p.fill('#fr-conv', (await p.inputValue('#fr-conv')) + ', invalido');
  await p.check('#fr-gravar'); await p.click('#f-reuniao button[type="submit"]'); await recibo(p, 'Reunião marcada com link');
  const ev = chamadas.find(c => c.acao === 'agenda_evento');
  confere(ev && ev.titulo === titulo && ev.inicio && ev.fim && new Date(ev.fim) - new Date(ev.inicio) === 45 * 60000 && ev.convidados.length === 1 && ev.convidados[0] === 'clara@prefeitura-exemplo.gov.br' && /registro nº \d+/.test(ev.descricao), 'agenda_evento: ' + JSON.stringify(ev));
  const art = p.locator('article[data-reuniao-id]').filter({ hasText: titulo });
  const id = Number(await art.getAttribute('data-reuniao-id'));
  confere(await art.locator('a[href="https://meet.google.com/abc-defg-hij"]').count() === 1, 'link do Meet não aparece');
  const r1 = (await porta('rui', 'ext.painel_reunioes', { p_empresa: await empAlfa() })).reunioes.find(x => x.id === id);
  confere(r1.evento_id && r1.evento_id.startsWith('ev-' + MARCA) && r1.link === 'https://meet.google.com/abc-defg-hij', 'evento não gravado no banco');
  await p.fill('#cs-' + id, 'Clara Cliente'); await p.click(`[data-consent="${id}"]`); await recibo(p, 'Consentimento registrado');
  await p.fill('#tr-' + id, 'https://drive.google.com/file/d/1AbCdEfGhIjKlMnOpQrStUvWxYz/view'); await p.click(`[data-transc="${id}"]`); await recibo(p, 'Transcrição guardada');
  confere(chamadas.some(c => c.acao === 'drive_ler' && c.id === '1AbCdEfGhIjKlMnOpQrStUvWxYz'), 'drive_ler não foi chamado com o id');
  await p.click(`[data-ia="${id}"]`); await recibo(p, 'Rascunho pronto');
  const ia = chamadas.find(c => c.f === 'ia');
  confere(ia && ia.acao === 'ata_rascunho' && ia.reuniao === id && ia.transcricao === TRANSCRICAO, 'chamada da IA: ' + JSON.stringify(ia));
  confere((await p.inputValue(`#ata-${id} [data-k="resumo"]`)).includes(MARCA), 'resumo da IA não aparece');
  confere(await p.inputValue(`#ata-${id} .enc [data-k="prazo_dias"]`) === '5', 'prazo da IA não aplicado');
  await p.click(`[data-salvarata="${id}"]`); await recibo(p, 'Rascunho salvo');
  await p.waitForSelector(`article[data-reuniao-id="${id}"] .chip:has-text("ata rascunho")`);
  await p.click(`[data-aprovarata="${id}"]`); await recibo(p, 'Ata aprovada');
  await p.waitForSelector(`article[data-reuniao-id="${id}"] .ata:has-text("Ata aprovada")`);
  await p.waitForSelector(`article[data-reuniao-id="${id}"] .encs li:has-text("Reenviar relatório de setembro ${MARCA}")`);
  const r2 = (await porta('rui', 'ext.painel_reunioes', { p_empresa: await empAlfa() })).reunioes.find(x => x.id === id);
  confere(r2.ata_situacao === 'aprovada' && r2.encaminhamentos.length === 1 && r2.encaminhamentos[0].responsavel === 'Operações · pessoa', 'ata no banco: ' + JSON.stringify(r2.encaminhamentos));
  const v = await axe(p); confere(v.length === 0, 'axe ' + v); await semErros(p); await p.close();
});

await caso('cancelar reunião com Meet retira o evento da Agenda', async () => {
  const p = await abrir('central.html', 'rui'); const chamadas = await servidor(p); await carregada(p); await aba(p, 'reunioes');
  const titulo = 'Cancelável ' + MARCA;
  await p.fill('#fr-titulo', titulo); await p.selectOption('#fr-plat', 'meet'); await p.click('#f-reuniao button[type="submit"]'); await recibo(p, 'Reunião marcada com link');
  const art = p.locator('article[data-reuniao-id]').filter({ hasText: titulo }); const id = Number(await art.getAttribute('data-reuniao-id'));
  const evento = chamadas.length;
  await p.fill('#cm-' + id, 'Cliente pediu outra data'); await p.click(`[data-cancelar="${id}"]`); await recibo(p, 'evento retirado da Agenda');
  confere(chamadas.some(c => c.acao === 'agenda_cancelar' && c.evento_id === 'ev-' + MARCA + '-' + evento), 'agenda_cancelar: ' + JSON.stringify(chamadas));
  await p.waitForSelector(`article[data-reuniao-id="${id}"] .chip:has-text("cancelada")`);
  await semErros(p); await p.close();
});

await caso('sem as funções do servidor: a reunião é marcada, a tela mostra o motivo e segue', async () => {
  const p = await abrir('central.html', 'rui'); await carregada(p); await aba(p, 'reunioes');
  const titulo = 'Sem Google ' + MARCA;
  await p.fill('#fr-titulo', titulo); await p.selectOption('#fr-plat', 'meet'); await p.click('#f-reuniao button[type="submit"]');
  await recibo(p, 'o evento com Meet não foi criado'); await recibo(p, 'falta o link');
  const art = p.locator('article[data-reuniao-id]').filter({ hasText: titulo }); const id = Number(await art.getAttribute('data-reuniao-id'));
  confere(await p.isVisible('#lk-' + id), 'campo para colar o link ausente');
  await p.fill('#lk-' + id, 'https://zoom.us/j/123456789'); await p.click(`[data-link="${id}"]`); await recibo(p, 'Link salvo');
  await p.waitForSelector(`article[data-reuniao-id="${id}"] a[href="https://zoom.us/j/123456789"]`);
  // a IA indisponível: a reunião aprovada antes não tem botão; usa a ata escrita à mão
  await p.click(`[data-escrever="${id}"]`); await p.fill(`#ata-${id} [data-k="resumo"]`, 'Ata escrita à mão porque a IA não estava disponível.');
  await p.click(`[data-salvarata="${id}"]`); await recibo(p, 'Rascunho salvo');
  confere((await p.textContent('#conteudo')).includes('Zoom, Teams e Webex'), 'texto aprovado sobre Zoom, Teams e Webex ausente');
  await semErros(p, ignoraRede); await p.close();
});

await caso('IA indisponível ao rascunhar a ata: mostra o motivo e oferece escrever à mão', async () => {
  const p = await abrir('central.html', 'rui'); const chamadas = await servidor(p); await carregada(p); await aba(p, 'reunioes');
  const titulo = 'IA fora ' + MARCA;
  await p.fill('#fr-titulo', titulo); await p.selectOption('#fr-plat', 'meet'); await p.check('#fr-gravar'); await p.click('#f-reuniao button[type="submit"]'); await recibo(p, 'Reunião marcada com link');
  const id = Number(await p.locator('article[data-reuniao-id]').filter({ hasText: titulo }).getAttribute('data-reuniao-id'));
  await p.fill('#cs-' + id, 'Equipe interna'); await p.click(`[data-consent="${id}"]`); await recibo(p, 'Consentimento registrado');
  await p.fill('#tr-' + id, 'https://drive.google.com/file/d/1ZyXwVuTsRqPoNmLkJiHgFeDcBa/view'); await p.click(`[data-transc="${id}"]`); await recibo(p, 'Transcrição guardada');
  await p.unroute('http://127.0.0.1:3398/ia');
  await p.click(`[data-ia="${id}"]`); await recibo(p, 'A IA não rascunhou');
  confere(await p.isEnabled(`[data-ia="${id}"]`) && await p.isVisible(`[data-escrever="${id}"]`), 'tela travou após a falha da IA');
  confere(chamadas.length >= 2, 'chamadas');
  await semErros(p, ignoraRede); await p.close();
});

// ---------- notas de débito ----------
// o worker do motor documental (documentos/worker.py) roda uma vez contra o PostgREST do ensaio: tira o pedido da fila, emite o PDF e registra
const DOCS = new URL('../../documentos/', import.meta.url).pathname;
function rodarWorker() {
  const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const h = b64({ alg: 'HS256', typ: 'JWT' }), c = b64({ role: 'anon', exp: Math.floor(Date.now() / 1000) + 600 });
  const anon = h + '.' + c + '.' + crypto.createHmac('sha256', process.env.IMTS_JWT_SEGREDO || 'segredo-de-ensaio-local-com-32-caracteres-ou-mais').update(h + '.' + c).digest('base64url');
  const chave = execFileSync('psql', ['postgresql:///app_ensaio?port=5499', '-Atc', "select decrypted_secret from vault.decrypted_secrets where name = 'doc_worker_chave'"]).toString().trim();
  return execFileSync('python3', ['worker.py', '--uma-vez'], { cwd: DOCS, timeout: 240000, stdio: ['ignore', 'pipe', 'ignore'],
    env: { ...process.env, SUPABASE_URL: 'http://127.0.0.1:3399', SUPABASE_REST: 'http://127.0.0.1:3399', SUPABASE_CHAVE_PUB: anon, DOC_WORKER_CHAVE: chave, DOC_WORKER_NOME: 'ensaio-app' } }).toString();
}
const texto = async (p, sel) => (await p.textContent(sel)).replace(/\s+/g, ' ');
async function abaNotas(p, filtro) {
  await aba(p, 'notas');
  if (filtro) { await p.click(`[data-ndfiltro="${filtro}"]`); await p.waitForSelector(`[data-ndfiltro="${filtro}"][aria-pressed="true"]`); }
}
async function baixa(p, sel) {
  const [d] = await Promise.all([p.waitForEvent('download'), p.click(sel)]);
  return fs.readFileSync(await d.path()).subarray(0, 5).toString();
}
const ND = { id: null, numero: null, ref: 'Viagem de implantação ' + MARCA };

await caso('nota de débito: rui cria pelo formulário com o total, não aprova a própria; lia aprova', async () => {
  const p = await abrir('central.html', 'rui'); await carregada(p); await abaNotas(p);
  await p.click('[data-ndnova]'); await p.waitForSelector('#f-nd');
  await p.selectOption('#nd-cp', { label: 'Prefeitura Exemplo (cliente)' });
  await p.fill('#nd-ref', ND.ref); await p.fill('#nd-local', 'Fortaleza/CE');
  const it = i => `#nd-itens .nd-item[data-i="${i}"]`;
  await p.fill(it(0) + ' [data-k="descricao"]', 'Passagem aérea Fortaleza a Brasília ' + MARCA); await p.fill(it(0) + ' [data-k="valor"]', '1.120,00');
  await p.click('[data-ndmais]'); await p.fill(it(1) + ' [data-k="descricao"]', 'Táxi do aeroporto ' + MARCA); await p.fill(it(1) + ' [data-k="valor"]', '86,40');
  confere((await texto(p, '#nd-total')).includes('R$ 1.206,40'), 'total na tela: ' + await texto(p, '#nd-total'));
  await p.click('#f-nd button[type="submit"]'); await recibo(p, 'Rascunho ND');
  const art = p.locator('article[data-nd]').filter({ hasText: ND.ref });
  ND.id = Number(await art.getAttribute('data-nd'));
  ND.numero = (await art.locator('h3').textContent()).split(' · ')[0];
  confere(/^ND \d{4}\/\d{4}$/.test(ND.numero), 'número ' + ND.numero);
  const n = (await porta('rui', 'doc.painel_notas_debito', { p_empresa: await empAlfa() })).notas.find(x => x.id === ND.id);
  confere(n.situacao === 'rascunho' && Number(n.total) === 1206.4 && n.itens.length === 2 && n.local === 'Fortaleza/CE', 'banco: ' + JSON.stringify(n));
  confere(await art.locator('[data-ndaprovar]').count() === 0 && (await art.textContent()).includes('Você criou'), 'quem criou vê o botão de aprovar');
  const r = await porta('rui', 'doc.nota_debito_aprovar', { p_nota: ND.id });
  confere(String(r.message || '').includes('quem criou'), 'quem criou aprovou pela porta: ' + JSON.stringify(r));
  const v = await axe(p); confere(v.length === 0, 'axe ' + v); await semErros(p, m => /status of 400/.test(m)); await p.close();
  const q = await abrir('central.html', 'lia'); await carregada(q); await abaNotas(q);
  await q.click(`[data-ndaprovar="${ND.id}"]`); await recibo(q, 'Nota aprovada');
  await q.waitForSelector(`[data-ndfiltro="aprovada"][aria-pressed="true"]`);
  await q.waitForSelector(`article[data-nd="${ND.id}"] .chip:has-text("aprovada")`);
  confere((await q.textContent(`article[data-nd="${ND.id}"]`)).includes('aprovada por Lia'), 'aprovador não aparece');
  await semErros(q); await q.close();
});

await caso('nota de débito: emite pelo motor, publica no portal da Prefeitura, baixa o PDF e registra o pagamento', async () => {
  confere(ND.id, 'sem nota do caso anterior');
  const p = await abrir('central.html', 'rui'); await carregada(p); await abaNotas(p, 'aprovada');
  await p.click(`[data-ndemitir="${ND.id}"]`); await recibo(p, 'Pedido de emissão');
  await p.waitForSelector(`article[data-nd="${ND.id}"]:has-text("na fila do motor documental")`);
  const n1 = (await porta('rui', 'doc.painel_notas_debito', { p_empresa: await empAlfa() })).notas.find(x => x.id === ND.id);
  confere(n1.situacao === 'emitida' && n1.pedido && n1.pedido_situacao === 'na_fila', 'pedido ao motor: ' + JSON.stringify(n1));
  const saida = rodarWorker();
  confere(saida.includes(`"pedido": ${n1.pedido}`) && /"situacao": "emitido/.test(saida), 'worker: ' + saida);
  await p.click('[data-ndatualizar]'); await p.waitForSelector(`[data-ndpublicar="${ND.id}"]`);
  confere(await baixa(p, `[data-ndpdf="${ND.id}"]`) === '%PDF-', 'PDF interno não baixou');
  await p.click(`[data-ndpublicar="${ND.id}"]`); await recibo(p, 'Nota publicada');
  await p.waitForSelector(`article[data-nd="${ND.id}"]:has-text("publicado no portal")`);
  // clara vê no portal e baixa o PDF; paulo (outra contraparte) não vê
  const c = await abrir('portal.html', 'clara'); await c.waitForSelector('#b-novo:not([disabled])');
  await c.click('#t-notas'); await c.waitForSelector(`#conteudo article[data-nd="${ND.id}"]`);
  const t = await texto(c, `article[data-nd="${ND.id}"]`);
  confere(t.includes(ND.numero) && t.includes('R$ 1.206,40') && t.includes('em aberto'), 'portal da clara: ' + t);
  confere(await baixa(c, `article[data-nd="${ND.id}"] [data-baixar]`) === '%PDF-', 'clara não baixou o PDF');
  confere(c.erros.length === 0, 'erros no portal ' + c.erros); await c.close();
  const pp = await porta('paulo', 'ext.portal_notas_debito', {});
  confere(Array.isArray(pp) && !pp.some(x => x.id === ND.id), 'paulo vê a nota da Prefeitura');
  // pagamento: rui (não aprovou) registra; a nota passa a paga
  await p.fill(`#ndpc-${ND.id}`, 'PIX E' + MARCA); await p.click(`[data-ndpagar="${ND.id}"]`); await recibo(p, 'Pagamento registrado');
  await p.waitForSelector(`[data-ndfiltro="paga"][aria-pressed="true"]`);
  await p.waitForSelector(`article[data-nd="${ND.id}"]:has-text("PIX E${MARCA}")`);
  const n2 = (await porta('clara', 'ext.portal_notas_debito', {})).find(x => x.id === ND.id);
  confere(n2.situacao === 'paga' && n2.pago_em, 'portal não vê o pagamento: ' + JSON.stringify(n2));
  await semErros(p); await p.close();
});

await caso('nota de débito: editar o rascunho recalcula o total; cancelar exige motivo', async () => {
  const emp = await empAlfa(), cp = (await porta('rui', 'doc.painel_notas_debito', { p_empresa: emp })).contrapartes.find(x => x.nome === 'Representante Regional Exemplo').id;
  const hoje = new Date().toISOString().slice(0, 10), venc = new Date(Date.now() + 10 * 864e5).toISOString().slice(0, 10);
  const r = await porta('rui', 'doc.nota_debito_salvar', { p_empresa: emp, p_contraparte: cp, p_vencimento: venc, p_itens: [{ descricao: 'Cópias ' + MARCA, data: hoje, valor: 12.5 }], p_local: 'Fortaleza/CE' });
  confere(r.id && r.numero, 'rascunho pela porta: ' + JSON.stringify(r));
  const p = await abrir('central.html', 'rui'); await carregada(p); await abaNotas(p);
  await p.click(`[data-ndeditar="${r.id}"]`); await p.waitForSelector('#f-nd');
  await p.fill('#nd-itens .nd-item[data-i="0"] [data-k="valor"]', '20,00');
  confere((await texto(p, '#nd-total')).includes('R$ 20,00'), 'total não recalculou');
  await p.click('#f-nd button[type="submit"]'); await recibo(p, 'salvo: total');
  confere((await porta('rui', 'doc.painel_notas_debito', { p_empresa: emp })).notas.find(x => x.id === r.id).total == 20, 'total editado não gravou');
  await p.click(`[data-ndcancelar="${r.id}"]`); await recibo(p, 'Recusado: cancelar exige motivo');
  await p.fill(`#ndcm-${r.id}`, 'Despesa entrou no contrato ' + MARCA); await p.click(`[data-ndcancelar="${r.id}"]`); await recibo(p, 'Nota cancelada');
  await p.waitForSelector(`article[data-nd="${r.id}"]:has-text("Despesa entrou no contrato ${MARCA}")`);
  await semErros(p, m => /status of 400/.test(m)); await p.close();
});

await caso('admin abre a Central na Empresa Alfa', async () => {
  const p = await abrir('central.html', 'admin'); await p.waitForSelector('#resumo span, #conteudo .vazio');
  const sel = await p.$('#imts-empresa');
  if (sel) { const v = await p.$eval('#imts-empresa', s => [...s.options].find(o => o.textContent === 'Empresa Alfa')?.value); if (v && v !== await p.inputValue('#imts-empresa')) { await p.selectOption('#imts-empresa', v); await p.waitForTimeout(300); await p.waitForLoadState('networkidle'); } }
  await p.waitForSelector('article[data-pedido]:has-text("Prefeitura Exemplo")');
  await semErros(p); await p.close();
});

await caso('paulo (parceiro) é recusado e volta à entrada', async () => {
  const p = await abrir('central.html', 'paulo');
  await p.waitForURL(u => !/central\.html/.test(String(u)), { timeout: 6000 });
  confere(!(await p.$('h1.marca:has-text("Central de atendimento")')), 'Central visível para externo'); await p.close();
});

await caso('acessibilidade nas quatro abas e no formulário da nota de débito: 1280 claro, 1280 escuro e 390 claro, sem rolagem horizontal', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const p = await abrir('central.html', 'rui', { largura: l, esquema: e }); await carregada(p);
    for (const a of ['atendimento', 'parceiros', 'reunioes', 'notas']) {
      await aba(p, a);
      const v = await axe(p); confere(v.length === 0, `${l} ${e} ${a} axe ${v}`);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} ${a} rolagem horizontal ${larg}`);
    }
    // formulário de nota de débito aberto, com duas despesas, e a lista das pagas com o quadro aberto
    await p.click('[data-ndnova]'); await p.click('[data-ndmais]');
    let v = await axe(p); confere(v.length === 0, `${l} ${e} formulário da nota axe ${v}`);
    let larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} formulário rolagem horizontal ${larg}`);
    await p.click('[data-ndfechar]'); await p.click('[data-ndfiltro="paga"]');
    for (const d of await p.$$('article[data-nd] details')) await d.evaluate(x => { x.open = true; });
    v = await axe(p); confere(v.length === 0, `${l} ${e} notas pagas axe ${v}`);
    larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${l} ${e} notas pagas rolagem horizontal ${larg}`);
    await semErros(p); await p.close();
  }
});

await fim('central');
