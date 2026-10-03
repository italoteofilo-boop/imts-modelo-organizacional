# -*- coding: utf-8 -*-
"""Instruções de trabalho das 73 jornadas (E3), geradas da fonte do modelo (saida/cN/circulo.json).
Escreve saida/instrucoes/html/<JORNADA>.html (uma por jornada, para imprimir em A4) e
saida/instrucoes/instrucoes.html (a versão digital, com as 73 navegáveis). Nada é escrito à mão:
cada linha vem do modelo; o que o modelo não diz, a instrução também não diz.
Uso: python3 instrucoes.py  (depois: node instrucoes_pdf.mjs, que gera os PDFs)"""
import html, json, os, re

BASE = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(BASE, 'saida', 'instrucoes')
VERSAO = '2026-10-03'
DATA = '03/10/2026'
E = html.escape
TIPO_INICIO = {'message': 'ao receber', 'timer': 'na data marcada', 'signal': 'ao sinal', None: 'ao iniciar'}

CSS = """
:root { color-scheme: light dark;
  --bg: #F2F4F3; --surface: #FFFFFF; --ink: #17222A; --muted: #58666F; --line: #D2D9D7; --line-soft: #E4E9E7;
  --accent: #0B5E6B; --accent-soft: #DDECEE; --pessoa: #A8480F; --pessoa-bg: #FBE9DC; --agente: #3346A8; --agente-bg: #E3E7FA;
  --regra: #17693F; --regra-bg: #DDF1E5; --neutro-bg: #E9EEEC; --alto: #A32222; --alto-bg: #F9E0E0; --medio: #8A5A00; --medio-bg: #FBEFD3;
  --f-body: 'IBM Plex Sans', system-ui, sans-serif; --f-head: 'IBM Plex Sans Condensed', 'IBM Plex Sans', system-ui, sans-serif; --f-mono: 'IBM Plex Mono', ui-monospace, monospace; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { color-scheme: dark;
  --bg: #0F161A; --surface: #161F25; --ink: #E3EAE9; --muted: #96A5AC; --line: #2B3840; --line-soft: #222D34;
  --accent: #6FC6D2; --accent-soft: #153038; --pessoa: #F0A371; --pessoa-bg: #3A2416; --agente: #9DAAF5; --agente-bg: #1E2547;
  --regra: #6ACB98; --regra-bg: #14301F; --neutro-bg: #222D34; --alto: #F08A8A; --alto-bg: #3B1B1B; --medio: #E6B95A; --medio-bg: #33270E; } }
:root[data-theme="dark"] { color-scheme: dark;
  --bg: #0F161A; --surface: #161F25; --ink: #E3EAE9; --muted: #96A5AC; --line: #2B3840; --line-soft: #222D34;
  --accent: #6FC6D2; --accent-soft: #153038; --pessoa: #F0A371; --pessoa-bg: #3A2416; --agente: #9DAAF5; --agente-bg: #1E2547;
  --regra: #6ACB98; --regra-bg: #14301F; --neutro-bg: #222D34; --alto: #F08A8A; --alto-bg: #3B1B1B; --medio: #E6B95A; --medio-bg: #33270E; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font-family: var(--f-body); font-size: 14.5px; line-height: 1.5; }
h1, h2, h3 { font-family: var(--f-head); font-weight: 600; margin: 0; line-height: 1.2; text-wrap: balance; }
.eyebrow { font-family: var(--f-head); font-weight: 500; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.code { font-family: var(--f-mono); font-size: .88em; font-weight: 500; }
.it { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 28px 30px; }
.it header { border-bottom: 2px solid var(--accent); padding-bottom: 14px; margin-bottom: 16px; }
.it h1 { font-size: 24px; margin: 4px 0 8px; }
.it .obj { margin: 0; font-size: 15px; }
.meta { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px 18px; margin: 14px 0 0; }
.meta div { min-width: 0; } .meta div.largo { grid-column: 1 / -1; } .meta dt { font-family: var(--f-head); font-size: 11.5px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
.meta dd { margin: 2px 0 0; }
h2 { font-size: 16px; margin: 22px 0 8px; color: var(--accent); }
ul.plain { margin: 0; padding-left: 18px; } ul.plain li { margin: 2px 0; }
.etapa { border: 1px solid var(--line); border-radius: 8px; margin: 14px 0; overflow: hidden; }
.etapa > .cab { display: flex; flex-wrap: wrap; gap: 6px 12px; align-items: baseline; background: var(--neutro-bg); padding: 9px 14px; }
.etapa > .cab h3 { font-size: 16px; flex: 1 1 260px; }
.etapa .corpo { padding: 10px 14px 12px; }
.tag { display: inline-block; font-family: var(--f-head); font-size: 12px; font-weight: 500; padding: 1px 8px; border-radius: 999px; background: var(--accent-soft); color: var(--accent); white-space: nowrap; }
.tag.alto { background: var(--alto-bg); color: var(--alto); } .tag.medio { background: var(--medio-bg); color: var(--medio); } .tag.baixo { background: var(--regra-bg); color: var(--regra); }
.sub { font-family: var(--f-head); font-size: 11.5px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin: 10px 0 4px; }
ol.passos { margin: 0; padding-left: 0; list-style: none; counter-reset: p; }
ol.passos li { counter-increment: p; display: grid; grid-template-columns: 28px 1fr; gap: 0 8px; padding: 6px 0; border-top: 1px solid var(--line-soft); }
ol.passos li:first-child { border-top: 0; }
ol.passos li::before { content: counter(p); font-family: var(--f-mono); color: var(--muted); font-size: 13px; padding-top: 1px; }
.quem { font-size: 12.5px; color: var(--muted); } .quem b { font-weight: 600; }
.ex { display: inline-block; font-family: var(--f-mono); font-size: 11px; font-weight: 500; min-width: 18px; text-align: center; border-radius: 4px; padding: 0 4px; margin-right: 4px; }
.ex.P, .ex.H, .ex.X { background: var(--pessoa-bg); color: var(--pessoa); } .ex.A { background: var(--agente-bg); color: var(--agente); }
.ex.R { background: var(--regra-bg); color: var(--regra); } .ex.C { background: var(--neutro-bg); color: var(--ink); }
.cond { font-size: 12.5px; color: var(--medio); }
.dec { border-left: 3px solid var(--accent); padding: 4px 0 4px 10px; margin: 6px 0; }
.dec p { margin: 0; } .dec ul { margin: 2px 0 0; padding-left: 18px; }
.rodape { margin-top: 22px; padding-top: 10px; border-top: 1px solid var(--line); font-size: 12px; color: var(--muted); }
.check { list-style: none; padding: 0; margin: 0; } .check li { padding: 2px 0 2px 24px; position: relative; }
.check li::before { content: ''; position: absolute; left: 0; top: 5px; width: 13px; height: 13px; border: 1.5px solid var(--muted); border-radius: 3px; }
"""

