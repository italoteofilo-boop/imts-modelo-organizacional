-- Testes da experiência do parceiro (E19); rodam dentro de adm.testar_tudo(), que desfaz tudo.
begin;
create or replace function ext._testar_parceiro() returns text language plpgsql set search_path = '' as $$
declare emp uuid := '80d8f119-a3fc-40ce-afaa-34d974f25d31'; parc uuid; outro uuid; ges uuid; ope uuid; ges2 uuid; a1 uuid; a2 uuid;
  r jsonb; ok boolean; cod text; op bigint; op2 bigint; c1 bigint; c2 bigint; c3 bigint; pr bigint; base text := '334445550001'; v_cnpj text; tg bigint := 990077000111; n int;
begin
  select pessoa into a1 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa where p.papel = 'Administrador do IMTS.OS' limit 1;
  select pessoa into a2 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa where p.papel = 'Sócios' limit 1;
  select id into parc from ext.contraparte where empresa = emp and tipo = 'parceiro' and simulado limit 1;
  select id into outro from ext.contraparte where tipo = 'parceiro' and id <> parc limit 1;
  select auth_uid into ges from ext.usuario where contraparte = parc and perfil = 'gestor' limit 1;
  select auth_uid into ope from ext.usuario where contraparte = parc and perfil not in ('gestor', 'financeiro') limit 1;
  select auth_uid into ges2 from ext.usuario where contraparte = outro and perfil = 'gestor' limit 1;
  if ope is null or ges2 is null then raise exception 'FALHA P0: dados simulados insuficientes'; end if;
  v_cnpj := acervo._cnpj_formatar(base || acervo._cnpj_dv(base));
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);

  -- P1. Telegram: código do portal liga a conta; código errado e código já usado não ligam; quem não é ninguém recebe a orientação
  cod := ext.telegram_codigo_como(ges)->>'codigo';
  perform set_config('request.jwt.claim.sub', '', true);
  r := rt.receber_update(jsonb_build_object('update_id', 990077001, 'message', jsonb_build_object('message_id', 1, 'from', jsonb_build_object('id', tg), 'chat', jsonb_build_object('id', tg, 'type', 'private'), 'text', '/vincular ABCDEF12')), true);
  if (select texto from rt.fila_envio where id = (r->>'fila')::bigint) !~ 'inválido' then raise exception 'FALHA P1: código errado ligou'; end if;
  r := rt.receber_update(jsonb_build_object('update_id', 990077002, 'message', jsonb_build_object('message_id', 2, 'from', jsonb_build_object('id', tg), 'chat', jsonb_build_object('id', tg, 'type', 'private'), 'text', '/vincular ' || cod)), true);
  if (select texto from rt.fila_envio where id = (r->>'fila')::bigint) !~ '^Pronto' or (select telegram_id from ext.telegram where auth_uid = ges) <> tg then raise exception 'FALHA P1: vínculo'; end if;
  if (select codigo_hash from ext.telegram where auth_uid = ges) is not null then raise exception 'FALHA P1: código ficou guardado depois do uso'; end if;
  r := rt.receber_update(jsonb_build_object('update_id', 990077003, 'message', jsonb_build_object('message_id', 3, 'from', jsonb_build_object('id', tg + 1), 'chat', jsonb_build_object('id', tg + 1, 'type', 'private'), 'text', 'oi')), true);
  if (select texto from rt.fila_envio where id = (r->>'fila')::bigint) !~ '/vincular' then raise exception 'FALHA P1: desconhecido sem orientação'; end if;

  -- P2. Oportunidade registrada pelo Telegram; a identidade de fora não fica valendo depois
  r := rt.receber_update(jsonb_build_object('update_id', 990077004, 'message', jsonb_build_object('message_id', 4, 'from', jsonb_build_object('id', tg), 'chat', jsonb_build_object('id', tg, 'type', 'private'),
        'text', '/oportunidade Hospital Teste Parceiro | Implantação do prontuário | detalhe do negócio')), true);
  select id into op from ext.oportunidade where contraparte = parc and cliente_final = 'Hospital Teste Parceiro';
  if op is null or (select texto from rt.fila_envio where id = (r->>'fila')::bigint) !~ 'registrada' then raise exception 'FALHA P2: oportunidade pelo Telegram (%)', (select texto from rt.fila_envio where id = (r->>'fila')::bigint); end if;
  if coalesce(current_setting('request.jwt.claim.sub', true), '') <> '' then raise exception 'FALHA P2: identidade de fora ficou ativa'; end if;
  if (select empresa from rt.cartao where id = (select cartao from ext.pedido where id = (select pedido from ext.oportunidade where id = op))) is distinct from emp then raise exception 'FALHA P2: cartão sem empresa'; end if;

  -- P3. Sala: o parceiro escreve; outro parceiro não entra; a IMTS responde e o parceiro é avisado no Telegram
  perform ext.sala_enviar_como(ope, op, 'Cliente pediu reunião na semana que vem.');
  perform set_config('request.jwt.claim.sub', '', true);
  ok := false; begin perform ext.sala_enviar_como(ges2, op, 'intruso'); exception when others then ok := true; end;
  perform set_config('request.jwt.claim.sub', '', true);
  if not ok then raise exception 'FALHA P3: outro parceiro escreveu na sala'; end if;
  perform ext.sala_responder(op, 'Agenda confirmada para terça.', a1);
  if not exists (select 1 from rt.fila_envio where chat_ref = 'tg:' || tg and texto ~ 'Agenda confirmada') then raise exception 'FALHA P3: parceiro não avisado'; end if;
  if (select count(*) from ext.sala_mensagem where oportunidade = op) <> 2 then raise exception 'FALHA P3: mensagens da sala'; end if;

  -- P4. Ganho gera a carteira prevista pela regra do contrato (10% simulado, sobre cada parcela)
  ok := false; begin perform ext.oportunidade_decidir(op, 'ganha', null, 3, date '2026-11-01', null, a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA P4: ganhou sem valor'; end if;
  r := ext.oportunidade_decidir(op, 'ganha', 12000, 3, date '2026-11-15', null, a1);
  if (r->>'comissoes')::int <> 3 or (select sum(valor) from ext.comissao where oportunidade = op) <> 1200 or (select min(competencia) from ext.comissao where oportunidade = op) <> date '2026-11-01'
    then raise exception 'FALHA P4: carteira prevista (%)', r; end if;
  ok := false; begin perform ext.oportunidade_decidir(op, 'perdida', null, null, null, 'mudou', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA P4: oportunidade ganha voltou a mudar'; end if;
  select id into c1 from ext.comissao where oportunidade = op and parcela = 1; select id into c2 from ext.comissao where oportunidade = op and parcela = 2; select id into c3 from ext.comissao where oportunidade = op and parcela = 3;

  -- P5. Carteira: o gestor vê; o operacional não
  r := ext.portal_parceiro_como(ges); perform set_config('request.jwt.claim.sub', '', true);
  if (r->'carteira'->'totais'->'prevista'->>'quantidade')::int <> 3 or (r->'contrato'->>'simulado')::boolean is not true then raise exception 'FALHA P5: carteira do gestor (%)', r->'carteira'->'totais'; end if;
  r := ext.portal_parceiro_como(ope); perform set_config('request.jwt.claim.sub', '', true);
  if r->'carteira' <> 'null'::jsonb or r->'prestacoes' <> 'null'::jsonb then raise exception 'FALHA P5: operacional viu a carteira'; end if;

  -- P6. Parcela recebida: comissão adquirida (uma vez só)
  perform ext.comissao_adquirir(c1, a1); perform ext.comissao_adquirir(c2, a1);
  ok := false; begin perform ext.comissao_adquirir(c1, a1); exception when others then ok := true; end;
  if not ok or (select count(*) from ext.comissao where oportunidade = op and situacao = 'adquirida') <> 2 then raise exception 'FALHA P6: aquisição'; end if;

  -- P7. Nota sem CNPJ do parceiro cadastrado: divergente, nada reservado, vai para a pasta 07 do acervo
  update ext.contraparte set documento = null where id = parc;   -- o teste parte de parceiro sem CNPJ (desfeito no fim)
  r := ext.prestacao_enviar_como(ges, 'nf', 'nf 777.pdf', encode(extensions.digest('nf-parceiro-1', 'sha256'), 'hex'), 'application/pdf', 100,
        E'NOTA FISCAL DE SERVIÇO ELETRÔNICA\nPrestador CNPJ ' || v_cnpj || E'\nNúmero: 000777\nValor total da nota: R$ 800,00', array[c1, c2]);
  perform set_config('request.jwt.claim.sub', '', true);
  if r->>'situacao' <> 'divergente' or not exists (select 1 from jsonb_array_elements(r->'conferencia') e where e->>'regra' = 'cnpj' and not (e->>'ok')::boolean)
     or (select prestacao from ext.comissao where id = c1) is not null then raise exception 'FALHA P7: devia divergir no CNPJ (%)', r->'conferencia'; end if;
  if (select pasta from acervo.arquivo where id = (r->>'arquivo')::bigint) <> '07' or (select enviado_por_externo from acervo.arquivo where id = (r->>'arquivo')::bigint) <> ges then raise exception 'FALHA P7: acervo'; end if;
  ok := false; begin perform ext.contraparte_documento(parc, base || case when acervo._cnpj_dv(base) = '00' then '01' else '00' end, a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA P7: CNPJ com dígito errado aceito'; end if;
  perform ext.contraparte_documento(parc, v_cnpj, a1);

  -- P8. Nota certa: conferida pela máquina, comissões reservadas, cartão para a Gestão com a empresa
  r := ext.prestacao_enviar_como(ges, 'nf', 'nf 777 v2.pdf', encode(extensions.digest('nf-parceiro-2', 'sha256'), 'hex'), 'application/pdf', 100,
        E'NOTA FISCAL DE SERVIÇO ELETRÔNICA\nPrestador CNPJ ' || v_cnpj || E'\nNúmero: 000777\nValor total da nota: R$ 800,00', array[c1, c2]);
  perform set_config('request.jwt.claim.sub', '', true);
  pr := (r->>'prestacao')::bigint;
  if r->>'situacao' <> 'conferida' or (select prestacao from ext.comissao where id = c2) <> pr or (select numero from ext.prestacao where id = pr) <> '777'
    then raise exception 'FALHA P8: conferência (%)', r->'conferencia'; end if;
  if (select empresa from rt.cartao where id = (select cartao from ext.prestacao where id = pr)) is distinct from emp then raise exception 'FALHA P8: cartão sem empresa'; end if;

  -- P9. Mesmo número de novo e comissão não adquirida: divergente; o mesmo arquivo de novo: recusado
  r := ext.prestacao_enviar_como(ges, 'nf', 'nf 777 v3.pdf', encode(extensions.digest('nf-parceiro-3', 'sha256'), 'hex'), 'application/pdf', 100,
        E'NOTA FISCAL\nCNPJ ' || v_cnpj || E'\nNúmero: 777\nValor total da nota: R$ 400,00', array[c3]);
  perform set_config('request.jwt.claim.sub', '', true);
  if r->>'situacao' <> 'divergente' or (select count(*) from jsonb_array_elements(r->'conferencia') e where not (e->>'ok')::boolean) < 2 then raise exception 'FALHA P9: número repetido (%)', r->'conferencia'; end if;
  ok := false; begin perform ext.prestacao_enviar_como(ges, 'nf', 'copia.pdf', encode(extensions.digest('nf-parceiro-2', 'sha256'), 'hex'), 'application/pdf', 100, 'x', array[c3]); exception when others then ok := true; end;
  perform set_config('request.jwt.claim.sub', '', true);
  if not ok then raise exception 'FALHA P9: arquivo repetido aceito'; end if;

  -- P10. O operacional não presta contas
  ok := false; begin perform ext.prestacao_enviar_como(ope, 'relatorio', 'rel.pdf', encode(extensions.digest('rel-ope', 'sha256'), 'hex'), 'application/pdf', 10, 'Relatório de atividades', '{}'); exception when others then ok := true; end;
  perform set_config('request.jwt.claim.sub', '', true);
  if not ok then raise exception 'FALHA P10: operacional enviou prestação'; end if;

  -- P11. Aprovada por uma pessoa, paga por outra: comissões a pagar e depois pagas; cartões fechados
  ok := false; begin perform ext.prestacao_decidir(pr, 'recusado', ' ', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA P11: recusa sem motivo'; end if;
  perform ext.prestacao_decidir(pr, 'aprovado', 'confere', a1);
  if (select count(*) from ext.comissao where prestacao = pr and situacao = 'a_pagar') <> 2 then raise exception 'FALHA P11: a pagar'; end if;
  ok := false; begin perform ext.prestacao_pagar(pr, 'TED 123', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA P11: quem aprovou pagou'; end if;
  perform ext.prestacao_pagar(pr, 'TED 123', a2);
  if (select count(*) from ext.comissao where prestacao = pr and situacao = 'paga') <> 2 or (select situacao from ext.prestacao where id = pr) <> 'paga'
     or (select coluna from rt.cartao where id = (select cartao from ext.prestacao where id = pr)) <> 'feito' then raise exception 'FALHA P11: pagamento'; end if;

  -- P12. Telegram: carteira, anexo vai para o portal, desligar
  r := rt.receber_update(jsonb_build_object('update_id', 990077005, 'message', jsonb_build_object('message_id', 5, 'from', jsonb_build_object('id', tg), 'chat', jsonb_build_object('id', tg, 'type', 'private'), 'text', '/carteira')), true);
  if (select texto from rt.fila_envio where id = (r->>'fila')::bigint) !~ 'paga: 2' then raise exception 'FALHA P12: carteira (%)', (select texto from rt.fila_envio where id = (r->>'fila')::bigint); end if;
  r := rt.receber_update(jsonb_build_object('update_id', 990077006, 'message', jsonb_build_object('message_id', 6, 'from', jsonb_build_object('id', tg), 'chat', jsonb_build_object('id', tg, 'type', 'private'), 'caption', 'nota', 'document', jsonb_build_object('file_id', 'x'))), true);
  if (select texto from rt.fila_envio where id = (r->>'fila')::bigint) !~ 'pelo portal' then raise exception 'FALHA P12: anexo pelo Telegram'; end if;
  r := rt.receber_update(jsonb_build_object('update_id', 990077007, 'message', jsonb_build_object('message_id', 7, 'from', jsonb_build_object('id', tg), 'chat', jsonb_build_object('id', tg, 'type', 'private'), 'text', '/desligar')), true);
  if (select vinculado_em from ext.telegram where auth_uid = ges) is not null then raise exception 'FALHA P12: desligar'; end if;
  if exists (select 1 from rt.mensagem where chat_ref = 'tg:' || tg) then raise exception 'FALHA P12: conversa de fora gravada'; end if;
  return 'parceiro: 12 de 12 ok';
end $$;
revoke all on function ext._testar_parceiro() from public, anon, authenticated;

create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro'] loop
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
