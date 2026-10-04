-- Modelos de ML, versão 2026-10-03.2: retreinados com as execuções simuladas dos nove motores (E10). Mesma regra: dado simulado, fora de uso.
-- Gerado por ml/treinar.py. Registro dos modelos treinados.
begin;
create table if not exists rt.modelo (nome text not null, versao text not null, tipo text not null, dado text not null check (dado in ('simulado', 'real', 'misto')),
  amostras integer not null, metricas jsonb not null, artefato text not null, sha256 text not null, biblioteca text not null,
  treinado_em timestamptz not null default now(), em_uso boolean not null default false, primary key (nome, versao));
alter table rt.modelo enable row level security;
do $$ begin if not exists (select 1 from pg_policies where schemaname = 'rt' and tablename = 'modelo') then
  create policy leitura_autenticada on rt.modelo for select to authenticated using (true); end if; end $$;
grant select on rt.modelo to authenticated; grant all on rt.modelo to service_role;
insert into rt.modelo (nome, versao, tipo, dado, amostras, metricas, artefato, sha256, biblioteca) values ('risco-atraso-etapa', '2026-10-03.2', 'classificação', 'simulado', 11034, '{"amostras_treino": 8313, "amostras_teste": 2721, "taxa_atraso": 0.2524, "auc_teste": 0.3901, "brier_teste": 0.19, "brier_base_taxa_media": 0.1876}'::jsonb, '4-modelo-fonte/ml/modelos/risco-atraso-etapa-2026-10-03.2.joblib', 'e51aa2be950161310c9e64f6f53febb257e86bcaa55410ebf53dc02af0c9746d', 'scikit-learn 1.8.0') on conflict (nome, versao) do update set metricas = excluded.metricas, sha256 = excluded.sha256, amostras = excluded.amostras;
insert into rt.modelo (nome, versao, tipo, dado, amostras, metricas, artefato, sha256, biblioteca) values ('anomalia-instancia', '2026-10-03.2', 'detecção de anomalia', 'simulado', 4201, '{"instancias": 4201, "marcadas_anomalas": 84, "contaminacao_assumida": 0.02}'::jsonb, '4-modelo-fonte/ml/modelos/anomalia-instancia-2026-10-03.2.joblib', '87e121b52b3865b8aeeed81b7f767b2404cb015f072826d13c6a010a4985f58f', 'scikit-learn 1.8.0') on conflict (nome, versao) do update set metricas = excluded.metricas, sha256 = excluded.sha256, amostras = excluded.amostras;
commit;
