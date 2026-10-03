# -*- coding: utf-8 -*-
"""Instruções de trabalho das 73 jornadas (E3), geradas da fonte do modelo (saida/cN/circulo.json).
Escreve saida/instrucoes/html/<JORNADA>.html (uma por jornada, para imprimir em A4) e
saida/instrucoes/instrucoes.html (a versão digital, com as 73 navegáveis). Nada é escrito à mão:
cada linha vem do modelo; o que o modelo não diz, a instrução também não diz.
Uso: python3 instrucoes.py  (depois: node instrucoes_pdf.mjs, que gera os PDFs)"""
import csv, html, json, math, os, re
import xml.etree.ElementTree as ET

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
  --papel: #FFFFFF; --f-body: 'IBM Plex Sans', system-ui, sans-serif; --f-head: 'IBM Plex Sans Condensed', 'IBM Plex Sans', system-ui, sans-serif; --f-mono: 'IBM Plex Mono', ui-monospace, monospace; }
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
.recorte { margin: 8px 0 12px; break-inside: avoid; }
.recorte figcaption { font-family: var(--f-head); font-size: 11.5px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin-bottom: 4px; }
.rec { display: grid; grid-template-columns: 92px 1fr; border: 1px solid var(--line); border-radius: 6px; overflow: hidden; background: var(--papel); }
.raias { position: relative; border-right: 1px solid var(--line); background: var(--neutro-bg); }
.raias span { position: absolute; left: 6px; right: 4px; transform: translateY(-50%); font-family: var(--f-head); font-size: 10.5px; line-height: 1.15; color: var(--ink); }
.raias i { position: absolute; left: 0; right: 0; border-top: 1px solid var(--line); }
.janela { position: relative; overflow: hidden; width: 100%; max-width: 100%; background: var(--papel); }
.janela img { position: absolute; max-width: none; }
.janela svg.peca { position: absolute; left: 0; top: 0; width: 100%; height: 100%; }
.check li::before { content: ''; position: absolute; left: 0; top: 5px; width: 13px; height: 13px; border: 1.5px solid var(--muted); border-radius: 3px; }
"""

PRINT_CSS = """
@page { size: A4; margin: 14mm 13mm 16mm; }
.etapa { break-inside: auto; } .etapa > .cab { break-after: avoid; } ol.passos li, .dec, .check li { break-inside: avoid; } h2 { break-after: avoid; }
body { background: #fff; font-size: 11pt; }
.it { border: 0; padding: 0; border-radius: 0; }
:root { --bg: #fff; --surface: #fff; }
"""


NS = {'bpmndi': 'http://www.omg.org/spec/BPMN/20100524/DI', 'dc': 'http://www.omg.org/spec/DD/20100524/DC',
      'di': 'http://www.omg.org/spec/DD/20100524/DI', 'b': 'http://www.omg.org/spec/BPMN/20100524/MODEL'}
LARG_ALVO = 1150  # largura máxima, em unidades do diagrama, de um recorte; acima disso a etapa é dividida


def svg_dims(caminho):
    m = re.search(r'width="([\d.]+)" height="([\d.]+)" viewBox="([-\d. ]+)"', open(caminho, encoding='utf-8').read(800))
    vx, vy, vw, vh = map(float, m.group(3).split())
    return vx, vy, vw, vh


def recortes(k, j):
    """Para cada etapa: pedaços do diagrama (x, y, w, h no sistema do SVG) e as raias que cada pedaço cruza."""
    raiz = ET.parse(os.path.join(BASE, 'saida', f'c{k}', 'bpmn', j['code'] + '.bpmn')).getroot()
    nomes = {el.get('id'): el.get('name') for el in raiz.iter() if el.get('id')}
    raias, formas = [], []
    for s in raiz.iter('{%s}BPMNShape' % NS['bpmndi']):
        b = s.find('dc:Bounds', NS)
        x, y, w, h = (float(b.get(a)) for a in ('x', 'y', 'width', 'height'))
        el = s.get('bpmnElement')
        if el.startswith('Lane_'):
            raias.append((nomes.get(el, ''), y, y + h))
        elif not el.startswith(('Participant_', 'Group_')):
            formas.append((x, y, w, h))
    out = {}
    for et in j['etapas']:
        x0, _, bw, _ = et['box']
        n = max(1, math.ceil(bw / LARG_ALVO))
        pw = bw / n
        pedacos = []
        for i in range(n):
            px = x0 + i * pw
            usadas = [(nm, a, b) for nm, a, b in raias
                      if any(px <= f[0] + f[2] / 2 <= px + pw and a <= f[1] + f[3] / 2 <= b for f in formas)]
            if usadas:
                y0, y1 = min(a for _, a, _ in usadas), max(b for _, _, b in usadas)
            else:
                y0, y1 = min(a for _, a, _ in raias), max(b for _, _, b in raias)
            rs = [(nm, max(a, y0), min(b, y1)) for nm, a, b in raias if b > y0 and a < y1 and min(b, y1) - max(a, y0) > 40]
            pedacos.append({'x': px, 'y': y0, 'w': pw, 'h': y1 - y0, 'raias': rs})
        out[et['n']] = pedacos
    return out


def caixas_di(k, code):
    """Retângulo de cada elemento do diagrama (formas, rótulos e conexões), no sistema do SVG."""
    raiz = ET.parse(os.path.join(BASE, 'saida', f'c{k}', 'bpmn', code + '.bpmn')).getroot()
    cx = {}
    for s in raiz.iter('{%s}BPMNShape' % NS['bpmndi']):
        b = s.find('dc:Bounds', NS)
        cx[s.get('bpmnElement')] = tuple(float(b.get(a)) for a in ('x', 'y', 'width', 'height'))
        lb = s.find('bpmndi:BPMNLabel/dc:Bounds', NS)
        if lb is not None:
            cx[s.get('bpmnElement') + '_label'] = tuple(float(lb.get(a)) for a in ('x', 'y', 'width', 'height'))
    for e in raiz.iter('{%s}BPMNEdge' % NS['bpmndi']):
        xs = [float(w.get('x')) for w in e.findall('di:waypoint', NS)]; ys = [float(w.get('y')) for w in e.findall('di:waypoint', NS)]
        cx[e.get('bpmnElement')] = (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
        lb = e.find('bpmndi:BPMNLabel/dc:Bounds', NS)
        if lb is not None:
            cx[e.get('bpmnElement') + '_label'] = tuple(float(lb.get(a)) for a in ('x', 'y', 'width', 'height'))
    return cx


def pecas_svg(k, code, svg, recs):
    """Um SVG por pedaço, só com os elementos que cruzam o recorte: o PDF fica leve e vetorial."""
    ET.register_namespace('', 'http://www.w3.org/2000/svg'); ET.register_namespace('xlink', 'http://www.w3.org/1999/xlink')
    cx = caixas_di(k, code)
    pasta = os.path.join(SAIDA, 'pecas'); os.makedirs(pasta, exist_ok=True)
    texto = open(svg, encoding='utf-8').read()
    out = {}
    for n, pedacos in recs.items():
        out[n] = []
        for i, pc in enumerate(pedacos):
            raiz = ET.fromstring(texto)
            x0, y0, x1, y1 = pc['x'] - 20, pc['y'] - 20, pc['x'] + pc['w'] + 20, pc['y'] + pc['h'] + 20
            def fora(eid):
                b = cx.get(eid)
                return b is not None and (b[0] > x1 or b[0] + b[2] < x0 or b[1] > y1 or b[1] + b[3] < y0)
            for pai in list(raiz.iter()):
                for g in list(pai):
                    if 'djs-group' in (g.get('class') or ''):
                        el = next((c for c in g if c.get('data-element-id')), None)
                        eid = el.get('data-element-id') if el is not None else None
                        if eid and not eid.startswith(('Participant_', 'Lane_')) and fora(eid):
                            pai.remove(g)
            raiz.set('viewBox', f'{pc["x"]:.1f} {pc["y"]:.1f} {pc["w"]:.1f} {pc["h"]:.1f}')
            raiz.set('width', f'{pc["w"]:.0f}'); raiz.set('height', f'{pc["h"]:.0f}')
            f = os.path.join(pasta, f'{code}_e{n}_p{i + 1}.svg')
            ET.ElementTree(raiz).write(f, encoding='utf-8', xml_declaration=True)
            out[n].append('file://' + f)
    return out


def figura(src, dims, pedacos, etapa_n, pecas=None):
    vx, vy, vw, vh = dims
    o = []
    for i, p in enumerate(pedacos):
        cap = f'Fluxo da etapa {etapa_n}' + (f', parte {i + 1} de {len(pedacos)}' if len(pedacos) > 1 else '')
        lab = ''.join(f'<span style="top:{((a + b) / 2 - p["y"]) / p["h"] * 100:.2f}%">{E(nm)}</span>' for nm, a, b in p['raias'])
        linhas = ''.join(f'<i style="top:{(b - p["y"]) / p["h"] * 100:.2f}%"></i>' for nm, a, b in p['raias'][:-1])
        o.append(f'<figure class="recorte"><figcaption>{cap}</figcaption><div class="rec"><div class="raias">{lab}{linhas}</div>'
                 f'<div class="janela" style="aspect-ratio:{p["w"]:.0f}/{p["h"]:.0f}">'
                 + (re.sub(r'^<\?xml[^>]*>\s*', '', open(pecas[i][7:], encoding='utf-8').read()).replace('<svg ', '<svg class="peca" ', 1) if pecas else
                    f'<img alt="{E(cap)}" loading="lazy" src="{E(src)}" style="'
                    f'left:{-(p["x"] - vx) / p["w"] * 100:.3f}%;top:{-(p["y"] - vy) / p["h"] * 100:.3f}%;'
                    f'width:{vw / p["w"] * 100:.3f}%;height:{vh / p["h"] * 100:.3f}%">')
                 + '</div></div></figure>')
    return ''.join(o)


def fontes_link():
    return ('<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
            '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Sans+Condensed:wght@500;600&display=swap">')


def risco_cls(r):
    r = (r or '').lower()
    return 'alto' if 'alto' in r else 'medio' if 'méd' in r or 'med' in r else 'baixo'


def bloco(j, c, exec_nome, src=None, dims=None, recs=None, pecas=None):
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
        if recs:
            w(figura(src, dims, recs[e['n']], e['n'], pecas[e['n']] if pecas else None))
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


def mapa_dados(circs):
    """Ligações entre jornadas: trocas entre círculos (cruzamento.json) e entradas vindas de outra jornada do mesmo círculo."""
    cz = json.load(open(os.path.join(BASE, 'saida', 'cruzamento.json'), encoding='utf-8'))
    prods = {}
    for tr in cz['trocas']:
        for s in tr['sai']:
            for e in tr['entra']:
                a, b = s.split(' etapa')[0], e.split(' etapa')[0]
                if a != b:
                    prods.setdefault((a, b), set()).add(tr['o'])
    for c, bl in circs:
        for j, _ in bl:
            for et in j['etapas']:
                for x in et['entradas']:
                    if re.fullmatch(r'[A-Z]{2}-\d{2}', x['de']) and x['de'] != j['code']:
                        prods.setdefault((x['de'], j['code']), set()).add(x['o'])
    nos = [{'c': j['code'], 'n': j['nome'], 'k': c['num'], 'ck': c['nome']} for c, bl in circs for j, _ in bl]
    cods = {x['c'] for x in nos}
    arestas = [[a, b, len(p), sorted(p)[:6]] for (a, b), p in sorted(prods.items()) if a in cods and b in cods]
    return {'nos': nos, 'arestas': arestas, 'circulos': [{'k': c['num'], 'nome': c['nome']} for c, _ in circs]}


def main():
    os.makedirs(os.path.join(SAIDA, 'html'), exist_ok=True)
    circs, n, svgs = [], 0, {}
    for k in range(1, 10):
        d = json.load(open(os.path.join(BASE, 'saida', f'c{k}', 'circulo.json'), encoding='utf-8'))
        c = d['circulo']
        blocos = []
        for j in d['jornadas']:
            svg = os.path.join(BASE, 'saida', f'c{k}', 'png', j['code'] + '.svg')
            dims, recs = svg_dims(svg), recortes(k, j)
            svgs[j['code']] = (svg, dims)
            impresso = bloco(j, c, d['exec_nome'], 'file://' + svg, dims, recs, pecas_svg(k, j['code'], svg, recs))
            digital_b = bloco(j, c, d['exec_nome'], f'fluxos/{j["code"]}.svg', dims, recs)
            blocos.append((j, digital_b))
            pagina = (f'<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
                      f'<title>{E(j["code"])} · Instrução de trabalho</title>{fontes_link()}<style>{CSS}{PRINT_CSS}</style></head><body>{impresso}</body></html>')
            open(os.path.join(SAIDA, 'html', f'{j["code"]}.html'), 'w', encoding='utf-8').write(pagina)
            n += 1
        circs.append((c, blocos))
    mapa = mapa_dados(circs)
    json.dump({c: s for c, (s, _) in svgs.items()}, open(os.path.join(SAIDA, 'fluxos.json'), 'w'), indent=0)
    dims_js = json.dumps({c: [round(v, 1) for v in dm] for c, (_, dm) in svgs.items()})
    nav = []
    for c, bl in circs:
        nav.append(f'<optgroup label="{c["num"]} · {E(c["nome"])}">' + ''.join(f'<option value="{E(j["code"])}">{E(j["code"])} · {E(j["nome"])}</option>' for j, _ in bl) + '</optgroup>')
    corpo = ''.join(f'<div class="j" data-c="{E(j["code"])}" hidden>{b}</div>' for c, bl in circs for j, b in bl)
    digital = DIGITAL.replace('%CSS%', CSS).replace('%FONTES%', fontes_link()).replace('%N%', str(n)).replace('%NAV%', ''.join(nav)) \
        .replace('%CORPO%', corpo).replace('%DATA%', DATA).replace('%MAPA%', json.dumps(mapa, ensure_ascii=False).replace('</', '<\\/')) \
        .replace('%DIMS%', dims_js).replace('%NARESTAS%', str(len(mapa['arestas'])))
    open(os.path.join(SAIDA, 'instrucoes.html'), 'w', encoding='utf-8').write(digital)
    print('instruções', n, 'digital', round(len(digital.encode()) / 1024), 'KB', 'ligações no mapa', len(mapa['arestas']))


DIGITAL = r"""<title>Instruções de Trabalho IMTS</title>%FONTES%<style>%CSS%
:root { --sai: #0B5E6B; --entra: #A8480F; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --sai: #6FC6D2; --entra: #F0A371; } }
:root[data-theme="dark"] { --sai: #6FC6D2; --entra: #F0A371; }
body { padding-inline: 16px; }
.top { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 3; background: var(--bg); border-bottom: 1px solid var(--line); margin-inline: -16px; padding: 10px 16px; }
.top .in { max-width: 1120px; margin: 0 auto; display: flex; flex-wrap: wrap; gap: 8px 12px; align-items: center; }
.top h1 { font-size: 18px; flex: 1 1 200px; }
.vistas { display: flex; gap: 4px; flex-wrap: wrap; }
.vistas button[aria-pressed="true"] { background: var(--accent); color: var(--surface); border-color: var(--accent); }
button:focus-visible, select:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
select, button { font: inherit; color: var(--ink); background: var(--surface); border: 1px solid var(--line); border-radius: 8px; padding: 6px 10px; max-width: 100%; }
button { cursor: pointer; } select { flex: 1 1 300px; min-width: 0; }
main { max-width: 1120px; margin: 0 auto; padding-block: 16px 40px; }
.nota { color: var(--muted); font-size: 13px; margin: 0 0 12px; }
.it { max-width: 980px; margin: 0 auto; }
#vmapa { display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: 16px; align-items: start; }
#vmapa .tela { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 8px; min-width: 0; }
#mapa { width: 100%; height: auto; display: block; touch-action: manipulation; }
#mapa .ar { fill: none; stroke: var(--muted); stroke-opacity: .16; }
#mapa .ar.sai { stroke: var(--sai); stroke-opacity: .85; } #mapa .ar.entra { stroke: var(--entra); stroke-opacity: .85; }
#mapa .ar.apaga { stroke-opacity: .04; }
#mapa .no circle { fill: var(--surface); stroke: var(--accent); stroke-width: 1.6; cursor: pointer; }
#mapa .no.on circle { fill: var(--accent); }
#mapa .no.liga circle { fill: var(--accent-soft); }
#mapa .no text { font-family: var(--f-mono); font-size: 9.5px; fill: var(--muted); cursor: pointer; }
#mapa .no.on text, #mapa .no.liga text { fill: var(--ink); font-weight: 500; }
#mapa .setor { fill: var(--ink); font-family: var(--f-head); font-weight: 600; font-size: 13px; cursor: pointer; }
#mapa .arco { fill: none; stroke: var(--line); stroke-width: 6; stroke-linecap: round; }
#mapa .arco.on { stroke: var(--accent); }
.lado { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 14px; min-width: 0; position: sticky; top: calc(env(safe-area-inset-top, 0px) + 70px); }
.lado h2 { font-size: 16px; margin: 4px 0 6px; color: var(--ink); } .lado p { margin: 0 0 8px; font-size: 13.5px; }
.lado ul { margin: 4px 0 10px; padding-left: 18px; font-size: 13px; } .lado li { margin: 2px 0; }
.lado .acoes { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 8px; }
.leg { display: flex; flex-wrap: wrap; gap: 6px 14px; font-size: 12.5px; color: var(--muted); margin: 8px 4px 2px; }
.leg i { display: inline-block; width: 18px; height: 3px; vertical-align: middle; margin-right: 5px; border-radius: 2px; }
#vfluxo .barra { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-bottom: 10px; }
#vfluxo .barra h2 { font-size: 17px; flex: 1 1 260px; margin: 0; color: var(--ink); }
#vfluxo .rolo { overflow: auto; border: 1px solid var(--line); border-radius: 10px; background: var(--papel); max-height: 78vh; }
#vfluxo .rolo img { display: block; max-width: none; }
.abrir-fluxo { margin: 10px 0 0; }
@media (max-width: 820px) { #vmapa { grid-template-columns: 1fr; } .lado { position: static; } }
@media (max-width: 600px) { .top h1 { display: none; } .it { padding: 18px 14px; } .it h1 { font-size: 20px; } .rec { grid-template-columns: 64px 1fr; } .raias span { font-size: 9px; left: 3px; } }
</style>
<div class="top"><div class="in"><h1>Instruções de trabalho · %N% jornadas</h1>
<div class="vistas" role="group" aria-label="Vista"><button id="b-mapa" aria-pressed="false">Mapa geral</button><button id="b-inst" aria-pressed="false">Instrução</button><button id="b-fluxo" aria-pressed="false">Fluxo completo</button></div>
<select id="sel" aria-label="Escolher jornada">%NAV%</select>
<button id="ant" aria-label="Jornada anterior">←</button><button id="prox" aria-label="Próxima jornada">→</button></div></div>
<main>
<section id="vmapa" hidden>
  <div class="tela"><svg id="mapa" viewBox="-640 -560 1280 1120" role="img" aria-label="Mapa das 73 jornadas e das ligações entre elas"></svg>
  <div class="leg"><span><i style="background:var(--sai)"></i>entrega para</span><span><i style="background:var(--entra)"></i>recebe de</span><span>%NARESTAS% ligações entre jornadas · espessura = quantas entregas</span></div></div>
  <aside class="lado" id="lado" aria-live="polite"></aside>
</section>
<section id="vinst" hidden><p class="nota">Geradas da fonte do modelo em %DATA%. Cada etapa traz o recorte do seu fluxo BPMN. Para imprimir, cada jornada tem um PDF A4 no repositório do projeto, na pasta 9-instrucoes-de-trabalho.</p>%CORPO%</section>
<section id="vfluxo" hidden>
  <div class="barra"><h2 id="f-tit"></h2><button id="z-menos" aria-label="Diminuir">−</button><button id="z-ajusta">Ajustar à tela</button><button id="z-mais" aria-label="Aumentar">+</button></div>
  <div class="rolo" id="rolo"><img id="f-img" alt=""></div>
  <p class="nota">Arraste para os lados ou use a rolagem. O diagrama é o BPMN da jornada, o mesmo que abre no Camunda Modeler e no bpmn.io.</p>
</section>
</main>
<script>
const MAPA = %MAPA%, DIMS = %DIMS%;
const sel = document.getElementById('sel'), js = [...document.querySelectorAll('.j')], cods = js.map(d => d.dataset.c);
const V = { mapa: document.getElementById('vmapa'), inst: document.getElementById('vinst'), fluxo: document.getElementById('vfluxo') };
const B = { mapa: document.getElementById('b-mapa'), inst: document.getElementById('b-inst'), fluxo: document.getElementById('b-fluxo') };
let atual = cods[0], vista = 'mapa', zoom = null;
function hash() { const h = vista === 'mapa' ? 'mapa' : vista === 'fluxo' ? 'fluxo-' + atual : atual; if (location.hash !== '#' + h) history.replaceState(null, '', '#' + h); }
function ir(v, c) {
  if (c && cods.includes(c)) atual = c;
  vista = v; sel.value = atual;
  for (const k in V) { V[k].hidden = k !== v; B[k].setAttribute('aria-pressed', String(k === v)); }
  if (v === 'inst') js.forEach(d => d.hidden = d.dataset.c !== atual);
  if (v === 'fluxo') abreFluxo();
  if (v === 'mapa') marca(atual);
  hash(); if (v !== 'mapa') window.scrollTo(0, 0);
}
sel.onchange = () => ir(vista === 'mapa' ? 'inst' : vista, sel.value);
function passo(k) { const i = cods.indexOf(atual); ir(vista === 'mapa' ? 'inst' : vista, cods[(i + k + cods.length) % cods.length]); }
document.getElementById('ant').onclick = () => passo(-1); document.getElementById('prox').onclick = () => passo(1);
B.mapa.onclick = () => ir('mapa'); B.inst.onclick = () => ir('inst'); B.fluxo.onclick = () => ir('fluxo');
js.forEach(d => { const bt = document.createElement('button'); bt.className = 'abrir-fluxo'; bt.textContent = 'Ver o fluxo completo'; bt.onclick = () => ir('fluxo', d.dataset.c); d.querySelector('header').append(bt); });

// fluxo completo com zoom
const img = document.getElementById('f-img'), rolo = document.getElementById('rolo');
function aplica() { const d = DIMS[atual]; img.style.width = (d[2] * zoom) + 'px'; img.style.height = (d[3] * zoom) + 'px'; }
function ajusta() { const d = DIMS[atual]; zoom = Math.max(0.08, Math.min(1, (rolo.clientWidth - 4) / d[2])); aplica(); }
function abreFluxo() {
  const no = MAPA.nos.find(n => n.c === atual);
  document.getElementById('f-tit').textContent = atual + ' · ' + no.n;
  img.alt = 'Fluxo BPMN da jornada ' + atual; img.src = 'fluxos/' + atual + '.svg';
  zoom = null; requestAnimationFrame(() => { ajusta(); });
}
document.getElementById('z-mais').onclick = () => { zoom = Math.min(2, zoom * 1.4); aplica(); };
document.getElementById('z-menos').onclick = () => { zoom = Math.max(0.05, zoom / 1.4); aplica(); };
document.getElementById('z-ajusta').onclick = ajusta;
let arr = null;
rolo.addEventListener('pointerdown', e => { arr = { x: e.clientX, y: e.clientY, l: rolo.scrollLeft, t: rolo.scrollTop }; rolo.setPointerCapture(e.pointerId); });
rolo.addEventListener('pointermove', e => { if (arr) { rolo.scrollLeft = arr.l - (e.clientX - arr.x); rolo.scrollTop = arr.t - (e.clientY - arr.y); } });
rolo.addEventListener('pointerup', () => arr = null);

// mapa geral: jornadas em anel, agrupadas por círculo; ligações em curva pelo centro
const NS = 'http://www.w3.org/2000/svg', svg = document.getElementById('mapa');
const mk = (t, a, p) => { const e = document.createElementNS(NS, t); for (const k in a) e.setAttribute(k, a[k]); (p || svg).append(e); return e; };
const R = 400, GAP = 0.09, N = MAPA.nos.length, K = MAPA.circulos.length;
const passoA = (2 * Math.PI - K * GAP) / N, pos = {}, porK = {};
let ang = -Math.PI / 2 + GAP / 2;
MAPA.circulos.forEach(c => {
  const nos = MAPA.nos.filter(n => n.k === c.k), a0 = ang;
  nos.forEach(n => { pos[n.c] = ang + passoA / 2; ang += passoA; });
  porK[c.k] = [a0, ang]; ang += GAP;
});
const gA = mk('g', {}), gN = mk('g', {});
const maxN = Math.max(...MAPA.arestas.map(a => a[2]));
const arestas = MAPA.arestas.map(([a, b, n, ps]) => {
  const p1 = [R * Math.cos(pos[a]), R * Math.sin(pos[a])], p2 = [R * Math.cos(pos[b]), R * Math.sin(pos[b])];
  const e = mk('path', { class: 'ar', d: `M${p1[0].toFixed(1)},${p1[1].toFixed(1)} Q${((p1[0] + p2[0]) * 0.18).toFixed(1)},${((p1[1] + p2[1]) * 0.18).toFixed(1)} ${p2[0].toFixed(1)},${p2[1].toFixed(1)}`, 'stroke-width': (0.8 + 2.6 * n / maxN).toFixed(2) }, gA);
  return { a, b, n, ps, e };
});
MAPA.circulos.forEach(c => {
  const [a0, a1] = porK[c.k], R2 = R + 64;
  const arc = mk('path', { class: 'arco', d: `M${(R2 * Math.cos(a0)).toFixed(1)},${(R2 * Math.sin(a0)).toFixed(1)} A${R2},${R2} 0 ${a1 - a0 > Math.PI ? 1 : 0} 1 ${(R2 * Math.cos(a1)).toFixed(1)},${(R2 * Math.sin(a1)).toFixed(1)}`, 'data-k': c.k });
  const am = (a0 + a1) / 2, R3 = R + 98;
  const tx = mk('text', { class: 'setor', x: (R3 * Math.cos(am)).toFixed(1), y: (R3 * Math.sin(am)).toFixed(1), 'text-anchor': Math.cos(am) > 0.25 ? 'start' : Math.cos(am) < -0.25 ? 'end' : 'middle', 'dominant-baseline': 'middle', tabindex: 0 });
  tx.textContent = c.k + ' · ' + c.nome; tx.onclick = () => marcaCirculo(c.k);
  tx.onkeydown = e => { if (e.key === 'Enter') marcaCirculo(c.k); };
});
const nosEl = {};
MAPA.nos.forEach(n => {
  const a = pos[n.c], g = mk('g', { class: 'no', tabindex: 0, role: 'button', 'aria-label': n.c + ' ' + n.n }, gN);
  mk('circle', { cx: (R * Math.cos(a)).toFixed(1), cy: (R * Math.sin(a)).toFixed(1), r: 7 }, g);
  const t = mk('text', { x: ((R + 14) * Math.cos(a)).toFixed(1), y: ((R + 14) * Math.sin(a)).toFixed(1), 'dominant-baseline': 'middle',
    'text-anchor': Math.cos(a) >= 0 ? 'start' : 'end', transform: `rotate(${(Math.cos(a) >= 0 ? a : a + Math.PI) * 180 / Math.PI} ${((R + 14) * Math.cos(a)).toFixed(1)} ${((R + 14) * Math.sin(a)).toFixed(1)})` }, g);
  t.textContent = n.c;
  g.onclick = () => marca(n.c); g.onkeydown = e => { if (e.key === 'Enter') marca(n.c); };
  g.onmouseenter = () => marca(n.c, true);
  nosEl[n.c] = g;
});
const lado = document.getElementById('lado');
const el = (t, txt, a = {}) => { const e = document.createElement(t); if (txt != null) e.textContent = txt; Object.assign(e, a); return e; };
function marca(c, leve) {
  if (!leve) atual = c;
  const sai = arestas.filter(x => x.a === c), entra = arestas.filter(x => x.b === c);
  const lig = new Set([...sai.map(x => x.b), ...entra.map(x => x.a)]);
  arestas.forEach(x => { x.e.setAttribute('class', 'ar ' + (x.a === c ? 'sai' : x.b === c ? 'entra' : 'apaga')); });
  Object.entries(nosEl).forEach(([k, g]) => g.setAttribute('class', 'no' + (k === c ? ' on' : lig.has(k) ? ' liga' : '')));
  document.querySelectorAll('#mapa .arco').forEach(a => a.setAttribute('class', 'arco'));
  const no = MAPA.nos.find(n => n.c === c);
  lado.replaceChildren(el('div', `Círculo ${no.k} · ${no.ck}`, { className: 'eyebrow' }), el('h2', `${no.c} · ${no.n}`),
    el('p', `Entrega para ${sai.length} jornadas e recebe de ${entra.length}.`));
  const lista = (tit, xs, campo) => { if (!xs.length) return; lado.append(el('div', tit, { className: 'sub' })); const ul = el('ul');
    xs.sort((p, q) => q.n - p.n).slice(0, 8).forEach(x => ul.append(el('li', `${x[campo]}: ${x.ps.slice(0, 2).join('; ')}${x.n > 2 ? ` (+${x.n - 2})` : ''}`))); if (xs.length > 8) ul.append(el('li', `e mais ${xs.length - 8}`)); lado.append(ul); };
  lista('Entrega para', sai, 'b'); lista('Recebe de', entra, 'a');
  const ac = el('div', null, { className: 'acoes' });
  ac.append(el('button', 'Abrir a instrução', { onclick: () => ir('inst', c) }), el('button', 'Ver o fluxo', { onclick: () => ir('fluxo', c) }));
  lado.append(ac);
}
function marcaCirculo(k) {
  const nos = new Set(MAPA.nos.filter(n => n.k === k).map(n => n.c));
  arestas.forEach(x => x.e.setAttribute('class', 'ar ' + (nos.has(x.a) && !nos.has(x.b) ? 'sai' : nos.has(x.b) && !nos.has(x.a) ? 'entra' : nos.has(x.a) ? 'sai' : 'apaga')));
  Object.entries(nosEl).forEach(([c, g]) => g.setAttribute('class', 'no' + (nos.has(c) ? ' on' : '')));
  document.querySelectorAll('#mapa .arco').forEach(a => a.setAttribute('class', 'arco' + (+a.dataset.k === k ? ' on' : '')));
  const c = MAPA.circulos.find(x => x.k === k), sai = arestas.filter(x => nos.has(x.a) && !nos.has(x.b)), entra = arestas.filter(x => nos.has(x.b) && !nos.has(x.a));
  lado.replaceChildren(el('div', 'Círculo', { className: 'eyebrow' }), el('h2', `${k} · ${c.nome}`),
    el('p', `${nos.size} jornadas. ${sai.length} ligações saem para outros círculos e ${entra.length} chegam de outros círculos.`),
    el('p', 'Clique numa jornada para ver as ligações dela.', { className: 'quem' }));
}
const h = decodeURIComponent(location.hash.slice(1));
if (h.startsWith('fluxo-') && cods.includes(h.slice(6))) ir('fluxo', h.slice(6));
else if (cods.includes(h)) ir('inst', h);
else ir('mapa');
</script>"""


if __name__ == '__main__':
    main()
