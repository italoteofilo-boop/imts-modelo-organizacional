# -*- coding: utf-8 -*-
"""Gera, a partir de dados.py: grafo de cada jornada, testes de integridade,
BPMN 2.0 (XML com diagrama) e o JSON usado pela página."""
import json, os, re, sys
from collections import Counter, defaultdict
from xml.sax.saxutils import escape, quoteattr
from dados import JORNADAS, LANES, PARTES, FONTES, DOMINIOS, MUDANCAS, CIRCULOS, FRONTEIRAS, PONTOS, ONDAS

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'saida')
os.makedirs(os.path.join(OUT, 'bpmn'), exist_ok=True)

EXEC_NOME = {'P': 'Pessoa da Identidade', 'A': 'Agente da Identidade', 'R': 'Automação da Identidade',
             'C': 'Outro círculo', 'H': 'Pessoa de fora do círculo', 'X': 'Assessoria externa'}
CODES = [j['code'] for j in JORNADAS]
BYCODE = {j['code']: j for j in JORNADAS}


# ------------------------------------------------------------------ grafo
def build(j):
    p = j['code'].replace('-', '')
    nodes, order, edges = {}, [], []
    groups = defaultdict(list)          # etapa (1..n) -> ids

    def add(n):
        nodes[n['id']] = n
        order.append(n['id'])
        if n.get('etapa'):
            groups[n['etapa']].append(n['id'])
        return n['id']

    for i, s in enumerate(j['inicios'], 1):
        add(dict(id=f'{p}_S{i}', kind='start', name=s['nome'], lane=s['lane'], tipo=s['tipo'], etapa=None))

    # fins referenciados por saídas de decisão
    refs = Counter()
    for et in j['etapas']:
        for it in et['fluxo']:
            if it['k'] == 'D':
                for s in it['saidas']:
                    if s['destino'].startswith('F'):
                        refs[s['destino']] += 1
    fins = {f'F{k}': f for k, f in enumerate(j['fins'], 1)}
    default_end = next(k for k in fins if refs[k] == 0)
    placed = {}

    def place_end(key, etapa, offset):
        if key in placed:
            return placed[key]
        f = fins[key]
        nid = add(dict(id=f'{p}_{key}', kind='end', name=f['nome'], lane=f['lane'], etapa=None,
                       offset=offset))
        placed[key] = nid
        return nid

    # passo 1: criar nós na ordem das colunas
    entry = {}                       # ('E', n) -> id ; ('I', n, idx) -> id
    tcount = Counter()
    seen_refs = Counter()
    for e, et in enumerate(j['etapas'], 1):
        gcount = pcount = 0
        for idx, it in enumerate(et['fluxo']):
            def mk_task(t):
                tcount[e] += 1
                t['id'] = add(dict(id=f'{p}_E{e}_T{tcount[e]}', kind='task', name=t['nome'], lane=t['lane'],
                                   tipo=t['tipo'], exec=t['exec'], etapa=e))
                return t['id']
            if it['k'] == 'T':
                nid = mk_task(it)
            elif it['k'] == 'PAR':
                pcount += 1
                first_lane = it['ramos'][0][0]['lane']
                nid = add(dict(id=f'{p}_E{e}_PS{pcount}', kind='psplit', name='', lane=first_lane, etapa=e))
                it['split'] = nid
                for r in it['ramos']:
                    for t in r:
                        mk_task(t)
                it['join'] = add(dict(id=f'{p}_E{e}_PJ{pcount}', kind='pjoin', name='', lane=it['ramos'][-1][-1]['lane'], etapa=e))
            else:
                gcount += 1
                nid = add(dict(id=f'{p}_E{e}_G{gcount}', kind='xgw', name=it['pergunta'], lane=it['lane'], etapa=e))
                it['id'] = nid
                for s in it['saidas']:
                    for t in s['via']:
                        mk_task(t)
                    d = s['destino']
                    if d.startswith('F'):
                        seen_refs[d] += 1
                        if seen_refs[d] == refs[d]:
                            place_end(d, e, 50 if (not s['via'] and refs[d] == 1) else 0)
            if idx == 0:
                entry[('E', e)] = nid
            entry[('I', e, idx)] = nid
    place_end(default_end, None, 0)

    # passo 2: arestas
    def E_(a, b, label=None, cond=False):
        edges.append(dict(src=a, dst=b, label=label, cond=cond))

    n_et = len(j['etapas'])

    def next_etapa_entry(e):
        return entry[('E', e + 1)] if e < n_et else placed[default_end]

    for sid in [n for n in order if nodes[n]['kind'] == 'start']:
        E_(sid, entry[('E', 1)])
    for e, et in enumerate(j['etapas'], 1):
        pending = []
        items = et['fluxo']
        for idx, it in enumerate(items):
            ent = entry[('I', e, idx)]
            for (nid, lab, cond) in pending:
                E_(nid, ent, lab, cond)
            pending = []
            if it['k'] == 'T':
                pending = [(it['id'], None, False)]
            elif it['k'] == 'PAR':
                for r in it['ramos']:
                    E_(it['split'], r[0]['id'])
                    for a, b in zip(r, r[1:]):
                        E_(a['id'], b['id'])
                    E_(r[-1]['id'], it['join'])
                pending = [(it['join'], None, False)]
            else:
                for s in it['saidas']:
                    if s['via']:
                        E_(it['id'], s['via'][0]['id'], s['rotulo'], True)
                        for a, b in zip(s['via'], s['via'][1:]):
                            E_(a['id'], b['id'])
                        tail, lab, cond = s['via'][-1]['id'], None, False
                    else:
                        tail, lab, cond = it['id'], s['rotulo'], True
                    d = s['destino']
                    if d == 'seg':
                        pending.append((tail, lab, cond))
                    elif d == 'prox':
                        E_(tail, next_etapa_entry(e), lab, cond)
                    elif d.startswith('E'):
                        E_(tail, entry[('E', int(d[1:]))], lab, cond)
                    elif d.startswith('F'):
                        E_(tail, placed[d], lab, cond)
                    else:
                        raise ValueError(d)
        for (nid, lab, cond) in pending:
            E_(nid, next_etapa_entry(e), lab, cond)

    # passo 3: gateways de junção onde há mais de uma entrada
    inc = defaultdict(list)
    for ed in edges:
        inc[ed['dst']].append(ed)
    mcount = 0
    for nid in list(order):
        n = nodes[nid]
        if len(inc[nid]) > 1 and n['kind'] != 'pjoin':
            mcount += 1
            mid = f'{p}_M{mcount}'
            nodes[mid] = dict(id=mid, kind='merge', name='', lane=n['lane'], etapa=n.get('etapa'))
            order.insert(order.index(nid), mid)
            if n.get('etapa'):
                g = groups[n['etapa']]
                g.insert(g.index(nid) if nid in g else 0, mid)
            for ed in inc[nid]:
                ed['dst'] = mid
            edges.append(dict(src=mid, dst=nid, label=None, cond=False))
            n['offset'] = 0
    for k, ed in enumerate(edges, 1):
        ed['id'] = f'{p}_Flow{k}'
    return dict(p=p, nodes=nodes, order=order, edges=edges, groups=groups, entry=entry)


