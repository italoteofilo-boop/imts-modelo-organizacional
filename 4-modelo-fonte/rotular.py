# -*- coding: utf-8 -*-
"""Aplica nas fontes os critérios aprovados em 03/10/2026 (auditoria de execução): o modo de cada etapa e o nível de
automação de cada jornada passam a ser os que as tarefas dão. Lê saida/cN/circulo.json (rode gerar.py antes) e
reescreve c1.py a c3.py e os fragmentos c4p/ a c9p/. Lista cada mudança. Uso: python3 rotular.py [c1 ...]"""
import glob, json, os, re, sys
from gerar import classe_real, faixa_automacao, MODO_DA_CLASSE

BASE = os.path.dirname(os.path.abspath(__file__))
MODS = sys.argv[1:] or ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']


def fontes(m):
    n = int(m[1:])
    return [os.path.join(BASE, f'{m}.py')] if n <= 3 else sorted(glob.glob(os.path.join(BASE, f'{m}p', '[0-9]*.py')))


def bloco(txt, code):
    i = txt.find(f"code='{code}'")
    if i < 0:
        return None
    k = txt.find("code='", i + 1)
    return i, (k if k > 0 else len(txt))


mudancas = []
for m in MODS:
    d = json.load(open(os.path.join(BASE, 'saida', m, 'circulo.json'), encoding='utf-8'))
    arqs = {p: open(p, encoding='utf-8').read() for p in fontes(m)}
    for j in d['jornadas']:
        p = next((p for p, t in arqs.items() if bloco(t, j['code'])), None)
        assert p, j['code']
        txt = arqs[p]
        i, k = bloco(txt, j['code'])
        b = txt[i:k]
        todas_j = []
        for e in j['etapas']:
            todas = e['tarefas']
            todas_j += todas
            real = classe_real([t for t in todas if not t['cond']], todas)
            if e['modo'] in MODO_DA_CLASSE[real]:
                continue
            novo = MODO_DA_CLASSE[real][0]
            pad = f"E({e['nome']!r}, "
            q = b.find(pad)
            assert q >= 0 and b.count(pad) == 1, (j['code'], e['nome'])
            seg = b[q:q + 600]
            alvo = f"'{e['modo']}', '{e['risco']}',"
            assert alvo in seg, (j['code'], e['n'], alvo)
            r = q + seg.index(alvo)
            b = b[:r] + f"'{novo}', '{e['risco']}'," + b[r + len(alvo):]
            mudancas.append((j['code'], f"etapa {e['n']}", e['modo'], novo, real))
        n = len(todas_j)
        fx = faixa_automacao(sum(1 for t in todas_j if t['exec'] in ('A', 'R')) / n)
        nivel = j['automacao']['nivel']
        if nivel.split()[0].rstrip(',;') != fx:
            novo = fx if nivel in ('baixa', 'média', 'alta') else f'{fx} ({nivel})'
            alvo = f"automacao=({nivel!r},"
            assert b.count(alvo) == 1, j['code']
            b = b.replace(alvo, f"automacao=({novo!r},")
            mudancas.append((j['code'], 'automação', nivel, novo, ''))
        arqs[p] = txt[:i] + b + txt[k:]
    for p, t in arqs.items():
        open(p, 'w', encoding='utf-8').write(t)
for x in mudancas:
    print(' | '.join(x))
print('mudanças', len(mudancas))
json.dump(mudancas, open(os.path.join(BASE, 'saida', 'rotulos_mudados.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
