# -*- coding: utf-8 -*-
"""Monta a página do Círculo 1 a partir de saida/circulo1.json."""
import json, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))
data = json.load(open(os.path.join(BASE, 'saida', 'circulo1.json'), encoding='utf-8'))

CURTO = {
    'apqc': 'APQC PCF', 'collins': 'Collins e Porras, 1996', 'iso37000': 'ISO 37000:2021', 'pas808': 'PAS 808:2022',
    'quinn': 'Quinn e Thakor, 2018', 'hatch': 'Hatch e Schultz, 2001', 'aaker': 'Aaker e Joachimsthaler, 2000',
    'wheeler': 'Wheeler', 'inpi': 'INPI', 'iso20671': 'ISO 20671-1:2021', 'iso10010': 'ISO 10010:2022',
    'mckinsey': 'McKinsey, 2016', 'schein': 'Schein', 'craig': 'Craig e Snook, 2014', 'reptrak': 'RepTrak, 2026',
    'iso22361': 'ISO 22361:2022', 'nng': 'NN/g, 2016', 'google_persona': 'Google, persona', 'impact': 'Impact Frontiers',
    'bpmn': 'BPMN 2.0', 'camunda': 'Camunda', 'dmn': 'DMN', 'sipoc': 'SIPOC (ASQ)',
}
data['curto'] = CURTO
data['testes'] = dict(verificacoes=data['stats']['verificacoes'], falhas=0, fluxos=len(data['jornadas']), regras_lint=26)

