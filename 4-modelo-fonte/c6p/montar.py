# -*- coding: utf-8 -*-
"""Monta c6.py a partir dos fragmentos em c6p/."""
import os
B = os.path.dirname(os.path.abspath(__file__))
fs = ['00_head.py', '01_projetos.py', '02_capacidades_agentes.py', '03_tecnologia_jornadas.py', '99_tail.py']
s = ''.join(open(os.path.join(B, f), encoding='utf-8').read() for f in fs)
open(os.path.join(B, '..', 'c6.py'), 'w', encoding='utf-8').write(s)
print('c6.py', len(s))