# -------------------------------------------------------------- integridade
def integridade(graphs):
    """Devolve (problemas, número de verificações feitas)."""
    probs = []
    n_chk = [0]

    def chk(ok, msg):
        n_chk[0] += 1
        if not ok:
            probs.append(msg)
    verbo = re.compile(r'^[A-Za-zÀ-ÿ]+(ar|er|ir|or)$')
    for j in JORNADAS:
        c = j['code']
        n = len(j['etapas'])
        nomes = Counter()
        chk(bool(verbo.match(j['nome'].split()[0])), f'{c}: nome da jornada não começa com verbo')
        for e, et in enumerate(j['etapas'], 1):
            chk(bool(et['entradas']), f'{c} etapa {e}: sem entrada')
            chk(bool(et['saidas']), f'{c} etapa {e}: sem saída')
            tarefas = list(tasks_of(et))
            chk(bool(tarefas), f'{c} etapa {e}: sem tarefa')
            for t, cond in tarefas:
                nomes[t['nome']] += 1
                chk(bool(verbo.match(t['nome'].split()[0])),
                    f'{c} etapa {e}: tarefa não começa com verbo no infinitivo: {t["nome"]}')
            chk(bool(verbo.match(et['nome'].split()[0])), f'{c} etapa {e}: nome da etapa não começa com verbo: {et["nome"]}')
            # entradas: toda entrada tem origem válida e, se interna, aparece como saída de quem gera
            for (nome, de) in et['entradas']:
                if de.startswith('ID-'):
                    chk(de in BYCODE and any(nome == o and c in para for ex in BYCODE[de]['etapas'] for (o, para) in ex['saidas']),
                        f'{c} etapa {e}: entrada "{nome}" de {de} não aparece como saída de {de} para {c}')
                elif de.startswith('etapa '):
                    k = int(de.split()[1])
                    chk(1 <= k <= n and any(nome == o and f'etapa {e}' in para for (o, para) in j['etapas'][k - 1]['saidas']),
                        f'{c} etapa {e}: entrada "{nome}" da {de} não aparece como saída dela para a etapa {e}')
                else:
                    chk(de in PARTES, f'{c} etapa {e}: origem fora do vocabulário: {de}')
            # saídas: toda saída tem destino válido e, se interno, aparece como entrada de quem recebe
            for (nome, para) in et['saidas']:
                chk(bool(para), f'{c} etapa {e}: saída "{nome}" sem destino')
                for d in para:
                    if d.startswith('ID-'):
                        chk(d in BYCODE and any((nome, c) == (o, de) for ex in BYCODE[d]['etapas'] for (o, de) in ex['entradas']),
                            f'{c} etapa {e}: saída "{nome}" para {d} não aparece como entrada de {d}')
                    elif d.startswith('etapa '):
                        k = int(d.split()[1])
                        chk(1 <= k <= n and any((nome, f'etapa {e}') == x for x in j['etapas'][k - 1]['entradas']),
                            f'{c} etapa {e}: saída "{nome}" para a {d} não aparece como entrada dela')
                    else:
                        chk(d in PARTES, f'{c} etapa {e}: destino fora do vocabulário: {d}')
            # modo e risco coerentes com quem executa
            main = [t for t, cond in tarefas if not cond]
            exs = Counter(t['exec'] for t in main)
            allx = Counter(t['exec'] for t, cond in tarefas)
            humano = exs['P'] + exs['H'] + exs['C'] + exs['X']
            m = et['modo']
            chk(not (et['risco'] == 'alto' and m not in ('Assistido', 'Copiloto')), f'{c} etapa {e}: risco alto com modo {m}')
            if m == 'Autômato':
                chk(not (exs['P'] or exs['A']), f'{c} etapa {e}: Autômato com tarefa de pessoa ou agente da Identidade')
            elif m == 'Autopiloto':
                chk((allx['A'] or allx['R']) and not exs['P'], f'{c} etapa {e}: Autopiloto exige agente ou automação e nenhuma pessoa da Identidade no caminho principal')
            elif m == 'Copiloto':
                chk((allx['A'] or allx['R']) and humano, f'{c} etapa {e}: Copiloto exige agente ou automação e uma pessoa')
            else:
                chk(bool(humano), f'{c} etapa {e}: Assistido sem pessoa')
        for nome, q in nomes.items():
            chk(q == 1, f'{c}: nome de tarefa repetido: {nome}')
        # grafo: todo nó é alcançado desde um início e chega a um fim; sem divisão ou junção implícita
        g = graphs[c]
        out = defaultdict(list); inn = defaultdict(list)
        for ed in g['edges']:
            out[ed['src']].append(ed['dst']); inn[ed['dst']].append(ed['src'])
        starts = [x for x in g['order'] if g['nodes'][x]['kind'] == 'start']
        ends = [x for x in g['order'] if g['nodes'][x]['kind'] == 'end']
        seen = set(starts); st = list(starts)
        while st:
            x = st.pop()
            for y in out[x]:
                if y not in seen:
                    seen.add(y); st.append(y)
        back = set(ends); st = list(ends)
        while st:
            x = st.pop()
            for y in inn[x]:
                if y not in back:
                    back.add(y); st.append(y)
        for nid in g['order']:
            k = g['nodes'][nid]['kind']
            chk(nid in seen, f'{c}: nó sem caminho desde o início: {nid}')
            chk(nid in back, f'{c}: nó sem caminho até um fim: {nid}')
            if k in ('task', 'start'):
                chk(len(out[nid]) == 1, f'{c}: {nid} deveria ter uma saída, tem {len(out[nid])}')
            if k in ('task', 'end', 'xgw', 'psplit'):
                chk(len(inn[nid]) == 1, f'{c}: {nid} deveria ter uma entrada, tem {len(inn[nid])}')
            if k == 'xgw':
                chk(len(out[nid]) >= 2, f'{c}: decisão com menos de duas saídas: {nid}')
            if k in ('merge', 'pjoin'):
                chk(len(inn[nid]) >= 2 and len(out[nid]) == 1, f'{c}: junção malformada: {nid}')
            if k == 'end':
                chk(not out[nid], f'{c}: fim com saída: {nid}')
        chk(len(ends) == len(j['fins']), f'{c}: fim declarado e não usado')
    return probs, n_chk[0]


