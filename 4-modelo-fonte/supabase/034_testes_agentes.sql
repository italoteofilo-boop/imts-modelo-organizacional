-- Testes dos agentes residentes (E15) como função; rodar sem gravar nada: do $$ begin raise exception '%', rt._testar_agentes(); end $$;
begin;
create or replace function rt._testar_agentes() returns text language plpgsql set search_path = '' as $$
declare r jsonb; c bigint; n int; adm1 uuid; ok boolean; cA uuid; u uuid; pid bigint; m bigint; v_dono uuid;
begin
  select pessoa into adm1 from rt.acesso where nivel = 'administrar' order by papel limit 1;
  select a.dono into v_dono from rt.agente_residente a where codigo = 'guardiao-prazos-operacoes';
  -- isola o teste: os residentes só veem o que o teste cria
  update rt.agente_residente set ligado = true, liberado = true where codigo in ('guardiao-prazos-operacoes', 'atendente-externo', 'vigia-vencimentos');
  update rt.cartao set coluna = 'feito' where coluna <> 'feito' and prazo < now();
  update ext.pedido set situacao = 'encerrado' where situacao = 'recebido';

  -- G1. Três residentes, com dono, círculo, modo e memória do dono
  if (select count(*) from rt.agente_residente) < 3 or exists (select 1 from rt.agente_residente where dono is null) then raise exception 'FALHA G1: residentes incompletos'; end if;
  if (select count(*) from rt.agente_memoria where autor = 'pessoa') < 4 then raise exception 'FALHA G1: memória do dono ausente'; end if;

  -- G2. Vigia de prazos (copiloto): cartão vencido no círculo vira aviso ao dono do agente, uma vez só
  c := rt.criar_avulsa(rt._pessoa('Operações · pessoa', 7::smallint), 'Entrega teste atrasada', now() + interval '1 hour', null, 'mesa', null);
  update rt.cartao set prazo = now() - interval '2 hours' where id = c;
  r := rt.agente_executar('guardiao-prazos-operacoes', 'teste');
  if r->>'situacao' <> 'ok' or (r->>'acoes')::int < 1 then raise exception 'FALHA G2: não agiu (%)', r; end if;
  if not exists (select 1 from rt.cartao where dono = v_dono and origem = 'agente' and titulo like 'Prazo vencido: Entrega teste atrasada%') then raise exception 'FALHA G2: aviso não chegou ao dono'; end if;
  r := rt.agente_executar('guardiao-prazos-operacoes', 'teste');
  if r->>'situacao' <> 'sem_acao' then raise exception 'FALHA G2: repetiu o aviso (%)', r; end if;

  -- G3. A memória governa: a pessoa desativa a nota e o agente volta a avisar
  select id into m from rt.agente_memoria where agente = 'guardiao-prazos-operacoes' and chave = 'cartao:' || c;
  ok := false; begin perform rt.agente_memoria_editar(m, null, false, '', adm1); exception when others then ok := true; end; if not ok then raise exception 'FALHA G3: editou sem motivo'; end if;
  perform rt.agente_memoria_editar(m, null, false, 'avisar de novo', adm1);
  r := rt.agente_executar('guardiao-prazos-operacoes', 'teste');
  if (r->>'acoes')::int < 1 then raise exception 'FALHA G3: memória editada não mudou o comportamento'; end if;

  -- G4. Modo assistido: só sugere, não cria cartão nem gasta orçamento
  update rt.agente_residente set modo = 'Assistido' where codigo = 'guardiao-prazos-operacoes';
  c := rt.criar_avulsa(rt._pessoa('Operações · pessoa', 7::smallint), 'Outra entrega atrasada', now() + interval '1 hour', null, 'mesa', null);
  update rt.cartao set prazo = now() - interval '1 hour' where id = c;
  select count(*) into n from rt.cartao where origem = 'agente';
  r := rt.agente_executar('guardiao-prazos-operacoes', 'teste');
  if (select count(*) from rt.cartao where origem = 'agente') <> n then raise exception 'FALHA G4: assistido criou cartão'; end if;
  if (select n_acoes from rt.agente_execucao where id = (r->>'execucao')::bigint) <> 0 then raise exception 'FALHA G4: assistido gastou orçamento'; end if;

  -- G5. Desligado, sem liberação ou com a chave geral desligada: não age
  perform rt.agente_ligar('guardiao-prazos-operacoes', false, 'teste de desligar', adm1);
  if rt.agente_executar('guardiao-prazos-operacoes', 'teste')->>'situacao' <> 'desligada' then raise exception 'FALHA G5: agiu desligado'; end if;
  if not exists (select 1 from adm.historico where objeto = 'agente' and chave = 'guardiao-prazos-operacoes') then raise exception 'FALHA G5: sem histórico'; end if;
  perform rt.agente_ligar('guardiao-prazos-operacoes', true, 'religar', adm1);
  update rt.agente_residente set liberado = false where codigo = 'guardiao-prazos-operacoes';
  if rt.agente_executar('guardiao-prazos-operacoes', 'teste')->>'situacao' <> 'bloqueada' then raise exception 'FALHA G5: agiu sem liberação'; end if;
  update rt.agente_residente set liberado = true where codigo = 'guardiao-prazos-operacoes';
  update adm.parametro set valor = 'false' where chave = 'agentes.ligados';
  if rt.agente_executar('guardiao-prazos-operacoes', 'teste')->>'situacao' <> 'desligada' then raise exception 'FALHA G5: chave geral ignorada'; end if;
  update adm.parametro set valor = 'true' where chave = 'agentes.ligados';
  ok := false; begin perform rt.agente_ligar('guardiao-prazos-operacoes', false, 'x', rt._pessoa('Operações · pessoa', 7::smallint)); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA G5: quem não administra desligou'; end if;

  -- G6. Orçamento esgotado: para e avisa o dono uma vez
  update rt.agente_residente set modo = 'Copiloto', orcamento_acoes_mes = 1 where codigo = 'guardiao-prazos-operacoes';
  r := rt.agente_executar('guardiao-prazos-operacoes', 'teste');
  if r->>'situacao' <> 'bloqueada' or r->>'detalhe' !~ 'orçamento' then raise exception 'FALHA G6: não parou no orçamento (%)', r; end if;
  if (select count(*) from rt.cartao where origem = 'agente' and titulo like '%orçamento de ações do mês esgotado') <> 1 then raise exception 'FALHA G6: aviso do orçamento'; end if;
  perform rt.agente_executar('guardiao-prazos-operacoes', 'teste');
  if (select count(*) from rt.cartao where origem = 'agente' and titulo like '%orçamento de ações do mês esgotado') <> 1 then raise exception 'FALHA G6: repetiu o aviso do orçamento'; end if;

  -- G7. Atendente (autopiloto): confirma recebimento, área e prazo; nunca dá o pedido por respondido
  select id into cA from ext.contraparte where simulado and tipo = 'cliente' order by nome limit 1;
  select auth_uid into u from ext.usuario where contraparte = cA and perfil = 'gestor' limit 1;
  pid := ext.pedir_como(u, 'chamado', 'Sistema lento', 'O painel demora para abrir.');
  r := rt.agente_executar('atendente-externo', 'teste');
  if (select situacao from ext.pedido where id = pid) <> 'em_atendimento' then raise exception 'FALHA G7: não confirmou'; end if;
  if (select resposta from ext.pedido where id = pid) !~ 'Operações' or (select respondido_por from ext.pedido where id = pid) !~ 'agente residente' then raise exception 'FALHA G7: resposta sem área ou sem autoria'; end if;
  r := rt.agente_executar('atendente-externo', 'teste');
  if r->>'situacao' <> 'sem_acao' then raise exception 'FALHA G7: tratou em dobro'; end if;

  -- G8. Atendente em copiloto: rascunho para a pessoa aprovar, sem responder ao externo
  update rt.agente_residente set modo = 'Copiloto' where codigo = 'atendente-externo';
  pid := ext.pedir_como(u, 'duvida', 'Prazo do contrato', 'Qual é a vigência?');
  perform rt.agente_executar('atendente-externo', 'teste');
  if (select situacao from ext.pedido where id = pid) <> 'recebido' then raise exception 'FALHA G8: copiloto respondeu sozinho'; end if;
  select id into c from rt.cartao where origem = 'agente' and titulo like 'Confirmar a resposta automática ao pedido ' || pid || '%';
  if c is null then raise exception 'FALHA G8: sem rascunho para aprovar'; end if;
  perform rt.agente_executar('atendente-externo', 'teste');
  if (select count(*) from rt.cartao where origem = 'agente' and titulo like 'Confirmar a resposta automática ao pedido ' || pid || '%') <> 1 then raise exception 'FALHA G8: rascunho em dobro'; end if;
  perform rt.agente_aprovar_rascunho(c, (select a.dono from rt.agente_residente a where a.codigo = 'atendente-externo'));
  if (select situacao from ext.pedido where id = pid) <> 'em_atendimento' or (select coluna from rt.cartao where id = c) <> 'feito' then raise exception 'FALHA G8: aprovação do rascunho não enviou'; end if;

  -- G9. Vigia de vencimentos: mudança de parâmetro parada há mais de 24 horas vira aviso
  insert into adm.mudanca (chave, valor, motivo, pedido_por, pedido_em) values ('simulacao.retencao_dias', '45', 'teste', adm1, now() - interval '2 days') returning id into m;
  r := rt.agente_executar('vigia-vencimentos', 'teste');
  if not exists (select 1 from rt.agente_memoria where agente = 'vigia-vencimentos' and chave = 'mudanca:' || m) then raise exception 'FALHA G9: não viu a mudança parada (%)', r; end if;

  -- G10. Painel: agentes com execuções e memória, sem expor nada de fora do registro
  if jsonb_array_length(adm.painel_completo()->'agentes') < 3 then raise exception 'FALHA G10: painel sem agentes'; end if;
  return 'agentes: 10 de 10 ok';
end $$;
revoke all on function rt._testar_agentes() from public;
commit;