PRINT_CSS = """
@page { size: A4; margin: 14mm 13mm 16mm; }
.etapa { break-inside: auto; } .etapa > .cab { break-after: avoid; } ol.passos li, .dec, .check li { break-inside: avoid; } h2 { break-after: avoid; }
body { background: #fff; font-size: 11pt; }
.it { border: 0; padding: 0; border-radius: 0; }
:root { --bg: #fff; --surface: #fff; }
"""


def fontes_link():
    return ('<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
            '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Sans+Condensed:wght@500;600&display=swap">')


def risco_cls(r):
    r = (r or '').lower()
    return 'alto' if 'alto' in r else 'medio' if 'méd' in r or 'med' in r else 'baixo'


def bloco(j, c, exec_nome):
    o = []
    w = o.append
    w(f'<article class="it" id="it-{E(j["code"])}">')
    w('<header>')
    w(f'<div class="eyebrow">Instrução de trabalho · Círculo {c["num"]} · {E(c["nome"])}</div>')
    w(f'<h1><span class="code">{E(j["code"])}</span> {E(j["nome"])}</h1>')
    w(f'<p class="obj">{E(j["objetivo"])}</p>')
    w('<dl class="meta">')
    for k, v in (('Frequência', j['frequencia']), ('Classe', j['classe']),
                 ('Etapas', str(len(j['etapas']))), ('Tarefas', str(sum(len(e['tarefas']) for e in j['etapas']))),
                 ('Versão do modelo', f'{VERSAO}'), ('Automação', f'{j["automacao"]["nivel"]}. {j["automacao"]["motivo"]}')):
        w(f'<div{" class=largo" if k == "Automação" else ""}><dt>{k}</dt><dd>{E(v)}</dd></div>')
    w('</dl></header>')

    w('<h2>Quando começa</h2><ul class="plain">')
    for i in j['inicios']:
        w(f'<li>{E(TIPO_INICIO.get(i.get("tipo"), "ao iniciar")).capitalize()}: {E(i["nome"])} <span class="quem">({E(i["raia"])})</span></li>')
    w('</ul>')
    w('<h2>Como termina</h2><ul class="plain">' + ''.join(f'<li>{E(f)}</li>' for f in j['fins']) + '</ul>')
    w('<h2>Quem participa</h2><p class="obj">' + ' · '.join(E(r) for r in j['raias']) + '</p>')
    usados = sorted({t['exec'] for e in j['etapas'] for t in e['tarefas']}, key='PAHRCX'.index)
    w('<p class="quem">' + ' · '.join(f'<span class="ex {x}">{x}</span>{E(exec_nome[x])}' for x in usados) + '</p>')

    w('<h2>Passo a passo</h2>')
    for e in j['etapas']:
        w('<section class="etapa">')
        w(f'<div class="cab"><h3>Etapa {e["n"]}. {E(e["nome"])}</h3>'
          f'<span class="tag">{E(e["modo"])}</span><span class="tag {risco_cls(e["risco"])}">risco {E(e["risco"])}</span>'
          f'<span class="quem">dono: <b>{E(e["dono"])}</b></span></div><div class="corpo">')
        if e['entradas']:
            w('<div class="sub">Recebe</div><ul class="plain">' + ''.join(f'<li>{E(x["o"])} <span class="quem">(de {E(x["de"])})</span></li>' for x in e['entradas']) + '</ul>')
        w('<div class="sub">Faz' + (' (tarefas em paralelo)' if e.get('paralelo') else '') + '</div><ol class="passos">')
        for t in e['tarefas']:
            cond = f'<div class="cond">Só se: {E(t["cond"])}</div>' if t.get('cond') else ''
            w(f'<li><div><span class="ex {t["exec"]}">{t["exec"]}</span>{E(t["nome"])}<div class="quem">{E(t["raia"])}</div>{cond}</div></li>')
        w('</ol>')
        for d in e.get('decisoes') or []:
            w(f'<div class="dec"><p><b>Decide:</b> {E(d["pergunta"])} <span class="quem">({E(d["quem"])})</span></p><ul>')
            for s in d['saidas']:
                via = f' <span class="quem">— antes: {E("; ".join(s["via"]))}</span>' if s.get('via') else ''
                w(f'<li>{E(s["rotulo"])} → {E(s["vai"])}{via}</li>')
            w('</ul></div>')
        if e['saidas']:
            w('<div class="sub">Entrega</div><ul class="check">' + ''.join(f'<li>{E(x["o"])} <span class="quem">(para {E(", ".join(x["para"]))})</span></li>' for x in e['saidas']) + '</ul>')
        w('</div></section>')
    w(f'<div class="rodape">Gerado da fonte do modelo em {DATA} (versão {VERSAO}). Fluxo BPMN: 3-fluxos-bpmn/circulo-{c["num"]}-{c["slug"].split("-", 1)[1]}/bpmn/{E(j["code"])}.bpmn. '
      'Tempos, volumes e alçadas em valor vêm dos parâmetros de cada círculo, não desta instrução.</div>')
    w('</article>')
    return '\n'.join(o)