def tasks_of(et):
    """(tarefa, condição) na ordem do fluxo; condição = texto do ramo quando a tarefa só ocorre num ramo."""
    for it in et['fluxo']:
        if it['k'] == 'T':
            yield it, None
        elif it['k'] == 'PAR':
            for r in it['ramos']:
                for t in r:
                    yield t, None
        else:
            for s in it['saidas']:
                for t in s['via']:
                    yield t, f'{it["pergunta"]} {s["rotulo"]}'


# ------------------------------------------------------------------ layout
X0, DX, LH = 150, 172, 160
TW, TH, EV, GW = 126, 84, 36, 50
POOL_LBL = 30


def layout(j, g):
    nodes, order, edges = g['nodes'], g['order'], g['edges']
    lanes = j['lanes']
    used = set(nodes[n]['lane'] for n in order)
    missing = used - set(lanes)
    assert not missing, (j['code'], missing)
    lanes = [l for l in lanes if l in used]
    li = {l: i for i, l in enumerate(lanes)}
    starts = [n for n in order if nodes[n]['kind'] == 'start']
    same_col = len(set(nodes[s]['lane'] for s in starts)) == len(starts)
    col = {}
    c = 0
    for nid in order:
        if nodes[nid]['kind'] == 'start' and same_col:
            col[nid] = 0
            continue
        if nodes[nid]['kind'] == 'start':
            col[nid] = c; c += 1
            continue
        if c == 0:
            c = 1
        col[nid] = c; c += 1
    ncols = c
    for nid in order:
        n = nodes[nid]
        w, h = {'task': (TW, TH), 'start': (EV, EV), 'end': (EV, EV)}.get(n['kind'], (GW, GW))
        cx = X0 + col[nid] * DX
        cy = li[n['lane']] * LH + LH / 2 + n.get('offset', 0)
        n.update(x=cx - w / 2, y=cy - h / 2, w=w, h=h, cx=cx, cy=cy, col=col[nid], li=li[n['lane']])
    W = X0 + (ncols - 1) * DX + TW / 2 + 70
    H = len(lanes) * LH

    # ----- roteamento
    PAD = 5
    segs_used = []          # (p1, p2, origem, destino) dos segmentos já desenhados
    side_out = defaultdict(set); side_in = defaultdict(set)

    def hits(pts, a, b):
        for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
            lo_x, hi_x = min(x1, x2), max(x1, x2)
            lo_y, hi_y = min(y1, y2), max(y1, y2)
            for nid in order:
                if nid in (a, b):
                    continue
                n = nodes[nid]
                if lo_x < n['x'] + n['w'] + PAD and hi_x > n['x'] - PAD and lo_y < n['y'] + n['h'] + PAD and hi_y > n['y'] - PAD:
                    return True
        # não atravessar a própria origem ou destino além do ponto de contato
        for nid, pp in ((a, pts[1:]), (b, pts[:-1])):
            n = nodes[nid]
            for (x1, y1), (x2, y2) in zip(pp, pp[1:]):
                lo_x, hi_x = min(x1, x2), max(x1, x2)
                lo_y, hi_y = min(y1, y2), max(y1, y2)
                if lo_x < n['x'] + n['w'] - 1 and hi_x > n['x'] + 1 and lo_y < n['y'] + n['h'] - 1 and hi_y > n['y'] + 1:
                    return True
        return False

    def overlap(pts, ed):
        """Comprimento de sobreposição com linhas de outros fluxos. Fluxos que saem da mesma
        origem ou chegam à mesma junção podem compartilhar a linha (barramento)."""
        tot = 0
        for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
            for (a1, b1), (a2, b2), s2, d2 in segs_used:
                if s2 == ed['src'] or (d2 == ed['dst'] and nodes[d2]['kind'] in ('merge', 'pjoin')):
                    continue
                if abs(x1 - x2) < 1 and abs(a1 - a2) < 1 and abs(x1 - a1) < 4:
                    lo, hi = max(min(y1, y2), min(b1, b2)), min(max(y1, y2), max(b1, b2))
                    tot += max(0, hi - lo)
                if abs(y1 - y2) < 1 and abs(b1 - b2) < 1 and abs(y1 - b1) < 4:
                    lo, hi = max(min(x1, x2), min(a1, a2)), min(max(x1, x2), max(a1, a2))
                    tot += max(0, hi - lo)
        return tot

    def side_pt(n, side):
        return {'right': (n['x'] + n['w'], n['cy']), 'left': (n['x'], n['cy']),
                'top': (n['cx'], n['y']), 'bottom': (n['cx'], n['y'] + n['h'])}[side]

    def candidates(u, v):
        fwd = v['col'] > u['col']
        out = []
        if fwd:
            if abs(u['cy'] - v['cy']) < 1:
                out.append((0, 'right', 'left', [side_pt(u, 'right'), side_pt(v, 'left')]))
            else:
                vs = 'bottom' if v['cy'] > u['cy'] else 'top'       # lado de saída de u em direção a v
                es = 'top' if v['cy'] > u['cy'] else 'bottom'       # lado de entrada em v vindo de u
                out.append((2, vs, 'left', [side_pt(u, vs), (u['cx'], v['cy']), side_pt(v, 'left')]))
                out.append((2, 'right', es, [side_pt(u, 'right'), (v['cx'], u['cy']), side_pt(v, es)]))
                for x1, c0 in ((v['x'] - 24, 3), (u['x'] + u['w'] + 24, 3)):
                    out.append((c0, 'right', 'left', [side_pt(u, 'right'), (x1, u['cy']), (x1, v['cy']), side_pt(v, 'left')]))
        for lane_i, base in ((u['li'], 6), (v['li'], 7)):
            for sd in ('top', 'bottom'):
                for k in range(6):
                    ch = lane_i * LH + 9 + 6 * k if sd == 'top' else (lane_i + 1) * LH - 8 - 6 * k
                    us = 'top' if ch < u['cy'] else 'bottom'
                    vs = 'top' if ch < v['cy'] else 'bottom'
                    pts = [side_pt(u, us), (u['cx'], ch), (v['cx'], ch), side_pt(v, vs)]
                    out.append((base + (0 if sd == 'top' else 1) + 0.6 * k, us, vs, pts))
        return out

    def route(ed):
        u, v = nodes[ed['src']], nodes[ed['dst']]
        best = None
        for cost, us, vs, pts in candidates(u, v):
            pts = [(float(x), float(y)) for x, y in pts]
            pp = [pts[0]]
            for q in pts[1:]:
                if abs(q[0] - pp[-1][0]) > 0.5 or abs(q[1] - pp[-1][1]) > 0.5:
                    pp.append(q)
            if len(pp) < 2 or hits(pp, ed['src'], ed['dst']):
                continue
            if u['kind'] == 'start' and us != 'right':
                cost += 5
            if us in side_out[ed['src']]:
                cost += 40
            if vs in side_in[ed['dst']] and v['kind'] not in ('merge', 'pjoin'):
                cost += 40
            if us in side_in[ed['src']] or vs in side_out[ed['dst']]:
                cost += 60
            cost += overlap(pp, ed) / 4.0
            if best is None or cost < best[0]:
                best = (cost, us, vs, pp)
        if best is None:
            raise RuntimeError(f'sem rota: {ed}')
        cost, us, vs, pp = best
        side_out[ed['src']].add(us); side_in[ed['dst']].add(vs)
        for a, b in zip(pp, pp[1:]):
            segs_used.append((a, b, ed['src'], ed['dst']))
        ed['pts'] = pp; ed['us'] = us

    def key(ed):
        d = nodes[ed['dst']]['col'] - nodes[ed['src']]['col']
        return (0 if d == 1 else 1 if d > 1 else 2, abs(d), nodes[ed['src']]['col'])
    for ed in sorted(edges, key=key):
        route(ed)
    # caixas das etapas
    boxes = {}
    for e, ids in g['groups'].items():
        cs = [nodes[i]['col'] for i in ids]
        x1 = X0 + min(cs) * DX - DX / 2 + 8
        x2 = X0 + max(cs) * DX + DX / 2 - 8
        boxes[e] = (x1, -44, x2 - x1, H + 52)
    focos = {}
    n_et = len(j['etapas'])
    for e, ids in g['groups'].items():
        ids = list(ids)
        if e == 1:
            ids += [n for n in order if nodes[n]['kind'] == 'start']
            ids += [n for n in order if nodes[n]['kind'] == 'merge' and nodes[n]['col'] < min(nodes[i]['col'] for i in g['groups'][e])]
        cmax = max(nodes[i]['col'] for i in ids)
        nxt = min([nodes[i]['col'] for ee, ii in g['groups'].items() if ee > e for i in ii] or [10 ** 6])
        ids += [n for n in order if nodes[n]['kind'] == 'end' and cmax < nodes[n]['col'] < nxt]
        x1 = min(nodes[i]['x'] for i in ids); y1 = min(nodes[i]['y'] for i in ids)
        x2 = max(nodes[i]['x'] + nodes[i]['w'] for i in ids); y2 = max(nodes[i]['y'] + nodes[i]['h'] for i in ids)
        focos[e] = (x1, y1, x2 - x1, y2 - y1)
    return dict(lanes=lanes, W=W, H=H, boxes=boxes, focos=focos)


