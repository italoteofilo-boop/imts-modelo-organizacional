-- Testes da 086 (agentes com IA real, B39). Não vai para produção: o perfil de produção apaga as funções _testar.
-- Rodar:  begin; select rt._testar_agentes_ia(); rollback;
-- Nenhuma chamada de rede: o resultado do provedor é simulado gravando direto pela função de conclusão (rt.agente_ia_concluir).
-- Também ajusta as suítes do motor assistido (062) e da automação R (079): elas conferem o cartão assistido de uma tarefa de
-- agente; passam a rodar com motor.agente_ia desligado e devolvem o valor anterior no fim.
begin;

-- instância real ou simulada, interativa, com o token já na tarefa pedida; anda um passo só
create or replace function rt._testar_agentes_ia_inst(p_tarefa bigint, p_simulado boolean) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_no rt.no; v_motor smallint; v_inst bigint;
begin
  select * into v_no from rt.no where tarefa = p_tarefa order by jornada, id limit 1;
  select circulo into v_motor from org.jornada where codigo = v_no.jornada;
  insert into rt.instancia (motor, jornada, simulado, inicio, relogio, versao_base, interativo)
  select v_motor, v_no.jornada, p_simulado, now(), now(), m.versao_base, true from rt.motor m where m.circulo = v_motor returning id into v_inst;
  insert into rt.token (instancia, no) values (v_inst, v_no.id);
  perform rt._avancar(v_inst, 1);
  return v_inst;
end $$;
revoke all on function rt._testar_agentes_ia_inst(bigint, boolean) from public, anon, authenticated;

create or replace function rt._testar_agentes_ia() returns text language plpgsql security definer set search_path = '' as $$
declare r jsonb := '[]'; ok boolean; inst bigint; x jsonb; t_age record; v_no text; f rt.fila_ia; k rt.cartao; p uuid; u_p uuid := gen_random_uuid();
  v_par jsonb := (select jsonb_object_agg(chave, valor) from adm.parametro where chave in ('motor.maquina_assistida', 'motor.agente_ia', 'motor.agente_ia_autonomo',
                  'motor.agente_ia_chamadas_dia', 'motor.agente_ia_tentativas', 'servidor.url_funcoes', 'ia.orcamento_mensal_tokens'));
  v_chave_oculta boolean := false; p_teste uuid; u_novo boolean := true; v_chave_criada boolean := false;
  dom text := adm.valor('login.dominios', '["imts.email"]') ->> 0;
