# -*- coding: utf-8 -*-
"""Gera os tipos TypeScript do esquema org a partir de 001_esquema.sql, no formato que o cliente do Supabase usa
(Database['org']['Tables'][...]['Row' | 'Insert' | 'Update']). Uso: python3 supabase/gerar_tipos.py"""
import os, re

BASE = os.path.dirname(os.path.abspath(__file__))
ddl = open(os.path.join(BASE, '001_esquema.sql'), encoding='utf-8').read()

enums = {m.group(1): re.findall(r"'([^']+)'", m.group(2)) for m in re.finditer(r"create type org\.(\w+) as enum \(([^)]*)\)", ddl)}
TS = {'text': 'string', 'uuid': 'string', 'date': 'string', 'timestamptz': 'string', 'jsonb': 'Json', 'boolean': 'boolean',
      'smallint': 'number', 'bigint': 'number', 'integer': 'number', 'numeric': 'number', 'text[]': 'string[]'}


def ts(tipo):
    tipo = tipo.strip()
    if tipo.startswith('org.'):
        return f"Database['org']['Enums']['{tipo[4:]}']"
    return TS[tipo]


tabelas = {}
for m in re.finditer(r"create table org\.(\w+) \((.*?)\n\);", ddl, re.S):
    cols = []
    for linha in m.group(2).split('\n'):
        linha = linha.strip().rstrip(',')
        if not linha or linha.startswith(('primary key', 'unique', 'check')):
            continue
        mm = re.match(r"(\w+) (org\.\w+|text\[\]|timestamptz|smallint|bigint|integer|numeric|boolean|uuid|date|jsonb|text)(.*)", linha)
        if not mm:
            continue
        nome, tipo, resto = mm.groups()
        opcional_insert = ('generated' in resto) or ('default' in resto) or ('not null' not in resto and 'primary key' not in resto)
        nulo = 'not null' not in resto and 'primary key' not in resto
        cols.append((nome, ts(tipo), nulo, opcional_insert))
    tabelas[m.group(1)] = cols

VIEWS = {
    'v_etapa': [('id', 'number'), ('circulo', 'number'), ('circulo_nome', 'string'), ('jornada', 'string'), ('numero', 'number'), ('nome', 'string'),
                ('dono', 'string'), ('modo', "Database['org']['Enums']['modo']"), ('risco', "Database['org']['Enums']['risco']"), ('classe_real', 'string'),
                ('tarefas', 'number'), ('tarefas_maquina', 'number'), ('tarefas_pessoa', 'number'), ('tarefas_outro_circulo', 'number')],
    'v_jornada': [('codigo', 'string'), ('circulo', 'number'), ('circulo_nome', 'string'), ('nome', 'string'), ('dominio', 'string'), ('classe', 'string'),
                  ('onda', 'number'), ('automacao_nivel', 'string'), ('etapas', 'number'), ('tarefas', 'number'), ('pct_maquina', 'number')],
}

o = ['// Gerado por supabase/gerar_tipos.py a partir de 001_esquema.sql. Não editar à mão.',
     'export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]', '',
     'export type Database = {', '  org: {', '    Tables: {']
for t, cols in tabelas.items():
    o.append(f'      {t}: {{')
    o.append('        Row: {')
    o += [f"          {n}: {tp}{' | null' if nu else ''}" for n, tp, nu, _ in cols]
    o.append('        }')
    o.append('        Insert: {')
    o += [f"          {n}{'?' if op else ''}: {tp}{' | null' if nu else ''}" for n, tp, nu, op in cols]
    o.append('        }')
    o.append('        Update: {')
    o += [f"          {n}?: {tp}{' | null' if nu else ''}" for n, tp, nu, _ in cols]
    o.append('        }')
    o.append('        Relationships: []')
    o.append('      }')
o.append('    }')
o.append('    Views: {')
for v, cols in VIEWS.items():
    o.append(f'      {v}: {{')
    o.append('        Row: {')
    o += [f'          {n}: {tp} | null' for n, tp in cols]
    o.append('        }')
    o.append('        Relationships: []')
    o.append('      }')
o.append('    }')
o.append('    Functions: { [_ in never]: never }')
o.append('    Enums: {')
o += [f"      {k}: {' | '.join(repr(x).replace(chr(39), chr(34)) for x in v)}" for k, v in enums.items()]
o.append('    }')
o.append('    CompositeTypes: { [_ in never]: never }')
o.append('  }')
o.append('}')
o.append('')
o.append("export type Tabela<T extends keyof Database['org']['Tables']> = Database['org']['Tables'][T]['Row']")
o.append("export type Visao<V extends keyof Database['org']['Views']> = Database['org']['Views'][V]['Row']")
open(os.path.join(BASE, 'tipos.ts'), 'w', encoding='utf-8').write('\n'.join(o) + '\n')
print('tabelas', len(tabelas), 'colunas', sum(len(c) for c in tabelas.values()), 'enums', len(enums))
