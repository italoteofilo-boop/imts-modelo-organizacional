-- Modelo organizacional do Ecossistema IMTS: esquema "org".
-- Desenho fechado em 03/10/2026. Tabelas de implantação (empresa, pessoa, atribuição) nascem vazias: gates G1 e G2.
create schema if not exists org;

create type org.modo as enum ('Assistido','Copiloto','Autopiloto','Autômato');
create type org.risco as enum ('baixo','médio','alto');
create type org.executor as enum ('P','A','R','H','C','X');
create type org.tipo_parametro as enum ('alçada','cadência','conteúdo','fonte');
create type org.situacao_gate as enum ('aberto','em andamento','cumprido');

create table org.executor_tipo (
  codigo org.executor primary key,
  nome text not null,
  e_pessoa boolean not null,
  e_maquina boolean not null
);

create table org.circulo (
  numero smallint primary key,
  nome text not null unique,
  sigla text not null unique,
  prefixo text not null unique,
  descricao text not null,
  principio text,
  situacao text not null
);

create table org.dominio (
  id bigint generated always as identity primary key,
  circulo smallint not null references org.circulo(numero),
  nome text not null,
  descricao text,
  unique (circulo, nome)
);

create table org.jornada (
  codigo text primary key,
  circulo smallint not null references org.circulo(numero),
  nome text not null,
  dominio text not null,
  classe text not null check (classe in ('essencial','recomendada')),
  onda smallint not null,
  objetivo text not null,
  frequencia text not null,
  automacao_nivel text not null,
  automacao_motivo text not null,
  raias text[] not null
);

create table org.evento (
  id bigint generated always as identity primary key,
  jornada text not null references org.jornada(codigo) on delete cascade,
  tipo text not null check (tipo in ('início','fim')),
  nome text not null,
  raia text,
  gatilho text
);

create table org.etapa (
  id bigint generated always as identity primary key,
  jornada text not null references org.jornada(codigo) on delete cascade,
  numero smallint not null,
  nome text not null,
  dono text not null,
  modo org.modo not null,
  risco org.risco not null,
  classe_real text not null,
  unique (jornada, numero)
);

create table org.tarefa (
  id bigint generated always as identity primary key,
  etapa bigint not null references org.etapa(id) on delete cascade,
  ordem smallint not null,
  nome text not null,
  executor org.executor not null references org.executor_tipo(codigo),
  raia text not null,
  tipo_bpmn text,
  condicao text,
  unique (etapa, ordem)
);

create table org.decisao_caminho (
  id bigint generated always as identity primary key,
  etapa bigint not null references org.etapa(id) on delete cascade,
  ordem smallint not null,
  pergunta text not null,
  quem text not null,
  saidas jsonb not null
);

create table org.entrada (
  id bigint generated always as identity primary key,
  etapa bigint not null references org.etapa(id) on delete cascade,
  produto text not null,
  origem text not null
);

create table org.saida (
  id bigint generated always as identity primary key,
  etapa bigint not null references org.etapa(id) on delete cascade,
  produto text not null,
  destinos text[] not null
);

create table org.troca (
  id bigint generated always as identity primary key,
  produto text not null,
  de_circulo text not null references org.circulo(nome),
  para_circulo text not null references org.circulo(nome),
  via text,
  sai_em text[] not null,
  entra_em text[] not null
);

create table org.cadeia (
  codigo text primary key,
  nome text not null,
  dono text,
  nota text,
  circulos text[] not null,
  jornadas text[] not null
);

create table org.cadeia_elo (
  id bigint generated always as identity primary key,
  cadeia text not null references org.cadeia(codigo) on delete cascade,
  ordem smallint not null,
  de_jornada text not null references org.jornada(codigo),
  para_jornada text not null references org.jornada(codigo),
  produtos text[] not null
);

create table org.fonte (
  chave text primary key,
  referencia text not null,
  conferencia text not null,
  links jsonb not null
);

create table org.fonte_uso (
  circulo smallint not null references org.circulo(numero),
  fonte text not null references org.fonte(chave),
  uso text not null,
  primary key (circulo, fonte)
);

create table org.jornada_fonte (
  jornada text not null references org.jornada(codigo) on delete cascade,
  fonte text not null references org.fonte(chave),
  primary key (jornada, fonte)
);

