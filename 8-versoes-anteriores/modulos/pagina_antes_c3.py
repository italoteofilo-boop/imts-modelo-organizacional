# -*- coding: utf-8 -*-
"""Monta a página de um círculo a partir de saida/<mod>/circulo.json, testes.json e do cruzamento.
Uso: python3 pagina.py c1"""
import json, os, sys

MOD = sys.argv[1]
BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, 'saida', MOD)
data = json.load(open(os.path.join(OUT, 'circulo.json'), encoding='utf-8'))
C = data['circulo']
from circulos import NAV
from dsl import ARTIGO

CURTO = {
    'apqc': 'APQC PCF', 'collins': 'Collins e Porras, 1996', 'iso37000': 'ISO 37000:2021', 'pas808': 'PAS 808:2022',
    'quinn': 'Quinn e Thakor, 2018', 'hatch': 'Hatch e Schultz, 2001', 'aaker': 'Aaker e Joachimsthaler, 2000',
    'wheeler': 'Wheeler', 'inpi': 'INPI', 'iso20671': 'ISO 20671-1:2021', 'iso10010': 'ISO 10010:2022',
    'mckinsey': 'McKinsey, 2016', 'schein': 'Schein', 'craig': 'Craig e Snook, 2014', 'reptrak': 'RepTrak, 2026',
    'iso22361': 'ISO 22361:2022', 'nng': 'NN/g, 2016', 'google_persona': 'Google, persona', 'impact': 'Impact Frontiers',
    'bpmn': 'BPMN 2.0', 'camunda': 'Camunda', 'dmn': 'DMN', 'sipoc': 'SIPOC (ASQ)', 'iia': 'IIA, Três Linhas',
    'kaplan': 'Kaplan e Norton, 2008', 'rumelt': 'Rumelt, 2011', 'okr': 'Google re:Work, OKR', 'lei': 'LEI, hoshin kanri',
    'horizons': 'McKinsey, três horizontes', 'parenting': 'Campbell, Goold e Alexander, 1995',
    'realloc': 'Hall, Lovallo e Musters, 2012', 'stagegate': 'Stage-Gate',
}
data['curto'] = CURTO
data['nav'] = [dict(num=n, nome=nm, estado=e, url=u) for n, nm, e, u in NAV]

# ----- cruzamento com os outros círculos já desenhados
cz = json.load(open(os.path.join(BASE, 'saida', 'cruzamento.json'), encoding='utf-8'))
outros = [c for c in cz['circulos'] if c != C['nome']]
outros_txt = ' e '.join(ARTIGO[o][0] for o in outros)
data['cruz'] = dict(
    outros=outros, outros_txt=outros_txt,
    trocas=[t for t in cz['trocas'] if C['nome'] in (t['de'], t['para'])],
    tarefas=[t for t in cz['tarefas'] if C['nome'] in (t['quem'], t['em'])])

# ----- testes
T = json.load(open(os.path.join(OUT, 'testes.json'), encoding='utf-8'))


def fmt(n):
    return f'{n:,}'.replace(',', '.')


def zero(n, sing, plur):
    return f'sem {sing}' if n == 0 else (f'1 {sing}' if n == 1 else f'{n} {plur}')


tt = []
i, l, r, ro, mu, cr = T['integridade'], T['lint'], T['render'], T['rotulos'], T['mutacao'], T['cruzamento']
tt.append(f'{fmt(i["verificacoes"])} verificações de integridade, {zero(i["problemas"], "falha", "falhas")}: toda entrada tem origem, '
          'toda saída tem destino, os dois lados conferem, todo caminho chega a um fim, os nomes seguem a regra e o modo é coerente com o risco.')
tt.append(f'{l["arquivos"]} fluxos lidos pelo metamodelo do BPMN 2.0 sem aviso e conferidos por {l["regras"]} regras de boas práticas (bpmnlint), '
          f'{zero(l["apontamentos"], "apontamento", "apontamentos")}.')
tt.append(f'{r["arquivos"]} fluxos desenhados no visualizador bpmn-js, {zero(r["avisos"], "aviso", "avisos")}. Dos {ro["tarefas"]} nomes de tarefa, '
          f'{"nenhum fica" if ro["problemas"] == 0 else str(ro["problemas"]) + " ficam"} encoberto pelo ícone ou cortado pela caixa.')
if outros:
    tt.append(f'Trocas com {outros_txt}: {len(data["cruz"]["trocas"])} produtos conferidos dos dois lados '
              f'({cr["verificacoes"]} verificações, {zero(cr["problemas"], "falha", "falhas")}).')
