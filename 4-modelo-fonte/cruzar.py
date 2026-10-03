# -*- coding: utf-8 -*-
"""Confere as trocas entre os círculos já desenhados, dos dois lados, e junta o que eles
pedem aos círculos que ainda não foram desenhados.
Uso: python3 cruzar.py c1 c2   (lê saida/<mod>/circulo.json e grava saida/cruzamento.json)"""
import json, os, sys
from collections import defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))
TODOS = 'Todos (pessoas e agentes)'
CORINGA = 'Solicitante'       # pedido de qualquer origem: pode ser um círculo


def carregar(mod):
    return json.load(open(os.path.join(BASE, 'saida', mod, 'circulo.json'), encoding='utf-8'))


def fluxos(d):
    """(entradas, saidas) de um círculo, com endereço jornada/etapa."""
    ent, sai = [], []
    for j in d['jornadas']:
        for e in j['etapas']:
            for x in e['entradas']:
                ent.append(dict(o=x['o'], de=x['de'], code=j['code'], etapa=e['n']))
            for x in e['saidas']:
                for p in x['para']:
                    sai.append(dict(o=x['o'], para=p, code=j['code'], etapa=e['n']))
    return ent, sai


def cruzar(dados):
    nomes = {m: d['circulo']['nome'] for m, d in dados.items()}
    fl = {m: fluxos(d) for m, d in dados.items()}
    trocas, probs, n = [], [], 0
    mods = list(dados)
    for a in mods:
        for b in mods:
            if a == b:
                continue
            A, B = nomes[a], nomes[b]
            ent_b, sai_a = fl[b][0], fl[a][1]
            # R1: toda entrada de B com origem A existe como saída de A para B, para todos ou para quem pediu
            vistos = set()
            for x in ent_b:
                if x['de'] != A:
                    continue
                n += 1
                ori = [s for s in sai_a if s['o'] == x['o'] and s['para'] in (B, TODOS, CORINGA)]
                if not ori:
                    probs.append(f'{x["code"]} etapa {x["etapa"]} ({B}) espera "{x["o"]}" de {A}, que não entrega esse produto a {B}')
                    continue
                via = 'direto' if any(s['para'] == B for s in ori) else ('a todos' if any(s['para'] == TODOS for s in ori) else 'a quem pediu')
                chave = (x['o'], A, B)
                if chave not in vistos:
                    vistos.add(chave)
                    trocas.append(dict(o=x['o'], de=A, para=B, via=via,
                                       sai=sorted({f'{s["code"]} etapa {s["etapa"]}' for s in ori}),
                                       entra=sorted({f'{y["code"]} etapa {y["etapa"]}' for y in ent_b if y['o'] == x['o'] and y['de'] == A})))
            # R2: toda saída de A endereçada a B existe como entrada de B (vinda de A ou de quem pede)
            for s in sai_a:
                if s['para'] != B:
                    continue
                n += 1
                dst = [y for y in ent_b if y['o'] == s['o'] and y['de'] in (A, CORINGA)]
                if not dst:
                    probs.append(f'{s["code"]} etapa {s["etapa"]} ({A}) entrega "{s["o"]}" a {B}, que não tem essa entrada')
                    continue
                chave = (s['o'], A, B)
                if chave not in vistos:
                    vistos.add(chave)
                    trocas.append(dict(o=s['o'], de=A, para=B, via='como pedido' if all(y['de'] == CORINGA for y in dst) else 'direto',
                                       sai=sorted({f'{z["code"]} etapa {z["etapa"]}' for z in sai_a if z['o'] == s['o'] and z['para'] == B}),
                                       entra=sorted({f'{y["code"]} etapa {y["etapa"]}' for y in dst})))
    # tarefas que um círculo faz dentro das jornadas do outro
    tarefas = []
    for a in mods:
        for t in dados[a]['tarefas_fora']:
            if t['parte'] in nomes.values():
                tarefas.append(dict(quem=t['parte'], em=nomes[a], code=t['code'], etapa=t['etapa'], nome=t['nome']))
    # o que os círculos desenhados pedem aos que faltam
    desenhados = set(nomes.values())
    req = defaultdict(lambda: dict(entrega=defaultdict(set), recebe=defaultdict(set), tarefas=defaultdict(set)))
    for m in mods:
        d = dados[m]
        for p in d['interfaces']:
            if p['parte'] in desenhados:
                continue
            for x in p['entrega']:
                req[p['parte']]['entrega'][x['o']].update(x['em'])
            for x in p['recebe']:
                req[p['parte']]['recebe'][x['o']].update(x['de'])
        for t in d['tarefas_fora']:
            if t['parte'] not in desenhados:
                req[t['parte']]['tarefas'][t['nome']].add(t['code'])
    requisitos = []
    for parte, r in req.items():
        requisitos.append(dict(parte=parte,
                               entrega=[dict(o=o, em=sorted(c)) for o, c in sorted(r['entrega'].items())],
                               recebe=[dict(o=o, de=sorted(c)) for o, c in sorted(r['recebe'].items())],
                               tarefas=[dict(nome=o, em=sorted(c)) for o, c in sorted(r['tarefas'].items())]))
    return dict(circulos=[nomes[m] for m in mods], trocas=trocas, problemas=probs, verificacoes=n,
                tarefas=tarefas, requisitos=requisitos)


def main():
    mods = sys.argv[1:] or ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']
    dados = {m: carregar(m) for m in mods}
    r = cruzar(dados)
    with open(os.path.join(BASE, 'saida', 'cruzamento.json'), 'w', encoding='utf-8') as fh:
        json.dump(r, fh, ensure_ascii=False, indent=1)
    print('círculos:', ', '.join(r['circulos']))
    print('trocas conferidas:', len(r['trocas']), '| verificações:', r['verificacoes'], '| problemas:', len(r['problemas']))
    for t in r['trocas']:
        print(f'  {t["de"]} -> {t["para"]}: {t["o"]} [{t["via"]}] sai em {", ".join(t["sai"])}; entra em {", ".join(t["entra"])}')
    for t in r['tarefas']:
        print(f'  tarefa de {t["quem"]} em {t["code"]} etapa {t["etapa"]}: {t["nome"]}')
    for p in r['problemas']:
        print(' -', p)
    return 1 if r['problemas'] else 0


if __name__ == '__main__':
    sys.exit(main())
