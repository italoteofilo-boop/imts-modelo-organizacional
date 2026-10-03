# -*- coding: utf-8 -*-
"""Monta painel.html: o modelo da página com o retrato embutido.
Uso: python3 painel/gerar_painel.py <retrato_painel.json> <detalhe_*.json ...>
  retrato_painel.json = saída de select rt.painel(); detalhe_X.json = saída de select rt.painel_detalhe('X', 8)."""
import collections, datetime, json, os, sys
aqui = os.path.dirname(os.path.abspath(__file__)); base = os.path.dirname(aqui)
painel = json.load(open(sys.argv[1], encoding='utf-8'))
detalhes = {}
for f in sys.argv[2:]:
    d = json.load(open(f, encoding='utf-8')); detalhes[d['jornada']] = d
circs, nos = [], []
for k in range(1, 10):
    c = json.load(open(os.path.join(base, 'saida', f'c{k}', 'circulo.json'), encoding='utf-8'))
    circs.append({'k': k, 'nome': c['circulo']['nome']})
    nos += [{'c': j['code'], 'n': j['nome'], 'k': k} for j in c['jornadas']]
num = {c['nome']: c['k'] for c in circs}
cz = json.load(open(os.path.join(base, 'saida', 'cruzamento.json'), encoding='utf-8'))
pares = collections.Counter((num[t['de']], num[t['para']]) for t in cz['trocas'])
sys.path.insert(0, base); import instrucoes  # mesma regra do mapa geral das instruções: 660 ligações entre jornadas
_cs = []
for k in range(1, 10):
    _d = json.load(open(os.path.join(base, 'saida', f'c{k}', 'circulo.json'), encoding='utf-8')); _c = dict(_d['circulo'], num=k)
    _cs.append((_c, [(j, None) for j in _d['jornadas']]))
sinapses = [[a, b, n] for a, b, n, _ in instrucoes.mapa_dados(_cs)['arestas']]
modelo = {'circulos': circs, 'nos': nos, 'trocasCirculos': [[a, b, n] for (a, b), n in sorted(pares.items())], 'sinapses': sinapses}
js = lambda x: json.dumps(x, ensure_ascii=False).replace('</', '<\\/')
quando = datetime.datetime.fromisoformat(painel['gerado_em']).strftime('%d/%m/%Y, %H:%M')
t = open(os.path.join(aqui, 'painel_modelo.html'), encoding='utf-8').read()
for k, v in (('__PAINEL__', js(painel)), ('__DETALHES__', js(detalhes)), ('__MODELO__', js(modelo)), ('__QUANDO__', quando)):
    assert t.count(k) == 1, k; t = t.replace(k, v)
open(os.path.join(aqui, 'painel.html'), 'w', encoding='utf-8').write(t)
print('painel.html', round(os.path.getsize(os.path.join(aqui, 'painel.html')) / 1024), 'KB', 'detalhes', len(detalhes), 'pares', len(pares), 'sinapses', len(sinapses))
