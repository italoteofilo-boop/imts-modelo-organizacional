-- E5 Canal Telegram e E9 conversa (fase 2). Depende de 003 a 017.
-- O webhook (Edge Function "telegram") entrega cada atualização a rt.receber_update, que identifica a pessoa, grava a mensagem com
-- autodestruição, interpreta o pedido (rt.interpretar) e põe a resposta na fila de envio. A fila respeita os limites do Telegram
-- (1 mensagem por segundo por chat, 20 por minuto por grupo, cerca de 30 por segundo no total). O token do bot fica no Vault do Supabase.
-- Fica fora do Telegram (plano da fase 2, seção 4): senhas, chaves e códigos; relatos da GO-09; aprovação de pagamento (GE-04, GE-05).
begin;

-- Usuários simulados ganham um id de Telegram fictício (900000001 em diante), para a simulação no ambiente de teste
with s as (select pseudonimo, row_number() over (order by criado_em, pseudonimo) as n from rt_chave.identidade where simulado and telegram_id is null)
update rt_chave.identidade i set telegram_id = 900000000 + s.n + coalesce((select max(telegram_id) - 900000000 from rt_chave.identidade where telegram_id between 900000001 and 999999999), 0)
  from s where i.pseudonimo = s.pseudonimo;

-- Fila de envio --------------------------------------------------------------------------------------------
create table if not exists rt.fila_envio (
  id           bigint generated always as identity primary key,
  chat_ref     text not null,
  texto        text not null,
  botoes       jsonb,
  pessoa       uuid references rt.pessoa(pseudonimo),
  motor        smallint references rt.motor(circulo),
  estado       text not null default 'pendente' check (estado in ('pendente', 'enviando', 'enviado', 'erro')),
  tentativas   int not null default 0,
  erro         text,
  mensagem_ref text,
  simulado     boolean not null,
  criado_em    timestamptz not null default now(),
  enviado_em   timestamptz
);
create index if not exists fila_envio_pendente on rt.fila_envio (estado, id);
create index if not exists fila_envio_chat on rt.fila_envio (chat_ref, enviado_em);

-- O que a conversa deixou pendente (texto aguardando confirmação)
create table if not exists rt.conversa (
  pessoa        uuid primary key references rt.pessoa(pseudonimo),
  pendente      jsonb,
  atualizado_em timestamptz not null default now()
);

-- Ajuda e quadro em texto --------------------------------------------------------------------------------------
create or replace function rt._ajuda() returns text language sql immutable set search_path = '' as $$
  select 'Comandos: /quadro (suas tarefas), /concluir N, /decidir N, /aceitar N, /recusar N, /nova texto (tarefa avulsa; prazo: "até dd/mm"), /iniciar ID-01. '
      || 'Também pode escrever o que precisa: eu procuro a jornada que já existe. Senhas, chaves e códigos não vão por aqui; '
      || 'relatos vão pelo formulário da Governança; aprovação de pagamento se confirma na Mesa.' $$;

create or replace function rt._prazo_texto(p_texto text) returns timestamptz language sql stable set search_path = '' as $$
  select coalesce(
    (select make_timestamptz(extract(year from now())::int + case when make_date(extract(year from now())::int, m[2]::int, m[1]::int) < current_date then 1 else 0 end,
                             m[2]::int, m[1]::int, 18, 0, 0, 'America/Fortaleza')
       from regexp_match(p_texto, 'até (\d{1,2})/(\d{1,2})') m where m is not null),
    now() + interval '1 day') $$;

