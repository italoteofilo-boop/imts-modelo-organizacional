import { abrir, axe, caso, confere, fim } from './apoio.mjs';
import fs from 'node:fs';
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
    for (const t of ['conexoes', 'parametros', 'agentes', 'saude', 'alertas', 'implantacao', 'cadastro', 'historico', 'agenda']) {
      await aba(p, t); await p.waitForTimeout(50);
      if (t === 'agentes') await p.$$eval('#conteudo details', ds => ds.forEach(d => { d.open = true; }));
      const v = await axe(p); confere(v.length === 0, `${l} ${e} ${t} axe ` + v);
      const larg = await p.evaluate(() => document.documentElement.scrollWidth); confere(larg <= l, `${t} rolagem horizontal ${larg}`);
    }
    await aba(p, 'conexoes'); await p.click('[data-editar-conexao]'); const v = await axe(p); confere(v.length === 0, `${l} ${e} painel axe ` + v);
    await p.keyboard.press('Escape');
    confere(p.erros.length === 0, 'erros ' + p.erros); await p.close();
  }
});
await fim('admin');