begin
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  update adm.parametro set valor = 'true' where chave in ('motor.maquina_assistida', 'motor.agente_ia');
  update adm.parametro set valor = 'false' where chave = 'motor.agente_ia_autonomo';
  update adm.parametro set valor = '200' where chave = 'motor.agente_ia_chamadas_dia';
  update adm.parametro set valor = '2' where chave = 'motor.agente_ia_tentativas';
  update adm.parametro set valor = '2000000' where chave = 'ia.orcamento_mensal_tokens';
  update adm.parametro set valor = '"https://teste-agente.invalid/functions/v1"' where chave = 'servidor.url_funcoes';
  -- chave de teste no cofre (só quando não há uma; a suíte roda em transação desfeita)
  if rt._segredo('anthropic_chave') is null then perform vault.create_secret('chave-de-teste', 'anthropic_chave'); v_chave_criada := true; end if;

  -- tarefa de agente de prova, com a pessoa da raia (dono do cartão de revisão) e login para ler o rascunho
  select t.id, t.nome, t.raia, j.circulo as motor into t_age from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada
   where t.executor = 'A' and exists (select 1 from rt.no n where n.tarefa = t.id) and exists (select 1 from rt.fluxo fl join rt.no n on n.id = fl.de and n.jornada = fl.jornada where n.tarefa = t.id)
   order by t.id limit 1;
  if t_age.id is null then raise exception 'FALHA agentes IA: modelo sem tarefa de agente'; end if;
  p_teste := gen_random_uuid();
  insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (p_teste, 'Teste Agente IA', 'agente.ia.' || left(p_teste::text, 8) || '@' || dom, false);
  insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (p_teste, rt._raia_humana(t_age.raia), t_age.motor, false);
  -- o dono do cartão é quem o motor escolhe para a raia (pode ser alguém que já estava lá); precisa de login para ler o rascunho
  p := coalesce(rt._pessoa(rt._raia_humana(t_age.raia), t_age.motor), rt._pessoa('Líder do círculo', t_age.motor));
  if exists (select 1 from rt_chave.login where pseudonimo = p) then select auth_uid into u_p from rt_chave.login where pseudonimo = p limit 1; u_novo := false;
  else insert into rt_chave.login (auth_uid, pseudonimo) values (u_p, p); end if;

  -- I1. tarefa A assistida vira pedido na fila (prompt montado), o token espera e não há cartão
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  select * into f from rt.fila_ia where instancia = inst;
  r := r || jsonb_build_object('teste', 'tarefa A assistida vai à fila da IA', 'ok',
        f.id is not null and f.estado = 'pendente' and f.na_fila and f.tarefa = t_age.id
        and f.prompt like 'Tarefa: ' || t_age.nome || '%' and f.prompt like '%Jornada: %' and f.prompt like '%Etapa %' and f.prompt like '%Entradas da etapa:%'
        and f.contexto ? 'saidas'
        and exists (select 1 from rt.token where instancia = inst and no = f.no and estado = 'aguardando')
        and not exists (select 1 from rt.cartao where instancia = inst)
        and exists (select 1 from rt.evento where instancia = inst and tipo = 'delegado' and tarefa = t_age.id and resultado like 'ao agente de IA:%'));

  -- I2. a função pega o pedido: executando, com uma tentativa e a configuração do provedor
  x := rt.agente_ia_pegar(20);
  select * into f from rt.fila_ia where id = f.id;
  r := r || jsonb_build_object('teste', 'a função pega o lote', 'ok',
        f.estado = 'executando' and f.tentativas = 1
        and exists (select 1 from jsonb_array_elements(x->'itens') i where (i->>'id')::bigint = f.id and i->>'prompt' = f.prompt)
        and x->'config'->>'provedor' in ('anthropic', 'kimi'));

  -- I3. resultado do provedor (simulado) gera cartão de revisão com o rascunho; concluir o cartão faz o token seguir
  x := rt.agente_ia_concluir(f.id, E'## Resultado\nRascunho de teste.\n## Pendências\nnenhuma', 'anthropic', 'modelo-teste', 120, 80);
  select * into f from rt.fila_ia where id = f.id;
  select * into k from rt.cartao where id = f.cartao;
  ok := x->>'desfecho' = 'revisao' and f.estado = 'feito' and f.desfecho = 'revisao' and f.resultado like '%Rascunho de teste.%' and f.tokens_entrada = 120
        and k.id is not null and k.titulo = left('Revisar rascunho da IA: ' || t_age.nome, 200) and k.dono = p and k.tipo = 'fluxo' and k.no = f.no and k.origem = 'agente'
        and exists (select 1 from rt.token where instancia = inst and no = f.no and estado = 'aguardando')
        and exists (select 1 from adm.historico where objeto = 'agente_ia' and chave = 'fila:' || f.id and depois->>'desfecho' = 'revisao');
  -- quem é dono lê o rascunho; quem não tem acesso, não
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_p, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_p::text, true);
  x := rt.agente_ia_rascunho(k.id);
  ok := ok and x->>'rascunho' like '%Rascunho de teste.%' and x->>'provedor' = 'anthropic' and x->>'aviso' is not null;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  begin perform rt.agente_ia_rascunho(k.id); ok := false; exception when others then ok := ok and sqlerrm like '%sem acesso%'; end;
  perform rt.concluir_cartao(k.id, p);
  ok := ok and not exists (select 1 from rt.token where instancia = inst and no = f.no and estado = 'aguardando')
        and exists (select 1 from rt.evento where instancia = inst and cartao = k.id and tipo = 'concluido');
  r := r || jsonb_build_object('teste', 'resultado gera cartão de revisão e a revisão faz seguir', 'ok', ok);

  -- I4. modo autônomo: o agente conclui sem cartão e o token avança
  update adm.parametro set valor = 'true' where chave = 'motor.agente_ia_autonomo';
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  select * into f from rt.fila_ia where instancia = inst;
  perform rt.agente_ia_pegar(20);
  x := rt.agente_ia_concluir(f.id, 'Resultado pronto.', 'kimi', 'modelo-kimi', 50, 30);
  select * into f from rt.fila_ia where id = f.id;
  r := r || jsonb_build_object('teste', 'modo autônomo conclui e o token avança', 'ok',
        x->>'desfecho' = 'autonomo' and f.desfecho = 'autonomo' and f.cartao is null
        and exists (select 1 from rt.evento where instancia = inst and tarefa = t_age.id and tipo = 'fim' and resultado = 'concluída pelo agente de IA (kimi, sem revisão)' and executor = 'A')
        and not exists (select 1 from rt.token where instancia = inst and no = f.no)
        and not exists (select 1 from rt.cartao where instancia = inst and tarefa = t_age.id));
  update adm.parametro set valor = 'false' where chave = 'motor.agente_ia_autonomo';

  -- I5. falha nos dois provedores: volta à fila até esgotar as tentativas; esgotou, cartão humano com o motivo
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  select * into f from rt.fila_ia where instancia = inst;
  perform rt.agente_ia_pegar(20);
  x := rt.agente_ia_falhar(f.id, 'IA indisponível: anthropic: respondeu 500', false);
  ok := x->>'desfecho' = 'nova_tentativa' and (select estado from rt.fila_ia where id = f.id) = 'pendente';
  perform rt.agente_ia_pegar(20);
  x := rt.agente_ia_falhar(f.id, 'IA indisponível: anthropic: respondeu 500', false);
  select * into f from rt.fila_ia where id = f.id;
  r := r || jsonb_build_object('teste', 'falha nos provedores tenta de novo e depois cai no cartão', 'ok',
        ok and x->>'desfecho' = 'cartao_humano' and f.estado = 'erro' and f.tentativas = 2 and f.motivo like 'IA indisponível%'
        and exists (select 1 from rt.cartao where id = f.cartao and titulo like '%(assistida:%' and dono = p)
        and exists (select 1 from rt.evento where cartao = f.cartao and tipo = 'cartao_criado' and resultado like '%(agente de IA: IA indisponível%')
        and exists (select 1 from rt.token where instancia = inst and no = f.no and estado = 'aguardando'));

  -- I6. sem chave no cofre: cai direto no cartão humano, com o motivo registrado
  update vault.secrets set name = 'anthropic_chave__teste_oculta' where name = 'anthropic_chave'; v_chave_oculta := true;
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  select * into f from rt.fila_ia where instancia = inst;
  r := r || jsonb_build_object('teste', 'sem chave cai no cartão humano com o motivo', 'ok',
        f.estado = 'erro' and not f.na_fila and f.desfecho = 'cartao_humano' and f.motivo like 'nenhum provedor de IA configurado%'
        and exists (select 1 from rt.cartao where instancia = inst and id = f.cartao and titulo like '%(assistida:%')
        and exists (select 1 from rt.token where instancia = inst and no = f.no and estado = 'aguardando')
        and (adm.agente_ia_resumo()->>'disponivel')::boolean = false);
  update vault.secrets set name = 'anthropic_chave' where name = 'anthropic_chave__teste_oculta'; v_chave_oculta := false;

  -- I7. limite diário atingido: cartão humano com o motivo; pedido pendente também cai quando a função pega
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  select * into f from rt.fila_ia where instancia = inst;
  update adm.parametro set valor = '0' where chave = 'motor.agente_ia_chamadas_dia';
  x := rt.agente_ia_pegar(20);
  ok := (select desfecho from rt.fila_ia where id = f.id) = 'cartao_humano' and (x->>'degradados')::int >= 1;
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  r := r || jsonb_build_object('teste', 'limite diário leva ao cartão humano', 'ok',
        ok and exists (select 1 from rt.fila_ia where instancia = inst and not na_fila and motivo like 'limite diário de chamadas%')
        and exists (select 1 from rt.cartao where instancia = inst and titulo like '%(assistida:%'));
  update adm.parametro set valor = '200' where chave = 'motor.agente_ia_chamadas_dia';

  -- I8. desligado: comportamento antigo (cartão assistido, sem pedido na fila)
  update adm.parametro set valor = 'false' where chave = 'motor.agente_ia';
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  r := r || jsonb_build_object('teste', 'desligado mantém o cartão assistido', 'ok',
        not exists (select 1 from rt.fila_ia where instancia = inst)
        and exists (select 1 from rt.cartao where instancia = inst and tarefa = t_age.id and titulo like '%(assistida:%'));
  update adm.parametro set valor = 'true' where chave = 'motor.agente_ia';

  -- I9. instância simulada não muda: o adaptador simulado conclui, sem fila e sem cartão
  inst := rt._testar_agentes_ia_inst(t_age.id, true);
  r := r || jsonb_build_object('teste', 'instância simulada não muda', 'ok',
        not exists (select 1 from rt.fila_ia where instancia = inst)
        and exists (select 1 from rt.evento where instancia = inst and tarefa = t_age.id and resultado = 'concluída (simulado)')
        and not exists (select 1 from rt.cartao where instancia = inst));

  -- I10. modo assistido desligado (protótipo): nada muda
  update adm.parametro set valor = 'false' where chave = 'motor.maquina_assistida';
  inst := rt._testar_agentes_ia_inst(t_age.id, false);
  r := r || jsonb_build_object('teste', 'modo assistido desligado não muda', 'ok',
        not exists (select 1 from rt.fila_ia where instancia = inst)
        and exists (select 1 from rt.evento where instancia = inst and tarefa = t_age.id and resultado = 'concluída (simulado)'));
  update adm.parametro set valor = 'true' where chave = 'motor.maquina_assistida';

  -- I11. resumo, porta única e permissões (de fora ninguém mexe na fila nem conclui pedido)
  x := adm.agente_ia_resumo();
  r := r || jsonb_build_object('teste', 'resumo, porta única e permissões', 'ok',
        x ? 'por_estado' and x ? 'hoje' and (x->>'tarefas_a')::int = (select count(*) from org.tarefa where executor = 'A')
        and exists (select 1 from adm.api_funcao where nome = 'adm.agente_ia_resumo' and quem = 'interno')
        and not has_function_privilege('anon', 'adm.agente_ia_resumo()', 'execute')
        and not has_function_privilege('authenticated', 'rt.agente_ia_concluir(bigint, text, text, text, integer, integer)', 'execute')
        and not has_function_privilege('authenticated', 'rt.agente_ia_pegar(integer)', 'execute')
        and not has_function_privilege('authenticated', 'rt.agente_ia_falhar(bigint, text, boolean)', 'execute')
        and not has_function_privilege('authenticated', 'rt._agente_ia_enfileirar(bigint, text, bigint)', 'execute')
        and not has_table_privilege('authenticated', 'rt.fila_ia', 'select')
        and (select relrowsecurity from pg_class where oid = 'rt.fila_ia'::regclass));

  -- devolve parâmetros, chave e pessoa de teste
  if v_chave_oculta then update vault.secrets set name = 'anthropic_chave' where name = 'anthropic_chave__teste_oculta'; end if;
  if v_chave_criada then delete from vault.secrets where name = 'anthropic_chave' and secret = 'chave-de-teste'; end if;
  update adm.parametro a set valor = v_par->a.chave where v_par ? a.chave;
  update rt.pessoa set papel = 'Teste agente IA (encerrado)', circulo = null where pseudonimo = p_teste;
  if u_novo then delete from rt_chave.login where auth_uid = u_p; end if;

  if exists (select 1 from jsonb_array_elements(r) t where not (t->>'ok')::boolean) then
    raise exception 'FALHA agentes IA: %', (select string_agg(t->>'teste', '; ') from jsonb_array_elements(r) t where not (t->>'ok')::boolean); end if;
  return 'agentes IA: ' || jsonb_array_length(r) || ' de ' || jsonb_array_length(r) || ' ok';
