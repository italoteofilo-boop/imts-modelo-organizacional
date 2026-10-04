-- Ajuste do motor (03/10/2026, E10). Ao rodar as 75 jornadas, o teto de três visitas por nó travou pontos de junção alcançados por caminhos
-- diferentes (ES-01, ES01_E2_G2: "decisão sem saída"). Regra nova: o teto vale por laço. A saída de decisão que abre um laço (rt.fluxo.laco, calculado
-- pelo gerar_grafos.py: leva, sem outra decisão no meio, a um fluxo de volta) tem peso 1/(1+voltas)^2 e fica fora depois de duas voltas;
-- as outras saídas têm peso 1. Se nenhuma saída sobrar, segue a menos usada. Rode depois do 013, que cria as colunas volta e laco.
begin;
CREATE OR REPLACE FUNCTION rt.executar_simulada(p_jornada text, p_semente double precision, p_inicio timestamp with time zone DEFAULT now(), p_max_passos integer DEFAULT 600)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_motor smallint; v_versao text; v_inst bigint; v_t timestamptz := p_inicio;
  v_fila text[]; v_no text; n record; f record; v_min numeric; v_tar record;
  v_visitas jsonb := '{}'::jsonb; v_chegadas jsonb := '{}'::jsonb; v_trocas_feitas text[] := '{}';
  v_passos int := 0; v_entradas int; v_escolha text; v_rotulo text; v_total numeric; v_sorteio numeric; v_acum numeric;
  v_etapa_id bigint; v_modo org.modo; v_tr record; v_chave text; v_laco text;
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
      -- sorteio ponderado: a saída que abre um laço tem peso 1/(1+voltas)^2 e fica fora depois de duas voltas; as outras, peso 1
      select sum(case when laco is null then 1.0 else 1.0 / power(1 + coalesce((v_visitas->>('f:' || laco))::int, 0), 2) end) into v_total from rt.fluxo where jornada = p_jornada and de = v_no and (laco is null or coalesce((v_visitas->>('f:' || laco))::int, 0) < 2);
      v_acum := 0; v_escolha := null; v_laco := null;
      if v_total is null then
        select para, rotulo, laco into v_escolha, v_rotulo, v_laco from rt.fluxo where jornada = p_jornada and de = v_no order by coalesce((v_visitas->>('f:' || laco))::int, 0), id limit 1;
      else
        v_sorteio := random() * v_total;
        for f in select para, rotulo, laco, case when laco is null then 1.0 else 1.0 / power(1 + coalesce((v_visitas->>('f:' || laco))::int, 0), 2) end as peso
                   from rt.fluxo where jornada = p_jornada and de = v_no and (laco is null or coalesce((v_visitas->>('f:' || laco))::int, 0) < 2) order by id loop
          v_acum := v_acum + f.peso;
          if v_escolha is null and v_sorteio <= v_acum then v_escolha := f.para; v_rotulo := f.rotulo; v_laco := f.laco; end if;
        end loop;
        if v_escolha is null then select para, rotulo, laco into v_escolha, v_rotulo, v_laco from rt.fluxo where jornada = p_jornada and de = v_no and (laco is null or coalesce((v_visitas->>('f:' || laco))::int, 0) < 2) order by id desc limit 1; end if;
      end if;
      if v_laco is not null then
        v_visitas := jsonb_set(v_visitas, array['f:' || v_laco], to_jsonb(coalesce((v_visitas->>('f:' || v_laco))::int, 0) + 1));
      end if;
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
end $function$;

