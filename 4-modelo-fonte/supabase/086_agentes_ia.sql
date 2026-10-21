-- Agentes com IA real para as tarefas de agente (executor A), B39 (21/10/2026).
-- Problema: no modo assistido (062) toda tarefa A de instância real e interativa virava cartão para uma pessoa do círculo,
-- porque não havia adaptador de IA. A função ia (070) já fala com dois provedores (Anthropic e Kimi, com reserva).
-- Regra nova, ligada pelo parâmetro motor.agente_ia (padrão: ligado):
--   tarefa A no modo assistido -> pedido na fila rt.fila_ia (prompt montado com tarefa, jornada, etapa, entradas, saídas e o que
--   já foi feito na instância); o token fica aguardando, como no cartão.
--   A função agente (nova, verify_jwt desligado, chamada pelo banco com X-IMTS-Chave) consome a fila, chama o provedor pelo
--   mesmo código da função ia (que continua com verify_jwt ligado, por causa do login) e grava o resultado como rascunho:
--     padrão: cartão de REVISÃO para a pessoa da raia, com o rascunho ligado ao cartão (rt.agente_ia_rascunho); concluir o
--     cartão faz o token seguir, como em qualquer cartão de fluxo;
--     motor.agente_ia_autonomo ligado: o agente conclui a tarefa sem revisão e o token segue.
--   Sem provedor configurado, sem endereço das funções, limite diário atingido, orçamento mensal esgotado ou falha nos dois
--   provedores (depois de motor.agente_ia_tentativas): cai no cartão humano de antes, com o motivo registrado.
-- Instância simulada, modo assistido desligado e o parâmetro desligado seguem como antes.
-- Como: rt._avancar ganha um trecho mínimo (troca conferida, como na 078) que chama rt._agente_ia_enfileirar.
-- Auditoria: rt.evento (delegado ao agente, cartão criado, fim), adm.historico (objeto agente_ia, desfecho de cada pedido)
-- e adm.registro_servidor (cada chamada da função, com tokens; conta no orçamento mensal ia.orcamento_mensal_tokens).
begin;

-- ---------- histórico: objeto novo ----------
do $$
declare v_def text; v_lista text[];
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint where conname = 'historico_objeto_check' and conrelid = 'adm.historico'::regclass;
  v_lista := array(select m[1] from regexp_matches(coalesce(v_def, ''), '''([a-z_]+)''', 'g') m);
  if not ('agente_ia' = any (v_lista)) then
    v_lista := v_lista || 'agente_ia'::text;
    alter table adm.historico drop constraint if exists historico_objeto_check;
    execute format('alter table adm.historico add constraint historico_objeto_check check (objeto in (%s))',
                   (select string_agg(quote_literal(x), ', ') from unnest(v_lista) x));
  end if;
end $$;

-- ---------- parâmetros ----------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('motor.agente_ia', 'global', 'Modo assistido: tarefa de agente (A) vai à fila da IA (função agente) em vez de virar cartão; sem IA disponível, volta ao cartão',
  'booleano', 'true', 'true', '{}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_autonomo', 'global', 'Agente de IA conclui a tarefa sem revisão humana; desligado, o rascunho vira cartão de revisão para a pessoa da raia',
  'booleano', 'false', 'false', '{}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_chamadas_dia', 'global', 'Limite diário de pedidos ao agente de IA (horário de Fortaleza); atingido, a tarefa vira cartão humano',
  'inteiro', '200', '200', '{"min": 0, "max": 100000}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_tokens_dia', 'global', 'Limite diário de tokens do agente de IA (entrada mais saída); atingido, a tarefa vira cartão humano',
  'inteiro', '400000', '400000', '{"min": 0, "max": 100000000}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_tentativas', 'global', 'Tentativas por pedido quando os provedores falham; esgotadas, a tarefa vira cartão humano',
  'inteiro', '2', '2', '{"min": 1, "max": 5}', true, '{}', 'Agentes com IA real (B39), 21/10/2026')
on conflict (chave) do nothing;

