-- Runtime dos runtimes (E0) e registro de eventos (E1) — fase 2, protótipo.
-- Decisões de 03/10/2026, 18:34: motores próprios sobre o Supabase, piloto Identidade,
-- Telegram com consentimento do art. 33, VIII, da LGPD para uso real.
-- Lê o modelo do esquema org (001/002). Não altera o org.
-- Esquema rt: plano de controle dos nove motores. Esquema rt_chave: identidade real, separada (LGPD, art. 13, § 4º).

begin;

create schema if not exists rt;
create schema if not exists rt_chave;

-- 1. Versões do modelo-base: cada correção comum vira uma versão publicada aos nove motores
create table rt.versao_base (
  versao       text primary key,
  descricao    text not null,
  commit_ref   text,
  publicada_em timestamptz not null default now()
);

-- 2. Os nove motores, um por círculo
create table rt.motor (
  circulo      smallint primary key references org.circulo(numero),
  nome         text not null unique,
  versao_base  text references rt.versao_base(versao),
  estado       text not null default 'desenho' check (estado in ('desenho', 'piloto', 'ativo', 'pausado')),
  criado_em    timestamptz not null default now()
);

-- 3. Configuração de cada motor: é aqui que cada círculo se customiza
create table rt.config (
  motor         smallint not null references rt.motor(circulo),
  chave         text not null,
  valor         jsonb not null,
  origem        text not null,
  atualizado_em timestamptz not null default now(),
  primary key (motor, chave)
);

-- 4. Propagação: cada versão nova chega a cada motor e só é aplicada com os testes do círculo verdes
create table rt.atualizacao (
  id           bigint generated always as identity primary key,
  motor        smallint not null references rt.motor(circulo),
  versao       text not null references rt.versao_base(versao),
  estado       text not null default 'pendente' check (estado in ('pendente', 'aplicada', 'recusada')),
  detalhe      text,
  criado_em    timestamptz not null default now(),
  concluido_em timestamptz,
  unique (motor, versao)
);

-- 5. Pessoas: o motor só vê o pseudônimo; a identidade fica em rt_chave
create table rt_chave.identidade (
  pseudonimo              uuid primary key default gen_random_uuid(),
  nome                    text not null,
  telegram_id             bigint unique,
  simulado                boolean not null,
  consentimento_art33_em  timestamptz,
  criado_em               timestamptz not null default now(),
  -- uso real do Telegram exige o consentimento do art. 33, VIII (decisão de 03/10/2026)
  constraint real_no_telegram_tem_consentimento
    check (simulado or telegram_id is null or consentimento_art33_em is not null)
);

create table rt.pessoa (
  pseudonimo uuid primary key references rt_chave.identidade(pseudonimo),
  papel      text not null,
  circulo    smallint references org.circulo(numero),
  simulado   boolean not null
);

-- 6. Registro de eventos (E1): base do painel e do ML
create table rt.evento (
  id          bigint generated always as identity primary key,
  motor       smallint not null references rt.motor(circulo),
  jornada     text not null references org.jornada(codigo),
  etapa       bigint references org.etapa(id),
  tarefa      bigint references org.tarefa(id),
  pessoa      uuid references rt.pessoa(pseudonimo),
  executor    org.executor,
  modo        org.modo,
  tipo        text not null check (tipo in ('inicio', 'fim', 'decisao', 'troca_enviada', 'troca_recebida', 'escalada', 'erro')),
  resultado   text,
  inicio      timestamptz,
  fim         timestamptz,
  simulado    boolean not null,
  versao_base text references rt.versao_base(versao),
  criado_em   timestamptz not null default now(),
  check (fim is null or inicio is null or fim >= inicio)
);
create index evento_motor_jornada on rt.evento (motor, jornada, criado_em);

-- 7. Trocas entre círculos: o runtime dos runtimes entrega a saída de um motor ao motor que a recebe
create table rt.troca_envio (
  id          bigint generated always as identity primary key,
  troca       bigint not null references org.troca(id),
  de_motor    smallint not null references rt.motor(circulo),
  para_motor  smallint not null references rt.motor(circulo),
  payload     jsonb not null default '{}'::jsonb,
  estado      text not null default 'enviada' check (estado in ('enviada', 'recebida', 'recusada')),
  simulado    boolean not null,
  enviado_em  timestamptz not null default now(),
  recebido_em timestamptz
);