# -------------------------------------------------------------------- BPMN
TAG = {'user': 'userTask', 'manual': 'manualTask', 'service': 'serviceTask', 'rule': 'businessRuleTask',
       'script': 'scriptTask', 'call': 'callActivity', 'task': 'task'}
EVDEF = {'message': 'messageEventDefinition', 'timer': 'timerEventDefinition', 'signal': 'signalEventDefinition'}


def bpmn_xml(j, g, lay):
    p = g['p']; nodes, order, edges = g['nodes'], g['order'], g['edges']
    A = quoteattr
    out = defaultdict(list); inn = defaultdict(list)
    for ed in edges:
        out[ed['src']].append(ed['id']); inn[ed['dst']].append(ed['id'])
    x = []
    x.append('<?xml version="1.0" encoding="UTF-8"?>')
    x.append('<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
             'xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" '
             'xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" '
             'xmlns:di="http://www.omg.org/spec/DD/20100524/DI" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
             f'id="Definitions_{p}" targetNamespace="urn:imts:modelo:identidade" '
             'exporter="Ecossistema IMTS - fonte única do Círculo 1" exporterVersion="2026-10-01">')
    x.append(f'  <bpmn:category id="Category_{p}">')
    for e, et in enumerate(j['etapas'], 1):
        rot = str(e) + '. ' + et['nome']
        x.append(f'    <bpmn:categoryValue id="CV_{p}_E{e}" value={A(rot)} />')
    x.append('  </bpmn:category>')
    x.append(f'  <bpmn:collaboration id="Collab_{p}">')
    x.append(f'    <bpmn:participant id="Participant_{p}" name={A(j["code"] + " · " + j["nome"])} processRef="Process_{p}" />')
    for e in range(1, len(j['etapas']) + 1):
        x.append(f'    <bpmn:group id="Group_{p}_E{e}" categoryValueRef="CV_{p}_E{e}" />')
    x.append('  </bpmn:collaboration>')
    x.append(f'  <bpmn:process id="Process_{p}" name={A(j["nome"])} isExecutable="false">')
    x.append(f'    <bpmn:documentation>{escape(j["objetivo"])}</bpmn:documentation>')
    x.append(f'    <bpmn:laneSet id="LaneSet_{p}">')
    for l in lay['lanes']:
        x.append(f'      <bpmn:lane id="Lane_{p}_{l}" name={A(LANES[l])}>')
        for nid in order:
            if nodes[nid]['lane'] == l:
                x.append(f'        <bpmn:flowNodeRef>{nid}</bpmn:flowNodeRef>')
        x.append('      </bpmn:lane>')
    x.append('    </bpmn:laneSet>')

    def io(nid):
        s = ''.join(f'<bpmn:incoming>{f}</bpmn:incoming>' for f in inn[nid])
        s += ''.join(f'<bpmn:outgoing>{f}</bpmn:outgoing>' for f in out[nid])
        return s
    for nid in order:
        n = nodes[nid]; k = n['kind']
        if k == 'start':
            x.append(f'    <bpmn:startEvent id="{nid}" name={A(n["name"])}>{io(nid)}<bpmn:{EVDEF[n["tipo"]]} id="{nid}_def" /></bpmn:startEvent>')
        elif k == 'end':
            x.append(f'    <bpmn:endEvent id="{nid}" name={A(n["name"])}>{io(nid)}</bpmn:endEvent>')
        elif k == 'task':
            et = j['etapas'][n['etapa'] - 1]
            doc = f'Etapa {n["etapa"]}: {et["nome"]}. Executor: {EXEC_NOME[n["exec"]]} ({LANES[n["lane"]]}). Modo da etapa: {et["modo"]}; risco {et["risco"]}.'
            x.append(f'    <bpmn:{TAG[n["tipo"]]} id="{nid}" name={A(n["name"])}><bpmn:documentation>{escape(doc)}</bpmn:documentation>{io(nid)}</bpmn:{TAG[n["tipo"]]}>')
        elif k == 'xgw':
            x.append(f'    <bpmn:exclusiveGateway id="{nid}" name={A(n["name"])}>{io(nid)}</bpmn:exclusiveGateway>')
        elif k == 'merge':
            x.append(f'    <bpmn:exclusiveGateway id="{nid}">{io(nid)}</bpmn:exclusiveGateway>')
        else:
            x.append(f'    <bpmn:parallelGateway id="{nid}">{io(nid)}</bpmn:parallelGateway>')
    for ed in edges:
        nm = f' name={A(ed["label"])}' if ed['label'] else ''
        if ed['cond']:
            x.append(f'    <bpmn:sequenceFlow id="{ed["id"]}"{nm} sourceRef="{ed["src"]}" targetRef="{ed["dst"]}">'
                     f'<bpmn:conditionExpression xsi:type="bpmn:tFormalExpression">{escape(ed["label"])}</bpmn:conditionExpression></bpmn:sequenceFlow>')
        else:
            x.append(f'    <bpmn:sequenceFlow id="{ed["id"]}"{nm} sourceRef="{ed["src"]}" targetRef="{ed["dst"]}" />')
    x.append('  </bpmn:process>')
    # ----- DI
    W, H = lay['W'], lay['H']
    f = lambda v: ('%.1f' % v).rstrip('0').rstrip('.')
    x.append(f'  <bpmndi:BPMNDiagram id="Diagram_{p}">')
    x.append(f'    <bpmndi:BPMNPlane id="Plane_{p}" bpmnElement="Collab_{p}">')
    x.append(f'      <bpmndi:BPMNShape id="Participant_{p}_di" bpmnElement="Participant_{p}" isHorizontal="true"><dc:Bounds x="0" y="0" width="{f(W)}" height="{f(H)}" /></bpmndi:BPMNShape>')
    for i, l in enumerate(lay['lanes']):
        x.append(f'      <bpmndi:BPMNShape id="Lane_{p}_{l}_di" bpmnElement="Lane_{p}_{l}" isHorizontal="true"><dc:Bounds x="{POOL_LBL}" y="{i * LH}" width="{f(W - POOL_LBL)}" height="{LH}" /></bpmndi:BPMNShape>')
    for nid in order:
        n = nodes[nid]; k = n['kind']
        extra = ' isMarkerVisible="true"' if k in ('xgw', 'merge') else ''
        lbl = ''
        if k in ('start', 'end') and n['name']:
            if n.get('offset'):
                lbl = f'<bpmndi:BPMNLabel><dc:Bounds x="{f(n["x"] + n["w"] + 6)}" y="{f(n["cy"] - 20)}" width="84" height="40" /></bpmndi:BPMNLabel>'
            else:
                lbl = f'<bpmndi:BPMNLabel><dc:Bounds x="{f(n["cx"] - 55)}" y="{f(n["y"] + n["h"] + 5)}" width="110" height="40" /></bpmndi:BPMNLabel>'
        if k == 'xgw':
            lbl = f'<bpmndi:BPMNLabel><dc:Bounds x="{f(n["cx"] - 112)}" y="{f(n["y"] + n["h"] + 2)}" width="106" height="40" /></bpmndi:BPMNLabel>'
        x.append(f'      <bpmndi:BPMNShape id="{nid}_di" bpmnElement="{nid}"{extra}><dc:Bounds x="{f(n["x"])}" y="{f(n["y"])}" width="{n["w"]}" height="{n["h"]}" />{lbl}</bpmndi:BPMNShape>')
    for ed in edges:
        wp = ''.join(f'<di:waypoint x="{f(px)}" y="{f(py)}" />' for px, py in ed['pts'])
        lbl = ''
        if ed['label']:
            (ax, ay), (bx, by) = ed['pts'][0], ed['pts'][1]
            w = min(76, 8 + 6 * len(ed['label'])); h = 14 if len(ed['label']) <= 12 else 27
            if ed['us'] == 'right':
                lx, ly = ax + 5, ay - h - 4
            elif ed['us'] == 'top':
                lx, ly = ax + 6, ay - h - 4
            else:
                lx, ly = ax + 6, ay + 5
            lbl = f'<bpmndi:BPMNLabel><dc:Bounds x="{f(lx)}" y="{f(ly)}" width="{w}" height="{h}" /></bpmndi:BPMNLabel>'
        x.append(f'      <bpmndi:BPMNEdge id="{ed["id"]}_di" bpmnElement="{ed["id"]}">{wp}{lbl}</bpmndi:BPMNEdge>')
    for e, (bx, by, bw, bh) in sorted(lay['boxes'].items()):
        x.append(f'      <bpmndi:BPMNShape id="Group_{p}_E{e}_di" bpmnElement="Group_{p}_E{e}"><dc:Bounds x="{f(bx)}" y="{f(by)}" width="{f(bw)}" height="{f(bh)}" />'
                 f'<bpmndi:BPMNLabel><dc:Bounds x="{f(bx + 6)}" y="{f(by + 6)}" width="{f(bw - 12)}" height="30" /></bpmndi:BPMNLabel></bpmndi:BPMNShape>')
    x.append('    </bpmndi:BPMNPlane>')
    x.append('  </bpmndi:BPMNDiagram>')
    x.append('</bpmn:definitions>')
    return '\n'.join(x) + '\n'