-- ---------- fila ----------
create table if not exists rt.fila_ia (
  id             bigint generated always as identity primary key,
  instancia      bigint not null references rt.instancia(id),
  no             text not null,
  tarefa         bigint not null references org.tarefa(id),
  circulo        smallint not null,
  jornada        text not null,
  etapa          bigint references org.etapa(id),
  prompt         text not null,
  contexto       jsonb not null default '{}',
  na_fila        boolean not null,                  -- false: nem entrou na fila (IA indisponível na hora), foi direto ao cartão
  estado         text not null default 'pendente' check (estado in ('pendente', 'executando', 'feito', 'erro', 'cancelado')),
  tentativas     int not null default 0,
  resultado      text,                              -- rascunho devolvido pela IA
  provedor       text,
  modelo         text,
  tokens_entrada int,
  tokens_saida   int,
  motivo         text,                              -- por que caiu no cartão humano ou voltou à fila
  desfecho       text check (desfecho in ('revisao', 'autonomo', 'cartao_humano')),
  cartao         bigint references rt.cartao(id),
  criado_em      timestamptz not null default now(),
  iniciado_em    timestamptz,
  concluido_em   timestamptz
);
create index if not exists fila_ia_pendente on rt.fila_ia (id) where estado in ('pendente', 'executando');
create index if not exists fila_ia_instancia on rt.fila_ia (instancia);
create index if not exists fila_ia_cartao on rt.fila_ia (cartao) where cartao is not null;
create index if not exists fila_ia_criado on rt.fila_ia (criado_em);
create unique index if not exists fila_ia_um_por_no on rt.fila_ia (instancia, no) where estado in ('pendente', 'executando');
alter table rt.fila_ia enable row level security;   -- sem política: ninguém lê pela API; o Admin vê pelo resumo e a pessoa pelo rascunho do seu cartão
revoke all on rt.fila_ia from public, anon, authenticated;
grant all on rt.fila_ia to service_role;

-- ---------- uso do dia (horário de Fortaleza) ----------
create or replace function rt._agente_ia_uso_hoje() returns jsonb language sql stable security definer set search_path = '' as $$
  with h as (select date_trunc('day', now() at time zone 'America/Fortaleza') at time zone 'America/Fortaleza' as ini)
  select jsonb_build_object(
    'chamadas', (select coalesce(sum(greatest(f.tentativas, 1)), 0) from rt.fila_ia f, h where f.na_fila and f.criado_em >= h.ini),
    'tokens', (select coalesce(sum(coalesce(f.tokens_entrada, 0) + coalesce(f.tokens_saida, 0)), 0) from rt.fila_ia f, h where f.concluido_em >= h.ini)) $$;

