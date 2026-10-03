-- Mesa de trabalho (E11), decisões de 03/10/2026, 20:36. Depende de 003 a 009.
-- 1. Motor interativo: a execução para nas tarefas de gente e nas decisões de gente, que viram cartões.
-- 2. Cartões: de fluxo, avulsa e pedido de ajuda; cinco colunas; delegação a agente e a pessoa; aceite.
-- 3. Regras: dono e prazo obrigatórios; cartão de fluxo só anda pelo motor; delegação de fluxo só na mesma raia
--    (fora dela, o líder); o modo do agente não passa do modo da etapa; avulsa privada; avulsa repetida vira sinal.
begin;

-- Estado persistente da execução interativa
alter table rt.instancia add column interativo boolean not null default false;
alter table rt.instancia add column visitas jsonb not null default '{}'::jsonb;
alter table rt.instancia add column chegadas jsonb not null default '{}'::jsonb;
alter table rt.instancia add column trocas_feitas text[] not null default '{}';
alter table rt.instancia add column relogio timestamptz;

create table rt.token (
  id        bigint generated always as identity primary key,
  instancia bigint not null references rt.instancia(id) on delete cascade,
  no        text not null,
  estado    text not null default 'pronto' check (estado in ('pronto', 'aguardando')),
  criado_em timestamptz not null default now()
);
create index token_instancia on rt.token (instancia, estado);

-- Cartões da Mesa
create table rt.cartao (
  id              bigint generated always as identity primary key,
  tipo            text not null check (tipo in ('fluxo', 'avulsa', 'ajuda')),
  titulo          text not null check (length(trim(titulo)) > 0),
  circulo         smallint not null references org.circulo(numero),
  instancia       bigint references rt.instancia(id),
  no              text,
  jornada         text references org.jornada(codigo),
  etapa           bigint references org.etapa(id),
  tarefa          bigint references org.tarefa(id),
  papel           text,
  dono            uuid not null references rt.pessoa(pseudonimo),
  criado_por      uuid not null references rt.pessoa(pseudonimo),
  delegado_pessoa uuid references rt.pessoa(pseudonimo),
  delegado_agente boolean not null default false,
  modo            smallint check (modo between 0 and 3),
  coluna          text not null default 'a_fazer' check (coluna in ('a_fazer', 'fazendo', 'esperando', 'decidir', 'feito')),
  prazo           timestamptz not null,
  aceite          text check (aceite in ('pendente', 'aceita', 'recusada')),
  origem          text not null default 'mesa' check (origem in ('motor', 'mesa', 'telegram', 'voz')),
  opcoes          jsonb,
  escolha         text,
  pai             bigint references rt.cartao(id),
  simulado        boolean not null,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  concluido_em    timestamptz,
  constraint fluxo_tem_execucao check (tipo <> 'fluxo' or (instancia is not null and no is not null and jornada is not null)),
  constraint ajuda_tem_pai check (tipo <> 'ajuda' or pai is not null),
  constraint agente_tem_modo check (not delegado_agente or modo is not null)
);
create index cartao_dono on rt.cartao (dono, coluna);
create index cartao_delegado on rt.cartao (delegado_pessoa) where delegado_pessoa is not null;
create index cartao_instancia on rt.cartao (instancia);

-- Eventos passam a registrar cartões; a avulsa não tem jornada
alter table rt.evento alter column jornada drop not null;
alter table rt.evento add column cartao bigint references rt.cartao(id);
alter table rt.evento drop constraint evento_tipo_check;
alter table rt.evento add constraint evento_tipo_check check (tipo in ('inicio', 'fim', 'decisao', 'troca_enviada', 'troca_recebida', 'escalada', 'erro',
  'cartao_criado', 'cartao_movido', 'delegado', 'aceito', 'recusado', 'concluido'));
create index evento_cartao on rt.evento (cartao);

-- Uma segunda pessoa simulada da Identidade, para testar a delegação a colega
with i as (insert into rt_chave.identidade (nome, simulado) values ('Simulado · Identidade · pessoa · 2', true) returning pseudonimo)
insert into rt.pessoa (pseudonimo, papel, circulo, simulado) select pseudonimo, 'Identidade · pessoa', 1, true from i;

create function rt._nivel_modo(p org.modo) returns smallint language sql immutable set search_path = '' as $$
  select (array_position(enum_range(null::org.modo), p) - 1)::smallint $$;