# ---------------------------------------------------------------- exportação
def destino_txt(j, e, d):
    n = len(j['etapas'])
    fins = {f'F{k}': f for k, f in enumerate(j['fins'], 1)}
    if d in ('prox', 'seg'):
        if d == 'seg':
            return 'segue na etapa'
        return f'etapa {e + 1}' if e < n else 'fim da jornada'
    if d.startswith('E'):
        k = int(d[1:])
        return (f'volta à etapa {k}' if k <= e else f'vai para a etapa {k}')
    return 'fim: ' + fins[d]['nome']


def export(graphs, lays):
    js = []
    for j in JORNADAS:
        g, lay = graphs[j['code']], lays[j['code']]
        ets = []
        for e, et in enumerate(j['etapas'], 1):
            tarefas = [dict(nome=t['nome'], exec=t['exec'], raia=LANES[t['lane']], tipo=t['tipo'], cond=cond)
                       for t, cond in tasks_of(et)]
            par = any(it['k'] == 'PAR' for it in et['fluxo'])
            decs = []
            for it in et['fluxo']:
                if it['k'] == 'D':
                    decs.append(dict(pergunta=it['pergunta'], quem=LANES[it['lane']],
                                     saidas=[dict(rotulo=s['rotulo'],
                                                  via=[t['nome'] for t in s['via']],
                                                  vai=destino_txt(j, e, s['destino'])) for s in it['saidas']]))
            bx = lay['boxes'][e]
            ets.append(dict(n=e, nome=et['nome'], dono=et['dono'], modo=et['modo'], risco=et['risco'],
                            entradas=[dict(o=o, de=de) for o, de in et['entradas']],
                            tarefas=tarefas, paralelo=par, decisoes=decs,
                            saidas=[dict(o=o, para=para) for o, para in et['saidas']],
                            box=[round(v, 1) for v in bx], foco=[round(v, 1) for v in lay['focos'][e]]))
        js.append(dict(code=j['code'], nome=j['nome'], dominio=j['dominio'], classe=j['classe'], onda=j['onda'],
                       objetivo=j['objetivo'], frequencia=j['frequencia'],
                       automacao=dict(nivel=j['automacao'][0], motivo=j['automacao'][1]),
                       base=j['base'],
                       inicios=[dict(nome=s['nome'], raia=LANES[s['lane']], tipo=s['tipo']) for s in j['inicios']],
                       fins=[f['nome'] for f in j['fins']],
                       raias=[LANES[l] for l in lay['lanes']],
                       etapas=ets, size=[round(lay['W']), round(lay['H'])]))
    # interfaces com as outras partes
    recebe = defaultdict(lambda: defaultdict(set)); entrega = defaultdict(lambda: defaultdict(set))
    for j in JORNADAS:
        for et in j['etapas']:
            for o, de in et['entradas']:
                if de in PARTES:
                    entrega[de][o].add(j['code'])       # a parte entrega à Identidade
            for o, para in et['saidas']:
                for d in para:
                    if d in PARTES:
                        recebe[d][o].add(j['code'])     # a parte recebe da Identidade
    # participação em tarefas (raias de outros círculos e papéis)
    participa = defaultdict(set)
    for j in JORNADAS:
        for et in j['etapas']:
            for t, cond in tasks_of(et):
                if t['exec'] in ('C', 'H', 'X'):
                    participa[LANES[t['lane']]].add(j['code'])
    inter = []
    for parte in PARTES:
        if parte in recebe or parte in entrega:
            inter.append(dict(parte=parte,
                              entrega=[dict(o=o, em=sorted(c)) for o, c in sorted(entrega[parte].items())],
                              recebe=[dict(o=o, de=sorted(c)) for o, c in sorted(recebe[parte].items())]))
    # estatísticas
    st = Counter(); modos = Counter(); riscos = Counter()
    n_et = n_dec = 0
    por_j = {}
    for j in JORNADAS:
        cj = Counter()
        for et in j['etapas']:
            n_et += 1; modos[et['modo']] += 1; riscos[et['risco']] += 1
            n_dec += sum(1 for it in et['fluxo'] if it['k'] == 'D')
            for t, cond in tasks_of(et):
                st[t['exec']] += 1; cj[t['exec']] += 1
        por_j[j['code']] = dict(cj)
    stats = dict(jornadas=len(JORNADAS), essenciais=sum(1 for j in JORNADAS if j['classe'] == 'essencial'),
                 recomendadas=sum(1 for j in JORNADAS if j['classe'] == 'recomendada'),
                 etapas=n_et, tarefas=sum(st.values()), decisoes=n_dec, exec=dict(st), modos=dict(modos),
                 riscos=dict(riscos), por_jornada=por_j)
    data = dict(jornadas=js, dominios=[dict(nome=n, desc=d) for n, d in DOMINIOS], fontes=FONTES,
                mudancas=[dict(antes=a, agora=b, nota=c) for a, b, c in MUDANCAS],
                interfaces=inter, participa={k: sorted(v) for k, v in participa.items()}, stats=stats,
                exec_nome=EXEC_NOME,
                fronteiras=[dict(o=a, dono=b, nota=c) for a, b, c in FRONTEIRAS],
                pontos=[dict(q=a, proposta=b, contra=c) for a, b, c in PONTOS],
                ondas={str(k): v for k, v in ONDAS.items()})
    return data


