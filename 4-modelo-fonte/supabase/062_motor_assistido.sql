-- Motor assistido (achado do ensaio de produção, 04/10/2026).
-- Problema: numa instância real, tarefa de automação (R) ou de agente (A) era concluída na hora como "concluída (simulado)"
-- e a decisão de agente era sorteada. Em produção isso registraria trabalho que ninguém fez e caminhos escolhidos ao acaso.
-- Regra nova, ligada pelo parâmetro motor.maquina_assistida (o perfil de produção liga; o protótipo continua como era):
--   instância real e interativa + tarefa R ou A  -> vira cartão para a pessoa do círculo (raia "X · pessoa"; sem ela, o líder do círculo);
--   decisão de agente ou automação               -> vira cartão de decisão para a mesma pessoa.
-- Quando um adaptador real existir para a tarefa, ele passa a concluí-la (B21 e B22); até lá, nada é inventado.
-- Corrige também: concluir um cartão de fluxo agora envia as trocas da etapa, como o caminho automático já fazia;
-- e o pedido de fora sem pessoa na raia vai ao líder do círculo ou a quem opera no círculo (rt._responsavel).
begin;
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('motor.maquina_assistida', 'global', 'Instância real: tarefa de automação ou de agente vira cartão para a pessoa do círculo, e decisão de agente vira cartão de decisão, até existir o adaptador real', 'booleano', 'false', 'false', '{}', true, '{}', 'Ensaio de produção, 04/10/2026')
on conflict (chave) do nothing;

