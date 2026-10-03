-- Motor dos círculos sobre o Supabase (fase 2, protótipo). Depende de 001 a 004.
-- 1. Sistemas e vínculo de cada uma das 1.555 tarefas (G7). 2. Usuários simulados (E2).
-- 3. Motor: percorre o grafo BPMN de uma jornada, grava instância, tokens e eventos.
-- Tempos simulados vêm de rt.parametro_simulacao: são hipóteses do protótipo, não medidas.
begin;

-- 1. Sistemas e vínculo -----------------------------------------------------------------
create table rt.sistema (
  codigo    text primary key,
  nome      text not null,
  atende    text not null,
  adaptador text not null default 'simulado' check (adaptador in ('simulado', 'real')),
  descricao text not null
);
insert into rt.sistema (codigo, nome, atende, descricao) values
  ('canal-pessoa',   'Canal das pessoas (Telegram e página web)', 'P, H',  'Pede e recebe a ação de uma pessoa do círculo ou de fora dele; Telegram por padrão, web no 1% fora do Telegram'),
  ('agente-ia',      'Agentes de IA do círculo',                   'A',     'Executa a tarefa de agente com o modelo e a DKP do círculo; libera pela IT-06'),
  ('automacao',      'Automações do motor',                        'R',     'Registra, avisa, calcula e integra, sem pessoa'),
  ('troca-circulo',  'Runtime dos runtimes, trocas entre círculos', 'C',    'Leva a tarefa ao motor do outro círculo e espera a volta'),
  ('canal-externo',  'Canal das assessorias',                      'X',     'Pede e recebe a entrega da assessoria externa, com prazo');

create table rt.vinculo (
  tarefa  bigint primary key references org.tarefa(id),
  sistema text not null references rt.sistema(codigo),
  motor   smallint not null references rt.motor(circulo)
);
insert into rt.vinculo (tarefa, sistema, motor)
  select t.id,
         case t.executor when 'P' then 'canal-pessoa' when 'H' then 'canal-pessoa' when 'A' then 'agente-ia'
                         when 'R' then 'automacao' when 'C' then 'troca-circulo' when 'X' then 'canal-externo' end,
         j.circulo
    from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada;

-- 2. Usuários simulados: um por papel de raia; papéis genéricos, um por círculo ----------------
create temporary table papeis_tmp as
  select distinct t.raia from org.tarefa t where t.executor in ('P', 'H', 'X', 'C');

with genericos as (select unnest(array['Líder do círculo', 'Pessoa', 'Líder da equipe', 'Solicitante']) as papel),
alvos as (
  -- papéis genéricos: um por círculo
  select p.raia as papel, c.numero as circulo from papeis_tmp p join genericos g on g.papel = p.raia cross join org.circulo c
  union all
  -- papéis de um círculo: "Identidade · pessoa" ou o próprio nome do círculo
  select p.raia, c.numero from papeis_tmp p join org.circulo c on p.raia = c.nome or p.raia = c.nome || ' · pessoa'
  union all
  -- papéis únicos do Ecossistema: sócios, executivo, Administrador, assessoria, cliente, parceiro
  select p.raia, null::smallint from papeis_tmp p
   where p.raia not in (select papel from genericos)
     and not exists (select 1 from org.circulo c where p.raia = c.nome or p.raia = c.nome || ' · pessoa')
),
ids as (
  insert into rt_chave.identidade (nome, simulado)
  select 'Simulado · ' || a.papel || coalesce(' · ' || c.nome, ''), true
    from alvos a left join org.circulo c on c.numero = a.circulo
  returning pseudonimo, nome
)
insert into rt.pessoa (pseudonimo, papel, circulo, simulado)
  select i.pseudonimo, a.papel, a.circulo, true
    from alvos a left join org.circulo c on c.numero = a.circulo
    join ids i on i.nome = 'Simulado · ' || a.papel || coalesce(' · ' || c.nome, '');
drop table papeis_tmp;

-- 3. Motor ----------------------------------------------------------------------------
create table rt.parametro_simulacao (
  executor    org.executor primary key,
  min_minutos numeric not null check (min_minutos > 0),
  max_minutos numeric not null,
  origem      text not null default 'hipótese do protótipo, a calibrar no G9 com dado real',
  check (max_minutos >= min_minutos)
);
insert into rt.parametro_simulacao (executor, min_minutos, max_minutos) values
  ('A', 2, 20), ('R', 0.1, 2), ('P', 30, 240), ('H', 60, 2880), ('C', 60, 2880), ('X', 1440, 7200);