def main():
    graphs = {j['code']: build(j) for j in JORNADAS}
    probs, n_chk = integridade(graphs)
    lays = {}
    for j in JORNADAS:
        lays[j['code']] = layout(j, graphs[j['code']])
        xml = bpmn_xml(j, graphs[j['code']], lays[j['code']])
        with open(os.path.join(OUT, 'bpmn', f'{j["code"]}.bpmn'), 'w', encoding='utf-8') as fh:
            fh.write(xml)
    data = export(graphs, lays)
    data['stats']['verificacoes'] = n_chk
    data['bpmn'] = {j['code']: open(os.path.join(OUT, 'bpmn', f'{j["code"]}.bpmn'), encoding='utf-8').read() for j in JORNADAS}
    with open(os.path.join(OUT, 'circulo1.json'), 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False)
    s = data['stats']
    print('jornadas', s['jornadas'], '| essenciais', s['essenciais'], '| recomendadas', s['recomendadas'])
    print('etapas', s['etapas'], '| tarefas', s['tarefas'], '| decisões', s['decisoes'])
    print('executor', s['exec']); print('modos', s['modos']); print('riscos', s['riscos'])
    for c, g in graphs.items():
        print(c, 'nós', len(g['order']), 'arestas', len(g['edges']), 'largura', round(lays[c]['W']))
    print('VERIFICAÇÕES:', n_chk, '| PROBLEMAS:', len(probs))
    for pb in probs:
        print(' -', pb)
    return 1 if probs else 0


if __name__ == '__main__':
    sys.exit(main())