create or replace function rt._assistido(p rt.instancia) returns boolean language sql stable security definer set search_path = '' as $$
  select not p.simulado and p.interativo and coalesce((adm.valor('motor.maquina_assistida', 'false') #>> '{}')::boolean, false) $$;
create or replace function rt._raia_humana(p_raia text) returns text language sql immutable set search_path = '' as $$
  select regexp_replace(coalesce(p_raia, ''), ' · (automação|agente)$', ' · pessoa') $$;
create or replace function rt._trocas_da_etapa(p_inst bigint, p_etapa bigint) returns int language plpgsql security definer set search_path = '' as $$
declare ins rt.instancia; v_chave text; v_tr record; n int := 0;
begin
  select * into ins from rt.instancia where id = p_inst for update;
  select ins.jornada || ' etapa ' || e.numero into v_chave from org.etapa e where e.id = p_etapa;
  if v_chave is null or v_chave = any (ins.trocas_feitas) then return 0; end if;
  update rt.instancia set trocas_feitas = trocas_feitas || v_chave where id = p_inst;
  for v_tr in select id from org.troca where v_chave = any (sai_em) loop
    perform rt.enviar_troca(v_tr.id, ins.jornada, jsonb_build_object('instancia', p_inst), ins.simulado); n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function rt._assistido(rt.instancia), rt._raia_humana(text), rt._trocas_da_etapa(bigint, bigint) from public, anon, authenticated;
grant execute on function rt._assistido(rt.instancia), rt._raia_humana(text), rt._trocas_da_etapa(bigint, bigint) to service_role;

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
      if ins.interativo and (v_tar.executor in ('P', 'H', 'X') or (v_tar.executor in ('A', 'R') and rt._assistido(ins))) then
        -- tarefa de gente (ou de máquina no modo assistido, feita por pessoa do círculo até o adaptador existir): vira cartão e o token espera
        v_dono := rt._pessoa(rt._raia_humana(v_tar.raia), ins.motor);
        if v_dono is null and v_tar.executor in ('A', 'R') then v_dono := rt._pessoa('Líder do círculo', ins.motor); end if;
        insert into rt.cartao (tipo, titulo, circulo, instancia, no, jornada, etapa, tarefa, papel, dono, criado_por, origem, prazo, simulado)
             values ('fluxo', v_tar.nome || case when v_tar.executor in ('A', 'R') then ' (assistida: ' || lower(v_tar.raia) || ')' else '' end,
                     ins.motor, p_inst, tk.no, ins.jornada, v_tar.etapa_id, v_tar.id, v_tar.raia, v_dono, v_dono, 'motor',
                     coalesce(ins.relogio, now()) + make_interval(mins => (select max_minutos from rt.parametro_simulacao where executor = case when v_tar.executor in ('A', 'R') then 'P' else v_tar.executor end)::int),
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
      if ins.interativo and (coalesce(n.raia, '') !~ '(agente|automação)$' or rt._assistido(ins)) then
        -- decisão de gente: vira cartão na coluna decidir
        select e.id, e.numero into v_et from org.etapa e where e.jornada = ins.jornada and e.numero = (regexp_match(tk.no, '_E(\d+)_'))[1]::smallint;
        v_dono := rt._pessoa(rt._raia_humana(coalesce(n.raia, '')), ins.motor);
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

CREATE OR REPLACE FUNCTION rt.concluir_cartao(p_cartao bigint, p_pessoa uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    -- trocas que saem na etapa: as mesmas do caminho automático, uma vez por etapa
    if c.tarefa is not null then perform rt._trocas_da_etapa(c.instancia, c.etapa); end if;
    delete from rt.token where instancia = c.instancia and no = c.no and estado = 'aguardando';
    insert into rt.token (instancia, no) select c.instancia, para from rt.fluxo where jornada = c.jornada and de = c.no order by id;
    update rt.instancia set relogio = greatest(relogio, now()) where id = c.instancia;
    v := rt._avancar(c.instancia);
  end if;
  return v;
end $function$;


-- Quem recebe um pedido de fora: a pessoa da raia; sem ela, o líder do círculo; sem ele, quem opera no círculo.
-- Sem ninguém, o pedido é recusado com a razão (antes: erro "pessoa sem círculo"). A conferência da implantação aponta o papel vazio.
create or replace function rt._responsavel(p_raia text, p_motor smallint) returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid;
begin
  v := coalesce(rt._pessoa(p_raia, p_motor), rt._pessoa('Líder do círculo', p_motor));
  if v is null then
    select a.pessoa into v from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
     where a.circulo = p_motor and p.circulo = p_motor and a.nivel in ('operar', 'aprovar', 'administrar') and (a.fim is null or a.fim >= current_date)
     order by p.simulado, a.id limit 1;
  end if;
  if v is null then raise exception 'ainda não há pessoa cadastrada no círculo % para receber este pedido (%)', p_motor, p_raia; end if;
  return v;
end $$;
revoke all on function rt._responsavel(text, smallint) from public, anon, authenticated;
grant execute on function rt._responsavel(text, smallint) to service_role;

CREATE OR REPLACE FUNCTION ext._pedir(u ext.usuario, p_tipo text, p_assunto text, p_texto text, p_instancia bigint, p_cliente_final text, p_anonimo boolean)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c ext.contraparte; v_id bigint; v_raia text; v_motor smallint; v_prazo timestamptz; v_dono uuid; v_card bigint;
  v_chave text; v_conf ext.oportunidade; v_dias int;
begin
  select * into c from ext.contraparte where id = u.contraparte;
  if coalesce(length(trim(p_assunto)), 0) = 0 or coalesce(length(trim(p_texto)), 0) = 0 then raise exception 'informe o assunto e o texto'; end if;
  if length(p_texto) > 4000 then raise exception 'texto acima de 4000 caracteres'; end if;
  if coalesce(p_anonimo, false) and p_tipo <> 'ouvidoria' then raise exception 'só a manifestação de ouvidoria pode ser anônima'; end if;
  if p_instancia is not null and not exists (select 1 from ext.vinculo where instancia = p_instancia and contraparte = c.id) then
    raise exception 'referência não pertence a esta organização'; end if;
  if p_tipo in ('aceite', 'devolucao') then
    if u.perfil not in ('gestor', 'fiscal') then raise exception 'o aceite é de quem fiscaliza ou gere o contrato'; end if;
    if p_instancia is null or not exists (select 1 from ext.publicacao where instancia = p_instancia and contraparte = c.id and acao = 'aceite') then
      raise exception 'não há entrega aguardando aceite nesta referência'; end if;
    if exists (select 1 from ext.pedido where instancia = p_instancia and contraparte = c.id and tipo in ('aceite', 'devolucao') and situacao <> 'recusado') then
      raise exception 'esta entrega já tem aceite ou devolução registrados'; end if;
  end if;
  if p_tipo = 'oportunidade' and c.tipo <> 'parceiro' then raise exception 'registro de oportunidade é do parceiro'; end if;
  if p_tipo = 'adesao' and not (c.tipo = 'cliente' and c.setor_publico) then raise exception 'adesão à ata é para órgão público'; end if;
  if p_tipo = 'os' and c.tipo <> 'cliente' then raise exception 'ordem de serviço é do cliente'; end if;
  if p_tipo = 'oportunidade' then
    if coalesce(length(trim(p_cliente_final)), 0) = 0 then raise exception 'informe o cliente final da oportunidade'; end if;
    v_chave := ext._norm(p_cliente_final) || ' | ' || ext._norm(p_assunto);
    update ext.oportunidade set situacao = 'expirada' where chave = v_chave and situacao in ('registrada', 'em_negociacao') and exclusiva_ate < current_date;
    select * into v_conf from ext.oportunidade where chave = v_chave and situacao in ('registrada', 'em_negociacao') and exclusiva_ate >= current_date limit 1;
    if found then raise exception 'oportunidade já registrada por outro canal, com exclusividade até %', to_char(v_conf.exclusiva_ate, 'DD/MM/YYYY'); end if;
  end if;
  case p_tipo
    when 'chamado', 'aceite', 'devolucao', 'reclamacao', 'os' then v_raia := 'Operações · pessoa'; v_motor := 7;
    when 'oportunidade', 'adesao' then v_raia := 'Negócios · pessoa'; v_motor := 5;
    when 'titular', 'ouvidoria' then v_raia := 'Governança · pessoa'; v_motor := 9;
    when 'duvida' then v_raia := 'Relações · pessoa'; v_motor := 4;
    else raise exception 'tipo de pedido desconhecido: %', p_tipo;
  end case;
  v_prazo := case p_tipo
    when 'titular' then now() + make_interval(days => (adm.valor('externo.prazo_titular_dias', '15') #>> '{}')::int)
    when 'ouvidoria' then now() + make_interval(days => (adm.valor('atendimento.prazo_ouvidoria_dias', '10') #>> '{}')::int)
    when 'os' then now() + make_interval(hours => (adm.valor('atendimento.prazo_os_horas', '72') #>> '{}')::int)
    when 'aceite' then now() + make_interval(hours => (adm.valor('externo.prazo_aceite_horas', '24') #>> '{}')::int)
    when 'devolucao' then now() + make_interval(hours => (adm.valor('externo.prazo_aceite_horas', '24') #>> '{}')::int)
    else now() + make_interval(hours => (adm.valor('externo.prazo_resposta_horas', '48') #>> '{}')::int) end;
  v_dono := rt._responsavel(v_raia, v_motor);
  insert into ext.pedido (contraparte, usuario, tipo, instancia, assunto, texto, prazo, anonimo)
  values (c.id, u.auth_uid, p_tipo, p_instancia, p_assunto, p_texto, v_prazo, coalesce(p_anonimo, false)) returning id into v_id;
  v_card := rt.criar_avulsa(v_dono, left(case p_tipo when 'aceite' then 'Aceite do cliente' when 'devolucao' then 'Entrega devolvida pelo cliente'
        when 'oportunidade' then 'Oportunidade registrada pelo parceiro' when 'titular' then 'Pedido de titular de dados (LGPD)'
        when 'adesao' then 'Pedido de adesão à ata' when 'chamado' then 'Chamado do cliente' when 'reclamacao' then 'Reclamação (OP-04)'
        when 'os' then 'Ordem de serviço do cliente' when 'ouvidoria' then 'Manifestação de ouvidoria' else 'Dúvida de fora' end
        || ': ' || p_assunto || case when coalesce(p_anonimo, false) then ' · anônima' else ' · ' || c.nome end, 200),
        v_prazo, null, 'externo', p_instancia);
  update ext.pedido set cartao = v_card where id = v_id;
  if p_tipo = 'oportunidade' then
    v_dias := (adm.valor('externo.exclusividade_dias', '90') #>> '{}')::int;
    insert into ext.oportunidade (pedido, contraparte, cliente_final, chave, exclusiva_ate) values (v_id, c.id, p_cliente_final, v_chave, current_date + v_dias);
  end if;
  if p_tipo in ('aceite', 'devolucao') then
    insert into ext.publicacao (contraparte, instancia, jornada, etapa, estado, mensagem, perfis, acao, em, simulado)
    select c.id, p_instancia, i.jornada, -1, case p_tipo when 'aceite' then 'Aceite registrado' else 'Entrega devolvida' end,
           case p_tipo when 'aceite' then 'Você registrou o aceite desta entrega.' else 'Você devolveu esta entrega: ' || left(p_texto, 300) end,
           '{gestor,fiscal}', null, now(), i.simulado from rt.instancia i where i.id = p_instancia
    on conflict (instancia, contraparte, etapa) do nothing;
  end if;
  return v_id;
end $function$;

-- Teste do modo assistido (entra na rodada única)
create or replace function rt._testar_assistido() returns text language plpgsql set search_path = '' as $$
declare op uuid; lider uuid; inst bigint; k rt.cartao; v text;
begin
  select pseudonimo into op from rt.pessoa where papel = 'Operações · pessoa' and circulo = 7 order by simulado, pseudonimo limit 1;
  -- A1. desligado (padrão do protótipo): automação conclui na hora, sem cartão
  update adm.parametro set valor = 'false' where chave = 'motor.maquina_assistida';
  inst := rt.iniciar_jornada('OP-03', op, false);
  if exists (select 1 from rt.cartao where instancia = inst and titulo like '%(assistida:%') then raise exception 'FALHA A1: cartão assistido com o modo desligado'; end if;
  -- A2. ligado: a primeira tarefa (automação) vira cartão da pessoa de Operações; nada "concluída (simulado)"
  update adm.parametro set valor = 'true' where chave = 'motor.maquina_assistida';
  inst := rt.iniciar_jornada('OP-03', op, false);
  select * into k from rt.cartao where instancia = inst order by id limit 1;
  if k.id is null or k.titulo not like '%(assistida: operações · automação)' or k.papel <> 'Operações · automação' then raise exception 'FALHA A2: tarefa de automação não virou cartão (%)', k.titulo; end if;
  if (select papel from rt.pessoa where pseudonimo = k.dono) <> 'Operações · pessoa' then raise exception 'FALHA A2: cartão fora da pessoa do círculo'; end if;
  if exists (select 1 from rt.evento where instancia = inst and resultado = 'concluída (simulado)') then raise exception 'FALHA A2: concluiu como simulado'; end if;
  -- A3. concluir o cartão leva à tarefa seguinte (agente), também como cartão
  v := rt.concluir_cartao(k.id, k.dono);
  select * into k from rt.cartao where instancia = inst and coluna <> 'feito' order by id limit 1;
  if k.id is null or k.titulo not like '%(assistida: operações · agente)' then raise exception 'FALHA A3: tarefa de agente não virou cartão (%)', k.titulo; end if;
  -- A4. concluir o de agente leva à decisão de agente, que vira cartão de decisão (nada sorteado)
  v := rt.concluir_cartao(k.id, k.dono);
  select * into k from rt.cartao where instancia = inst and coluna <> 'feito' order by id limit 1;
  if k.id is null or k.coluna <> 'decidir' then raise exception 'FALHA A4: decisão de agente não virou cartão (%)', k.coluna; end if;
  if exists (select 1 from rt.evento where instancia = inst and tipo = 'decisao' and resultado like '%(agente)') then raise exception 'FALHA A4: decisão sorteada'; end if;
  -- A5. instância simulada continua automática mesmo com o modo ligado
  inst := rt.executar_simulada('OP-03', 0.5, now());
  if exists (select 1 from rt.cartao where instancia = inst and titulo like '%(assistida:%') then raise exception 'FALHA A5: simulação virou assistida'; end if;
  return 'motor assistido: 5 de 5 ok';
end $$;
revoke all on function rt._testar_assistido() from public, anon, authenticated;

-- a rodada única passa a ter 18 suítes
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido'] loop
    begin
      execute format('select %s()', s) into msg;
      raise exception using errcode = 'P0099', message = msg;
    exception when sqlstate 'P0099' then res := res || jsonb_build_object(s, jsonb_build_object('ok', true, 'resultado', sqlerrm));
              when others then res := res || jsonb_build_object(s, jsonb_build_object('ok', false, 'resultado', sqlerrm));
    end;
  end loop;
  return jsonb_build_object('todas_ok', not exists (select 1 from jsonb_each(res) e where not (e.value->>'ok')::boolean), 'suites', res);
end $f$;
commit;