create table rt.instancia (
  id           bigint generated always as identity primary key,
  motor        smallint not null references rt.motor(circulo),
  jornada      text not null references org.jornada(codigo),
  simulado     boolean not null,
  semente      double precision,
  estado       text not null default 'rodando' check (estado in ('rodando', 'concluida', 'erro')),
  inicio       timestamptz not null,
  fim          timestamptz,
  fim_no       text,
  passos       integer not null default 0,
  versao_base  text references rt.versao_base(versao),
  detalhe      text
);
alter table rt.evento add column instancia bigint references rt.instancia(id);
create index evento_instancia on rt.evento (instancia);

create function rt._minutos(p_exec org.executor) returns numeric language sql volatile set search_path = '' as $$
  -- distribuição log-uniforme entre o mínimo e o máximo do executor
  select exp(ln(min_minutos) + random() * (ln(max_minutos) - ln(min_minutos))) from rt.parametro_simulacao where executor = p_exec
$$;

create function rt._pessoa(p_raia text, p_motor smallint) returns uuid language sql stable set search_path = '' as $$
  select pseudonimo from rt.pessoa where papel = p_raia
   order by (circulo is not distinct from p_motor) desc, circulo nulls first limit 1
$$;

-- Roda uma instância simulada de ponta a ponta. Decisões sorteadas; voltas ficam menos prováveis
-- a cada visita e são cortadas na terceira. Ramos paralelos rodam em sequência no relógio simulado.
create function rt.executar_simulada(p_jornada text, p_semente double precision, p_inicio timestamptz default now(),
                                     p_max_passos integer default 600)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_motor smallint; v_versao text; v_inst bigint; v_t timestamptz := p_inicio;
  v_fila text[]; v_no text; n record; f record; v_min numeric; v_tar record;
  v_visitas jsonb := '{}'::jsonb; v_chegadas jsonb := '{}'::jsonb; v_trocas_feitas text[] := '{}';
  v_passos int := 0; v_entradas int; v_escolha text; v_rotulo text; v_total numeric; v_sorteio numeric; v_acum numeric;
  v_etapa_id bigint; v_modo org.modo; v_tr record; v_chave text;
