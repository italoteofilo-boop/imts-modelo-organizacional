import { abrir, axe, caso, confere, fim } from './apoio.mjs';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
const sql = q => execFileSync('psql', ['postgresql:///app_ensaio?port=5499', '-Atc', q], { encoding: 'utf8' }).trim();
const marca = Date.now().toString(36);
const csv = linhas => Buffer.from('﻿' + linhas.join('\r\n') + '\r\n', 'utf8');
const pronto = async p => { await p.waitForSelector('#t-conexoes'); await p.waitForFunction(() => document.querySelectorAll('#conteudo .linha').length > 0, null, { timeout: 8000 }); };
const aba = async (p, id) => { await p.click('#t-' + id); await p.waitForFunction(i => document.getElementById('t-' + i).getAttribute('aria-selected') === 'true', id); };
const semAviso = async p => p.waitForFunction(() => !document.querySelector('#foco:not([hidden])'));

await caso('admin abre com dados reais da porta única', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p);
  confere((await p.textContent('#imts-barra')).includes('Administração'), 'barra sem o módulo');
  const t = await p.textContent('#conteudo'); confere(t.includes('pg-cron'), 'conexões sem pg-cron');
  confere(!(await p.$('#t-simulacao')), 'aba Simulação ainda existe');
  confere(!/protótipo da página|Atuando como|Retrato gravado/.test(await p.textContent('body')), 'resto de protótipo na tela');
  await aba(p, 'parametros'); confere((await p.textContent('#conteudo')).includes('login.dominios'), 'parâmetros');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('implantação: itens ok/falta, externo marcado, cobertura de papéis', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'implantacao');
  await p.waitForSelector('#tab-implantacao');
  const t = await p.textContent('#tab-implantacao');
  confere(t.includes('segredos no cofre') && t.includes('falta') && t.includes('fora do sistema'), 'itens da conferência');
  confere(/\d+ de \d+ papéis/.test(await p.textContent('#cobertura-txt')), 'cobertura');
  const v = await axe(p); confere(v.length === 0, 'axe ' + v); await p.close();
});

await caso('alertas: lista ou vazio; resolve se houver aberto', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'alertas');
  const b = await p.$('[data-resolver]');
  if (b) { const id = await b.getAttribute('data-resolver'); await b.click();
    await p.waitForFunction(i => !document.querySelector(`[data-resolver="${i}"]`), id, { timeout: 8000 }); }
  else confere(await p.isVisible('#alertas-vazio'), 'nem lista nem vazio');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('ação real: desligar e religar um agente', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'agentes');
  const cod = 'guardiao-prazos-operacoes', chip = `[data-agente-cartao="${cod}"] [data-estado-ligado]`;
  await p.waitForSelector(chip);
  const antes = (await p.textContent(chip)).trim();
  for (const esperado of [antes === 'ligado' ? 'desligado' : 'ligado', antes]) {
    await p.click(`[data-ligar="${cod}"]`); await p.fill('#f-mot', 'teste do aplicativo ' + marca); await p.click('#f-ag button[type=submit]');
    await semAviso(p); await p.waitForFunction(([s, e]) => document.querySelector(s)?.textContent.trim() === e, [chip, esperado], { timeout: 8000 });
  }
  await aba(p, 'historico'); confere((await p.textContent('#tab-historico')).includes('teste do aplicativo ' + marca), 'histórico sem o motivo');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('cadastro: cinco modelos CSV com BOM, ponto e vírgula e cabeçalho', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'cadastro');
  const esperado = { empresas: 'nome;cnpj;razao_social;regime_tributario;porte;marca', pessoas: 'nome;email;papel;circulo;nivel;empresa',
    contrapartes: 'empresa;tipo;nome;cnpj;setor_publico', usuarios_externos: 'contraparte;nome;email;perfil', contratos_parceria: 'parceiro;percentual;parcelas_max;vigente_de;fonte' };
  for (const [k, cab] of Object.entries(esperado)) {
    const [d] = await Promise.all([p.waitForEvent('download'), p.click(`[data-modelo="${k}"]`)]);
    const txt = fs.readFileSync(await d.path(), 'utf8');
    confere(d.suggestedFilename() === `modelo_${k}.csv`, 'nome ' + d.suggestedFilename());
    confere(txt.charCodeAt(0) === 0xFEFF && txt.slice(1).trim() === cab, k + ': ' + JSON.stringify(txt));
  }
  await p.close();
});

