-- Gerado de testar_runtime.sql e testar_motor.sql: os mesmos testes como funções, para rodar no Supabase.
-- Uso (desfaz tudo): do $$ begin raise exception '%', rt._testar_runtime() || ' | ' || rt._testar_motor(); end $$;
create or replace function rt._testar_runtime() returns text language plpgsql set search_path = '' as $f$
declare n int; v text; v_antes text; p uuid; t_id bigint; j text; dest smallint; esperado smallint;
begin
  -- T1. Nove motores, um por círculo; Identidade é o piloto
  select count(*) into n from rt.motor;
  if n <> 9 then raise exception 'FALHA T1: % motores', n; end if;
  if (select estado from rt.motor where circulo = 1) <> 'piloto' then raise exception 'FALHA T1: Identidade não é piloto'; end if;

  -- T2. A configuração de cada motor bate com o modelo
  select count(*) into n from rt.motor m
   where jsonb_array_length((select valor from rt.config where motor = m.circulo and chave = 'jornadas'))
         <> (select count(*) from org.jornada where circulo = m.circulo);
  if n <> 0 then raise exception 'FALHA T2: % motores com jornadas diferentes do modelo', n; end if;
  if (select sum(jsonb_array_length(valor)) from rt.config where chave = 'jornadas') <> (select count(*) from org.jornada) then raise exception 'FALHA T2: total de jornadas'; end if;

  -- T3. Publicar uma versão abre uma atualização pendente em cada um dos nove motores
  n := rt.publicar_versao('teste-1', 'versão de teste');
  if n <> 9 then raise exception 'FALHA T3: % atualizações abertas', n; end if;

  -- T4. Testes vermelhos recusam e não mudam a versão do motor; verdes aplicam
  v_antes := (select versao_base from rt.motor where circulo = 2);
  v := rt.concluir_atualizacao(2::smallint, 'teste-1', false, 'teste do círculo falhou');
  if v <> 'recusada' or (select versao_base from rt.motor where circulo = 2) is distinct from v_antes then raise exception 'FALHA T4: recusa'; end if;
  v := rt.concluir_atualizacao(1::smallint, 'teste-1', true);
  if v <> 'aplicada' or (select versao_base from rt.motor where circulo = 1) <> 'teste-1' then raise exception 'FALHA T4: aplicação'; end if;
  begin
    perform rt.concluir_atualizacao(1::smallint, 'teste-1', true);
    raise exception 'FALHA T4: concluiu duas vezes';
  exception when others then
    if sqlerrm like 'FALHA%' then raise; end if;
  end;

  -- T5. Toda troca do modelo chega ao motor do círculo que a recebe (todas)
  select count(*) into n from org.troca t
    join org.circulo cd on cd.nome = t.de_circulo join org.circulo cp on cp.nome = t.para_circulo
   where not exists (select 1 from rt.motor where circulo = cd.numero) or not exists (select 1 from rt.motor where circulo = cp.numero);
  if n <> 0 then raise exception 'FALHA T5: % trocas sem motor', n; end if;
  if (select sum(trocas) from rt.v_rota_troca) <> (select count(*) from org.troca) then raise exception 'FALHA T5: rotas'; end if;

  -- T6. Enviar uma troca real registra o envio no motor certo e o evento
  select t.id, j2.codigo, cp.numero into t_id, j, esperado
    from org.troca t join org.circulo cd on cd.nome = t.de_circulo join org.circulo cp on cp.nome = t.para_circulo
    join org.jornada j2 on j2.circulo = cd.numero order by t.id limit 1;
  perform rt.enviar_troca(t_id, j, '{"teste": true}'::jsonb, true);
  select para_motor into dest from rt.troca_envio where troca = t_id;
  if dest <> esperado then raise exception 'FALHA T6: troca foi para %, esperado %', dest, esperado; end if;
  if not exists (select 1 from rt.evento where tipo = 'troca_enviada' and simulado) then raise exception 'FALHA T6: sem evento'; end if;
  begin
    perform rt.enviar_troca(t_id, 'XX-99', '{}'::jsonb, true);
    raise exception 'FALHA T6: aceitou jornada de outro círculo';
  exception when others then
    if sqlerrm like 'FALHA%' then raise; end if;
  end;

  -- T7. Pessoa real no Telegram sem consentimento do art. 33 é recusada; simulada passa
  begin
    insert into rt_chave.identidade (nome, telegram_id, simulado) values ('Pessoa real', 111, false);
    raise exception 'FALHA T7: aceitou pessoa real sem consentimento';
  exception when check_violation then null;
  end;
  insert into rt_chave.identidade (nome, telegram_id, simulado) values ('Líder simulado da Identidade', 222, true) returning pseudonimo into p;
  insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (p, 'Líder do círculo', 1, true);

  -- T8. Porta única: mensagem gravada, roteada ao motor do chat, autodestruição dentro de 47 horas
  insert into rt.rota_chat (chat_ref, motor, descricao) values ('teste:grupo-identidade', 1, 'grupo de teste');
  perform rt.receber_mensagem('teste:grupo-identidade', '1', p, 'olá', true);
  if (select motor from rt.mensagem where chat_ref = 'teste:grupo-identidade') <> 1 then raise exception 'FALHA T8: rota'; end if;
  begin
    perform rt.receber_mensagem('teste:grupo-identidade', '2', p, 'olá', true, 72);
    raise exception 'FALHA T8: aceitou autodestruição em 72 horas';
  exception when check_violation then null;
  end;
  begin
    perform rt.receber_mensagem('chat-sem-motor', '3', p, 'olá', true);
    raise exception 'FALHA T8: aceitou chat sem motor';
  exception when others then
    if sqlerrm like 'FALHA%' then raise; end if;
  end;

  -- T9. Evento sem a marca simulado ou real é recusado
  begin
    insert into rt.evento (motor, jornada, tipo, simulado) values (1, 'ID-01', 'inicio', null);
    raise exception 'FALHA T9: aceitou evento sem marca';
  exception when not_null_violation then null;
  end;

  -- T10. Segurança: anon não lê nada; autenticado não lê a identidade real
  if has_schema_privilege('anon', 'rt', 'usage') or has_schema_privilege('anon', 'rt_chave', 'usage') then raise exception 'FALHA T10: anon com acesso'; end if;
  if has_schema_privilege('authenticated', 'rt_chave', 'usage') then raise exception 'FALHA T10: autenticado vê a identidade'; end if;
  if has_function_privilege('authenticated', 'rt.publicar_versao(text,text,text)', 'execute') then raise exception 'FALHA T10: autenticado publica versão'; end if;
  select count(*) into n from pg_tables where schemaname in ('rt', 'rt_chave') and not rowsecurity;
  if n <> 0 then raise exception 'FALHA T10: % tabelas sem RLS', n; end if;

  return 'RUNTIME DOS RUNTIMES: 10 testes, 0 falhas';
