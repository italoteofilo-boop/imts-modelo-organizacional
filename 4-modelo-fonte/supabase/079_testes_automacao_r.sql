-- Testes da 078 (automação real das tarefas R). Não vai para produção: o perfil de produção apaga as funções _testar.
-- Rodar:  begin; select rt._testar_automacao_r(); rollback;
-- Também ajusta a suíte do motor assistido (062): ela confere o cartão assistido de uma tarefa "Registrar ...", que agora a
-- automação conclui; a suíte passa a rodar com motor.automacao_r desligado e devolve o valor anterior no fim.
begin;

-- instância real ou simulada, interativa, com o token já na tarefa pedida; anda um passo só (o resto do fluxo não interfere)
create or replace function rt._testar_automacao_r_inst(p_tarefa bigint, p_simulado boolean) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_no rt.no; v_motor smallint; v_inst bigint;
begin
  select * into v_no from rt.no where tarefa = p_tarefa order by jornada, id limit 1;
  select circulo into v_motor from org.jornada where codigo = v_no.jornada;
  insert into rt.instancia (motor, jornada, simulado, inicio, relogio, versao_base, interativo)
  select v_motor, v_no.jornada, p_simulado, now(), now(), m.versao_base, true from rt.motor m where m.circulo = v_motor returning id into v_inst;
  insert into rt.token (instancia, no) values (v_inst, v_no.id);
  perform rt._avancar(v_inst, 1);
  return v_inst;
end $$;
revoke all on function rt._testar_automacao_r_inst(bigint, boolean) from public, anon, authenticated;

create or replace function rt._testar_automacao_r() returns text language plpgsql security definer set search_path = '' as $$
declare r jsonb := '[]'; ok boolean; inst bigint; x jsonb;
  t_reg record; t_avi record; t_hum record; t_age record; pess uuid[] := '{}'; p uuid; rh record;
  v_dest uuid; v_tg_antes bigint; v_cons_antes timestamptz; v_tg bigint;
  adm_id uuid; u_a uuid := gen_random_uuid(); u_o uuid := gen_random_uuid();
  v_assist jsonb := adm.valor('motor.maquina_assistida', 'false'); v_auto jsonb := adm.valor('motor.automacao_r', 'true');
  dom text := adm.valor('login.dominios', '["imts.email"]') ->> 0;
