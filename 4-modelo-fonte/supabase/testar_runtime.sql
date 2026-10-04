-- Testes do runtime dos runtimes (003_runtime.sql). Roda numa transação e desfaz tudo no fim.
-- Cada teste que falha interrompe com a mensagem FALHA. Uso: psql -v ON_ERROR_STOP=1 -f testar_runtime.sql
begin;

do $$
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

  raise notice 'RUNTIME DOS RUNTIMES: 10 testes, 0 falhas';
end $$;

rollback;
