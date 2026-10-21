-- Testes da 091 (lista das regras por verbo da automação R). Não vai para produção: o perfil de produção apaga as funções _testar.
-- Rodar:  begin; select adm._testar_automacao_r_regras(); rollback;
-- Para entrar na rodada geral, acrescentar 'adm._testar_automacao_r_regras' à lista de adm.testar_tudo (não redefinida aqui).
begin;

create or replace function adm._testar_automacao_r_regras() returns text language plpgsql security definer set search_path = '' as $$
declare r jsonb := '[]'; ok boolean; x jsonb; y jsonb; e jsonb;
  adm_id uuid; u_a uuid := gen_random_uuid(); u_o uuid := gen_random_uuid(); p_o uuid := gen_random_uuid();
  dom text := adm.valor('login.dominios', '["imts.email"]') ->> 0; v_antes adm.automacao_r_regra;
begin
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);

  -- G1. uma linha por regra da tabela, com o mesmo modo e a mesma descrição; total e contagem por modo fecham
  x := adm.automacao_r_regras();
  r := r || jsonb_build_object('teste', 'uma linha por regra, com modo e descrição da tabela', 'ok',
        (x->>'total')::int = (select count(*) from adm.automacao_r_regra)
        and jsonb_array_length(x->'regras') = (x->>'total')::int
        and not exists (select 1 from adm.automacao_r_regra g where not exists (
              select 1 from jsonb_array_elements(x->'regras') e2 where e2->>'verbo' = g.verbo and e2->>'modo' = g.modo and e2->>'descricao' = g.descricao))
        and (select sum(v::int) from jsonb_each_text(x->'por_modo') q(k, v)) = (x->>'total')::int
        and (x->'por_modo'->>'humano')::int = (select count(*) from adm.automacao_r_regra where modo = 'humano'));

  -- G2. quantas tarefas R usam o verbo: confere com o modelo, e a soma mais as tarefas de verbo sem regra dá o total de tarefas R
  e := (select e2 from jsonb_array_elements(x->'regras') e2 where e2->>'verbo' = 'Registrar');
  r := r || jsonb_build_object('teste', 'tarefas R por verbo conferem com o modelo', 'ok',
        (e->>'tarefas_r')::int = (select count(*) from org.tarefa where executor = 'R' and initcap(lower(split_part(btrim(nome), ' ', 1))) = 'Registrar')
        and (e->>'tarefas_r')::int > 0
        and (select sum((e2->>'tarefas_r')::int) from jsonb_array_elements(x->'regras') e2)
            + (select count(*) from org.tarefa t where t.executor = 'R'
                and not exists (select 1 from adm.automacao_r_regra g where g.verbo = initcap(lower(split_part(btrim(t.nome), ' ', 1)))))
            = (select count(*) from org.tarefa where executor = 'R')
        and (select sum((e2->>'compostas_com_pessoa')::int) from jsonb_array_elements(x->'regras') e2) = (adm.automacao_r_resumo()->>'compostas_humanas')::int
        and not exists (select 1 from jsonb_array_elements(x->'regras') e2 where e2->>'modo' = 'humano' and (e2->>'compostas_com_pessoa')::int <> 0));

  -- G3. ordem: mais tarefas primeiro, depois o verbo
  r := r || jsonb_build_object('teste', 'ordem por tarefas e verbo', 'ok',
        not exists (select 1 from (select (e2->>'tarefas_r')::int as q, e2->>'verbo' as v, n,
                      lag((e2->>'tarefas_r')::int) over (order by n) as q0, lag(e2->>'verbo') over (order by n) as v0
                      from jsonb_array_elements(x->'regras') with ordinality o(e2, n)) s
                    where s.q0 is not null and (s.q > s.q0 or (s.q = s.q0 and s.v < s.v0))));

  -- G4. quem administra: depois de definir, a linha traz o novo modo, quando e por quem (nome da pessoa)
  select p2.pseudonimo into adm_id from rt.pessoa p2 where rt.pode_estrito(p2.pseudonimo, null, null, 'administrar') order by p2.simulado, p2.pseudonimo limit 1;
  if adm_id is not null and not exists (select 1 from rt_chave.login where pseudonimo = adm_id) then
    insert into rt_chave.login (auth_uid, pseudonimo) values (u_a, adm_id);
  else
    select auth_uid into u_a from rt_chave.login where pseudonimo = adm_id;
  end if;
  select * into v_antes from adm.automacao_r_regra where verbo = 'Arquivar';
  ok := adm_id is not null;
  if ok then
    perform set_config('request.jwt.claims', jsonb_build_object('sub', u_a, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_a::text, true);
    perform adm.automacao_r_definir('Arquivar', 'humano', 'teste da lista de regras');
    y := adm.automacao_r_regras();
    e := (select e2 from jsonb_array_elements(y->'regras') e2 where e2->>'verbo' = 'Arquivar');
    ok := e->>'modo' = 'humano' and e->>'descricao' = 'teste da lista de regras' and (e->>'atualizado_por')::uuid = adm_id
          and e->>'atualizado_por_nome' is not distinct from (select nome from rt_chave.identidade where pseudonimo = adm_id and nome not like 'eliminado em %')
          and (e->>'atualizado_em')::timestamptz >= now() - interval '1 minute'
          and (e->>'compostas_com_pessoa')::int = 0
          and (y->'por_modo'->>'humano')::int = (x->'por_modo'->>'humano')::int + case when v_antes.modo = 'humano' then 0 else 1 end;
    update adm.automacao_r_regra set modo = v_antes.modo, descricao = v_antes.descricao, atualizado_em = v_antes.atualizado_em, atualizado_por = v_antes.atualizado_por
     where verbo = 'Arquivar';
  end if;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  r := r || jsonb_build_object('teste', 'após definir, mostra modo, quando e por quem', 'ok', ok);

  -- G5. quem não administra é recusado; chamada de serviço lê
  insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (p_o, 'Teste Regras R', 'regras.r.' || left(p_o::text, 8) || '@' || dom, false);
  insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (p_o, 'Teste regras R (sem administração)', null, false);
  insert into rt_chave.login (auth_uid, pseudonimo) values (u_o, p_o);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_o, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_o::text, true);
  ok := false; begin perform adm.automacao_r_regras(); exception when others then ok := sqlerrm like '%administração%'; end;
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true); perform set_config('request.jwt.claim.sub', '', true);
  ok := ok and jsonb_array_length(adm.automacao_r_regras()->'regras') > 0;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  delete from rt_chave.login where auth_uid = u_o;
  update rt.pessoa set papel = 'Teste regras R (encerrado)' where pseudonimo = p_o;
  r := r || jsonb_build_object('teste', 'só administração (ou serviço) lê a lista', 'ok', ok);

  -- G6. permissões, definição segura e porta única
  r := r || jsonb_build_object('teste', 'permissões, search_path vazio e porta única', 'ok',
        not has_function_privilege('anon', 'adm.automacao_r_regras()', 'execute')
        and has_function_privilege('authenticated', 'adm.automacao_r_regras()', 'execute')
        and not exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                         where p.oid = 'adm.automacao_r_regras()'::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE')
        and (select prosecdef and proconfig @> array['search_path=""'] and provolatile = 's' from pg_proc where oid = 'adm.automacao_r_regras()'::regprocedure)
        and exists (select 1 from adm.api_funcao where nome = 'adm.automacao_r_regras' and quem = 'interno'));

  if exists (select 1 from jsonb_array_elements(r) t where not (t->>'ok')::boolean) then
    raise exception 'FALHA regras da automação R: %', (select string_agg(t->>'teste', '; ') from jsonb_array_elements(r) t where not (t->>'ok')::boolean); end if;
  return 'regras da automação R: ' || jsonb_array_length(r) || ' de ' || jsonb_array_length(r) || ' ok';
end $$;
revoke all on function adm._testar_automacao_r_regras() from public, anon, authenticated;

-- rodada de testes com a lista de regras da automação (30 suítes)
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido', 'adm._testar_servidor', 'doc._testar_nota_debito', 'adm._testar_integracoes',
                           'rt._testar_papeis_acumulados', 'doc._testar_assinatura',
                           'rt._testar_automacao_r', 'doc._testar_assinatura_avisos', 'rt._testar_telegram_miniapp', 'doc._testar_docs_google', 'rt._testar_agentes_ia',
                           'rt._testar_telegram_vinculo_equipe', 'adm._testar_automacao_r_regras'] loop
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
