# -*- coding: utf-8 -*-
"""Monta mesa.html: o modelo da Mesa com o retrato embutido.
Uso: python3 mesa/gerar_mesa.py mesa/retrato_mesa.json
  retrato_mesa.json = pessoas (rt.mesa_pessoas), quadros (rt.quadro por pessoa), circulo (rt.quadro_circulo(1)), jornadas e tarefas do modelo."""
import datetime, json, os, sys
aqui = os.path.dirname(os.path.abspath(__file__)); base = os.path.dirname(aqui)
r = json.load(open(sys.argv[1], encoding='utf-8'))
circs = [{'k': k, 'nome': json.load(open(os.path.join(base, 'saida', f'c{k}', 'circulo.json'), encoding='utf-8'))['circulo']['nome']} for k in range(1, 10)]
js = lambda x: json.dumps(x, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
quando = datetime.datetime.fromisoformat(r['gerado_em']).strftime('%d/%m/%Y, %H:%M')
t = open(os.path.join(aqui, 'mesa_modelo.html'), encoding='utf-8').read()
for k, v in (('__RETRATO__', js(r)), ('__CIRCULOS__', js(circs)), ('__QUANDO__', quando)):
    assert t.count(k) == 1, k; t = t.replace(k, v)
open(os.path.join(aqui, 'mesa.html'), 'w', encoding='utf-8').write(t)
print('mesa.html', round(os.path.getsize(os.path.join(aqui, 'mesa.html')) / 1024), 'KB')
