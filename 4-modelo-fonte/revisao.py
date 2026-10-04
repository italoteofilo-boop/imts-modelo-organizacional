# -*- coding: utf-8 -*-
"""Monta o pacote de leitura para a revisão independente: um arquivo de texto por círculo (com o fluxo
de cada etapa na ordem em que roda), as trocas entre os círculos e as fontes de um círculo.
Uso: python3 revisao.py c1 c2 c3   (o último é o círculo cujas fontes entram no pacote)"""
import importlib, json, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, 'saida', 'revisao')
os.makedirs(OUT, exist_ok=True)
mods = sys.argv[1:] or ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']

from fontes import FONTES_BASE


def destino(j, e, d):
    n = len(j['etapas'])
    fins = {f'F{k}': f for k, f in enumerate(j['fins'], 1)}
    if d == 'seg':
        return 'segue na etapa'
    if d == 'prox':
        if e < n:
            return f'vai para a etapa {e + 1}'
        usados = {s['destino'] for et in j['etapas'] for it in et['fluxo'] if it['k'] == 'D' for s in it['saidas']}
        return 'FIM: ' + next(f['nome'] for k, f in fins.items() if k not in usados)
    if d.startswith('E'):
        k = int(d[1:])
        return f'volta ao começo da etapa {k}' if k <= e else f'vai para a etapa {k}'
    return 'FIM: ' + fins[d]['nome']


