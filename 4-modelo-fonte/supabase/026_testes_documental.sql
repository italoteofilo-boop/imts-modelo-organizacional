-- Testes do motor documental (E12) como função; rodar sem gravar nada: do $$ begin raise exception '%', doc._testar_documental(); end $$;
begin;
create or replace function doc._testar_documental() returns text language plpgsql set search_path = '' as $$
declare
  p1 uuid; l1 uuid; l2 uuid; u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); u3 uuid := gen_random_uuid();
  ch text := encode(extensions.gen_random_bytes(24), 'hex'); ped bigint; ped2 bigint; em bigint; j jsonb; ok boolean; n int; s text;
  pdf bytea := convert_to('%PDF-1.7 teste', 'UTF8'); reg jsonb;
  c jsonb := '{"titulo":"Contrato de teste","data":"2026-10-04","local":"Fortaleza/CE","blocos":[{"t":"p","texto":"Teste."}]}';
begin
  -- D1. Catálogo, modelos, marcas e vínculo com o modelo organizacional
  if (select count(*) from doc.tipo) < 38 or (select count(*) from doc.modelo) <> 10 or (select count(*) from doc.marca) <> 4 then raise exception 'FALHA D1: catálogo incompleto'; end if;
  if (select count(distinct tarefa) from doc.tipo_tarefa) < 100 then raise exception 'FALHA D1: tipos sem tarefas do modelo'; end if;
  if (select count(*) from rt.vinculo where sistema = 'motor-documental') = 0 then raise exception 'FALHA D1: nenhuma automação ligada ao motor documental'; end if;

  -- D2. Pedido inválido é recusado na entrada
  ok := false; begin perform doc.pedir('nao-existe', 'imts', c); exception when others then ok := true; end; if not ok then raise exception 'FALHA D2: tipo fora do catálogo'; end if;
  ok := false; begin perform doc.pedir('contrato-cliente', 'tron', c); exception when others then ok := true; end; if not ok then raise exception 'FALHA D2: marca provisória em externo'; end if;
  ok := false; begin perform doc.pedir('contrato-cliente', 'imts', c - 'titulo'); exception when others then ok := true; end; if not ok then raise exception 'FALHA D2: sem título'; end if;
  if doc.pedir('politica', 'tron', c) is null then raise exception 'FALHA D2: provisória em interno deveria passar'; end if;

  -- D3. Pessoa com acesso de operar pede; quem só lê, não
  select pseudonimo into p1 from rt.pessoa p where exists (select 1 from rt.acesso a where a.pessoa = p.pseudonimo and a.nivel = 'operar') order by pseudonimo limit 1;
  select pseudonimo into l1 from rt.pessoa p where exists (select 1 from rt.acesso a where a.pessoa = p.pseudonimo and a.nivel = 'aprovar' and a.circulo is not null) order by pseudonimo limit 1;
  select pseudonimo into l2 from rt.pessoa p where exists (select 1 from rt.acesso a where a.pessoa = p.pseudonimo and a.nivel = 'aprovar') and pseudonimo <> l1 order by pseudonimo limit 1;
  insert into rt_chave.login (auth_uid, pseudonimo) values (u1, p1), (u2, l1), (u3, l2);
  perform set_config('request.jwt.claim.sub', u1::text, true);
  ped := doc.pedir('contrato-cliente', 'imts', c);
  if (select pedido_por from doc.pedido where id = ped) <> p1 or (select situacao from doc.pedido where id = ped) <> 'na_fila' then raise exception 'FALHA D3: pedido sem dono ou fora da fila'; end if;
  if not exists (select 1 from doc.evento where pedido = ped and tipo = 'pedido') then raise exception 'FALHA D3: sem evento'; end if;
  perform set_config('request.jwt.claim.sub', '', true);

  -- D4. Worker: chave errada recusada; a certa pega o mais antigo e registra com hash conferido
  -- usa a chave do Vault se já existir (sem expô-la); senão cria uma só para o teste (a exceção final desfaz)
  if rt._segredo('doc_worker_chave') is not null then ch := rt._segredo('doc_worker_chave');
  elsif to_regclass('vault.secrets') is not null then perform vault.create_secret(ch, 'doc_worker_chave');
  else insert into vault.decrypted_secrets values ('doc_worker_chave', ch); end if;
  ok := false; begin perform doc.worker_proximo('chave-errada-chave-errada-chave-errada', 't'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA D4: chave errada aceita'; end if;
  update doc.pedido set criado_em = now() - interval '1 hour' where id = ped;
  j := public.doc_worker_proximo(ch, 'worker-teste');
  if (j->>'pedido')::bigint <> ped or j->>'tipo' <> 'contrato-cliente' or j->>'titulo' <> 'Contrato de teste' then raise exception 'FALHA D4: worker pegou o pedido errado: %', j; end if;
  if (select situacao from doc.pedido where id = ped) <> 'em_emissao' then raise exception 'FALHA D4: pedido não entrou em emissão'; end if;
  reg := jsonb_build_object('situacao', 'emitido_com_alertas', 'paginas', 1, 'hash_pdf', 'errado', 'gates', '[]'::jsonb, 'alertas', '[{"alerta":"regra do terço"}]'::jsonb);
  ok := false; begin perform public.doc_worker_registrar(ch, ped, reg, encode(pdf, 'base64'), encode(convert_to('<p>x</p>', 'UTF8'), 'base64')); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA D4: hash errado aceito'; end if;
  reg := reg || jsonb_build_object('hash_pdf', encode(extensions.digest(pdf, 'sha256'), 'hex'));
  em := public.doc_worker_registrar(ch, ped, reg, encode(pdf, 'base64'), encode(convert_to('<p>x</p>', 'UTF8'), 'base64'));
  if (select count(*) from doc.arquivo where emissao = em) <> 2 or (select situacao from doc.pedido where id = ped) <> 'emitido_com_alertas' then raise exception 'FALHA D4: emissão não registrada'; end if;

  -- D5. Falha do worker: volta à fila duas vezes e para em erro na terceira
  ped2 := doc.pedir('ata', 'imts', c);
  update doc.pedido set criado_em = now() - interval '2 hours' where id = ped2;
  for n in 1..3 loop j := public.doc_worker_proximo(ch, 'w'); s := public.doc_worker_falhar(ch, (j->>'pedido')::bigint, 'Chromium caiu'); end loop;
  if s <> 'erro' or (select tentativas from doc.pedido where id = ped2) <> 3 then raise exception 'FALHA D5: falha sem limite (%)', s; end if;

  -- D6. Destravar: pedido preso em emissão há mais de 15 minutos volta à fila
  update doc.pedido set situacao = 'em_emissao', atualizado_em = now() - interval '1 hour' where id = ped2;
  n := doc.destravar();
  if n < 1 or (select situacao from doc.pedido where id = ped2) <> 'na_fila' then raise exception 'FALHA D6: não destravou'; end if;

  -- D7. Decisão em duas mãos: quem pediu não decide; alerta exige justificativa; análise antes da aprovação; quem analisou não aprova
  perform set_config('request.jwt.claim.sub', u1::text, true);
  ok := false; begin perform doc.decidir(em, 'analise', 'aprovado', 'ok'); exception when others then ok := true; end; if not ok then raise exception 'FALHA D7: quem pediu decidiu'; end if;
  perform set_config('request.jwt.claim.sub', u2::text, true);
  ok := false; begin perform doc.decidir(em, 'analise', 'aprovado'); exception when others then ok := true; end; if not ok then raise exception 'FALHA D7: alerta sem justificativa'; end if;
  ok := false; begin perform doc.decidir(em, 'aprovacao', 'aprovado', 'ok'); exception when others then ok := true; end; if not ok then raise exception 'FALHA D7: aprovação sem análise'; end if;
  perform doc.decidir(em, 'analise', 'aprovado', 'linha curta mantida: texto do Book aprovado');
  ok := false; begin perform doc.decidir(em, 'aprovacao', 'aprovado', 'ok'); exception when others then ok := true; end; if not ok then raise exception 'FALHA D7: quem analisou aprovou'; end if;
  perform set_config('request.jwt.claim.sub', u3::text, true);
  perform doc.decidir(em, 'aprovacao', 'aprovado', 'aprovado com o alerta justificado');
  if (select situacao from doc.pedido where id = ped) <> 'aprovado' then raise exception 'FALHA D7: pedido não ficou aprovado'; end if;

  -- D8. Emissão bloqueada não se submete
  update doc.emissao set situacao = 'bloqueado' where id = em;
  ok := false; begin perform doc.decidir(em, 'analise', 'aprovado', 'x'); exception when others then ok := true; end; if not ok then raise exception 'FALHA D8: bloqueada submetida'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  return 'documental: 8 de 8 ok';
end $$;
revoke all on function doc._testar_documental() from public;
commit;