create function rt._ev(p_inst bigint, p_cartao bigint, p_tipo text, p_res text, p_pessoa uuid, p_motor smallint, p_jornada text,
                       p_etapa bigint, p_tarefa bigint, p_exec org.executor, p_ini timestamptz, p_fim timestamptz, p_sim boolean)
returns void language sql set search_path = '' as $$
  insert into rt.evento (instancia, cartao, motor, jornada, etapa, tarefa, pessoa, executor, tipo, resultado, inicio, fim, simulado, versao_base)
  select p_inst, p_cartao, p_motor, p_jornada, p_etapa, p_tarefa, p_pessoa, p_exec, p_tipo, p_res, p_ini, p_fim, p_sim, m.versao_base
    from rt.motor m where m.circulo = p_motor $$;

-- O passo do motor: processa os tokens prontos até tudo estar esperando gente ou acabar
create function rt._avancar(p_inst bigint, p_max integer default 600) returns text
language plpgsql security definer set search_path = '' as $$
declare
  ins rt.instancia; tk rt.token; n rt.no; f record; v_tar record; v_min numeric; v_chave text; v_tr record;
  v_ent int; v_total numeric; v_sort numeric; v_acum numeric; v_esc text; v_rot text; v_passos int := 0; v_dono uuid; v_et record; v_cartao bigint;
