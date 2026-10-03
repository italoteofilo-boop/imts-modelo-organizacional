# -*- coding: utf-8 -*-
"""Roda todos os testes de todos os círculos desenhados e grava o resultado em saida/<mod>/testes.json.
Uso: python3 testar.py c1 c2"""
import json, os, re, subprocess, sys

BASE = os.path.dirname(os.path.abspath(__file__))
# onde estão o bpmn-js, o bpmn-moddle e o bpmnlint: ../c1 no ambiente de trabalho, ./ferramentas-node no pacote
NODE = next(p for p in (os.path.join(BASE, '..', 'c1'), os.path.join(BASE, 'ferramentas-node')) if os.path.exists(p))
mods = sys.argv[1:] or ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']


def run(cmd, cwd):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def num(pat, txt, grupo=1):
    m = re.search(pat, txt)
    assert m, (pat, txt[-600:])
    return int(m.group(grupo))


falhou = False
res = {}
for m in mods:
    bp = os.path.join(BASE, 'saida', m, 'bpmn')
    png = os.path.join(BASE, 'saida', m, 'png')
    rc1, o = run([sys.executable, 'gerar.py', m], BASE)
    integ = dict(verificacoes=num(r'VERIFICAÇÕES: (\d+)', o), problemas=num(r'PROBLEMAS: (\d+)', o))
    rc2, o = run(['node', 'validar2.mjs', bp], NODE)
    lint = dict(arquivos=num(r'ARQUIVOS (\d+)', o), apontamentos=num(r'TOTAL (\d+)', o), regras=num(r'REGRAS (\d+)', o))
    rc3, o = run(['node', 'render2.mjs', bp, png], NODE)
    render = dict(arquivos=len(re.findall(r'avisos \d+ erros \d+', o)), avisos=num(r'TOTAL de avisos e erros: (\d+)', o))
    rc4, o = run(['node', 'sobrepoe.mjs', bp], NODE)
    rot = dict(tarefas=num(r'TAREFAS (\d+)', o), problemas=num(r'RÓTULOS COM PROBLEMA (\d+)', o))
    rc5, o = run([sys.executable, 'mutacao.py', m], BASE)
    mut = dict(detectados=num(r'DEFEITOS DETECTADOS: (\d+) de (\d+)', o), total=num(r'DEFEITOS DETECTADOS: (\d+) de (\d+)', o, 2))
    res[m] = dict(integridade=integ, lint=lint, render=render, rotulos=rot, mutacao=mut)
    ok = not any([rc1, rc2, rc3, rc4, rc5])
    falhou = falhou or not ok
    print(m, 'OK' if ok else 'FALHOU', json.dumps(res[m], ensure_ascii=False))

# a mutação reescreve nada em disco, mas o gerar.py precisa rodar por último para deixar os arquivos finais
for m in mods:
    run([sys.executable, 'gerar.py', m], BASE)
rc, o = run([sys.executable, 'cruzar.py'] + mods, BASE)
cz = dict(trocas=num(r'trocas conferidas: (\d+)', o), verificacoes=num(r'verificações: (\d+)', o), problemas=num(r'problemas: (\d+)', o))
rcm, o = run([sys.executable, 'mutacao.py', 'cruzar'], BASE)
cz['mut_detectados'] = num(r'DEFEITOS DETECTADOS: (\d+) de (\d+)', o)
cz['mut_total'] = num(r'DEFEITOS DETECTADOS: (\d+) de (\d+)', o, 2)
falhou = falhou or bool(rc) or bool(rcm)
print('cruzamento', 'OK' if not (rc or rcm) else 'FALHOU', json.dumps(cz, ensure_ascii=False))
rca, o = run([sys.executable, 'alcadas_fluxo.py'], BASE)
cz['alcadas'] = num(r'ALÇADAS: (\d+)', o)
cz['alcadas_niveis'] = num(r'NÍVEIS CONFERIDOS: (\d+)', o)
cz['alcadas_faltas'] = num(r'FALTAS: (\d+)', o)
cz['alcadas_mut'] = num(r'DETECTADOS: (\d+) de (\d+)', o)
cz['alcadas_mut_total'] = num(r'DETECTADOS: (\d+) de (\d+)', o, 2)
falhou = falhou or bool(rca)
print('alçadas no fluxo', 'OK' if not rca else 'FALHOU', o.strip().splitlines()[-1] if o.strip() else '')
for m in mods:
    res[m]['cruzamento'] = cz
    with open(os.path.join(BASE, 'saida', m, 'testes.json'), 'w', encoding='utf-8') as fh:
        json.dump(res[m], fh, ensure_ascii=False, indent=1)
sys.exit(1 if falhou else 0)
