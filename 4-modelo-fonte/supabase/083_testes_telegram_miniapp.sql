-- Testes da 082 (Mini App do Telegram). Não vai para produção: o perfil de produção apaga as funções _testar.
-- Rodar: select rt._testar_telegram_miniapp();   (devolve 'telegram mini app: N de N ok' ou levanta 'FALHA ...')
-- As pessoas de teste nascem e saem aqui; nada de dado real é usado.
begin;
create or replace function rt._testar_telegram_miniapp() returns text language plpgsql set search_path = '' as $$
declare
  r jsonb := '[]'; pa uuid := gen_random_uuid(); pb uuid := gen_random_uuid(); ua uuid := gen_random_uuid(); ub uuid := gen_random_uuid();
  tga bigint := 880000000 + (random() * 9000000)::bigint; tgb bigint; ps uuid; tgs bigint;
  x jsonb; ok boolean; c1 bigint; c2 bigint; c3 bigint; c4 bigint; c5 bigint; url_antes jsonb; v_chave text := 'tg:' || md5(random()::text);
begin
  tgb := tga + 1;
  -- M0. parâmetros e registro
  r := r || jsonb_build_object('teste', 'M0 parâmetros do Mini App', 'ok',
        (select count(*) from adm.parametro where chave in ('telegram_app.url', 'telegram_app.validade_segundos', 'telegram_app.tentativas_max', 'telegram_app.janela_minutos', 'telegram_app.pedidos_minuto')) = 5);
  insert into adm.registro_servidor (funcao, acao, alvo, ok, detalhe) values ('telegram_app', 'mesa', v_chave, true, 'teste');
  r := r || jsonb_build_object('teste', 'M0 registro aceita telegram_app', 'ok', true);

  -- pessoas de teste: A (com Telegram e login) e B (com login, sem Telegram)
  insert into rt_chave.identidade (pseudonimo, nome, telegram_id, consentimento_art33_em, simulado) values
    (pa, 'Teste Mini App A', tga, now(), false), (pb, 'Teste Mini App B', null, null, false);
  insert into rt.pessoa values (pa, 'Operações · pessoa', 6, false), (pb, 'Operações · pessoa', 6, false);
  insert into rt.acesso (pessoa, circulo, papel, nivel, motivo) values (pa, 6, 'Operações · pessoa', 'operar', 'teste'), (pb, 6, 'Operações · pessoa', 'operar', 'teste');
  insert into rt_chave.login (auth_uid, pseudonimo) values (ua, pa), (ub, pb);

  -- M1. identificação (só pelo serviço)
  x := rt.tg_app_identificar(tga, false);
  r := r || jsonb_build_object('teste', 'M1 Telegram ligado: pessoa e login', 'ok', x->>'situacao' = 'ok' and (x->>'auth_uid')::uuid = ua and (x->>'pessoa')::uuid = pa);
  r := r || jsonb_build_object('teste', 'M1 Telegram sem vínculo', 'ok', rt.tg_app_identificar(tgb + 1000, false)->>'situacao' = 'sem_vinculo');
  update rt_chave.identidade set telegram_id = tgb, consentimento_art33_em = now() where pseudonimo = pb;
  delete from rt_chave.login where pseudonimo = pb;
  r := r || jsonb_build_object('teste', 'M1 pessoa sem login', 'ok', rt.tg_app_identificar(tgb, false)->>'situacao' = 'sem_login');
  insert into rt_chave.login (auth_uid, pseudonimo) values (ub, pb);
  r := r || jsonb_build_object('teste', 'M1 real e simulado não se misturam', 'ok', rt.tg_app_identificar(tga, true)->>'situacao' = 'simulado');
  select i.pseudonimo, i.telegram_id into ps, tgs from rt_chave.identidade i join rt.pessoa p using (pseudonimo) where i.simulado and i.telegram_id is not null limit 1;
  if ps is not null then
    r := r || jsonb_build_object('teste', 'M1 pessoa simulada no Telegram real', 'ok', rt.tg_app_identificar(tgs, false)->>'situacao' = 'simulado');
  end if;

  -- cartões: avulsas de A, uma de B, uma de B delegada a A, uma de B delegada a A para recusar e uma de pagamento de A
  c1 := rt.criar_avulsa(pa, 'Teste Mini App concluir', now() + interval '1 day', null, 'telegram');
  c2 := rt.criar_avulsa(pb, 'Teste Mini App alheia', now() + interval '1 day', null, 'telegram');
  c3 := rt.criar_avulsa(pb, 'Teste Mini App pedido para A', now() + interval '1 day', null, 'telegram');
  perform rt.delegar_cartao(c3, pb, pa, false, null);
  c4 := rt.criar_avulsa(pb, 'Teste Mini App pedido para recusar', now() + interval '1 day', null, 'telegram');
  perform rt.delegar_cartao(c4, pb, pa, false, null);
  c5 := rt.criar_avulsa(pa, 'Teste Mini App aprovar pagamento', now() + interval '1 day', null, 'telegram');
  update rt.cartao set jornada = 'GE-04', tarefa = (select t.id from org.tarefa t join org.etapa e on e.id = t.etapa where e.jornada = 'GE-04' and t.nome ~* '^aprovar' order by t.id limit 1) where id = c5;

  -- M2 a M6: como a pessoa A, com o papel authenticated (o que a função do servidor faz)
  perform set_config('request.jwt.claims', jsonb_build_object('sub', ua, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', ua::text, true);
  begin
    set local role authenticated;
    x := public.imts('rt.tg_mesa', '{}');
    r := r || jsonb_build_object('teste', 'M2 Mesa traz as abertas da pessoa', 'ok', x->>'nome' = 'Teste Mini App A'
          and exists (select 1 from jsonb_array_elements(x->'cartoes') k where (k->>'id')::bigint = c1)
          and not exists (select 1 from jsonb_array_elements(x->'cartoes') k where (k->>'id')::bigint = c2));
    r := r || jsonb_build_object('teste', 'M2 pedido para aceitar vem primeiro e marcado', 'ok', ((x->'cartoes'->0->>'para_aceitar')::boolean)
          and exists (select 1 from jsonb_array_elements(x->'cartoes') k where (k->>'id')::bigint = c3 and (k->>'para_aceitar')::boolean));
    r := r || jsonb_build_object('teste', 'M2 sem ids internos (pseudônimo, dono, tarefa, destino da opção)', 'ok',
          position(pa::text in x::text) = 0 and position(ua::text in x::text) = 0 and not (x::text ~ '"(dono|delegado_pessoa|tarefa|para|instancia)"'));
    r := r || jsonb_build_object('teste', 'M2 pagamento marcado como só na web', 'ok',
          exists (select 1 from jsonb_array_elements(x->'cartoes') k where (k->>'id')::bigint = c5 and (k->>'so_na_web')::boolean));

    x := public.imts('rt.tg_agir', jsonb_build_object('p_acao', 'concluir', 'p_cartao', c1));
    r := r || jsonb_build_object('teste', 'M3 concluir a própria avulsa', 'ok', x->>'texto' like 'Feito: #' || c1 || '%');
    ok := false; begin perform public.imts('rt.tg_agir', jsonb_build_object('p_acao', 'concluir', 'p_cartao', c2)); exception when others then ok := true; end;
    r := r || jsonb_build_object('teste', 'M3 concluir cartão alheio é recusado pelo banco', 'ok', ok);
    x := public.imts('rt.tg_agir', jsonb_build_object('p_acao', 'aceitar', 'p_cartao', c3));
    r := r || jsonb_build_object('teste', 'M4 aceitar o pedido', 'ok', x->>'texto' like 'Aceito: #' || c3 || '%');
    x := public.imts('rt.tg_agir', jsonb_build_object('p_acao', 'recusar', 'p_cartao', c4));
    r := r || jsonb_build_object('teste', 'M4 recusar o pedido', 'ok', x->>'texto' like 'Recusado: #' || c4 || '%');
    ok := false; begin perform public.imts('rt.tg_agir', jsonb_build_object('p_acao', 'concluir', 'p_cartao', c5)); exception when others then ok := sqlerrm like '%fora do Telegram%'; end;
    r := r || jsonb_build_object('teste', 'M5 aprovação de pagamento fica fora do Telegram', 'ok', ok);
    ok := false; begin perform public.imts('rt.tg_agir', jsonb_build_object('p_acao', 'decidir', 'p_cartao', c1, 'p_opcao', 0)); exception when others then ok := sqlerrm like '%opção inválida%'; end;
    r := r || jsonb_build_object('teste', 'M5 decidir o que não é decisão é recusado', 'ok', ok);
    ok := false; begin perform rt.tg_app_identificar(tga, false); exception when others then ok := true; end;
    r := r || jsonb_build_object('teste', 'M6 identificar só pela chave de serviço', 'ok', ok);
    ok := false; begin perform adm.tg_app_limite(v_chave); exception when others then ok := true; end;
    r := r || jsonb_build_object('teste', 'M6 limite só pela chave de serviço', 'ok', ok);
    reset role;
  exception when others then
    reset role; perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true); raise;
  end;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  r := r || jsonb_build_object('teste', 'M4 delegação aceita e recusada no banco', 'ok',
        (select aceite from rt.cartao where id = c3) = 'aceita' and (select aceite from rt.cartao where id = c4) = 'recusada'
        and (select coluna from rt.cartao where id = c1) = 'feito' and (select coluna from rt.cartao where id = c2) <> 'feito');
  r := r || jsonb_build_object('teste', 'M6 quem não tem login não chama', 'ok',
        not has_function_privilege('anon', 'rt.tg_mesa()', 'execute') and not has_function_privilege('authenticated', 'rt.tg_app_identificar(bigint, boolean)', 'execute'));

  -- M7. limite de tentativas
  r := r || jsonb_build_object('teste', 'M7 sem falhas, segue', 'ok', adm.tg_app_limite(v_chave) is null);
  insert into adm.registro_servidor (funcao, acao, alvo, ok, detalhe)
    select 'telegram_app', 'mesa', v_chave, false, 'teste' from generate_series(1, (adm.valor('telegram_app.tentativas_max', '10') #>> '{}')::int);
  r := r || jsonb_build_object('teste', 'M7 falhas demais bloqueiam', 'ok', adm.tg_app_limite(v_chave) like 'muitas tentativas%');
  ok := false; begin perform adm.tg_app_limite('qualquer coisa'); exception when others then ok := true; end;
  r := r || jsonb_build_object('teste', 'M7 chave de limite precisa ser hash', 'ok', ok);

  -- M8. bot: /mesa com o botão web_app, /quadro ganha o botão, /ajuda cita a Mesa; sem endereço, nada de botão
  x := rt.interpretar(pa, '/mesa');
  r := r || jsonb_build_object('teste', 'M8 /mesa abre o Mini App', 'ok', x->'botoes'->0->0->'web_app'->>'url' = rt._tg_app_url() and rt._tg_app_url() like 'https://%/tg.html');
  x := rt.interpretar(pa, '/quadro');
  r := r || jsonb_build_object('teste', 'M8 /quadro com o botão da Mesa no fim', 'ok', x->>'texto' like 'Suas tarefas abertas:%'
        and x->'botoes'->(jsonb_array_length(x->'botoes') - 1)->0->'web_app'->>'url' = rt._tg_app_url()
        and x->'botoes'->0->0 ? 'callback_data');
  r := r || jsonb_build_object('teste', 'M8 /ajuda cita a Mesa', 'ok', rt.interpretar(pa, '/ajuda')->>'texto' like '%/mesa%');
  select valor into url_antes from adm.parametro where chave = 'telegram_app.url';
  update adm.parametro set valor = '""' where chave = 'telegram_app.url';
  r := r || jsonb_build_object('teste', 'M8 sem endereço: /mesa explica e /quadro sem web_app', 'ok', rt.interpretar(pa, '/mesa')->>'texto' like '%ainda não está ligada%'
        and position('web_app' in rt.interpretar(pa, '/quadro')::text) = 0);
  update adm.parametro set valor = url_antes where chave = 'telegram_app.url';

  -- limpeza
  delete from adm.registro_servidor where alvo = v_chave;
  delete from rt_chave.login where pseudonimo in (pa, pb);
  update rt_chave.identidade set telegram_id = null, consentimento_art33_em = null where pseudonimo in (pa, pb);

  if exists (select 1 from jsonb_array_elements(r) t where not (t->>'ok')::boolean) then
    raise exception 'FALHA telegram mini app: %', (select string_agg(t->>'teste', '; ') from jsonb_array_elements(r) t where not (t->>'ok')::boolean); end if;
  return 'telegram mini app: ' || jsonb_array_length(r) || ' de ' || jsonb_array_length(r) || ' ok';
end $$;
revoke all on function rt._testar_telegram_miniapp() from public, anon, authenticated;
commit;
