-- P6 do inventário: Telegram Mini App do IMTS.OS (app/tg.html em www.imts.global; homologação em homolog.imts.global).
-- A página abre dentro do Telegram e manda o initData à função do servidor telegram_app (verify_jwt desligado). A função confere a
-- assinatura com o token do bot, acha a pessoa pelo Telegram ligado (rt_chave.identidade) e o login dela (rt_chave.login) e então chama
-- o banco COM A IDENTIDADE DESSA PESSOA, pela porta única (public.imts). Quem decide o que pode é o banco, como na Mesa da web.
-- Depende de 017, 019, 047, 057, 065 e 066. Não mexe no motor nem na assinatura.
-- 1. Parâmetros do Mini App (endereço, validade do initData, limite de tentativas).
-- 2. adm.registro_servidor aceita a função telegram_app.
-- 3. Serviço: rt.tg_app_identificar (quem é o usuário do Telegram) e adm.tg_app_limite (limite de tentativas), só pela chave de serviço.
-- 4. Pessoa: rt.tg_mesa (as tarefas abertas, sem ids internos) e rt.tg_agir (concluir, decidir, aceitar, recusar), pela porta única.
-- 5. Bot: /mesa abre o Mini App e o /quadro ganha o botão "Abrir a Mesa" (botão web_app; em grupo a função telegram troca por link).
begin;

-- 1. Parâmetros ---------------------------------------------------------------------------------------------------------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('telegram_app.url', 'telegram', 'Endereço do Mini App do Telegram (a Mesa no Telegram). Produção: https://www.imts.global/tg.html; homologação: https://homolog.imts.global/tg.html. Vazio desliga o botão no bot',
  'texto', '"https://www.imts.global/tg.html"', '"https://www.imts.global/tg.html"', '{}', true, '{bot:menu,bot:/mesa,bot:/quadro}', 'P6 do inventário (Telegram Mini App, em imts.global)'),
 ('telegram_app.validade_segundos', 'telegram', 'Idade máxima, em segundos, dos dados de abertura do Mini App (auth_date do initData); passou, a pessoa fecha e abre de novo pelo bot',
  'inteiro', '3600', '3600', '{"min":60,"max":86400}', true, '{functions:telegram_app}', 'P6; documentação do Telegram, validação do initData'),
 ('telegram_app.tentativas_max', 'telegram', 'Tentativas sem sucesso (assinatura inválida, sem vínculo, recusa) aceitas na janela antes de bloquear, por IP ou por usuário do Telegram',
  'inteiro', '10', '10', '{"min":3,"max":100}', true, '{functions:telegram_app}', 'P6; segurança do Mini App'),
 ('telegram_app.janela_minutos', 'telegram', 'Janela, em minutos, da contagem de tentativas sem sucesso do Mini App',
  'inteiro', '15', '15', '{"min":1,"max":1440}', true, '{functions:telegram_app}', 'P6; segurança do Mini App'),
 ('telegram_app.pedidos_minuto', 'telegram', 'Pedidos por minuto aceitos de um mesmo usuário do Telegram no Mini App',
  'inteiro', '60', '60', '{"min":10,"max":600}', true, '{functions:telegram_app}', 'P6; segurança do Mini App')
on conflict (chave) do nothing;

-- 2. Registro do servidor aceita telegram_app (acrescenta à lista que já existir, sem apagar a de outras migrações) ----------------
do $$
declare d text; n text;
begin
  select conname, pg_get_constraintdef(oid) into n, d from pg_constraint
   where conrelid = 'adm.registro_servidor'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%funcao%';
  if d is not null and d not like '%''telegram_app''%' then
    execute format('alter table adm.registro_servidor drop constraint %I', n);
    execute format('alter table adm.registro_servidor add constraint %I %s', n, replace(d, 'ARRAY[', 'ARRAY[''telegram_app''::text, '));
  end if;
end $$;
create index if not exists registro_servidor_alvo on adm.registro_servidor (funcao, alvo, em desc);

