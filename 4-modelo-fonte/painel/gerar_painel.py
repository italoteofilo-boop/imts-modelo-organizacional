# -*- coding: utf-8 -*-
"""Monta painel.html: o modelo da página com o retrato de rt.painel() embutido.
Uso: python3 painel/gerar_painel.py <retrato.json>  (retrato = saída de: select rt.painel())"""
import json, os, sys
aqui = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(sys.argv[1], encoding='utf-8'))
dados = json.dumps(d, ensure_ascii=False).replace('</', '<\\/')
t = open(os.path.join(aqui, 'painel_modelo.html'), encoding='utf-8').read()
assert t.count('__DADOS__') == 1
open(os.path.join(aqui, 'painel.html'), 'w', encoding='utf-8').write(t.replace('__DADOS__', dados))
print('painel.html', round(os.path.getsize(os.path.join(aqui, 'painel.html')) / 1024), 'KB')