begin
  select * into ins from rt.instancia where id = p_inst for update;
  loop
    select * into tk from rt.token where instancia = p_inst and estado = 'pronto' order by id limit 1;
    exit when tk.id is null;
    v_passos := v_passos + 1;
    if v_passos > p_max then
      update rt.instancia set estado = 'erro', detalhe = 'passou do limite de passos' where id = p_inst; return 'erro';
    end if;
    delete from rt.token where id = tk.id;
    select * into n from rt.no where jornada = ins.jornada and id = tk.no;
    update rt.instancia set visitas = jsonb_set(visitas, array[tk.no], to_jsonb(coalesce((visitas->>tk.no)::int, 0) + 1)) where id = p_inst
      returning * into ins;

    if n.tarefa is not null then
      select t.*, e.id as etapa_id, e.modo as etapa_modo, e.numero as etapa_numero, e.nome as etapa_nome into v_tar
        from org.tarefa t join org.etapa e on e.id = t.etapa where t.id = n.tarefa;
      if ins.interativo and v_tar.executor in ('P', 'H', 'X') then
        -- tarefa de gente: vira cartão e o token espera
        v_dono := rt._pessoa(v_tar.raia, ins.motor);
        insert into rt.cartao (tipo, titulo, circulo, instancia, no, jornada, etapa, tarefa, papel, dono, criado_por, origem, prazo, simulado)
             values ('fluxo', v_tar.nome, ins.motor, p_inst, tk.no, ins.jornada, v_tar.etapa_id, v_tar.id, v_tar.raia, v_dono, v_dono, 'motor',
                     coalesce(ins.relogio, now()) + make_interval(mins => (select max_minutos from rt.parametro_simulacao where executor = v_tar.executor)::int),
                     ins.simulado)
          returning id into v_cartao;
        insert into rt.token (instancia, no, estado) values (p_inst, tk.no, 'aguardando');
        perform rt._ev(p_inst, v_cartao, 'cartao_criado', 'a fazer: ' || v_tar.nome, v_dono, ins.motor, ins.jornada, v_tar.etapa_id, v_tar.id, v_tar.executor, ins.relogio, null, ins.simulado);
        continue;
      end if;
      -- máquina ou outro círculo: o adaptador simulado conclui na hora
      v_min := rt._minutos(v_tar.executor);
      perform rt._ev(p_inst, null, 'fim', 'concluída (simulado)', case when v_tar.executor in ('A', 'R') then null else rt._pessoa(v_tar.raia, ins.motor) end,
                     ins.motor, ins.jornada, v_tar.etapa_id, v_tar.id, v_tar.executor, ins.relogio, ins.relogio + make_interval(secs => v_min * 60), ins.simulado);
      update rt.instancia set relogio = relogio + make_interval(secs => v_min * 60) where id = p_inst returning * into ins;
      v_chave := ins.jornada || ' etapa ' || v_tar.etapa_numero;
      if not v_chave = any (ins.trocas_feitas) then
        update rt.instancia set trocas_feitas = trocas_feitas || v_chave where id = p_inst returning * into ins;
        for v_tr in select id from org.troca where v_chave = any (sai_em) loop
          perform rt.enviar_troca(v_tr.id, ins.jornada, jsonb_build_object('instancia', p_inst), ins.simulado);
        end loop;
      end if;
      insert into rt.token (instancia, no) select p_inst, para from rt.fluxo where jornada = ins.jornada and de = tk.no order by id;

    elsif n.tipo = 'exclusiveGateway' and n.diverge then
      if ins.interativo and coalesce(n.raia, '') !~ '(agente|automação)$' then
        -- decisão de gente: vira cartão na coluna decidir
        select e.id, e.numero into v_et from org.etapa e where e.jornada = ins.jornada and e.numero = (regexp_match(tk.no, '_E(\d+)_'))[1]::smallint;
        v_dono := rt._pessoa(coalesce(n.raia, ''), ins.motor);
        if v_dono is null then v_dono := rt._pessoa('Líder do círculo', ins.motor); end if;
        insert into rt.cartao (tipo, titulo, circulo, instancia, no, jornada, etapa, papel, dono, criado_por, coluna, origem, prazo, opcoes, simulado)
             values ('fluxo', coalesce(n.nome, 'Decidir o caminho'), ins.motor, p_inst, tk.no, ins.jornada, v_et.id, n.raia, v_dono, v_dono, 'decidir', 'motor',
                     coalesce(ins.relogio, now()) + interval '1 day',
                     (select jsonb_agg(jsonb_build_object('para', para, 'rotulo', coalesce(rotulo, para)) order by id) from rt.fluxo where jornada = ins.jornada and de = tk.no
                        and coalesce((ins.visitas->>para)::int, 0) < 3),
                     ins.simulado)
          returning id into v_cartao;
        insert into rt.token (instancia, no, estado) values (p_inst, tk.no, 'aguardando');
        perform rt._ev(p_inst, v_cartao, 'cartao_criado', 'decidir: ' || coalesce(n.nome, ''), v_dono, ins.motor, ins.jornada, v_et.id, null, null, ins.relogio, null, ins.simulado);
        continue;
      end if;
      select sum(1.0 / power(1 + coalesce((ins.visitas->>para)::int, 0), 2)) into v_total
        from rt.fluxo where jornada = ins.jornada and de = tk.no and coalesce((ins.visitas->>para)::int, 0) < 3;
      if v_total is null then update rt.instancia set estado = 'erro', detalhe = 'decisão sem saída em ' || tk.no where id = p_inst; return 'erro'; end if;
      v_sort := random() * v_total; v_acum := 0; v_esc := null;
      for f in select para, rotulo, 1.0 / power(1 + coalesce((ins.visitas->>para)::int, 0), 2) as peso
                 from rt.fluxo where jornada = ins.jornada and de = tk.no and coalesce((ins.visitas->>para)::int, 0) < 3 order by id loop
        v_acum := v_acum + f.peso;
        if v_esc is null and v_sort <= v_acum then v_esc := f.para; v_rot := f.rotulo; end if;
      end loop;
      perform rt._ev(p_inst, null, 'decisao', coalesce(n.nome, tk.no) || ' → ' || coalesce(v_rot, '(sem rótulo)') || ' (agente)', null, ins.motor, ins.jornada, null, null, null, ins.relogio, null, ins.simulado);
      insert into rt.token (instancia, no) values (p_inst, v_esc);

    elsif n.tipo = 'parallelGateway' then
      select count(*) into v_ent from rt.fluxo where jornada = ins.jornada and para = tk.no;
      if v_ent > 1 then
        update rt.instancia set chegadas = jsonb_set(chegadas, array[tk.no], to_jsonb(coalesce((chegadas->>tk.no)::int, 0) + 1)) where id = p_inst returning * into ins;
        if (ins.chegadas->>tk.no)::int >= v_ent then
          update rt.instancia set chegadas = jsonb_set(chegadas, array[tk.no], '0'::jsonb) where id = p_inst returning * into ins;
          insert into rt.token (instancia, no) select p_inst, para from rt.fluxo where jornada = ins.jornada and de = tk.no order by id;
        end if;
      else
        insert into rt.token (instancia, no) select p_inst, para from rt.fluxo where jornada = ins.jornada and de = tk.no order by id;
      end if;

    elsif n.tipo = 'endEvent' then
      perform rt._ev(p_inst, null, 'fim', coalesce(n.nome, tk.no), null, ins.motor, ins.jornada, null, null, null, null, ins.relogio, ins.simulado);
      update rt.instancia set fim_no = coalesce(fim_no || ' | ', '') || coalesce(n.nome, tk.no) where id = p_inst returning * into ins;

    else
      insert into rt.token (instancia, no) select p_inst, para from rt.fluxo where jornada = ins.jornada and de = tk.no order by id;
    end if;
  end loop;
  update rt.instancia set passos = passos + v_passos where id = p_inst;
  if not exists (select 1 from rt.token where instancia = p_inst) then
    update rt.instancia set estado = case when fim_no is null then 'erro' else 'concluida' end,
           detalhe = case when fim_no is null then 'terminou sem chegar a um fim' end, fim = relogio where id = p_inst;
    return (select estado from rt.instancia where id = p_inst);
  end if;
  return 'esperando';
