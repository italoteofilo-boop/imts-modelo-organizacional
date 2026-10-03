# -*- coding: utf-8 -*-
"""Lê os 73 fluxos BPMN (saida/cN/bpmn/*.bpmn) e escreve supabase/004_grafos.sql: o grafo executável de cada jornada
(nós e fluxos) que os motores percorrem. Cada tarefa do BPMN aponta para a tarefa do esquema org pelo código
<jornada>_E<etapa>_T<ordem>. Uso: python3 supabase/gerar_grafos.py"""
import glob, os, re, xml.etree.ElementTree as ET

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, 'supabase', '004_grafos.sql')
NS = {'b': 'http://www.omg.org/spec/BPMN/20100524/MODEL'}
TAREFAS = {'task', 'userTask', 'scriptTask', 'serviceTask', 'manualTask', 'callActivity', 'receiveTask', 'businessRuleTask', 'sendTask'}
TIPOS = TAREFAS | {'startEvent', 'endEvent', 'exclusiveGateway', 'parallelGateway', 'intermediateCatchEvent', 'intermediateThrowEvent'}


def q(s):
    return 'null' if s is None else "'" + s.replace("'", "''") + "'"


def main():
    nos, fluxos = [], []
    arquivos = sorted(glob.glob(os.path.join(BASE, 'saida', 'c[1-9]', 'bpmn', '*.bpmn')))
    for arq in arquivos:
        jornada = os.path.basename(arq)[:-5]
        raiz = ET.parse(arq).getroot()
        proc = raiz.find('b:process', NS)
        raia_de = {}
        for lane in proc.iter('{%s}lane' % NS['b']):
            for ref in lane.findall('b:flowNodeRef', NS):
                raia_de[ref.text] = lane.get('name')
        for el in proc:
            tag = el.tag.split('}')[1]
            if tag in TIPOS:
                m = re.search(r'_E(\d+)_T(\d+)$', el.get('id'))
                if tag in TAREFAS and not m:
                    raise SystemExit(f'tarefa sem código de etapa e ordem: {jornada} {el.get("id")}')
                ev = None
                if tag.endswith('Event'):
                    for d in ('messageEventDefinition', 'timerEventDefinition', 'signalEventDefinition'):
                        if el.find('b:' + d, NS) is not None:
                            ev = d.replace('EventDefinition', '')
                diverge = len(el.findall('b:outgoing', NS)) > 1
                nos.append((jornada, el.get('id'), tag, el.get('name'), raia_de.get(el.get('id')),
                            int(m.group(1)) if m else None, int(m.group(2)) if m else None, ev, diverge))
            elif tag == 'sequenceFlow':
                c = el.find('b:conditionExpression', NS)
                fluxos.append((jornada, el.get('id'), el.get('sourceRef'), el.get('targetRef'),
                               el.get('name') or (c.text if c is not None else None)))
    S = ['-- Gerado por supabase/gerar_grafos.py a partir dos 73 fluxos BPMN. Não edite à mão.', 'begin;',
         'create table rt.no (jornada text not null references org.jornada(codigo), id text not null, tipo text not null, nome text, raia text,',
         '  etapa_numero smallint, ordem smallint, evento text, diverge boolean not null, tarefa bigint references org.tarefa(id),',
         '  primary key (jornada, id));',
         'create table rt.fluxo (jornada text not null, id text not null, de text not null, para text not null, rotulo text,',
         '  primary key (jornada, id), foreign key (jornada, de) references rt.no(jornada, id), foreign key (jornada, para) references rt.no(jornada, id));',
         'create index fluxo_de on rt.fluxo (jornada, de);']
    for i in range(0, len(nos), 400):
        S.append('insert into rt.no (jornada, id, tipo, nome, raia, etapa_numero, ordem, evento, diverge) values')
        S.append(',\n'.join(f'({q(j)},{q(i_)},{q(t)},{q(n)},{q(r)},{e if e is not None else "null"},{o if o is not None else "null"},{q(ev)},{str(d).lower()})'
                            for j, i_, t, n, r, e, o, ev, d in nos[i:i + 400]) + ';')
    for i in range(0, len(fluxos), 400):
        S.append('insert into rt.fluxo (jornada, id, de, para, rotulo) values')
        S.append(',\n'.join(f'({q(j)},{q(i_)},{q(d)},{q(p)},{q(r)})' for j, i_, d, p, r in fluxos[i:i + 400]) + ';')
    S.append('update rt.no n set tarefa = t.id from org.tarefa t join org.etapa e on e.id = t.etapa '
             'where e.jornada = n.jornada and e.numero = n.etapa_numero and t.ordem = n.ordem;')
    S.append("do $$ declare k int; begin\n"
             "  select count(*) into k from rt.no where ordem is not null and tarefa is null;\n"
             "  if k > 0 then raise exception 'tarefas do BPMN sem tarefa no modelo: %', k; end if;\n"
             "  select count(*) into k from rt.no n join org.tarefa t on t.id = n.tarefa where n.nome is distinct from t.nome;\n"
             "  if k > 0 then raise exception 'tarefas com nome diferente do modelo: %', k; end if;\n"
             "  select count(*) into k from org.tarefa t where not exists (select 1 from rt.no n where n.tarefa = t.id);\n"
             "  if k > 0 then raise exception 'tarefas do modelo fora do BPMN: %', k; end if;\n"
             "end $$;")
    S.append("do $$ declare t text; begin foreach t in array array['no','fluxo'] loop\n"
             "  execute format('alter table rt.%I enable row level security', t);\n"
             "  execute format('create policy leitura_autenticada on rt.%I for select to authenticated using (true)', t);\n"
             "end loop; end $$;")
    S.append('grant select on rt.no, rt.fluxo to authenticated; grant all on rt.no, rt.fluxo to service_role;')
    S.append('commit;')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(S) + '\n')
    print('arquivos', len(arquivos), 'nós', len(nos), 'tarefas', sum(1 for n in nos if n[6] is not None), 'fluxos', len(fluxos))


if __name__ == '__main__':
    main()