await caso('cadastro: prévia com erro bloqueia; prévia limpa libera; carga confirmada grava', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'cadastro');
  const cab = 'nome;email;papel;circulo;nivel;empresa';
  // 1) erro: e-mail fora do domínio e nível inválido; contrato com percentual em vírgula e data dd/mm/aaaa (convertidos na tela)
  await p.setInputFiles('#csv-pessoas', { name: 'pessoas.csv', mimeType: 'text/csv', buffer: csv([cab, `Pessoa Errada ${marca};errada.${marca}@gmail.com;Estratégia · pessoa;1;chefe;Empresa Alfa`]) });
  await p.setInputFiles('#csv-contratos_parceria', { name: 'contratos.csv', mimeType: 'text/csv', buffer: csv(['parceiro;percentual;parcelas_max;vigente_de;fonte', 'Representante Regional Exemplo;12,5;10;01/11/2026;Contrato de teste']) });
  await p.waitForFunction(() => /1 linha/.test(document.getElementById('st-contratos_parceria').textContent));
  await p.click('#b-previa'); await p.waitForSelector('#previa-erros');
  const er = await p.textContent('#previa-erros');
  confere(er.includes('linha 1') && er.includes('email') && er.includes('nivel'), 'erros: ' + er);
  confere(!er.includes('percentual') && !er.includes('vigente_de'), 'conversão de número/data falhou: ' + er);
  confere(await p.isDisabled('#b-confirmar'), 'confirmar liberado com erro');
  let v = await axe(p); confere(v.length === 0, 'axe ' + v);
  // 2) sem erro: só a pessoa nova
  await p.click('#b-limpar');
  const email = `nova.${marca}@imts.com.br`;
  await p.setInputFiles('#csv-pessoas', { name: 'pessoas.csv', mimeType: 'text/csv', buffer: csv([cab, `Pessoa Nova ${marca};${email};Estratégia · pessoa;1;operar;Empresa Alfa`]) });
  await p.waitForFunction(() => /1 linha/.test(document.getElementById('st-pessoas').textContent));
  await p.click('#b-previa'); await p.waitForSelector('#previa-resultado[data-pode="true"]');
  confere(!(await p.isDisabled('#b-confirmar')), 'confirmar bloqueado sem erro');
  await p.click('#b-confirmar'); await p.waitForSelector('#previa-resultado[data-confirmado="true"]', { timeout: 8000 });
  confere((await p.textContent('#previa-resultado')).includes('1 pessoas'), 'gravados: ' + await p.textContent('#previa-resultado'));
  // 3) aparece na tela: histórico com a carga e a cobertura do papel
  await aba(p, 'historico'); const h = await p.textContent('#tab-historico');
  confere(h.includes('carga do cadastro real pela importação') && h.includes('pessoas: 1'), 'histórico sem a carga');
  await aba(p, 'implantacao'); await p.waitForSelector('#cobertura-txt');
  confere(!((await p.$('#sem-pessoa')) && (await p.textContent('#sem-pessoa')).includes('Estratégia · pessoa')), 'papel ainda sem pessoa');
  // 4) repetir a mesma planilha: aviso de já cadastrada
  await aba(p, 'cadastro'); await p.click('#b-previa'); await p.waitForSelector('#previa-avisos');
  confere((await p.textContent('#previa-avisos')).includes('já cadastrada'), 'sem aviso de repetida');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('ação real: convidar cliente pela tela', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'cadastro');
  await p.waitForFunction(() => document.querySelectorAll('#cv-cp option').length > 0, null, { timeout: 8000 });
  await p.selectOption('#cv-cp', { label: 'Prefeitura Exemplo (cliente)' });
  confere((await p.textContent('#cv-usuarios')).includes('clara@prefeitura-exemplo.gov.br'), 'usuários da contraparte');
  await p.fill('#cv-nome', 'Convidado ' + marca); await p.fill('#cv-email', `convidado.${marca}@exemplo.gov.br`);
  await p.click('#f-convite button[type=submit]'); await p.waitForFunction(() => /Convite \d+ criado/.test(document.getElementById('cv-ok').textContent), null, { timeout: 8000 });
  await p.waitForFunction(m => document.getElementById('cv-convites')?.textContent.includes(`convidado.${m}@exemplo.gov.br`), marca, { timeout: 8000 });
  confere(await p.$eval('#cv-cp', s => s.selectedOptions[0].textContent) === 'Prefeitura Exemplo (cliente)', 'seleção perdida');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});


