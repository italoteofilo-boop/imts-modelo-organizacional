-- Testes das integrações guiadas (072) e a definição final da rodada única (21 suítes, com a nota de débito da 071).
begin;
create or replace function adm._testar_integracoes() returns text language plpgsql set search_path = '' as $$
declare a1 uuid; op uuid; u_a uuid := gen_random_uuid(); u_o uuid := gen_random_uuid(); ok boolean; r jsonb; dom text := adm.valor('login.dominios', '["imts.com.br"]') ->> 0;
begin
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  select p.pseudonimo into a1 from rt.pessoa p where rt.pode_estrito(p.pseudonimo, null, null, 'administrar') order by p.simulado, p.pseudonimo limit 1;
  select p.pseudonimo into op from rt.pessoa p where not rt.pode_estrito(p.pseudonimo, null, null, 'administrar') and rt.pode(p.pseudonimo, null, null, 'operar') order by p.pseudonimo limit 1;
  insert into rt_chave.login (auth_uid, pseudonimo) values (u_a, a1), (u_o, op) on conflict do nothing;
  -- I1. quem não administra não grava segredo nem lê integrações
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_o, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_o::text, true);
  ok := false; begin perform adm.segredo_gravar('anthropic_chave', 'valor-de-teste-123', 'teste'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA I1: gravou sem administrar'; end if;
  ok := false; begin perform adm.integracoes(); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA I1: leu integrações sem administrar'; end if;
  -- I2. administração grava; o valor não volta nem fica no histórico
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_a, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_a::text, true);
  r := adm.segredo_gravar('anthropic_chave', 'valor-secreto-de-teste-123', 'teste');
  if r::text like '%valor-secreto%' or length(r->>'impressao') <> 8 then raise exception 'FALHA I2: %', r; end if;
  if exists (select 1 from adm.historico where depois::text like '%valor-secreto%' or coalesce(antes::text, '') like '%valor-secreto%') then raise exception 'FALHA I2: valor no histórico'; end if;
  if rt._segredo('anthropic_chave') <> 'valor-secreto-de-teste-123' then raise exception 'FALHA I2: não gravou no cofre'; end if;
  -- I3. regravar troca o valor; nome não previsto é recusado
  perform adm.segredo_gravar('anthropic_chave', 'outro-valor-de-teste-456', 'troca');
  if rt._segredo('anthropic_chave') <> 'outro-valor-de-teste-456' then raise exception 'FALHA I3: não trocou'; end if;
  ok := false; begin perform adm.segredo_gravar('qualquer_nome', 'valor-de-teste-123', 'x'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA I3: nome não previsto aceito'; end if;
  -- I4. a lista mostra que o segredo existe, sem o valor
  r := adm.integracoes();
  if r::text like '%outro-valor%' or not exists (select 1 from jsonb_array_elements(r->'conexoes') c, jsonb_array_elements(c->'segredos') s where s->>'nome' = 'anthropic_chave' and (s->>'gravado')::boolean) then
    raise exception 'FALHA I4: situação'; end if;
  -- I5. serviço externo novo: endereço só https; nasce pendente
  ok := false; begin perform adm.conexao_criar('erp-teste', 'ERP de teste', 'contábil', 'Fornecedor X', 'http://inseguro', '{erp_teste_chave}', '{}', 'teste'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA I5: aceitou http'; end if;
  perform adm.conexao_criar('erp-teste', 'ERP de teste', 'contábil', 'Fornecedor X', 'https://erp.exemplo.com/api', '{erp_teste_chave}', '{"empresa_codigo":"123"}', 'teste');
  if (select estado from adm.conexao where codigo = 'erp-teste') <> 'pendente' then raise exception 'FALHA I5: estado'; end if;
  perform adm.segredo_gravar('erp_teste_chave', 'chave-do-erp-de-teste', 'teste');
  -- I6. sistema só vira real com conexão ativa e testada
  ok := false; begin perform adm.sistema_adaptador('erp-contabil', 'real', 'erp-teste', 'teste'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA I6: virou real sem teste'; end if;
  perform adm.sistema_adaptador('erp-contabil', 'assistido', null, 'teste');
  if (select adaptador from rt.sistema where codigo = 'erp-contabil') <> 'assistido' then raise exception 'FALHA I6: assistido'; end if;
  -- I7. resultado de teste só pela chave de serviço, e conexão testada fica ativa
  ok := false; begin perform adm.conexao_saude('erp-teste', true, 'x'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA I7: gravou saúde com login'; end if;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  perform adm.conexao_saude('erp-teste', true, 'endereço respondeu 200');
  if (select estado || saude from adm.conexao where codigo = 'erp-teste') <> 'ativaok' then raise exception 'FALHA I7: estado depois do teste'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_a, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_a::text, true);
  perform adm.sistema_adaptador('erp-contabil', 'real', 'erp-teste', 'teste');
  -- I8. a função conexoes só autoriza quem administra
  r := adm.servidor_autorizar('conexoes', 'testar', '{"codigo":"erp-teste"}');
  if r->>'endpoint' <> 'https://erp.exemplo.com/api' then raise exception 'FALHA I8: %', r; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_o, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_o::text, true);
  ok := false; begin perform adm.servidor_autorizar('conexoes', 'testar', '{"codigo":"erp-teste"}'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA I8: autorizou sem administrar'; end if;
  return 'integrações: 8 de 8 ok';
end $$;
revoke all on function adm._testar_integracoes() from public, anon, authenticated;

-- a rodada única passa a ter 21 suítes
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido', 'adm._testar_servidor', 'doc._testar_nota_debito', 'adm._testar_integracoes'] loop
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
