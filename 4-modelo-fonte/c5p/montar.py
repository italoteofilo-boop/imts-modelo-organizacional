# -*- coding: utf-8 -*-
"""Monta c5.py a partir dos fragmentos em c5p/."""
import os
B = os.path.dirname(os.path.abspath(__file__))
fs = ['00_head.py', '01_preco_plano.py', '02_venda.py', '03_contas_conjunta.py', '99_tail.py']
s = ''.join(open(os.path.join(B, f), encoding='utf-8').read() for f in fs)
open(os.path.join(B, '..', 'c5.py'), 'w', encoding='utf-8').write(s)
print('c5.py', len(s))
