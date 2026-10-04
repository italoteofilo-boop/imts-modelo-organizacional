-- Testes de marca e modelos a partir das pastas (E18); rodam dentro de adm.testar_tudo(), que desfaz tudo.
begin;
create or replace function doc._testar_marca_modelos() returns text language plpgsql set search_path = '' as $$
declare emp uuid := '80d8f119-a3fc-40ce-afaa-34d974f25d31'; a1 uuid; a2 uuid; r jsonb; ok boolean; pr bigint; mi bigint; mi2 bigint; ped bigint; v_cnpj text; base text := '998887770001';
begin
  select pessoa into a1 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa where p.papel = 'Administrador do IMTS.OS' limit 1;
  select pessoa into a2 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa where p.papel = 'Sócios' limit 1;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);

  -- M1. Manual de marca no acervo vira proposta com as cores e a tipografia lidas do texto
  r := acervo.registrar(emp, 'manual da marca.pdf', encode(extensions.digest('manual-onni-teste', 'sha256'), 'hex'), 'application/pdf', 10,
        E'MANUAL DE IDENTIDADE VISUAL\nCor primária #1A2B3C e destaque #AA5500.\nTipografia principal: Montserrat\n', 'upload', null, null, a1);
  pr := (r->'derivado'->>'proposta_marca')::bigint;
  if pr is null or not coalesce((select '#1A2B3C' = any (cores) and 'Montserrat' = any (fontes) from doc.marca_proposta where id = pr), false)
    then raise exception 'FALHA M1: proposta de marca (%)', r; end if;

  -- M2. Duas mãos: a primeira escolhe os papéis; a mesma pessoa não decide de novo; a segunda não muda o que a primeira escolheu
  r := doc.decidir_marca(pr, 'aprovado', '{"primaria":"#1A2B3C","destaque":"#AA5500"}', '{"texto":"Montserrat","display":"Montserrat"}', 'conforme o manual', a1);
  if r->>'situacao' <> 'proposta' then raise exception 'FALHA M2: uma pessoa bastou'; end if;
  ok := false; begin perform doc.decidir_marca(pr, 'aprovado', null, null, 'de novo', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M2: a mesma pessoa decidiu duas vezes'; end if;
  ok := false; begin perform doc.decidir_marca(pr, 'aprovado', '{"primaria":"#000000"}', null, 'outra cor', a2); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M2: a segunda mudou os papéis'; end if;

  -- M3. Aprovada: o pacote de marca muda no banco e o histórico registra antes e depois
  r := doc.decidir_marca(pr, 'aprovado', null, null, 'conferido', a2);
  if r->>'situacao' <> 'aprovada' or (select dados->'cores'->>'primaria' from doc.marca where id = 'onni') <> '#1A2B3C'
     or (select dados->'tipografia'->>'texto' from doc.marca where id = 'onni') <> 'Montserrat' then raise exception 'FALHA M3: marca não aplicada (%)', r; end if;
  if not exists (select 1 from adm.historico where objeto = 'marca' and chave = 'onni' and depois->'dados'->'cores'->>'primaria' = '#1A2B3C') then raise exception 'FALHA M3: sem histórico da marca'; end if;

  -- M4. O worker recebe o pacote aprovado e o conteúdo do pedido não consegue trocá-lo
  ped := doc.pedir('resposta-externa', 'onni', '{"titulo":"t","data":"2026-10-04","local":"x","_marca_dados":{"id":"onni","cores":{"primaria":"#FFFFFF"}}}', emp);
  update doc.pedido set criado_em = '2000-01-01' where id = ped;
  -- sem a chave do worker no cofre (banco novo), M4 não se aplica
  if rt._segredo('doc_worker_chave') is not null then r := doc.worker_proximo(rt._segredo('doc_worker_chave'), 'teste'); end if;
  if rt._segredo('doc_worker_chave') is not null and (r->'_marca_dados'->'cores'->>'primaria') <> '#1A2B3C' then raise exception 'FALHA M4: worker sem a marca do banco (%)', r->'_marca_dados'->'cores'; end if;

  -- M5. Modelo de documento vira minuta em blocos (cláusula, item, alínea, parágrafo)
  r := acervo.registrar(emp, 'minuta contrato.docx', encode(extensions.digest('minuta-1', 'sha256'), 'hex'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 10,
        E'Minuta de contrato de cliente\nCLÁUSULA 1ª – OBJETO\n1.1 O objeto é a prestação de serviços.\na) primeira condição;\nTexto livre do contrato.', 'upload', null, null, a1);
  mi := (r->'derivado'->>'minuta')::bigint;
  if mi is null or (select jsonb_agg(b->>'t') from doc.minuta m, jsonb_array_elements(m.blocos) b where m.id = mi) <> '["p","secao","item","alinea","p"]'::jsonb
    then raise exception 'FALHA M5: blocos (%)', (select blocos from doc.minuta where id = mi); end if;
  if (select tipo from doc.minuta where id = mi) is distinct from 'contrato-cliente' then raise exception 'FALHA M5: tipo sugerido (%)', (select tipo from doc.minuta where id = mi); end if;

  -- M6. Quem subiu o modelo não aprova a minuta; minuta não aprovada não emite
  ok := false; begin perform doc.decidir_minuta(mi, 'aprovado', null, 'ok', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M6: quem subiu aprovou'; end if;
  ok := false; begin perform doc.pedir_minuta(mi, null, '2026-10-04', 'Fortaleza/CE', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M6: minuta em proposta emitiu'; end if;

  -- M7. Aprovada por outra pessoa; a próxima minuta do mesmo tipo substitui a anterior
  perform doc.decidir_minuta(mi, 'aprovado', null, 'confere com o padrão', a2);
  r := acervo.registrar(emp, 'minuta contrato v nova.docx', encode(extensions.digest('minuta-2', 'sha256'), 'hex'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 10,
        E'Minuta de contrato de cliente\nCLÁUSULA 1ª – OBJETO\n1.1 O objeto é a prestação de serviços de tecnologia.', 'upload', null, null, a1);
  mi2 := (r->'derivado'->>'minuta')::bigint;
  perform doc.decidir_minuta(mi2, 'aprovado', 'contrato-cliente', 'nova redação do objeto', a2);
  if (select situacao from doc.minuta where id = mi) <> 'substituida' or (select substitui from doc.minuta where id = mi2) <> mi then raise exception 'FALHA M7: substituição'; end if;

  -- M8. Minuta aprovada emite pelo motor: pedido na fila com os blocos e a marca da empresa
  ped := doc.pedir_minuta(mi2, 'Contrato de cliente', '2026-10-04', 'Fortaleza/CE', a1);
  if (select marca from doc.pedido where id = ped) <> 'onni' or (select jsonb_array_length(conteudo->'blocos') from doc.pedido where id = ped) <> 3
     or (select situacao from doc.pedido where id = ped) <> 'na_fila' then raise exception 'FALHA M8: pedido pela minuta'; end if;

  -- M9. Texto vira bloco sem perder conteúdo: a quantidade de linhas não vazias é a de blocos
  if jsonb_array_length(doc._texto_em_blocos(E'a\n\nb\nCláusula 2ª\n2.1 c')) <> 4 then raise exception 'FALHA M9: conversão perdeu linhas'; end if;

  -- M10. CNPJ aprovado no acervo vai para o pacote de marca da empresa e sai das inferências
  -- o CNPJ que a simulação tenha proposto para a empresa sai antes (o teste desfaz tudo no fim)
  delete from acervo.divergencia where empresa = emp and chave = 'cnpj'; delete from acervo.campo where empresa = emp and chave = 'cnpj';
  v_cnpj := acervo._cnpj_formatar(base || acervo._cnpj_dv(base));
  r := acervo.registrar(emp, 'cartao.pdf', encode(extensions.digest('cartao-onni-teste', 'sha256'), 'hex'), 'application/pdf', 10,
        'COMPROVANTE DE INSCRIÇÃO E DE SITUAÇÃO CADASTRAL ' || v_cnpj, 'upload', null, null, a1);
  perform acervo.decidir_campo((select id from acervo.campo where empresa = emp and chave = 'cnpj' and situacao = 'proposto' order by id desc limit 1), 'aprovado', 'confere', a1);
  perform acervo.decidir_campo((select id from acervo.campo where empresa = emp and chave = 'cnpj' and situacao = 'proposto' order by id desc limit 1), 'aprovado', 'confere', a2);
  if (select dados->>'cnpj' from doc.marca where id = 'onni') <> v_cnpj
     or exists (select 1 from doc.marca, jsonb_array_elements(dados->'inferencias') e where id = 'onni' and e::text ~* 'cnpj') then raise exception 'FALHA M10: CNPJ não chegou à marca'; end if;
  return 'marca e modelos: 10 de 10 ok';
end $$;
revoke all on function doc._testar_marca_modelos() from public, anon, authenticated;

create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos'] loop
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