tt.append(f'Os testes foram provados com defeitos plantados de propósito: {mu["detectados"]} de {mu["total"]} detectados na integridade '
          f'e {cr["mut_detectados"]} de {cr["mut_total"]} no cruzamento entre círculos.')
tt += data.get('revisao', [])
data['testes_txt'] = tt
data['testes_ok'] = (i['problemas'] == 0 and l['apontamentos'] == 0 and r['avisos'] == 0 and ro['problemas'] == 0
                     and cr['problemas'] == 0 and mu['detectados'] == mu['total'])

TEMPLATE = r'''<title>__TITLE__</title>
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
a:focus-visible, button:focus-visible, select:focus-visible, summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
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
.status.fechado { color: var(--regra); border-color: var(--regra); background: var(--regra-bg); }
.circulos { display: flex; flex-wrap: wrap; gap: 4px 6px; font-size: 13px; align-items: center; }
.circulos .c { border: 1px solid var(--line); border-radius: 3px; padding: 1px 8px; background: var(--surface); color: var(--muted); text-decoration: none; }
.circulos a.c { color: var(--accent); }
.circulos .c[aria-current="page"] { color: var(--ink); border-color: var(--ink); font-weight: 500; }
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
.meta { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0; border: 1px solid var(--line); background: var(--surface); margin: 0; }
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
.chip.acr { background: var(--agente-bg); color: var(--agente); } .chip.aju { background: var(--regra-bg); color: var(--regra); } .chip.ret { background: var(--alto-bg); color: var(--alto); }
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
.note { border-left: 3px solid var(--accent); padding: 6px 0 6px 12px; font-size: 15px; max-width: 86ch; }

/* jornadas transferidas */
.transfs { display: flex; flex-direction: column; gap: 8px; }
.transf { border: 1px solid var(--line); background: var(--surface); }
.transf > summary { cursor: pointer; padding: 11px 14px; display: grid; grid-template-columns: 96px minmax(0, 1fr) minmax(0, 0.9fr) 92px; gap: 6px 14px; align-items: baseline; list-style: none; }
.transf > summary::-webkit-details-marker { display: none; }
.transf > summary::after { content: "ver rascunho"; color: var(--accent); font-size: 13px; text-align: right; text-decoration: underline; text-underline-offset: 2px; }
.transf[open] > summary::after { content: "fechar"; }
.transf > summary .t-nome { font-weight: 600; }
.transf > summary .t-dest { color: var(--muted); font-size: 13.5px; }
.transf[open] > summary { border-bottom: 1px solid var(--line-soft); }
.transf .corpo { padding: 12px 14px 14px; display: flex; flex-direction: column; gap: 12px; }
@media (max-width: 760px) { .transf > summary { grid-template-columns: minmax(0, 1fr); } }
</style>

<div class="wrap">
  <header class="top">
    <div class="eyebrow">Ecossistema IMTS · modelo organizacional e operacional</div>
    <nav class="circulos" id="circulos" aria-label="Círculos já desenhados"></nav>
    <div class="top-row"><h1 id="titulo"></h1><span class="status" id="status"></span></div>
    <p class="lead" id="lead"></p>
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

  <section class="panel" data-panel="transferidas" hidden>
    <div class="prose" id="transf-intro"></div>
    <div class="transfs" id="transferidas"></div>
  </section>

  <section class="panel" data-panel="interfaces" hidden>
    <div class="prose"><h2 id="h-fronteiras"></h2><p>Cada linha é uma fronteira resolvida no desenho. A terceira coluna diz o que o círculo entrega a quem faz.</p></div>
    <div class="scroll"><table class="wide" id="tb-fronteiras"></table></div>
    <div id="bloco-cruz" class="panel" hidden>
      <div class="prose"><h2 id="h-cruz"></h2><p id="p-cruz"></p></div>
      <div class="scroll"><table class="wide" id="tb-cruz"></table></div>
      <div class="prose" id="cruz-tarefas"></div>
    </div>
    <div class="prose"><h2 id="h-interfaces"></h2><p>Esta lista vira requisito quando cada círculo for desenhado: o que ele precisa entregar e o que recebe.</p></div>
    <div class="cards" id="interfaces"></div>
  </section>

  <section class="panel" data-panel="decidir" hidden>
    <div class="prose"><h2 id="h-pontos"></h2><p>Em cada um, a proposta e o melhor argumento contra ela.</p></div>
    <p class="note" id="principio" hidden></p>
    <div class="cards two" id="pontos"></div>
  </section>

  <section class="panel" data-panel="decisoes" hidden>
    <div class="prose"><h2>Decisões que fecharam o círculo</h2><p>Os horários são os da conversa de 01/10/2026. A coluna do meio separa o que foi regra sua do que foi proposta minha aprovada por você.</p></div>
    <div class="scroll"><table class="wide" id="tb-decisoes"></table></div>
    <div id="bloco-propostas" class="panel" hidden>
      <div class="prose"><h2>Propostas de mudança que aguardam a sua aprovação</h2><p>Mexem em conteúdo que você já aprovou. Nenhuma foi aplicada: o desenho desta página é o aprovado.</p></div>
      <div class="scroll"><table class="wide" id="tb-propostas"></table></div>
    </div>
    <div class="prose"><h2>Alertas que seguem para os próximos círculos</h2></div>
    <div class="cards two" id="alertas"></div>
  </section>

  <section class="panel" data-panel="metodo" hidden id="metodo"></section>

  <section class="panel" data-panel="fontes" hidden>
    <div class="prose"><h2>Fontes e como cada uma foi conferida</h2><p>Só entra o que foi aberto. A coluna da direita diz o que foi lido de fato: página oficial, resumo oficial, cópia hospedada por terceiro ou fonte secundária.</p></div>
    <div class="scroll"><table class="wide" id="tb-fontes"></table></div>
  </section>

  <section class="panel" data-panel="mudou" hidden>
    <div class="prose"><h2>O que mudou</h2><p id="p-mudou"></p></div>
    <div class="scroll"><table class="wide" id="tb-mudou"></table></div>
  </section>
</div>

<script type="application/json" id="dados">__DADOS__</script>
<script src="__BPMNJS__"></script>
<script>
(function () {
  var D = JSON.parse(document.getElementById('dados').textContent);
  var C = D.circulo;
  var J = {}; D.jornadas.forEach(function (j) { J[j.code] = j; });
  var cur = D.jornadas[0].code, viewer = null;
  var RE_COD = new RegExp('^' + C.pref + '-\\d\\d$'), RE_COD_G = new RegExp('\\b' + C.pref + '-\\d\\d\\b', 'g');
  var NUM_F = {1: 'uma', 2: 'duas', 3: 'três', 4: 'quatro', 5: 'cinco', 6: 'seis', 7: 'sete', 8: 'oito', 9: 'nove', 10: 'dez', 11: 'onze', 12: 'doze', 13: 'treze'};
  var NUM_M = {1: 'Um', 2: 'Dois', 3: 'Três', 4: 'Quatro', 5: 'Cinco', 6: 'Seis', 7: 'Sete', 8: 'Oito', 9: 'Nove', 10: 'Dez'};
  var TABS = [['jornadas', 'Jornadas']];
  if (D.transferidas.length) { TABS.push(['transferidas', 'Transferidas']); }
  TABS.push(['interfaces', 'Fronteiras e interfaces']);
  if (D.pontos.length) { TABS.push(['decidir', 'Para decidir']); }
  if (D.decisoes.length) { TABS.push(['decisoes', 'Decisões']); }
  TABS.push(['metodo', 'Método'], ['fontes', 'Fontes'], ['mudou', 'O que mudou']);
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c]; }); }
  function $(id) { return document.getElementById(id); }
  function codeLink(c) { return '<a class="code" href="#' + c + '">' + c + '</a>'; }
  function who(x) { return RE_COD.test(x) ? codeLink(x) : esc(x); }
  function comLinks(t) { return esc(t).replace(RE_COD_G, function (c) { return J[c] ? codeLink(c) : c; }); }
  function fmt(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.'); }

  /* ---------- topo */
  $('titulo').textContent = 'Círculo ' + C.num + ' · ' + C.nome;
  $('status').textContent = C.status; if (C.fechado) { $('status').classList.add('fechado'); }
  $('lead').textContent = C.lead;
  $('circulos').innerHTML = '<span class="muted">Círculos desenhados:</span>' + D.nav.map(function (n) {
    var txt = n.num + ' · ' + esc(n.nome) + ' (' + esc(n.estado) + ')';
    if (n.num === C.num) { return '<span class="c" aria-current="page">' + txt + '</span>'; }
    return n.url ? '<a class="c" href="' + esc(n.url) + '" target="_blank" rel="noopener">' + txt + '</a>' : '<span class="c">' + txt + '</span>';
  }).join('');
  var s = D.stats, ex = s.exec;
  var segs = [['P', D.exec_nome.P, 'var(--pessoa)'], ['A', D.exec_nome.A, 'var(--agente)'], ['R', D.exec_nome.R, 'var(--regra)'], ['C', 'Outros círculos', 'var(--muted)'], ['H', 'Pessoas de fora do círculo', 'var(--line)'], ['X', 'Assessoria externa', 'var(--medio)']];
  $('nums').innerHTML =
    '<div class="num"><b>' + s.jornadas + '</b><span>jornadas' + (s.recomendadas ? ': ' + s.essenciais + ' essenciais, ' + s.recomendadas + ' recomendadas' : ', todas essenciais') + '</span></div>' +
    '<div class="num"><b>' + s.etapas + '</b><span>etapas</span></div>' +
    '<div class="num"><b>' + s.tarefas + '</b><span>tarefas</span></div>' +
    '<div class="num"><b>' + s.decisoes + '</b><span>decisões</span></div>' +
    '<div class="exbar"><div class="small muted">Quem executa as ' + s.tarefas + ' tarefas, no desenho</div><div class="bar">' +
    segs.map(function (g) { return '<i style="width:' + (100 * (ex[g[0]] || 0) / s.tarefas) + '%;background:' + g[2] + '" title="' + esc(g[1]) + ': ' + (ex[g[0]] || 0) + '"></i>'; }).join('') +
    '</div><div class="leg">' + segs.map(function (g) { return '<span style="--c:' + g[2] + '">' + esc(g[1]) + ' ' + (ex[g[0]] || 0) + '</span>'; }).join('') + '</div></div>';

  /* ---------- abas */
  $('tabs').innerHTML = TABS.map(function (t) { return '<button role="tab" data-tab="' + t[0] + '" aria-selected="false">' + t[1] + '</button>'; }).join('');
  function showTab(name) {
    document.querySelectorAll('section[data-panel]').forEach(function (p) { p.hidden = p.getAttribute('data-panel') !== name; });
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
  function tabelaEtapas(etapas, linkar) {
    var quem = linkar ? who : esc;
    var h = '<div class="scroll"><table class="etapas"><thead><tr><th>Etapa</th><th>Entrada · quem gera</th><th>Tarefas · quem faz</th><th>Saída · quem recebe</th></tr></thead><tbody>';
    etapas.forEach(function (e) {
      h += '<tr><td><span class="et-n">' + e.n + '</span> <span class="et-nome">' + esc(e.nome) + '</span><div class="chips"><span class="chip">' + e.modo + '</span><span class="chip ' + (e.risco === 'alto' ? 'alto' : e.risco === 'médio' ? 'medio' : '') + '">risco ' + e.risco + '</span></div><div class="small muted" style="margin-top:5px">Dono: ' + esc(e.dono) + '</div></td>';
      h += '<td data-l="Entrada · quem gera"><ul class="io">' + e.entradas.map(function (x) { return '<li>' + esc(x.o) + '<span>origem: ' + (/^etapa /.test(x.de) ? x.de + ' desta jornada' : quem(x.de)) + '</span></li>'; }).join('') + '</ul></td>';
      h += '<td data-l="Tarefas · quem faz">' + (e.paralelo ? '<div class="small muted" style="margin-bottom:6px">Há tarefas em paralelo nesta etapa.</div>' : '') + '<ul class="tarefas">' + e.tarefas.map(function (t) {
        return '<li><span class="ex ' + t.exec + '">' + esc(exLabel(t)) + '</span><span>' + esc(t.nome) + (TIPO_T[t.tipo] ? ' <span class="muted small">(' + TIPO_T[t.tipo] + ')</span>' : '') + (t.cond ? '<span class="cond">só se: ' + esc(t.cond) + '</span>' : '') + '</span></li>';
      }).join('') + '</ul>' + (e.decisoes || []).map(function (d) {
        return '<div class="dec"><b>Decisão:</b> ' + esc(d.pergunta) + ' <span class="muted small">(' + esc(d.quem) + ')</span><ul>' + d.saidas.map(function (o) {
          return '<li>' + esc(o.rotulo) + ': ' + (o.via.length ? o.via.map(esc).join(', depois ') + ', depois ' : '') + esc(o.vai) + '</li>';
        }).join('') + '</ul></div>';
      }).join('') + '</td>';
      h += '<td data-l="Saída · quem recebe"><ul class="io">' + e.saidas.map(function (x) { return '<li>' + esc(x.o) + '<span>destino: ' + x.para.map(function (p) { return /^etapa /.test(p) ? p : quem(p); }).join(', ') + '</span></li>'; }).join('') + '</ul></td></tr>';
    });
    return h + '</tbody></table></div>';
  }
  function ficha() {
    var j = J[cur];
    var h = '<div class="ficha-head"><div class="eyebrow">' + esc(j.dominio) + '</div><h2><span class="code">' + j.code + '</span> · ' + esc(j.nome) + '</h2>' +
      '<div class="line"><span class="tag' + (j.classe === 'essencial' ? ' ess' : '') + '">' + j.classe + '</span><span class="tag">onda ' + j.onda + ': ' + esc(D.ondas[j.onda]).toLowerCase() + '</span><span class="tag">automação ' + esc(j.automacao.nivel) + '</span></div>' +
      '<p class="lead" style="font-size:15px">' + esc(j.objetivo) + '</p></div>';
    h += '<dl class="meta">' +
      '<div><dt>Começa quando</dt><dd><ul>' + j.inicios.map(function (i) { return '<li>' + esc(i.nome) + ' <span class="muted small">(' + TIPO_EV[i.tipo] + ')</span></li>'; }).join('') + '</ul></dd></div>' +
      '<div><dt>Termina quando</dt><dd><ul>' + j.fins.map(function (f) { return '<li>' + esc(f) + '</li>'; }).join('') + '</ul></dd></div>' +
      '<div><dt>Frequência</dt><dd>' + comLinks(j.frequencia) + '</dd></div>' +
      '<div><dt>Quem participa</dt><dd>' + j.raias.map(esc).join(', ') + '</dd></div>' +
      '<div><dt>Automação</dt><dd>' + esc(j.automacao.motivo) + '</dd></div>' +
      '<div><dt>Base de mercado</dt><dd>' + j.base.map(function (b) { return '<a href="#fontes" data-fonte="' + b + '">' + esc(D.curto[b]) + '</a>'; }).join(', ') + '</dd></div>' +
      '</dl>';
    h += '<div><h3>Etapas, tarefas, entradas e saídas</h3></div>' +
      '<div class="legend"><span>Quem faz cada tarefa:</span><span class="ex P">Pessoa</span><span class="ex A">Agente</span><span class="ex R">Automação</span><span>' + esc(C.do) + ';</span><span class="ex">Outro círculo ou papel</span></div>';
    h += tabelaEtapas(j.etapas, true);
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
    function lim(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    /* quando a etapa não cabe, o quadro abre no primeiro elemento dela, e não no canto vazio */
    var x = bw > vw ? lim(f[4] - vw * 0.3, f[0] - pad, f[0] + f[2] + pad - vw) : f[0] + f[2] / 2 - vw / 2;
    var y = bh > vh ? lim(f[5] - vh / 2, f[1] - pad, f[1] + f[3] + pad - vh) : f[1] + f[3] / 2 - vh / 2;
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

  /* ---------- transferidas */
  if (D.transferidas.length) {
    var nT = D.transferidas.length;
    $('transf-intro').innerHTML = '<h2>' + NUM_M[nT] + ' jornadas saíram ' + esc(C.do) + '</h2><p>Pela regra de desenho, quem executa fica com a jornada. O rascunho de cada uma está guardado aqui, com etapas e tarefas, para servir de ponto de partida quando o círculo de destino for desenhado. Os códigos são os da versão de treze jornadas. Onde o rascunho diz pessoa, agente ou automação, leia: do círculo que recebe.</p>';
    $('transferidas').innerHTML = D.transferidas.map(function (t) {
      return '<details class="transf"><summary><span class="code">antiga ' + t.antes + '</span><span class="t-nome">' + esc(t.nome) + '</span><span class="t-dest">vai para: ' + esc(t.destino) + '</span></summary><div class="corpo">' +
        '<dl class="meta"><div><dt>Vai para</dt><dd>' + esc(t.destino) + '</dd></div><div><dt>' + esc(C.o.charAt(0).toUpperCase() + C.o.slice(1)) + ' entrega</dt><dd>' + comLinks(t.entrega) + '</dd></div><div><dt>Volta para ' + esc(C.o) + '</dt><dd>' + comLinks(t.volta) + '</dd></div></dl>' +
        '<p class="small muted">Rascunho guardado: ' + t.etapas.length + ' etapas e ' + t.n_tarefas + ' tarefas. Objetivo: ' + esc(t.objetivo) + '</p>' +
        tabelaEtapas(t.etapas, false) + '</div></details>';
    }).join('');
  }

  /* ---------- fronteiras e interfaces */
  $('h-fronteiras').textContent = 'O que ' + C.o + ' não faz';
  $('h-interfaces').textContent = 'O que ' + C.o + ' troca com cada círculo e papel';
  $('tb-fronteiras').innerHTML = '<thead><tr><th>O que não é ' + esc(C.do) + '</th><th>De quem é</th><th>O que ' + esc(C.o) + ' entrega</th></tr></thead><tbody>' +
    D.fronteiras.map(function (f) { return '<tr><td>' + esc(f.o) + '</td><td>' + esc(f.dono) + '</td><td>' + comLinks(f.nota) + '</td></tr>'; }).join('') + '</tbody>';
  if (D.cruz && D.cruz.trocas.length) {
    var VIA = {'direto': 'endereçado ao círculo', 'a todos': 'publicado para todos', 'a quem pediu': 'resposta a quem pediu', 'como pedido': 'entra como pedido'};
    $('bloco-cruz').hidden = false;
    $('h-cruz').textContent = 'Trocas com ' + D.cruz.outros_txt + ', conferidas dos dois lados';
    $('p-cruz').textContent = 'Cada produto abaixo aparece como saída de um círculo e como entrada do outro, com o mesmo nome. O teste falha se um lado mudar e o outro não.';
    $('tb-cruz').innerHTML = '<thead><tr><th>Produto</th><th>De</th><th>Para</th><th>Sai em</th><th>Entra em</th><th>Como chega</th></tr></thead><tbody>' +
      D.cruz.trocas.map(function (t) { return '<tr><td>' + esc(t.o) + '</td><td>' + esc(t.de) + '</td><td>' + esc(t.para) + '</td><td>' + comLinks(t.sai.join('; ')) + '</td><td>' + comLinks(t.entra.join('; ')) + '</td><td>' + esc(VIA[t.via] || t.via) + '</td></tr>'; }).join('') + '</tbody>';
    $('cruz-tarefas').innerHTML = D.cruz.tarefas.length ? '<h3>Tarefas de um círculo dentro das jornadas do outro</h3><ul>' + D.cruz.tarefas.map(function (t) {
      return '<li>' + esc(t.quem) + ', em ' + comLinks(t.code) + ', etapa ' + t.etapa + ': ' + esc(t.nome) + '</li>'; }).join('') + '</ul>' : '';
  }
  $('interfaces').innerHTML = D.interfaces.map(function (p) {
    return '<div class="card"><h3>' + esc(p.parte) + '</h3>' +
      (p.entrega.length ? '<div class="lbl">Entrega ' + esc(C.ao) + '</div><ul>' + p.entrega.map(function (x) { return '<li>' + esc(x.o) + ' <span class="muted small">(' + x.em.map(codeLink).join(', ') + ')</span></li>'; }).join('') + '</ul>' : '') +
      (p.recebe.length ? '<div class="lbl">Recebe ' + esc(C.do) + '</div><ul>' + p.recebe.map(function (x) { return '<li>' + esc(x.o) + ' <span class="muted small">(' + x.de.map(codeLink).join(', ') + ')</span></li>'; }).join('') + '</ul>' : '') +
      (p.tarefas.length ? '<div class="lbl">Tem tarefa em</div><p class="small">' + p.tarefas.map(codeLink).join(', ') + '</p>' : '') + '</div>';
  }).join('');

  /* ---------- pontos a decidir */
  if (D.pontos.length) {
    $('h-pontos').textContent = (NUM_M[D.pontos.length] || D.pontos.length) + ' pontos para decidir';
    if (D.principio) { $('principio').hidden = false; $('principio').textContent = D.principio; }
    $('pontos').innerHTML = D.pontos.map(function (p, i) {
      return '<div class="card"><h3>' + (i + 1) + '. ' + esc(p.q) + '</h3><div class="lbl">Proposta</div><p>' + comLinks(p.proposta) + '</p><div class="lbl">Argumento contra</div><p>' + comLinks(p.contra) + '</p></div>';
    }).join('');
  }

  /* ---------- decisões de fechamento */
  if (D.decisoes.length) {
    $('tb-decisoes').innerHTML = '<thead><tr><th>Decisão</th><th>Origem</th><th>Efeito no desenho</th></tr></thead><tbody>' +
      D.decisoes.map(function (d) { return '<tr><td style="width:34%">' + esc(d.o) + '</td><td style="width:26%">' + esc(d.origem) + '</td><td>' + comLinks(d.efeito) + '</td></tr>'; }).join('') + '</tbody>';
    $('alertas').innerHTML = D.alertas.map(function (a) { return '<div class="card"><h3>' + esc(a.o) + '</h3><p>' + comLinks(a.nota) + '</p></div>'; }).join('');
    if (D.propostas.length) {
      $('bloco-propostas').hidden = false;
      $('tb-propostas').innerHTML = '<thead><tr><th>O que mudaria</th><th>Por quê</th><th>De onde veio</th></tr></thead><tbody>' +
        D.propostas.map(function (p, i) { return '<tr><td style="width:42%">' + (i + 1) + '. ' + comLinks(p.o) + '</td><td>' + comLinks(p.porque) + '</td><td style="width:16%">' + esc(p.origem) + '</td></tr>'; }).join('') + '</tbody>';
    }
  }

  /* ---------- método */
  var alta = D.jornadas.filter(function (j) { return /^alta/.test(j.automacao.nivel); }).map(function (j) { return codeLink(j.code); }).join(', ');
  var nId = (ex.P || 0) + (ex.A || 0) + (ex.R || 0);
  function pct(n) { return Math.round(100 * n / nId); }
  var cob = '';
  if (D.cobertura.length) {
    cob = '<div class="prose"><h2>Cobertura do referencial</h2><p>Categoria 1.0 do APQC PCF 7.4, processo a processo: onde cada um está neste modelo. Os nomes estão como no referencial.</p></div>' +
      '<div class="scroll"><table class="wide"><thead><tr><th>Processo do referencial</th><th>Onde está no modelo</th></tr></thead><tbody>' +
      D.cobertura.map(function (c) { return '<tr><td style="width:48%"><span class="code">' + esc(c.ref) + '</span> ' + esc(c.nome) + '</td><td>' + comLinks(c.onde) + '</td></tr>'; }).join('') + '</tbody></table></div>';
  }
  $('metodo').innerHTML =
    '<div class="prose"><h2>Como as jornadas foram desenhadas</h2>' +
    '<p>Uma fonte única descreve as ' + (NUM_F[s.jornadas] || s.jornadas) + ' jornadas. Dela saem esta página, os fluxos em BPMN e os testes. Mudar uma jornada é mudar a fonte e gerar tudo de novo. O vocabulário de raias, papéis e partes é o mesmo em todos os círculos.</p></div>' +
    '<div class="cards">' +
    '<div class="card"><h3>Três níveis</h3><ul><li><b>Jornada:</b> processo de ponta a ponta, com evento de início e evento de fim.</li><li><b>Etapa:</b> parte da jornada com entrada, saída e dono. É o que o catálogo anterior chamava de workflow.</li><li><b>Tarefa:</b> menor unidade de trabalho, com um executor.</li></ul></div>' +
    '<div class="card"><h3>Nomes</h3><ul><li>Jornada, etapa e tarefa: verbo no infinitivo e objeto.</li><li>Evento de início e de fim: objeto e estado (“Pedido atendido”).</li><li>Decisão: pergunta, com o rótulo em cada saída.</li><li>Raia: papel ou sistema, nunca o nome de uma pessoa.</li></ul><p class="small muted">Regra de nomes da Camunda para BPMN.</p></div>' +
    '<div class="card"><h3>Entradas e saídas</h3><ul><li>Cada etapa diz o que entra e quem gera, o que sai e quem recebe.</li><li>Toda entrada vinda de outra jornada aparece como saída dela, e o contrário.</li><li>Entre círculos já desenhados, a mesma regra vale dos dois lados.</li></ul><p class="small muted">Lógica do SIPOC: fornecedor, entrada, processo, saída e cliente.</p></div>' +
    '<div class="card"><h3>Quem executa e o tipo de tarefa no BPMN</h3><ul><li>Pessoa: tarefa de usuário; conversa ou reunião é tarefa manual.</li><li>Agente: tarefa de serviço.</li><li>Automação: tarefa de script; quando decide por regra, tarefa de regra de negócio.</li><li>Outro círculo: tarefa simples ou atividade de chamada, quando chama uma jornada dele.</li></ul><p class="small muted">Este mapeamento é proposta do modelo, não norma do BPMN.</p></div>' +
    '<div class="card"><h3>Modo de cada etapa</h3><ul><li><b>Assistido:</b> a pessoa executa.</li><li><b>Copiloto:</b> o agente prepara e a pessoa decide.</li><li><b>Autopiloto:</b> o agente ou a regra executa; a pessoa entra na exceção.</li><li><b>Autômato:</b> regra fixa, sem pessoa nem agente.</li><li>Etapa de risco alto é sempre assistida ou de copiloto.</li></ul></div>' +
    '<div class="card"><h3>O que vale automatizar</h3><ul><li>' + (alta ? 'Fluxo executável só onde há volume e regra clara: ' + alta + '.' : 'Nenhuma jornada deste círculo tem volume e regra clara para virar fluxo executável inteiro.') + '</li><li>As demais ficam como roteiro: são raras ou de julgamento.</li><li>Decisão por regra vira tabela de decisão (DMN), fora do desenho do fluxo.</li></ul></div>' +
    '</div>' + cob +
    '<div class="prose"><h2>Testes desta versão</h2><ul>' + D.testes_txt.map(function (t) { return '<li>' + comLinks(t) + '</li>'; }).join('') + '</ul>' +
    '<h2>Números do desenho</h2><ul>' +
    '<li>Das ' + nId + ' tarefas do próprio círculo, ' + (ex.A || 0) + ' são de agente (' + pct(ex.A || 0) + '%), ' + (ex.R || 0) + ' de automação (' + pct(ex.R || 0) + '%) e ' + (ex.P || 0) + ' de pessoa (' + pct(ex.P || 0) + '%).</li>' +
    '<li>Etapas por modo: ' + ['Copiloto', 'Autopiloto', 'Assistido', 'Autômato'].map(function (m) { return (D.stats.modos[m] || 0) + ' de ' + m.toLowerCase(); }).join(', ') + '.</li>' +
    '<li>Etapas por risco: ' + ['baixo', 'médio', 'alto'].map(function (r) { return (D.stats.riscos[r] || 0) + ' de risco ' + r; }).join(', ') + '.</li></ul>' +
    '<h2>Limites</h2><ul>' + D.limites.map(function (t) { return '<li>' + comLinks(t) + '</li>'; }).join('') + '</ul></div>';

  /* ---------- fontes */
  $('tb-fontes').innerHTML = '<thead><tr><th>Referência</th><th>O que usamos</th><th>Como foi conferida</th></tr></thead><tbody>' +
    Object.keys(D.fontes).map(function (k) { var f = D.fontes[k];
      return '<tr id="f-' + k + '"><td style="width:30%">' + esc(f.ref) + '<div class="small" style="margin-top:4px">' + f.links.map(function (l) { return '<a href="' + esc(l[1]) + '" target="_blank" rel="noopener">' + esc(l[0]) + '</a>'; }).join(' · ') + '</div></td><td style="width:38%">' + comLinks(f.uso) + '</td><td>' + esc(f.conf) + '</td></tr>'; }).join('') + '</tbody>';

  /* ---------- o que mudou */
  var CL = {'Acrescentado': 'acr', 'Ajustado': 'aju', 'Retirado': 'ret'};
  $('p-mudou').textContent = D.mudou_intro || '';
  $('tb-mudou').innerHTML = '<thead><tr><th>Tipo</th><th>Antes</th><th>Agora</th><th>O que mudou</th></tr></thead><tbody>' +
    D.mudancas.map(function (m) { return '<tr><td><span class="chip ' + (CL[m.tipo] || '') + '">' + esc(m.tipo) + '</span></td><td>' + esc(m.antes) + '</td><td>' + comLinks(m.agora) + '</td><td>' + comLinks(m.nota) + '</td></tr>'; }).join('') + '</tbody>';

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


def build(bpmnjs_src, path):
    blob = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
    html = (TEMPLATE.replace('__TITLE__', f'Círculo {C["num"]} · {C["nome"]}')
            .replace('__DADOS__', blob).replace('__BPMNJS__', bpmnjs_src))
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(html)
    print(os.path.relpath(path, BASE), round(len(html.encode('utf-8')) / 1024), 'KB')


import importlib
M = importlib.import_module(MOD)
data['mudou_intro'] = getattr(M, 'MUDOU_INTRO', '')
build('https://unpkg.com/bpmn-js@18.31.0/dist/bpmn-navigated-viewer.production.min.js', os.path.join(OUT, C['slug'] + '.html'))
build('file://' + os.path.join(BASE, '..', 'c1', 'node_modules/bpmn-js/dist/bpmn-navigated-viewer.production.min.js'),
      os.path.join(OUT, 'local.html'))