end $$;

-- Inicia uma execução interativa de uma jornada
create function rt.iniciar_jornada(p_jornada text, p_pessoa uuid, p_simulado boolean default true, p_semente double precision default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_motor smallint; v_inst bigint; v_ini text;
begin
  select circulo into v_motor from org.jornada where codigo = p_jornada;
  if v_motor is null then raise exception 'jornada inexistente: %', p_jornada; end if;
  if (select estado from rt.motor where circulo = v_motor) = 'desenho' then raise exception 'o motor do círculo % ainda está em desenho', v_motor; end if;
  if p_semente is not null then perform setseed(p_semente); end if;
  insert into rt.instancia (motor, jornada, simulado, semente, inicio, relogio, versao_base, interativo)
       select v_motor, p_jornada, p_simulado, p_semente, now(), now(), versao_base, true from rt.motor where circulo = v_motor returning id into v_inst;
  perform rt._ev(v_inst, null, 'inicio', 'iniciada na Mesa', p_pessoa, v_motor, p_jornada, null, null, null, now(), null, p_simulado);
  select id into v_ini from rt.no where jornada = p_jornada and tipo = 'startEvent' order by id limit 1;
  insert into rt.token (instancia, no) values (v_inst, v_ini);
  perform rt._avancar(v_inst);
  return v_inst;
end $$;

create function rt._pode_agir(c rt.cartao, p uuid) returns boolean language sql stable set search_path = '' as $$
  select coalesce(c.dono = p, false) or coalesce(c.delegado_pessoa = p and c.aceite is distinct from 'recusada', false) $$;

-- Concluir um cartão: o de fluxo libera o token e o motor segue
create function rt.concluir_cartao(p_cartao bigint, p_pessoa uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare c rt.cartao; v text := 'feito';
begin
  select * into c from rt.cartao where id = p_cartao for update;
  if c.id is null then raise exception 'cartão inexistente'; end if;
  if c.coluna = 'feito' then raise exception 'cartão já concluído'; end if;
  if c.coluna = 'decidir' then raise exception 'cartão de decisão se resolve escolhendo um caminho'; end if;
  if not rt._pode_agir(c, p_pessoa) then raise exception 'só quem é dono ou recebeu a tarefa pode concluir'; end if;
  if c.delegado_pessoa = p_pessoa and c.aceite = 'pendente' then raise exception 'aceite a tarefa antes de concluir'; end if;
  update rt.cartao set coluna = 'feito', concluido_em = now(), atualizado_em = now() where id = p_cartao;
  perform rt._ev(c.instancia, c.id, 'concluido', c.titulo, p_pessoa, c.circulo, c.jornada, c.etapa, c.tarefa,
                 (select executor from org.tarefa where id = c.tarefa), c.criado_em, now(), c.simulado);
  if c.tipo = 'fluxo' then
    delete from rt.token where instancia = c.instancia and no = c.no and estado = 'aguardando';
    insert into rt.token (instancia, no) select c.instancia, para from rt.fluxo where jornada = c.jornada and de = c.no order by id;
    update rt.instancia set relogio = greatest(relogio, now()) where id = c.instancia;
    v := rt._avancar(c.instancia);
  end if;
  return v;
end $$;

-- Decidir: escolhe um dos caminhos oferecidos
create function rt.decidir_cartao(p_cartao bigint, p_pessoa uuid, p_para text) returns text
language plpgsql security definer set search_path = '' as $$
declare c rt.cartao;
begin
  select * into c from rt.cartao where id = p_cartao for update;
  if c.coluna <> 'decidir' then raise exception 'este cartão não é uma decisão aberta'; end if;
  if not rt._pode_agir(c, p_pessoa) then raise exception 'só quem tem a decisão pode decidir'; end if;
  if not exists (select 1 from jsonb_array_elements(c.opcoes) o where o->>'para' = p_para) then raise exception 'caminho fora das opções'; end if;
  update rt.cartao set coluna = 'feito', escolha = p_para, concluido_em = now(), atualizado_em = now() where id = p_cartao;
  perform rt._ev(c.instancia, c.id, 'decisao', c.titulo || ' → ' || (select o->>'rotulo' from jsonb_array_elements(c.opcoes) o where o->>'para' = p_para limit 1),
                 p_pessoa, c.circulo, c.jornada, c.etapa, null, null, now(), now(), c.simulado);
  delete from rt.token where instancia = c.instancia and no = c.no and estado = 'aguardando';
  insert into rt.token (instancia, no) values (c.instancia, p_para);
  return rt._avancar(c.instancia);
end $$;

-- Mover entre colunas: avulsa e ajuda andam livres; o de fluxo só entre a fazer e fazendo
create function rt.mover_cartao(p_cartao bigint, p_pessoa uuid, p_coluna text) returns void
language plpgsql security definer set search_path = '' as $$
declare c rt.cartao;
begin
  select * into c from rt.cartao where id = p_cartao for update;
  if not rt._pode_agir(c, p_pessoa) then raise exception 'só quem é dono ou recebeu a tarefa pode mover'; end if;
  if p_coluna = 'feito' then raise exception 'para concluir, use concluir'; end if;
  if c.tipo = 'fluxo' and (c.coluna not in ('a_fazer', 'fazendo') or p_coluna not in ('a_fazer', 'fazendo')) then
    raise exception 'cartão de fluxo só anda pelo motor';
  end if;
  if p_coluna = 'decidir' then raise exception 'a coluna decidir é só das decisões do fluxo'; end if;
  update rt.cartao set coluna = p_coluna, atualizado_em = now() where id = p_cartao;
  perform rt._ev(c.instancia, c.id, 'cartao_movido', c.coluna || ' → ' || p_coluna, p_pessoa, c.circulo, c.jornada, c.etapa, c.tarefa, null, now(), null, c.simulado);
end $$;

-- Tarefa avulsa ou pedido de ajuda
create function rt.criar_avulsa(p_pessoa uuid, p_titulo text, p_prazo timestamptz, p_pai bigint default null, p_origem text default 'mesa',
                                p_instancia bigint default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_id bigint; v_circ smallint; v_sim boolean; pai rt.cartao;
begin
  if p_prazo is null then raise exception 'toda tarefa tem prazo'; end if;
  select circulo, simulado into v_circ, v_sim from rt.pessoa where pseudonimo = p_pessoa;
  if p_pai is not null then select * into pai from rt.cartao where id = p_pai; v_circ := pai.circulo; end if;
  if v_circ is null then raise exception 'pessoa sem círculo: a avulsa precisa de um círculo'; end if;
  insert into rt.cartao (tipo, titulo, circulo, instancia, jornada, etapa, dono, criado_por, origem, prazo, pai, simulado)
       values (case when p_pai is null then 'avulsa' else 'ajuda' end, p_titulo, v_circ, coalesce(p_instancia, pai.instancia), pai.jornada, pai.etapa,
               p_pessoa, p_pessoa, p_origem, p_prazo, p_pai, v_sim)
    returning id into v_id;
  perform rt._ev(coalesce(p_instancia, pai.instancia), v_id, 'cartao_criado', case when p_pai is null then 'avulsa' else 'pedido de ajuda' end,
                 p_pessoa, v_circ, pai.jornada, pai.etapa, null, null, now(), null, v_sim);
  return v_id;
end $$;

-- Delegar a pessoa ou a agente
create function rt.delegar_cartao(p_cartao bigint, p_pessoa uuid, p_para uuid default null, p_agente boolean default false, p_modo smallint default null)
returns void language plpgsql security definer set search_path = '' as $$
declare c rt.cartao; quem rt.pessoa; para rt.pessoa; v_teto smallint;
begin
  select * into c from rt.cartao where id = p_cartao for update;
  select * into quem from rt.pessoa where pseudonimo = p_pessoa;
  if c.coluna = 'feito' then raise exception 'cartão já concluído'; end if;
  if c.dono <> p_pessoa and not (quem.papel = 'Líder do círculo' and quem.circulo = c.circulo) then raise exception 'só o dono ou o líder do círculo delega'; end if;
  if p_agente then
    if p_modo is null then raise exception 'diga até onde o agente vai'; end if;
    v_teto := case when c.etapa is not null then rt._nivel_modo((select modo from org.etapa where id = c.etapa)) else 2 end;
    if p_modo > v_teto then raise exception 'o modo pedido passa do aprovado para esta etapa (até %)', v_teto; end if;
    update rt.cartao set delegado_agente = true, modo = p_modo, delegado_pessoa = null, aceite = null, atualizado_em = now() where id = p_cartao;
    perform rt._ev(c.instancia, c.id, 'delegado', 'ao agente, modo ' || p_modo, p_pessoa, c.circulo, c.jornada, c.etapa, c.tarefa, 'A', now(), null, c.simulado);
    -- fazer e enviar: o agente conclui; fazer e você aprova: o agente faz e o cartão espera a sua aprovação em fazendo
    if p_modo = 3 then perform rt.concluir_cartao(p_cartao, c.dono);
    elsif p_modo = 2 then update rt.cartao set coluna = 'fazendo' where id = p_cartao; end if;
    return;
  end if;
  select * into para from rt.pessoa where pseudonimo = p_para;
  if para.pseudonimo is null then raise exception 'pessoa inexistente'; end if;
  if c.tipo = 'fluxo' and para.papel is distinct from c.papel and not (quem.papel = 'Líder do círculo' and quem.circulo = c.circulo) then
    raise exception 'tarefa de fluxo só se delega dentro da mesma raia; fora dela, o líder decide';
  end if;
  update rt.cartao set delegado_pessoa = p_para, delegado_agente = false, modo = null, aceite = 'pendente', atualizado_em = now() where id = p_cartao;
  perform rt._ev(c.instancia, c.id, 'delegado', 'a ' || para.papel || case when para.circulo is distinct from c.circulo then ' (outro círculo)' else '' end,
                 p_pessoa, c.circulo, c.jornada, c.etapa, c.tarefa, null, now(), null, c.simulado);
end $$;

create function rt.responder_delegacao(p_cartao bigint, p_pessoa uuid, p_aceita boolean, p_novo_prazo timestamptz default null)
returns void language plpgsql security definer set search_path = '' as $$
declare c rt.cartao;
begin
  select * into c from rt.cartao where id = p_cartao for update;
  if c.delegado_pessoa is distinct from p_pessoa then raise exception 'só quem recebeu responde à delegação'; end if;
  if c.aceite <> 'pendente' then raise exception 'delegação já respondida'; end if;
  update rt.cartao set aceite = case when p_aceita then 'aceita' else 'recusada' end, prazo = coalesce(p_novo_prazo, prazo), atualizado_em = now(),
         delegado_pessoa = case when p_aceita then delegado_pessoa end where id = p_cartao;
  perform rt._ev(c.instancia, c.id, case when p_aceita then 'aceito' else 'recusado' end, coalesce('novo prazo ' || p_novo_prazo::date, ''),
                 p_pessoa, c.circulo, c.jornada, c.etapa, c.tarefa, null, now(), null, c.simulado);
end $$;

-- A captura sugere a jornada que já existe: palavras de 5 letras ou mais em comum com o nome das tarefas
create function rt.sugerir_jornada(p_texto text) returns jsonb language sql stable set search_path = '' as $$
  with p as (select distinct lower(w) w from regexp_split_to_table(p_texto, '[^[:alpha:]]+') w where length(w) >= 5),
  s as (select t.id, t.nome, e.jornada, j.nome as jnome, count(*) as pontos,
               count(*)::numeric / greatest(1, (select count(*) from regexp_split_to_table(t.nome, '[^[:alpha:]]+') x where length(x) >= 5)) as cobertura
          from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada
          join p on lower(t.nome) like '%' || p.w || '%' group by 1, 2, 3, 4)
  select coalesce(jsonb_agg(jsonb_build_object('jornada', jornada, 'jornada_nome', jnome, 'tarefa', nome, 'pontos', pontos) order by pontos desc, cobertura desc, jornada), '[]'::jsonb)
    from (select * from s order by pontos desc, cobertura desc, jornada limit 3) x $$;

-- Avulsa que se repete: sinal de jornada ou tarefa faltando no modelo (proposta à ID-04)
create view rt.v_avulsas_recorrentes with (security_invoker = true) as
  select circulo, lower(regexp_replace(trim(titulo), '\s+', ' ', 'g')) as titulo, count(*) as vezes, count(distinct dono) as pessoas, max(criado_em) as ultima
    from rt.cartao where tipo = 'avulsa' and criado_em > now() - interval '30 days'
   group by 1, 2 having count(*) >= 3;

-- Meu quadro: o que é meu ou me foi delegado
create function rt.quadro(p_pessoa uuid) returns jsonb language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'tipo', c.tipo, 'titulo', c.titulo, 'coluna', c.coluna, 'prazo', c.prazo, 'jornada', c.jornada, 'jornada_nome', j.nome,
    'etapa', et.numero, 'etapa_nome', et.nome, 'etapa_modo', et.modo, 'tarefa', c.tarefa, 'executor', t.executor, 'papel', c.papel,
    'dono', c.dono, 'sou_dono', c.dono = p_pessoa, 'delegado_pessoa', c.delegado_pessoa, 'delegado_agente', c.delegado_agente, 'modo', c.modo,
    'aceite', c.aceite, 'opcoes', c.opcoes, 'escolha', c.escolha, 'pai', c.pai, 'instancia', c.instancia, 'origem', c.origem,
    'outro_circulo', c.circulo <> coalesce((select circulo from rt.pessoa where pseudonimo = p_pessoa), c.circulo),
    'criado_em', c.criado_em, 'atualizado_em', c.atualizado_em) order by c.prazo), '[]'::jsonb)
    from rt.cartao c left join org.jornada j on j.codigo = c.jornada left join org.etapa et on et.id = c.etapa left join org.tarefa t on t.id = c.tarefa
   where (c.dono = p_pessoa or c.delegado_pessoa = p_pessoa) and (c.coluna <> 'feito' or c.concluido_em > now() - interval '7 days') $$;

