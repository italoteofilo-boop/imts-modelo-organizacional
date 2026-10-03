# -*- coding: utf-8 -*-
"""Monta c2.py a partir dos fragmentos em c2p/ (cabeçalho, seis jornadas, cauda e fechamento)."""
import os
B = os.path.dirname(os.path.abspath(__file__))
rd = lambda f: open(os.path.join(B, f), encoding='utf-8').read()
tail = rd('99_tail_base.py')
j = tail.index('# ------------------------------------------------------- decisões de fechamento')
s = rd('00_head.py') + ''.join(rd(f) for f in ('01_es01.py', '02_es02.py', '03_es03.py', '04_es04.py', '05_es05.py', '06_es06.py')) + tail[:j] + rd('99b_fecho.py')
open(os.path.join(B, '..', 'c2.py'), 'w', encoding='utf-8').write(s)
print('c2.py', len(s))