create table org.decisao_registrada (
  id bigint generated always as identity primary key,
  circulo smallint not null references org.circulo(numero),
  ordem smallint not null,
  decisao text not null,
  origem text not null,
  efeito text not null
);

create table org.limite (
  id bigint generated always as identity primary key,
  circulo smallint not null references org.circulo(numero),
  ordem smallint not null,
  texto text not null
);

create table org.parametro (
  id bigint generated always as identity primary key,
  tipo org.tipo_parametro not null,
  nome text not null,
  onde text,
  quem_propoe text,
  quem_decide text,
  valor text,
  unique (tipo, nome)
);

create table org.gate (
  codigo text primary key,
  nome text not null,
  entra text not null,
  quem_fornece text not null,
  criterio_saida text not null,
  desbloqueia text not null,
  situacao org.situacao_gate not null default 'aberto'
);

create table org.achado_auditoria (
  id bigint generated always as identity primary key,
  gravidade text not null,
  tipo text not null,
  onde text not null,
  detalhe text not null
);

-- Implantação: nascem vazias (gates G1 e G2)
create table org.empresa (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  regime_tributario text,
  porte text,
  agente_pequeno_porte boolean,
  criado_em timestamptz not null default now()
);

create table org.pessoa (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  email text unique,
  criado_em timestamptz not null default now()
);

create table org.atribuicao (
  id uuid primary key default gen_random_uuid(),
  pessoa uuid not null references org.pessoa(id) on delete cascade,
  papel text not null check (papel in ('sócio','executivo','líder de círculo','pessoa do círculo','encarregado de dados','assessoria')),
  circulo smallint references org.circulo(numero),
  empresa uuid references org.empresa(id),
  inicio date not null default current_date,
  fim date
);

create index on org.jornada (circulo);
create index on org.etapa (jornada);
create index on org.tarefa (etapa);
create index on org.tarefa (executor);
create index on org.decisao_caminho (etapa);
create index on org.entrada (etapa);
create index on org.saida (etapa);
create index on org.evento (jornada);
create index on org.cadeia_elo (cadeia);
create index on org.cadeia_elo (de_jornada);
create index on org.cadeia_elo (para_jornada);
create index on org.jornada_fonte (fonte);
create index on org.fonte_uso (fonte);
create index on org.decisao_registrada (circulo);
create index on org.limite (circulo);
create index on org.atribuicao (pessoa);
create index on org.atribuicao (circulo);
create index on org.atribuicao (empresa);

-- Visões de leitura
create view org.v_etapa as
select e.id, j.circulo, c.nome as circulo_nome, e.jornada, e.numero, e.nome, e.dono, e.modo, e.risco, e.classe_real,
       count(t.id) as tarefas,
       count(t.id) filter (where t.executor in ('A','R')) as tarefas_maquina,
       count(t.id) filter (where t.executor in ('P','H','X')) as tarefas_pessoa,
       count(t.id) filter (where t.executor = 'C') as tarefas_outro_circulo
from org.etapa e join org.jornada j on j.codigo = e.jornada join org.circulo c on c.numero = j.circulo
left join org.tarefa t on t.etapa = e.id
group by e.id, j.circulo, c.nome;

create view org.v_jornada as
select j.codigo, j.circulo, c.nome as circulo_nome, j.nome, j.dominio, j.classe, j.onda, j.automacao_nivel,
       count(distinct e.id) as etapas, count(t.id) as tarefas,
       round(100.0 * count(t.id) filter (where t.executor in ('A','R')) / nullif(count(t.id), 0)) as pct_maquina
from org.jornada j join org.circulo c on c.numero = j.circulo
left join org.etapa e on e.jornada = j.codigo left join org.tarefa t on t.etapa = e.id
group by j.codigo, c.nome;

-- Segurança: leitura para usuário autenticado; escrita só pelo papel de serviço
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'org' loop
    execute format('alter table org.%I enable row level security', t);
    execute format('create policy leitura_autenticada on org.%I for select to authenticated using (true)', t);
  end loop;
end $$;
alter view org.v_etapa set (security_invoker = true);
alter view org.v_jornada set (security_invoker = true);
grant usage on schema org to authenticated, service_role;
grant select on all tables in schema org to authenticated;
grant all on all tables in schema org to service_role;
