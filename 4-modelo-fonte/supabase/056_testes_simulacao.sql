-- Testes da simulação completa e do corte para a base de produção (E22); rodam dentro de adm.testar_tudo(), que desfaz tudo.
begin;
create or replace function adm._testar_simulacao() returns text language plpgsql set search_path = '' as $$
declare a1 uuid := 'd9499c2a-3ffc-4ed8-9141-08574f769c01'; op7 uuid; r jsonb; ok boolean; real_emp uuid := gen_random_uuid(); arq bigint; volta int := 0;
begin
  op7 := rt._pessoa('Operações · pessoa', 7::smallint);
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  -- Z1. Só a administração sem restrição simula ou zera
  ok := false; begin perform adm.simular_ecossistema(op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA Z1: Operações gerou simulação'; end if;
  ok := false; begin perform adm.zerar_simulacoes('ZERAR SIMULAÇÕES', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA Z1: Operações zerou'; end if;
  -- Z2. O ciclo completo passa por todas as áreas
  r := adm.simular_ecossistema(a1);
  if (r->'movimento'->>'oportunidades')::int < 2 or (r->'movimento'->>'comissoes')::int < 6 or (r->'movimento'->>'prestacoes')::int < 2 or (r->'movimento'->>'reunioes')::int < 2
     or (r->'movimento'->>'pedidos_de_fora')::int < 8 or (r->'movimento'->>'acervo')::int < 6 then raise exception 'FALHA Z2: ciclo incompleto (%)', r->'movimento'; end if;
  if not exists (select 1 from rt.fila_envio where simulado and chat_ref like 'tg:sim-%') then raise exception 'FALHA Z2: Telegram simulado sem aviso'; end if;
  -- Z3. Frase errada não zera
  ok := false; begin perform adm.zerar_simulacoes('zerar', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA Z3: zerou sem a frase'; end if;
  -- Z4. Dado real fica: empresa real com arquivo no acervo
  insert into org.empresa (id, nome, simulado) values (real_emp, 'Empresa real de teste', false);
  arq := (acervo._registrar(real_emp, 'real.pdf', encode(extensions.digest('real-' || random()::text, 'sha256'), 'hex'), 'application/pdf', 10, 'certidão negativa de débitos', 'upload', null, null, a1, null)->>'arquivo')::bigint;
  -- Z5. Zerar: movimento de fora, acervo e reuniões simuladas saem já no primeiro lote; a simulação desliga
  r := adm.zerar_simulacoes('ZERAR SIMULAÇÕES', a1, 200);
  if (r->'restante'->>'oportunidades')::int <> 0 or (r->'restante'->>'pedidos_de_fora')::int <> 0 or (r->'restante'->>'reunioes')::int <> 0
     or (r->'restante'->>'acervo')::int <> 0 or (r->'restante'->>'publicacoes')::int <> 0 or exists (select 1 from rt.fila_envio where simulado) then raise exception 'FALHA Z5: sobrou movimento simulado (%)', r->'restante'; end if;
  if (adm.valor('simulacao.ativa') #>> '{}')::boolean then raise exception 'FALHA Z5: simulação continuou ligada'; end if;
  if not exists (select 1 from acervo.arquivo where id = arq) then raise exception 'FALHA Z4: apagou dado real'; end if;
  if (select count(*) from ext.contraparte where simulado) = 0 or (select count(*) from rt.pessoa where simulado) = 0 then raise exception 'FALHA Z5: apagou cadastro'; end if;
  -- Z6. Desligada, não simula; com empresa real, não religa
  ok := false; begin perform adm.simular_ecossistema(a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA Z6: simulou com a simulação desligada'; end if;
  ok := false; begin perform adm.religar_simulacao(a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA Z6: religou com empresa real'; end if;
  -- Z7. O painel conta o que há
  r := adm.simulacao_painel(a1);
  if (r->>'ativa')::boolean or (r->'cadastro'->>'empresas_reais')::int <> 1 then raise exception 'FALHA Z7: painel (%)', r; end if;
  return 'simulação: 7 de 7 ok';
end $$;
revoke all on function adm._testar_simulacao() from public, anon, authenticated;
-- rodada única com as 16 suítes (esta passa a ser a definição final)
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes', 'adm._testar_simulacao'] loop
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