end $f$;
revoke all on function rt._testar_runtime() from public;
create or replace function rt._testar_motor() returns text language plpgsql set search_path = '' as $f$
declare n int; m int; i1 bigint; i2 bigint; j record; v_inst bigint;
begin
  -- T1. Cada tarefa está ligada a um sistema coerente com o executor (G7)
  select count(*) into n from org.tarefa t left join rt.vinculo v on v.tarefa = t.id where v.tarefa is null;
  if n <> 0 then raise exception 'FALHA T1: % tarefas sem sistema', n; end if;
  select count(*) into n from rt.vinculo v join org.tarefa t on t.id = v.tarefa
   where not (v.sistema = case t.executor when 'P' then 'canal-pessoa' when 'H' then 'canal-pessoa' when 'A' then 'agente-ia'
                                      when 'R' then 'automacao' when 'C' then 'troca-circulo' when 'X' then 'canal-externo' end
              or (t.executor = 'R' and v.sistema in ('erp-contabil', 'banco', 'emissor-fiscal')));
  if n <> 0 then raise exception 'FALHA T1: % tarefas no sistema errado', n; end if;

  -- T2. Toda raia de pessoa tem usuário simulado em todos os motores que a usam
  select count(*) into n from (
    select distinct t.raia, jo.circulo from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada jo on jo.codigo = e.jornada
     where t.executor in ('P', 'H', 'X', 'C')) x
   where rt._pessoa(x.raia, x.circulo) is null;
  if n <> 0 then raise exception 'FALHA T2: % raias sem pessoa simulada', n; end if;
  if exists (select 1 from rt.pessoa where not simulado) then raise exception 'FALHA T2: pessoa real na carga'; end if;

  -- T3. O grafo bate com o modelo: todas as tarefas, cada uma num nó; toda jornada tem início e fim
  select count(*) into n from rt.no where tarefa is not null;
  if n <> (select count(*) from org.tarefa) then raise exception 'FALHA T3: % nós de tarefa', n; end if;
  select count(*) into n from org.jornada jo where not exists (select 1 from rt.no where jornada = jo.codigo and tipo = 'startEvent')
                                                  or not exists (select 1 from rt.no where jornada = jo.codigo and tipo = 'endEvent');
  if n <> 0 then raise exception 'FALHA T3: % jornadas sem início ou fim', n; end if;

  -- T4. As cinco jornadas da Identidade (piloto) rodam até um fim, 10 vezes cada
  for j in select codigo from org.jornada where circulo = 1 loop
    for k in 1..10 loop
      v_inst := rt.executar_simulada(j.codigo, k / 11.0, timestamptz '2026-10-05 08:00-03');
      if (select estado from rt.instancia where id = v_inst) <> 'concluida' then
        raise exception 'FALHA T4: % semente % terminou em %', j.codigo, k, (select detalhe from rt.instancia where id = v_inst);
      end if;
    end loop;
  end loop;

  -- T5. Mesma semente, mesmo caminho
  i1 := rt.executar_simulada('ID-02', 0.3, timestamptz '2026-10-05 08:00-03');
  i2 := rt.executar_simulada('ID-02', 0.3, timestamptz '2026-10-05 08:00-03');
  if (select array_agg(coalesce(tarefa::text, resultado) order by id) from rt.evento where instancia = i1)
     is distinct from (select array_agg(coalesce(tarefa::text, resultado) order by id) from rt.evento where instancia = i2) then
    raise exception 'FALHA T5: mesma semente deu caminhos diferentes';
  end if;

  -- T6. Eventos: todos simulados; na execução da tarefa, pessoa nas tarefas de gente, nenhuma nas de máquina; relógio não volta
  select count(*) into n from rt.evento where instancia is not null and not simulado;
  if n <> 0 then raise exception 'FALHA T6: % eventos sem marca de simulado', n; end if;
  select count(*) into n from rt.evento where tarefa is not null and tipo = 'fim' and ((executor in ('A', 'R') and pessoa is not null) or (executor not in ('A', 'R') and pessoa is null));
  if n <> 0 then raise exception 'FALHA T6: % eventos com pessoa errada', n; end if;
  select count(*) into n from rt.evento e join org.tarefa t on t.id = e.tarefa join rt.pessoa p on p.pseudonimo = e.pessoa where e.tipo = 'fim' and p.papel <> t.raia;
  if n <> 0 then raise exception 'FALHA T6: % eventos com pessoa de outro papel', n; end if;
  select count(*) into n from (select fim, lag(fim) over (partition by instancia order by id) as ant from rt.evento where tarefa is not null) x where fim < ant;
  if n <> 0 then raise exception 'FALHA T6: relógio voltou % vezes', n; end if;

  -- T7. Trocas: toda troca enviada vai ao motor do círculo de destino
  select count(*) into n from rt.troca_envio te join org.troca t on t.id = te.troca join org.circulo c on c.nome = t.para_circulo
   where te.para_motor <> c.numero;
  if n <> 0 then raise exception 'FALHA T7: % trocas no motor errado', n; end if;
  if not exists (select 1 from rt.troca_envio) then raise exception 'FALHA T7: nenhuma troca enviada'; end if;

  -- T8. Voltas cortadas: cada fluxo de volta passa no máximo duas vezes, então uma tarefa roda no máximo 1 + 2 × (fluxos de volta da jornada)
  select count(*) into n from (select e.instancia, e.tarefa, i.jornada, count(*) c from rt.evento e join rt.instancia i on i.id = e.instancia
                                where e.tarefa is not null and e.tipo = 'fim' group by 1, 2, 3) x
   where c > 1 + 2 * (select count(*) from rt.fluxo f where f.jornada = x.jornada and f.volta);
  if n <> 0 then raise exception 'FALHA T8: % tarefas rodaram mais de 3 vezes', n; end if;

  -- T9. Todas as jornadas rodam (uma vez cada) sem erro: o motor serve aos nove círculos
  for j in select codigo from org.jornada loop
    v_inst := rt.executar_simulada(j.codigo, 0.77, timestamptz '2026-10-05 08:00-03');
    if (select estado from rt.instancia where id = v_inst) <> 'concluida' then
      raise exception 'FALHA T9: % terminou em %', j.codigo, (select detalhe from rt.instancia where id = v_inst);
    end if;
  end loop;

  return 'MOTOR: 9 testes, 0 falhas';
end $f$;
revoke all on function rt._testar_motor() from public;
