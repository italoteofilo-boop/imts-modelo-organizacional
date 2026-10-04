-- Gerado de testar_mesa.sql: os testes da Mesa como função, para rodar no Supabase sem gravar nada.
-- Uso: do $$ begin raise exception '%', rt._testar_mesa(); end $$;
create or replace function rt._testar_mesa() returns text language plpgsql set search_path = '' as $f$
declare
  lider uuid; p1 uuid; p2 uuid; socio uuid; gov uuid; i bigint; c rt.cartao; v text; n int; k int; a bigint; b bigint; ok boolean;
begin
  select pseudonimo into lider from rt.pessoa where papel = 'Líder do círculo' and circulo = 1;
  select pseudonimo into p1 from rt.pessoa where papel = 'Identidade · pessoa' order by pseudonimo limit 1;
  select pseudonimo into p2 from rt.pessoa where papel = 'Identidade · pessoa' and pseudonimo <> p1 limit 1;
  select pseudonimo into socio from rt.pessoa where papel = 'Sócios' limit 1;
  select pseudonimo into gov from rt.pessoa where papel = 'Governança · pessoa' limit 1;

  -- M1. Iniciar uma jornada interativa: as tarefas de máquina rodam, a primeira de gente vira cartão a fazer
  i := rt.iniciar_jornada('ID-01', lider, true, 0.3);
  select * into c from rt.cartao where instancia = i and coluna = 'a_fazer' limit 1;
  if c.id is null then raise exception 'FALHA M1: nenhum cartão a fazer'; end if;
  if (select estado from rt.instancia where id = i) <> 'rodando' then raise exception 'FALHA M1: execução não ficou esperando'; end if;
  if not exists (select 1 from rt.evento where instancia = i and tipo = 'fim' and executor = 'A') then raise exception 'FALHA M1: tarefa de agente não rodou'; end if;

  -- M2. Cartão de fluxo não vai a feito arrastando, nem para decidir; vai de a fazer para fazendo
  ok := false; begin perform rt.mover_cartao(c.id, c.dono, 'esperando'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M2: cartão de fluxo foi para esperando arrastado'; end if;
  ok := false; begin perform rt.mover_cartao(c.id, c.dono, 'feito'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M2: cartão de fluxo foi para feito arrastado'; end if;
  perform rt.mover_cartao(c.id, c.dono, 'fazendo');

  -- M3. Só o dono conclui; ao concluir, o motor segue
  ok := false; begin perform rt.concluir_cartao(c.id, socio); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M3: quem não é dono concluiu'; end if;
  perform rt.concluir_cartao(c.id, c.dono);
  if (select coluna from rt.cartao where id = c.id) <> 'feito' then raise exception 'FALHA M3: não foi a feito'; end if;
  if (select count(*) from rt.cartao where instancia = i) < 2 and (select estado from rt.instancia where id = i) = 'rodando' then raise exception 'FALHA M3: o motor não seguiu'; end if;

  -- M4. Levar a execução até o fim, concluindo e decidindo (primeira opção)
  for k in 1..200 loop
    select * into c from rt.cartao where instancia = i and coluna <> 'feito' order by id limit 1;
    exit when c.id is null;
    if c.coluna = 'decidir' then perform rt.decidir_cartao(c.id, c.dono, c.opcoes->0->>'para');
    else perform rt.concluir_cartao(c.id, c.dono); end if;
  end loop;
  if (select estado from rt.instancia where id = i) <> 'concluida' then raise exception 'FALHA M4: execução terminou em %', (select estado || coalesce(' ' || detalhe, '') from rt.instancia where id = i); end if;
  if exists (select 1 from rt.token where instancia = i) then raise exception 'FALHA M4: sobrou token'; end if;
  -- as outras quatro jornadas da Identidade também vão até o fim pela Mesa
  for v in select codigo from org.jornada where circulo = 1 and codigo <> 'ID-01' loop
    i := rt.iniciar_jornada(v, lider, true, 0.6);
    for k in 1..300 loop
      select * into c from rt.cartao where instancia = i and coluna <> 'feito' order by id limit 1;
      exit when c.id is null;
      if c.coluna = 'decidir' then perform rt.decidir_cartao(c.id, c.dono, c.opcoes->0->>'para'); else perform rt.concluir_cartao(c.id, c.dono); end if;
    end loop;
    if (select estado from rt.instancia where id = i) <> 'concluida' then raise exception 'FALHA M4: % terminou em %', v, (select estado from rt.instancia where id = i); end if;
  end loop;

  -- M5. Motor em desenho não inicia jornada
  update rt.motor set estado = 'desenho' where circulo = 2;
  ok := false; begin perform rt.iniciar_jornada('ES-01', lider); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M5: iniciou jornada de motor em desenho'; end if;
  update rt.motor set estado = 'piloto' where circulo = 2;

  -- M6. Avulsa: sem prazo não entra; com prazo vai a a fazer e anda livre
  ok := false; begin perform rt.criar_avulsa(p1, 'Ligar para o contador', null); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M6: avulsa sem prazo entrou'; end if;
  a := rt.criar_avulsa(p1, 'Ligar para o contador sobre o regime', now() + interval '2 days');
  perform rt.mover_cartao(a, p1, 'esperando'); perform rt.mover_cartao(a, p1, 'fazendo');
  if (select coluna from rt.cartao where id = a) <> 'fazendo' then raise exception 'FALHA M6: avulsa não andou'; end if;
  if not exists (select 1 from rt.evento where cartao = a and tipo = 'cartao_criado') then raise exception 'FALHA M6: avulsa sem evento'; end if;

  -- M7. Delegar avulsa a colega: aceite pendente; só quem recebeu responde; aceita e conclui
  perform rt.delegar_cartao(a, p1, p2);
  if (select aceite from rt.cartao where id = a) <> 'pendente' then raise exception 'FALHA M7: sem aceite pendente'; end if;
  ok := false; begin perform rt.concluir_cartao(a, p2); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M7: concluiu antes de aceitar'; end if;
  ok := false; begin perform rt.responder_delegacao(a, socio, true); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M7: quem não recebeu respondeu'; end if;
  perform rt.responder_delegacao(a, p2, true, now() + interval '3 days');
  perform rt.concluir_cartao(a, p2);
  if (select coluna from rt.cartao where id = a) <> 'feito' then raise exception 'FALHA M7: delegado não concluiu'; end if;

  -- M8. Tarefa de fluxo só se delega na mesma raia (fora dela, só o líder)
  i := rt.iniciar_jornada('ID-01', lider, true, 0.3);
  select * into c from rt.cartao where instancia = i and coluna = 'a_fazer' limit 1;
  ok := false; begin perform rt.delegar_cartao(c.id, c.dono, socio); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M8: delegou fluxo para fora da raia'; end if;
  perform rt.delegar_cartao(c.id, c.dono, (select pseudonimo from rt.pessoa where papel = c.papel and pseudonimo <> c.dono limit 1));
  perform rt.delegar_cartao(c.id, lider, socio);  -- o líder pode
  if (select delegado_pessoa from rt.cartao where id = c.id) <> socio then raise exception 'FALHA M8: líder não delegou'; end if;

  -- M9. Agente não passa do modo da etapa; fazer e enviar conclui pelo agente
  select * into c from rt.cartao where instancia = i and coluna = 'a_fazer' and id <> c.id limit 1;
  i := rt.iniciar_jornada('ID-01', lider, true, 0.31);
  select * into c from rt.cartao where instancia = i and coluna = 'a_fazer' limit 1;   -- etapa 1 da ID-01 é Assistido (0)
  ok := false; begin perform rt.delegar_cartao(c.id, c.dono, null, true, 2::smallint); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA M9: agente passou do modo da etapa'; end if;
  perform rt.delegar_cartao(c.id, c.dono, null, true, 0::smallint);
  if not (select delegado_agente from rt.cartao where id = c.id) then raise exception 'FALHA M9: não delegou ao agente'; end if;

  -- M10. Privacidade: o quadro do círculo não mostra o título das avulsas; o meu quadro mostra
  b := rt.criar_avulsa(p1, 'Assunto pessoal reservado', now() + interval '1 day');
  if rt.quadro_circulo(1::smallint)::text like '%Assunto pessoal reservado%' then raise exception 'FALHA M10: avulsa aparece no quadro do círculo'; end if;
  if rt.quadro(p1)::text not like '%Assunto pessoal reservado%' then raise exception 'FALHA M10: avulsa some do meu quadro'; end if;
  if rt.quadro(p2)::text like '%Assunto pessoal reservado%' then raise exception 'FALHA M10: avulsa aparece para outra pessoa'; end if;
  if exists (select 1 from pg_policies where schemaname = 'rt' and tablename = 'cartao' and qual not like '%fluxo%') then raise exception 'FALHA M10: a API lê avulsas'; end if;

  -- M11. A captura sugere a jornada existente
  if rt.sugerir_jornada('registrar a versão e a data de vigência da declaração')->0->>'jornada' <> 'ID-01' then raise exception 'FALHA M11: não sugeriu ID-01'; end if;

  -- M12. Avulsa repetida por três pessoas vira sinal para a ID-04
  perform rt.criar_avulsa(p1, 'Atualizar o crachá', now() + interval '1 day');
  perform rt.criar_avulsa(p2, 'Atualizar  o crachá', now() + interval '1 day');
  perform rt.criar_avulsa(lider, 'atualizar o crachá', now() + interval '1 day');
  if not exists (select 1 from rt.v_avulsas_recorrentes where titulo = 'atualizar o crachá' and vezes = 3) then raise exception 'FALHA M12: repetição não apareceu'; end if;

  return 'MESA: 12 testes, 0 falhas';
end $f$;
revoke all on function rt._testar_mesa() from public;