CREATE OR REPLACE FUNCTION rt._avancar(p_inst bigint, p_max integer DEFAULT 600)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ins rt.instancia; tk rt.token; n rt.no; f record; v_tar record; v_min numeric; v_chave text; v_tr record;
  v_ent int; v_total numeric; v_sort numeric; v_acum numeric; v_esc text; v_rot text; v_passos int := 0; v_dono uuid; v_et record; v_cartao bigint; v_laco text;
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
                        and ((laco is null or coalesce((ins.visitas->>('f:' || laco))::int, 0) < 2) or not exists (select 1 from rt.fluxo f2 where f2.jornada = ins.jornada and f2.de = tk.no
                             and (f2.laco is null or coalesce((ins.visitas->>('f:' || f2.laco))::int, 0) < 2)))),
                     ins.simulado)
          returning id into v_cartao;
        insert into rt.token (instancia, no, estado) values (p_inst, tk.no, 'aguardando');
        perform rt._ev(p_inst, v_cartao, 'cartao_criado', 'decidir: ' || coalesce(n.nome, ''), v_dono, ins.motor, ins.jornada, v_et.id, null, null, ins.relogio, null, ins.simulado);
        continue;
      end if;
      select sum(case when laco is null then 1.0 else 1.0 / power(1 + coalesce((ins.visitas->>('f:' || laco))::int, 0), 2) end) into v_total from rt.fluxo where jornada = ins.jornada and de = tk.no and (laco is null or coalesce((ins.visitas->>('f:' || laco))::int, 0) < 2);
      v_acum := 0; v_esc := null; v_laco := null;
      if v_total is null then
        select para, rotulo, laco into v_esc, v_rot, v_laco from rt.fluxo where jornada = ins.jornada and de = tk.no order by coalesce((ins.visitas->>('f:' || laco))::int, 0), id limit 1;
      else
        v_sort := random() * v_total;
        for f in select para, rotulo, laco, case when laco is null then 1.0 else 1.0 / power(1 + coalesce((ins.visitas->>('f:' || laco))::int, 0), 2) end as peso
                   from rt.fluxo where jornada = ins.jornada and de = tk.no and (laco is null or coalesce((ins.visitas->>('f:' || laco))::int, 0) < 2) order by id loop
          v_acum := v_acum + f.peso;
          if v_esc is null and v_sort <= v_acum then v_esc := f.para; v_rot := f.rotulo; v_laco := f.laco; end if;
        end loop;
      end if;
      if v_laco is not null then
        update rt.instancia set visitas = jsonb_set(visitas, array['f:' || v_laco], to_jsonb(coalesce((visitas->>('f:' || v_laco))::int, 0) + 1)) where id = p_inst returning * into ins;
      end if;
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
end $function$;

create or replace function rt.decidir_cartao(p_cartao bigint, p_pessoa uuid, p_para text) returns text
language plpgsql security definer set search_path = '' as $$
declare c rt.cartao; v_laco text;
begin
  select * into c from rt.cartao where id = p_cartao for update;
  if c.coluna <> 'decidir' then raise exception 'este cartão não é uma decisão aberta'; end if;
  if not rt._pode_agir(c, p_pessoa) then raise exception 'só quem tem a decisão pode decidir'; end if;
  if not exists (select 1 from jsonb_array_elements(c.opcoes) o where o->>'para' = p_para) then raise exception 'caminho fora das opções'; end if;
  update rt.cartao set coluna = 'feito', escolha = p_para, concluido_em = now(), atualizado_em = now() where id = p_cartao;
  perform rt._ev(c.instancia, c.id, 'decisao', c.titulo || ' → ' || (select o->>'rotulo' from jsonb_array_elements(c.opcoes) o where o->>'para' = p_para limit 1),
                 p_pessoa, c.circulo, c.jornada, c.etapa, null, null, now(), now(), c.simulado);
  select laco into v_laco from rt.fluxo where jornada = c.jornada and de = c.no and para = p_para order by id limit 1;
  if v_laco is not null then
    update rt.instancia set visitas = jsonb_set(visitas, array['f:' || v_laco], to_jsonb(coalesce((visitas->>('f:' || v_laco))::int, 0) + 1)) where id = c.instancia;
  end if;
  delete from rt.token where instancia = c.instancia and no = c.no and estado = 'aguardando';
  insert into rt.token (instancia, no) values (c.instancia, p_para);
  return rt._avancar(c.instancia);
end $$;

revoke all on function rt.executar_simulada(text, double precision, timestamptz, integer), rt._avancar(bigint, integer), rt.decidir_cartao(bigint, uuid, text) from public;
grant execute on function rt.executar_simulada(text, double precision, timestamptz, integer), rt._avancar(bigint, integer), rt.decidir_cartao(bigint, uuid, text) to service_role;
commit;
