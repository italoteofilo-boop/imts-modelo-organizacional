-- Testes da 074 (papéis acumulados). Não vai para produção: o perfil de produção apaga as funções _testar.
begin;
create or replace function rt._testar_papeis_acumulados() returns text language plpgsql security definer set search_path = '' as $$
declare r jsonb := '[]'; p1 uuid; p2 uuid; adm_id uuid; ok boolean; x jsonb; dom text := adm.valor('login.dominios', '["imts.email"]') ->> 0; ea text := 'acumula.a.teste@' || dom; eb text := 'acumula.b.teste@' || dom;
begin
  select a.pessoa into adm_id from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
   where a.nivel = 'administrar' and a.empresa is null and a.circulo is null order by p.simulado limit 1;
  p1 := gen_random_uuid(); p2 := gen_random_uuid();
  insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (p1, 'Teste Acumula A', ea, false), (p2, 'Teste Acumula B', eb, false);
  insert into rt.pessoa values (p1, 'Sócios', null, false), (p2, 'Pessoa', null, false);
  insert into rt.acesso (pessoa, circulo, papel, nivel, motivo) values (p1, 2, 'Estratégia · pessoa', 'operar', 'teste'), (p2, 8, 'Gestão · pessoa', 'operar', 'teste');
  r := r || jsonb_build_object('teste', 'papel acumulado responde pelo motor', 'ok', rt._pessoa('Estratégia · pessoa', 2::smallint) = p1);
  r := r || jsonb_build_object('teste', 'papéis da pessoa: principal primeiro', 'ok', rt.papeis_de(p1) = array['Sócios', 'Estratégia · pessoa']);
  ok := false;
  begin insert into rt.acesso (pessoa, circulo, papel, nivel, motivo) values (p2, 8, 'Líder do círculo', 'aprovar', 'teste'); exception when others then ok := true; end;
  r := r || jsonb_build_object('teste', 'segregação vale para papel acumulado', 'ok', ok);
  x := adm._cadastro_incompativeis(jsonb_build_object('pessoas', jsonb_build_array(jsonb_build_object('email', eb, 'papel', 'Líder do círculo', 'circulo', '8'))));
  r := r || jsonb_build_object('teste', 'prévia aponta papel incompatível', 'ok', jsonb_array_length(x) = 1);
  if adm_id is not null then
    x := adm.importar_cadastro(jsonb_build_object('pessoas', jsonb_build_array(jsonb_build_object('nome', 'Teste Acumula A', 'email', ea, 'papel', 'Identidade · pessoa', 'circulo', '1', 'nivel', 'operar'))), true, adm_id);
    r := r || jsonb_build_object('teste', 'importação acrescenta papel a pessoa existente', 'ok', (x->>'confirmado')::boolean
          and exists (select 1 from rt.acesso where pessoa = p1 and papel = 'Identidade · pessoa'));
  end if;
  delete from rt.acesso where pessoa in (p1, p2); delete from rt.pessoa where pseudonimo in (p1, p2); delete from rt_chave.identidade where pseudonimo in (p1, p2);
  if exists (select 1 from jsonb_array_elements(r) t where not (t->>'ok')::boolean) then
    raise exception 'FALHA papéis acumulados: %', (select string_agg(t->>'teste', '; ') from jsonb_array_elements(r) t where not (t->>'ok')::boolean); end if;
  return 'papéis acumulados: ' || jsonb_array_length(r) || ' de ' || jsonb_array_length(r) || ' ok';
end $$;
revoke all on function rt._testar_papeis_acumulados() from public, anon, authenticated;

-- a rodada única passa a ter 22 suítes
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido', 'adm._testar_servidor', 'doc._testar_nota_debito', 'adm._testar_integracoes',
                           'rt._testar_papeis_acumulados'] loop
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
