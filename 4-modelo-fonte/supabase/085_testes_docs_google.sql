-- Testes do Google Docs como terceira saída (084): fila, permissão decidida pelo banco, nova tentativa, alerta e segurança.
-- Rodar: begin; select doc._testar_docs_google(); rollback;   (a suíte não grava nada fora da transação de quem chama)
begin;
create or replace function doc._testar_docs_google() returns text language plpgsql set search_path = '' as $$
declare a1 uuid; r jsonb; ok boolean; n int; n_ok int := 0; total int := 10;
  u_op uuid := gen_random_uuid(); u_le uuid := gen_random_uuid(); u_cli uuid := gen_random_uuid(); u_fora uuid := gen_random_uuid();
  emp uuid; outra uuid; base text := '778889990084'; v_cnpj text; dom text := adm.valor('login.dominios', '["imts.com.br"]') ->> 0;
  v_marca text := (select min(id) from doc.marca); ped bigint; em1 bigint; em2 bigint; em3 bigint; em4 bigint; html bytea := convert_to('<h1>Contrato de teste</h1><p>Cláusula primeira.</p>', 'UTF8');
  pdf bytea := convert_to('%PDF-1.4 teste', 'UTF8'); f text;
begin
  select p.pseudonimo into a1 from rt.pessoa p where rt.pode_estrito(p.pseudonimo, null, null, 'administrar') order by p.simulado, p.pseudonimo limit 1;
  v_cnpj := acervo._cnpj_formatar(base || acervo._cnpj_dv(base));
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true); perform set_config('request.headers', '', true);
  r := adm.importar_cadastro(jsonb_build_object(
    'empresas', jsonb_build_array(jsonb_build_object('nome', 'Empresa Docs Google Teste', 'cnpj', v_cnpj, 'regime_tributario', 'Lucro Presumido', 'marca', 'imts')),
    'pessoas', jsonb_build_array(
      jsonb_build_object('nome', 'Op Docs', 'email', 'op.docs@' || dom, 'papel', 'Operações · pessoa', 'circulo', 7, 'nivel', 'operar', 'empresa', 'Empresa Docs Google Teste'),
      jsonb_build_object('nome', 'Leitor Docs', 'email', 'leitor.docs@' || dom, 'papel', 'Operações · pessoa', 'circulo', 7, 'nivel', 'ler', 'empresa', 'Empresa Docs Google Teste')),
    'contrapartes', jsonb_build_array(jsonb_build_object('empresa', 'Empresa Docs Google Teste', 'tipo', 'cliente', 'nome', 'Cliente Docs Teste', 'setor_publico', true)),
    'usuarios_externos', jsonb_build_array(jsonb_build_object('contraparte', 'Cliente Docs Teste', 'nome', 'Cli Docs', 'email', 'cli@docs-teste.gov.br', 'perfil', 'gestor'))), true, a1);
  select id into emp from org.empresa where nome = 'Empresa Docs Google Teste';
  if emp is null then raise exception 'FALHA G0: cadastro de teste não entrou: %', r; end if;
  select id into outra from org.empresa where id <> emp order by nome limit 1;
  insert into auth.users (id, email, aud, role) values (u_op, 'op.docs@' || dom, 'authenticated', 'authenticated'), (u_le, 'leitor.docs@' || dom, 'authenticated', 'authenticated'),
    (u_cli, 'cli@docs-teste.gov.br', 'authenticated', 'authenticated');
  update adm.parametro set valor = '"sistema@imts.com.br"' where chave = 'google.usuario_sistema';
  update adm.parametro set valor = '""' where chave = 'servidor.url_funcoes';
  update adm.parametro set valor = 'false' where chave = 'documentos.saida_google_docs';
  update adm.parametro set valor = '5' where chave = 'documentos.google_docs_tentativas';
  update doc.tipo set google_docs = true where id = 'contrato-cliente';
  update doc.tipo set google_docs = false where id = 'nota-debito';

  -- G1. desligado (padrão): a emissão sai com PDF e HTML e nada vai para a fila
  insert into doc.pedido (tipo, marca, empresa, conteudo, situacao, worker) values ('contrato-cliente', v_marca, emp, '{"titulo": "Contrato Docs Teste"}', 'em_emissao', 'w-teste') returning id into ped;
  insert into doc.emissao (pedido, situacao, registro) values (ped, 'emitido', '{}') returning id into em1;
  insert into doc.arquivo values (em1, 'pdf', pdf, 'x', length(pdf)), (em1, 'html', html, 'y', length(html));
  if exists (select 1 from doc.google_doc where emissao = em1) then raise exception 'FALHA G1: gerou Doc com o parâmetro desligado'; end if;
  if (adm.valor('documentos.saida_google_docs') #>> '{}')::boolean is distinct from false then raise exception 'FALHA G1: parâmetro não nasce desligado'; end if;
  n_ok := n_ok + 1;

  -- G2. ligado: tipo marcado entra na fila (pasta pela família); tipo desmarcado e emissão bloqueada não; endereço configurado, chama a função docs
  update adm.parametro set valor = 'true' where chave = 'documentos.saida_google_docs';
  insert into doc.pedido (tipo, marca, empresa, conteudo, situacao, worker) values ('contrato-cliente', v_marca, emp, '{"titulo": "Contrato Docs Dois"}', 'em_emissao', 'w-teste') returning id into ped;
  insert into doc.emissao (pedido, situacao, registro) values (ped, 'emitido_com_alertas', '{}') returning id into em2;
  insert into doc.arquivo values (em2, 'pdf', pdf, 'x', length(pdf)), (em2, 'html', html, 'y', length(html));
  select count(*) into n from doc.google_doc where emissao = em2 and situacao = 'na_fila' and origem = 'emissao' and pasta = '06' and empresa = emp;
  if n <> 1 then raise exception 'FALHA G2: emissão do tipo marcado não entrou na fila'; end if;
  insert into doc.pedido (tipo, marca, empresa, conteudo, situacao, worker) values ('nota-debito', v_marca, emp, '{}', 'em_emissao', 'w-teste') returning id into ped;
  insert into doc.emissao (pedido, situacao, registro) values (ped, 'emitido', '{}') returning id into em3;
  insert into doc.arquivo values (em3, 'html', html, 'y', length(html));
  insert into doc.pedido (tipo, marca, empresa, conteudo, situacao, worker) values ('contrato-cliente', v_marca, emp, '{}', 'em_emissao', 'w-teste') returning id into ped;
  insert into doc.emissao (pedido, situacao, registro) values (ped, 'bloqueado', '{}') returning id into em4;
  insert into doc.arquivo values (em4, 'html', html, 'y', length(html));
  if exists (select 1 from doc.google_doc where emissao in (em3, em4)) then raise exception 'FALHA G2: tipo desmarcado ou emissão bloqueada entrou na fila'; end if;
  if doc._gdoc_chamar() is not null then raise exception 'FALHA G2: chamou a função sem o endereço configurado'; end if;
  update adm.parametro set valor = '"https://exemplo-teste.supabase.co/functions/v1"' where chave = 'servidor.url_funcoes';
  if rt._segredo('imts_funcao_chave') is not null and doc._gdoc_chamar() is null then raise exception 'FALHA G2: não chamou a função docs com o endereço configurado'; end if;
  update adm.parametro set valor = '""' where chave = 'servidor.url_funcoes';
  n_ok := n_ok + 1;

  -- G3. autorização da ação docs_criar: quem opera na empresa pode; quem só lê, quem é de fora e emissão sem HTML ou bloqueada, não
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_op::text, true);
  r := adm.servidor_autorizar('google', 'docs_criar', jsonb_build_object('emissao', em1));
  if (r->>'emissao')::bigint <> em1 or (r->>'empresa')::uuid <> emp or r->>'usuario_sistema' <> 'sistema@imts.com.br' or r->>'pessoa' is null then raise exception 'FALHA G3: %', r; end if;
  ok := false; begin perform adm.servidor_autorizar('google', 'docs_criar', jsonb_build_object('emissao', em4)); exception when others then ok := sqlerrm like '%só documento emitido%'; end;
  if not ok then raise exception 'FALHA G3: emissão bloqueada virou Doc'; end if;
  ok := false; begin perform adm.servidor_autorizar('google', 'docs_criar', '{"emissao": "x"}'); exception when others then ok := sqlerrm like '%emissão inválida%'; end;
  if not ok then raise exception 'FALHA G3: emissão inválida aceita'; end if;
  delete from doc.arquivo where emissao = em3 and formato = 'html';
  update doc.tipo set google_docs = true where id = 'nota-debito';
  ok := false; begin perform adm.servidor_autorizar('google', 'docs_criar', jsonb_build_object('emissao', em3)); exception when others then ok := sqlerrm like '%não tem o HTML%'; end;
  if not ok then raise exception 'FALHA G3: emissão sem HTML aceita'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_le, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_le::text, true);
  ok := false; begin perform adm.servidor_autorizar('google', 'docs_criar', jsonb_build_object('emissao', em1)); exception when others then ok := sqlerrm like '%sem acesso de operar%'; end;
  if not ok then raise exception 'FALHA G3: quem só lê gerou Doc'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cli::text, true);
  ok := false; begin perform adm.servidor_autorizar('google', 'docs_criar', jsonb_build_object('emissao', em1)); exception when others then ok := sqlerrm like '%só a equipe%'; end;
  if not ok then raise exception 'FALHA G3: cliente gerou Doc'; end if;
  n_ok := n_ok + 1;

  -- G4. fila (função docs, chave de serviço): toma o vencido com o HTML emitido, marca gerando e não entrega duas vezes
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  r := doc.gdoc_proximos(20);
  if r->>'usuario_sistema' <> 'sistema@imts.com.br' then raise exception 'FALHA G4: configuração %', r - 'itens'; end if;
  select count(*) into n from jsonb_array_elements(r->'itens') i
   where (i->>'emissao')::bigint = em2 and decode(i->>'html', 'base64') = html and i->>'pasta' = '06' and i->>'nome' like 'Contrato Docs Dois (emissão nº %' and (i->>'tentativa')::int = 1;
  if n <> 1 then raise exception 'FALHA G4: item da fila errado'; end if;
  if not exists (select 1 from doc.google_doc where emissao = em2 and situacao = 'gerando' and tentativas = 1) then raise exception 'FALHA G4: não marcou gerando'; end if;
  if exists (select 1 from jsonb_array_elements(doc.gdoc_proximos(20)->'itens') i where (i->>'emissao')::bigint = em2) then raise exception 'FALHA G4: entregou duas vezes'; end if;
  n_ok := n_ok + 1;

  -- G5. falha: o PDF fica; volta à fila com espera, registra sem virar erro a cada tentativa; esgotou, falhou e alerta de operação
  update adm.parametro set valor = '2' where chave = 'documentos.google_docs_tentativas';
  r := doc.gdoc_falhar(em2, 'Google respondeu 500: teste');
  if r->>'situacao' <> 'na_fila' or (r->>'proxima_em')::timestamptz <= now() then raise exception 'FALHA G5: primeira falha %', r; end if;
  if not exists (select 1 from doc.arquivo where emissao = em2 and formato = 'pdf') then raise exception 'FALHA G5: perdeu o PDF'; end if;
  if not exists (select 1 from adm.registro_servidor s where s.funcao = 'google' and s.acao = 'docs_criar' and not s.ok and alvo = 'emissao:' || em2) then raise exception 'FALHA G5: falha sem registro'; end if;
  if exists (select 1 from adm.erro where origem = 'google.docs_criar' and em > now() - interval '1 minute') then raise exception 'FALHA G5: tentativa virou erro de operação'; end if;
  if exists (select 1 from jsonb_array_elements(doc.gdoc_proximos(20)->'itens') i where (i->>'emissao')::bigint = em2) then raise exception 'FALHA G5: tomou antes da espera'; end if;
  update doc.google_doc set proxima_em = now() - interval '1 second' where emissao = em2;
  if not exists (select 1 from jsonb_array_elements(doc.gdoc_proximos(20)->'itens') i where (i->>'emissao')::bigint = em2) then raise exception 'FALHA G5: nova tentativa não veio'; end if;
  r := doc.gdoc_falhar(em2, 'Google respondeu 500: de novo');
  if r->>'situacao' <> 'falhou' then raise exception 'FALHA G5: não esgotou %', r; end if;
  if not exists (select 1 from adm.alerta where chave = 'docs_google:' || em2 and resolvido_em is null and tipo = 'erro') then raise exception 'FALHA G5: esgotou sem alerta'; end if;
  if doc.gdoc_rotina()->>'vencidos' <> '0' then raise exception 'FALHA G5: rotina insiste no que falhou de vez'; end if;
  n_ok := n_ok + 1;

  -- G6. pessoa pede de novo (função google, docs_criar): volta a valer e é tomado na hora
  update adm.parametro set valor = '5' where chave = 'documentos.google_docs_tentativas';
  r := doc.gdoc_tomar(em2, (select pseudonimo from rt_chave.identidade where email = 'op.docs@' || dom));
  if (r->>'pronto')::boolean or (r->>'emissao')::bigint <> em2 or decode(r->>'html', 'base64') <> html then raise exception 'FALHA G6: %', r - 'html'; end if;
  if not exists (select 1 from doc.google_doc where emissao = em2 and situacao = 'gerando' and tentativas = 1 and origem = 'pessoa' and pedido_por is not null) then raise exception 'FALHA G6: pedido da pessoa não reabriu'; end if;
  ok := false; begin perform doc.gdoc_tomar(em2, null); exception when others then ok := sqlerrm like '%já está sendo gerado%'; end;
  if not ok then raise exception 'FALHA G6: tomou duas vezes ao mesmo tempo'; end if;
  n_ok := n_ok + 1;

  -- G7. concluir: link só do Google; grava no registro da emissão, registra e fecha o alerta; pedir de novo devolve o mesmo Doc
  ok := false; begin perform doc.gdoc_concluir(em2, 'docTeste1234567890', 'javascript:alert(1)'); exception when others then ok := sqlerrm like '%link do Google Doc inválido%'; end;
  if not ok then raise exception 'FALHA G7: aceitou link de fora do Google'; end if;
  ok := false; begin perform doc.gdoc_concluir(em2, 'x', 'https://docs.google.com/document/d/x/edit'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA G7: aceitou id inválido'; end if;
  perform doc.gdoc_concluir(em2, 'docTeste1234567890', 'https://docs.google.com/document/d/docTeste1234567890/edit');
  if not exists (select 1 from doc.emissao where id = em2 and google_doc_id = 'docTeste1234567890' and google_doc_link like 'https://docs.google.com/%' and google_doc_em is not null) then raise exception 'FALHA G7: registro da emissão sem o Doc'; end if;
  if not exists (select 1 from doc.google_doc where emissao = em2 and situacao = 'pronto' and erro is null) then raise exception 'FALHA G7: fila não ficou pronta'; end if;
  if not exists (select 1 from adm.registro_servidor s where s.funcao = 'google' and s.acao = 'docs_criar' and s.ok and s.alvo = 'docTeste1234567890') then raise exception 'FALHA G7: sem registro do servidor'; end if;
  if exists (select 1 from adm.alerta where chave = 'docs_google:' || em2 and resolvido_em is null) then raise exception 'FALHA G7: alerta ficou aberto'; end if;
  r := doc.gdoc_tomar(em2, null);
  if not (r->>'pronto')::boolean or r->>'id' <> 'docTeste1234567890' then raise exception 'FALHA G7: gerou outro Doc %', r; end if;
  n_ok := n_ok + 1;

  -- G8. só a chave de serviço toma, conclui e falha; anon não executa nada do 084
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_op::text, true);
  ok := false; begin perform doc.gdoc_proximos(5); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA G8: login de pessoa tomou a fila'; end if;
  ok := false; begin perform doc.gdoc_concluir(em1, 'docTeste0987654321', 'https://docs.google.com/document/d/a/edit'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA G8: login de pessoa concluiu'; end if;
  foreach f in array array['doc._gdoc_pasta(text)', 'doc._gdoc_enfileirar(bigint,text,uuid)', 'doc._gdoc_chamar()', 'doc._gdoc_apos_arquivo()', 'doc._gdoc_item(bigint)',
    'doc._gdoc_autorizar(jsonb,uuid)', 'doc.gdoc_tomar(bigint,uuid)', 'doc.gdoc_proximos(integer)', 'doc.gdoc_concluir(bigint,text,text,uuid)', 'doc.gdoc_falhar(bigint,text,uuid)',
    'doc.gdoc_rotina()', 'doc.painel_docs_google(uuid)'] loop
    if has_function_privilege('anon', f::regprocedure, 'execute') then raise exception 'FALHA G8: anon executa %', f; end if;
    if f not like 'doc.painel%' and has_function_privilege('authenticated', f::regprocedure, 'execute') then raise exception 'FALHA G8: authenticated executa %', f; end if;
  end loop;
  if has_table_privilege('anon', 'doc.google_doc', 'select') or has_table_privilege('authenticated', 'doc.google_doc', 'insert') then raise exception 'FALHA G8: grants da fila'; end if;
  n_ok := n_ok + 1;

  -- G9. linha a linha: quem lê a empresa vê o pedido de Doc; quem é de outra empresa, não
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_le, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_le::text, true);
  execute 'set local role authenticated';
  select count(*) into n from doc.google_doc where emissao = em2;
  execute 'reset role';
  if n <> 1 then raise exception 'FALHA G9: quem lê a empresa não viu o pedido de Doc'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cli::text, true);
  execute 'set local role authenticated';
  select count(*) into n from doc.google_doc where emissao = em2;
  execute 'reset role';
  if n <> 0 then raise exception 'FALHA G9: cliente viu a fila de Docs'; end if;
  n_ok := n_ok + 1;

  -- G10. tela: o painel mostra o link a quem lê e o botão só a quem opera; empresa sem acesso, recusa
  r := null;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_le, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_le::text, true);
  r := doc.painel_docs_google(emp);
  if (r->>'pode_operar')::boolean or not (r->>'ligado')::boolean or not (r->>'automatico')::boolean then raise exception 'FALHA G10: cabeçalho %', r - 'emissoes'; end if;
  if not exists (select 1 from jsonb_array_elements(r->'emissoes') e where (e->>'emissao')::bigint = em2 and e->'google'->>'link' like 'https://docs.google.com/%' and e->'google'->>'situacao' = 'pronto') then
    raise exception 'FALHA G10: painel sem o link do Doc'; end if;
  if exists (select 1 from jsonb_array_elements(r->'emissoes') e where (e->>'emissao')::bigint in (em3, em4)) then raise exception 'FALHA G10: painel mostrou emissão sem HTML ou bloqueada'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_op::text, true);
  if not (doc.painel_docs_google(emp)->>'pode_operar')::boolean then raise exception 'FALHA G10: quem opera sem o botão'; end if;
  ok := false; begin perform doc.painel_docs_google(outra); exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'FALHA G10: painel de empresa sem acesso'; end if;
  n_ok := n_ok + 1;

  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  return 'Google Docs: ' || n_ok || ' de ' || total || ' ok';
end $$;
revoke all on function doc._testar_docs_google() from public, anon, authenticated;
commit;