-- Endereço do Mini App (nulo se desligado)
create or replace function rt._tg_app_url() returns text language sql stable security definer set search_path = '' as $$
  select nullif(btrim(adm.valor('telegram_app.url', '""') #>> '{}'), '') $$;

-- 3. Serviço -------------------------------------------------------------------------------------------------------------
-- Quem é este usuário do Telegram (id já conferido pela assinatura do initData). Não devolve nada além do necessário.
-- situacao: ok | sem_vinculo | sem_login | externo | simulado
create or replace function rt.tg_app_identificar(p_telegram_id bigint, p_simulado boolean default false) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_pessoa uuid; v_sim boolean; v_nome text; v_auth uuid;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select i.pseudonimo, i.simulado, i.nome into v_pessoa, v_sim, v_nome from rt_chave.identidade i
   where i.telegram_id = p_telegram_id and i.nome not like 'eliminado em %';
  if v_pessoa is null or not exists (select 1 from rt.pessoa where pseudonimo = v_pessoa) then
    if exists (select 1 from ext.telegram t where t.telegram_id = p_telegram_id and t.vinculado_em is not null) then
      return jsonb_build_object('situacao', 'externo');
    end if;
    return jsonb_build_object('situacao', 'sem_vinculo');
  end if;
  if v_sim <> p_simulado then return jsonb_build_object('situacao', 'simulado', 'pessoa', v_pessoa); end if;
  select auth_uid into v_auth from rt_chave.login where pseudonimo = v_pessoa;
  if v_auth is null then return jsonb_build_object('situacao', 'sem_login', 'pessoa', v_pessoa); end if;
  return jsonb_build_object('situacao', 'ok', 'pessoa', v_pessoa, 'auth_uid', v_auth, 'nome', v_nome);
end $$;

-- Limite de tentativas: conta no próprio registro do servidor, pela chave (hash do IP ou do usuário do Telegram, nunca o valor em claro).
-- Devolve o motivo do bloqueio, ou nulo se pode seguir.
create or replace function adm.tg_app_limite(p_chave text) returns text language plpgsql stable security definer set search_path = '' as $$
declare
  v_max int := coalesce((adm.valor('telegram_app.tentativas_max', '10') #>> '{}')::int, 10);
  v_jan int := coalesce((adm.valor('telegram_app.janela_minutos', '15') #>> '{}')::int, 15);
  v_ppm int := coalesce((adm.valor('telegram_app.pedidos_minuto', '60') #>> '{}')::int, 60);
  v_falhas int; v_pedidos int;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  if coalesce(p_chave, '') !~ '^(ip|tg):[0-9a-f]{16,64}$' then raise exception 'chave de limite inválida'; end if;
  select count(*) filter (where not ok and em > now() - make_interval(mins => v_jan)), count(*) filter (where em > now() - interval '1 minute')
    into v_falhas, v_pedidos
    from adm.registro_servidor where funcao = 'telegram_app' and alvo = p_chave and em > now() - make_interval(mins => greatest(v_jan, 1));
  if v_falhas >= v_max then return 'muitas tentativas sem sucesso: espere ' || v_jan || ' minutos e abra de novo pelo bot'; end if;
  if v_pedidos >= v_ppm then return 'muitos pedidos em sequência: espere um minuto'; end if;
  return null;
end $$;

-- 4. Pessoa (pela porta única, com o login de quem abriu) ----------------------------------------------------------------------
-- Aprovação de pagamento (GE-04 e GE-05) se confirma fora do Telegram, na Mesa da web (segregação; plano da fase 2, seção 4)
create or replace function rt._tg_restrito(p_cartao bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from rt.cartao c join org.tarefa x on x.id = c.tarefa
                  where c.id = p_cartao and c.jornada in ('GE-04', 'GE-05') and x.nome ~* '^(aprovar|autorizar)') $$;

-- As tarefas abertas de quem abriu o Mini App. Sem pseudônimos nem ids de etapa: só o número do cartão (o mesmo do bot) e o necessário.
create or replace function rt.tg_mesa() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); q jsonb;
begin
  q := coalesce(rt.quadro(v), '[]'::jsonb);
  return jsonb_build_object(
    'nome', (select nome from rt_chave.identidade where pseudonimo = v),
    'mesa_web', 'mesa.html',
    'cartoes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', (c->>'id')::bigint,
               'titulo', c->>'titulo',
               'coluna', c->>'coluna',
               'prazo', c->'prazo',
               'tipo', coalesce(c->>'tipo', 'fluxo'),
               'jornada', c->>'jornada',
               'jornada_nome', c->>'jornada_nome',
               'etapa_nome', c->>'etapa_nome',
               'de', case when coalesce((c->>'sou_dono')::boolean, true) then null
                          else (select i.nome from rt_chave.identidade i where i.pseudonimo = (c->>'dono')::uuid) end,
               'para_aceitar', (c->>'delegado_pessoa')::uuid is not distinct from v and coalesce(c->>'aceite', '') = 'pendente',
               'delegada', (c->>'delegado_pessoa') is not null and (c->>'delegado_pessoa')::uuid is distinct from v,
               'com_agente', coalesce((c->>'delegado_agente')::boolean, false),
               'opcoes', case when c->>'coluna' = 'decidir' and jsonb_typeof(c->'opcoes') = 'array'
                              then (select coalesce(jsonb_agg(o->>'rotulo' order by k), '[]') from jsonb_array_elements(c->'opcoes') with ordinality e(o, k)) end,
               'so_na_web', rt._tg_restrito((c->>'id')::bigint))
             order by ((c->>'delegado_pessoa')::uuid is not distinct from v and coalesce(c->>'aceite', '') = 'pendente') desc, (c->>'coluna' = 'decidir') desc, c->>'prazo')
        from jsonb_array_elements(q) c where c->>'coluna' <> 'feito'), '[]'::jsonb));
end $$;

-- Uma ação sobre um cartão. A regra continua nas funções da Mesa (rt.app_*); aqui só se escolhe qual chamar e se guarda a segregação.
-- p_opcao: posição (0, 1, ...) da opção de decisão, como o bot já faz; o destino interno da opção não sai do banco.
create or replace function rt.tg_agir(p_acao text, p_cartao bigint, p_opcao int default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); c rt.cartao; v_para text; v_rot text;
begin
  select * into c from rt.cartao where id = p_cartao;
  if c.id is null then raise exception 'cartão #% não encontrado', p_cartao; end if;
  if p_acao in ('concluir', 'decidir') and rt._tg_restrito(p_cartao) then
    raise exception 'aprovação de pagamento se confirma fora do Telegram, na Mesa (segregação); o cartão #% segue aberto', p_cartao;
  end if;
  if p_acao = 'concluir' then
    perform rt.app_concluir(p_cartao);
    return jsonb_build_object('texto', 'Feito: #' || p_cartao || ' concluído.' || case when c.tipo = 'fluxo' then ' O fluxo seguiu; o que for seu chega aqui.' else '' end);
  elsif p_acao = 'decidir' then
    if c.coluna <> 'decidir' or p_opcao is null or p_opcao < 0 or jsonb_typeof(c.opcoes) <> 'array' or p_opcao >= jsonb_array_length(c.opcoes) then
      raise exception 'opção inválida para o cartão #%', p_cartao;
    end if;
    v_para := c.opcoes->p_opcao->>'para'; v_rot := c.opcoes->p_opcao->>'rotulo';
    perform rt.app_decidir(p_cartao, v_para);
    return jsonb_build_object('texto', 'Decidido: ' || coalesce(v_rot, 'opção ' || (p_opcao + 1)) || '. O fluxo seguiu.');
  elsif p_acao in ('aceitar', 'recusar') then
    perform rt.app_responder(p_cartao, p_acao = 'aceitar', null);
    return jsonb_build_object('texto', case when p_acao = 'aceitar' then 'Aceito: #' || p_cartao || ' está no seu quadro.' else 'Recusado: #' || p_cartao || ' volta para quem pediu.' end);
  end if;
  raise exception 'ação desconhecida: %', p_acao;
end $$;

insert into adm.api_funcao (nome, quem, descricao) values
 ('rt.tg_mesa', 'interno', 'Mesa no Telegram (Mini App): tarefas abertas de quem abriu'),
 ('rt.tg_agir', 'interno', 'Mesa no Telegram (Mini App): concluir, decidir, aceitar ou recusar')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;

-- 5. Bot: /mesa e o botão no /quadro ------------------------------------------------------------------------------------------
-- A interpretação que já existe fica como rt._interpretar_base (sem cópia: o que as migrações anteriores definiram continua valendo).
do $$
begin
  if to_regprocedure('rt._interpretar_base(uuid, text)') is null then
    alter function rt.interpretar(uuid, text) rename to _interpretar_base;
  end if;
end $$;

create or replace function rt.interpretar(p_pessoa uuid, p_texto text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t text := btrim(coalesce(p_texto, '')); cmd text; u text := rt._tg_app_url(); r jsonb;
  botao jsonb;
begin
  cmd := regexp_replace(lower(split_part(t, ' ', 1)), '@.*$', '');
  botao := case when u is not null then jsonb_build_array(jsonb_build_object('text', 'Abrir a Mesa', 'web_app', jsonb_build_object('url', u))) end;
  if cmd in ('/mesa', 'mesa') then
    if botao is null then return jsonb_build_object('texto', 'A Mesa no Telegram ainda não está ligada (parâmetro telegram_app.url). Use /quadro.'); end if;
    return jsonb_build_object('texto', 'Sua Mesa: tarefas abertas, decisões e pedidos para aceitar. Toque no botão para abrir.', 'botoes', jsonb_build_array(botao));
  end if;
  r := rt._interpretar_base(p_pessoa, p_texto);
  if botao is not null and (cmd in ('/quadro', 'quadro') or lower(t) in ('minhas tarefas', 'o que tenho')) then
    r := jsonb_set(r, '{botoes}', coalesce(r->'botoes', '[]'::jsonb) || jsonb_build_array(botao));
  elsif botao is not null and cmd in ('/start', '/ajuda', 'ajuda', '/help') then
    r := jsonb_set(r, '{texto}', to_jsonb((r->>'texto') || ' /mesa abre a Mesa aqui no Telegram.'));
  end if;
  return r;
end $$;

-- Permissões ------------------------------------------------------------------------------------------------------------------
revoke all on function rt._tg_app_url(), rt.tg_app_identificar(bigint, boolean), adm.tg_app_limite(text), rt._tg_restrito(bigint),
  rt.tg_mesa(), rt.tg_agir(text, bigint, int), rt.interpretar(uuid, text) from public, anon;
revoke all on function rt.tg_app_identificar(bigint, boolean), adm.tg_app_limite(text), rt._tg_restrito(bigint), rt.interpretar(uuid, text) from authenticated;
grant execute on function rt.tg_app_identificar(bigint, boolean), adm.tg_app_limite(text), rt.interpretar(uuid, text), rt._tg_app_url() to service_role;
grant execute on function rt.tg_mesa(), rt.tg_agir(text, bigint, int) to authenticated, service_role;

commit;
