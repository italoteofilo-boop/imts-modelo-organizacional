-- Testes das reuniões (E21); rodam dentro de adm.testar_tudo(), que desfaz tudo.
begin;
create or replace function ext._testar_reunioes() returns text language plpgsql set search_path = '' as $$
declare emp uuid := '80d8f119-a3fc-40ce-afaa-34d974f25d31'; cli uuid; fis uuid; ges uuid; fin uuid; parc uuid; op7 uuid; gov uuid;
  r jsonb; ok boolean; rec bigint; ouv bigint; re bigint; re2 bigint; re3 bigint; enc bigint;
  ata jsonb := '{"resumo":"Revisão do atraso do relatório mensal com a secretaria.","decisoes":["Relatório sai até o dia 5"],"encaminhamentos":[{"descricao":"Reenviar o relatório de setembro","responsavel":"Operações · pessoa","prazo_dias":2},{"descricao":"Ajustar a rotina de envio","responsavel":"Gestão · pessoa"}],"origem":"ia"}';
begin
  select id into cli from ext.contraparte where empresa = emp and tipo = 'cliente' and simulado limit 1;
  select auth_uid into fis from ext.usuario where contraparte = cli and perfil = 'fiscal';
  select auth_uid into ges from ext.usuario where contraparte = cli and perfil = 'gestor';
  select auth_uid into fin from ext.usuario where contraparte = cli and perfil = 'financeiro';
  select u.auth_uid into parc from ext.usuario u join ext.contraparte c on c.id = u.contraparte where c.tipo = 'parceiro' and u.perfil = 'gestor' limit 1;
  op7 := rt._pessoa('Operações · pessoa', 7::smallint); gov := rt._pessoa('Governança · pessoa', 9::smallint);
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  rec := ext.pedir_como(fis, 'reclamacao', 'Atraso no relatório', 'O relatório não chegou.', null, null);
  ouv := ext.ouvidoria_como(fin, 'Conduta', 'Relato sobre conduta.', true);
  perform set_config('request.jwt.claim.sub', '', true);

  -- R1. Reunião da demanda: herda a contraparte; ouvidoria só a Governança marca
  re := ext.reuniao_agendar(emp, 'Atraso do relatório', now() + interval '1 day', 45, 'meet', rec, null, true, op7);
  if (select contraparte from ext.reuniao where id = re) is distinct from cli then raise exception 'FALHA R1: contraparte'; end if;
  ok := false; begin perform ext.reuniao_agendar(emp, 'Ouvidoria', now() + interval '1 day', 30, 'meet', ouv, null, false, op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA R1: Operações marcou reunião da ouvidoria'; end if;
  re3 := ext.reuniao_agendar(emp, 'Escuta da ouvidoria', now() + interval '1 day', 30, 'presencial', ouv, null, false, gov);

  -- R2. Contrato do adaptador: só link https
  ok := false; begin perform ext.reuniao_registrar_externa(re, 'ev1', 'http://meet.google.com/abc', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA R2: link sem https'; end if;
  perform ext.reuniao_registrar_externa(re, 'ev1', 'https://meet.google.com/abc-defg-hij', op7);

  -- R3. Sem consentimento não se guarda transcrição; reunião sem gravação não recebe transcrição
  ok := false; begin perform ext.reuniao_transcricao(re, 'transcricao.txt', encode(extensions.digest('tr-1', 'sha256'), 'hex'), 'text/plain', 100, 'Transcrição da reunião sobre o atraso do relatório mensal.', 'drv-tr-1', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA R3: transcrição sem consentimento'; end if;
  ok := false; begin perform ext.reuniao_transcricao(re3, 'x.txt', encode(extensions.digest('tr-3', 'sha256'), 'hex'), 'text/plain', 100, 'Transcrição de uma reunião que não seria gravada.', null, gov); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA R3: transcrição de reunião sem gravação'; end if;

  -- R4. Consentimento pelo portal; transcrição vai para a pasta 09 do acervo
  perform ext.reuniao_consentir_como(fis, re); perform set_config('request.jwt.claim.sub', '', true);
  perform ext.reuniao_consentir(re, 'Representante da secretaria, por voz no início', op7);
  r := ext.reuniao_transcricao(re, 'transcricao.txt', encode(extensions.digest('tr-1', 'sha256'), 'hex'), 'text/plain', 100, 'Transcrição da reunião sobre o atraso do relatório mensal.', 'drv-tr-1', op7);
  if jsonb_array_length((select consentimentos from ext.reuniao where id = re)) <> 2 or (select pasta from acervo.arquivo where id = (r->>'arquivo')::bigint) <> '09'
     or (select situacao from ext.reuniao where id = re) <> 'realizada' then raise exception 'FALHA R4: consentimento ou transcrição'; end if;

  -- R5. Ata: sem resumo não entra; responsável desconhecido não aprova
  ok := false; begin perform ext.reuniao_ata_rascunho(re, '{"resumo":"curto"}', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA R5: ata sem resumo'; end if;
  perform ext.reuniao_ata_rascunho(re, ata, op7);
  ok := false; begin perform ext.reuniao_ata_aprovar(re, jsonb_set(ata, '{encaminhamentos,0,responsavel}', '"Ninguém"'), op7); exception when others then ok := true; end;
  if not ok or (select ata_situacao from ext.reuniao where id = re) <> 'rascunho' then raise exception 'FALHA R5: responsável desconhecido aprovado'; end if;

  -- R6. Aprovada por pessoa: encaminhamentos com cartão na empresa, demanda em atendimento, prazo de retenção; o cliente vê ata e datas
  r := ext.reuniao_ata_aprovar(re, null, op7);
  if (r->>'encaminhamentos')::int <> 2 or (select count(*) from ext.encaminhamento where reuniao = re and pedido = rec) <> 2
     or exists (select 1 from ext.encaminhamento e join rt.cartao k on k.id = e.cartao where e.reuniao = re and k.empresa is distinct from emp)
     or (select situacao from ext.pedido where id = rec) <> 'em_atendimento' or (select apagar_gravacao_em from ext.reuniao where id = re) is null then raise exception 'FALHA R6: aprovação (%)', r; end if;
  ok := false; begin perform ext.reuniao_ata_aprovar(re, null, op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA R6: aprovou duas vezes'; end if;
  r := ext.portal_reunioes_como(fis); perform set_config('request.jwt.claim.sub', '', true);
  select x into r from jsonb_array_elements(r) x where (x->>'id')::bigint = re;
  if r->'ata'->>'resumo' is null or jsonb_array_length(r->'encaminhamentos') <> 2 or not (r->>'consenti')::boolean then raise exception 'FALHA R6: portal do cliente (%)', r; end if;

  -- R7. Reunião sem demanda: encaminhamento só com a reunião; concluir usa a empresa da reunião
  re2 := ext.reuniao_agendar(emp, 'Alinhamento trimestral', now() + interval '2 days', 60, 'teams', null, cli, false, op7);
  perform ext.reuniao_ata_aprovar(re2, '{"resumo":"Alinhamento trimestral de indicadores do contrato.","decisoes":[],"encaminhamentos":[{"descricao":"Enviar o painel de indicadores","responsavel":"Operações · pessoa"}]}', op7);
  select id into enc from ext.encaminhamento where reuniao = re2;
  if enc is null or (select pedido from ext.encaminhamento where id = enc) is not null then raise exception 'FALHA R7: encaminhamento sem demanda'; end if;
  perform ext.encaminhamento_concluir(enc, 'concluido', 'Painel enviado.', op7);
  if (select situacao from ext.encaminhamento where id = enc) <> 'concluido' then raise exception 'FALHA R7: concluir'; end if;

  -- R8. Quem é de fora vê só o seu; Operações não vê reunião da ouvidoria; o gestor não vê a da ouvidoria anônima
  r := ext.portal_reunioes_como(parc); perform set_config('request.jwt.claim.sub', '', true);
  if jsonb_array_length(r) <> 0 then raise exception 'FALHA R8: parceiro viu reunião do cliente'; end if;
  r := ext.portal_reunioes_como(ges); perform set_config('request.jwt.claim.sub', '', true);
  if exists (select 1 from jsonb_array_elements(r) x where (x->>'id')::bigint = re3) then raise exception 'FALHA R8: gestor viu reunião da ouvidoria'; end if;
  r := ext.painel_reunioes(emp, op7);
  if exists (select 1 from jsonb_array_elements(r->'reunioes') x where (x->>'id')::bigint = re3) then raise exception 'FALHA R8: Operações viu reunião da ouvidoria'; end if;
  if (select count(*) from jsonb_array_elements(r->'conexoes')) < 4 then raise exception 'FALHA R8: conexões de vídeo'; end if;
  -- R9. Retenção: antes do prazo não se apaga; vencido, a transcrição sai do Drive e a ata fica
  ok := false; begin perform ext.reuniao_gravacao_apagada(re, op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA R9: apagou antes do prazo'; end if;
  update ext.reuniao set apagar_gravacao_em = current_date where id = re;
  perform ext.reuniao_gravacao_apagada(re, op7);
  if (select drive_id from acervo.arquivo where id = (select transcricao from ext.reuniao where id = re)) is not null
     or (select gravacao_apagada_em from ext.reuniao where id = re) is null or (select ata_situacao from ext.reuniao where id = re) <> 'aprovada' then raise exception 'FALHA R9: retenção'; end if;
  return 'reuniões: 9 de 9 ok';
end $$;
revoke all on function ext._testar_reunioes() from public, anon, authenticated;

create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes'] loop
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