begin
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  update adm.parametro set valor = 'true' where chave in ('motor.maquina_assistida', 'motor.automacao_r');

  -- tarefas de prova (uma por caso), sempre com nó no fluxo
  select t.id, t.nome, t.raia, j.circulo as motor into t_reg from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada
   where t.executor = 'R' and rt._automacao_r_modo(t.nome) = 'registrar' and split_part(t.nome, ' ', 1) = 'Registrar' and exists (select 1 from rt.no n where n.tarefa = t.id) order by t.id limit 1;
  select t.id, t.nome, t.raia, j.circulo as motor into t_avi from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada
   where t.executor = 'R' and rt._automacao_r_modo(t.nome) = 'avisar' and split_part(t.nome, ' ', 1) = 'Avisar' and exists (select 1 from rt.no n where n.tarefa = t.id) order by t.id limit 1;
  select t.id, t.nome, t.raia, j.circulo as motor into t_hum from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada
   where t.executor = 'R' and rt._automacao_r_modo(t.nome) = 'humano' and split_part(t.nome, ' ', 1) = 'Publicar' and exists (select 1 from rt.no n where n.tarefa = t.id) order by t.id limit 1;
  select t.id, t.nome, t.raia, j.circulo as motor into t_age from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada
   where t.executor = 'A' and exists (select 1 from rt.no n where n.tarefa = t.id) order by t.id limit 1;
  if t_reg.id is null or t_avi.id is null or t_hum.id is null or t_age.id is null then raise exception 'FALHA automação R: modelo sem tarefa de prova'; end if;

  -- uma pessoa real de teste na raia humana de cada tarefa de prova (o cartão e o aviso precisam de dono)
  for rh in select distinct rt._raia_humana(x.raia) as papel, x.motor from (values (t_reg.raia, t_reg.motor), (t_avi.raia, t_avi.motor), (t_hum.raia, t_hum.motor), (t_age.raia, t_age.motor)) x(raia, motor) loop
    p := gen_random_uuid(); pess := pess || p;
    insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (p, 'Teste Automação R ' || cardinality(pess), 'automacao.r.' || cardinality(pess) || '.' || left(p::text, 8) || '@' || dom, false);
    insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (p, rh.papel, rh.motor, false);
  end loop;

  -- R1. regras carregadas: verbos da carga, verbo sem regra fica humano, tarefa composta com ação humana fica humana
  ok := (select count(*) from adm.automacao_r_regra where (verbo, modo) in (('Registrar', 'registrar'), ('Receber', 'registrar'), ('Arquivar', 'registrar'),
          ('Enviar', 'encaminhar'), ('Pedir', 'encaminhar'), ('Devolver', 'encaminhar'), ('Avisar', 'avisar'), ('Responder', 'avisar'),
          ('Publicar', 'humano'), ('Abrir', 'humano'), ('Reunir', 'humano'), ('Conferir', 'humano'), ('Calcular', 'humano'))) = 13
        and rt._automacao_r_modo('Registrar o pedido') = 'registrar'
        and rt._automacao_r_modo('Xyzabc qualquer coisa') = 'humano'
        and rt._automacao_r_modo('Registrar o pedido e conferir o orçamento') = 'humano'
        and rt._automacao_r_modo('Avisar círculos e executivos') = 'avisar';
  r := r || jsonb_build_object('teste', 'regras carregadas para os verbos', 'ok', ok);

  -- R2. Registrar em instância real assistida: concluída pela automação, sem cartão, e o token segue
  inst := rt._testar_automacao_r_inst(t_reg.id, false);
  r := r || jsonb_build_object('teste', 'Registrar conclui sem cartão', 'ok',
        not exists (select 1 from rt.cartao where instancia = inst)
        and exists (select 1 from rt.evento where instancia = inst and tarefa = t_reg.id and tipo = 'fim' and resultado = 'concluída pela automação: registrar' and executor = 'R')
        and not exists (select 1 from rt.token where instancia = inst and estado = 'aguardando')
        and not exists (select 1 from rt.evento where instancia = inst and resultado = 'concluída (simulado)'));

  -- R3. Avisar sem Telegram: concluída pela automação e aviso na Mesa da pessoa da raia, sem segurar o fluxo
  v_dest := coalesce(rt._pessoa(rt._raia_humana(t_avi.raia), t_avi.motor), rt._pessoa('Líder do círculo', t_avi.motor));
  select telegram_id, consentimento_art33_em into v_tg_antes, v_cons_antes from rt_chave.identidade where pseudonimo = v_dest;
  update rt_chave.identidade set telegram_id = null where pseudonimo = v_dest;
  inst := rt._testar_automacao_r_inst(t_avi.id, false);
  r := r || jsonb_build_object('teste', 'Avisar conclui e põe o aviso na Mesa', 'ok',
        v_dest is not null
        and not exists (select 1 from rt.cartao where instancia = inst and tipo = 'fluxo')
        and exists (select 1 from rt.evento where instancia = inst and tarefa = t_avi.id and tipo = 'fim' and resultado = 'concluída pela automação: avisar (aviso na Mesa)')
        and exists (select 1 from rt.cartao where instancia = inst and tipo = 'avulsa' and dono = v_dest and coluna = 'a_fazer' and titulo = left('Aviso: ' || t_avi.nome, 200))
        and not exists (select 1 from rt.token where instancia = inst and estado = 'aguardando'));
  update rt_chave.identidade set telegram_id = v_tg_antes where pseudonimo = v_dest;

  -- R4. Avisar com Telegram ligado: o aviso vai à fila do Telegram, sem cartão nenhum
  v_dest := coalesce(rt._pessoa(rt._raia_humana(t_avi.raia), t_avi.motor), rt._pessoa('Líder do círculo', t_avi.motor));
  select telegram_id, consentimento_art33_em into v_tg_antes, v_cons_antes from rt_chave.identidade where pseudonimo = v_dest;
  select coalesce(max(telegram_id), 0) + 1 into v_tg from rt_chave.identidade;
  update rt_chave.identidade set telegram_id = v_tg, consentimento_art33_em = coalesce(consentimento_art33_em, now()) where pseudonimo = v_dest;
  inst := rt._testar_automacao_r_inst(t_avi.id, false);
  r := r || jsonb_build_object('teste', 'Avisar com Telegram vai à fila de envio', 'ok',
        not exists (select 1 from rt.cartao where instancia = inst)
        and exists (select 1 from rt.evento where instancia = inst and tarefa = t_avi.id and resultado = 'concluída pela automação: avisar (aviso pelo Telegram)')
        and exists (select 1 from rt.fila_envio where chat_ref = 'tg:' || v_tg and pessoa = v_dest and estado = 'pendente' and not simulado and texto like '%' || t_avi.nome || '%'));
  update rt_chave.identidade set telegram_id = v_tg_antes, consentimento_art33_em = v_cons_antes where pseudonimo = v_dest;

  -- R5. verbo humano continua virando cartão assistido
  inst := rt._testar_automacao_r_inst(t_hum.id, false);
  r := r || jsonb_build_object('teste', 'verbo humano continua cartão', 'ok',
        exists (select 1 from rt.cartao where instancia = inst and tarefa = t_hum.id and tipo = 'fluxo' and titulo like '%(assistida:%')
        and exists (select 1 from rt.token where instancia = inst and estado = 'aguardando')
        and not exists (select 1 from rt.evento where instancia = inst and resultado like 'concluída pela automação%'));

  -- R6. parâmetro desligado: Registrar volta a ser cartão assistido
  update adm.parametro set valor = 'false' where chave = 'motor.automacao_r';
  inst := rt._testar_automacao_r_inst(t_reg.id, false);
  r := r || jsonb_build_object('teste', 'parâmetro desligado volta ao cartão', 'ok',
        exists (select 1 from rt.cartao where instancia = inst and tarefa = t_reg.id and titulo like '%(assistida:%')
        and not exists (select 1 from rt.evento where instancia = inst and resultado like 'concluída pela automação%'));
  update adm.parametro set valor = 'true' where chave = 'motor.automacao_r';

  -- R7. instância simulada não muda: o adaptador simulado conclui, sem automação e sem cartão
  inst := rt._testar_automacao_r_inst(t_reg.id, true);
  r := r || jsonb_build_object('teste', 'instância simulada não muda', 'ok',
        exists (select 1 from rt.evento where instancia = inst and tarefa = t_reg.id and resultado = 'concluída (simulado)')
        and not exists (select 1 from rt.evento where instancia = inst and resultado like 'concluída pela automação%')
        and not exists (select 1 from rt.cartao where instancia = inst));

  -- R8. tarefa de agente não muda: continua cartão assistido
  inst := rt._testar_automacao_r_inst(t_age.id, false);
  r := r || jsonb_build_object('teste', 'tarefa de agente não muda', 'ok',
        exists (select 1 from rt.cartao where instancia = inst and tarefa = t_age.id and titulo like '%(assistida:%')
        and not exists (select 1 from rt.evento where instancia = inst and resultado like 'concluída pela automação%'));

  -- R9. modo assistido desligado (protótipo): nada muda, a tarefa R é concluída como antes
  update adm.parametro set valor = 'false' where chave = 'motor.maquina_assistida';
  inst := rt._testar_automacao_r_inst(t_reg.id, false);
  r := r || jsonb_build_object('teste', 'modo assistido desligado não muda', 'ok',
        exists (select 1 from rt.evento where instancia = inst and tarefa = t_reg.id and resultado = 'concluída (simulado)')
        and not exists (select 1 from rt.evento where instancia = inst and resultado like 'concluída pela automação%'));
  update adm.parametro set valor = 'true' where chave = 'motor.maquina_assistida';

  -- R10. só quem administra altera a regra; a alteração fica no histórico e passa a valer
  select p2.pseudonimo into adm_id from rt.pessoa p2 where rt.pode_estrito(p2.pseudonimo, null, null, 'administrar') order by p2.simulado, p2.pseudonimo limit 1;
  insert into rt_chave.login (auth_uid, pseudonimo) values (u_o, pess[1]);
  if adm_id is not null and not exists (select 1 from rt_chave.login where pseudonimo = adm_id) then
    insert into rt_chave.login (auth_uid, pseudonimo) values (u_a, adm_id);
  else
    select auth_uid into u_a from rt_chave.login where pseudonimo = adm_id;
  end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_o, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_o::text, true);
  ok := false; begin perform adm.automacao_r_definir('Registrar', 'humano', 'teste'); exception when others then ok := sqlerrm like '%administração%'; end;
  ok := ok and (select modo from adm.automacao_r_regra where verbo = 'Registrar') = 'registrar';
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_a, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_a::text, true);
  if adm_id is not null then
    x := adm.automacao_r_definir('registrar', 'humano', 'teste da automação R');
    ok := ok and x->>'modo' = 'humano' and x->>'verbo' = 'Registrar'
          and exists (select 1 from adm.historico where objeto = 'automacao_r' and chave = 'Registrar' and por = adm_id
                       and antes->>'modo' = 'registrar' and depois->>'modo' = 'humano' and motivo = 'teste da automação R');
    perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
    inst := rt._testar_automacao_r_inst(t_reg.id, false);
    ok := ok and exists (select 1 from rt.cartao where instancia = inst and tarefa = t_reg.id and titulo like '%(assistida:%');
    update adm.automacao_r_regra set modo = 'registrar' where verbo = 'Registrar';
  else
    ok := false;
  end if;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  r := r || jsonb_build_object('teste', 'só administrador altera regra, com histórico', 'ok', ok);

  -- R11. resumo: a soma dos modos fecha com o total de tarefas R e está na lista da porta única
  x := adm.automacao_r_resumo();
  r := r || jsonb_build_object('teste', 'resumo por modo fecha com o total', 'ok',
        (x->>'tarefas_r')::int = (select count(*) from org.tarefa where executor = 'R')
        and (select sum(v::int) from jsonb_each_text(x->'por_modo') e(k, v)) = (x->>'tarefas_r')::int
        and (x->>'humanas')::int = (x->'por_modo'->>'humano')::int
        and exists (select 1 from adm.api_funcao where nome = 'adm.automacao_r_resumo' and quem = 'interno'));

  -- R12. permissões: anon não executa nada; a conclusão automática não é chamável de fora; tabela com segurança por linha
  r := r || jsonb_build_object('teste', 'permissões e segurança por linha', 'ok',
        not has_function_privilege('anon', 'adm.automacao_r_definir(text, text, text)', 'execute')
        and not has_function_privilege('anon', 'adm.automacao_r_resumo()', 'execute')
        and not has_function_privilege('authenticated', 'rt._automatizar_r(bigint, text, bigint)', 'execute')
        and not has_function_privilege('authenticated', 'rt._automacao_r_modo(text)', 'execute')
        and not has_table_privilege('authenticated', 'adm.automacao_r_regra', 'update')
        and not has_table_privilege('anon', 'adm.automacao_r_regra', 'select')
        and (select relrowsecurity from pg_class where oid = 'adm.automacao_r_regra'::regclass));

  -- devolve os parâmetros e tira as pessoas de teste dos papéis (para não ocuparem raias nas suítes seguintes da rodada)
  update adm.parametro set valor = v_assist where chave = 'motor.maquina_assistida';
  update adm.parametro set valor = v_auto where chave = 'motor.automacao_r';
  update rt.pessoa set papel = 'Teste automação R (encerrado)', circulo = null where pseudonimo = any (pess);
  delete from rt_chave.login where auth_uid = u_o;

  if exists (select 1 from jsonb_array_elements(r) t where not (t->>'ok')::boolean) then
    raise exception 'FALHA automação R: %', (select string_agg(t->>'teste', '; ') from jsonb_array_elements(r) t where not (t->>'ok')::boolean); end if;
  return 'automação R: ' || jsonb_array_length(r) || ' de ' || jsonb_array_length(r) || ' ok';