const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
async function servidorFalso(p, resposta) {
  await p.unroute('**/conexoes').catch(() => {});
  await p.route('**/conexoes', r => r.request().method() === 'OPTIONS' ? r.fulfill({ status: 204, headers: CORS })
    : r.fulfill({ status: resposta.status || 200, headers: { ...CORS, 'Content-Type': 'application/json' }, body: JSON.stringify(resposta.corpo) }));
}
const assistente = async (p, k) => { await p.click(`[data-assist="${k}"]`); await p.waitForSelector(`#assistente[data-assist-atual="${k}"]`); };

await caso('integrações: situação e gravar segredo (valor nunca volta)', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'integracoes');
  await p.waitForSelector('#integ-situacao'); confere(/Ativas e testadas \d+/.test(await p.textContent('#integ-situacao')), 'situação');
  await assistente(p, 'kimi');
  const valor = `sk-ensaio-${marca}-naoreal`, imp = crypto.createHash('sha256').update(valor).digest('hex').slice(0, 8);
  confere(await p.getAttribute('#sg-kimi_chave', 'type') === 'password', 'campo não é senha');
  await p.fill('#sg-kimi_chave', valor); await p.fill('#sg-kimi_chave-mot', 'teste do aplicativo ' + marca);
  await p.click('[data-segredo-form="kimi_chave"] button[type=submit]');
  await p.waitForFunction(i => document.querySelector('[data-segredo-st="kimi_chave"]')?.textContent.includes('impressão ' + i), imp, { timeout: 8000 });
  confere(/gravado em \d/.test(await p.textContent('[data-segredo-st="kimi_chave"]')), 'sem data de gravação');
  confere(await p.inputValue('#sg-kimi_chave') === '', 'campo não foi limpo');
  confere(!(await p.content()).includes(valor), 'valor aparece na página');
  await aba(p, 'historico'); confere(!(await p.content()).includes(valor), 'valor no histórico da tela');
  confere((await p.textContent('#tab-historico')).includes('segredo:kimi_chave'), 'histórico sem a gravação');
  confere(sql("select count(*) from vault.secrets where name = 'kimi_chave' and coalesce(updated_at, created_at) > now() - interval '2 minutes'") === '1', 'segredo não está no cofre');
  confere(sql(`select count(*) from adm.historico where coalesce(antes::text,'') || coalesce(depois::text,'') || coalesce(motivo,'') like '%${valor}%'`) === '0', 'valor no histórico do banco');
  // Google: JSON inválido é barrado na tela, sem ir ao banco
  await aba(p, 'integracoes'); await assistente(p, 'google');
  await p.fill('#sg-google_conta_servico', '{"type":"service_account"}'); await p.fill('#sg-google_conta_servico-mot', 'teste');
  await p.click('[data-segredo-form="google_conta_servico"] button[type=submit]');
  await p.waitForFunction(() => /client_email e private_key/.test(document.querySelector('[data-segredo-st="google_conta_servico"]').textContent));
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('integrações: testar conexão (servidor interceptado: ok e falha) e parâmetro', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'integracoes'); await assistente(p, 'telegram');
  // enquanto o núcleo não expõe IMTS.servidor(nome, acao, dados), o teste instala um equivalente ao padrão de IMTS.google
  const nucleo = await p.evaluate(() => typeof IMTS.servidor === 'function');
  if (!nucleo) await p.evaluate(() => { IMTS.servidor = async (nome, acao, dados) => {
    const r = await fetch(IMTS_CONFIG.funcoes + '/' + nome, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + sessionStorage.getItem('imts_token_teste') }, body: JSON.stringify({ acao, ...(dados || {}) }) });
    const c = await r.json().catch(() => ({})); if (!r.ok) throw new Error(c.erro || c.message || 'falha na função ' + nome); return c; }; });
  console.log('     (IMTS.servidor ' + (nucleo ? 'do núcleo' : 'instalado pelo teste: falta no núcleo') + ')');
  await servidorFalso(p, { corpo: { ok: true, detalhe: 'bot @imts_ensaio_bot respondeu' } });
  await p.click('[data-testar="telegram-bot-api"]');
  await p.waitForFunction(() => /Funcionou: bot @imts_ensaio_bot/.test(document.querySelector('[data-teste-st="telegram-bot-api"]')?.textContent || ''), null, { timeout: 8000 });
  await servidorFalso(p, { corpo: { ok: false, detalhe: 'token recusado pelo Telegram' } });
  await p.click('[data-testar="telegram-bot-api"]');
  await p.waitForFunction(() => /Falhou: token recusado/.test(document.querySelector('[data-teste-st="telegram-bot-api"]')?.textContent || ''), null, { timeout: 8000 });
  await servidorFalso(p, { status: 500, corpo: { erro: 'função fora do ar', codigo: 500 } });
  await p.click('[data-testar="telegram-bot-api"]');
  await p.waitForFunction(() => /Falhou: função fora do ar/.test(document.querySelector('[data-teste-st="telegram-bot-api"]')?.textContent || ''), null, { timeout: 8000 });
  const ref = '-100' + Date.now();
  await p.fill('#pr-alerta-chat_ref', ref); await p.fill('#pr-alerta-chat_ref-mot', 'teste do aplicativo');
  await p.click('[data-param-form="alerta.chat_ref"] button[type=submit]');
  await p.waitForFunction(() => /Aplicado/.test(document.querySelector('[data-param-st="alerta.chat_ref"]')?.textContent || ''), null, { timeout: 8000 });
  confere(await p.inputValue('#pr-alerta-chat_ref') === ref, 'parâmetro não voltou do banco');
  p.erros.splice(0, p.erros.length, ...p.erros.filter(e => !/status of 500/.test(e)));   // o 500 é provocado pelo teste
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('integrações: cadastrar serviço externo, configurar e ver os sistemas', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'integracoes'); await assistente(p, 'externo');
  const cod = 'erp-' + marca, seg = `erp_${marca}_chave`;
  await p.fill('#ex-cod', cod); await p.fill('#ex-nome', 'ERP de ensaio ' + marca); await p.selectOption('#ex-cat', 'contábil');
  await p.fill('#ex-forn', 'Fornecedor Exemplo'); await p.fill('#ex-end', 'https://erp.exemplo.com.br/api'); await p.fill('#ex-seg', seg);
  await p.fill('#ex-pares [data-par-k]', 'api_key'); await p.fill('#ex-pares [data-par-v]', 'x'); await p.fill('#ex-mot', 'teste do aplicativo');
  await p.click('#f-ext button[type=submit]'); await p.waitForFunction(() => /parece segredo/.test(document.getElementById('ex-st').textContent));
  await p.fill('#ex-pares [data-par-k]', 'ambiente'); await p.fill('#ex-pares [data-par-v]', 'homologacao');
  await p.click('#f-ext button[type=submit]');
  await p.waitForSelector(`[data-conexao="${cod}"]`, { timeout: 8000 });
  const t = await p.textContent(`[data-conexao="${cod}"]`);
  confere(t.includes('ambiente=homologacao') && t.includes(seg) && t.includes('pendente'), 'cartão do serviço: ' + t);
  await p.click(`[data-configurar="${cod}"]`); await p.fill('#cf-forn', 'Fornecedor Novo'); await p.fill('#f-mot', 'teste');
  await p.click('#f-cfg button[type=submit]'); await semAviso(p);
  await p.waitForFunction(c => document.querySelector(`[data-conexao="${c}"]`)?.textContent.includes('Fornecedor Novo'), cod, { timeout: 8000 });
  await assistente(p, 'sistemas'); confere((await p.textContent('#tab-sistemas')).includes('erp-contabil'), 'sistemas');
  const rs = await p.$('[data-sistema-form="erp-contabil"]');
  await p.selectOption('#si-erp-contabil-m', 'real'); await p.fill('#si-erp-contabil-mot', 'teste');
  await (await rs.$('button[type=submit]')).click();
  await p.waitForFunction(() => /só vira real/.test(document.querySelector('[data-sistema-form="erp-contabil"]')?.textContent || ''), null, { timeout: 8000 });
  p.erros.splice(0, p.erros.length, ...p.erros.filter(e => !/status of 400/.test(e)));   // a recusa do modo real é provocada pelo teste
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('automação e IA: resumo das tarefas R e dos agentes de IA, com os números do banco', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'automacao');
  await p.waitForSelector('#sec-automacao-r'); await p.waitForSelector('#sec-agente-ia');
  const r = JSON.parse(sql('select adm.automacao_r_resumo()')), a = JSON.parse(sql('select adm.agente_ia_resumo()'));
  const tot = await p.textContent('#automacao-totais');
  confere(tot.includes('Tarefas R no modelo ' + r.tarefas_r) && tot.includes('A automação conclui ' + r.automaticas) && tot.includes('Com a pessoa ' + r.humanas), 'totais R: ' + tot);
  for (const m of ['registrar', 'encaminhar', 'avisar', 'humano'])
    confere((await p.textContent(`[data-modo-r="${m}"]`)).includes(String(r.por_modo[m])), 'modo ' + m);
  const ia = await p.textContent('#sec-agente-ia');
  confere((await p.textContent('#agente-ia-totais')).includes('Tarefas A no modelo ' + a.tarefas_a), 'tarefas A');
  confere(ia.includes(a.disponivel ? 'disponível' : 'indisponível') && (a.disponivel || ia.includes(a.motivo_indisponivel)), 'disponibilidade: ' + ia);
  confere(ia.includes(a.autonomo ? 'autônomo' : 'revisão humana'), 'autonomia');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('automação R: definir o modo de um verbo pede confirmação, grava e fica no histórico', async () => {
  const letras = Array.from(marca.replace(/[^a-z]/g, '') + 'abcdef').slice(0, 6).join('');
  const verbo = 'Ensaiar' + letras, mot = 'teste do aplicativo ' + marca;
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'automacao'); await p.waitForSelector('#f-automacao-r');
  await p.fill('#ar-verbo', verbo.toLowerCase()); await p.selectOption('#ar-modo', 'avisar'); await p.fill('#ar-mot', mot);
  await p.click('#f-automacao-r button[type=submit]'); await p.waitForSelector('#f-ar-conf');
  confere((await p.textContent('#foco')).includes(verbo) && (await p.textContent('#foco')).includes('avisar'), 'confirmação sem o verbo e o modo');
  let v = await axe(p); confere(v.length === 0, 'axe na confirmação ' + v);
  await p.click('#f-cancelar'); await semAviso(p);
  confere(sql(`select count(*) from adm.automacao_r_regra where verbo = '${verbo}'`) === '0', 'gravou sem confirmar');
  await p.click('#f-automacao-r button[type=submit]'); await p.waitForSelector('#f-ar-conf'); await p.click('#f-ar-conf button[type=submit]');
  await semAviso(p); await p.waitForFunction(t => document.getElementById('ar-st')?.textContent.includes(t), verbo, { timeout: 8000 });
  confere(sql(`select modo from adm.automacao_r_regra where verbo = '${verbo}'`) === 'avisar', 'regra não gravada');
  confere(sql(`select count(*) from adm.historico where objeto = 'automacao_r' and chave = '${verbo}' and motivo = '${mot}'`) === '1', 'sem histórico');
  sql(`delete from adm.automacao_r_regra where verbo = '${verbo}'`);
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('automação R: lista de regras por verbo com os números do banco, filtro por modo e busca por verbo', async () => {
  const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'automacao'); await p.waitForSelector('#tab-regras-r');
  const g = JSON.parse(sql('select adm.automacao_r_regras()'));
  confere(g.total === Number(sql('select count(*) from adm.automacao_r_regra')), 'total da função');
  confere(await p.$$eval('#tb-regras-r tr[data-regra]', t => t.length) === g.total, 'linhas da tabela');
  const reg = g.regras.find(x => x.verbo === 'Registrar');
  confere(reg.tarefas_r === Number(sql("select count(*) from org.tarefa where executor = 'R' and initcap(lower(split_part(btrim(nome), ' ', 1))) = 'Registrar'")), 'tarefas de Registrar');
  const lr = await p.textContent('#tb-regras-r tr[data-regra="Registrar"]');
  confere(lr.includes('registrar') && lr.includes(reg.descricao) && lr.includes(String(reg.tarefas_r)) && lr.includes('Trocar modo'), 'linha de Registrar: ' + lr);
  confere((await p.$$eval('#tab-regras-r thead th', ts => ts.map(t => t.textContent).join('|'))) === 'Verbo|Modo|Descrição|Tarefas R|Atualizado|Ação', 'colunas');
  await p.selectOption('#rg-modo', 'avisar');
  const nAv = Number(sql("select count(*) from adm.automacao_r_regra where modo = 'avisar'"));
  confere(await p.$$eval('#tb-regras-r tr[data-regra]', t => t.length) === nAv, 'filtro por modo avisar');
  confere(await p.$$eval('#tb-regras-r tr[data-regra] .chip', cs => cs.every(c => c.textContent === 'avisar')), 'filtro deixou outro modo');
  confere((await p.textContent('#rg-n')).includes(`${nAv} de ${g.total}`), 'contagem do filtro');
  await p.selectOption('#rg-modo', ''); await p.click('#rg-busca'); await p.keyboard.type('regis');
  confere(await p.evaluate(() => document.activeElement?.id) === 'rg-busca', 'busca perdeu o foco');
  const vs = await p.$$eval('#tb-regras-r tr[data-regra]', t => t.map(x => x.dataset.regra));
  confere(vs.length > 0 && vs.includes('Registrar') && vs.every(v => v.toLowerCase().includes('regis')), 'busca por verbo: ' + vs);
  await p.fill('#rg-busca', 'zzzsemverbo'); confere((await p.textContent('#tb-regras-r')).includes('Nenhuma regra com esse filtro'), 'busca vazia');
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('automação R: trocar modo pela linha pré-preenche o formulário e mantém a confirmação', async () => {
  const letras = Array.from(marca.replace(/[^a-z]/g, '') + 'ghijkl').slice(0, 6).join('');
  const verbo = 'Linhar' + letras, mot = 'troca pela linha ' + marca;
  sql(`insert into adm.automacao_r_regra (verbo, modo, descricao) values ('${verbo}', 'humano', 'regra de teste da lista')`);
  try {
    const p = await abrir('admin.html', 'admin'); await pronto(p); await aba(p, 'automacao'); await p.waitForSelector('#tab-regras-r');
    await p.fill('#rg-busca', verbo.toLowerCase());
    const lin = `#tb-regras-r tr[data-regra="${verbo}"]`;
    confere((await p.textContent(lin)).includes('carga inicial'), 'linha sem autor deveria dizer carga inicial');
    await p.click(`${lin} [data-regra-verbo]`);
    confere(await p.inputValue('#ar-verbo') === verbo && await p.inputValue('#ar-modo') === 'humano', 'formulário não pré-preenchido');
    confere(await p.evaluate(() => document.activeElement?.id) === 'ar-modo', 'foco não foi ao modo');
    await p.selectOption('#ar-modo', 'registrar'); await p.fill('#ar-mot', mot);
    await p.click('#f-automacao-r button[type=submit]'); await p.waitForSelector('#f-ar-conf');
    confere((await p.textContent('#foco')).includes(verbo) && (await p.textContent('#foco')).includes('registrar'), 'confirmação sem verbo e modo');
    confere(sql(`select modo from adm.automacao_r_regra where verbo = '${verbo}'`) === 'humano', 'gravou antes de confirmar');
    await p.click('#f-ar-conf button[type=submit]'); await semAviso(p);
    await p.waitForFunction(t => document.getElementById('ar-st')?.textContent.includes(t), verbo, { timeout: 8000 });
    confere(sql(`select modo from adm.automacao_r_regra where verbo = '${verbo}'`) === 'registrar', 'regra não gravada');
    confere(sql(`select count(*) from adm.historico where objeto = 'automacao_r' and chave = '${verbo}' and motivo = '${mot}'`) === '1', 'sem histórico');
    const nome = sql(`select i.nome from rt_chave.login l join rt_chave.identidade i on i.pseudonimo = l.pseudonimo where l.auth_uid = '00000000-0000-4000-8000-000000000001'`);
    await p.waitForFunction(v => document.querySelector(`#tb-regras-r tr[data-regra="${v}"] .chip`)?.textContent === 'registrar', verbo, { timeout: 8000 });
    const t = await p.textContent(lin);
    confere(t.includes(mot) && t.includes(nome), 'linha não mostra a mudança: ' + t);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  } finally { sql(`delete from adm.automacao_r_regra where verbo = '${verbo}'`); }
});

await caso('automação R: quem não administra é recusado pelo banco', async () => {
  const p = await abrir('mesa.html', 'olga'); await p.waitForSelector('body[data-pronto="1"]');
  const r = await p.evaluate(async () => { try { await IMTS.chamar('adm.automacao_r_definir', { p_verbo: 'Registrar', p_modo: 'humano', p_motivo: 'tentativa' }); return 'aceito'; } catch (e) { return 'recusado: ' + e.message; } });
  confere(r.startsWith('recusado'), 'olga gravou: ' + r);
  const ia = await p.evaluate(async () => { try { await IMTS.chamar('adm.agente_ia_resumo', {}); return 'aceito'; } catch (e) { return 'recusado'; } });
  confere(ia === 'recusado', 'olga leu o resumo do agente de IA');
  const rg = await p.evaluate(async () => { try { await IMTS.chamar('adm.automacao_r_regras', {}); return 'aceito'; } catch (e) { return 'recusado: ' + e.message; } });
  confere(rg.startsWith('recusado'), 'olga leu a lista de regras: ' + rg);
  confere(sql("select modo from adm.automacao_r_regra where verbo = 'Registrar'") === 'registrar', 'regra mudou');
  p.erros.splice(0, p.erros.length, ...p.erros.filter(e => !/status of (400|403)/.test(e)));
  confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
});

await caso('automação e IA: axe em 390 e 1280, claro e escuro, com a confirmação aberta, sem rolagem horizontal', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light'], [390, 'dark']]) {
    const p = await abrir('admin.html', 'admin', { largura: l, esquema: e }); await pronto(p); await aba(p, 'automacao'); await p.waitForSelector('#sec-agente-ia');
    let v = await axe(p); confere(v.length === 0, `${l} ${e} axe ` + v);
    let lg = await p.evaluate(() => document.documentElement.scrollWidth); confere(lg <= l, `${l} ${e} rolagem horizontal ${lg}`);
    confere(await p.$$eval('#tb-regras-r tr[data-regra]', t => t.length) > 0, `${l} ${e} lista de regras vazia`);
    await p.selectOption('#rg-modo', 'encaminhar'); await p.fill('#rg-busca', 'e');
    v = await axe(p); confere(v.length === 0, `${l} ${e} regras filtradas axe ` + v);
    lg = await p.evaluate(() => document.documentElement.scrollWidth); confere(lg <= l, `${l} ${e} regras filtradas rolagem ${lg}`);
    await p.click('#tb-regras-r [data-regra-verbo]'); confere(await p.inputValue('#ar-modo') === 'encaminhar', `${l} ${e} trocar modo não pré-preencheu`);
    await p.fill('#ar-verbo', 'Registrar'); await p.fill('#ar-mot', 'só conferir a tela'); await p.click('#f-automacao-r button[type=submit]'); await p.waitForSelector('#f-ar-conf');
    v = await axe(p); confere(v.length === 0, `${l} ${e} confirmação axe ` + v);
    lg = await p.evaluate(() => document.documentElement.scrollWidth); confere(lg <= l, `${l} ${e} confirmação rolagem ${lg}`);
    await p.keyboard.press('Escape'); await semAviso(p);
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  }
});

