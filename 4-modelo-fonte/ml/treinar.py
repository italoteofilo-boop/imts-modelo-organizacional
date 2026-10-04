# -*- coding: utf-8 -*-
"""Treina os primeiros modelos de ML do motor com os eventos simulados (rt.evento) e escreve
supabase/006_modelos.sql com o registro de cada modelo (rt.modelo).

Modelos:
  risco-atraso-etapa  classificação: a etapa vai passar do p75 de duração daquela etapa? Atributos conhecidos
                      quando a etapa começa: jornada, etapa, modo, visita (1ª, 2ª...) e quantas tarefas de cada
                      executor a etapa tem no modelo.
  anomalia-instancia  IsolationForest sobre a instância inteira: duração total, passos, tarefas, decisões, voltas.

Treinados só com dado simulado: aprendem as hipóteses do simulador (rt.parametro_simulacao), não a operação real.
Servem para provar o encanamento e evoluir a plataforma; são retreinados quando entrar dado real.
Uso: python3 ml/treinar.py --psql "psql -p 5499 -U postgres" [--saida ml/modelos]"""
import argparse, csv, hashlib, io, json, os, subprocess, sys
import numpy as np, joblib, sklearn
from sklearn.ensemble import GradientBoostingClassifier, IsolationForest
from sklearn.metrics import roc_auc_score, brier_score_loss
from sklearn.model_selection import GroupShuffleSplit

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXEC = ['P', 'A', 'R', 'H', 'C', 'X']
MODOS = ['Assistido', 'Copiloto', 'Autopiloto', 'Autômato']

Q_ETAPAS = """
copy (
  with ev as (
    select e.instancia, e.jornada, e.etapa, e.inicio, e.fim, e.id,
           sum(case when e.etapa is distinct from lag_etapa then 1 else 0 end) over (partition by e.instancia order by e.id) as bloco
      from (select *, lag(etapa) over (partition by instancia order by id) as lag_etapa from rt.evento where tarefa is not null and simulado and tipo = 'fim' and fim is not null) e
  ), blocos as (
    select instancia, jornada, etapa, bloco, min(inicio) as ini, max(fim) as fim from ev group by 1, 2, 3, 4
  ), vis as (
    select b.*, row_number() over (partition by instancia, etapa order by bloco) as visita from blocos b
  )
  select v.instancia, v.jornada, et.numero as etapa, et.modo, v.visita,
         extract(epoch from v.fim - v.ini) / 60 as minutos,
         (select count(*) filter (where t.executor = 'P') from org.tarefa t where t.etapa = v.etapa) as n_p,
         (select count(*) filter (where t.executor = 'A') from org.tarefa t where t.etapa = v.etapa) as n_a,
         (select count(*) filter (where t.executor = 'R') from org.tarefa t where t.etapa = v.etapa) as n_r,
         (select count(*) filter (where t.executor = 'H') from org.tarefa t where t.etapa = v.etapa) as n_h,
         (select count(*) filter (where t.executor = 'C') from org.tarefa t where t.etapa = v.etapa) as n_c,
         (select count(*) filter (where t.executor = 'X') from org.tarefa t where t.etapa = v.etapa) as n_x
    from vis v join org.etapa et on et.id = v.etapa order by v.instancia, v.bloco
) to stdout with csv header
"""

Q_INST = """
copy (
  select i.id, i.jornada, extract(epoch from i.fim - i.inicio) / 60 as minutos, i.passos,
         count(e.*) filter (where e.tarefa is not null) as tarefas,
         count(e.*) filter (where e.tipo = 'decisao') as decisoes,
         (select count(*) from (select tarefa from rt.evento x where x.instancia = i.id and x.tarefa is not null group by 1 having count(*) > 1) r) as voltas
    from rt.instancia i join rt.evento e on e.instancia = i.id
   where i.simulado and i.estado = 'concluida' and not i.interativo group by i.id order by i.id
) to stdout with csv header
"""


def consulta(psql, q):
    r = subprocess.run(psql.split() + ['-X', '-q', '-c', q.replace('\n', ' ')], capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr)
    return list(csv.DictReader(io.StringIO(r.stdout)))


