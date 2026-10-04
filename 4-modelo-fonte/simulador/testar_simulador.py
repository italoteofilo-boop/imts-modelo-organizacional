# -*- coding: utf-8 -*-
"""Testes do simulador (E7). Uso: python3 simulador/testar_simulador.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simular as S

g, nome_j, circ_j = S.carregar()
falhas = []
a = S.rodar('base', S.CENARIOS['base'], g, circ_j, 3, 11, {})
b = S.rodar('base', S.CENARIOS['base'], g, circ_j, 3, 11, {})
if a != b: falhas.append('S1: mesma semente deu resultado diferente')
if len(a['jornadas']) != len(g): falhas.append(f'S2: rodaram {len(a["jornadas"])} de {len(g)} jornadas')
d = S.rodar('dobro', S.CENARIOS['dobro'], g, circ_j, 3, 11, {})
if not all(d['papeis'][p]['ocupacao'] > a['papeis'][p]['ocupacao'] for p in a['papeis']): falhas.append('S3: o dobro do volume não aumentou a ocupação')
cap = {p: 2 for p in d['papeis']}
r = S.rodar('reforco', S.CENARIOS['dobro'], g, circ_j, 3, 11, cap)
if not all(r['papeis'][p]['ocupacao'] < d['papeis'][p]['ocupacao'] for p in d['papeis']): falhas.append('S4: a segunda pessoa não reduziu a ocupação')
if not all(abs(r['papeis'][p]['ocupacao'] * 2 / d['papeis'][p]['ocupacao'] - 1) < 0.1 for p in d['papeis']): falhas.append('S5: o trabalho total mudou mais de 10% com a capacidade')
src = open(S.__file__, encoding='utf-8').read()
if any(x in src for x in ('psycopg', 'supabase', 'postgres(', 'requests.post')): falhas.append('S6: o simulador fala com a base')
print('SIMULADOR:', 6 - len(falhas), 'de 6 testes;', 'falhas: ' + '; '.join(falhas) if falhas else '0 falhas')
sys.exit(1 if falhas else 0)
