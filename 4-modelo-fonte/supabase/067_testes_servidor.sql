-- Testes das funções do servidor (P4): permissão decidida pelo banco, registro e alerta de armazenamento.
begin;
create or replace function adm._testar_servidor() returns text language plpgsql set search_path = '' as $$
declare a1 uuid; r jsonb; ok boolean; u_op uuid := gen_random_uuid(); u_cli uuid := gen_random_uuid(); emp uuid; outra uuid; base text := '778889990001'; v_cnpj text;
  dom text := adm.valor('login.dominios', '["imts.com.br"]') ->> 0;
begin
  select p.pseudonimo into a1 from rt.pessoa p where rt.pode_estrito(p.pseudonimo, null, null, 'administrar') order by p.simulado, p.pseudonimo limit 1;
  v_cnpj := acervo._cnpj_formatar(base || acervo._cnpj_dv(base));
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  r := adm.importar_cadastro(jsonb_build_object(
    'empresas', jsonb_build_array(jsonb_build_object('nome', 'Empresa Servidor Teste', 'cnpj', v_cnpj, 'regime_tributario', 'Lucro Presumido', 'marca', 'imts')),
    'pessoas', jsonb_build_array(jsonb_build_object('nome', 'Op Servidor', 'email', 'op.servidor@' || dom, 'papel', 'Operações · pessoa', 'circulo', 7, 'nivel', 'operar', 'empresa', 'Empresa Servidor Teste')),
    'contrapartes', jsonb_build_array(jsonb_build_object('empresa', 'Empresa Servidor Teste', 'tipo', 'cliente', 'nome', 'Cliente Servidor Teste', 'setor_publico', true)),
    'usuarios_externos', jsonb_build_array(jsonb_build_object('contraparte', 'Cliente Servidor Teste', 'nome', 'Cli', 'email', 'cli@servidor-teste.gov.br', 'perfil', 'gestor'))), true, a1);
  select id into emp from org.empresa where nome = 'Empresa Servidor Teste';
  select id into outra from org.empresa where id <> emp order by nome limit 1;
  insert into auth.users (id, email, aud, role) values (u_op, 'op.servidor@' || dom, 'authenticated', 'authenticated'), (u_cli, 'cli@servidor-teste.gov.br', 'authenticated', 'authenticated');
  update adm.parametro set valor = '""' where chave = 'google.usuario_sistema';

  -- V1. Google sem configuração: recusa com o motivo
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_op::text, true);
  ok := false; begin perform adm.servidor_autorizar('google', 'drive_enviar', jsonb_build_object('empresa', emp)); exception when others then ok := sqlerrm like '%google.usuario_sistema%'; end;
  if not ok then raise exception 'FALHA V1: sem configuração'; end if;
  update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema';
  -- V2. pessoa de dentro envia na empresa em que opera, com a pasta pedida; em outra empresa, não
  r := adm.servidor_autorizar('google', 'drive_enviar', jsonb_build_object('empresa', emp, 'pasta', '01'));
  if r->>'pasta' <> '01' or (r->>'empresa')::uuid <> emp or r->>'usuario_sistema' <> 'sistema@imts.com.br' then raise exception 'FALHA V2: %', r; end if;
  ok := false; begin perform adm.servidor_autorizar('google', 'drive_enviar', jsonb_build_object('empresa', outra)); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA V2: enviou em empresa sem acesso'; end if;
  -- V3. quem é de fora só envia para a pasta da sua organização, mesmo pedindo outra
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cli::text, true);
  r := adm.servidor_autorizar('google', 'drive_enviar', jsonb_build_object('empresa', outra, 'pasta', '01'));
  if r->>'pasta' <> '08' or (r->>'empresa')::uuid <> emp then raise exception 'FALHA V3: %', r; end if;
  ok := false; begin perform adm.servidor_autorizar('google', 'agenda_evento', '{}'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA V3: externo marcou reunião'; end if;
  -- V4. renomear: o externo só mexe no que ele mesmo enviou na última hora; apagar, nunca
  ok := false; begin perform adm.servidor_autorizar('google', 'drive_renomear', '{"id": "arquivoQualquer123"}'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA V4: renomeou arquivo alheio'; end if;
  perform set_config('request.jwt.claims', '', true);
  perform adm.servidor_registrar('google', 'drive_enviar', null, u_cli, 'arquivoDoCliente123', true, 'teste');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli, 'role', 'authenticated')::text, true);
  perform adm.servidor_autorizar('google', 'drive_renomear', '{"id": "arquivoDoCliente123"}');
  ok := false; begin perform adm.servidor_autorizar('google', 'drive_lixeira', '{"id": "arquivoDoCliente123"}'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA V4: externo apagou'; end if;
  -- V5. agenda: organizador é a própria pessoa
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_op::text, true);
  r := adm.servidor_autorizar('google', 'agenda_evento', '{}');
  if r->>'organizador' <> 'op.servidor@' || dom then raise exception 'FALHA V5: %', r; end if;
  -- V6. listar só pasta registrada de empresa em que opera
  ok := false; begin perform adm.servidor_autorizar('google', 'drive_listar', '{"pasta_id": "pastaDesconhecida123"}'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA V6: listou pasta fora do acervo'; end if;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  perform adm.servidor_pasta(emp, '06', 'pastaContratos12345');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_op::text, true);
  perform adm.servidor_autorizar('google', 'drive_listar', '{"pasta_id": "pastaContratos12345"}');
  -- V7. IA com orçamento: esgotado, recusa
  update adm.parametro set valor = '10' where chave = 'ia.orcamento_mensal_tokens';
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  perform adm.servidor_registrar('ia', 'ata_rascunho', null, null, 'teste', true, 'teste', 15, 5);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_op::text, true);
  ok := false; begin perform adm.servidor_autorizar('ia', 'ata_rascunho', '{"reuniao": 1}'); exception when others then ok := sqlerrm like '%orçamento%'; end;
  if not ok then raise exception 'FALHA V7: orçamento'; end if;
  -- V8. registro só pela chave de serviço; falha vira erro para o vigia; armazenamento acima do limite vira alerta
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true);
  ok := false; begin perform adm.servidor_registrar('google', 'x', null, null, null, true, null); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA V8: registro sem chave de serviço'; end if;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  perform adm.servidor_registrar('google', 'drive_ler', null, null, 'x', false, 'falha de teste');
  if not exists (select 1 from adm.erro where origem = 'google.drive_ler') then raise exception 'FALHA V8: falha sem erro'; end if;
  update adm.parametro set valor = '0' where chave = 'documentos.limite_mb';
  insert into doc.arquivo (emissao, formato, conteudo, sha256, bytes) select id, 'html', '\x00', 'x', 1 from doc.emissao where not exists (select 1 from doc.arquivo a where a.emissao = doc.emissao.id and formato = 'html') limit 1;
  perform adm.vigiar();
  if not exists (select 1 from adm.alerta where chave = 'armazenamento:documentos' and resolvido_em is null) and exists (select 1 from doc.arquivo) then raise exception 'FALHA V8: armazenamento sem alerta'; end if;
  return 'servidor: 8 de 8 ok';
end $$;
revoke all on function adm._testar_servidor() from public, anon, authenticated;

-- a rodada única passa a ter 19 suítes
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido', 'adm._testar_servidor'] loop
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