def q(s):
    return "'" + str(s).replace("'", "''") + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--psql', required=True)
    ap.add_argument('--saida', default=os.path.join(BASE, 'ml', 'modelos'))
    ap.add_argument('--versao', default='2026-10-03.1')
    a = ap.parse_args()
    os.makedirs(a.saida, exist_ok=True)
    reg = []

    # 1. risco de atraso por etapa
    linhas = consulta(a.psql, Q_ETAPAS)
    jornadas = sorted({l['jornada'] for l in linhas})
    p75 = {}
    for chave in {(l['jornada'], l['etapa']) for l in linhas}:
        v = [float(l['minutos']) for l in linhas if (l['jornada'], l['etapa']) == chave]
        p75[chave] = float(np.percentile(v, 75))
    X, y, g = [], [], []
    for l in linhas:
        x = [1.0 if l['jornada'] == j else 0.0 for j in jornadas] + [float(l['etapa'])] + \
            [1.0 if l['modo'] == m else 0.0 for m in MODOS] + [float(l['visita'])] + [float(l['n_' + e.lower()]) for e in EXEC]
        X.append(x); y.append(1 if float(l['minutos']) > p75[(l['jornada'], l['etapa'])] else 0); g.append(l['instancia'])
    X, y = np.array(X), np.array(y)
    tr, te = next(GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=7).split(X, y, g))
    m1 = GradientBoostingClassifier(random_state=7).fit(X[tr], y[tr])
    p = m1.predict_proba(X[te])[:, 1]
    base = float(y[tr].mean())
    met1 = {'amostras_treino': int(len(tr)), 'amostras_teste': int(len(te)), 'taxa_atraso': round(float(y.mean()), 4),
            'auc_teste': round(float(roc_auc_score(y[te], p)), 4),
            'brier_teste': round(float(brier_score_loss(y[te], p)), 4),
            'brier_base_taxa_media': round(float(brier_score_loss(y[te], np.full(len(te), base))), 4)}
    f1 = os.path.join(a.saida, f'risco-atraso-etapa-{a.versao}.joblib')
    joblib.dump({'modelo': m1, 'jornadas': jornadas, 'modos': MODOS, 'executores': EXEC, 'p75_minutos': {f'{k[0]} etapa {k[1]}': v for k, v in p75.items()}}, f1, compress=3)
    reg.append(('risco-atraso-etapa', 'classificação', f1, met1, len(linhas)))

    # 2. anomalia de instância
    inst = consulta(a.psql, Q_INST)
    Xi = np.array([[float(l['minutos']), float(l['passos']), float(l['tarefas']), float(l['decisoes']), float(l['voltas'])] for l in inst])
    m2 = IsolationForest(n_estimators=200, contamination=0.02, random_state=7).fit(Xi)
    marcadas = int((m2.predict(Xi) == -1).sum())
    met2 = {'instancias': len(inst), 'marcadas_anomalas': marcadas, 'contaminacao_assumida': 0.02}
    f2 = os.path.join(a.saida, f'anomalia-instancia-{a.versao}.joblib')
    joblib.dump({'modelo': m2, 'atributos': ['minutos', 'passos', 'tarefas', 'decisoes', 'voltas']}, f2, compress=3)
    reg.append(('anomalia-instancia', 'detecção de anomalia', f2, met2, len(inst)))

    # registro
    S = ['-- Gerado por ml/treinar.py. Registro dos modelos treinados.', 'begin;',
         'create table if not exists rt.modelo (nome text not null, versao text not null, tipo text not null, dado text not null check (dado in (\'simulado\', \'real\', \'misto\')),',
         '  amostras integer not null, metricas jsonb not null, artefato text not null, sha256 text not null, biblioteca text not null,',
         '  treinado_em timestamptz not null default now(), em_uso boolean not null default false, primary key (nome, versao));',
         'alter table rt.modelo enable row level security;',
         "do $$ begin if not exists (select 1 from pg_policies where schemaname = 'rt' and tablename = 'modelo') then",
         "  create policy leitura_autenticada on rt.modelo for select to authenticated using (true); end if; end $$;",
         'grant select on rt.modelo to authenticated; grant all on rt.modelo to service_role;']
    for nome, tipo, f, met, n in reg:
        sha = hashlib.sha256(open(f, 'rb').read()).hexdigest()
        S.append(f"insert into rt.modelo (nome, versao, tipo, dado, amostras, metricas, artefato, sha256, biblioteca) values "
                 f"({q(nome)}, {q(a.versao)}, {q(tipo)}, 'simulado', {n}, {q(json.dumps(met, ensure_ascii=False))}::jsonb, "
                 f"{q('4-modelo-fonte/ml/modelos/' + os.path.basename(f))}, {q(sha)}, {q('scikit-learn ' + sklearn.__version__)}) "
                 f"on conflict (nome, versao) do update set metricas = excluded.metricas, sha256 = excluded.sha256, amostras = excluded.amostras;")
        print(nome, n, json.dumps(met, ensure_ascii=False), sha[:12])
    S.append('commit;')
    open(os.path.join(BASE, 'supabase', '006_modelos.sql'), 'w', encoding='utf-8').write('\n'.join(S) + '\n')


if __name__ == '__main__':
    main()
