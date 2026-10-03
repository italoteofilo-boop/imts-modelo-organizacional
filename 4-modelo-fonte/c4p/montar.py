# -*- coding: utf-8 -*-
"""Monta c4.py a partir dos fragmentos em c4p/."""
import os
B = os.path.dirname(os.path.abspath(__file__))
fs = ['00_head.py', '01_demanda.py', '02_clientes.py', '03_parcerias_comunicacao.py', '99_tail.py']
s = ''.join(open(os.path.join(B, f), encoding='utf-8').read() for f in fs)
open(os.path.join(B, '..', 'c4.py'), 'w', encoding='utf-8').write(s)
print('c4.py', len(s))
