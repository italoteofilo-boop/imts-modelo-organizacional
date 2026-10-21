-- Testes da 089 (vínculo do Telegram da equipe pela Mesa). Não vai para produção: o perfil de produção apaga as funções _testar.
-- Rodar: select rt._testar_telegram_vinculo_equipe();   (devolve 'telegram vínculo da equipe: N de N ok' ou levanta 'FALHA ...')
-- Também redefine adm.testar_tudo(): a lista da 088 mais esta suíte (29 suítes).
-- As pessoas de teste nascem aqui; no fim, códigos, logins e Telegram de teste saem.
begin;
create or replace function rt._testar_telegram_vinculo_equipe() returns text language plpgsql set search_path = '' as $$
declare
  r jsonb := '[]'; pa uuid := gen_random_uuid(); pb uuid := gen_random_uuid(); ps uuid := gen_random_uuid();
  ua uuid := gen_random_uuid(); ub uuid := gen_random_uuid(); us uuid := gen_random_uuid();
  tga bigint := 860000000 + (random() * 9000000)::bigint; tgb bigint; tgc bigint; tgx bigint; tgext bigint;
  x jsonb; y jsonb; ok boolean; cod text; cod2 text; v_upd bigint := -(floor(random() * 1e12)::bigint + 1); n int; h0 bigint; msg text;