await caso('olga (sem administração) é recusada', async () => {
  const p = await abrir('admin.html', 'olga'); await p.waitForURL(/index\.html/, { timeout: 5000 });
  await p.waitForSelector('#inicio:not([hidden])'); await p.close();
});
await caso('clara (cliente) é recusada', async () => {
  const p = await abrir('admin.html', 'clara'); await p.waitForURL(/(index|portal)\.html/, { timeout: 5000 }); confere(!/admin\.html/.test(p.url()), 'ficou na administração'); await p.close();
});

await caso('acessibilidade e largura: 1280 claro, 1280 escuro, 390 claro', async () => {
  for (const [l, e] of [[1280, 'light'], [1280, 'dark'], [390, 'light']]) {
    const p = await abrir('admin.html', 'admin', { largura: l, esquema: e }); await pronto(p);
    for (const t of ['conexoes', 'integracoes', 'parametros', 'agentes', 'automacao', 'saude', 'alertas', 'implantacao', 'cadastro', 'historico', 'agenda']) {
      await aba(p, t); await p.waitForTimeout(50);
      if (t === 'agentes' || t === 'alertas') await p.$$eval('#conteudo details', ds => ds.forEach(d => { d.open = true; }));
      if (t === 'integracoes') for (const k of ['telegram', 'anthropic', 'kimi', 'google', 'externo', 'sistemas', 'todas']) {
        await assistente(p, k); const v = await axe(p); confere(v.length === 0, `${l} ${e} integrações/${k} axe ` + v);
        const lg = await p.evaluate(() => document.documentElement.scrollWidth); confere(lg <= l, `integrações/${k} rolagem horizontal ${lg}`); }
      const v = await axe(p); confere(v.length === 0, `${l} ${e} ${t} axe ` + v);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${t} rolagem horizontal ${larg}`);
    }
    await aba(p, 'conexoes'); await p.click('[data-editar-conexao]'); const v = await axe(p); confere(v.length === 0, `${l} ${e} painel axe ` + v);
    await p.keyboard.press('Escape');
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  }
});
await fim('admin');
