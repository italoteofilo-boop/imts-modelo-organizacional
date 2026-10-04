# -*- coding: utf-8 -*-
"""Tira o retrato da Mesa da Identidade de uma base com o esquema rt (010 em diante) e grava mesa/retrato_mesa.json.
Uso: python3 mesa/exportar_retrato.py "psql -h 127.0.0.1 -p 5499 -U postgres" """
import json, os, subprocess, sys
psql = sys.argv[1].split() if len(sys.argv) > 1 else ['psql', '-h', '127.0.0.1', '-p', '5499', '-U', 'postgres']
q = lambda s: json.loads(subprocess.run(psql + ['-X', '-Atc', s], capture_output=True, text=True, check=True).stdout)
pessoas = [p for p in q('select rt.mesa_pessoas()') if p['circulo'] in (1, None)]
r = dict(gerado_em=q("select to_jsonb(now())"), pessoas=pessoas,
         quadros={p['id']: q(f"select rt.quadro('{p['id']}'::uuid)") for p in pessoas},
         circulo=q('select rt.quadro_circulo(1::smallint)'),
         jornadas=q("select jsonb_agg(jsonb_build_object('c', j.codigo, 'n', j.nome, 'k', j.circulo, 'ativo', m.estado <> 'desenho') order by j.codigo) from org.jornada j join rt.motor m on m.circulo = j.circulo"),
         tarefas=q("select jsonb_agg(jsonb_build_array(e.jornada, t.nome) order by e.jornada, e.numero, t.ordem) from org.tarefa t join org.etapa e on e.id = t.etapa"))
saida = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'retrato_mesa.json')
json.dump(r, open(saida, 'w', encoding='utf-8'), ensure_ascii=False)
print('retrato_mesa.json', len(pessoas), 'pessoas', sum(len(v) for v in r['quadros'].values()), 'cartões', len(r['jornadas']), 'jornadas', len(r['tarefas']), 'tarefas')