-- 8. Porta única do Telegram: toda mensagem é gravada aqui antes de qualquer outra coisa
create table rt.rota_chat (
  chat_ref  text primary key,
  motor     smallint not null references rt.motor(circulo),
  descricao text
);

create table rt.mensagem (
  id           bigint generated always as identity primary key,
  canal        text not null default 'telegram' check (canal in ('telegram', 'web')),
  chat_ref     text not null,
  mensagem_ref text,
  direcao      text not null check (direcao in ('entrada', 'saida')),
  pessoa       uuid references rt.pessoa(pseudonimo),
  motor        smallint references rt.motor(circulo),
  conteudo     text not null,
  recebida_em  timestamptz not null default now(),
  apagar_ate   timestamptz not null,
  apagada_em   timestamptz,
  simulado     boolean not null,
  -- o bot só apaga mensagem com menos de 48 horas (Bot API, deleteMessage); folga de 1 hora
  constraint autodestruicao_dentro_de_47h check (apagar_ate <= recebida_em + interval '47 hours')
);

-- Funções do plano de controle --------------------------------------------------------

-- Publica uma versão do modelo-base e abre uma atualização pendente em cada motor
create function rt.publicar_versao(p_versao text, p_descricao text, p_commit text default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  insert into rt.versao_base (versao, descricao, commit_ref) values (p_versao, p_descricao, p_commit);
  insert into rt.atualizacao (motor, versao) select circulo, p_versao from rt.motor;
  get diagnostics n = row_count;
  return n;
end $$;

-- Conclui a atualização de um motor: aplica só com os testes do círculo verdes
create function rt.concluir_atualizacao(p_motor smallint, p_versao text, p_testes_ok boolean, p_detalhe text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare v_estado text;
begin
  select estado into v_estado from rt.atualizacao where motor = p_motor and versao = p_versao for update;
  if v_estado is null then raise exception 'atualização inexistente: motor %, versão %', p_motor, p_versao; end if;
  if v_estado <> 'pendente' then raise exception 'atualização já concluída: %', v_estado; end if;
  if p_testes_ok then
    update rt.atualizacao set estado = 'aplicada', detalhe = p_detalhe, concluido_em = now() where motor = p_motor and versao = p_versao;
    update rt.motor set versao_base = p_versao where circulo = p_motor;
    return 'aplicada';
  end if;
  update rt.atualizacao set estado = 'recusada', detalhe = p_detalhe, concluido_em = now() where motor = p_motor and versao = p_versao;
  return 'recusada';
end $$;

-- Entrega uma troca do modelo: acha os dois motores pelo org.troca e registra o envio e o evento
create function rt.enviar_troca(p_troca bigint, p_jornada text, p_payload jsonb, p_simulado boolean)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_de smallint; v_para smallint; v_id bigint;
begin
  select cd.numero, cp.numero into v_de, v_para
    from org.troca t join org.circulo cd on cd.nome = t.de_circulo join org.circulo cp on cp.nome = t.para_circulo
   where t.id = p_troca;
  if v_de is null then raise exception 'troca inexistente: %', p_troca; end if;
  if not exists (select 1 from org.jornada where codigo = p_jornada and circulo = v_de) then
    raise exception 'a jornada % não é do círculo que envia a troca %', p_jornada, p_troca;
  end if;
  insert into rt.troca_envio (troca, de_motor, para_motor, payload, simulado)
       values (p_troca, v_de, v_para, coalesce(p_payload, '{}'::jsonb), p_simulado) returning id into v_id;
  insert into rt.evento (motor, jornada, tipo, resultado, simulado, versao_base)
       select v_de, p_jornada, 'troca_enviada', 'troca ' || p_troca || ' para o motor ' || v_para, p_simulado, m.versao_base
         from rt.motor m where m.circulo = v_de;
  return v_id;
end $$;

-- Recebe uma mensagem pela porta única: grava, roteia ao motor do chat e marca a autodestruição
create function rt.receber_mensagem(p_chat_ref text, p_mensagem_ref text, p_pessoa uuid, p_conteudo text,
                                    p_simulado boolean, p_horas_autodestruicao integer default 24)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_motor smallint; v_id bigint;
begin
  select motor into v_motor from rt.rota_chat where chat_ref = p_chat_ref;
  if v_motor is null then raise exception 'chat sem motor: %', p_chat_ref; end if;
  insert into rt.mensagem (chat_ref, mensagem_ref, direcao, pessoa, motor, conteudo, apagar_ate, simulado)
       values (p_chat_ref, p_mensagem_ref, 'entrada', p_pessoa, v_motor, p_conteudo,
               now() + make_interval(hours => p_horas_autodestruicao), p_simulado)
    returning id into v_id;
  return v_id;
end $$;

-- Fila de autodestruição: o trabalhador chama deleteMessage para cada linha e marca apagada_em
create view rt.v_a_apagar with (security_invoker = true) as
  select id, canal, chat_ref, mensagem_ref, apagar_ate from rt.mensagem
   where apagada_em is null and apagar_ate <= now();

-- Painel do plano de controle
create view rt.v_motor with (security_invoker = true) as
  select m.circulo, m.nome, m.estado, m.versao_base,
         (select count(*) from rt.atualizacao a where a.motor = m.circulo and a.estado = 'pendente') as atualizacoes_pendentes,
         (select count(*) from org.jornada j where j.circulo = m.circulo) as jornadas,
         (select count(*) from org.troca t join org.circulo c on c.nome = t.de_circulo where c.numero = m.circulo) as trocas_que_envia,
         (select count(*) from org.troca t join org.circulo c on c.nome = t.para_circulo where c.numero = m.circulo) as trocas_que_recebe,
         (select count(*) from rt.evento e where e.motor = m.circulo) as eventos
    from rt.motor m;

create view rt.v_rota_troca with (security_invoker = true) as
  select cd.numero as de_motor, cp.numero as para_motor, count(*) as trocas
    from org.troca t join org.circulo cd on cd.nome = t.de_circulo join org.circulo cp on cp.nome = t.para_circulo
   group by 1, 2;

-- Carga inicial -------------------------------------------------------------------------
insert into rt.versao_base (versao, descricao, commit_ref)
     values ('2026-10-03', 'Modelo fechado: 9 círculos, 73 jornadas, 1.555 tarefas, 410 trocas', '725a5f6');

insert into rt.motor (circulo, nome, versao_base, estado)
     select numero, 'motor-' || lower(prefixo), '2026-10-03', case when numero = 1 then 'piloto' else 'desenho' end
       from org.circulo;

insert into rt.config (motor, chave, valor, origem)
     select c.numero, 'jornadas', coalesce(jsonb_agg(j.codigo order by j.codigo) filter (where j.codigo is not null), '[]'::jsonb), 'org.jornada'
       from org.circulo c left join org.jornada j on j.circulo = c.numero group by c.numero;
insert into rt.config (motor, chave, valor, origem)
     select c.numero, 'raias', coalesce((select jsonb_agg(distinct r order by r) from org.jornada j, unnest(j.raias) r where j.circulo = c.numero), '[]'::jsonb), 'org.jornada.raias'
       from org.circulo c;
insert into rt.config (motor, chave, valor, origem)
     select c.numero, 'limites', coalesce((select jsonb_agg(l.texto order by l.ordem) from org.limite l where l.circulo = c.numero), '[]'::jsonb), 'org.limite'
       from org.circulo c;
insert into rt.config (motor, chave, valor, origem)
     select numero, 'telegram', jsonb_build_object('autodestruicao_horas', 24, 'canal_padrao', true,
            'fora_do_telegram', jsonb_build_array('senhas e chaves', 'relatos da GO-09', 'confirmação de pagamento')), 'decisão de 03/10/2026'
       from org.circulo;

-- Segurança: nada exposto a anon; leitura do rt para autenticados; rt_chave só service_role ---------
do $$ declare t text; begin
  for t in select tablename from pg_tables where schemaname = 'rt' loop
    execute format('alter table rt.%I enable row level security', t);
    execute format('create policy leitura_autenticada on rt.%I for select to authenticated using (true)', t);
  end loop;
  for t in select tablename from pg_tables where schemaname = 'rt_chave' loop
    execute format('alter table rt_chave.%I enable row level security', t);
  end loop;
end $$;
grant usage on schema rt to authenticated, service_role;
grant select on all tables in schema rt to authenticated;
grant all on all tables in schema rt to service_role;
grant usage on schema rt_chave to service_role;
grant all on all tables in schema rt_chave to service_role;
revoke all on all functions in schema rt from public;
grant execute on all functions in schema rt to service_role;

commit;
