-- Testes do banco para produção (P1); rodam dentro de adm.testar_tudo(), que desfaz tudo.
begin;
create or replace function adm._testar_producao() returns text language plpgsql set search_path = '' as $$
declare a1 uuid; r jsonb; ok boolean; u_int uuid := gen_random_uuid(); u_ext uuid := gen_random_uuid(); u_nada uuid := gen_random_uuid();
  base text := '445556660001'; v_cnpj text; v_p uuid; dados jsonb; n int; f record;
begin
  select p.pseudonimo into a1 from rt.pessoa p where rt.pode_estrito(p.pseudonimo, null, null, 'administrar') order by p.pseudonimo limit 1;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  v_cnpj := acervo._cnpj_formatar(base || acervo._cnpj_dv(base));
  dados := jsonb_build_object(
    'empresas', jsonb_build_array(jsonb_build_object('nome', 'Empresa Real Teste', 'cnpj', v_cnpj, 'regime_tributario', 'Lucro Presumido', 'marca', 'imts')),
    'pessoas', jsonb_build_array(jsonb_build_object('nome', 'Ana Teste', 'email', 'ana.teste@imts.com.br', 'papel', 'Operações · pessoa', 'circulo', 7, 'nivel', 'operar', 'empresa', 'Empresa Real Teste')),
    'contrapartes', jsonb_build_array(jsonb_build_object('empresa', 'Empresa Real Teste', 'tipo', 'cliente', 'nome', 'Cliente Real Teste', 'setor_publico', true)),
    'usuarios_externos', jsonb_build_array(jsonb_build_object('contraparte', 'Cliente Real Teste', 'nome', 'Beto Cliente', 'email', 'beto@cliente-teste.gov.br', 'perfil', 'gestor')));

  -- C1. Prévia aponta erros linha a linha e não grava; com erro, não confirma
  r := adm.importar_cadastro(jsonb_set(jsonb_set(dados, '{pessoas,0,email}', '"ana@gmail.com"'), '{empresas,0,cnpj}', '"11.111.111/1111-11"'), true, a1);
  if (r->>'confirmado')::boolean or jsonb_array_length(r->'erros') < 2 or exists (select 1 from org.empresa where nome = 'Empresa Real Teste') then raise exception 'FALHA C1: prévia (%)', r; end if;
  -- C2. Sem erro, confirma e grava tudo; só a administração importa
  ok := false; begin perform adm.importar_cadastro(dados, true, rt._pessoa('Operações · pessoa', 7::smallint)); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA C2: Operações importou'; end if;
  r := adm.importar_cadastro(dados, true, a1);
  if not (r->>'confirmado')::boolean or (r->'gravados'->>'pessoas')::int <> 1 or (r->'gravados'->>'convites')::int <> 1 then raise exception 'FALHA C2: carga (%)', r; end if;
  select i.pseudonimo into v_p from rt_chave.identidade i where i.email = 'ana.teste@imts.com.br';
  if (select simulado from rt.pessoa where pseudonimo = v_p) or not exists (select 1 from rt.acesso where pessoa = v_p and nivel = 'operar') then raise exception 'FALHA C2: pessoa'; end if;
  -- C3. A tarefa vai para a pessoa de verdade antes da simulada
  if rt._pessoa('Operações · pessoa', 7::smallint) <> v_p then raise exception 'FALHA C3: roteamento ignorou a pessoa real'; end if;
  -- C4. Primeiro login: de dentro liga à pessoa; convite vira usuário do portal; desconhecido fica sem cadastro
  insert into auth.users (id, email, aud, role) values (u_int, 'Ana.Teste@imts.com.br', 'authenticated', 'authenticated');
  insert into auth.users (id, email, aud, role) values (u_ext, 'beto@cliente-teste.gov.br', 'authenticated', 'authenticated');
  insert into auth.users (id, email, aud, role) values (u_nada, 'curioso@gmail.com', 'authenticated', 'authenticated');
  if (select pseudonimo from rt_chave.login where auth_uid = u_int) is distinct from v_p then raise exception 'FALHA C4: login de dentro não ligou'; end if;
  if not exists (select 1 from ext.usuario where auth_uid = u_ext and perfil = 'gestor' and not simulado) then raise exception 'FALHA C4: convite não virou usuário'; end if;
  perform set_config('request.jwt.claim.sub', u_int::text, true);
  if rt.quem_sou()->>'tipo' <> 'interno' then raise exception 'FALHA C4: quem_sou interno (%)', rt.quem_sou(); end if;
  perform set_config('request.jwt.claim.sub', u_ext::text, true);
  if rt.quem_sou()->>'tipo' <> 'externo' then raise exception 'FALHA C4: quem_sou externo'; end if;
  perform set_config('request.jwt.claim.sub', u_nada::text, true);
  if rt.quem_sou()->>'tipo' <> 'sem_cadastro' then raise exception 'FALHA C4: quem_sou desconhecido'; end if;
  -- C5. Porta única: com o login de quem usa; fora da lista, p_como e argumento estranho são recusados
  -- como o PostgREST faz: papel authenticated e o login nas claims
  perform set_config('request.jwt.claim.sub', u_int::text, true); perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_int, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    r := public.imts('rt.quem_sou', '{}');
    if r->>'tipo' <> 'interno' then raise exception 'FALHA C5: porta única não usou o login'; end if;
    r := public.imts('rt.app_quadro', '{}');
    if r is null then raise exception 'FALHA C5: Mesa pela porta única'; end if;
    ok := false; begin perform public.imts('rt.criar_avulsa', '{}'); exception when others then ok := sqlerrm like '%não disponível%'; end;
    if not ok then raise exception 'FALHA C5: função fora da lista'; end if;
    ok := false; begin perform public.imts('ext.responder', jsonb_build_object('p_pedido', 1, 'p_resposta', 'x', 'p_como', a1)); exception when others then ok := sqlerrm like '%outra pessoa%'; end;
    if not ok then raise exception 'FALHA C5: p_como aceito'; end if;
    ok := false; begin perform public.imts('rt.app_concluir', '{"p_x": 1}'); exception when others then ok := sqlerrm like '%desconhecido%'; end;
    if not ok then raise exception 'FALHA C5: argumento estranho aceito'; end if;
    perform set_config('request.jwt.claim.sub', u_ext::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', u_ext, 'role', 'authenticated')::text, true);
    r := public.imts('ext.portal', '{}');
    if r->'contraparte'->>'nome' <> 'Cliente Real Teste' then raise exception 'FALHA C5: portal pela porta única (%)', r->'contraparte'; end if;
    ok := false; begin perform public.imts('adm.painel_completo', '{}'); exception when others then ok := true; end;
    if not ok then raise exception 'FALHA C5: externo leu a administração'; end if;
  exception when others then
    reset role; perform set_config('request.jwt.claim.role', '', true); perform set_config('request.jwt.claims', '', true); raise;
  end;
  reset role;
  perform set_config('request.jwt.claim.sub', '', true); perform set_config('request.jwt.claim.role', '', true); perform set_config('request.jwt.claims', '', true);
  -- C6. Toda função da lista existe e pode ser executada por quem tem login
  for f in select a.nome from adm.api_funcao a loop
    if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname || '.' || p.proname = f.nome and has_function_privilege('authenticated', p.oid, 'EXECUTE')) then
      raise exception 'FALHA C6: % fora do alcance de quem tem login', f.nome; end if;
  end loop;
  -- C7. Alertas: abre, avisa uma vez no Telegram de Integração, renova sem repetir o aviso
  update adm.parametro set valor = '"tg:-100999"' where chave = 'alerta.chat_ref';
  insert into adm.erro (origem, detalhe) values ('teste.vigia', 'falha de teste');
  perform adm.vigiar();
  perform adm.vigiar();
  if (select count(*) from rt.fila_envio where chat_ref = 'tg:-100999' and texto like '%teste.vigia%') <> 1 or (select vezes from adm.alerta where chave = 'erro:teste.vigia' and resolvido_em is null) <> 2 then raise exception 'FALHA C7: alertas'; end if;
  -- C8. Retenção desligada por padrão não apaga nada
  if rt.reter_eventos() <> 0 then raise exception 'FALHA C8: retenção apagou com o padrão desligado'; end if;
  return 'produção: 8 de 8 ok';
end $$;
revoke all on function adm._testar_producao() from public, anon, authenticated;

create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao'] loop
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