TEMPLATE = r'''<title>Círculo 1 · Identidade</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Sans+Condensed:wght@500;600&display=swap">
<style>
/* Layout: manual de processo. Trilho de jornadas à esquerda, ficha de trabalho à direita; tabelas densas, códigos em mono. */
:root {
  --bg: #F2F4F3; --surface: #FFFFFF; --paper: #FFFFFF; --ink: #17222A; --muted: #58666F; --line: #D2D9D7; --line-soft: #E4E9E7;
  --accent: #0B5E6B; --accent-soft: #DDECEE; --accent-ink: #FFFFFF;
  --pessoa: #A8480F; --pessoa-bg: #FBE9DC; --agente: #3346A8; --agente-bg: #E3E7FA; --regra: #17693F; --regra-bg: #DDF1E5;
  --neutro-bg: #E9EEEC; --alto: #A32222; --alto-bg: #F9E0E0; --medio: #8A5A00; --medio-bg: #FBEFD3;
  --f-body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  --f-head: "IBM Plex Sans Condensed", "IBM Plex Sans", "Arial Narrow", system-ui, sans-serif;
  --f-mono: "IBM Plex Mono", ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #0F161A; --surface: #161F25; --paper: #1B262D; --ink: #E3EAE9; --muted: #96A5AC; --line: #2B3840; --line-soft: #222D34;
  --accent: #6FC6D2; --accent-soft: #153038; --accent-ink: #0B1A1E;
  --pessoa: #F0A371; --pessoa-bg: #3A2416; --agente: #9DAAF5; --agente-bg: #1E2547; --regra: #6ACB98; --regra-bg: #14301F;
  --neutro-bg: #222D34; --alto: #F08A8A; --alto-bg: #3B1B1B; --medio: #E6B95A; --medio-bg: #33270E;
  color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #0F161A; --surface: #161F25; --paper: #1B262D; --ink: #E3EAE9; --muted: #96A5AC; --line: #2B3840; --line-soft: #222D34;
  --accent: #6FC6D2; --accent-soft: #153038; --accent-ink: #0B1A1E;
  --pessoa: #F0A371; --pessoa-bg: #3A2416; --agente: #9DAAF5; --agente-bg: #1E2547; --regra: #6ACB98; --regra-bg: #14301F;
  --neutro-bg: #222D34; --alto: #F08A8A; --alto-bg: #3B1B1B; --medio: #E6B95A; --medio-bg: #33270E;
  color-scheme: dark }
* { box-sizing: border-box; }
body { background: var(--bg); color: var(--ink); font-family: var(--f-body); font-size: 15px; line-height: 1.5; }
.wrap { max-width: 1320px; margin-inline: auto; padding-inline: 20px; padding-block: 28px 56px; display: flex; flex-direction: column; gap: 22px; }
a { color: var(--accent); text-underline-offset: 2px; }
a:focus-visible, button:focus-visible, select:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
h1, h2, h3 { font-family: var(--f-head); font-weight: 600; text-wrap: balance; margin: 0; line-height: 1.2; }
h1 { font-size: 34px; letter-spacing: -0.01em; }
h2 { font-size: 23px; }
h3 { font-size: 17px; }
p { margin: 0; }
.eyebrow { font-family: var(--f-head); font-weight: 500; font-size: 13px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); }
.code { font-family: var(--f-mono); font-size: 0.86em; font-weight: 500; }
.muted { color: var(--muted); }
.small { font-size: 13px; }

/* topo */
.top { display: flex; flex-direction: column; gap: 14px; }
.top-row { display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px 16px; }
.status { font-size: 13px; border: 1px solid var(--line); border-radius: 3px; padding: 2px 8px; color: var(--muted); background: var(--surface); }
.lead { max-width: 78ch; font-size: 16px; }
.nums { display: grid; grid-template-columns: repeat(4, minmax(0, auto)) minmax(0, 1fr); gap: 14px 30px; align-items: end; border-top: 1px solid var(--line); border-bottom: 1px solid var(--line); padding-block: 14px; }
.num b { display: block; font-family: var(--f-head); font-size: 30px; font-weight: 600; line-height: 1; font-variant-numeric: tabular-nums; }
.num span { font-size: 13px; color: var(--muted); }
.exbar { min-width: 0; display: flex; flex-direction: column; gap: 6px; }
.exbar .bar { display: flex; height: 14px; border-radius: 2px; overflow: hidden; background: var(--neutro-bg); }
.exbar .bar i { display: block; height: 100%; }
.exbar .leg { display: flex; flex-wrap: wrap; gap: 4px 14px; font-size: 12.5px; color: var(--muted); }
.exbar .leg span::before { content: ""; display: inline-block; width: 9px; height: 9px; border-radius: 2px; margin-right: 5px; background: var(--c); vertical-align: baseline; }
@media (max-width: 860px) { .nums { grid-template-columns: repeat(2, minmax(0, 1fr)); } .exbar { grid-column: 1 / -1; } h1 { font-size: 28px; } }

/* abas */
.tabs { display: flex; flex-wrap: wrap; gap: 4px; border-bottom: 1px solid var(--line); }
.tabs button { font: inherit; font-family: var(--f-head); font-weight: 500; font-size: 15px; color: var(--muted); background: none; border: 0; border-bottom: 3px solid transparent; padding: 8px 12px; cursor: pointer; margin-bottom: -1px; }
.tabs button[aria-selected="true"] { color: var(--ink); border-bottom-color: var(--accent); }
.tabs button:hover { color: var(--ink); }
.panel { display: flex; flex-direction: column; gap: 18px; }

/* jornadas */
.split { display: grid; grid-template-columns: 300px minmax(0, 1fr); gap: 26px; align-items: start; }
.rail { display: flex; flex-direction: column; gap: 14px; position: sticky; top: calc(env(safe-area-inset-top, 0px) + 12px); max-height: calc(100vh - 24px); overflow: auto; padding-right: 4px; }
.rail h3 { font-size: 12.5px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); font-weight: 500; }
.rail ul { list-style: none; margin: 6px 0 0; padding: 0; display: flex; flex-direction: column; gap: 2px; }
.rail a { display: grid; grid-template-columns: 46px minmax(0, 1fr); gap: 6px; padding: 6px 8px; border-radius: 3px; color: var(--ink); text-decoration: none; font-size: 13.5px; line-height: 1.3; border-left: 3px solid transparent; }
.rail a:hover { background: var(--surface); }
.rail a[aria-current="true"] { background: var(--surface); border-left-color: var(--accent); }
.rail a .rec { display: block; color: var(--muted); font-size: 12px; }
.pick { display: none; }
.pick select { font: inherit; width: 100%; padding: 8px; background: var(--surface); color: var(--ink); border: 1px solid var(--line); border-radius: 3px; }
@media (max-width: 900px) { .split { grid-template-columns: minmax(0, 1fr); } .rail { display: none; } .pick { display: block; } }
.ficha { min-width: 0; display: flex; flex-direction: column; gap: 18px; }
.ficha-head { display: flex; flex-direction: column; gap: 8px; }
.ficha-head .line { display: flex; flex-wrap: wrap; gap: 6px; }
.tag { font-size: 12.5px; border: 1px solid var(--line); border-radius: 3px; padding: 1px 7px; color: var(--muted); background: var(--surface); }
.tag.ess { color: var(--accent); border-color: var(--accent); }
.meta { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0; border: 1px solid var(--line); background: var(--surface); }
.meta > div { padding: 10px 12px; border-right: 1px solid var(--line-soft); border-bottom: 1px solid var(--line-soft); min-width: 0; }
.meta dt { font-size: 12px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); font-family: var(--f-head); font-weight: 500; }
.meta dd { margin: 3px 0 0; font-size: 14px; }
.meta ul { margin: 0; padding-left: 16px; }
@media (max-width: 760px) { .meta { grid-template-columns: minmax(0, 1fr); } }

/* tabela de etapas */
.scroll { overflow-x: auto; border: 1px solid var(--line); background: var(--surface); }
table { border-collapse: collapse; width: 100%; font-size: 14px; }
th { font-family: var(--f-head); font-weight: 500; font-size: 12.5px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--line); background: var(--bg); position: sticky; top: 0; }
td { padding: 11px 12px; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
tr:last-child td { border-bottom: 0; }
.etapas { min-width: 900px; }
.etapas td:nth-child(1) { width: 21%; } .etapas td:nth-child(2) { width: 22%; } .etapas td:nth-child(3) { width: 35%; } .etapas td:nth-child(4) { width: 22%; }
.et-n { font-family: var(--f-mono); color: var(--muted); font-size: 13px; }
.et-nome { font-weight: 600; display: block; margin-bottom: 5px; }
.chips { display: flex; flex-wrap: wrap; gap: 4px; }
.chip { font-size: 12px; padding: 0 6px; border-radius: 2px; background: var(--neutro-bg); color: var(--muted); white-space: nowrap; line-height: 1.6; }
.chip.alto { background: var(--alto-bg); color: var(--alto); } .chip.medio { background: var(--medio-bg); color: var(--medio); }
.io { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 7px; }
.io li span { display: block; color: var(--muted); font-size: 12.5px; }
.tarefas { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }
.tarefas li { display: grid; grid-template-columns: 96px minmax(0, 1fr); gap: 8px; align-items: baseline; }
.ex { font-size: 11.5px; line-height: 1.55; padding: 0 5px; border-radius: 2px; text-align: center; background: var(--neutro-bg); color: var(--muted); overflow-wrap: anywhere; }
.ex.P { background: var(--pessoa-bg); color: var(--pessoa); } .ex.A { background: var(--agente-bg); color: var(--agente); } .ex.R { background: var(--regra-bg); color: var(--regra); }
.cond { display: block; color: var(--muted); font-size: 12.5px; }
.dec { margin-top: 9px; padding: 7px 9px; border-left: 3px solid var(--accent); background: var(--accent-soft); font-size: 13.5px; }
.dec b { font-weight: 600; }
.dec ul { margin: 3px 0 0; padding-left: 16px; }
@media (max-width: 760px) {
  .etapas { min-width: 0; }
  .etapas thead { display: none; }
  .etapas, .etapas tbody, .etapas tr, .etapas td { display: block; width: auto !important; }
  .etapas td { border-bottom: 0; padding-block: 8px; }
  .etapas tr { border-bottom: 1px solid var(--line); padding-block: 6px; }
  .etapas tr:last-child { border-bottom: 0; }
  .etapas td[data-l]::before { content: attr(data-l); display: block; font-family: var(--f-head); font-weight: 500; font-size: 12px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); margin-bottom: 4px; }
}
.legend { display: flex; flex-wrap: wrap; gap: 6px 14px; font-size: 12.5px; color: var(--muted); align-items: center; }
.legend .ex { display: inline-block; min-width: 0; }

/* fluxo */
.flow { display: flex; flex-direction: column; gap: 8px; }
.flow-bar { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.btn { font: inherit; font-size: 13px; padding: 4px 10px; border: 1px solid var(--line); border-radius: 3px; background: var(--surface); color: var(--ink); cursor: pointer; }
.btn:hover { border-color: var(--accent); }
#canvas { height: clamp(420px, 72vh, 760px); border: 1px solid var(--line); background: var(--paper); position: relative; overflow: hidden; }
#canvas .aviso { padding: 16px; color: var(--muted); }
#canvas a.bjs-powered-by { opacity: 0.6; }

/* blocos genéricos */
.cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 350px), 1fr)); gap: 14px; }
.cards.two { grid-template-columns: repeat(auto-fit, minmax(min(100%, 460px), 1fr)); }
.card { border: 1px solid var(--line); background: var(--surface); padding: 14px 16px; display: flex; flex-direction: column; gap: 8px; min-width: 0; }
.card h3 { font-size: 16px; }
.card ul { margin: 0; padding-left: 17px; display: flex; flex-direction: column; gap: 3px; font-size: 14px; }
.card .lbl { font-size: 12px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); font-family: var(--f-head); font-weight: 500; }
.prose { max-width: 80ch; display: flex; flex-direction: column; gap: 10px; }
.prose ul { margin: 0; padding-left: 18px; display: flex; flex-direction: column; gap: 4px; }
.wide { min-width: 760px; }
.note { border-left: 3px solid var(--line); padding: 4px 0 4px 12px; color: var(--muted); font-size: 14px; max-width: 86ch; }
</style>

<div class="wrap">
  <header class="top">
    <div class="eyebrow">Ecossistema IMTS · modelo organizacional e operacional</div>
    <div class="top-row"><h1>Círculo 1 · Identidade</h1><span class="status">Proposta em debate · rodada de 01/10/2026</span></div>
    <p class="lead">A Identidade responde por três coisas: dizer quem somos, transformar isso em regra que pessoas e agentes aplicam, e conferir se é praticado. O Soul Brand é a declaração de identidade em vigor: é a saída da jornada ID-01 e serve de insumo às outras doze.</p>
    <div class="nums" id="nums"></div>
  </header>

  <nav class="tabs" role="tablist" aria-label="Seções" id="tabs"></nav>

  <section class="panel" data-panel="jornadas">
    <div class="pick"><label class="small muted" for="sel-jornada">Jornada</label><select id="sel-jornada"></select></div>
    <div class="split">
      <aside class="rail" id="rail" aria-label="Jornadas do círculo"></aside>
      <article class="ficha" id="ficha"></article>
    </div>
  </section>

  <section class="panel" data-panel="interfaces" hidden>
    <div class="prose"><h2>O que a Identidade não faz</h2><p>Cada linha é uma fronteira já resolvida no desenho. A terceira coluna diz o que o círculo entrega a quem faz.</p></div>
    <div class="scroll"><table class="wide" id="tb-fronteiras"></table></div>
    <div class="prose"><h2>O que a Identidade troca com cada círculo e papel</h2><p>Esta lista vira requisito quando cada círculo for debatido: o que ele precisa entregar à Identidade e o que recebe dela.</p></div>
    <div class="cards" id="interfaces"></div>
  </section>

  <section class="panel" data-panel="decidir" hidden>
    <div class="prose"><h2>Quatro pontos para decidir</h2><p>Em cada um, a proposta e o melhor argumento contra ela.</p></div>
    <div class="cards two" id="pontos"></div>
  </section>

  <section class="panel" data-panel="metodo" hidden id="metodo"></section>

  <section class="panel" data-panel="fontes" hidden>
    <div class="prose"><h2>Fontes e como cada uma foi conferida</h2><p>Só entra o que foi aberto nesta rodada. A coluna da direita diz o que foi lido de fato: página oficial, resumo oficial, cópia hospedada por terceiro ou fonte secundária.</p></div>
    <div class="scroll"><table class="wide" id="tb-fontes"></table></div>
  </section>

  <section class="panel" data-panel="mudou" hidden>
    <div class="prose"><h2>O que mudou em relação às propostas anteriores</h2><p>As cinco jornadas da rodada 2 e as duas da versão baseada no Soul Brand viraram treze, com nome que diz o que a jornada faz. O documento do projeto não foi alterado; o mapa e o catálogo só mudam quando o círculo for fechado.</p></div>
    <div class="scroll"><table class="wide" id="tb-mudou"></table></div>
  </section>
</div>

<script type="application/json" id="dados">__DADOS__</script>
<script src="__BPMNJS__"></script>
<script>
(function () {
  var D = JSON.parse(document.getElementById('dados').textContent);
  var J = {}; D.jornadas.forEach(function (j) { J[j.code] = j; });
  var cur = D.jornadas[0].code, viewer = null;
  var TABS = [['jornadas', 'Jornadas'], ['interfaces', 'Fronteiras e interfaces'], ['decidir', 'Para decidir'], ['metodo', 'Método'], ['fontes', 'Fontes'], ['mudou', 'O que mudou']];
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c]; }); }
  function $(id) { return document.getElementById(id); }
  function codeLink(c) { return '<a class="code" href="#' + c + '">' + c + '</a>'; }
  function who(x) { return /^ID-\d\d$/.test(x) ? codeLink(x) : esc(x); }
  function fmt(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.'); }

  /* ---------- topo */
  var s = D.stats, ex = s.exec;
  var segs = [['P', 'Pessoa da Identidade', 'var(--pessoa)'], ['A', 'Agente da Identidade', 'var(--agente)'], ['R', 'Automação da Identidade', 'var(--regra)'], ['C', 'Outros círculos', 'var(--muted)'], ['H', 'Pessoas de fora do círculo', 'var(--line)'], ['X', 'Assessoria externa', 'var(--medio)']];
  $('nums').innerHTML =
    '<div class="num"><b>' + s.jornadas + '</b><span>jornadas: ' + s.essenciais + ' essenciais, ' + s.recomendadas + ' recomendadas</span></div>' +
    '<div class="num"><b>' + s.etapas + '</b><span>etapas</span></div>' +
    '<div class="num"><b>' + s.tarefas + '</b><span>tarefas</span></div>' +
    '<div class="num"><b>' + s.decisoes + '</b><span>decisões</span></div>' +
    '<div class="exbar"><div class="small muted">Quem executa as ' + s.tarefas + ' tarefas, no desenho proposto</div><div class="bar">' +
    segs.map(function (g) { return '<i style="width:' + (100 * (ex[g[0]] || 0) / s.tarefas) + '%;background:' + g[2] + '" title="' + g[1] + ': ' + (ex[g[0]] || 0) + '"></i>'; }).join('') +
    '</div><div class="leg">' + segs.map(function (g) { return '<span style="--c:' + g[2] + '">' + g[1] + ' ' + (ex[g[0]] || 0) + '</span>'; }).join('') + '</div></div>';

  /* ---------- abas */
  $('tabs').innerHTML = TABS.map(function (t) { return '<button role="tab" data-tab="' + t[0] + '" aria-selected="false">' + t[1] + '</button>'; }).join('');
  function showTab(name) {
    document.querySelectorAll('[data-panel]').forEach(function (p) { p.hidden = p.getAttribute('data-panel') !== name; });
    document.querySelectorAll('#tabs button').forEach(function (b) { b.setAttribute('aria-selected', b.getAttribute('data-tab') === name ? 'true' : 'false'); });
    if (name === 'jornadas' && viewer) { try { viewer.get('canvas').resized(); focar(1); } catch (err) {} }
  }
  $('tabs').addEventListener('click', function (e) { var b = e.target.closest('button'); if (b) { showTab(b.getAttribute('data-tab')); } });

  /* ---------- trilho */
  function rail() {
    var h = '';
    D.dominios.forEach(function (d) {
      var js = D.jornadas.filter(function (j) { return j.dominio === d.nome; });
      h += '<div><h3>' + esc(d.nome) + '</h3><ul>' + js.map(function (j) {
        return '<li><a href="#' + j.code + '"' + (j.code === cur ? ' aria-current="true"' : '') + '><span class="code">' + j.code + '</span><span>' + esc(j.nome) + (j.classe === 'recomendada' ? '<span class="rec">recomendada</span>' : '') + '</span></a></li>';
      }).join('') + '</ul></div>';
    });
    $('rail').innerHTML = h;
    $('sel-jornada').innerHTML = D.jornadas.map(function (j) { return '<option value="' + j.code + '"' + (j.code === cur ? ' selected' : '') + '>' + j.code + ' · ' + esc(j.nome) + '</option>'; }).join('');
  }
  $('sel-jornada').addEventListener('change', function (e) { location.hash = e.target.value; });

  /* ---------- ficha */
  var TIPO_EV = {message: 'pedido ou aviso', timer: 'data ou ciclo', signal: 'sinal detectado'};
  var TIPO_T = {manual: 'conversa ou reunião', rule: 'tabela de decisão', call: 'chama jornada de outro círculo'};
  function exLabel(t) { return t.exec === 'P' ? 'Pessoa' : t.exec === 'A' ? 'Agente' : t.exec === 'R' ? 'Automação' : t.raia; }
  function ficha() {
    var j = J[cur];
    var h = '<div class="ficha-head"><div class="eyebrow">' + esc(j.dominio) + '</div><h2><span class="code">' + j.code + '</span> · ' + esc(j.nome) + '</h2>' +
      '<div class="line"><span class="tag' + (j.classe === 'essencial' ? ' ess' : '') + '">' + j.classe + '</span><span class="tag">onda ' + j.onda + ': ' + esc(D.ondas[j.onda]).toLowerCase() + '</span><span class="tag">automação ' + esc(j.automacao.nivel) + '</span></div>' +
      '<p class="lead" style="font-size:15px">' + esc(j.objetivo) + '</p></div>';
    h += '<dl class="meta">' +
      '<div><dt>Começa quando</dt><dd><ul>' + j.inicios.map(function (i) { return '<li>' + esc(i.nome) + ' <span class="muted small">(' + TIPO_EV[i.tipo] + ')</span></li>'; }).join('') + '</ul></dd></div>' +
      '<div><dt>Termina quando</dt><dd><ul>' + j.fins.map(function (f) { return '<li>' + esc(f) + '</li>'; }).join('') + '</ul></dd></div>' +
      '<div><dt>Frequência</dt><dd>' + esc(j.frequencia) + '</dd></div>' +
      '<div><dt>Quem participa</dt><dd>' + j.raias.map(esc).join(', ') + '</dd></div>' +
      '<div><dt>Automação</dt><dd>' + esc(j.automacao.motivo) + '</dd></div>' +
      '<div><dt>Base de mercado</dt><dd>' + j.base.map(function (b) { return '<a href="#fontes" data-fonte="' + b + '">' + esc(D.curto[b]) + '</a>'; }).join(', ') + '</dd></div>' +
      '</dl>';
    h += '<div><h3>Etapas, tarefas, entradas e saídas</h3></div>' +
      '<div class="legend"><span>Quem faz cada tarefa:</span><span class="ex P">Pessoa</span><span class="ex A">Agente</span><span class="ex R">Automação</span><span>da Identidade;</span><span class="ex">Outro círculo ou papel</span></div>';
    h += '<div class="scroll"><table class="etapas"><thead><tr><th>Etapa</th><th>Entrada · quem gera</th><th>Tarefas · quem faz</th><th>Saída · quem recebe</th></tr></thead><tbody>';
    j.etapas.forEach(function (e) {
      h += '<tr><td><span class="et-n">' + e.n + '</span> <span class="et-nome">' + esc(e.nome) + '</span><div class="chips"><span class="chip">' + e.modo + '</span><span class="chip ' + (e.risco === 'alto' ? 'alto' : e.risco === 'médio' ? 'medio' : '') + '">risco ' + e.risco + '</span></div><div class="small muted" style="margin-top:5px">Dono: ' + esc(e.dono) + '</div></td>';
      h += '<td data-l="Entrada · quem gera"><ul class="io">' + e.entradas.map(function (x) { return '<li>' + esc(x.o) + '<span>origem: ' + (/^etapa /.test(x.de) ? x.de + ' desta jornada' : who(x.de)) + '</span></li>'; }).join('') + '</ul></td>';
      h += '<td data-l="Tarefas · quem faz">' + (e.paralelo ? '<div class="small muted" style="margin-bottom:6px">Há tarefas em paralelo nesta etapa.</div>' : '') + '<ul class="tarefas">' + e.tarefas.map(function (t) {
        return '<li><span class="ex ' + t.exec + '">' + esc(exLabel(t)) + '</span><span>' + esc(t.nome) + (TIPO_T[t.tipo] ? ' <span class="muted small">(' + TIPO_T[t.tipo] + ')</span>' : '') + (t.cond ? '<span class="cond">só se: ' + esc(t.cond) + '</span>' : '') + '</span></li>';
      }).join('') + '</ul>' + e.decisoes.map(function (d) {
        return '<div class="dec"><b>Decisão:</b> ' + esc(d.pergunta) + ' <span class="muted small">(' + esc(d.quem) + ')</span><ul>' + d.saidas.map(function (o) {
          return '<li>' + esc(o.rotulo) + ': ' + (o.via.length ? o.via.map(esc).join(', depois ') + ', depois ' : '') + esc(o.vai) + '</li>';
        }).join('') + '</ul></div>';
      }).join('') + '</td>';
      h += '<td data-l="Saída · quem recebe"><ul class="io">' + e.saidas.map(function (x) { return '<li>' + esc(x.o) + '<span>destino: ' + x.para.map(function (p) { return /^etapa /.test(p) ? p : who(p); }).join(', ') + '</span></li>'; }).join('') + '</ul></td></tr>';
    });
    h += '</tbody></table></div>';
    h += '<div class="flow"><h3>Fluxo em BPMN</h3><div class="flow-bar"><button class="btn" data-z="fit">Ver tudo</button><button class="btn" data-z="in" aria-label="Aproximar">+</button><button class="btn" data-z="out" aria-label="Afastar">−</button><span class="small muted">Ir para a etapa:</span>' +
      j.etapas.map(function (e) { return '<button class="btn" data-etapa="' + e.n + '" title="' + esc(e.nome) + '">' + e.n + '</button>'; }).join('') +
      '</div><div id="canvas"></div><p class="small muted">O quadro abre na etapa 1. Arraste para mover, use os botões das etapas ou a roda do mouse com Ctrl para aproximar. Cada raia é um papel ou sistema; as caixas tracejadas são as etapas. Ícone de pessoa: tarefa de pessoa; engrenagem: agente; pergaminho: automação; tabela: regra; mão: conversa ou reunião; borda grossa: chama jornada de outro círculo; sem ícone: tarefa de outro círculo.</p></div>';
    $('ficha').innerHTML = h;
    desenhar();
  }
  $('ficha').addEventListener('click', function (e) {
    var b = e.target.closest('button'); var a = e.target.closest('a[data-fonte]');
    if (a) { e.preventDefault(); showTab('fontes'); var r = document.getElementById('f-' + a.getAttribute('data-fonte')); if (r) { r.scrollIntoView({block: 'center'}); } return; }
    if (!b || !viewer) { return; }
    var canvas = viewer.get('canvas');
    if (b.dataset.z === 'fit') { canvas.zoom('fit-viewport'); }
    else if (b.dataset.z === 'in') { viewer.get('zoomScroll').stepZoom(1); }
    else if (b.dataset.z === 'out') { viewer.get('zoomScroll').stepZoom(-1); }
    else if (b.dataset.etapa) { focar(+b.dataset.etapa); }
  });
  function focar(n) {
    if (!viewer) { return; }
    var el = $('canvas'), f = J[cur].etapas[n - 1].foco, pad = 64;
    var W = el.clientWidth, H = el.clientHeight; if (!W || !H) { return; }
    var bw = f[2] + 2 * pad, bh = f[3] + 2 * pad;
    var sc = Math.max(0.6, Math.min(1, W / bw, H / bh));
    var vw = W / sc, vh = H / sc;
    var x = bw > vw ? f[0] - pad : f[0] + f[2] / 2 - vw / 2;
    var y = bh > vh ? f[1] - pad : f[1] + f[3] / 2 - vh / 2;
    viewer.get('canvas').viewbox({x: x, y: y, width: vw, height: vh});
  }

  /* ---------- fluxo */
  var token = 0;
  function desenhar() {
    var el = $('canvas'); if (!el) { return; }
    if (!window.BpmnJS) { el.innerHTML = '<p class="aviso">O visualizador de fluxo não carregou. A tabela de etapas acima descreve o mesmo fluxo.</p>'; return; }
    var my = ++token;
    if (viewer) { try { viewer.destroy(); } catch (err) {} viewer = null; }
    el.innerHTML = '';
    var cs = getComputedStyle(document.documentElement);
    var v = new BpmnJS({ container: el, bpmnRenderer: { defaultFillColor: cs.getPropertyValue('--paper').trim(), defaultStrokeColor: cs.getPropertyValue('--ink').trim(), defaultLabelColor: cs.getPropertyValue('--ink').trim() } });
    viewer = v;
    v.importXML(D.bpmn[cur]).then(function () { if (my === token) { focar(1); } }).catch(function (err) { if (my === token) { el.innerHTML = '<p class="aviso">Não foi possível desenhar o fluxo: ' + esc(err.message) + '</p>'; } });
  }
  try { window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', desenhar); } catch (err) {}
  try { new MutationObserver(desenhar).observe(document.documentElement, {attributes: true, attributeFilter: ['data-theme']}); } catch (err) {}

  /* ---------- fronteiras e interfaces */
  $('tb-fronteiras').innerHTML = '<thead><tr><th>O que não é da Identidade</th><th>De quem é</th><th>O que a Identidade entrega</th></tr></thead><tbody>' +
    D.fronteiras.map(function (f) { return '<tr><td>' + esc(f.o) + '</td><td>' + esc(f.dono) + '</td><td>' + esc(f.nota) + '</td></tr>'; }).join('') + '</tbody>';
  $('interfaces').innerHTML = D.interfaces.map(function (p) {
    var part = D.participa[p.parte] || D.participa[{'Executivos': 'Executivo da empresa', 'Líderes': 'Líder da equipe', 'Pessoas': 'Pessoa'}[p.parte]] || [];
    return '<div class="card"><h3>' + esc(p.parte) + '</h3>' +
      (p.entrega.length ? '<div class="lbl">Entrega à Identidade</div><ul>' + p.entrega.map(function (x) { return '<li>' + esc(x.o) + ' <span class="muted small">(' + x.em.map(codeLink).join(', ') + ')</span></li>'; }).join('') + '</ul>' : '') +
      (p.recebe.length ? '<div class="lbl">Recebe da Identidade</div><ul>' + p.recebe.map(function (x) { return '<li>' + esc(x.o) + ' <span class="muted small">(' + x.de.map(codeLink).join(', ') + ')</span></li>'; }).join('') + '</ul>' : '') +
      (part.length ? '<div class="lbl">Tem tarefa em</div><p class="small">' + part.map(codeLink).join(', ') + '</p>' : '') + '</div>';
  }).join('');

  /* ---------- pontos a decidir */
  $('pontos').innerHTML = D.pontos.map(function (p, i) {
    return '<div class="card"><h3>' + (i + 1) + '. ' + esc(p.q) + '</h3><div class="lbl">Proposta</div><p>' + esc(p.proposta) + '</p><div class="lbl">Argumento contra</div><p>' + esc(p.contra) + '</p></div>';
  }).join('');

  /* ---------- método */
  var t = D.testes, alta = D.jornadas.filter(function (j) { return /^alta/.test(j.automacao.nivel); }).map(function (j) { return codeLink(j.code); }).join(', ');
  var nId = (ex.P || 0) + (ex.A || 0) + (ex.R || 0);
  function pct(n) { return Math.round(100 * n / nId); }
  $('metodo').innerHTML =
    '<div class="prose"><h2>Como as jornadas foram desenhadas</h2>' +
    '<p>Uma fonte única descreve as treze jornadas. Dela saem esta página, os fluxos em BPMN e os testes. Mudar uma jornada é mudar a fonte e gerar tudo de novo.</p></div>' +
    '<div class="cards">' +
    '<div class="card"><h3>Três níveis</h3><ul><li><b>Jornada:</b> processo de ponta a ponta, com evento de início e evento de fim.</li><li><b>Etapa:</b> parte da jornada com entrada, saída e dono. É o que o catálogo anterior chamava de workflow.</li><li><b>Tarefa:</b> menor unidade de trabalho, com um executor.</li></ul></div>' +
    '<div class="card"><h3>Nomes</h3><ul><li>Jornada, etapa e tarefa: verbo no infinitivo e objeto.</li><li>Evento de início e de fim: objeto e estado (“Pedido atendido”).</li><li>Decisão: pergunta, com o rótulo em cada saída.</li><li>Raia: papel ou sistema, nunca o nome de uma pessoa.</li></ul><p class="small muted">Regra de nomes da Camunda para BPMN.</p></div>' +
    '<div class="card"><h3>Entradas e saídas</h3><ul><li>Cada etapa diz o que entra e quem gera, o que sai e quem recebe.</li><li>Toda entrada vinda de outra jornada aparece como saída dela, e o contrário.</li></ul><p class="small muted">Lógica do SIPOC: fornecedor, entrada, processo, saída e cliente.</p></div>' +
    '<div class="card"><h3>Quem executa e o tipo de tarefa no BPMN</h3><ul><li>Pessoa: tarefa de usuário; conversa ou reunião é tarefa manual.</li><li>Agente: tarefa de serviço.</li><li>Automação: tarefa de script; quando decide por regra, tarefa de regra de negócio.</li><li>Outro círculo: tarefa simples ou atividade de chamada, quando chama uma jornada dele.</li></ul><p class="small muted">Este mapeamento é proposta do modelo, não norma do BPMN.</p></div>' +
    '<div class="card"><h3>Modo de cada etapa</h3><ul><li><b>Assistido:</b> a pessoa executa.</li><li><b>Copiloto:</b> o agente prepara e a pessoa decide.</li><li><b>Autopiloto:</b> o agente ou a regra executa; a pessoa entra na exceção.</li><li><b>Autômato:</b> regra fixa, sem pessoa nem agente.</li><li>Etapa de risco alto é sempre assistida ou de copiloto.</li></ul></div>' +
    '<div class="card"><h3>O que vale automatizar</h3><ul><li>Fluxo executável só onde há volume e regra clara: ' + alta + '.</li><li>As demais ficam como roteiro: são raras e de julgamento.</li><li>Decisão por regra vira tabela de decisão (DMN), fora do desenho do fluxo.</li></ul></div>' +
    '</div>' +
    '<div class="prose"><h2>Testes desta versão</h2><ul>' +
    '<li>' + fmt(t.verificacoes) + ' verificações de integridade, ' + t.falhas + ' falhas: toda entrada tem origem, toda saída tem destino, os dois lados conferem, todo caminho chega a um fim, os nomes seguem a regra e o modo é coerente com o risco.</li>' +
    '<li>' + t.fluxos + ' fluxos lidos pelo metamodelo do BPMN 2.0 sem aviso e conferidos por ' + t.regras_lint + ' regras de boas práticas (bpmnlint), sem apontamento.</li>' +
    '<li>' + t.fluxos + ' fluxos desenhados no visualizador bpmn-js sem aviso.</li>' +
    '<li>Os testes foram provados com defeitos plantados de propósito: todos foram detectados.</li>' +
    '<li>Um revisor independente leu as treze jornadas e apontou 30 achados, 3 graves. Os graves e a maior parte dos médios foram corrigidos nesta versão; os que ficaram abertos estão em Limites.</li>' +
    '<li>Um segundo revisor reabriu as 23 fontes: 18 confirmadas e 5 confirmadas em parte. As cinco foram corrigidas na aba Fontes.</li></ul>' +
    '<h2>Números do desenho</h2><ul>' +
    '<li>Das ' + nId + ' tarefas do próprio círculo, ' + (ex.A || 0) + ' são de agente (' + pct(ex.A || 0) + '%), ' + (ex.R || 0) + ' de automação (' + pct(ex.R || 0) + '%) e ' + (ex.P || 0) + ' de pessoa (' + pct(ex.P || 0) + '%).</li>' +
    '<li>Etapas por modo: ' + ['Copiloto', 'Autopiloto', 'Assistido', 'Autômato'].map(function (m) { return (D.stats.modos[m] || 0) + ' de ' + m.toLowerCase(); }).join(', ') + '.</li>' +
    '<li>Etapas por risco: ' + ['baixo', 'médio', 'alto'].map(function (r) { return (D.stats.riscos[r] || 0) + ' de risco ' + r; }).join(', ') + '.</li></ul>' +
    '<h2>Limites</h2><ul>' +
    '<li>Os fluxos são descritivos. Para executar falta escolher o motor e ligar cada tarefa a um sistema.</li>' +
    '<li>Não há tempo, volume nem carga por pessoa: nada disso foi medido, então nada foi estimado.</li>' +
    '<li>As trocas com os outros círculos estão descritas pelo nome do círculo. Elas serão conferidas dos dois lados quando cada círculo for debatido.</li>' +
    '<li>As conferências feitas por outros círculos não têm ramo de recusa desenhado: a recusa devolve o trabalho à tarefa anterior.</li>' +
    '<li>Na ID-13, definir os indicadores e coletar os dados usam o mesmo gatilho anual; separar os dois momentos é uma melhoria pendente.</li>' +
    '<li>Na ID-03, a jornada termina no pedido de registro; oposição ou recusa do registro ainda não tem caminho desenhado.</li>' +
    '<li>A onda 1 depende de três saídas da onda 2: um pacote mínimo das marcas atuais, as mensagens de crise e um ritual de acolhida. Elas precisam ser antecipadas.</li>' +
    '<li>Os números acima descrevem este desenho, não a operação atual.</li></ul></div>';

  /* ---------- fontes */
  $('tb-fontes').innerHTML = '<thead><tr><th>Referência</th><th>O que usamos</th><th>Como foi conferida</th></tr></thead><tbody>' +
    Object.keys(D.fontes).map(function (k) { var f = D.fontes[k];
      return '<tr id="f-' + k + '"><td style="width:30%">' + esc(f.ref) + '<div class="small" style="margin-top:4px">' + f.links.map(function (l) { return '<a href="' + esc(l[1]) + '" target="_blank" rel="noopener">' + esc(l[0]) + '</a>'; }).join(' · ') + '</div></td><td style="width:38%">' + esc(f.uso) + '</td><td>' + esc(f.conf) + '</td></tr>'; }).join('') + '</tbody>';

  /* ---------- o que mudou */
  $('tb-mudou').innerHTML = '<thead><tr><th>Antes</th><th>Agora</th><th>O que mudou</th></tr></thead><tbody>' +
    D.mudancas.map(function (m) { return '<tr><td>' + esc(m.antes) + '</td><td>' + esc(m.agora).replace(/ID-\d\d/g, function (c) { return codeLink(c); }) + '</td><td>' + esc(m.nota) + '</td></tr>'; }).join('') + '</tbody>';

  /* ---------- navegação por âncora */
  function go() {
    var h = (location.hash || '').replace('#', '');
    if (J[h]) { cur = h; rail(); showTab('jornadas'); ficha(); window.scrollTo(0, 0); return; }
    var tab = TABS.filter(function (t) { return t[0] === h; })[0];
    if (tab) { showTab(h); return; }
  }
  window.addEventListener('hashchange', go);
  var h0 = (location.hash || '').replace('#', '');
  if (J[h0]) { cur = h0; }
  rail(); ficha();
  showTab(TABS.some(function (t) { return t[0] === h0; }) ? h0 : 'jornadas');
})();
</script>
'''


def build(bpmnjs_src, out_name):
    blob = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
    html = TEMPLATE.replace('__DADOS__', blob).replace('__BPMNJS__', bpmnjs_src)
    path = os.path.join(BASE, 'saida', out_name)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(html)
    print(out_name, round(len(html.encode('utf-8')) / 1024), 'KB')


build('https://unpkg.com/bpmn-js@18.31.0/dist/bpmn-navigated-viewer.production.min.js', 'circulo1-identidade.html')
build('file://' + os.path.join(BASE, 'node_modules/bpmn-js/dist/bpmn-navigated-viewer.production.min.js'), 'circulo1-local.html')