-- Interpretação (E9): intenção → ação, com a pessoa decidindo o que é de alçada ------------------------------------
create or replace function rt.interpretar(p_pessoa uuid, p_texto text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  t text := trim(coalesce(p_texto, '')); cmd text; arg text; n bigint; c rt.cartao; s jsonb; r text; v_id bigint; v_titulo text; b jsonb := '[]'::jsonb; k int;
begin
  -- segredo no texto: não guarda e pede para apagar
  if t ~* '(senha|password|token|chave de acesso|código de acesso)\s*[:=]' then
    return jsonb_build_object('texto', 'Isso parece uma senha ou chave. Não mande segredos pelo Telegram: a mensagem será apagada. Use o cofre indicado pela Integração.', 'segredo', true);
  end if;
  cmd := lower(split_part(t, ' ', 1)); arg := trim(substr(t, length(split_part(t, ' ', 1)) + 1));
  cmd := regexp_replace(cmd, '@.*$', '');   -- /quadro@nome_do_bot

  if cmd in ('/start', '/ajuda', 'ajuda', '/help') then
    return jsonb_build_object('texto', rt._ajuda());

  elsif cmd in ('/quadro', 'quadro') or lower(t) in ('minhas tarefas', 'o que tenho') then
    r := ''; k := 0;
    for c in select * from rt.cartao where (dono = p_pessoa or delegado_pessoa = p_pessoa) and coluna <> 'feito' order by (coluna = 'decidir') desc, prazo limit 8 loop
      k := k + 1;
      r := r || '#' || c.id || ' ' || c.titulo || ' · ' || replace(c.coluna, '_', ' ') || ' · até ' || to_char(c.prazo at time zone 'America/Fortaleza', 'DD/MM HH24:MI')
             || case when c.delegado_pessoa = p_pessoa and c.aceite = 'pendente' then ' · pedido para você' else '' end || E'\n';
      if k <= 4 then
        b := b || case when c.coluna = 'decidir' then jsonb_build_array(jsonb_build_object('text', 'Decidir #' || c.id, 'callback_data', 'v:' || c.id))
                       when c.delegado_pessoa = p_pessoa and c.aceite = 'pendente' then jsonb_build_array(jsonb_build_object('text', 'Aceitar #' || c.id, 'callback_data', 'a:' || c.id),
                                                                                                             jsonb_build_object('text', 'Recusar #' || c.id, 'callback_data', 'r:' || c.id))
                       else jsonb_build_array(jsonb_build_object('text', 'Concluir #' || c.id, 'callback_data', 'c:' || c.id)) end;
      end if;
    end loop;
    if k = 0 then return jsonb_build_object('texto', 'Nada aberto com você agora.'); end if;
    return jsonb_build_object('texto', 'Suas tarefas abertas:' || E'\n' || r, 'botoes', b);

  elsif cmd in ('/concluir', 'c:') and arg ~ '^\d+$' then
    n := arg::bigint;
    select * into c from rt.cartao where id = n;
    if c.jornada in ('GE-04', 'GE-05') and exists (select 1 from org.tarefa x where x.id = c.tarefa and x.nome ~* '^(aprovar|autorizar)') then
      return jsonb_build_object('texto', 'Aprovação de pagamento se confirma fora do Telegram, na Mesa (segregação). O cartão #' || n || ' segue aberto.');
    end if;
    begin
      perform rt.concluir_cartao(n, p_pessoa);
      return jsonb_build_object('texto', 'Feito: #' || n || ' concluído.' || case when c.tipo = 'fluxo' then ' O fluxo seguiu; o que for seu chega aqui.' else '' end);
    exception when others then return jsonb_build_object('texto', 'Não deu: ' || sqlerrm); end;

  elsif cmd in ('/decidir', 'v:') and arg ~ '^\d+$' then
    select * into c from rt.cartao where id = arg::bigint;
    if c.id is null or c.coluna <> 'decidir' then return jsonb_build_object('texto', 'O cartão #' || arg || ' não é uma decisão aberta.'); end if;
    select jsonb_agg(jsonb_build_array(jsonb_build_object('text', o.v->>'rotulo', 'callback_data', 'd:' || c.id || ':' || (o.i - 1))) order by o.i) into b
      from jsonb_array_elements(c.opcoes) with ordinality o(v, i);
    return jsonb_build_object('texto', c.titulo || ' (#' || c.id || ')', 'botoes', b);

  elsif cmd = 'd:' and arg ~ '^\d+:\d+$' then
    select * into c from rt.cartao where id = split_part(arg, ':', 1)::bigint;
    begin
      perform rt.decidir_cartao(c.id, p_pessoa, c.opcoes->(split_part(arg, ':', 2)::int)->>'para');
      return jsonb_build_object('texto', 'Decidido: ' || (c.opcoes->(split_part(arg, ':', 2)::int)->>'rotulo') || '. O fluxo seguiu.');
    exception when others then return jsonb_build_object('texto', 'Não deu: ' || sqlerrm); end;

  elsif cmd in ('/aceitar', 'a:', '/recusar', 'r:') and arg ~ '^\d+$' then
    begin
      perform rt.responder_delegacao(arg::bigint, p_pessoa, cmd in ('/aceitar', 'a:'));
      return jsonb_build_object('texto', case when cmd in ('/aceitar', 'a:') then 'Aceito: #' || arg || ' está no seu quadro.' else 'Recusado: #' || arg || ' volta para quem pediu.' end);
    exception when others then return jsonb_build_object('texto', 'Não deu: ' || sqlerrm); end;

  elsif cmd in ('/iniciar', 'i:') and arg ~* '^[a-z]{2}-\d{2}$' then
    begin
      if not rt.pode(p_pessoa, null, (select circulo from org.jornada where codigo = upper(arg)), 'operar') then
        return jsonb_build_object('texto', 'Esta jornada é de outro círculo. Delegue a quem é de lá pela Mesa.');
      end if;
      v_id := rt.iniciar_jornada(upper(arg), p_pessoa, (select simulado from rt.pessoa where pseudonimo = p_pessoa));
      delete from rt.conversa where pessoa = p_pessoa;
      return jsonb_build_object('texto', 'Iniciada a ' || upper(arg) || ' (execução ' || v_id || '). As tarefas de gente chegam como cartões; mande /quadro.');
    exception when others then return jsonb_build_object('texto', 'Não deu: ' || sqlerrm); end;

  elsif cmd = 'n:' then
    select pendente->>'texto' into v_titulo from rt.conversa where pessoa = p_pessoa;
    if v_titulo is null then return jsonb_build_object('texto', 'Não há tarefa pendente para criar.'); end if;
    begin
      v_id := rt.criar_avulsa(p_pessoa, regexp_replace(v_titulo, '\s*até \d{1,2}/\d{1,2}\s*', ' ', 'g'), rt._prazo_texto(v_titulo), null, 'telegram');
      delete from rt.conversa where pessoa = p_pessoa;
      return jsonb_build_object('texto', 'Criada a tarefa avulsa #' || v_id || ', prazo ' || to_char(rt._prazo_texto(v_titulo) at time zone 'America/Fortaleza', 'DD/MM HH24:MI') || '.');
    exception when others then return jsonb_build_object('texto', 'Não deu: ' || sqlerrm); end;

  elsif cmd = 'x:' then
    delete from rt.conversa where pessoa = p_pessoa;
    return jsonb_build_object('texto', 'Ok, deixei de lado.');

  elsif cmd like '/%' and cmd <> '/nova' then
    return jsonb_build_object('texto', 'Não conheço esse comando. ' || rt._ajuda());

  else
    -- texto livre ou /nova: procura a jornada que já existe antes de criar avulsa (a alçada não se contorna)
    v_titulo := case when cmd = '/nova' then arg else t end;
    if length(v_titulo) < 3 then return jsonb_build_object('texto', 'Escreva o que precisa ser feito.'); end if;
    insert into rt.conversa (pessoa, pendente) values (p_pessoa, jsonb_build_object('texto', v_titulo))
      on conflict (pessoa) do update set pendente = excluded.pendente, atualizado_em = now();
    s := rt.sugerir_jornada(v_titulo);
    if jsonb_array_length(s) > 0 and (s->0->>'pontos')::int >= 2 then
      return jsonb_build_object('texto', 'Isso já existe: ' || (s->0->>'jornada') || ' · ' || (s->0->>'jornada_nome') || ' (tarefa "' || (s->0->>'tarefa') || '"). Iniciar a jornada ou criar como avulsa?',
        'botoes', jsonb_build_array(
          jsonb_build_array(jsonb_build_object('text', 'Iniciar ' || (s->0->>'jornada'), 'callback_data', 'i:' || (s->0->>'jornada'))),
          jsonb_build_array(jsonb_build_object('text', 'Criar como avulsa', 'callback_data', 'n:'), jsonb_build_object('text', 'Deixar', 'callback_data', 'x:'))));
    end if;
    return jsonb_build_object('texto', 'Crio a tarefa avulsa "' || v_titulo || '" com prazo ' || to_char(rt._prazo_texto(v_titulo) at time zone 'America/Fortaleza', 'DD/MM HH24:MI') || '?',
      'botoes', jsonb_build_array(jsonb_build_array(jsonb_build_object('text', 'Criar', 'callback_data', 'n:'), jsonb_build_object('text', 'Deixar', 'callback_data', 'x:'))));
  end if;
end $$;

-- Entrada do webhook ----------------------------------------------------------------------------------------------
create or replace function rt.receber_update(p_update jsonb, p_simulado boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_msg jsonb; v_cb jsonb; v_from bigint; v_chat text; v_tipo text; v_texto text; v_msgid text; v_pessoa uuid; v_sim boolean; v_motor smallint;
  v_horas int; v_res jsonb; v_fila bigint; v_in bigint; v_circ smallint;
begin
  v_msg := p_update->'message'; v_cb := p_update->'callback_query';
  if v_cb is not null then
    v_from := (v_cb->'from'->>'id')::bigint; v_chat := v_cb->'message'->'chat'->>'id'; v_tipo := v_cb->'message'->'chat'->>'type';
    v_texto := v_cb->>'data'; v_msgid := v_cb->'message'->>'message_id';
    v_texto := case when v_texto ~ '^[a-z]:' then split_part(v_texto, ':', 1) || ': ' || substr(v_texto, 3) else v_texto end;
  elsif v_msg is not null then
    v_from := (v_msg->'from'->>'id')::bigint; v_chat := v_msg->'chat'->>'id'; v_tipo := v_msg->'chat'->>'type';
    v_texto := coalesce(v_msg->>'text', v_msg->>'caption'); v_msgid := v_msg->>'message_id';
  else
    return jsonb_build_object('ignorado', 'tipo de atualização não tratado');
  end if;

  select i.pseudonimo, i.simulado into v_pessoa, v_sim from rt_chave.identidade i where i.telegram_id = v_from and i.nome not like 'eliminado em %';
  if v_pessoa is null or not exists (select 1 from rt.pessoa where pseudonimo = v_pessoa) then
    insert into rt.fila_envio (chat_ref, texto, simulado) values ('tg:' || v_chat, 'Você ainda não está cadastrado no IMTS.OS. Peça o seu acesso à Gestão (GE-07).', p_simulado)
      returning id into v_fila;
    return jsonb_build_object('pessoa', null, 'fila', v_fila, 'callback_id', v_cb->>'id');
  end if;
  if p_simulado <> v_sim then raise exception 'mistura de simulado e real: a atualização e a pessoa não são do mesmo ambiente'; end if;
  select circulo into v_circ from rt.pessoa where pseudonimo = v_pessoa;

  -- rota: chat privado vai ao motor do círculo da pessoa (sem círculo: o motor piloto, 1); grupo precisa estar cadastrado
  select motor into v_motor from rt.rota_chat where chat_ref = 'tg:' || v_chat;
  if v_motor is null then
    if v_tipo <> 'private' then
      insert into rt.fila_envio (chat_ref, texto, simulado) values ('tg:' || v_chat, 'Este grupo ainda não está ligado a um motor. Peça à Integração.', p_simulado) returning id into v_fila;
      return jsonb_build_object('pessoa', v_pessoa, 'fila', v_fila, 'callback_id', v_cb->>'id');
    end if;
    v_motor := coalesce(v_circ, 1);
    insert into rt.rota_chat (chat_ref, motor, descricao) values ('tg:' || v_chat, v_motor, 'conversa privada com o bot');
  end if;

  -- grava a entrada antes de tudo, com autodestruição pela configuração do motor (menos de 48 horas)
  select coalesce((valor #>> '{}')::int, 24) into v_horas from rt.config where motor = v_motor and chave = 'autodestruicao_horas';
  v_res := rt.interpretar(v_pessoa, case when v_cb is not null then v_texto else coalesce(v_texto, '') end);
  if v_msg is not null and v_msg ? 'voice' then
    v_res := jsonb_build_object('texto', 'Recebi o áudio. A transcrição entra quando o modelo de voz for ligado; por enquanto, escreva o pedido.');
  end if;
  v_in := rt.receber_mensagem('tg:' || v_chat, v_msgid, v_pessoa,
                              case when coalesce((v_res->>'segredo')::boolean, false) then '(apagada: possível segredo)'
                                   when v_cb is not null then 'botão: ' || coalesce(v_cb->>'data', '') else coalesce(v_texto, '(sem texto)') end,
                              p_simulado, coalesce(v_horas, 24));
  if coalesce((v_res->>'segredo')::boolean, false) then update rt.mensagem set apagar_ate = now() where id = v_in; end if;

  insert into rt.fila_envio (chat_ref, texto, botoes, pessoa, motor, simulado)
       values ('tg:' || v_chat, v_res->>'texto', v_res->'botoes', v_pessoa, v_motor, p_simulado) returning id into v_fila;
  return jsonb_build_object('pessoa', v_pessoa, 'motor', v_motor, 'mensagem', v_in, 'fila', v_fila, 'resposta', v_res, 'callback_id', v_cb->>'id');
end $$;

-- Fila: o que pode sair agora sem passar dos limites do Telegram ---------------------------------------------------------
create or replace function rt.proximos_envios(p_limite int default 20) returns setof rt.fila_envio
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_envio; v_seg int; v_n int := 0;
begin
  select count(*) into v_seg from rt.fila_envio where estado in ('enviando', 'enviado') and enviado_em > now() - interval '1 second';
  for f in select * from rt.fila_envio where estado = 'pendente' order by id for update skip locked loop
    exit when v_n >= p_limite or v_seg + v_n >= 30;
    continue when exists (select 1 from rt.fila_envio x where x.chat_ref = f.chat_ref and x.estado in ('enviando', 'enviado') and x.enviado_em > now() - interval '1 second');
    continue when f.chat_ref like 'tg:-%' and (select count(*) from rt.fila_envio x where x.chat_ref = f.chat_ref and x.estado in ('enviando', 'enviado') and x.enviado_em > now() - interval '1 minute') >= 20;
    continue when exists (select 1 from rt.fila_envio x where x.chat_ref = f.chat_ref and x.id < f.id and x.estado = 'pendente');   -- ordem por chat
    update rt.fila_envio set estado = 'enviando', enviado_em = now(), tentativas = tentativas + 1 where id = f.id returning * into f;
    v_n := v_n + 1;
    return next f;
  end loop;
end $$;

create or replace function rt.confirmar_envio(p_fila bigint, p_ok boolean, p_mensagem_ref text default null, p_erro text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_envio; v_horas int;
begin
  select * into f from rt.fila_envio where id = p_fila for update;
  if p_ok then
    update rt.fila_envio set estado = 'enviado', mensagem_ref = p_mensagem_ref, erro = null where id = p_fila;
    select coalesce((valor #>> '{}')::int, 24) into v_horas from rt.config where motor = coalesce(f.motor, 1) and chave = 'autodestruicao_horas';
    insert into rt.mensagem (chat_ref, mensagem_ref, direcao, pessoa, motor, conteudo, apagar_ate, simulado)
         values (f.chat_ref, p_mensagem_ref, 'saida', f.pessoa, coalesce(f.motor, 1), f.texto, now() + make_interval(hours => coalesce(v_horas, 24)), f.simulado);
  else
    update rt.fila_envio set estado = case when tentativas >= 5 then 'erro' else 'pendente' end, erro = p_erro where id = p_fila;
  end if;
end $$;

create or replace function rt.marcar_apagada(p_mensagem bigint) returns void language sql security definer set search_path = '' as $$
  update rt.mensagem set apagada_em = now() where id = p_mensagem and apagada_em is null $$;

-- Segredos do canal no Vault (só no Supabase): token do bot, segredo do webhook, chave das tarefas da função
create or replace function rt._segredo(p_nome text) returns text language plpgsql stable security definer set search_path = '' as $$
declare v text;
begin
  if to_regclass('vault.decrypted_secrets') is null then return null; end if;
  execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1' into v using p_nome;
  return v;
end $$;

alter table rt.fila_envio enable row level security;
alter table rt.conversa enable row level security;
grant all on rt.fila_envio, rt.conversa to service_role;
revoke all on function rt.interpretar(uuid, text), rt.receber_update(jsonb, boolean), rt.proximos_envios(int), rt.confirmar_envio(bigint, boolean, text, text),
  rt.marcar_apagada(bigint), rt._segredo(text), rt._ajuda(), rt._prazo_texto(text) from public;
grant execute on function rt.interpretar(uuid, text), rt.receber_update(jsonb, boolean), rt.proximos_envios(int), rt.confirmar_envio(bigint, boolean, text, text),
  rt.marcar_apagada(bigint), rt._segredo(text) to service_role;

commit;