-- ---------- a IA está disponível? devolve o motivo quando não está ----------
create or replace function rt._agente_ia_indisponivel(p_checar_endereco boolean default true) returns text
language plpgsql stable security definer set search_path = '' as $$
declare u jsonb := rt._agente_ia_uso_hoje(); lim_c bigint; lim_t bigint; teto bigint;
begin
  if rt._segredo('anthropic_chave') is null
     and (rt._segredo('kimi_chave') is null or coalesce(adm.valor('ia.kimi_url', '""') #>> '{}', '') = '' or coalesce(adm.valor('ia.kimi_modelo', '""') #>> '{}', '') = '') then
    return 'nenhum provedor de IA configurado (falta anthropic_chave ou kimi_chave no cofre)'; end if;
  if p_checar_endereco and rt._url_funcao('agente') is null then
    return 'endereço das funções não configurado (servidor.url_funcoes)'; end if;
  lim_c := coalesce((adm.valor('motor.agente_ia_chamadas_dia', '200') #>> '{}')::bigint, 200);
  if (u->>'chamadas')::bigint >= lim_c then return 'limite diário de chamadas do agente de IA atingido (' || lim_c || ')'; end if;
  lim_t := coalesce((adm.valor('motor.agente_ia_tokens_dia', '400000') #>> '{}')::bigint, 400000);
  if (u->>'tokens')::bigint >= lim_t then return 'limite diário de tokens do agente de IA atingido (' || lim_t || ')'; end if;
  teto := coalesce((adm.valor('ia.orcamento_mensal_tokens', '0') #>> '{}')::bigint, 0);
  if adm._ia_usado_no_mes() >= teto then return 'orçamento mensal da IA esgotado (ia.orcamento_mensal_tokens)'; end if;
  return null;
end $$;

-- ---------- prompt: só o que o modelo e a instância já têm (sem nome de pessoa) ----------
create or replace function rt._agente_ia_prompt(p_inst bigint, p_tarefa bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare t record; v text; ctx jsonb;
begin
  select tf.id, tf.nome, tf.raia, tf.ordem, tf.condicao, e.id as etapa_id, e.numero, e.nome as etapa_nome, e.modo::text as modo, e.risco::text as risco,
         j.codigo, j.nome as jornada_nome, j.objetivo, c.nome as circulo_nome
    into t from org.tarefa tf join org.etapa e on e.id = tf.etapa join org.jornada j on j.codigo = e.jornada left join org.circulo c on c.numero = j.circulo
   where tf.id = p_tarefa;
  ctx := jsonb_build_object(
    'tarefa', t.nome, 'papel', t.raia, 'jornada', t.codigo, 'etapa', t.numero, 'circulo', t.circulo_nome,
    'entradas', (select coalesce(jsonb_agg(jsonb_build_object('produto', produto, 'origem', origem) order by id), '[]') from org.entrada where etapa = t.etapa_id),
    'saidas', (select coalesce(jsonb_agg(jsonb_build_object('produto', produto, 'destinos', destinos) order by id), '[]') from org.saida where etapa = t.etapa_id),
    'tarefas_da_etapa', (select coalesce(jsonb_agg(x.nome || ' (' || x.executor || ')' order by x.ordem), '[]') from org.tarefa x where x.etapa = t.etapa_id),
    'feito_na_instancia', (select coalesce(jsonb_agg(y.nome order by y.id), '[]') from (
        select ev.id, tx.nome from rt.evento ev join org.tarefa tx on tx.id = ev.tarefa
         where ev.instancia = p_inst and ev.tipo in ('fim', 'concluido') and ev.tarefa is not null order by ev.id desc limit 30) y),
    'rascunhos_anteriores', (select coalesce(jsonb_agg(jsonb_build_object('tarefa', z.nome, 'texto', left(z.resultado, 1500)) order by z.id), '[]') from (
        select f.id, tx.nome, f.resultado from rt.fila_ia f join org.tarefa tx on tx.id = f.tarefa
         where f.instancia = p_inst and f.estado = 'feito' and f.resultado is not null order by f.id desc limit 3) z));
  v := 'Tarefa: ' || t.nome || E'\n'
    || 'Papel: ' || t.raia || coalesce(' (círculo ' || t.circulo_nome || ')', '') || E'\n'
    || 'Jornada: ' || t.codigo || ' ' || t.jornada_nome || coalesce(E'\nObjetivo da jornada: ' || t.objetivo, '') || E'\n'
    || 'Etapa ' || t.numero || ': ' || t.etapa_nome || ' (modo ' || coalesce(t.modo, '?') || ', risco ' || coalesce(t.risco, '?') || ')' || E'\n'
    || coalesce('Condição da tarefa: ' || t.condicao || E'\n', '')
    || E'\nEntradas da etapa:\n' || coalesce((select string_agg('- ' || (e->>'produto') || ' (vem de ' || (e->>'origem') || ')', E'\n') from jsonb_array_elements(ctx->'entradas') e), '- nenhuma registrada')
    || E'\n\nSaídas esperadas da etapa:\n' || coalesce((select string_agg('- ' || (s->>'produto') || ' (para ' || array_to_string(array(select jsonb_array_elements_text(s->'destinos')), ', ') || ')', E'\n') from jsonb_array_elements(ctx->'saidas') s), '- nenhuma registrada')
    || E'\n\nTarefas da etapa, em ordem:\n' || coalesce((select string_agg('- ' || x, E'\n') from jsonb_array_elements_text(ctx->'tarefas_da_etapa') x), '- nenhuma')
    || E'\n\nJá feito nesta instância (mais recente primeiro):\n' || coalesce((select string_agg('- ' || x, E'\n') from jsonb_array_elements_text(ctx->'feito_na_instancia') x), '- nada ainda')
    || coalesce(E'\n\nRascunhos anteriores do agente nesta instância:\n' || (select string_agg('### ' || (r->>'tarefa') || E'\n' || (r->>'texto'), E'\n\n') from jsonb_array_elements(ctx->'rascunhos_anteriores') r), '');
  return jsonb_build_object('prompt', left(v, 20000), 'contexto', ctx);
end $$;

-- ---------- pede à função agente que consuma a fila (pelo pg_net, depois do commit); sem endereço, a rotina tenta depois ----------
create or replace function rt._agente_ia_chamar() returns bigint language plpgsql security definer set search_path = '' as $$
declare u text := rt._url_funcao('agente');
begin
  if u is null or rt._segredo('imts_funcao_chave') is null or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then return null; end if;
  return net.http_post(url := u, headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{"acao":"agente_executar"}'::jsonb, timeout_milliseconds := 120000);
end $$;

-- ---------- cartão para pessoa: revisão do rascunho, ou o cartão humano de antes (com o motivo) ----------
create or replace function rt._agente_ia_cartao(p_fila bigint, p_revisao boolean, p_motivo text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_ia; ins rt.instancia; v_tar record; v_dono uuid; v_card bigint; v_ini timestamptz;
begin
  select * into f from rt.fila_ia where id = p_fila;
  select * into ins from rt.instancia where id = f.instancia;
  select t.id, t.nome, t.raia, t.executor, e.id as etapa_id into v_tar from org.tarefa t join org.etapa e on e.id = t.etapa where t.id = f.tarefa;
  v_dono := coalesce(rt._pessoa(rt._raia_humana(v_tar.raia), ins.motor), rt._pessoa('Líder do círculo', ins.motor));
  v_ini := greatest(coalesce(ins.relogio, now()), now());
  insert into rt.cartao (tipo, titulo, circulo, instancia, no, jornada, etapa, tarefa, papel, dono, criado_por, origem, prazo, simulado)
  values ('fluxo',
          case when p_revisao then left('Revisar rascunho da IA: ' || v_tar.nome, 200) else v_tar.nome || ' (assistida: ' || lower(v_tar.raia) || ')' end,
          ins.motor, ins.id, f.no, ins.jornada, v_tar.etapa_id, v_tar.id, v_tar.raia, v_dono, v_dono, case when p_revisao then 'agente' else 'motor' end,
          v_ini + make_interval(mins => coalesce((select max_minutos from rt.parametro_simulacao where executor = 'P'), 240)::int), false)
  returning id into v_card;
  perform rt._ev(ins.id, v_card, 'cartao_criado',
                 case when p_revisao then 'revisar rascunho da IA: ' || v_tar.nome else left('a fazer: ' || v_tar.nome || coalesce(' (agente de IA: ' || p_motivo || ')', ''), 500) end,
                 v_dono, ins.motor, ins.jornada, v_tar.etapa_id, v_tar.id, 'A', v_ini, null, false);
  update rt.fila_ia set cartao = v_card where id = p_fila;
  return v_card;
end $$;

-- ---------- auditoria do desfecho de cada pedido ----------
create or replace function rt._agente_ia_auditar(p_fila bigint, p_antes text, p_motivo text) returns void
language sql security definer set search_path = '' as $$
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  select 'agente_ia', 'fila:' || f.id, jsonb_build_object('estado', p_antes),
         jsonb_build_object('estado', f.estado, 'desfecho', f.desfecho, 'instancia', f.instancia, 'tarefa', f.tarefa, 'cartao', f.cartao,
                            'provedor', f.provedor, 'modelo', f.modelo, 'tentativas', f.tentativas, 'tokens_entrada', f.tokens_entrada, 'tokens_saida', f.tokens_saida),
         null, 'motor', left(p_motivo, 1000)
    from rt.fila_ia f where f.id = p_fila $$;

-- ---------- entrada: chamada por rt._avancar quando a tarefa A cai no modo assistido ----------
-- Devolve true quando cuidou da tarefa (pedido na fila, ou cartão humano com o motivo); false quando o fluxo segue como antes.
create or replace function rt._agente_ia_enfileirar(p_inst bigint, p_no text, p_tarefa bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare ins rt.instancia; v_tar record; v_motivo text; p jsonb; v_id bigint;
begin
  if not coalesce((adm.valor('motor.agente_ia', 'true') #>> '{}')::boolean, true) then return false; end if;
  select * into ins from rt.instancia where id = p_inst;
  if ins.id is null or ins.simulado or not ins.interativo then return false; end if;
  select t.id, t.nome, t.executor, e.id as etapa_id into v_tar from org.tarefa t join org.etapa e on e.id = t.etapa where t.id = p_tarefa;
  if v_tar.id is null or v_tar.executor <> 'A' then return false; end if;

  v_motivo := rt._agente_ia_indisponivel(true);
  p := rt._agente_ia_prompt(p_inst, p_tarefa);
  insert into rt.fila_ia (instancia, no, tarefa, circulo, jornada, etapa, prompt, contexto, na_fila, estado, motivo, desfecho, concluido_em)
  values (p_inst, p_no, p_tarefa, ins.motor, ins.jornada, v_tar.etapa_id, p->>'prompt', p->'contexto', v_motivo is null,
          case when v_motivo is null then 'pendente' else 'erro' end, v_motivo,
          case when v_motivo is not null then 'cartao_humano' end, case when v_motivo is not null then now() end)
  returning id into v_id;
  insert into rt.token (instancia, no, estado) values (p_inst, p_no, 'aguardando');
  if v_motivo is not null then
    -- IA indisponível: o cartão humano de antes, com o motivo no evento e no pedido
    perform rt._agente_ia_cartao(v_id, false, v_motivo);
    perform rt._agente_ia_auditar(v_id, null, v_motivo);
    return true;
  end if;
  perform rt._ev(p_inst, null, 'delegado', left('ao agente de IA: ' || v_tar.nome || ' (pedido ' || v_id || ')', 500), null, ins.motor, ins.jornada,
                 v_tar.etapa_id, v_tar.id, 'A', greatest(coalesce(ins.relogio, now()), now()), null, false);
  perform rt._agente_ia_chamar();
  return true;
end $$;

-- ---------- falha: volta à fila enquanto houver tentativa; esgotou (ou falha definitiva), cartão humano ----------
create or replace function rt._agente_ia_falhar(p_fila bigint, p_motivo text, p_definitivo boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_ia; v_max int := coalesce((adm.valor('motor.agente_ia_tentativas', '2') #>> '{}')::int, 2); v_card bigint;
begin
  select * into f from rt.fila_ia where id = p_fila for update;
  if f.id is null then raise exception 'pedido da IA inexistente'; end if;
  if f.estado not in ('pendente', 'executando') then return jsonb_build_object('fila', f.id, 'desfecho', 'ignorado', 'estado', f.estado); end if;
  if not exists (select 1 from rt.token where instancia = f.instancia and no = f.no and estado = 'aguardando') then
    update rt.fila_ia set estado = 'cancelado', motivo = 'a instância não espera mais esta tarefa', concluido_em = now() where id = p_fila;
    perform rt._agente_ia_auditar(p_fila, f.estado, 'a instância não espera mais esta tarefa');
    return jsonb_build_object('fila', f.id, 'desfecho', 'cancelado');
  end if;
  if not coalesce(p_definitivo, false) and f.tentativas < v_max then
    update rt.fila_ia set estado = 'pendente', motivo = left(p_motivo, 1000) where id = p_fila;
    return jsonb_build_object('fila', f.id, 'desfecho', 'nova_tentativa', 'tentativas', f.tentativas);
  end if;
  update rt.fila_ia set estado = 'erro', motivo = left(p_motivo, 1000), desfecho = 'cartao_humano', concluido_em = now() where id = p_fila;
  v_card := rt._agente_ia_cartao(p_fila, false, left(p_motivo, 300));
  perform rt._agente_ia_auditar(p_fila, f.estado, p_motivo);
  return jsonb_build_object('fila', f.id, 'desfecho', 'cartao_humano', 'cartao', v_card);
end $$;

-- ---------- função agente: pega o lote ----------
create or replace function rt.agente_ia_pegar(p_lote int default 5) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record; v_motivo text; itens jsonb := '[]'; degradados int := 0;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  -- quem ficou executando por mais de 15 minutos (a função caiu no meio) volta para a fila
  update rt.fila_ia set estado = 'pendente', motivo = 'execução interrompida' where estado = 'executando' and iniciado_em < now() - interval '15 minutes';
  for r in select id from rt.fila_ia where estado = 'pendente' order by id limit greatest(least(coalesce(p_lote, 5), 20), 1) for update skip locked loop
    v_motivo := case when not coalesce((adm.valor('motor.agente_ia', 'true') #>> '{}')::boolean, true) then 'agente de IA desligado (motor.agente_ia)'
                     else rt._agente_ia_indisponivel(false) end;
    if v_motivo is not null then
      perform rt._agente_ia_falhar(r.id, v_motivo, true); degradados := degradados + 1; continue;
    end if;
    update rt.fila_ia set estado = 'executando', tentativas = tentativas + 1, iniciado_em = now() where id = r.id;
    itens := itens || (select jsonb_build_object('id', f.id, 'prompt', f.prompt, 'tarefa', t.nome, 'tentativa', f.tentativas)
                         from rt.fila_ia f join org.tarefa t on t.id = f.tarefa where f.id = r.id);
  end loop;
  return jsonb_build_object('itens', itens, 'degradados', degradados, 'config', jsonb_build_object(
    'provedor', coalesce(adm.valor('ia.provedor', '"anthropic"') #>> '{}', 'anthropic'),
    'modelo', adm.valor('ia.modelo', '"claude-sonnet-5-5"') #>> '{}',
    'kimi_modelo', nullif(adm.valor('ia.kimi_modelo', '""') #>> '{}', ''),
    'kimi_url', nullif(rtrim(coalesce(adm.valor('ia.kimi_url', '""') #>> '{}', ''), '/'), '')));
end $$;

-- ---------- função agente: grava o resultado (rascunho) e decide revisão ou conclusão autônoma ----------
create or replace function rt.agente_ia_concluir(p_fila bigint, p_resultado text, p_provedor text, p_modelo text,
  p_tokens_entrada int default null, p_tokens_saida int default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_ia; ins rt.instancia; v_card bigint; v_quando timestamptz; v_estado text; v_auto boolean;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select * into f from rt.fila_ia where id = p_fila for update;
  if f.id is null then raise exception 'pedido da IA inexistente'; end if;
  if f.estado not in ('pendente', 'executando') then return jsonb_build_object('fila', f.id, 'desfecho', 'ignorado', 'estado', f.estado); end if;
  if coalesce(btrim(p_resultado), '') = '' then return rt._agente_ia_falhar(p_fila, 'a IA devolveu resposta vazia', false); end if;
  if not exists (select 1 from rt.token where instancia = f.instancia and no = f.no and estado = 'aguardando') then
    return rt._agente_ia_falhar(p_fila, 'a instância não espera mais esta tarefa', true); end if;
  v_auto := coalesce((adm.valor('motor.agente_ia_autonomo', 'false') #>> '{}')::boolean, false);
  update rt.fila_ia set estado = 'feito', resultado = left(p_resultado, 20000), provedor = left(p_provedor, 40), modelo = left(p_modelo, 120),
         tokens_entrada = p_tokens_entrada, tokens_saida = p_tokens_saida, motivo = null, concluido_em = now(),
         desfecho = case when v_auto then 'autonomo' else 'revisao' end
   where id = p_fila;

  if not v_auto then
    -- human-in-the-loop: cartão de revisão com o rascunho; concluir o cartão faz o token seguir
    v_card := rt._agente_ia_cartao(p_fila, true);
    perform rt._agente_ia_auditar(p_fila, f.estado, 'rascunho pronto para revisão');
    return jsonb_build_object('fila', f.id, 'desfecho', 'revisao', 'cartao', v_card);
  end if;

  -- autônomo: o agente conclui a tarefa e o token segue (como a conclusão de cartão de fluxo)
  select * into ins from rt.instancia where id = f.instancia for update;
  v_quando := greatest(coalesce(ins.relogio, now()), now());
  perform rt._ev(f.instancia, null, 'fim', left('concluída pelo agente de IA (' || coalesce(p_provedor, '?') || ', sem revisão)', 500), null, ins.motor, ins.jornada,
                 f.etapa, f.tarefa, 'A', least(f.criado_em, v_quando), v_quando, false);
  update rt.instancia set relogio = v_quando where id = f.instancia;
  perform rt._trocas_da_etapa(f.instancia, f.etapa);
  delete from rt.token where instancia = f.instancia and no = f.no and estado = 'aguardando';
  insert into rt.token (instancia, no) select f.instancia, para from rt.fluxo where jornada = f.jornada and de = f.no order by id;
  perform rt._agente_ia_auditar(p_fila, f.estado, 'concluída pelo agente de IA sem revisão');
  v_estado := rt._avancar(f.instancia);
  return jsonb_build_object('fila', f.id, 'desfecho', 'autonomo', 'instancia', v_estado);
end $$;

-- ---------- função agente: falha nos provedores ----------
create or replace function rt.agente_ia_falhar(p_fila bigint, p_motivo text, p_definitivo boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  return rt._agente_ia_falhar(p_fila, coalesce(nullif(btrim(p_motivo), ''), 'falha sem detalhe'), p_definitivo);
end $$;

-- ---------- Mesa: o rascunho ligado ao cartão (quem é dono ou recebeu a tarefa, ou aprova no círculo) ----------
create or replace function rt.agente_ia_rascunho(p_cartao bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu(); c rt.cartao; f rt.fila_ia;
begin
  select * into c from rt.cartao where id = p_cartao;
  if c.id is null then raise exception 'cartão inexistente'; end if;
  if v is null or not (rt._pode_agir(c, v) or rt.pode(v, c.empresa, c.circulo, 'aprovar')) then raise exception 'sem acesso a este cartão'; end if;
  select * into f from rt.fila_ia where cartao = p_cartao order by id desc limit 1;
  if f.id is null then return null; end if;
  return jsonb_build_object('cartao', c.id, 'tarefa', (select nome from org.tarefa where id = f.tarefa), 'desfecho', f.desfecho,
    'rascunho', f.resultado, 'provedor', f.provedor, 'modelo', f.modelo, 'gerado_em', f.concluido_em, 'motivo', f.motivo,
    'aviso', case when f.desfecho = 'revisao' then 'Rascunho feito por IA: confira antes de concluir o cartão.' end);
end $$;

-- ---------- Admin: conferência ----------
create or replace function adm.agente_ia_resumo() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u jsonb;
begin
  if not rt.chamada_servico() then perform adm._so_admin(); end if;
  u := rt._agente_ia_uso_hoje();
  return jsonb_build_object(
    'ligado', coalesce((adm.valor('motor.agente_ia', 'true') #>> '{}')::boolean, true),
    'autonomo', coalesce((adm.valor('motor.agente_ia_autonomo', 'false') #>> '{}')::boolean, false),
    'modo_assistido', coalesce((adm.valor('motor.maquina_assistida', 'false') #>> '{}')::boolean, false),
    'provedor', coalesce(adm.valor('ia.provedor', '"anthropic"') #>> '{}', 'anthropic'),
    'chave_anthropic', rt._segredo('anthropic_chave') is not null,
    'chave_kimi', rt._segredo('kimi_chave') is not null,
    'endereco_funcoes', rt._url_funcao('agente') is not null,
    'disponivel', rt._agente_ia_indisponivel(true) is null,
    'motivo_indisponivel', rt._agente_ia_indisponivel(true),
    'tarefas_a', (select count(*) from org.tarefa where executor = 'A'),
    'hoje', u || jsonb_build_object('limite_chamadas', (adm.valor('motor.agente_ia_chamadas_dia', '200') #>> '{}')::bigint,
                                    'limite_tokens', (adm.valor('motor.agente_ia_tokens_dia', '400000') #>> '{}')::bigint),
    'por_estado', (select jsonb_object_agg(e, (select count(*) from rt.fila_ia where estado = e)) from unnest(array['pendente', 'executando', 'feito', 'erro', 'cancelado']) e),
    'por_desfecho', (select jsonb_object_agg(d, (select count(*) from rt.fila_ia where desfecho = d)) from unnest(array['revisao', 'autonomo', 'cartao_humano']) d),
    'revisoes_abertas', (select count(*) from rt.fila_ia f join rt.cartao c on c.id = f.cartao where f.desfecho = 'revisao' and c.coluna <> 'feito'),
    'tokens_30_dias', (select coalesce(sum(coalesce(tokens_entrada, 0) + coalesce(tokens_saida, 0)), 0) from rt.fila_ia where concluido_em >= now() - interval '30 days'),
    'motivos_recentes', (select coalesce(jsonb_agg(jsonb_build_object('motivo', m, 'vezes', q) order by q desc), '[]') from (
        select motivo as m, count(*) as q from rt.fila_ia where motivo is not null and criado_em >= now() - interval '7 days' group by motivo order by count(*) desc limit 5) x));
end $$;

-- ---------- trecho mínimo em rt._avancar (troca conferida, sem copiar o corpo) ----------
do $$
declare d text := pg_get_functiondef('rt._avancar(bigint, integer)'::regprocedure); a text;
  alvo text := $q$      if ins.interativo and (v_tar.executor in ('P', 'H', 'X') or (v_tar.executor in ('A', 'R') and rt._assistido(ins))) then$q$;
begin
  if position('rt._agente_ia_enfileirar' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, alvo, ''))) / length(alvo) <> 1 then raise exception 'rt._avancar não tem o texto esperado: revisar a 086'; end if;
  a := d;
  d := replace(d, alvo, $q$      -- agente de IA (086): tarefa A no modo assistido vai à fila da IA (ou ao cartão humano com o motivo); o token espera
      if v_tar.executor = 'A' and ins.interativo and rt._assistido(ins) and rt._agente_ia_enfileirar(p_inst, tk.no, v_tar.id) then
        continue;
      end if;
$q$ || alvo);
  if d = a or (length(d) - length(replace(d, 'rt._agente_ia_enfileirar(', ''))) / length('rt._agente_ia_enfileirar(') <> 1 then
    raise exception 'rt._avancar não tem o texto esperado: revisar a 086'; end if;
  execute d;
end $$;

-- ---------- rotina: a cada 5 minutos, se houver pedido pendente, chama a função agente (rede de segurança do pg_net) ----------
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'imts-agente-ia';
    perform cron.schedule('imts-agente-ia', '*/5 * * * *', $c$select rt._agente_ia_chamar() where exists (select 1 from rt.fila_ia where estado = 'pendente')$c$);
  end if;
end $$;

-- ---------- permissões ----------
revoke all on function rt._agente_ia_uso_hoje(), rt._agente_ia_indisponivel(boolean), rt._agente_ia_prompt(bigint, bigint), rt._agente_ia_chamar(),
  rt._agente_ia_cartao(bigint, boolean, text), rt._agente_ia_auditar(bigint, text, text), rt._agente_ia_enfileirar(bigint, text, bigint),
  rt._agente_ia_falhar(bigint, text, boolean), rt.agente_ia_pegar(int), rt.agente_ia_concluir(bigint, text, text, text, int, int),
  rt.agente_ia_falhar(bigint, text, boolean), rt.agente_ia_rascunho(bigint), adm.agente_ia_resumo() from public, anon, authenticated;
grant execute on function rt._agente_ia_uso_hoje(), rt._agente_ia_indisponivel(boolean), rt._agente_ia_prompt(bigint, bigint), rt._agente_ia_chamar(),
  rt._agente_ia_cartao(bigint, boolean, text), rt._agente_ia_auditar(bigint, text, text), rt._agente_ia_enfileirar(bigint, text, bigint),
  rt._agente_ia_falhar(bigint, text, boolean), rt.agente_ia_pegar(int), rt.agente_ia_concluir(bigint, text, text, text, int, int),
  rt.agente_ia_falhar(bigint, text, boolean) to service_role;
grant execute on function rt.agente_ia_rascunho(bigint), adm.agente_ia_resumo() to authenticated, service_role;

insert into adm.api_funcao (nome, quem, descricao) values
  ('adm.agente_ia_resumo', 'interno', 'Agente de IA das tarefas A: ligado, autônomo, provedores, uso do dia contra os limites, fila por estado e desfecho, motivos de queda para o cartão'),
  ('rt.agente_ia_rascunho', 'interno', 'Rascunho do agente de IA ligado a um cartão de revisão (quem é dono, recebeu a tarefa ou aprova no círculo)')
on conflict (nome) do nothing;

insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('edge-agente', 'Função agente: executa a fila das tarefas de agente pela IA', 'ia', 'produção', null, 'Integração', 'pendente', '{anthropic_chave,imts_funcao_chave}', 'manual', null,
  'gravar anthropic_chave (ou kimi_chave com ia.kimi_url e ia.kimi_modelo) no cofre, preencher servidor.url_funcoes e implantar a função agente com verify_jwt desligado (o banco chama com X-IMTS-Chave)', '086, B39')
on conflict (codigo) do nothing;
commit;
