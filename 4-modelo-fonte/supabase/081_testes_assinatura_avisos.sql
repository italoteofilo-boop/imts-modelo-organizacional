-- Testes dos complementos da assinatura (080): avisos por e-mail, lembrete, limite de consultas da verificação e rotação da chave do selo.
-- Não vai para produção: o perfil de produção apaga as funções _testar. Rodar sempre no bloco que desfaz:
--   begin; select doc._testar_assinatura_avisos(); rollback;
-- O cadastro de teste nasce aqui mesmo (empresa, pessoas, cliente, PDF): roda igual no protótipo e num banco de produção.
begin;

-- entra como alguém (pelo login) ou volta a ser a chave de serviço (p_uid nulo)
create or replace function doc._testar_avs_entrar(p_uid uuid) returns void language plpgsql set search_path = '' as $$
begin
  if p_uid is null then
    perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true); perform set_config('request.jwt.claim.role', '', true);
  else
    perform set_config('request.jwt.claims', jsonb_build_object('sub', p_uid, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth', 'timestamp', 1)))::text, true);
    perform set_config('request.jwt.claim.sub', p_uid::text, true);
  end if;
end $$;
revoke all on function doc._testar_avs_entrar(uuid) from public, anon, authenticated;

create or replace function doc._testar_assinatura_avisos() returns text language plpgsql set search_path = '' as $$
declare e1 uuid; c1 uuid; m text := (select id from doc.marca order by id limit 1); dom text := 'avisos-teste.imts';
  p_ped uuid := gen_random_uuid(); p_ana uuid := gen_random_uuid(); p_adm uuid := gen_random_uuid();
  u_ped uuid := gen_random_uuid(); u_ana uuid := gen_random_uuid(); u_adm uuid := gen_random_uuid(); x1 uuid := gen_random_uuid();
  pdf1 bytea := convert_to('%PDF-1.4 documento de teste dos avisos de assinatura', 'UTF8');
  em1 bigint; dp bigint; r jsonb; a jsonb; ok boolean; n int; p1 bigint; p2 bigint; p3 bigint; p4 bigint; s_ana bigint; s_x1 bigint; v_id bigint; cod text;
  v_kid text; v_pub jsonb; man text; url_antes jsonb; lim_antes jsonb; n_testes int := 10;
begin
  perform doc._testar_avs_entrar(null); perform set_config('request.headers', '', true);
  url_antes := adm.valor('servidor.url_funcoes', '""'); lim_antes := adm.valor('verificar.limite_por_minuto', '30');
  -- ---------- cadastro de teste ----------
  insert into org.empresa (nome, simulado) values ('Empresa Avisos de Assinatura ' || p_ped, false) returning id into e1;
  insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (p_ped, 'Pede Avisos', 'pede@' || dom, false), (p_ana, 'Ana Avisos', 'ana@' || dom, false),
    (p_adm, 'Adm Avisos', 'adm@' || dom, false);
  insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (p_ped, 'Operações · pessoa', 7, false), (p_ana, 'Operações · pessoa', 7, false), (p_adm, 'Operações · pessoa', 7, false);
  insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, motivo) values (p_ped, e1, null, 'Operações · pessoa', 'operar', 'teste avisos'),
    (p_ana, e1, null, 'Operações · pessoa', 'operar', 'teste avisos'), (p_adm, null, null, 'Operações · pessoa', 'administrar', 'teste avisos');
  insert into rt_chave.login (auth_uid, pseudonimo) values (u_ped, p_ped), (u_ana, p_ana), (u_adm, p_adm);
  insert into ext.contraparte (empresa, tipo, nome) values (e1, 'cliente', 'Cliente Avisos') returning id into c1;
  insert into auth.users (id, email, aud, role) values (x1, 'xa@cliente.' || dom, 'authenticated', 'authenticated');
  insert into ext.usuario (auth_uid, contraparte, nome, perfil) values (x1, c1, 'Xavier Cliente', 'gestor');
  insert into doc.pedido (tipo, marca, empresa, conteudo, situacao) values ('nota-debito', m, e1, '{"titulo":"Contrato de teste dos avisos"}', 'emitido') returning id into dp;
  insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro, worker) values (dp, 'emitido', 1, encode(extensions.digest(pdf1, 'sha256'), 'hex'), '{}', 'teste') returning id into em1;
  insert into doc.arquivo values (em1, 'pdf', pdf1, encode(extensions.digest(pdf1, 'sha256'), 'hex'), length(pdf1));
  update adm.parametro set valor = '"https://ensaio-avisos.exemplo/functions/v1"' where chave = 'servidor.url_funcoes';
  update adm.parametro set valor = '"https://app.exemplo-avisos.test/"' where chave = 'assinatura.url_app';

  -- V1. rascunho não avisa; ao sair do rascunho, o primeiro da ordem entra na fila e o banco chama a função avisos
  perform doc._testar_avs_entrar(u_ped);
  p1 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana), jsonb_build_object('usuario', x1)), now() + interval '5 days', null, false, false)->>'id')::bigint;
  if exists (select 1 from doc.assinatura_aviso where pedido = p1) then raise exception 'FALHA V1: rascunho gerou aviso'; end if;
  perform doc.assinatura_enviar(p1);
  select id into s_ana from doc.assinatura_signatario where pedido = p1 and pessoa = p_ana;
  select id into s_x1 from doc.assinatura_signatario where pedido = p1 and usuario = x1;
  if (select string_agg(signatario || ':' || tipo || ':' || situacao, ',') from doc.assinatura_aviso where pedido = p1) is distinct from s_ana || ':vez:pendente' then
    raise exception 'FALHA V1: fila ao sair do rascunho'; end if;
  if to_regnamespace('net') is not null and doc._ass_pedir_aviso() is null then raise exception 'FALHA V1: não chamou a função avisos pelo pg_net'; end if;

  -- V2. lote para a função: título, quem pediu, prazo e link da Central para a equipe; nenhum segredo; reserva conta tentativa e não repete
  perform doc._testar_avs_entrar(null);
  r := doc.assinatura_avisos_para_enviar(50);
  select x into a from jsonb_array_elements(r->'avisos') x where (x->>'id')::bigint = (select id from doc.assinatura_aviso where signatario = s_ana and tipo = 'vez');
  if a is null or a->>'para' <> 'ana@' || dom or a->>'titulo' <> 'Contrato de teste dos avisos' or a->>'pedido_por' <> 'Pede Avisos'
     or a->>'link' <> 'https://app.exemplo-avisos.test/central.html#assinaturas' or a->>'prazo_texto' !~ '^\d{2}/\d{2}/\d{4} às \d{2}:\d{2}$' or (a->>'tentativa')::int <> 1 then
    raise exception 'FALHA V2: aviso %', a; end if;
  if a ? 'codigo' or a::text like '%' || (select hash_documento from doc.assinatura_pedido where id = p1) || '%'
     or a::text like '%' || (select codigo from doc.assinatura_pedido where id = p1) || '%' then raise exception 'FALHA V2: segredo no aviso %', a; end if;
  if exists (select 1 from jsonb_array_elements(doc.assinatura_avisos_para_enviar(50)->'avisos') x where (x->>'id')::bigint = (a->>'id')::bigint) then
    raise exception 'FALHA V2: aviso reservado saiu duas vezes'; end if;
  cod := doc.assinatura_aviso_resultado((a->>'id')::bigint, true, null);
  if cod <> 'enviado' or (select situacao from doc.assinatura_aviso where id = (a->>'id')::bigint) <> 'enviado' then
    raise exception 'FALHA V2: resultado do envio % %', cod, (select to_jsonb(v) from doc.assinatura_aviso v where id = (a->>'id')::bigint); end if;

  -- V3. quem assina passa a vez: o próximo da ordem (externo) recebe aviso com o link do Portal
  cod := doc.assinatura_codigo_emitir(s_ana)->>'codigo';
  perform doc._testar_avs_entrar(u_ana);
  r := doc.assinatura_assinar(s_ana, cod, true);
  if not (r->>'assinado')::boolean then raise exception 'FALHA V3: assinatura %', r; end if;
  perform doc._testar_avs_entrar(null);
  if not exists (select 1 from doc.assinatura_aviso where signatario = s_x1 and tipo = 'vez' and situacao = 'pendente') then raise exception 'FALHA V3: próximo da ordem sem aviso'; end if;
  select x into a from jsonb_array_elements(doc.assinatura_avisos_para_enviar(50)->'avisos') x where (x->>'id')::bigint = (select id from doc.assinatura_aviso where signatario = s_x1 and tipo = 'vez');
  if a is null or a->>'link' <> 'https://app.exemplo-avisos.test/portal.html#assinaturas' or a->>'para' <> 'xa@cliente.' || dom then raise exception 'FALHA V3: aviso do externo %', a; end if;
  perform doc.assinatura_aviso_resultado((a->>'id')::bigint, true, null);

  -- V4. sem duplicar: avisar a vez de novo não cria outro aviso para o mesmo signatário
  perform doc._ass_avisar_vez(p1); perform doc._ass_avisar_vez(p1);
  if (select count(*) from doc.assinatura_aviso where pedido = p1) <> 2 or (select count(*) from doc.assinatura_aviso where signatario = s_x1) <> 1 then
    raise exception 'FALHA V4: aviso duplicado'; end if;

  -- V5. Gmail falhou: volta para a fila com espera; na 5ª falha o aviso é encerrado e vira alerta de operação; reserva vencida também esgota
  perform doc._testar_avs_entrar(u_ped);
  p2 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana)), now() + interval '5 days')->>'id')::bigint;
  perform doc._testar_avs_entrar(null);
  select id into v_id from doc.assinatura_aviso where pedido = p2;
  update adm.alerta set resolvido_em = now() where chave = 'assinatura:avisos' and resolvido_em is null;
  for n in 1..5 loop
    update doc.assinatura_aviso set proxima_em = now() - interval '1 second' where id = v_id;
    if not exists (select 1 from jsonb_array_elements(doc.assinatura_avisos_para_enviar(50)->'avisos') x where (x->>'id')::bigint = v_id) then raise exception 'FALHA V5: tentativa % sem reserva', n; end if;
    cod := doc.assinatura_aviso_resultado(v_id, false, 'Gmail respondeu 503');
    if (n < 5 and (cod <> 'pendente' or (select proxima_em from doc.assinatura_aviso where id = v_id) <= now())) or (n = 5 and cod <> 'falhou') then
      raise exception 'FALHA V5: tentativa % ficou %', n, cod; end if;
  end loop;
  if (select tentativas || situacao || coalesce(ultimo_erro, '') from doc.assinatura_aviso where id = v_id) <> '5falhouGmail respondeu 503'
     or not exists (select 1 from adm.alerta where chave = 'assinatura:avisos' and resolvido_em is null and detalhe like '%pedido nº ' || p2 || '%' and detalhe like '%an***@' || dom || '%') then
    raise exception 'FALHA V5: esgotou sem alerta'; end if;
  if (select detalhe from adm.alerta where chave = 'assinatura:avisos' and resolvido_em is null) like '%ana@' || dom || '%' then raise exception 'FALHA V5: e-mail sem máscara no alerta'; end if;
  update doc.assinatura_aviso set situacao = 'pendente', encerrado_em = null, tentativas = 5, proxima_em = now() - interval '1 second' where id = v_id;
  perform doc.assinatura_avisos_para_enviar(50);
  if (select situacao from doc.assinatura_aviso where id = v_id) <> 'falhou' then raise exception 'FALHA V5: reserva vencida na 5ª tentativa não esgotou'; end if;

  -- V6. lembrete único perto do fim do prazo, só para quem está na vez desde antes da janela do lembrete
  update doc.assinatura_pedido set prazo = now() + interval '2 hours' where id = p1;
  update doc.assinatura_aviso set criado_em = now() - interval '3 days' where signatario = s_x1 and tipo = 'vez';
  perform doc._testar_avs_entrar(u_ped);
  p3 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana)), now() + interval '3 hours')->>'id')::bigint;   -- chegou à vez já dentro da janela
  perform doc._testar_avs_entrar(null);
  perform doc.assinatura_rotina(); perform doc.assinatura_rotina();
  if (select count(*) from doc.assinatura_aviso where signatario = s_x1 and tipo = 'lembrete' and situacao = 'pendente') <> 1 then raise exception 'FALHA V6: lembrete ausente ou duplicado'; end if;
  if exists (select 1 from doc.assinatura_aviso where pedido = p3 and tipo = 'lembrete') then raise exception 'FALHA V6: lembrete para quem acabou de receber o aviso'; end if;
  select x into a from jsonb_array_elements(doc.assinatura_avisos_para_enviar(50)->'avisos') x where x->>'tipo' = 'lembrete' and x->>'para' = 'xa@cliente.' || dom;
  if a is null then raise exception 'FALHA V6: lembrete fora do lote'; end if;
  perform doc.assinatura_aviso_resultado((a->>'id')::bigint, true, null);
  perform doc.assinatura_rotina();
  if (select count(*) from doc.assinatura_aviso where signatario = s_x1 and tipo = 'lembrete') <> 1 then raise exception 'FALHA V6: segundo lembrete'; end if;

  -- V7. pedido cancelado: o aviso que ainda não saiu é descartado e não vai no lote
  perform doc._testar_avs_entrar(u_ped);
  p4 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana)), now() + interval '5 days')->>'id')::bigint;
  perform doc.assinatura_cancelar(p4, 'Pedido de teste cancelado');
  perform doc._testar_avs_entrar(null);
  r := doc.assinatura_avisos_para_enviar(50);
  if exists (select 1 from jsonb_array_elements(r->'avisos') x join doc.assinatura_aviso v on v.id = (x->>'id')::bigint where v.pedido = p4)
     or (select situacao from doc.assinatura_aviso where pedido = p4) <> 'descartado' then raise exception 'FALHA V7: aviso de pedido cancelado'; end if;

  -- V8. rotação: a chave aposentada continua conferindo o selo antigo pelo kid; a privada sai do cofre (destruída), a próxima selagem gera outra
  perform doc._testar_avs_entrar(u_ped);
  p2 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana)), now() + interval '5 days')->>'id')::bigint;
  perform doc._testar_avs_entrar(null);
  cod := doc.assinatura_codigo_emitir((select id from doc.assinatura_signatario where pedido = p2))->>'codigo';
  perform doc._testar_avs_entrar(u_ana);
  if not (doc.assinatura_assinar((select id from doc.assinatura_signatario where pedido = p2), cod, true)->>'concluido')::boolean then raise exception 'FALHA V8: não concluiu'; end if;
  perform doc._testar_avs_entrar(null);
  select c.kid, c.publica into v_kid, v_pub from doc.assinatura_chave c where c.ativa;
  if v_kid is null then
    v_kid := 'kidDeTesteDosAvisos0123456789abc'; v_pub := '{"kty":"EC","crv":"P-256","x":"AAAA","y":"BBBB"}';
    if not doc.assinatura_chave_gravar(v_kid, v_pub, '{"kty":"EC","crv":"P-256","x":"AAAA","y":"BBBB","d":"CCCC"}') then raise exception 'FALHA V8: chave não gravada'; end if;
  end if;
  select x->>'manifesto' into man from jsonb_array_elements(doc.assinatura_para_selar(p2)) x;
  perform doc.assinatura_selar(p2, man, repeat('A', 86), v_kid, encode(pdf1, 'base64'), 'manifesto_separado');
  perform doc._testar_avs_entrar(u_adm);
  r := adm.assinatura_chave_rotacionar('Rotação periódica de teste');
  if r->>'kid_aposentada' <> v_kid or (select ativa from doc.assinatura_chave where kid = v_kid) or rt._segredo('assinatura_chave_privada') is not null
     or exists (select 1 from doc.assinatura_chave where ativa) then raise exception 'FALHA V8: rotação %', r; end if;
  if not exists (select 1 from adm.historico where chave = 'segredo:assinatura_chave_privada' and por = p_adm and motivo = 'Rotação periódica de teste' and depois->>'kid' = v_kid)
     or exists (select 1 from adm.historico where chave = 'segredo:assinatura_chave_privada' and (coalesce(antes::text, '') || coalesce(depois::text, '')) like '%"d"%') then
    raise exception 'FALHA V8: histórico da rotação'; end if;
  perform doc._testar_avs_entrar(null);
  if not doc.assinatura_chave_gravar('kidNovoDepoisDaRotacao0123456789', '{"kty":"EC","crv":"P-256","x":"DDDD","y":"EEEE"}', '{"kty":"EC","crv":"P-256","x":"DDDD","y":"EEEE","d":"FFFF"}')
     or (select kid from doc.assinatura_chave where ativa) <> 'kidNovoDepoisDaRotacao0123456789' then raise exception 'FALHA V8: a selagem seguinte não gerou chave nova'; end if;
  r := doc.assinatura_verificacao((select codigo from doc.assinatura_pedido where id = p2));
  if r->>'kid' <> v_kid or r->'chave_publica' <> (select publica from doc.assinatura_chave where kid = v_kid) or not (r->>'manifesto_confere')::boolean then
    raise exception 'FALHA V8: verificação da chave antiga %', r; end if;
  ok := false; begin update doc.assinatura_chave set ativa = true, aposentada_em = null where kid = v_kid; exception when others then ok := true; end;
  if not ok then raise exception 'FALHA V8: chave aposentada voltou'; end if;
  ok := false; begin delete from doc.assinatura_chave where kid = v_kid; exception when others then ok := sqlerrm like '%não se apaga%'; end;
  if not ok then raise exception 'FALHA V8: chave apagada'; end if;

  -- V9. só a administração rotaciona: quem opera não, a chave de serviço sem login não, anon nem executa
  perform doc._testar_avs_entrar(u_ped);
  ok := false; begin perform adm.assinatura_chave_rotacionar('tentativa sem administrar'); exception when others then ok := sqlerrm like '%administração%'; end;
  if not ok then raise exception 'FALHA V9: rotacionou sem administrar'; end if;
  perform doc._testar_avs_entrar(null);
  ok := false; begin perform adm.assinatura_chave_rotacionar('tentativa pela chave de serviço'); exception when others then ok := sqlerrm like '%administração%'; end;
  if not ok then raise exception 'FALHA V9: rotacionou sem login'; end if;
  perform doc._testar_avs_entrar(u_adm);
  ok := false; begin perform adm.assinatura_chave_rotacionar(' '); exception when others then ok := sqlerrm like '%motivo%'; end;
  if not ok then raise exception 'FALHA V9: rotacionou sem motivo'; end if;
  perform doc._testar_avs_entrar(null);
  if has_function_privilege('anon', 'adm.assinatura_chave_rotacionar(text)', 'execute') or has_function_privilege('authenticated', 'doc.assinatura_avisos_para_enviar(int)', 'execute')
     or has_function_privilege('authenticated', 'doc.verificar_contar(text, text)', 'execute') or has_table_privilege('authenticated', 'doc.assinatura_aviso', 'select') then
    raise exception 'FALHA V9: permissões'; end if;

  -- V10. limite de consultas: por IP e por código, na janela do minuto; o banco guarda só hash; a rotina limpa o que passou
  update adm.parametro set valor = '3' where chave = 'verificar.limite_por_minuto';
  for n in 1..3 loop
    if not (doc.verificar_contar('203.0.113.77', 'ABCD-EFGH-JKMN')->>'permitido')::boolean then raise exception 'FALHA V10: consulta % recusada', n; end if;
  end loop;
  r := doc.verificar_contar('203.0.113.77', 'zzzz-yyyy-xxxx');
  if (r->>'permitido')::boolean or r->>'por' <> 'ip' or (r->>'tentar_em')::int not between 1 and 61 then raise exception 'FALHA V10: excesso por IP aceito %', r; end if;
  r := doc.verificar_contar('198.51.100.9', 'abcdefghjkmn');
  if (r->>'permitido')::boolean or r->>'por' <> 'codigo' then raise exception 'FALHA V10: excesso por código aceito %', r; end if;
  if not (doc.verificar_contar('198.51.100.10', 'QRST-UVWX-YZ23')->>'permitido')::boolean then raise exception 'FALHA V10: outro IP e outro código recusados'; end if;
  if exists (select 1 from doc.verificar_consulta where chave like '%203.0.113%' or chave like '%ABCD%' or chave like '%ABCDEFGHJKMN%')
     or not exists (select 1 from doc.verificar_consulta c where c.chave = 'ip:' || doc._ass_sha256(doc._verificar_sal() || ':ip:203.0.113.77') and c.n = 4) then
    raise exception 'FALHA V10: contador guarda IP ou código em claro'; end if;
  insert into doc.verificar_consulta (chave, janela) values ('ip:' || repeat('a', 64), date_trunc('minute', now()) - interval '2 hours');
  perform doc.assinatura_rotina();
  if exists (select 1 from doc.verificar_consulta where janela < now() - interval '1 hour') then raise exception 'FALHA V10: contador antigo não foi limpo'; end if;

  update adm.parametro set valor = url_antes where chave = 'servidor.url_funcoes';
  update adm.parametro set valor = lim_antes where chave = 'verificar.limite_por_minuto';
  perform doc._testar_avs_entrar(null); perform set_config('request.headers', '', true);
  return 'avisos de assinatura: ' || n_testes || ' de ' || n_testes || ' ok';
end $$;
revoke all on function doc._testar_assinatura_avisos() from public, anon, authenticated;
commit;
