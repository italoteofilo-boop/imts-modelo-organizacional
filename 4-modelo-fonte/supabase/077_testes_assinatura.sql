-- Testes da assinatura eletrônica avançada (076) e a rodada única com 23 suítes.
-- Não vai para produção: o perfil de produção apaga as funções _testar. Rodar sempre no bloco que desfaz:
--   begin; select doc._testar_assinatura(); rollback;    ou    begin; select adm.testar_tudo(); rollback;
-- O cadastro de teste é criado aqui mesmo (empresas, pessoas, clientes, PDFs): roda igual no protótipo e num banco de produção.
begin;

-- entra como alguém (interno ou externo) ou volta a ser a chave de serviço (p_uid nulo)
create or replace function doc._testar_ass_como(p_uid uuid) returns void language plpgsql set search_path = '' as $$
begin
  if p_uid is null then
    perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true); perform set_config('request.jwt.claim.role', '', true);
  else
    perform set_config('request.jwt.claims', jsonb_build_object('sub', p_uid, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth', 'timestamp', 1)))::text, true);
    perform set_config('request.jwt.claim.sub', p_uid::text, true);
  end if;
end $$;
revoke all on function doc._testar_ass_como(uuid) from public, anon, authenticated;

create or replace function doc._testar_assinatura() returns text language plpgsql set search_path = '' as $$
declare e1 uuid; e2 uuid; c1 uuid; c2 uuid; m text := (select id from doc.marca order by id limit 1); dom text := 'assinatura-teste.imts';
  p_ped uuid := gen_random_uuid(); p_ana uuid := gen_random_uuid(); p_bia uuid := gen_random_uuid(); p_fora uuid := gen_random_uuid();
  u_ped uuid := gen_random_uuid(); u_ana uuid := gen_random_uuid(); u_bia uuid := gen_random_uuid(); u_fora uuid := gen_random_uuid();
  x1 uuid := gen_random_uuid(); x2 uuid := gen_random_uuid();
  pdf1 bytea := convert_to('%PDF-1.4 documento de teste da assinatura um', 'UTF8'); pdf2 bytea := convert_to('%PDF-1.4 documento de teste da assinatura dois', 'UTF8');
  em1 bigint; em2 bigint; dp bigint; r jsonb; ok boolean; n int; p1 bigint; p2 bigint; p3 bigint; p4 bigint; p5 bigint; p6 bigint;
  s_ana bigint; s_x1 bigint; s_bia bigint; cod text; v_kid text; man text; n_testes int := 15;
begin
  perform doc._testar_ass_como(null); perform set_config('request.headers', '', true);
  -- ---------- cadastro de teste ----------
  insert into org.empresa (nome, simulado) values ('Empresa Assinatura Um ' || p_ped, false) returning id into e1;
  insert into org.empresa (nome, simulado) values ('Empresa Assinatura Dois ' || p_ped, false) returning id into e2;
  insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (p_ped, 'Pede Teste', 'pede@' || dom, false), (p_ana, 'Ana Teste', 'ana@' || dom, false),
    (p_bia, 'Bia Teste', 'bia@' || dom, false), (p_fora, 'Fora Teste', 'fora@' || dom, false);
  insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (p_ped, 'Operações · pessoa', 7, false), (p_ana, 'Operações · pessoa', 7, false),
    (p_bia, 'Operações · pessoa', 7, false), (p_fora, 'Operações · pessoa', 7, false);
  insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, motivo) values (p_ped, e1, null, 'Operações · pessoa', 'operar', 'teste assinatura'),
    (p_ana, e1, null, 'Operações · pessoa', 'ler', 'teste assinatura'), (p_bia, e1, null, 'Operações · pessoa', 'operar', 'teste assinatura'),
    (p_fora, e2, null, 'Operações · pessoa', 'operar', 'teste assinatura');
  insert into rt_chave.login (auth_uid, pseudonimo) values (u_ped, p_ped), (u_ana, p_ana), (u_bia, p_bia), (u_fora, p_fora);
  insert into ext.contraparte (empresa, tipo, nome) values (e1, 'cliente', 'Cliente Assinatura A') returning id into c1;
  insert into ext.contraparte (empresa, tipo, nome) values (e1, 'cliente', 'Cliente Assinatura B') returning id into c2;
  insert into auth.users (id, email, aud, role) values (x1, 'xa@cliente-a.' || dom, 'authenticated', 'authenticated'), (x2, 'xb@cliente-b.' || dom, 'authenticated', 'authenticated');
  insert into ext.usuario (auth_uid, contraparte, nome, perfil) values (x1, c1, 'Xavier Cliente A', 'gestor'), (x2, c2, 'Yara Cliente B', 'gestor');
  insert into doc.pedido (tipo, marca, empresa, conteudo, situacao) values ('nota-debito', m, e1, '{"titulo":"Contrato de teste da assinatura"}', 'emitido') returning id into dp;
  insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro, worker) values (dp, 'emitido', 1, encode(extensions.digest(pdf1, 'sha256'), 'hex'), '{}', 'teste') returning id into em1;
  insert into doc.arquivo values (em1, 'pdf', pdf1, encode(extensions.digest(pdf1, 'sha256'), 'hex'), length(pdf1));
  insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro, worker) values (dp, 'emitido', 1, encode(extensions.digest(pdf2, 'sha256'), 'hex'), '{}', 'teste') returning id into em2;
  insert into doc.arquivo values (em2, 'pdf', pdf2, encode(extensions.digest(pdf2, 'sha256'), 'hex'), length(pdf2));

  -- A1. o pedido grava o SHA-256 do PDF, nasce aguardando com código de verificação e a trilha começa; quem não opera na empresa não pede
  perform doc._testar_ass_como(u_fora);
  ok := false; begin perform doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana))); exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'FALHA A1: pediu sem acesso à empresa'; end if;
  perform doc._testar_ass_como(u_ped);
  ok := false; begin perform doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_fora))); exception when others then ok := sqlerrm like '%não tem acesso%'; end;
  if not ok then raise exception 'FALHA A1: signatário sem acesso à empresa aceito'; end if;
  r := doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana), jsonb_build_object('usuario', x1)), now() + interval '5 days');
  p1 := (r->>'id')::bigint;
  if r->>'hash_documento' <> encode(extensions.digest(pdf1, 'sha256'), 'hex') or r->>'situacao' <> 'aguardando' or r->>'codigo' !~ '^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$' then
    raise exception 'FALHA A1: pedido %', r; end if;
  if (select string_agg(tipo, ',' order by seq) from doc.assinatura_evento where pedido = p1) <> 'pedido,enviado' then raise exception 'FALHA A1: trilha inicial'; end if;
  select id into s_ana from doc.assinatura_signatario where pedido = p1 and pessoa = p_ana;
  select id into s_x1 from doc.assinatura_signatario where pedido = p1 and usuario = x1;

  -- A2. sem código não assina; sem aceite do consentimento também não
  perform doc._testar_ass_como(u_ana);
  ok := false; begin perform doc.assinatura_assinar(s_ana, '123456', true); exception when others then ok := sqlerrm like '%peça o código%'; end;
  if not ok then raise exception 'FALHA A2: assinou sem código'; end if;
  perform doc._testar_ass_como(null); cod := doc.assinatura_codigo_emitir(s_ana)->>'codigo';
  if cod !~ '^[0-9]{6}$' or exists (select 1 from doc.assinatura_codigo where signatario = s_ana and hash like '%' || cod || '%') then raise exception 'FALHA A2: código % ou guardado em claro', cod; end if;
  perform doc._testar_ass_como(u_ana);
  ok := false; begin perform doc.assinatura_assinar(s_ana, cod, false); exception when others then ok := sqlerrm like '%consentimento%'; end;
  if not ok then raise exception 'FALHA A2: assinou sem aceitar o consentimento'; end if;

  -- A3. código errado conta tentativa (e a contagem fica gravada); no limite o código é bloqueado e nem o certo passa
  for n in 1..4 loop
    r := doc.assinatura_assinar(s_ana, case when cod = '000000' then '111111' else '000000' end, true);
    if (r->>'assinado')::boolean or (r->>'restantes')::int <> 5 - n then raise exception 'FALHA A3: tentativa % %', n, r; end if;
  end loop;
  if (select tentativas from doc.assinatura_codigo where signatario = s_ana order by id desc limit 1) <> 4 then raise exception 'FALHA A3: tentativas não gravadas'; end if;
  r := doc.assinatura_assinar(s_ana, 'abc', true);
  if not (r->>'bloqueado')::boolean then raise exception 'FALHA A3: não bloqueou no limite %', r; end if;
  ok := false; begin perform doc.assinatura_assinar(s_ana, cod, true); exception when others then ok := sqlerrm like '%peça o código%'; end;
  if not ok then raise exception 'FALHA A3: código bloqueado ainda vale'; end if;
  if (select count(*) from doc.assinatura_evento where pedido = p1 and tipo in ('codigo_errado', 'codigo_bloqueado')) <> 5 then raise exception 'FALHA A3: tentativas fora da trilha'; end if;

  -- A4. código vencido é recusado; pedir outro antes de um minuto também
  perform doc._testar_ass_como(null);
  ok := false; begin perform doc.assinatura_codigo_emitir(s_ana); exception when others then ok := sqlerrm like '%aguarde um minuto%'; end;
  if not ok then raise exception 'FALHA A4: emitiu dois códigos no mesmo minuto'; end if;
  update doc.assinatura_codigo set criado_em = criado_em - interval '2 minutes' where signatario = s_ana;
  cod := doc.assinatura_codigo_emitir(s_ana)->>'codigo';
  update doc.assinatura_codigo set valido_ate = now() - interval '1 minute' where signatario = s_ana and usado_em is null and invalidado_em is null;
  perform doc._testar_ass_como(u_ana);
  ok := false; begin perform doc.assinatura_assinar(s_ana, cod, true); exception when others then ok := sqlerrm like '%vencido%'; end;
  if not ok then raise exception 'FALHA A4: código vencido aceito'; end if;

  -- A5. fora da vez: o segundo da ordem não pede código nem assina antes do primeiro
  perform doc._testar_ass_como(x1);
  ok := false; begin perform ext.assinatura_assinar(s_x1, '123456', true); exception when others then ok := sqlerrm like '%não é a sua vez%'; end;
  if not ok then raise exception 'FALHA A5: assinou fora da vez'; end if;
  ok := false; begin perform doc._assinatura_autorizar('codigo', jsonb_build_object('signatario', s_x1), null, x1); exception when others then ok := sqlerrm like '%não é a sua vez%'; end;
  if not ok then raise exception 'FALHA A5: código fora da vez autorizado'; end if;

  -- A6. código certo assina com as evidências (IP e navegador dos cabeçalhos, consentimento, hash); o último conclui
  perform doc._testar_ass_como(null);
  update doc.assinatura_codigo set criado_em = criado_em - interval '2 minutes' where signatario = s_ana;
  cod := doc.assinatura_codigo_emitir(s_ana)->>'codigo';
  perform set_config('request.headers', '{"x-forwarded-for":"203.0.113.7, 10.0.0.1","user-agent":"NavegadorDeTeste/1.0"}', true);
  perform doc._testar_ass_como(u_ana);
  r := doc.assinatura_assinar(s_ana, cod, true);
  if not (r->>'assinado')::boolean or (r->>'concluido')::boolean then raise exception 'FALHA A6: primeira assinatura %', r; end if;
  select evidencia into r from doc.assinatura_signatario where id = s_ana;
  if r->>'ip' <> '203.0.113.7' or r->>'agente' <> 'NavegadorDeTeste/1.0' or r->>'hash_documento' <> encode(extensions.digest(pdf1, 'sha256'), 'hex')
     or r->>'consentimento' not like '%Lei nº 14.063/2020%' or r->>'email' <> 'ana@' || dom or r->>'login' <> 'oauth' then raise exception 'FALHA A6: evidências %', r; end if;
  perform doc._testar_ass_como(null); cod := doc.assinatura_codigo_emitir(s_x1)->>'codigo';
  perform doc._testar_ass_como(x1);
  r := ext.assinatura_assinar(s_x1, cod, true);
  if not (r->>'concluido')::boolean or (select situacao from doc.assinatura_pedido where id = p1) <> 'concluido' then raise exception 'FALHA A6: não concluiu %', r; end if;
  perform set_config('request.headers', '', true);

  -- A7. documento alterado depois do pedido: nem código nem assinatura
  perform doc._testar_ass_como(u_ped);
  p2 := (doc.assinatura_pedir(em2, jsonb_build_array(jsonb_build_object('pessoa', p_ana)))->>'id')::bigint;
  perform doc._testar_ass_como(null); cod := doc.assinatura_codigo_emitir((select id from doc.assinatura_signatario where pedido = p2))->>'codigo';
  update doc.arquivo set conteudo = convert_to('%PDF-1.4 documento ALTERADO', 'UTF8') where emissao = em2 and formato = 'pdf';
  perform doc._testar_ass_como(u_ana);
  ok := false; begin perform doc.assinatura_assinar((select id from doc.assinatura_signatario where pedido = p2), cod, true); exception when others then ok := sqlerrm like '%mudou depois do pedido%'; end;
  if not ok then raise exception 'FALHA A7: assinou documento alterado'; end if;
  if not (doc._ass_json((select x from doc.assinatura_pedido x where id = p2), p_ana, null)->>'documento_alterado')::boolean then raise exception 'FALHA A7: tela não mostra a alteração'; end if;

  -- A8. trilha encadeada confere; não aceita alteração nem exclusão; adulteração por fora é detectada
  r := doc._ass_trilha(p1);
  if not (r->>'ok')::boolean or (r->>'eventos')::int < 10 then raise exception 'FALHA A8: trilha %', r; end if;
  if (select hash_anterior from doc.assinatura_evento where pedido = p1 and seq = 1) <> encode(extensions.digest(pdf1, 'sha256'), 'hex') then raise exception 'FALHA A8: primeiro elo'; end if;
  ok := false; begin update doc.assinatura_evento set dados = '{"x":1}' where pedido = p1 and seq = 3; exception when others then ok := sqlerrm like '%imutável%'; end;
  if not ok then raise exception 'FALHA A8: evento alterado'; end if;
  ok := false; begin delete from doc.assinatura_evento where pedido = p1 and seq = 3; exception when others then ok := sqlerrm like '%imutável%'; end;
  if not ok then raise exception 'FALHA A8: evento apagado'; end if;
  ok := false; begin update doc.assinatura_pedido set hash_documento = repeat('0', 64) where id = p1; exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A8: hash do pedido trocado'; end if;
  alter table doc.assinatura_evento disable trigger imutavel;
  update doc.assinatura_evento set dados = dados || '{"adulterado":true}' where pedido = p1 and seq = 3;
  alter table doc.assinatura_evento enable trigger imutavel;
  if (doc._ass_trilha(p1)->>'ok')::boolean then raise exception 'FALHA A8: adulteração não detectada'; end if;
  alter table doc.assinatura_evento disable trigger imutavel;
  update doc.assinatura_evento set dados = dados - 'adulterado' where pedido = p1 and seq = 3;
  alter table doc.assinatura_evento enable trigger imutavel;
  if not (doc._ass_trilha(p1)->>'ok')::boolean then raise exception 'FALHA A8: trilha não voltou'; end if;

  -- A9. recusa exige motivo e encerra o pedido para todos
  perform doc._testar_ass_como(u_ped);
  p3 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_bia), jsonb_build_object('pessoa', p_ana)))->>'id')::bigint;
  select id into s_bia from doc.assinatura_signatario where pedido = p3 and pessoa = p_bia;
  perform doc._testar_ass_como(u_bia);
  ok := false; begin perform doc.assinatura_recusar(s_bia, ' '); exception when others then ok := sqlerrm like '%motivo%'; end;
  if not ok then raise exception 'FALHA A9: recusou sem motivo'; end if;
  perform doc.assinatura_recusar(s_bia, 'Cláusula de prazo diferente do combinado');
  if (select situacao from doc.assinatura_pedido where id = p3) <> 'recusado' then raise exception 'FALHA A9: recusa não encerrou'; end if;
  perform doc._testar_ass_como(null);
  ok := false; begin perform doc.assinatura_codigo_emitir((select id from doc.assinatura_signatario where pedido = p3 and pessoa = p_ana)); exception when others then ok := sqlerrm like '%recusado%'; end;
  if not ok then raise exception 'FALHA A9: código depois da recusa'; end if;

  -- A10. cancelamento só por quem pediu, com motivo, e uma vez
  perform doc._testar_ass_como(u_ped);
  p4 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana)))->>'id')::bigint;
  perform doc._testar_ass_como(u_bia);
  ok := false; begin perform doc.assinatura_cancelar(p4, 'quero cancelar'); exception when others then ok := sqlerrm like '%só quem pediu%'; end;
  if not ok then raise exception 'FALHA A10: outra pessoa da empresa cancelou'; end if;
  perform doc._testar_ass_como(u_fora);
  ok := false; begin perform doc.assinatura_cancelar(p4, 'quero cancelar'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A10: pessoa de outra empresa cancelou'; end if;
  perform doc._testar_ass_como(u_ped);
  ok := false; begin perform doc.assinatura_cancelar(p4, ''); exception when others then ok := sqlerrm like '%motivo%'; end;
  if not ok then raise exception 'FALHA A10: cancelou sem motivo'; end if;
  perform doc.assinatura_cancelar(p4, 'Documento substituído por outra versão');
  ok := false; begin perform doc.assinatura_cancelar(p4, 'de novo'); exception when others then ok := true; end;
  if not ok or (select situacao from doc.assinatura_pedido where id = p4) <> 'cancelado' then raise exception 'FALHA A10: cancelado'; end if;

  -- A11. externo só vê e assina o que é dele; quem é de outra empresa não vê o painel
  perform doc._testar_ass_como(x2);
  r := ext.portal_assinaturas();
  if exists (select 1 from jsonb_array_elements(r->'pedidos') x where (x->>'id')::bigint = p1) then raise exception 'FALHA A11: externo viu pedido de outro'; end if;
  ok := false; begin perform ext.assinatura_documento(p1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A11: externo baixou documento de outro'; end if;
  ok := false; begin perform ext.assinatura_recusar(s_x1, 'não é meu'); exception when others then ok := sqlerrm like '%não é sua%'; end;
  if not ok then raise exception 'FALHA A11: externo respondeu por outro'; end if;
  perform doc._testar_ass_como(x1);
  r := ext.portal_assinaturas();
  if not exists (select 1 from jsonb_array_elements(r->'pedidos') x where (x->>'id')::bigint = p1 and x->>'situacao' = 'concluido') then raise exception 'FALHA A11: externo não vê o seu %', r; end if;
  if r::text like '%xa@cliente-a%' or r::text like '%ana@%' then raise exception 'FALHA A11: e-mail sem máscara no portal'; end if;
  perform doc._testar_ass_como(u_fora);
  ok := false; begin perform doc.painel_assinaturas(e1); exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'FALHA A11: painel de outra empresa'; end if;

  -- A12. exige ICP-Brasil: aqui ninguém assina nem recebe código; só se registra a assinatura qualificada feita fora; sem selo do IMTS
  perform doc._testar_ass_como(u_ped);
  p5 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana), jsonb_build_object('usuario', x1)), null, 'Termo para órgão que exige ICP-Brasil', true)->>'id')::bigint;
  perform doc._testar_ass_como(null);
  ok := false; begin perform doc.assinatura_codigo_emitir((select id from doc.assinatura_signatario where pedido = p5 and pessoa = p_ana)); exception when others then ok := sqlerrm like '%ICP-Brasil%'; end;
  if not ok then raise exception 'FALHA A12: código em pedido que exige ICP-Brasil'; end if;
  perform doc._testar_ass_como(u_ana);
  ok := false; begin perform doc.assinatura_assinar((select id from doc.assinatura_signatario where pedido = p5 and pessoa = p_ana), '123456', true); exception when others then ok := sqlerrm like '%ICP-Brasil%'; end;
  if not ok then raise exception 'FALHA A12: assinatura interna em pedido que exige ICP-Brasil'; end if;
  perform doc._testar_ass_como(u_ped);
  for s_bia in select id from doc.assinatura_signatario where pedido = p5 order by ordem loop
    perform doc.assinatura_registrar_fora(s_bia, 'PDF assinado com certificado ICP-Brasil em ' || to_char(current_date, 'DD/MM/YYYY'));
  end loop;
  if (select situacao from doc.assinatura_pedido where id = p5) <> 'concluido' then raise exception 'FALHA A12: registro de fora não concluiu'; end if;
  perform doc._testar_ass_como(null);
  if exists (select 1 from jsonb_array_elements(doc.assinatura_para_selar()) x where (x->>'pedido')::bigint = p5) then raise exception 'FALHA A12: pedido ICP-Brasil iria para o selo'; end if;

  -- A13. prazo: pedido vencido não aceita assinatura e a rotina o encerra com evento
  perform doc._testar_ass_como(u_ped);
  p6 := (doc.assinatura_pedir(em1, jsonb_build_array(jsonb_build_object('pessoa', p_ana)), now() + interval '2 hours')->>'id')::bigint;
  update doc.assinatura_pedido set prazo = now() - interval '1 minute' where id = p6;
  perform doc._testar_ass_como(u_ana);
  ok := false; begin perform doc.assinatura_assinar((select id from doc.assinatura_signatario where pedido = p6), '123456', true); exception when others then ok := sqlerrm like '%vencido%'; end;
  if not ok then raise exception 'FALHA A13: assinou pedido vencido'; end if;
  perform doc._testar_ass_como(null); perform doc.assinatura_rotina();
  if (select situacao from doc.assinatura_pedido where id = p6) <> 'vencido' or not exists (select 1 from doc.assinatura_evento where pedido = p6 and tipo = 'vencido') then
    raise exception 'FALHA A13: rotina não venceu o pedido'; end if;

  -- A14. selo: só com o manifesto registrado; fica imutável; a verificação pública mostra só nome e e-mail mascarado e compara o arquivo
  select c.kid into v_kid from doc.assinatura_chave c where c.ativa;
  if v_kid is null then
    v_kid := 'kidDeTesteDaAssinatura0123456789';
    if not doc.assinatura_chave_gravar(v_kid, '{"kty":"EC","crv":"P-256","x":"AAAA","y":"BBBB"}', '{"kty":"EC","crv":"P-256","x":"AAAA","y":"BBBB","d":"CCCC"}') then
      raise exception 'FALHA A14: chave não gravada'; end if;
    if rt._segredo('assinatura_chave_privada') is null then raise exception 'FALHA A14: chave privada fora do cofre'; end if;
  end if;
  select x->>'manifesto' into man from jsonb_array_elements(doc.assinatura_para_selar(p1)) x;
  if man is null or (man::jsonb)->'documento'->>'sha256' <> encode(extensions.digest(pdf1, 'sha256'), 'hex') or jsonb_array_length((man::jsonb)->'signatarios') <> 2 then
    raise exception 'FALHA A14: manifesto %', man; end if;
  ok := false; begin perform doc.assinatura_selar(p1, man || ' ', repeat('A', 86), v_kid, encode(pdf1, 'base64'), 'original_com_manifesto'); exception when others then ok := sqlerrm like '%manifesto diferente%'; end;
  if not ok then raise exception 'FALHA A14: selou manifesto diferente'; end if;
  r := doc.assinatura_selar(p1, man, repeat('A', 86), v_kid, encode(pdf1 || convert_to(' pagina de manifesto', 'UTF8'), 'base64'), 'original_com_manifesto');
  ok := false; begin update doc.assinatura_selo set assinatura = repeat('B', 86) where pedido = p1; exception when others then ok := sqlerrm like '%imutável%'; end;
  if not ok then raise exception 'FALHA A14: selo alterado'; end if;
  r := doc.assinatura_verificacao(lower(replace((select codigo from doc.assinatura_pedido where id = p1), '-', '')), encode(extensions.digest(pdf1, 'sha256'), 'hex'));
  if not (r->>'encontrado')::boolean or r->>'confere_arquivo' <> 'original' or not (r->'trilha'->>'integra')::boolean or not (r->>'manifesto_confere')::boolean
     or r->'signatarios'->0->>'email' <> 'an***@' || dom or (r->'signatarios')::text like '%203.0.113.7%' then raise exception 'FALHA A14: verificação %', r; end if;
  if doc.assinatura_verificacao((select codigo from doc.assinatura_pedido where id = p1), repeat('f', 64))->>'confere_arquivo' <> 'diferente'
     or (doc.assinatura_verificacao('ZZZZ-ZZZZ-ZZZZ')->>'encontrado')::boolean then raise exception 'FALHA A14: arquivo diferente ou código inexistente'; end if;

  -- A15. permissões: anon não executa nada novo; quem tem login não emite código, não sela, não verifica pelo banco nem lê os códigos
  if exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname in ('doc', 'ext') and (p.proname like '%assinatura%' or p.proname like '\_ass\_%')
              and has_function_privilege('anon', p.oid, 'execute')) then raise exception 'FALHA A15: anon executa função da assinatura'; end if;
  if has_function_privilege('authenticated', 'doc.assinatura_codigo_emitir(bigint)', 'execute') or has_function_privilege('authenticated', 'doc.assinatura_selar(bigint, text, text, text, text, text)', 'execute')
     or has_function_privilege('authenticated', 'doc.assinatura_verificacao(text, text)', 'execute') or has_table_privilege('authenticated', 'doc.assinatura_codigo', 'select') then
    raise exception 'FALHA A15: login comum com função de serviço'; end if;
  perform doc._testar_ass_como(u_ana);
  ok := false; begin perform doc.assinatura_codigo_emitir(s_ana); exception when others then ok := sqlerrm like '%chave de serviço%'; end;
  if not ok then raise exception 'FALHA A15: código emitido com login'; end if;

  perform doc._testar_ass_como(null); perform set_config('request.headers', '', true);
  return 'assinatura: ' || n_testes || ' de ' || n_testes || ' ok';
end $$;
revoke all on function doc._testar_assinatura() from public, anon, authenticated;

-- a rodada única passa a ter 23 suítes
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido', 'adm._testar_servidor', 'doc._testar_nota_debito', 'adm._testar_integracoes',
                           'rt._testar_papeis_acumulados', 'doc._testar_assinatura'] loop
    begin
      execute format('select %s()', s) into msg;
      raise exception using errcode = 'P0099', message = msg;
    exception when sqlstate 'P0099' then res := res || jsonb_build_object(s, jsonb_build_object('ok', true, 'resultado', sqlerrm));
              when others then res := res || jsonb_build_object(s, jsonb_build_object('ok', false, 'resultado', sqlerrm));
    end;
  end loop;
  return jsonb_build_object('todas_ok', not exists (select 1 from jsonb_each(res) e where not (e.value->>'ok')::boolean), 'suites', res);
end $f$;
-- a rodada só roda pela chave de serviço (num banco com o perfil de produção ela nasce de novo aqui, sem o endurecimento)
revoke all on function adm.testar_tudo() from public, anon, authenticated;
commit;