def circulo(mod):
    M = importlib.import_module(mod)
    L = M.LANES
    out = []
    w = out.append

    def tarefa(t):
        tipo = f' [tipo BPMN: {t["tipo"]}]' if t['tipo'] in ('manual', 'call', 'rule', 'receive') else ''
        return f'{t["exec"]} | {L[t["lane"]]} | {t["nome"]}{tipo}'

    w(f'# Círculo {M.NUM} · {M.NOME} — {M.STATUS}\n')
    w(M.LEAD + '\n')
    if getattr(M, 'PRINCIPIO', None):
        w(M.PRINCIPIO + '\n')
    for j in M.JORNADAS:
        w(f'\n## {j["code"]} · {j["nome"]}')
        w(f'- Domínio: {j["dominio"]} | classe: {j["classe"]} | onda {j["onda"]} | automação: {j["automacao"][0]} — {j["automacao"][1]}')
        w(f'- Objetivo: {j["objetivo"]}')
        w(f'- Frequência: {j["frequencia"]}')
        w('- Começa quando (todos os inícios entram no primeiro item da etapa 1): ' +
          '; '.join(f'{s["nome"]} [{L[s["lane"]]}, {s["tipo"]}]' for s in j['inicios']))
        w('- Termina quando: ' + '; '.join(f['nome'] for f in j['fins']))
        w('- Base de mercado: ' + ', '.join(j['base']))
        for e, et in enumerate(j['etapas'], 1):
            w(f'\n### {j["code"]} etapa {e} — {et["nome"]}  (dono: {et["dono"]}; modo: {et["modo"]}; risco: {et["risco"]})')
            w('Entradas (o que entra ← quem gera):')
            for o, de in et['entradas']:
                w(f'  - {o} ← {de}')
            w('Fluxo, na ordem (executor | raia | tarefa):')
            for n, it in enumerate(et['fluxo'], 1):
                if it['k'] == 'T':
                    w(f'  {n}. {tarefa(it)}')
                elif it['k'] == 'PAR':
                    w(f'  {n}. EM PARALELO:')
                    for r, ramo in enumerate(it['ramos'], 1):
                        w(f'       ramo {r}: ' + ' → '.join(tarefa(t) for t in ramo))
                else:
                    w(f'  {n}. DECISÃO [{L[it["lane"]]}]: {it["pergunta"]}')
                    for s in it['saidas']:
                        via = ''.join(f'{tarefa(t)}; depois ' for t in s['via'])
                        w(f'       · {s["rotulo"]}: {via}{destino(j, e, s["destino"])}')
            ult = et['fluxo'][-1]
            if ult['k'] != 'D':
                w(f'  (depois do último item: {destino(j, e, "prox")})')
            w('Saídas (o que sai → quem recebe):')
            for o, para in et['saidas']:
                w(f'  - {o} → {", ".join(para)}')
    w('\n\n## O que o círculo não faz (fronteiras)')
    for o, dono, nota in M.FRONTEIRAS:
        w(f'- {o} — de quem é: {dono}. O círculo entrega: {nota}')
    if getattr(M, 'PONTOS', None):
        w('\n## Pontos para o dono do projeto decidir (proposta e argumento contra)')
        for n, (q, prop, contra) in enumerate(M.PONTOS, 1):
            w(f'{n}. {q}\n   - Proposta: {prop}\n   - Argumento contra: {contra}')
    if getattr(M, 'DECISOES', None):
        w('\n## Decisões que fecharam o círculo')
        for o, origem, efeito in M.DECISOES:
            w(f'- {o} [{origem}] — efeito: {efeito}')
    if getattr(M, 'PROPOSTAS', None):
        w('\n## Propostas de mudança pendentes (nenhuma aplicada)')
        for n, (o, porque, origem) in enumerate(M.PROPOSTAS, 1):
            w(f'{n}. {o} — por quê: {porque} [{origem}]')
    if getattr(M, 'ALERTAS', None):
        w('\n## Alertas para os próximos círculos')
        for o, nota in M.ALERTAS:
            w(f'- {o}: {nota}')
    if getattr(M, 'COBERTURA', None):
        w('\n## Cobertura do referencial (APQC PCF 7.4)')
        for ref, nome, onde in M.COBERTURA:
            w(f'- {ref} {nome} → {onde}')
    if getattr(M, 'MUDANCAS', None):
        w('\n## O que mudou em relação ao catálogo anterior')
        for tipo, antes, depois, nota in M.MUDANCAS:
            w(f'- [{tipo}] {antes} → {depois}: {nota}')
    w('\n## Limites declarados')
    for l in M.LIMITES:
        w(f'- {l}')
    open(os.path.join(OUT, mod + '.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    return M


Ms = [circulo(m) for m in mods]

# ----- trocas entre os círculos
cz = json.load(open(os.path.join(BASE, 'saida', 'cruzamento.json'), encoding='utf-8'))
out = ['# Trocas entre os círculos (o nome de cada produto já foi conferido dos dois lados por teste automático)\n']
for t in cz['trocas']:
    out.append(f'- {t["de"]} → {t["para"]}: {t["o"]} [sai em {", ".join(t["sai"])}; entra em {", ".join(t["entra"])}; chega: {t["via"]}]')
out.append('\n## Tarefas de um círculo dentro das jornadas de outro')
for t in cz['tarefas']:
    out.append(f'- {t["quem"]}, em {t["code"]} etapa {t["etapa"]}: {t["nome"]}')
open(os.path.join(OUT, 'cruzamento.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')

# ----- fontes do último círculo
M = Ms[-1]
out = [f'# Fontes do Círculo {M.NUM} · {M.NOME}: para conferência independente\n']
for k in sorted(M.USO):
    f = FONTES_BASE[k]
    out.append(f'\n## {k}')
    out.append(f'- Referência (como será publicada): {f["ref"]}')
    out.append(f'- O que dizemos que a fonte contém e como a usamos: {M.USO[k]}')
    out.append(f'- Como dizemos que foi conferida: {f["conf"]}')
    out.append('- Links:')
    for nome, url in f['links']:
        out.append(f'  - {nome}: {url}')
open(os.path.join(OUT, f'fontes_{mods[-1]}.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')
for f in sorted(os.listdir(OUT)):
    print(f, os.path.getsize(os.path.join(OUT, f)))
