-- Testes de segurança (Onda 1): chamadas como o PostgREST faz (papel no JWT), sem login interno, com login externo e com login interno.
-- Rodar sem gravar nada: do $$ begin raise exception '%', rt._testar_seguranca(); end $$;
begin;
create or replace function rt._testar_seguranca() returns text language plpgsql set search_path = '' as $$
declare adm1 uuid; adm2 uuid; ext1 uuid; int1 uuid; u_int uuid := gen_random_uuid(); ok boolean; n int; c text; m bigint; j jsonb;
begin
  select pessoa into adm1 from rt.acesso where nivel = 'administrar' order by papel limit 1;
  select pessoa into adm2 from rt.acesso where nivel = 'administrar' and pessoa <> adm1 order by papel limit 1;
  select pseudonimo into int1 from rt.pessoa p where exists (select 1 from rt.acesso a where a.pessoa = p.pseudonimo and a.nivel = 'operar') order by pseudonimo limit 1;
  select auth_uid into ext1 from ext.usuario where simulado and perfil = 'gestor' order by nome limit 1;
  insert into rt_chave.login (auth_uid, pseudonimo) values (u_int, int1);

  -- S1. Chamada direta ao banco é serviço; pela API, o papel do JWT decide
  if not rt.chamada_servico() then raise exception 'FALHA S1: chamada direta não é serviço'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated', 'sub', ext1)::text, true);
  if rt.chamada_servico() then raise exception 'FALHA S1: authenticated passou como serviço'; end if;

  -- S2. Externo autenticado não atua como administrador nem como pessoa de dentro (o ataque R02/R03 da auditoria)
  ok := false; begin perform adm.alterar_parametro('simulacao.intervalo_minutos', '7', 'ataque', adm1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S2: externo alterou parâmetro como administrador'; end if;
  insert into adm.mudanca (chave, valor, motivo, pedido_por) values ('simulacao.retencao_dias', '45', 'teste', adm1) returning id into m;
  ok := false; begin perform adm.decidir_mudanca(m, 'aprovada', 'ataque', adm2); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S2: externo aprovou mudança'; end if;
  ok := false; begin perform rt.agente_ligar('atendente-externo', false, 'ataque', adm1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S2: externo desligou agente'; end if;
  ok := false; begin perform doc.pedir('ata', 'imts', '{"titulo":"t","data":"2026-10-04","local":"x"}', '8995fbb2-538c-43cf-94ff-f6b0c75f7c14'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S2: externo pediu documento interno'; end if;
  ok := false; begin perform ext.portal_como(ext1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S2: externo usou a porta do protótipo'; end if;

  -- S3. Externo não responde pedido (R04) nem lê o painel dos agentes (R06)
  ok := false; begin perform ext.responder((select id from ext.pedido limit 1), 'resposta forjada', 'encerrado', int1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S3: externo respondeu pedido'; end if;
  ok := false; begin perform rt.agentes_painel(); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S3: externo leu a memória dos agentes'; end if;

  -- S4. Leitura direta (RLS) como authenticated externo: nada de dentro, só a própria contraparte
  perform set_config('request.jwt.claim.sub', ext1::text, true);
  execute 'set local role authenticated';
  select count(*) into n from rt.mensagem; if n <> 0 then execute 'reset role'; raise exception 'FALHA S4: externo leu mensagens'; end if;
  select count(*) into n from rt.evento; if n <> 0 then execute 'reset role'; raise exception 'FALHA S4: externo leu eventos'; end if;
  select count(*) into n from rt.pessoa; if n <> 0 then execute 'reset role'; raise exception 'FALHA S4: externo leu pessoas'; end if;
  select count(*) into n from org.jornada; if n <> 0 then execute 'reset role'; raise exception 'FALHA S4: externo leu o modelo interno'; end if;
  select count(*) into n from ext.contraparte; if n <> 1 then execute 'reset role'; raise exception 'FALHA S4: externo viu % contrapartes', n; end if;
  select count(*) into n from rt.rota_chat; if n <> 0 then execute 'reset role'; raise exception 'FALHA S4: externo leu rota de chat'; end if;
  execute 'reset role';

  -- S5. Pessoa de dentro com login lê o runtime, mas só as próprias mensagens
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated', 'sub', u_int)::text, true);
  perform set_config('request.jwt.claim.sub', u_int::text, true);
  execute 'set local role authenticated';
  select count(*) into n from rt.evento where instancia is not null limit 1; if n = 0 then execute 'reset role'; raise exception 'FALHA S5: pessoa de dentro não leu eventos'; end if;
  select count(*) into n from rt.mensagem where pessoa <> int1; if n <> 0 then execute 'reset role'; raise exception 'FALHA S5: leu mensagem de outra pessoa'; end if;
  execute 'reset role';
  ok := false; begin perform rt.agentes_painel(); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA S5: quem não administra leu o painel dos agentes'; end if;

  -- S6. anon não executa nada dos nossos esquemas; só as três entradas do worker em public, protegidas pela chave
  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname in ('rt', 'doc', 'adm', 'ext', 'org', 'sim') and has_function_privilege('anon', p.oid, 'execute');
  if n <> 0 then raise exception 'FALHA S6: % funções executáveis por anon', n; end if;

  -- S7. Trilha de auditoria não se altera
  perform set_config('request.jwt.claims', '', true);
  ok := false; begin delete from adm.historico where id = (select min(id) from adm.historico); exception when others then ok := true; end;
  if not ok and exists (select 1 from adm.historico) then raise exception 'FALHA S7: apagou o histórico'; end if;

  -- S8. Webhook repetido do Telegram não roda duas vezes
  perform rt.receber_update('{"update_id":987654321,"message":{"message_id":1,"from":{"id":1},"chat":{"id":1,"type":"private"},"text":"oi"}}', true);
  if rt.receber_update('{"update_id":987654321,"message":{"message_id":1,"from":{"id":1},"chat":{"id":1,"type":"private"},"text":"oi"}}', true)->>'ignorado' <> 'atualização repetida' then
    raise exception 'FALHA S8: atualização repetida processada'; end if;
  -- S9. Multiempresa: instância simulada nasce com empresa; quem só tem acesso a uma empresa não lê a instância de outra
  declare emp_a uuid := '80d8f119-a3fc-40ce-afaa-34d974f25d31'; emp_b uuid := '9ce4812d-e39d-4fb3-bbda-a59a0f4aa897'; pa uuid; u_a uuid := gen_random_uuid(); ia bigint; ib bigint;
  begin
    perform set_config('request.jwt.claims', '', true); perform set_config('request.headers', '', true);
    if exists (select 1 from rt.instancia where empresa is null) then raise exception 'FALHA S9: instância sem empresa'; end if;
    select id into ia from rt.instancia where empresa = emp_a limit 1; select id into ib from rt.instancia where empresa = emp_b limit 1;
    insert into rt_chave.identidade (nome, simulado) values ('Teste empresa A', true) returning pseudonimo into pa;
    insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (pa, 'Pessoa', 7, true);
    insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, motivo) values (pa, emp_a, null, 'Pessoa', 'ler', 'teste S9');
    insert into rt_chave.login (auth_uid, pseudonimo) values (u_a, pa);
    perform set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated', 'sub', u_a)::text, true);
    perform set_config('request.jwt.claim.sub', u_a::text, true);
    execute 'set local role authenticated';
    if not exists (select 1 from rt.instancia where id = ia) then execute 'reset role'; raise exception 'FALHA S9: não leu a própria empresa'; end if;
    if exists (select 1 from rt.instancia where id = ib) then execute 'reset role'; raise exception 'FALHA S9: leu instância de outra empresa'; end if;
    execute 'reset role';
    -- cabeçalho com empresa sem acesso de operar é recusado
    perform set_config('request.headers', jsonb_build_object('x-empresa', emp_b)::text, true);
    ok := false; begin perform rt._empresa_da_chamada(); exception when others then ok := true; end;
    if not ok then raise exception 'FALHA S9: aceitou empresa sem acesso'; end if;
    perform set_config('request.headers', '', true);
    ok := false; begin perform ext.vincular(ib, (select id from ext.contraparte where empresa = emp_a limit 1)); exception when others then ok := true; end;
    if not ok then raise exception 'FALHA S9: ligou instância a contraparte de outra empresa'; end if;
  end;
  -- S10. O portal mostra a marca da empresa só com o que é público (sem inferências, fontes internas nem regras do motor)
  execute 'reset role'; perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.role', '', true); perform set_config('request.jwt.claim.sub', '', true);
  for j in select ext.portal_como(auth_uid) from ext.usuario where simulado and ativo loop
    if (j->'contraparte'->'marca') ?| array['inferencias', 'fonte', 'regras', 'razao_social', 'rodape_aprovacao'] then raise exception 'FALHA S10: portal expõe dado interno da marca'; end if;
  end loop;
  -- S11. Escopo de acesso (auditoria de 04/10/2026): administrar numa empresa não administra a plataforma; quem lê numa empresa
  --      não lê contraparte de outra; líder de um círculo não decide documento de tarefa de outro círculo
  declare emp_a uuid := '80d8f119-a3fc-40ce-afaa-34d974f25d31'; emp_b uuid := '9ce4812d-e39d-4fb3-bbda-a59a0f4aa897'; pb uuid; u_b uuid := gen_random_uuid(); lider4 uuid;
  begin
    insert into rt_chave.identidade (nome, simulado) values ('Teste admin empresa B', true) returning pseudonimo into pb;
    insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (pb, 'Pessoa', 7, true);
    insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, motivo) values (pb, emp_b, null, 'Pessoa', 'administrar', 'teste S11');
    if rt.pode_estrito(pb, null, null, 'administrar') then raise exception 'FALHA S11: admin de uma empresa administra a plataforma'; end if;
    ok := false; begin perform adm._quem(pb); exception when others then ok := true; end;
    if not ok then raise exception 'FALHA S11: admin de uma empresa passou na administração global'; end if;
    insert into rt_chave.login (auth_uid, pseudonimo) values (u_b, pb);
    perform set_config('request.jwt.claim.sub', u_b::text, true);
    if ext._le((select id from ext.contraparte where empresa = emp_a limit 1)) then raise exception 'FALHA S11: leu contraparte de outra empresa'; end if;
    if not ext._le((select id from ext.contraparte where empresa = emp_b limit 1)) then raise exception 'FALHA S11: não leu contraparte da própria empresa'; end if;
    perform set_config('request.jwt.claim.sub', '', true);
    select pessoa into lider4 from rt.acesso where papel = 'Líder do círculo' and circulo = 4 and nivel = 'aprovar' limit 1;
    if rt.pode_estrito(lider4, emp_a, 7::smallint, 'aprovar') or rt.pode_estrito(lider4, emp_a, null, 'aprovar') then raise exception 'FALHA S11: líder decide fora do próprio círculo'; end if;
    if not rt.pode_estrito(lider4, emp_a, 4::smallint, 'aprovar') then raise exception 'FALHA S11: líder não decide no próprio círculo'; end if;
  end;
  return 'segurança: 11 de 11 ok';
end $$;
revoke all on function rt._testar_seguranca() from public;
commit;
