-- Gerado por ml/treinar.py. Registro dos modelos treinados.
begin;
create table if not exists rt.modelo (nome text not null, versao text not null, tipo text not null, dado text not null check (dado in ('simulado', 'real', 'misto')),
  amostras integer not null, metricas jsonb not null, artefato text not null, sha256 text not null, biblioteca text not null,
  treinado_em timestamptz not null default now(), em_uso boolean not null default false, primary key (nome, versao));
alter table rt.modelo enable row level security;
do $$ begin if not exists (select 1 from pg_policies where schemaname = 'rt' and tablename = 'modelo') then
  create policy leitura_autenticada on rt.modelo for select to authenticated using (true); end if; end $$;
grant select on rt.modelo to authenticated; grant all on rt.modelo to service_role;
insert into rt.modelo (nome, versao, tipo, dado, amostras, metricas, artefato, sha256, biblioteca) values ('risco-atraso-etapa', '2026-10-03.1', 'classificação', 'simulado', 7797, '{"amostras_treino": 5856, "amostras_teste": 1941, "taxa_atraso": 0.2506, "auc_teste": 0.4473, "brier_teste": 0.2006, "brier_base_taxa_media": 0.1991}'::jsonb, '4-modelo-fonte/ml/modelos/risco-atraso-etapa-2026-10-03.1.joblib', 'be47461bbf14ed5aea7f3b191591b89120f8d051e4327c2a87d722c7a45b0577', 'scikit-learn 1.8.0') on conflict (nome, versao) do update set metricas = excluded.metricas, sha256 = excluded.sha256, amostras = excluded.amostras;
insert into rt.modelo (nome, versao, tipo, dado, amostras, metricas, artefato, sha256, biblioteca) values ('anomalia-instancia', '2026-10-03.1', 'detecção de anomalia', 'simulado', 2000, '{"instancias": 2000, "marcadas_anomalas": 40, "contaminacao_assumida": 0.02}'::jsonb, '4-modelo-fonte/ml/modelos/anomalia-instancia-2026-10-03.1.joblib', '1a07c0098643cc2b9a21e39870605e5cc90dfb1a037971301a1151ca9f876b73', 'scikit-learn 1.8.0') on conflict (nome, versao) do update set metricas = excluded.metricas, sha256 = excluded.sha256, amostras = excluded.amostras;
commit;
