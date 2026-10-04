# -*- coding: utf-8 -*-
"""Monta c8.py a partir dos fragmentos em c8p/."""
import os
B = os.path.dirname(os.path.abspath(__file__))
fs = ['00_head.py', '01_planejamento.py', '02_financas.py', '03_pessoas.py', '04_ativos.py', '05_contabil_tributario.py', '99_tail.py']
s = ''.join(open(os.path.join(B, f), encoding='utf-8').read() for f in fs)
open(os.path.join(B, '..', 'c8.py'), 'w', encoding='utf-8').write(s)
print('c8.py', len(s))
