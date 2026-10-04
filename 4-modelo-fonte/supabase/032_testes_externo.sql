-- Testes da projeção externa e do portal (E16 e E14) como função; rodar sem gravar nada:
-- do $$ begin raise exception '%', ext._testar_externo(); end $$;
begin;
create or replace function ext._testar_externo() returns text language plpgsql set search_path = '' as $$
declare cA uuid; cB uuid; pA uuid; pB uuid; gA uuid; fA uuid; fin uuid; gB uuid; sp uuid; sq uuid; iA bigint; iB bigint; iSem bigint; iGE bigint;
  j jsonb; ok boolean; n int; pid bigint; ped bigint; em bigint; b64 text; interno uuid; v text;
begin
  -- montagem: duas contrapartes cliente e duas parceiras do teste, com usuários; instâncias simuladas reais do motor
  insert into ext.contraparte (empresa, tipo, nome, setor_publico, simulado) values ('80d8f119-a3fc-40ce-afaa-34d974f25d31', 'cliente', 'Teste A', true, true) returning id into cA;
  insert into ext.contraparte (empresa, tipo, nome, setor_publico, simulado) values ('80d8f119-a3fc-40ce-afaa-34d974f25d31', 'cliente', 'Teste B', false, true) returning id into cB;
  insert into ext.contraparte (empresa, tipo, nome, simulado) values ('80d8f119-a3fc-40ce-afaa-34d974f25d31', 'parceiro', 'Parceiro P', true) returning id into pA;
  insert into ext.contraparte (empresa, tipo, nome, simulado) values ('80d8f119-a3fc-40ce-afaa-34d974f25d31', 'parceiro', 'Parceiro Q', true) returning id into pB;
  gA := gen_random_uuid(); fA := gen_random_uuid(); fin := gen_random_uuid(); gB := gen_random_uuid(); sp := gen_random_uuid(); sq := gen_random_uuid();
  insert into ext.usuario (auth_uid, contraparte, nome, perfil, simulado) values (gA, cA, 'gA', 'gestor', true), (fA, cA, 'fA', 'fiscal', true), (fin, cA, 'finA', 'financeiro', true),
    (gB, cB, 'gB', 'gestor', true), (sp, pA, 'sp', 'gestor', true), (sq, pB, 'sq', 'gestor', true);
  select id into iA from rt.instancia i where jornada = 'OP-02' and empresa = '80d8f119-a3fc-40ce-afaa-34d974f25d31' and exists (select 1 from rt.evento e join org.etapa g on g.id = e.etapa where e.instancia = i.id and g.numero = 3) order by id desc limit 1;
  select id into iB from rt.instancia where jornada = 'OP-02' and empresa = '80d8f119-a3fc-40ce-afaa-34d974f25d31' and id <> iA order by id desc limit 1;
  select id into iGE from rt.instancia i where jornada = 'GE-03' and empresa = '80d8f119-a3fc-40ce-afaa-34d974f25d31' and exists (select 1 from rt.evento e join org.etapa g on g.id = e.etapa where e.instancia = i.id and g.numero = 2) order by id desc limit 1;
  select id into iSem from rt.instancia where jornada = 'GE-05' and empresa = '80d8f119-a3fc-40ce-afaa-34d974f25d31' order by id desc limit 1;
  delete from ext.vinculo where instancia in (iA, iB, iGE, iSem);
  perform ext.vincular(iA, cA); perform ext.vincular(iGE, cA); perform ext.vincular(iB, cB); perform ext.vincular(iSem, cA);

  -- X1. Lista de permissão: jornada sem regra não publica nada, mesmo ligada
  if exists (select 1 from ext.publicacao where instancia = iSem) then raise exception 'FALHA X1: publicou jornada sem regra'; end if;
  if not exists (select 1 from ext.publicacao where instancia = iA and contraparte = cA) then raise exception 'FALHA X1: não publicou a entrega'; end if;

  -- X2. Sem login externo, nada; com login, só a própria contraparte
  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  ok := false; begin perform ext.portal(); exception when others then ok := true; end; if not ok then raise exception 'FALHA X2: portal sem usuário externo'; end if;
  perform set_config('request.jwt.claim.sub', gA::text, true);
  j := ext.portal();
  if exists (select 1 from jsonb_array_elements(j->'andamentos') a where (a->>'ref')::bigint = iB) then raise exception 'FALHA X2: viu a instância de outra contraparte'; end if;
  if not exists (select 1 from jsonb_array_elements(j->'andamentos') a where (a->>'ref')::bigint = iA) then raise exception 'FALHA X2: não viu a própria entrega'; end if;

  -- X3. Nada interno sai: o assunto é o título externo e o texto é o da regra
  if j::text ~ 'Executar as entregas|Confirmar a entrega com o cliente|simulado\)|tarefa' then raise exception 'FALHA X3: texto interno no portal'; end if;
  if not exists (select 1 from jsonb_array_elements(j->'andamentos') a where a->>'assunto' = 'Entregas') then raise exception 'FALHA X3: sem título externo'; end if;

  -- X4. Perfil: o fiscal não vê faturamento; o financeiro vê
  perform set_config('request.jwt.claim.sub', fA::text, true);
  if exists (select 1 from jsonb_array_elements(ext.portal()->'andamentos') a where a->>'jornada' = 'GE-03') then raise exception 'FALHA X4: fiscal viu faturamento'; end if;
  perform set_config('request.jwt.claim.sub', fin::text, true);
  if not exists (select 1 from jsonb_array_elements(ext.portal()->'andamentos') a where a->>'jornada' = 'GE-03') then raise exception 'FALHA X4: financeiro não viu faturamento'; end if;

  -- X5. Aceite: o financeiro não aceita; referência de outra organização é recusada; o fiscal aceita uma vez, vira cartão de Operações com prazo
  ok := false; begin perform ext.pedir('aceite', 'Entrega do ciclo', 'Conferido', iA); exception when others then ok := true; end; if not ok then raise exception 'FALHA X5: financeiro deu aceite'; end if;
  perform set_config('request.jwt.claim.sub', fA::text, true);
  ok := false; begin perform ext.pedir('chamado', 'x', 'y', iB); exception when others then ok := true; end; if not ok then raise exception 'FALHA X5: pediu sobre referência alheia'; end if;
  update ext.publicacao set acao = 'aceite' where instancia = iA and contraparte = cA and etapa = 3;
  pid := ext.pedir('aceite', 'Entrega do ciclo', 'Conferido e aceito', iA);
  if (select c.dono from ext.pedido p join rt.cartao c on c.id = p.cartao where p.id = pid) is distinct from rt._pessoa('Operações · pessoa', 7::smallint) then raise exception 'FALHA X5: cartão no lugar errado'; end if;
  if not exists (select 1 from ext.publicacao where instancia = iA and contraparte = cA and etapa = -1) then raise exception 'FALHA X5: aceite fora da linha do tempo'; end if;
  ok := false; begin perform ext.pedir('devolucao', 'Entrega do ciclo', 'Mudei de ideia', iA); exception when others then ok := true; end; if not ok then raise exception 'FALHA X5: aceite em dobro'; end if;

  -- X6. Titular de dados: prazo da LGPD (art. 19, II) vindo da administração
  pid := ext.pedir('titular', 'Acesso aos meus dados', 'Peço a confirmação e o acesso aos dados tratados.');
  if (select prazo from ext.pedido where id = pid) > now() + interval '15 days 1 minute' then raise exception 'FALHA X6: prazo acima de 15 dias'; end if;

  -- X7. Oportunidade: só parceiro; exclusividade barra o segundo registro do mesmo cliente e objeto, sem dizer quem registrou
  ok := false; begin perform ext.pedir('oportunidade', 'Plataforma', 'x', null, 'Prefeitura X'); exception when others then ok := true; end; if not ok then raise exception 'FALHA X7: cliente registrou oportunidade'; end if;
  perform set_config('request.jwt.claim.sub', sp::text, true);
  perform ext.pedir('oportunidade', 'Plataforma de regulação', 'Município com interesse declarado', null, 'Prefeitura de Exemplópolis');
  perform set_config('request.jwt.claim.sub', sq::text, true);
  ok := false; begin perform ext.pedir('oportunidade', 'plataforma de REGULAÇÃO', 'Mesma', null, 'prefeitura de exemplopolis'); exception when others then ok := true; get stacked diagnostics v = message_text; end;
  if not ok then raise exception 'FALHA X7: exclusividade não barrou'; end if;
  if v ~ 'Parceiro P' then raise exception 'FALHA X7: revelou quem registrou'; end if;

  -- X8. Adesão à ata só para órgão público
  perform set_config('request.jwt.claim.sub', gB::text, true);
  ok := false; begin perform ext.pedir('adesao', 'Adesão', 'Queremos aderir'); exception when others then ok := true; end; if not ok then raise exception 'FALHA X8: adesão de privado'; end if;

  -- X9. Documento: só aprovado em duas mãos vai para fora, e só a quem foi publicado
  perform set_config('request.jwt.claim.sub', '', true);
  select pseudonimo into interno from rt.pessoa p where exists (select 1 from rt.acesso a where a.pessoa = p.pseudonimo and a.nivel = 'operar') limit 1;
  ped := doc.pedir('contrato-cliente', 'onni', '{"titulo":"Contrato teste","data":"2026-10-04","local":"x"}', '9ce4812d-e39d-4fb3-bbda-a59a0f4aa897');
  insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro) values (ped, 'emitido', 1, 'h', '{}') returning id into em;
  insert into doc.arquivo values (em, 'pdf', convert_to('%PDF teste', 'UTF8'), 'h', 10);
  ok := false; begin perform ext.publicar_documento(em, cA, null, interno); exception when others then ok := true; end; if not ok then raise exception 'FALHA X9: publicou sem aprovação'; end if;
  update doc.pedido set situacao = 'aprovado' where id = ped;
  -- documento da empresa de educação não vai para cliente da empresa de saúde
  ok := false; begin perform ext.publicar_documento(em, cA, null, interno); exception when others then ok := true; end; if not ok then raise exception 'FALHA X9: publicou para outra empresa'; end if;
  update doc.pedido set empresa = '80d8f119-a3fc-40ce-afaa-34d974f25d31' where id = ped;
  perform ext.publicar_documento(em, cA, '{gestor,fiscal}', interno);
  perform set_config('request.jwt.claim.sub', gA::text, true);
  b64 := ext.documento_pdf(em); if b64 is null then raise exception 'FALHA X9: gestor não baixou'; end if;
  perform set_config('request.jwt.claim.sub', gB::text, true);
  ok := false; begin perform ext.documento_pdf(em); exception when others then ok := true; end; if not ok then raise exception 'FALHA X9: outra contraparte baixou'; end if;

  -- X10. Resposta interna chega ao externo; a página via serviço só atua como usuário simulado
  perform set_config('request.jwt.claim.sub', '', true);
  perform ext.responder(pid, 'Recebido; respondemos no prazo da lei.', 'em_atendimento', interno);
  perform set_config('request.jwt.claim.sub', fA::text, true);
  if not exists (select 1 from jsonb_array_elements(ext.portal()->'pedidos') p where (p->>'id')::bigint = pid and p->>'situacao' = 'em_atendimento') then raise exception 'FALHA X10: resposta não chegou'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  update ext.usuario set simulado = false where auth_uid = gB;
  ok := false; begin perform ext.portal_como(gB); exception when others then ok := true; end; if not ok then raise exception 'FALHA X10: serviço atuou como usuário real'; end if;
  return 'externo: 10 de 10 ok';
end $$;
revoke all on function ext._testar_externo() from public;
commit;
