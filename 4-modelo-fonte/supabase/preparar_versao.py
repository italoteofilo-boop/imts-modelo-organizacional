# -*- coding: utf-8 -*-
"""Prepara a carga de uma versão nova do modelo no esquema org_novo, para a migração versionada (012_sincronizar_modelo.sql).
Lê 001_esquema.sql e 002_carga.sql; escreve 012a_org_novo.sql: o esquema e a carga em org_novo, com os mesmos tipos do org.
Uso: python3 supabase/preparar_versao.py"""
import os, re
B = os.path.dirname(os.path.abspath(__file__))
TIPOS = ('modo', 'risco', 'executor', 'tipo_parametro', 'situacao_gate')
esq = open(os.path.join(B, '001_esquema.sql'), encoding='utf-8').read()
car = open(os.path.join(B, '002_carga.sql'), encoding='utf-8').read()
# só as tabelas: sem tipos, visões, políticas e permissões
blocos = [s for s in re.split(r';\s*\n', esq) if re.match(r'\s*(--[^\n]*\n\s*)*create (table|index)', s)]
esq = ';\n'.join(blocos) + ';\n'
def troca(s):
    s = re.sub(r'\borg\.', 'org_novo.', s)
    for t in TIPOS:
        s = s.replace(f'org_novo.{t} ', f'org.{t} ').replace(f'org_novo.{t},', f'org.{t},').replace(f'org_novo.{t})', f'org.{t})').replace(f'org_novo.{t}\n', f'org.{t}\n').replace(f'org_novo.{t};', f'org.{t};')
    return s
car = re.sub(r'^(begin|commit);\s*$', '', car, flags=re.M)
out = 'drop schema if exists org_novo cascade;\ncreate schema org_novo;\n' + troca(esq) + troca(car)
open(os.path.join(B, '012a_org_novo.sql'), 'w', encoding='utf-8').write(out)
print('012a_org_novo.sql', round(len(out.encode()) / 1024), 'KB')