def main():
    os.makedirs(os.path.join(SAIDA, 'html'), exist_ok=True)
    circs, n = [], 0
    for k in range(1, 10):
        d = json.load(open(os.path.join(BASE, 'saida', f'c{k}', 'circulo.json'), encoding='utf-8'))
        c = d['circulo']
        blocos = []
        for j in d['jornadas']:
            b = bloco(j, c, d['exec_nome'])
            blocos.append((j, b))
            pagina = (f'<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
                      f'<title>{E(j["code"])} · Instrução de trabalho</title>{fontes_link()}<style>{CSS}{PRINT_CSS}</style></head><body>{b}</body></html>')
            open(os.path.join(SAIDA, 'html', f'{j["code"]}.html'), 'w', encoding='utf-8').write(pagina)
            n += 1
        circs.append((c, blocos))
    # versão digital: as 73 numa página, navegação por círculo e jornada
    nav = []
    for c, bl in circs:
        nav.append(f'<optgroup label="{c["num"]} · {E(c["nome"])}">' + ''.join(f'<option value="{E(j["code"])}">{E(j["code"])} · {E(j["nome"])}</option>' for j, _ in bl) + '</optgroup>')
    corpo = ''.join(f'<div class="j" data-c="{E(j["code"])}" hidden>{b}</div>' for c, bl in circs for j, b in bl)
    digital = f'''<title>Instruções de Trabalho IMTS</title>{fontes_link()}<style>{CSS}
.top {{ position: sticky; top: env(safe-area-inset-top, 0px); z-index: 2; background: var(--bg); border-bottom: 1px solid var(--line); padding: 12px 16px; }}
.top .in {{ max-width: 980px; margin: 0 auto; display: flex; flex-wrap: wrap; gap: 8px 14px; align-items: center; }}
.top h1 {{ font-size: 18px; flex: 1 1 220px; }}
button:focus-visible, select:focus-visible {{ outline: 2px solid var(--accent); outline-offset: 2px; }}
select, button {{ font: inherit; color: var(--ink); background: var(--surface); border: 1px solid var(--line); border-radius: 8px; padding: 7px 10px; max-width: 100%; }}
button {{ cursor: pointer; }} select {{ flex: 1 1 320px; min-width: 0; }}
main {{ max-width: 980px; margin: 0 auto; padding: 16px; }}
.nota {{ color: var(--muted); font-size: 13px; margin: 0 0 12px; }}
@media (max-width: 600px) {{ .it {{ padding: 18px 16px; }} .it h1 {{ font-size: 20px; }} }}
</style>
<div class="top"><div class="in"><h1>Instruções de trabalho · {n} jornadas</h1>
<select id="sel" aria-label="Escolher jornada">{''.join(nav)}</select>
<button id="ant" aria-label="Jornada anterior">←</button><button id="prox" aria-label="Próxima jornada">→</button></div></div>
<main><p class="nota">Geradas da fonte do modelo em {DATA}. Para imprimir, cada jornada tem um PDF A4 no repositório do projeto, na pasta 9-instrucoes-de-trabalho.</p>{corpo}</main>
<script>
const sel = document.getElementById('sel'), js = [...document.querySelectorAll('.j')];
function mostra(c) {{ js.forEach(d => d.hidden = d.dataset.c !== c); sel.value = c; if (location.hash !== '#' + c) history.replaceState(null, '', '#' + c); window.scrollTo(0, 0); }}
sel.onchange = () => mostra(sel.value);
function passo(k) {{ const i = js.findIndex(d => !d.hidden); mostra(js[(i + k + js.length) % js.length].dataset.c); }}
document.getElementById('ant').onclick = () => passo(-1); document.getElementById('prox').onclick = () => passo(1);
const h = decodeURIComponent(location.hash.slice(1)); mostra(js.some(d => d.dataset.c === h) ? h : js[0].dataset.c);
</script>'''
    open(os.path.join(SAIDA, 'instrucoes.html'), 'w', encoding='utf-8').write(digital)
    print('instruções', n, 'digital', round(len(digital.encode()) / 1024), 'KB')


if __name__ == '__main__':
    main()