begin
  select circulo into v_motor from org.jornada where codigo = p_jornada;
  if v_motor is null then raise exception 'jornada inexistente: %', p_jornada; end if;
  select versao_base into v_versao from rt.motor where circulo = v_motor;
  perform setseed(p_semente);
  insert into rt.instancia (motor, jornada, simulado, semente, inicio, versao_base)
       values (v_motor, p_jornada, true, p_semente, p_inicio, v_versao) returning id into v_inst;
  insert into rt.evento (instancia, motor, jornada, tipo, resultado, inicio, simulado, versao_base)
       values (v_inst, v_motor, p_jornada, 'inicio', 'instância simulada', v_t, true, v_versao);

  -- começa num dos eventos de início, sorteado
  select array[id] into v_fila from rt.no where jornada = p_jornada and tipo = 'startEvent' order by random() limit 1;

  while array_length(v_fila, 1) > 0 loop
    v_passos := v_passos + 1;
    if v_passos > p_max_passos then
      update rt.instancia set estado = 'erro', passos = v_passos, fim = v_t, detalhe = 'passou do limite de passos' where id = v_inst;
      return v_inst;
    end if;
    v_no := v_fila[1]; v_fila := v_fila[2:];
    select * into n from rt.no where jornada = p_jornada and id = v_no;
    v_visitas := jsonb_set(v_visitas, array[v_no], to_jsonb(coalesce((v_visitas->>v_no)::int, 0) + 1));

    if n.tarefa is not null then
      select t.*, e.id as etapa_id, e.modo as etapa_modo, e.numero as etapa_numero into v_tar
        from org.tarefa t join org.etapa e on e.id = t.etapa where t.id = n.tarefa;
      v_min := rt._minutos(v_tar.executor);
      insert into rt.evento (instancia, motor, jornada, etapa, tarefa, pessoa, executor, modo, tipo, resultado, inicio, fim, simulado, versao_base)
           values (v_inst, v_motor, p_jornada, v_tar.etapa_id, v_tar.id,
                   case when v_tar.executor in ('A', 'R') then null else rt._pessoa(v_tar.raia, v_motor) end,
                   v_tar.executor, v_tar.etapa_modo, 'fim', 'concluída (simulado)', v_t, v_t + make_interval(secs => v_min * 60), true, v_versao);
      v_t := v_t + make_interval(secs => v_min * 60);
      -- trocas que saem desta etapa: entregues uma vez por instância
      v_chave := p_jornada || ' etapa ' || v_tar.etapa_numero;
      if not v_chave = any (v_trocas_feitas) then
        v_trocas_feitas := v_trocas_feitas || v_chave;
        for v_tr in select id from org.troca where v_chave = any (sai_em) loop
          perform rt.enviar_troca(v_tr.id, p_jornada, jsonb_build_object('instancia', v_inst), true);
        end loop;
      end if;
      v_fila := v_fila || (select array_agg(para order by id) from rt.fluxo where jornada = p_jornada and de = v_no);

    elsif n.tipo = 'exclusiveGateway' and n.diverge then
      -- sorteio ponderado: peso 1/(1+visitas)^2; destino visitado 3 vezes fica fora
      select sum(1.0 / power(1 + coalesce((v_visitas->>para)::int, 0), 2)) into v_total
        from rt.fluxo where jornada = p_jornada and de = v_no and coalesce((v_visitas->>para)::int, 0) < 3;
      if v_total is null then
        update rt.instancia set estado = 'erro', passos = v_passos, fim = v_t, detalhe = 'decisão sem saída possível em ' || v_no where id = v_inst;
        return v_inst;
      end if;
      v_sorteio := random() * v_total; v_acum := 0; v_escolha := null;
      for f in select para, rotulo, 1.0 / power(1 + coalesce((v_visitas->>para)::int, 0), 2) as peso
                 from rt.fluxo where jornada = p_jornada and de = v_no and coalesce((v_visitas->>para)::int, 0) < 3 order by id loop
        v_acum := v_acum + f.peso;
        if v_escolha is null and v_sorteio <= v_acum then v_escolha := f.para; v_rotulo := f.rotulo; end if;
      end loop;
      if v_escolha is null then select para, rotulo into v_escolha, v_rotulo from rt.fluxo where jornada = p_jornada and de = v_no order by id desc limit 1; end if;
      select e.id, e.modo into v_etapa_id, v_modo from org.etapa e where e.jornada = p_jornada and e.numero = (
        select coalesce(n.etapa_numero, (regexp_match(v_no, '_E(\d+)_'))[1]::smallint));
      insert into rt.evento (instancia, motor, jornada, etapa, tipo, resultado, inicio, simulado, versao_base)
           values (v_inst, v_motor, p_jornada, v_etapa_id, 'decisao', coalesce(n.nome, v_no) || ' → ' || coalesce(v_rotulo, '(sem rótulo)'), v_t, true, v_versao);
      v_fila := v_fila || v_escolha;

    elsif n.tipo = 'parallelGateway' then
      select count(*) into v_entradas from rt.fluxo where jornada = p_jornada and para = v_no;
      if v_entradas > 1 then
        v_chegadas := jsonb_set(v_chegadas, array[v_no], to_jsonb(coalesce((v_chegadas->>v_no)::int, 0) + 1));
        if (v_chegadas->>v_no)::int >= v_entradas then
          v_chegadas := jsonb_set(v_chegadas, array[v_no], '0'::jsonb);
          v_fila := v_fila || (select array_agg(para order by id) from rt.fluxo where jornada = p_jornada and de = v_no);
        end if;
      else
        v_fila := v_fila || (select array_agg(para order by id) from rt.fluxo where jornada = p_jornada and de = v_no);
      end if;

    elsif n.tipo = 'endEvent' then
      insert into rt.evento (instancia, motor, jornada, tipo, resultado, fim, simulado, versao_base)
           values (v_inst, v_motor, p_jornada, 'fim', coalesce(n.nome, v_no), v_t, true, v_versao);
      update rt.instancia set fim_no = coalesce(fim_no || ' | ', '') || coalesce(n.nome, v_no) where id = v_inst;

    else
      -- início, junção exclusiva e eventos intermediários: segue
      v_fila := v_fila || coalesce((select array_agg(para order by id) from rt.fluxo where jornada = p_jornada and de = v_no), '{}');
    end if;
  end loop;

  update rt.instancia set estado = case when fim_no is null then 'erro' else 'concluida' end,
         detalhe = case when fim_no is null then 'terminou sem chegar a um fim' end,
         passos = v_passos, fim = v_t where id = v_inst;
  return v_inst;
end $$;

-- Painel de cobertura: quanto do modelo de cada motor já rodou na simulação
create view rt.v_cobertura with (security_invoker = true) as
  select v.motor, count(*) as tarefas,
         count(*) filter (where exists (select 1 from rt.evento e where e.tarefa = v.tarefa)) as tarefas_executadas
    from rt.vinculo v group by v.motor;

-- Segurança, como no 003
do $$ declare t text; begin
  foreach t in array array['sistema', 'vinculo', 'parametro_simulacao', 'instancia'] loop
    execute format('alter table rt.%I enable row level security', t);
    execute format('create policy leitura_autenticada on rt.%I for select to authenticated using (true)', t);
  end loop;
end $$;
grant select on rt.sistema, rt.vinculo, rt.parametro_simulacao, rt.instancia to authenticated;
grant all on rt.sistema, rt.vinculo, rt.parametro_simulacao, rt.instancia to service_role;
revoke all on all functions in schema rt from public;
grant execute on all functions in schema rt to service_role;

commit;