-- Quadro do círculo: cartões de fluxo por inteiro; das avulsas, só a carga em números
create function rt.quadro_circulo(p_circulo smallint) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'fluxo', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'titulo', c.titulo, 'coluna', c.coluna, 'jornada', c.jornada, 'papel', c.papel,
                'dono', c.dono, 'prazo', c.prazo, 'instancia', c.instancia) order by c.prazo), '[]'::jsonb)
                from rt.cartao c where c.circulo = p_circulo and c.tipo = 'fluxo' and c.coluna <> 'feito'),
    'carga', (select coalesce(jsonb_agg(jsonb_build_object('pessoa', x.dono, 'papel', p.papel, 'abertas', x.abertas, 'avulsas', x.avulsas)), '[]'::jsonb)
                from (select dono, count(*) as abertas, count(*) filter (where tipo <> 'fluxo') as avulsas
                        from rt.cartao where circulo = p_circulo and coluna <> 'feito' group by dono) x join rt.pessoa p on p.pseudonimo = x.dono),
    'pedidos_de_fora', (select count(*) from rt.cartao c join rt.pessoa p on p.pseudonimo = c.delegado_pessoa
                         where p.circulo = p_circulo and c.circulo <> p_circulo and c.aceite = 'pendente')) $$;

-- Pessoas da Mesa (só pseudônimo e papel) e a execução vista como quadro da jornada
create function rt.mesa_pessoas() returns jsonb language sql stable set search_path = '' as $$
  select jsonb_agg(jsonb_build_object('id', pseudonimo, 'papel', papel, 'circulo', circulo) order by circulo nulls last, papel) from rt.pessoa $$;

alter table rt.token enable row level security;
create policy leitura_autenticada on rt.token for select to authenticated using (true);
-- avulsas e pedidos de ajuda são privados: pela API, só os cartões de fluxo
alter table rt.cartao enable row level security;
create policy leitura_autenticada_fluxo on rt.cartao for select to authenticated using (tipo = 'fluxo');
grant select on rt.token, rt.cartao to authenticated;
grant all on rt.token, rt.cartao to service_role;
revoke all on all functions in schema rt from public;
grant execute on all functions in schema rt to service_role;

commit;
