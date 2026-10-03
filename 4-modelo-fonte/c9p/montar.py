# -*- coding: utf-8 -*-
"""Monta c9.py a partir dos fragmentos em c9p/."""
import os
B = os.path.dirname(os.path.abspath(__file__))
fs = ['00_head.py', '01_regras.py', '02_contratos_auditoria.py', '03_dados_crise.py', '99_tail.py']
s = ''.join(open(os.path.join(B, f), encoding='utf-8').read() for f in fs)
open(os.path.join(B, '..', 'c9.py'), 'w', encoding='utf-8').write(s)
print('c9.py', len(s))