end $$;
revoke all on function rt._testar_agentes_ia() from public, anon, authenticated;

-- suítes do motor assistido (062) e da automação R (079): conferem o cartão assistido da tarefa de agente; rodam com o agente de IA desligado
do $$
declare d text; a text;
begin
  if to_regprocedure('rt._testar_assistido()') is not null then
    d := pg_get_functiondef('rt._testar_assistido()'::regprocedure); a := d;
    if position('motor.agente_ia' in d) = 0 then
      d := replace(d, $q$  update adm.parametro set valor = 'true' where chave = 'motor.maquina_assistida';
$q$, $q$  update adm.parametro set valor = 'true' where chave = 'motor.maquina_assistida';
  -- o agente de IA (086) levaria a tarefa de agente à fila; aqui se confere o cartão assistido de antes
  perform set_config('teste.agente_ia', adm.valor('motor.agente_ia', 'true')::text, true);
  update adm.parametro set valor = 'false' where chave = 'motor.agente_ia';
$q$);
      d := replace(d, $q$  return 'motor assistido: 5 de 5 ok';$q$, $q$  update adm.parametro set valor = current_setting('teste.agente_ia')::jsonb where chave = 'motor.agente_ia';
  return 'motor assistido: 5 de 5 ok';$q$);
      if d = a or position('teste.agente_ia'')::jsonb' in d) = 0 then raise exception 'rt._testar_assistido não tem o texto esperado: revisar a 087'; end if;
      execute d;
    end if;
  end if;
  if to_regprocedure('rt._testar_automacao_r()') is not null then
    d := pg_get_functiondef('rt._testar_automacao_r()'::regprocedure); a := d;
    if position('motor.agente_ia' in d) = 0 then
      d := replace(d, $q$  -- R8. tarefa de agente não muda: continua cartão assistido
$q$, $q$  -- R8. tarefa de agente não muda: continua cartão assistido (com o agente de IA da 086 desligado)
  perform set_config('teste.agente_ia', adm.valor('motor.agente_ia', 'true')::text, true);
  update adm.parametro set valor = 'false' where chave = 'motor.agente_ia';
$q$);
      d := replace(d, $q$  -- R9. modo assistido desligado$q$, $q$  update adm.parametro set valor = current_setting('teste.agente_ia')::jsonb where chave = 'motor.agente_ia';
  -- R9. modo assistido desligado$q$);
      if d = a or position('teste.agente_ia'')::jsonb' in d) = 0 or position('(com o agente de IA da 086 desligado)' in d) = 0 then
        raise exception 'rt._testar_automacao_r não tem o texto esperado: revisar a 087'; end if;
      execute d;
    end if;
  end if;
end $$;
commit;
