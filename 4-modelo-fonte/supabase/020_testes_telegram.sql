-- Os testes do canal Telegram (testar_telegram.sql) como função, para rodar no Supabase sem gravar nada:
-- do $$ begin raise exception '%', rt._testar_telegram(); end $$;
begin;
create or replace function rt._testar_telegram() returns text language plpgsql set search_path = '' as $$
declare
  p1 uuid; tg1 bigint; lider8 uuid; tg8 bigint; ges uuid; tgg bigint; r jsonb; c rt.cartao; i bigint; k int; n int; f rt.fila_envio; ok boolean; v_id bigint;
  upd jsonb;
begin
  select p.pseudonimo, i.telegram_id into p1, tg1 from rt.pessoa p join rt_chave.identidade i using (pseudonimo) where p.papel = 'Identidade · pessoa' order by p.pseudonimo limit 1;
  select p.pseudonimo, i.telegram_id into lider8, tg8 from rt.pessoa p join rt_chave.identidade i using (pseudonimo) where p.papel = 'Líder do círculo' and p.circulo = 8;
  select p.pseudonimo, i.telegram_id into ges, tgg from rt.pessoa p join rt_chave.identidade i using (pseudonimo) where p.papel = 'Gestão · pessoa' limit 1;
  if tg1 is null then raise exception 'FALHA T0: pessoa simulada sem id de Telegram'; end if;

  -- T1. Quem não está cadastrado recebe o caminho do cadastro, e nada mais
  r := rt.receber_update('{"update_id":1,"message":{"message_id":10,"from":{"id":123456},"chat":{"id":123456,"type":"private"},"text":"oi"}}', true);
  if r->>'pessoa' is not null or (select texto from rt.fila_envio where id = (r->>'fila')::bigint) not like '%não está cadastrado%' then raise exception 'FALHA T1: desconhecido'; end if;

  -- T2. /quadro lista os cartões com botões; a mensagem entra com autodestruição de menos de 48 horas
  i := rt.iniciar_jornada('ID-01', p1, true, 0.3);
  upd := jsonb_build_object('update_id', 2, 'message', jsonb_build_object('message_id', 11, 'from', jsonb_build_object('id', tg1), 'chat', jsonb_build_object('id', tg1, 'type', 'private'), 'text', '/quadro'));
  r := rt.receber_update(upd, true);
  if r->'resposta'->>'texto' not like 'Suas tarefas abertas:%' or jsonb_array_length(r->'resposta'->'botoes') < 1 then raise exception 'FALHA T2: quadro %', r; end if;
  if (select apagar_ate from rt.mensagem where id = (r->>'mensagem')::bigint) > now() + interval '48 hours' then raise exception 'FALHA T2: autodestruição acima de 48 horas'; end if;

  -- T3. Botão concluir: o cartão vai a feito e o motor segue
  select * into c from rt.cartao where instancia = i and coluna = 'a_fazer' order by id limit 1;
  select telegram_id into tgg from rt_chave.identidade where pseudonimo = c.dono;
  upd := jsonb_build_object('update_id', 3, 'callback_query', jsonb_build_object('id', 'cb1', 'from', jsonb_build_object('id', tgg), 'data', 'c:' || c.id,
                            'message', jsonb_build_object('message_id', 12, 'chat', jsonb_build_object('id', tgg, 'type', 'private'))));
  r := rt.receber_update(upd, true);
  if (select coluna from rt.cartao where id = c.id) <> 'feito' or r->>'callback_id' <> 'cb1' then raise exception 'FALHA T3: concluir pelo botão %', r; end if;

  -- T4. Decisão pelo Telegram: mostra as opções e decide
  for k in 1..30 loop
    select * into c from rt.cartao where instancia = i and coluna <> 'feito' order by id limit 1;
    exit when c.id is null or c.coluna = 'decidir';
    perform rt.concluir_cartao(c.id, c.dono);
  end loop;
  if c.coluna is distinct from 'decidir' then raise exception 'FALHA T4: não chegou a uma decisão'; end if;
  begin
    r := rt.interpretar(c.dono, 'v: ' || c.id);
    if jsonb_array_length(r->'botoes') < 2 then raise exception 'FALHA T4: opções'; end if;
    r := rt.interpretar(c.dono, 'd: ' || c.id || ':0');
    if (select coluna from rt.cartao where id = c.id) <> 'feito' then raise exception 'FALHA T4: decisão %', r; end if;
  end;

  -- T5. Texto livre acha a jornada que já existe e inicia pelo botão
  r := rt.interpretar(p1, 'registrar a versão e a data de vigência da declaração');
  if r->'botoes'->0->0->>'callback_data' <> 'i:ID-01' then raise exception 'FALHA T5: sugestão %', r; end if;
  n := (select count(*) from rt.instancia);
  r := rt.interpretar(p1, 'i: ID-01');
  if (select count(*) from rt.instancia) <> n + 1 then raise exception 'FALHA T5: não iniciou %', r; end if;

  -- T6. Avulsa pela conversa, com o prazo do texto
  r := rt.interpretar(p1, 'Comprar café para a oficina até 10/10');
  r := rt.interpretar(p1, 'n: ');
  select * into c from rt.cartao where dono = p1 and tipo = 'avulsa' and origem = 'telegram' order by id desc limit 1;
  if c.id is null or to_char(c.prazo at time zone 'America/Fortaleza', 'DD/MM HH24') <> '10/10 18' or c.titulo like '%até%' then raise exception 'FALHA T6: avulsa %', r; end if;

  -- T7. Segredo não fica: a mensagem é gravada como apagada e vai para a fila de apagar já
  upd := jsonb_build_object('update_id', 7, 'message', jsonb_build_object('message_id', 17, 'from', jsonb_build_object('id', tg1), 'chat', jsonb_build_object('id', tg1, 'type', 'private'), 'text', 'senha: 123456'));
  r := rt.receber_update(upd, true);
  if (select conteudo from rt.mensagem where id = (r->>'mensagem')::bigint) like '%123456%'
     or not exists (select 1 from rt.v_a_apagar where id = (r->>'mensagem')::bigint) then raise exception 'FALHA T7: segredo guardado'; end if;

  -- T8. Aprovação de pagamento não se confirma pelo Telegram
  i := rt.iniciar_jornada('GE-05', lider8, true, 0.2);
  for k in 1..40 loop
    select * into c from rt.cartao where instancia = i and coluna not in ('feito') order by id limit 1;
    exit when c.id is null or exists (select 1 from org.tarefa x where x.id = c.tarefa and x.nome ~* '^(aprovar|autorizar)');
    if c.coluna = 'decidir' then perform rt.decidir_cartao(c.id, c.dono, c.opcoes->0->>'para'); else perform rt.concluir_cartao(c.id, c.dono); end if;
  end loop;
  if c.id is null then raise exception 'FALHA T8: não chegou à aprovação'; end if;
  r := rt.interpretar(c.dono, '/concluir ' || c.id);
  if r->>'texto' not like 'Aprovação de pagamento se confirma fora do Telegram%' or (select coluna from rt.cartao where id = c.id) = 'feito' then raise exception 'FALHA T8: aprovou pelo Telegram'; end if;

  -- T9. Fila: uma por segundo por chat, na ordem
  delete from rt.fila_envio where estado = 'pendente';
  insert into rt.fila_envio (chat_ref, texto, simulado) values ('tg:777', 'um', true), ('tg:777', 'dois', true), ('tg:888', 'outro chat', true);
  select count(*) into n from rt.proximos_envios(20);
  if n <> 2 then raise exception 'FALHA T9: saíram % (esperado 2: uma por chat)', n; end if;
  if exists (select 1 from rt.fila_envio where texto = 'dois' and estado <> 'pendente') then raise exception 'FALHA T9: passou na frente'; end if;

  -- T10. Grupo: no máximo 20 por minuto
  insert into rt.fila_envio (chat_ref, texto, estado, enviado_em, simulado) select 'tg:-100', 'x' || g, 'enviado', now() - interval '30 seconds', true from generate_series(1, 20) g;
  insert into rt.fila_envio (chat_ref, texto, simulado) values ('tg:-100', 'vigésima primeira', true);
  if exists (select 1 from rt.proximos_envios(20) p where p.chat_ref = 'tg:-100') then raise exception 'FALHA T10: passou de 20 por minuto no grupo'; end if;

  -- T11. Confirmação grava a saída com autodestruição; mensagem apagada sai da fila de apagar
  select * into f from rt.fila_envio where texto = 'um';
  perform rt.confirmar_envio(f.id, true, '555');
  select id into v_id from rt.mensagem where chat_ref = 'tg:777' and direcao = 'saida' and mensagem_ref = '555';
  if v_id is null then raise exception 'FALHA T11: saída não gravada'; end if;
  update rt.mensagem set apagar_ate = now() - interval '1 minute' where id = v_id;
  perform rt.marcar_apagada(v_id);
  if exists (select 1 from rt.v_a_apagar where id = v_id) then raise exception 'FALHA T11: apagada continuou na fila'; end if;

  -- T12. Grupo sem motor é recusado; simulado e real não se misturam
  upd := jsonb_build_object('update_id', 12, 'message', jsonb_build_object('message_id', 20, 'from', jsonb_build_object('id', tg1), 'chat', jsonb_build_object('id', -55, 'type', 'group'), 'text', '/quadro'));
  r := rt.receber_update(upd, true);
  if (select texto from rt.fila_envio where id = (r->>'fila')::bigint) not like 'Este grupo ainda não está ligado%' then raise exception 'FALHA T12: grupo sem motor'; end if;
  ok := false; begin perform rt.receber_update(jsonb_set(upd, '{message,chat}', jsonb_build_object('id', tg1, 'type', 'private')), false); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA T12: misturou simulado e real'; end if;

  return 'TELEGRAM: 12 testes, 0 falhas';
end $$;
revoke all on function rt._testar_telegram() from public;
commit;
