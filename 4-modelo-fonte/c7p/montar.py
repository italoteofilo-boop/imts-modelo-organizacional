# -*- coding: utf-8 -*-
"""Monta c7.py a partir dos fragmentos em c7p/."""
import os
B = os.path.dirname(os.path.abspath(__file__))
fs = ['00_head.py', '01_entrega.py', '02_atendimento.py', '03_produto.py', '99_tail.py']
s = ''.join(open(os.path.join(B, f), encoding='utf-8').read() for f in fs)
open(os.path.join(B, '..', 'c7.py'), 'w', encoding='utf-8').write(s)
print('c7.py', len(s))
