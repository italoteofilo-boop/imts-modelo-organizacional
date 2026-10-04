-- Testes do atendimento ao cliente (E20); rodam dentro de adm.testar_tudo(), que desfaz tudo.
begin;
create or replace function ext._testar_atendimento() returns text language plpgsql set search_path = '' as $$
declare emp uuid := '80d8f119-a3fc-40ce-afaa-34d974f25d31'; cli uuid; ges uuid; fis uuid; fin uuid; parc uuid; op7 uuid; gov uuid; gest uuid;
  r jsonb; ok boolean; rec bigint; os bigint; ouv bigint; e1 bigint; e2 bigint; v_card bigint;
begin
  select id into cli from ext.contraparte where empresa = emp and tipo = 'cliente' and simulado limit 1;
  select auth_uid into ges from ext.usuario where contraparte = cli and perfil = 'gestor';
  select auth_uid into fis from ext.usuario where contraparte = cli and perfil = 'fiscal';
  select auth_uid into fin from ext.usuario where contraparte = cli and perfil = 'financeiro';
  select u.auth_uid into parc from ext.usuario u join ext.contraparte c on c.id = u.contraparte where c.tipo = 'parceiro' and u.perfil = 'gestor' limit 1;
  op7 := rt._pessoa('Operações · pessoa', 7::smallint); gov := rt._pessoa('Governança · pessoa', 9::smallint); gest := rt._pessoa('Gestão · pessoa', 8::smallint);
  if ges is null or fis is null or fin is null or op7 is null or gov is null then raise exception 'FALHA A0: dados simulados insuficientes'; end if;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);

  -- A1. Reclamação e ordem de serviço do cliente viram cartão de Operações com a empresa; parceiro não abre OS
  rec := ext.pedir_como(fis, 'reclamacao', 'Atraso no relatório mensal', 'O relatório de setembro não chegou.', null, null);
  os := ext.pedir_como(ges, 'os', 'Instalar o módulo de agenda', 'Precisamos do módulo na unidade 2.', null, null);
  perform set_config('request.jwt.claim.sub', '', true);
  if (select dono from rt.cartao where id = (select cartao from ext.pedido where id = rec)) <> op7 or (select empresa from rt.cartao where id = (select cartao from ext.pedido where id = os)) is distinct from emp
    then raise exception 'FALHA A1: cartão de atendimento'; end if;
  ok := false; begin perform ext.pedir_como(parc, 'os', 'x', 'y', null, null); exception when others then ok := true; end;
  perform set_config('request.jwt.claim.sub', '', true);
  if not ok then raise exception 'FALHA A1: parceiro abriu OS'; end if;

  -- A2. Ouvidoria anônima: cartão da Governança sem o nome da organização; o gestor do cliente não vê; quem escreveu vê
  ouv := ext.ouvidoria_como(fin, 'Conduta no atendimento', 'Relato sobre o atendimento presencial.', true);
  perform set_config('request.jwt.claim.sub', '', true);
  if (select dono from rt.cartao where id = (select cartao from ext.pedido where id = ouv)) <> gov or (select titulo from rt.cartao where id = (select cartao from ext.pedido where id = ouv)) !~ 'anônima'
     or strpos((select titulo from rt.cartao where id = (select cartao from ext.pedido where id = ouv)), (select nome from ext.contraparte where id = cli)) > 0 then raise exception 'FALHA A2: cartão da ouvidoria'; end if;
  r := ext.portal_como(ges); perform set_config('request.jwt.claim.sub', '', true);
  if exists (select 1 from jsonb_array_elements(r->'pedidos') p where (p->>'id')::bigint = ouv) then raise exception 'FALHA A2: gestor viu a ouvidoria de outra pessoa'; end if;
  r := ext.portal_como(fin); perform set_config('request.jwt.claim.sub', '', true);
  if not exists (select 1 from jsonb_array_elements(r->'pedidos') p where (p->>'id')::bigint = ouv) then raise exception 'FALHA A2: autor não vê a própria manifestação'; end if;

  -- A3. Central: Operações não vê ouvidoria; Governança vê, sem identificar quem escreveu
  r := ext.painel_atendimento(emp, op7);
  if exists (select 1 from jsonb_array_elements(r->'pedidos') p where p->>'tipo' = 'ouvidoria') or (r->>'ve_ouvidoria')::boolean then raise exception 'FALHA A3: Operações viu ouvidoria'; end if;
  r := ext.painel_atendimento(emp, gov);
  select p into r from jsonb_array_elements(r->'pedidos') p where (p->>'id')::bigint = ouv;
  if r is null or r->>'contraparte' <> 'anônima' or r->>'quem' is not null then raise exception 'FALHA A3: anonimato na Central (%)', r; end if;

  -- A4. Ouvidoria só a Governança conduz
  ok := false; begin perform ext.encaminhar(ouv, 'Ouvir a equipe', op7, now() + interval '2 days', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A4: Operações encaminhou ouvidoria'; end if;
  ok := false; begin perform ext.responder(ouv, 'resposta', 'em_atendimento', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A4: Operações respondeu ouvidoria'; end if;
  perform ext.encaminhar(ouv, 'Ouvir a equipe da unidade', gov, now() + interval '3 days', gov);

  -- A5. Encaminhamentos datados, com responsável e cartão na empresa; prazo no passado é recusado
  e1 := ext.encaminhar(rec, 'Reenviar o relatório de setembro', op7, now() + interval '2 days', op7);
  e2 := ext.encaminhar(rec, 'Rever a rotina de envio mensal', gest, now() + interval '5 days', op7);
  ok := false; begin perform ext.encaminhar(rec, 'atrasado', op7, now() - interval '1 hour', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A5: prazo no passado aceito'; end if;
  if (select situacao from ext.pedido where id = rec) <> 'em_atendimento' or (select dono from rt.cartao where id = (select cartao from ext.encaminhamento where id = e2)) <> gest
     or (select empresa from rt.cartao where id = (select cartao from ext.encaminhamento where id = e1)) is distinct from emp then raise exception 'FALHA A5: encaminhamento'; end if;

  -- A6. Não se propõe encerrar com encaminhamento aberto; "encerrado" não vem de dentro
  ok := false; begin perform ext.responder(rec, 'Resolvido.', 'respondido', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A6: encerramento proposto com encaminhamento aberto'; end if;
  ok := false; begin perform ext.responder(rec, 'Resolvido.', 'encerrado', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A6: encerrado por dentro'; end if;

  -- A7. Concluir exige dizer o que foi feito; com tudo fechado, a proposta abre o prazo de confirmação; o cliente vê as datas
  ok := false; begin perform ext.encaminhamento_concluir(e1, 'concluido', ' ', op7); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A7: concluído sem dizer o quê'; end if;
  perform ext.encaminhamento_concluir(e1, 'concluido', 'Relatório reenviado em 04/10.', op7);
  perform ext.encaminhamento_concluir(e2, 'cancelado', 'Rotina já revista em agosto.', op7);
  if (select coluna from rt.cartao where id = (select cartao from ext.encaminhamento where id = e1)) <> 'feito' then raise exception 'FALHA A7: cartão do encaminhamento aberto'; end if;
  perform ext.responder(rec, 'Relatório reenviado; rotina mantida.', 'respondido', op7);
  if (select confirmar_ate from ext.pedido where id = rec) is null then raise exception 'FALHA A7: sem prazo de confirmação'; end if;
  r := ext.portal_como(fis); perform set_config('request.jwt.claim.sub', '', true);
  select p into r from jsonb_array_elements(r->'pedidos') p where (p->>'id')::bigint = rec;
  if jsonb_array_length(r->'encaminhamentos') <> 2 or r->'encaminhamentos'->0->>'concluido_em' is null or r->'encaminhamentos'->0->>'area' <> 'Operações' then raise exception 'FALHA A7: cliente não vê os encaminhamentos (%)', r->'encaminhamentos'; end if;

  -- A8. Reabrir e confirmar: só quem é dono; reabertura gera cartão novo; confirmação encerra e fecha o cartão
  ok := false; begin perform ext.atendimento_confirmar_como(parc, rec, 5::smallint, null); exception when others then ok := true; end;
  perform set_config('request.jwt.claim.sub', '', true);
  if not ok then raise exception 'FALHA A8: estranho confirmou'; end if;
  v_card := (select cartao from ext.pedido where id = rec);
  perform ext.atendimento_reabrir_como(fis, rec, 'Faltou o anexo do relatório.'); perform set_config('request.jwt.claim.sub', '', true);
  if (select situacao from ext.pedido where id = rec) <> 'em_atendimento' or (select reaberturas from ext.pedido where id = rec) <> 1 or (select cartao from ext.pedido where id = rec) = v_card
    then raise exception 'FALHA A8: reabertura'; end if;
  perform ext.responder(rec, 'Anexo enviado.', 'respondido', op7);
  perform ext.atendimento_confirmar_como(ges, rec, 4::smallint, 'ok'); perform set_config('request.jwt.claim.sub', '', true);
  if (select situacao || '/' || encerrado_como || '/' || avaliacao from ext.pedido where id = rec) <> 'encerrado/confirmado/4'
     or (select coluna from rt.cartao where id = (select cartao from ext.pedido where id = rec)) <> 'feito' then raise exception 'FALHA A8: confirmação'; end if;

  -- A9. Aceite tácito depois do prazo
  perform ext.responder(os, 'Módulo instalado.', 'respondido', op7);
  update ext.pedido set confirmar_ate = now() - interval '1 minute' where id = os;
  if ext.encerrar_tacitos() < 1 or (select situacao || '/' || encerrado_como from ext.pedido where id = os) <> 'encerrado/tacito' then raise exception 'FALHA A9: aceite tácito'; end if;

  -- A10. O gestor não age sobre a ouvidoria de outra pessoa; nada se confirma sem proposta
  perform ext.encaminhamento_concluir((select id from ext.encaminhamento where pedido = ouv), 'concluido', 'Equipe ouvida.', gov);
  perform ext.responder(ouv, 'Apurado e tratado.', 'respondido', gov);
  ok := false; begin perform ext.atendimento_reabrir_como(ges, ouv, 'quero ver'); exception when others then ok := true; end;
  perform set_config('request.jwt.claim.sub', '', true);
  if not ok then raise exception 'FALHA A10: gestor reabriu ouvidoria alheia'; end if;
  ok := false; begin perform ext.atendimento_confirmar_como(fis, rec, null, null); exception when others then ok := true; end;
  perform set_config('request.jwt.claim.sub', '', true);
  if not ok then raise exception 'FALHA A10: confirmou o que já estava encerrado'; end if;
  return 'atendimento: 10 de 10 ok';
end $$;
revoke all on function ext._testar_atendimento() from public, anon, authenticated;

create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento'] loop
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
