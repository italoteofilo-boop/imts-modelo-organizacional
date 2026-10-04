-- Testes do acervo (E17) como função; rodam dentro de adm.testar_tudo(), que desfaz tudo.
begin;
create or replace function acervo._testar_acervo() returns text language plpgsql set search_path = '' as $$
declare emp uuid := '54d1ee0e-6ee3-4557-9a47-fdac1d7afc48'; a1 uuid; a2 uuid; leitor uuid; r jsonb; r2 jsonb; ok boolean; base text := '112223330001';
  v_cnpj text; cnpj_inv text; f bigint; d bigint; arq bigint;
  h text;
begin
  select pessoa into a1 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa where p.papel = 'Administrador do IMTS.OS' limit 1;
  select pessoa into a2 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa where p.papel = 'Sócios' limit 1;
  select pessoa into leitor from rt.acesso where nivel = 'ler' limit 1;
  v_cnpj := acervo._cnpj_formatar(base || acervo._cnpj_dv(base));
  cnpj_inv := acervo._cnpj_formatar(base || case when acervo._cnpj_dv(base) = '00' then '01' else '00' end);
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);

  -- X1. Cartão CNPJ reconhecido pelo texto, vai para 01 Societário e propõe CNPJ e razão social
  h := encode(extensions.digest('cartao-teste-1', 'sha256'), 'hex');
  r := acervo.registrar(emp, 'documento.pdf', h, 'application/pdf', 1000,
        'COMPROVANTE DE INSCRIÇÃO E DE SITUAÇÃO CADASTRAL NÚMERO DE INSCRIÇÃO ' || v_cnpj || E'\nNOME EMPRESARIAL: EMPRESA TESTE DE CREDITO LTDA\nTÍTULO DO ESTABELECIMENTO', 'upload', null, null, a1);
  if r->>'tipo' <> 'cartao-cnpj' or r->>'pasta' <> '01' or jsonb_array_length(r->'campos_propostos') <> 2 then raise exception 'FALHA X1: classificação ou extração (%)', r; end if;
  arq := (r->>'arquivo')::bigint;

  -- X2. Mesmo arquivo de novo: recusado como duplicado, sem segunda linha
  r2 := acervo.registrar(emp, 'outro-nome.pdf', h, 'application/pdf', 1000, 'qualquer', 'upload', null, null, a1);
  if r2->>'situacao' <> 'duplicado' or (select count(*) from acervo.arquivo where empresa = emp and hash = h) <> 1 then raise exception 'FALHA X2: duplicado aceito'; end if;

  -- X3. Texto sem tipo reconhecido vai para triagem; pessoa classifica; histórico registra
  r := acervo.registrar(emp, 'abc.pdf', encode(extensions.digest('sem-tipo', 'sha256'), 'hex'), 'application/pdf', 10, 'lista de compras do mercado', 'upload', null, null, a1);
  if r->>'situacao' <> 'triagem' or r->>'pasta' <> '99' then raise exception 'FALHA X3: devia ir para triagem (%)', r; end if;
  r2 := acervo.classificar((r->>'arquivo')::bigint, 'certidao', null, a1);
  if r2->>'pasta' <> '02' or not exists (select 1 from adm.historico where objeto = 'acervo' and chave = 'arquivo ' || (r->>'arquivo')) then raise exception 'FALHA X3: classificação manual'; end if;

  -- X4. Nota fiscal com o mesmo número: a nova é versão da anterior, que fica substituída (nada se apaga)
  r := acervo.registrar(emp, 'nf.pdf', encode(extensions.digest('nf-1', 'sha256'), 'hex'), 'application/pdf', 10, E'NOTA FISCAL DE SERVIÇO ELETRÔNICA\nNúmero: 000123\nValor total da nota: R$ 1.500,00', 'upload', null, null, a1);
  perform acervo.confirmar_local((r->>'arquivo')::bigint, 'drive-teste-1', a1);
  r2 := acervo.registrar(emp, 'nf-corrigida.pdf', encode(extensions.digest('nf-2', 'sha256'), 'hex'), 'application/pdf', 10, E'NOTA FISCAL DE SERVIÇO ELETRÔNICA\nNúmero: 123\nValor total da nota: R$ 1.600,00', 'upload', null, null, a1);
  if (r2->>'versao_de')::bigint is distinct from (r->>'arquivo')::bigint then raise exception 'FALHA X4: versão não reconhecida (%)', r2; end if;
  perform acervo.confirmar_local((r2->>'arquivo')::bigint, 'drive-teste-2', a1);
  if (select situacao from acervo.arquivo where id = (r->>'arquivo')::bigint) <> 'substituido' then raise exception 'FALHA X4: anterior não ficou substituída'; end if;
  if (r2->'extraido'->'valor_total'->>'valor') <> '1600.00' then raise exception 'FALHA X4: valor total (%)', r2->'extraido'; end if;

  -- X5. CNPJ com dígito errado não vira proposta
  r := acervo.registrar(emp, 'cartao2.pdf', encode(extensions.digest('cartao-invalido', 'sha256'), 'hex'), 'application/pdf', 10,
        'COMPROVANTE DE INSCRIÇÃO E DE SITUAÇÃO CADASTRAL ' || cnpj_inv, 'upload', null, null, a1);
  if exists (select 1 from jsonb_array_elements(r->'campos_propostos') e where e->>'chave' = 'cnpj') then raise exception 'FALHA X5: CNPJ inválido proposto'; end if;

  -- X6. Contrato social com outra razão social: divergência aberta, campos ficam divergentes
  r := acervo.registrar(emp, 'contrato social.pdf', encode(extensions.digest('cs-1', 'sha256'), 'hex'), 'application/pdf', 10,
        E'CONTRATO SOCIAL\nRazão social: CREDITO TESTE SOCIEDADE LTDA\nCNPJ ' || v_cnpj || E'\nOptante pelo Simples Nacional', 'upload', null, null, a1);
  select id into d from acervo.divergencia where empresa = emp and chave = 'razao_social' and situacao = 'aberta';
  if d is null or exists (select 1 from acervo.campo where empresa = emp and chave = 'razao_social' and situacao = 'proposto') then raise exception 'FALHA X6: divergência não aberta'; end if;
  if exists (select 1 from acervo.divergencia where empresa = emp and chave = 'cnpj' and situacao = 'aberta') then raise exception 'FALHA X6: mesmo CNPJ virou divergência'; end if;

  -- X7. Dado sensível: duas pessoas diferentes; a mesma não decide duas vezes; o aprovado vai para org.empresa
  select id into f from acervo.campo where empresa = emp and chave = 'cnpj' and situacao = 'proposto' order by id limit 1;
  r := acervo.decidir_campo(f, 'aprovado', 'confere com o cartão', a1);
  if r->>'situacao' <> 'proposto' then raise exception 'FALHA X7: uma pessoa bastou'; end if;
  ok := false; begin perform acervo.decidir_campo(f, 'aprovado', 'de novo', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA X7: a mesma pessoa decidiu duas vezes'; end if;
  r := acervo.decidir_campo(f, 'aprovado', 'conferido', a2);
  if r->>'situacao' <> 'aprovado' or (select cnpj from org.empresa where id = emp) <> v_cnpj then raise exception 'FALHA X7: aprovado não aplicado (%)', r; end if;

  -- X8. Divergência: escolher exige motivo; o escolhido volta a proposto e os outros saem
  ok := false; begin perform acervo.resolver_divergencia(d, (select id from acervo.campo where empresa = emp and chave = 'razao_social' order by id limit 1), ' ', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA X8: resolveu sem motivo'; end if;
  r := acervo.resolver_divergencia(d, (select id from acervo.campo where empresa = emp and chave = 'razao_social' order by id desc limit 1), 'o contrato social prevalece', a1);
  if (select count(*) from acervo.campo where empresa = emp and chave = 'razao_social' and situacao = 'proposto') <> 1
     or (select situacao from acervo.divergencia where id = d) <> 'resolvida' then raise exception 'FALHA X8: resolução'; end if;

  -- X9. Quem só lê não registra arquivo
  ok := false; begin perform acervo.registrar(emp, 'x.pdf', encode(extensions.digest('leitor', 'sha256'), 'hex'), 'application/pdf', 1, 'x', 'upload', null, null, leitor); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA X9: quem só lê registrou'; end if;

  -- X10. Regime vindo do contrato social é proposto (uma mão) e aprovado com uma decisão
  select id into f from acervo.campo where empresa = emp and chave = 'regime_tributario' and situacao = 'proposto';
  if f is null then raise exception 'FALHA X10: regime não extraído'; end if;
  r := acervo.decidir_campo(f, 'aprovado', 'conferido', a1);
  if r->>'situacao' <> 'aprovado' or (select regime_tributario from org.empresa where id = emp) <> 'Simples Nacional' then raise exception 'FALHA X10: regime (%)', r; end if;
  return 'acervo: 10 de 10 ok';
end $$;
revoke all on function acervo._testar_acervo() from public, anon, authenticated;

-- a rodada única passa a incluir o acervo
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo'] loop
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