end $$;
revoke all on function rt._testar_automacao_r() from public, anon, authenticated;

-- suíte do motor assistido (062): roda com a automação R desligada, porque confere o cartão assistido de uma tarefa "Registrar ..."
do $$
declare d text; a text;
begin
  if to_regprocedure('rt._testar_assistido()') is null then return; end if;
  d := pg_get_functiondef('rt._testar_assistido()'::regprocedure); a := d;
  if position('motor.automacao_r' in d) > 0 then return; end if;
  d := replace(d, $q$  update adm.parametro set valor = 'true' where chave = 'motor.maquina_assistida';
$q$, $q$  update adm.parametro set valor = 'true' where chave = 'motor.maquina_assistida';
  -- a automação R (078) concluiria a tarefa "Registrar ..."; aqui se confere o cartão assistido de antes
  perform set_config('teste.automacao_r', adm.valor('motor.automacao_r', 'true')::text, true);
  update adm.parametro set valor = 'false' where chave = 'motor.automacao_r';
$q$);
  d := replace(d, $q$  return 'motor assistido: 5 de 5 ok';$q$, $q$  update adm.parametro set valor = current_setting('teste.automacao_r')::jsonb where chave = 'motor.automacao_r';
  return 'motor assistido: 5 de 5 ok';$q$);
  if d = a or position('teste.automacao_r'')::jsonb' in d) = 0 then raise exception 'rt._testar_assistido não tem o texto esperado: revisar a 079'; end if;
  execute d;
end $$;
commit;