begin
  tgb := tga + 1; tgc := tga + 2; tgx := tga + 3;
  select coalesce(max(id), 0) into h0 from adm.historico;

  -- V0. parâmetros, objeto do histórico, porta única
  r := r || jsonb_build_object('teste', 'V0 parâmetros do vínculo', 'ok',
        (select count(*) from adm.parametro where chave in ('telegram.vinculo_codigo_minutos', 'telegram.vinculo_codigos_hora', 'telegram.vinculo_termo')) = 3);
  r := r || jsonb_build_object('teste', 'V0 funções na porta única, só para a equipe', 'ok',
        (select count(*) from adm.api_funcao where nome in ('rt.tg_vinculo', 'rt.tg_codigo_gerar', 'rt.tg_desvincular') and quem = 'interno') = 3);
  r := r || jsonb_build_object('teste', 'V0 sem login não chama; bot e vínculo só pelo serviço', 'ok',
        not has_function_privilege('anon', 'rt.tg_codigo_gerar(boolean)', 'execute')
        and not has_function_privilege('anon', 'rt.tg_desvincular()', 'execute')
        and not has_function_privilege('authenticated', 'rt._tg_vincular_equipe(bigint, text, text, text, boolean)', 'execute')
        and not has_function_privilege('authenticated', 'rt.receber_update(jsonb, boolean)', 'execute')
        and has_function_privilege('service_role', 'rt.receber_update(jsonb, boolean)', 'execute')
        and not has_table_privilege('authenticated', 'rt_chave.tg_codigo', 'select'));

  -- pessoas de teste: A e B reais, com login e sem Telegram; S simulada, com login
  insert into rt_chave.identidade (pseudonimo, nome, telegram_id, consentimento_art33_em, simulado) values
    (pa, 'Teste Vínculo A', null, null, false), (pb, 'Teste Vínculo B', null, null, false), (ps, 'Teste Vínculo S', null, null, true);
  insert into rt.pessoa values (pa, 'Operações · pessoa', 6, false), (pb, 'Operações · pessoa', 6, false), (ps, 'Operações · pessoa', 6, true);
  insert into rt.acesso (pessoa, circulo, papel, nivel, motivo) values (pa, 6, 'Operações · pessoa', 'operar', 'teste'), (pb, 6, 'Operações · pessoa', 'operar', 'teste');
  insert into rt_chave.login (auth_uid, pseudonimo) values (ua, pa), (ub, pb), (us, ps);

  -- V1 a V2: como a pessoa A, pela porta única com o papel authenticated (o que a Mesa faz)
  perform set_config('request.jwt.claims', jsonb_build_object('sub', ua, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', ua::text, true);
  begin
    set local role authenticated;
    x := public.imts('rt.tg_vinculo', '{}');
    r := r || jsonb_build_object('teste', 'V1 estado: desligado, com o termo e os limites', 'ok',
          not (x->>'ligado')::boolean and x->'codigo_aberto' = 'null'::jsonb and length(x->>'termo') > 50 and (x->>'validade_minutos')::int > 0 and (x->>'restantes_hora')::int = (x->>'limite_hora')::int);
    ok := false; begin perform public.imts('rt.tg_codigo_gerar', '{"p_aceite": false}'); exception when others then ok := sqlerrm like '%aceite o termo%'; end;
    r := r || jsonb_build_object('teste', 'V1 sem aceite do termo, sem código', 'ok', ok);
    ok := false; begin perform public.imts('rt.tg_codigo_gerar', jsonb_build_object('p_aceite', true, 'p_como', pb)); exception when others then ok := true; end;
    r := r || jsonb_build_object('teste', 'V1 a Mesa não gera código como outra pessoa', 'ok', ok);
    x := public.imts('rt.tg_codigo_gerar', '{"p_aceite": true}');
    cod := x->>'codigo';
    r := r || jsonb_build_object('teste', 'V2 código curto com a instrução do bot', 'ok',
          cod ~ '^[0-9A-F]{8}$' and x->>'comando' = '/vincular ' || cod and x->>'instrucao' like '%conversa privada%' and (x->>'expira')::timestamptz > now());
    y := public.imts('rt.tg_vinculo', '{}');
    r := r || jsonb_build_object('teste', 'V2 estado mostra o código em aberto, sem o código', 'ok',
          y->'codigo_aberto' ? 'expira' and position(cod in y::text) = 0 and (y->>'restantes_hora')::int = (y->>'limite_hora')::int - 1);
    reset role;
  exception when others then
    reset role; perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true); raise;
  end;
  r := r || jsonb_build_object('teste', 'V2 só o hash fica guardado, com o aceite', 'ok',
        exists (select 1 from rt_chave.tg_codigo where pessoa = pa and codigo_hash = encode(extensions.digest(cod, 'sha256'), 'hex')
                and consentimento_em is not null and consentimento_texto like '%art. 33, VIII%' and not simulado)
        and not exists (select 1 from rt_chave.tg_codigo k where pessoa = pa and to_jsonb(k)::text like '%' || cod || '%'));
  r := r || jsonb_build_object('teste', 'V2 auditoria do código, sem o código', 'ok',
        exists (select 1 from adm.historico where id > h0 and objeto = 'telegram' and chave = pa::text and depois->>'evento' = 'codigo_gerado' and como = 'mesa (web)')
        and not exists (select 1 from adm.historico h where id > h0 and objeto = 'telegram' and to_jsonb(h)::text like '%' || cod || '%'));

  -- V3. código enviado em grupo: recusa e cancela; depois, nem na conversa privada vale
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 1, 'text', '/vincular ' || cod,
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', -100123, 'type', 'supergroup'))), false);
  r := r || jsonb_build_object('teste', 'V3 grupo: recusado e código cancelado', 'ok',
        (x->>'vinculo_equipe')::boolean and not (x->>'vinculou')::boolean
        and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like '%conversa privada%cancelado%'
        and (select telegram_id from rt_chave.identidade where pseudonimo = pa) is null);
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 2, 'text', '/vincular ' || cod,
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V3 código cancelado não liga depois', 'ok',
        not (x->>'vinculou')::boolean and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like 'Este código foi cancelado%'
        and (select telegram_id from rt_chave.identidade where pseudonimo = pa) is null);

  -- V4. código novo, conversa privada (com @nome do bot e minúsculas): liga, com consentimento; repetir o update é ignorado
  perform set_config('request.jwt.claim.sub', ua::text, true);
  cod := rt.tg_codigo_gerar(true)->>'codigo';
  r := r || jsonb_build_object('teste', 'V4 código novo cancela o anterior em aberto', 'ok',
        (select count(*) from rt_chave.tg_codigo where pessoa = pa and usado_em is null and invalidado_em is null) = 1);
  x := rt.receber_update(jsonb_build_object('update_id', v_upd, 'message', jsonb_build_object('message_id', 3, 'text', '/vincular@ImtsOsBot ' || lower(cod),
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V4 pessoa da equipe liga o Telegram pelo código', 'ok',
        (x->>'vinculou')::boolean and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like 'Pronto, Teste Vínculo A.%'
        and (select telegram_id = tga and consentimento_art33_em is not null from rt_chave.identidade where pseudonimo = pa)
        and (select usado_em is not null from rt_chave.tg_codigo where codigo_hash = encode(extensions.digest(cod, 'sha256'), 'hex')));
  x := rt.receber_update(jsonb_build_object('update_id', v_upd, 'message', jsonb_build_object('message_id', 3, 'text', '/vincular ' || cod,
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V4 atualização repetida é ignorada', 'ok', x->>'ignorado' = 'atualização repetida');
  r := r || jsonb_build_object('teste', 'V4 auditoria do vínculo', 'ok',
        exists (select 1 from adm.historico where id > h0 and objeto = 'telegram' and chave = pa::text and depois->>'evento' = 'vinculado' and como = 'bot do Telegram')
        and not exists (select 1 from adm.historico h where id > h0 and objeto = 'telegram' and to_jsonb(h)::text like '%' || tga::text || '%'));
  y := rt.tg_vinculo();
  r := r || jsonb_build_object('teste', 'V4 estado: ligado pela Mesa, sem o número do Telegram', 'ok',
        (y->>'ligado')::boolean and y->>'origem' = 'mesa' and y->>'desde' is not null and position(tga::text in y::text) = 0);
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 4, 'text', '/vincular ' || cod,
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V4 código usado não vale de novo', 'ok',
        not (x->>'vinculou')::boolean and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like 'Este código já foi usado%');
  ok := false; begin perform rt.tg_codigo_gerar(true); exception when others then ok := sqlerrm like '%já está ligado%'; end;
  r := r || jsonb_build_object('teste', 'V4 ligado: não gera código sem desligar antes', 'ok', ok);
  -- depois de ligado, o bot atende como pessoa da equipe
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 5, 'text', '/quadro',
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V4 ligado: o bot reconhece a pessoa (/quadro)', 'ok',
        (x->>'pessoa')::uuid = pa and exists (select 1 from rt.rota_chat where chat_ref = 'tg:' || tga));

  -- V5. código vencido
  perform set_config('request.jwt.claim.sub', ub::text, true);
  cod2 := rt.tg_codigo_gerar(true)->>'codigo';
  update rt_chave.tg_codigo set criado_em = now() - interval '2 hours', expira_em = now() - interval '1 minute' where codigo_hash = encode(extensions.digest(cod2, 'sha256'), 'hex');
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 6, 'text', '/vincular ' || cod2,
        'from', jsonb_build_object('id', tgb), 'chat', jsonb_build_object('id', tgb, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V5 código vencido é recusado', 'ok',
        not (x->>'vinculou')::boolean and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like 'Código vencido%'
        and (select telegram_id from rt_chave.identidade where pseudonimo = pb) is null);

  -- V6. código de B mandado de um Telegram que já é de A
  cod2 := rt.tg_codigo_gerar(true)->>'codigo';
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 7, 'text', '/vincular ' || cod2,
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V6 Telegram de outra pessoa da equipe é recusado', 'ok',
        not (x->>'vinculou')::boolean and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like '%outra pessoa da equipe%'
        and (select telegram_id from rt_chave.identidade where pseudonimo = pa) = tga and (select telegram_id from rt_chave.identidade where pseudonimo = pb) is null);

  -- V7. B ganhou outro Telegram pelo cadastro (GE-07) depois de gerar o código: precisa desligar antes
  update rt_chave.identidade set telegram_id = tgx, consentimento_art33_em = now() where pseudonimo = pb;
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 8, 'text', '/vincular ' || cod2,
        'from', jsonb_build_object('id', tgb), 'chat', jsonb_build_object('id', tgb, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V7 pessoa já ligada a outro Telegram: exige desligar antes', 'ok',
        not (x->>'vinculou')::boolean and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like '%já está ligado a outro Telegram%desligue%'
        and (select telegram_id from rt_chave.identidade where pseudonimo = pb) = tgx);
  y := rt.tg_vinculo();
  r := r || jsonb_build_object('teste', 'V7 estado: ligado pelo cadastro', 'ok', (y->>'ligado')::boolean and y->>'origem' = 'cadastro');

  -- V8. desligar pela própria pessoa: tira o vínculo, revoga o consentimento, cancela o código, avisa o Telegram e audita
  x := rt.tg_desvincular();
  r := r || jsonb_build_object('teste', 'V8 desligar pela Mesa', 'ok',
        not (x->>'ligado')::boolean and (select telegram_id is null and consentimento_art33_em is null from rt_chave.identidade where pseudonimo = pb)
        and not exists (select 1 from rt_chave.tg_codigo where pessoa = pb and usado_em is null and invalidado_em is null)
        and exists (select 1 from rt.fila_envio where chat_ref = 'tg:' || tgx and texto like 'Este Telegram foi desligado%')
        and exists (select 1 from adm.historico where id > h0 and objeto = 'telegram' and chave = pb::text and depois->>'evento' = 'desvinculado' and por = pb));
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 9, 'text', '/vincular ' || cod2,
        'from', jsonb_build_object('id', tgb), 'chat', jsonb_build_object('id', tgb, 'type', 'private'))), false);
  r := r || jsonb_build_object('teste', 'V8 código de antes do desligamento não vale', 'ok',
        not (x->>'vinculou')::boolean and (select telegram_id from rt_chave.identidade where pseudonimo = pb) is null);
  r := r || jsonb_build_object('teste', 'V8 desligar de novo não falha', 'ok', rt.tg_desvincular()->>'texto' like '%já estava desligado%');

  -- V9. limite de códigos por hora
  n := 0; ok := false;
  for i in 1..40 loop
    begin perform rt.tg_codigo_gerar(true); n := n + 1;
    exception when others then ok := sqlerrm like 'limite de % códigos por hora%'; exit; end;
  end loop;
  r := r || jsonb_build_object('teste', 'V9 limite de códigos por hora', 'ok', ok
        and (select count(*) from rt_chave.tg_codigo where pessoa = pb and criado_em > now() - interval '1 hour') = (adm.valor('telegram.vinculo_codigos_hora', '5') #>> '{}')::int
        and (rt.tg_vinculo()->>'restantes_hora')::int = 0);

  -- V10. A desliga: o bot volta a tratar como desconhecido, com o caminho da Mesa no texto
  perform set_config('request.jwt.claim.sub', ua::text, true);
  perform rt.tg_desvincular();
  r := r || jsonb_build_object('teste', 'V10 desligar apaga a rota da conversa privada', 'ok', not exists (select 1 from rt.rota_chat where chat_ref = 'tg:' || tga));
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 10, 'text', 'oi',
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  msg := (select texto from rt.fila_envio where id = (x->>'fila')::bigint);
  r := r || jsonb_build_object('teste', 'V10 sem vínculo: a resposta ensina o caminho da Mesa e mantém a GE-07', 'ok',
        x->>'pessoa' is null and msg like '%Ligar o Telegram%' and msg like '%GE-07%' and msg like '%portal%');
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 11, 'text', '/vincular 0000ZZZZ',
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 12, 'text', '/vincular 0BADC0DE',
        'from', jsonb_build_object('id', tga), 'chat', jsonb_build_object('id', tga, 'type', 'private'))), false);
  msg := (select texto from rt.fila_envio where id = (x->>'fila')::bigint);
  r := r || jsonb_build_object('teste', 'V10 código desconhecido segue para o portal e cita a Mesa', 'ok',
        msg like 'Código inválido ou vencido.%Mesa%portal%');
  perform set_config('request.jwt.claim.sub', '', true); perform set_config('request.jwt.claims', '', true);

  -- V11. simulado e real não se misturam; Telegram ligado ao portal de fora é recusado
  perform set_config('request.jwt.claim.sub', us::text, true);
  cod := rt.tg_codigo_gerar(true)->>'codigo';
  perform set_config('request.jwt.claim.sub', '', true);
  ok := false;
  begin perform rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 13, 'text', '/vincular ' || cod,
        'from', jsonb_build_object('id', tgc), 'chat', jsonb_build_object('id', tgc, 'type', 'private'))), false);
  exception when others then ok := sqlerrm like '%mistura de simulado e real%'; end;
  r := r || jsonb_build_object('teste', 'V11 código simulado no bot real é recusado', 'ok', ok);
  select telegram_id into tgext from ext.telegram where vinculado_em is not null and simulado and telegram_id is not null limit 1;
  if tgext is not null then
    x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 14, 'text', '/vincular ' || cod,
          'from', jsonb_build_object('id', tgext), 'chat', jsonb_build_object('id', tgext, 'type', 'private'))), true);
    r := r || jsonb_build_object('teste', 'V11 Telegram ligado ao portal de fora é recusado', 'ok',
          not (x->>'vinculou')::boolean and (select texto from rt.fila_envio where id = (x->>'fila')::bigint) like '%portal de parceiro ou cliente%'
          and (select telegram_id from rt_chave.identidade where pseudonimo = ps) is null);
  end if;
  x := rt.receber_update(jsonb_build_object('message', jsonb_build_object('message_id', 15, 'text', '/vincular ' || cod,
        'from', jsonb_build_object('id', tgc), 'chat', jsonb_build_object('id', tgc, 'type', 'private'))), true);
  r := r || jsonb_build_object('teste', 'V11 pessoa simulada liga no bot de teste', 'ok',
        (x->>'vinculou')::boolean and (select telegram_id from rt_chave.identidade where pseudonimo = ps) = tgc);

  -- limpeza (o histórico é só de acréscimo e fica)
  delete from rt.rota_chat where chat_ref in ('tg:' || tga, 'tg:' || tgb, 'tg:' || tgc);
  delete from rt_chave.tg_codigo where pessoa in (pa, pb, ps);
  delete from rt_chave.login where pseudonimo in (pa, pb, ps);
  update rt_chave.identidade set telegram_id = null, consentimento_art33_em = null where pseudonimo in (pa, pb, ps);

  if exists (select 1 from jsonb_array_elements(r) t where not (t->>'ok')::boolean) then
    raise exception 'FALHA telegram vínculo da equipe: %', (select string_agg(t->>'teste', '; ') from jsonb_array_elements(r) t where not (t->>'ok')::boolean); end if;
  return 'telegram vínculo da equipe: ' || jsonb_array_length(r) || ' de ' || jsonb_array_length(r) || ' ok';
end $$;
revoke all on function rt._testar_telegram_vinculo_equipe() from public, anon, authenticated;

-- Rodada completa: a lista da 088 e, no fim, a suíte da 089
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido', 'adm._testar_servidor', 'doc._testar_nota_debito', 'adm._testar_integracoes',
                           'rt._testar_papeis_acumulados', 'doc._testar_assinatura',
                           'rt._testar_automacao_r', 'doc._testar_assinatura_avisos', 'rt._testar_telegram_miniapp', 'doc._testar_docs_google', 'rt._testar_agentes_ia',
                           'rt._testar_telegram_vinculo_equipe'] loop
    begin
      execute format('select %s()', s) into msg;
      raise exception using errcode = 'P0099', message = msg;
    exception when sqlstate 'P0099' then res := res || jsonb_build_object(s, jsonb_build_object('ok', true, 'resultado', sqlerrm));
              when others then res := res || jsonb_build_object(s, jsonb_build_object('ok', false, 'resultado', sqlerrm));
    end;
  end loop;
  return jsonb_build_object('todas_ok', not exists (select 1 from jsonb_each(res) e where not (e.value->>'ok')::boolean), 'suites', res);
end $f$;
revoke all on function adm.testar_tudo() from public, anon, authenticated;
commit;
