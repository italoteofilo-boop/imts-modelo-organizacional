-- E13 · Administração geral (aprovada por Ítalo em 04/10/2026). Esquema adm:
-- 1. Registro único das conexões externas: ambiente, endpoint, dono, estado, saúde e só o NOME do segredo no Vault (nunca o valor).
-- 2. Parâmetros num lugar só, com escopo, validação, histórico, propagação ao destino (rt.config, rt.parametro_simulacao, pg_cron)
--    e aprovação em duas mãos para os sensíveis.
-- 3. Verificação de saúde das conexões (SQL, Vault, HTTP pelo pg_net) e o painel que a página de administração lê.
begin;
create schema if not exists adm;
revoke all on schema adm from anon;
grant usage on schema adm to authenticated, service_role;

-- nome de segredo: snake_case curto; recusa o que parece valor (hex ou base64 longo)
create or replace function adm._nomes_de_segredo_ok(p text[]) returns boolean language sql immutable set search_path = '' as $$
  select coalesce(bool_and(n ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)+$' and length(n) <= 40 and n !~ '[0-9a-f]{16,}'), true) from unnest(p) n $$;

create table if not exists adm.conexao (
  codigo text primary key, nome text not null,
  categoria text not null check (categoria in ('banco de dados','api','mensageria','segredos','agenda','documentos','contábil','fiscal','bancário','assinatura','ia','repositório','domínio')),
  ambiente text not null check (ambiente in ('protótipo','teste','produção')),
  endpoint text, dono text not null,
  estado text not null check (estado in ('ativa','simulada','pendente','desligada')),
  segredos text[] not null default '{}' check (adm._nomes_de_segredo_ok(segredos)),
  verificacao text not null check (verificacao in ('sql','segredo','http','manual')),
  alvo text, sistema text references rt.sistema(codigo),
  saude text not null default 'desconhecida' check (saude in ('ok','falha','desconhecida')),
  saude_detalhe text, verificada_em timestamptz, pendencia text, fonte text not null, atualizado_em timestamptz not null default now());

create table if not exists adm.parametro (
  chave text primary key check (chave ~ '^[a-z_]+(\.[a-z_]+)+$'),
  escopo text not null check (escopo in ('global','telegram','simulação','documental','administração','acesso')),
  descricao text not null,
  tipo text not null check (tipo in ('inteiro','número','texto','booleano','lista','faixa')),
  valor jsonb not null, padrao jsonb not null,
  validacao jsonb not null default '{}',       -- {"min":..,"max":..,"opcoes":[..]}
  sensivel boolean not null default false,     -- mudança só com aprovação de outra pessoa
  destinos text[] not null default '{}',       -- rt.config:<chave> | rt.parametro_simulacao:<executor> | cron:<job> | cron_comando:<job>
  fonte text not null, atualizado_em timestamptz not null default now(), atualizado_por uuid);

create table if not exists adm.mudanca (
  id bigint generated always as identity primary key, chave text not null references adm.parametro(chave),
  valor jsonb not null, motivo text not null check (length(trim(motivo)) > 0), pedido_por uuid, pedido_em timestamptz not null default now(),
  situacao text not null default 'pendente' check (situacao in ('pendente','aprovada','recusada')),
  decidido_por uuid, decidido_em timestamptz, motivo_decisao text);

create table if not exists adm.historico (
  id bigint generated always as identity primary key, objeto text not null check (objeto in ('parametro','conexao')),
  chave text not null, antes jsonb, depois jsonb, por uuid, como text not null, motivo text, em timestamptz not null default now());

create table if not exists adm.verificacao_http (conexao text primary key references adm.conexao(codigo), pedido bigint not null, em timestamptz not null default now());

-- Quem age: a pessoa do login; sem login, só o service_role, e então informando como quem atua (protótipo da página via MCP) ------
create or replace function adm._quem(p_como uuid) returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then
    if not rt.chamada_servico() then raise exception 'sem identidade'; end if;
    v := p_como;
  end if;
  if v is null or not rt.pode_estrito(v, null, null, 'administrar') then raise exception 'sem acesso de administrar'; end if;
  return v;
end $$;

create or replace function adm.valor(p_chave text, p_padrao jsonb default null) returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((select valor from adm.parametro where chave = p_chave), p_padrao) $$;

create or replace function adm._validar(p adm.parametro, v jsonb) returns text language plpgsql immutable set search_path = '' as $$
declare n numeric;
begin
  case p.tipo
    when 'inteiro', 'número' then
      if jsonb_typeof(v) <> 'number' then return 'esperado número'; end if;
      n := (v #>> '{}')::numeric;
      if p.tipo = 'inteiro' and n <> trunc(n) then return 'esperado inteiro'; end if;
      if p.validacao ? 'min' and n < (p.validacao->>'min')::numeric then return 'abaixo do mínimo ' || (p.validacao->>'min'); end if;
      if p.validacao ? 'max' and n > (p.validacao->>'max')::numeric then return 'acima do máximo ' || (p.validacao->>'max'); end if;
    when 'texto' then
      if jsonb_typeof(v) <> 'string' then return 'esperado texto'; end if;
      if p.validacao ? 'opcoes' and not (p.validacao->'opcoes') ? (v #>> '{}') then return 'fora das opções ' || (p.validacao->>'opcoes'); end if;
    when 'booleano' then if jsonb_typeof(v) <> 'boolean' then return 'esperado verdadeiro ou falso'; end if;
    when 'lista' then
      if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) = 0 then return 'esperada lista não vazia'; end if;
    when 'faixa' then
      if jsonb_typeof(v->'min') <> 'number' or jsonb_typeof(v->'max') <> 'number' then return 'esperado {min, max}'; end if;
      if (v->>'min')::numeric < 0 or (v->>'min')::numeric > (v->>'max')::numeric then return 'mínimo maior que o máximo ou negativo'; end if;
  end case;
  return null;
end $$;

-- aplica o valor e propaga a cada destino; tudo na mesma transação
create or replace function adm._aplicar(p_chave text, v jsonb, p_por uuid, p_como text, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare p adm.parametro; d text; alvo text; n int;
begin
  select * into p from adm.parametro where chave = p_chave for update;
  foreach d in array p.destinos loop
    alvo := split_part(d, ':', 2);
    case split_part(d, ':', 1)
      when 'rt.config' then update rt.config set valor = v, origem = 'adm: ' || p_chave || ' em ' || to_char(now(), 'DD/MM/YYYY HH24:MI'), atualizado_em = now() where chave = alvo;
      when 'rt.parametro_simulacao' then
        update rt.parametro_simulacao set min_minutos = (v->>'min')::numeric, max_minutos = (v->>'max')::numeric,
               origem = 'adm: ' || p_chave || ' em ' || to_char(now(), 'DD/MM/YYYY HH24:MI') where executor::text = alvo;
      when 'cron' then
        n := (v #>> '{}')::int;
        perform cron.alter_job(job_id := (select jobid from cron.job where jobname = alvo), schedule := case when n >= 60 then '0 */' || (n / 60) || ' * * *' else '*/' || n || ' * * * *' end);
      when 'cron_comando' then
        if alvo = 'imts-limpeza-simulado' then
          perform cron.alter_job(job_id := (select jobid from cron.job where jobname = alvo), command := 'select rt.limpar_simulado(' || ((v #>> '{}')::int) || ')');
        else raise exception 'destino de comando sem regra: %', alvo; end if;
      else raise exception 'destino desconhecido: %', d;
    end case;
  end loop;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo) values ('parametro', p_chave, p.valor, v, p_por, p_como, p_motivo);
  update adm.parametro set valor = v, atualizado_em = now(), atualizado_por = p_por where chave = p_chave;
end $$;

create or replace function adm.alterar_parametro(p_chave text, p_valor jsonb, p_motivo text, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_eu uuid := adm._quem(p_como); p adm.parametro; erro text; m bigint;
begin
  select * into p from adm.parametro where chave = p_chave; if not found then raise exception 'parâmetro desconhecido: %', p_chave; end if;
  if coalesce(length(trim(p_motivo)), 0) = 0 then raise exception 'informe o motivo'; end if;
  erro := adm._validar(p, p_valor); if erro is not null then raise exception 'valor inválido para %: %', p_chave, erro; end if;
  if p.valor = p_valor then return jsonb_build_object('situacao', 'sem mudança'); end if;
  if p.sensivel then
    insert into adm.mudanca (chave, valor, motivo, pedido_por) values (p_chave, p_valor, p_motivo, v_eu) returning id into m;
    return jsonb_build_object('situacao', 'pendente', 'mudanca', m);
  end if;
  perform adm._aplicar(p_chave, p_valor, v_eu, case when rt.eu() is null then 'página de administração (protótipo)' else 'app' end, p_motivo);
  return jsonb_build_object('situacao', 'aplicada');
end $$;

create or replace function adm.decidir_mudanca(p_mudanca bigint, p_decisao text, p_motivo text, p_como uuid default null) returns text
language plpgsql security definer set search_path = '' as $$
declare v_eu uuid := adm._quem(p_como); m adm.mudanca; p adm.parametro; erro text;
begin
  select * into m from adm.mudanca where id = p_mudanca for update; if not found then raise exception 'mudança inexistente'; end if;
  if m.situacao <> 'pendente' then raise exception 'mudança já decidida'; end if;
  if m.pedido_por = v_eu then raise exception 'quem pediu não decide a própria mudança'; end if;
  if p_decisao not in ('aprovada', 'recusada') then raise exception 'decisão inválida'; end if;
  if p_decisao = 'recusada' and coalesce(length(trim(p_motivo)), 0) = 0 then raise exception 'recusa exige motivo'; end if;
  if p_decisao = 'aprovada' then
    select * into p from adm.parametro where chave = m.chave;
    erro := adm._validar(p, m.valor); if erro is not null then raise exception 'valor deixou de ser válido: %', erro; end if;
    perform adm._aplicar(m.chave, m.valor, v_eu, 'aprovação da mudança ' || m.id, m.motivo || coalesce(' | aprovação: ' || p_motivo, ''));
  end if;
  update adm.mudanca set situacao = p_decisao, decidido_por = v_eu, decidido_em = now(), motivo_decisao = p_motivo where id = m.id;
  return p_decisao;
end $$;

-- conexões: editáveis só nos campos de cadastro; o alvo da verificação SQL só muda por migração
create or replace function adm.alterar_conexao(p_codigo text, p_campos jsonb, p_motivo text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v_eu uuid := adm._quem(p_como); c adm.conexao; k text; novo adm.conexao;
begin
  select * into c from adm.conexao where codigo = p_codigo for update; if not found then raise exception 'conexão desconhecida: %', p_codigo; end if;
  if coalesce(length(trim(p_motivo)), 0) = 0 then raise exception 'informe o motivo'; end if;
  for k in select jsonb_object_keys(p_campos) loop
    if k not in ('nome','ambiente','endpoint','dono','estado','segredos','pendencia') then raise exception 'campo não editável aqui: %', k; end if;
  end loop;
  update adm.conexao set nome = coalesce(p_campos->>'nome', nome), ambiente = coalesce(p_campos->>'ambiente', ambiente),
         endpoint = case when p_campos ? 'endpoint' then p_campos->>'endpoint' else endpoint end, dono = coalesce(p_campos->>'dono', dono),
         estado = coalesce(p_campos->>'estado', estado),
         segredos = case when p_campos ? 'segredos' then array(select jsonb_array_elements_text(p_campos->'segredos')) else segredos end,
         pendencia = case when p_campos ? 'pendencia' then nullif(p_campos->>'pendencia', '') else pendencia end, atualizado_em = now()
   where codigo = p_codigo returning * into novo;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('conexao', p_codigo, to_jsonb(c) - 'alvo' - 'saude' - 'saude_detalhe' - 'verificada_em', to_jsonb(novo) - 'alvo' - 'saude' - 'saude_detalhe' - 'verificada_em', v_eu,
          case when rt.eu() is null then 'página de administração (protótipo)' else 'app' end, p_motivo);
end $$;

-- saúde: SQL e Vault na hora; HTTP pelo pg_net (dispara agora, colhe na rodada seguinte)
create or replace function adm.verificar_conexoes() returns jsonb language plpgsql security definer set search_path = '' as $$
declare c adm.conexao; ok boolean; faltam text[]; r record; n_ok int := 0; n_falha int := 0; n_http int := 0; h jsonb;
begin
  -- colhe as respostas HTTP da rodada anterior
  for r in select v.conexao, v.pedido, x.status_code, x.error_msg, x.timed_out from adm.verificacao_http v left join net._http_response x on x.id = v.pedido loop
    if r.status_code is not null or r.error_msg is not null or r.timed_out then
      -- a função do Telegram responde 200 só com a chave certa; as demais só precisam responder (até 499)
      update adm.conexao set saude = case when (r.conexao = 'edge-telegram' and r.status_code = 200) or (r.conexao <> 'edge-telegram' and r.status_code between 200 and 499) then 'ok' else 'falha' end,
             saude_detalhe = coalesce('HTTP ' || r.status_code, r.error_msg, 'sem resposta no prazo'), verificada_em = now() where codigo = r.conexao;
      delete from adm.verificacao_http where conexao = r.conexao;
    end if;
  end loop;
  for c in select * from adm.conexao where estado <> 'desligada' order by codigo loop
    if c.verificacao = 'segredo' or (c.verificacao in ('sql', 'http') and array_length(c.segredos, 1) > 0) then
      select array_agg(s) into faltam from unnest(c.segredos) s where rt._segredo(s) is null;
      if faltam is not null then
        update adm.conexao set saude = 'falha', saude_detalhe = 'segredo ausente no Vault: ' || array_to_string(faltam, ', '), verificada_em = now() where codigo = c.codigo;
        n_falha := n_falha + 1; continue;
      elsif c.verificacao = 'segredo' then
        update adm.conexao set saude = 'ok', saude_detalhe = 'segredos presentes no Vault', verificada_em = now() where codigo = c.codigo; n_ok := n_ok + 1; continue;
      end if;
    end if;
    if c.verificacao = 'sql' then
      begin execute 'select (' || c.alvo || ')::boolean' into ok; exception when others then ok := false; end;
      update adm.conexao set saude = case when ok then 'ok' else 'falha' end, saude_detalhe = case when ok then 'conferência SQL passou' else 'conferência SQL falhou' end, verificada_em = now() where codigo = c.codigo;
      if ok then n_ok := n_ok + 1; else n_falha := n_falha + 1; end if;
    elsif c.verificacao = 'http' and not exists (select 1 from adm.verificacao_http where conexao = c.codigo) then
      h := case when c.codigo = 'edge-telegram' then jsonb_build_object('x-imts-chave', rt._segredo('imts_funcao_chave'), 'content-type', 'application/json') else '{}'::jsonb end;
      insert into adm.verificacao_http values (c.codigo,
        case when c.codigo = 'edge-telegram' then net.http_post(url := c.alvo, body := '{}'::jsonb, headers := h, timeout_milliseconds := 10000)
             else net.http_get(url := c.alvo, timeout_milliseconds := 10000) end, now())
      on conflict (conexao) do nothing;
      n_http := n_http + 1;
    end if;
  end loop;
  return jsonb_build_object('ok', n_ok, 'falha', n_falha, 'http_disparadas', n_http);
end $$;

create or replace function adm.painel() returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if rt.eu() is not null and not rt.pode_estrito(rt.eu(), null, null, 'administrar') then raise exception 'sem acesso de administrar'; end if;
  if rt.eu() is null and not rt.chamada_servico() then raise exception 'sem identidade'; end if;
  return jsonb_build_object(
    'gerado_em', now(),
    'resumo', jsonb_build_object(
      'conexoes', (select count(*) from adm.conexao), 'ativas', (select count(*) from adm.conexao where estado = 'ativa'),
      'pendentes', (select count(*) from adm.conexao where estado = 'pendente'), 'simuladas', (select count(*) from adm.conexao where estado = 'simulada'),
      'saude_ok', (select count(*) from adm.conexao where saude = 'ok'), 'saude_falha', (select count(*) from adm.conexao where saude = 'falha'),
      'parametros', (select count(*) from adm.parametro), 'mudancas_pendentes', (select count(*) from adm.mudanca where situacao = 'pendente'),
      'fila_documentos', (select coalesce(jsonb_object_agg(situacao, n), '{}') from (select situacao, count(*) n from doc.pedido group by 1) x)),
    'conexoes', (select coalesce(jsonb_agg(to_jsonb(c) - 'alvo' order by c.categoria, c.codigo), '[]') from adm.conexao c),
    'parametros', (select coalesce(jsonb_agg(to_jsonb(p) order by p.escopo, p.chave), '[]') from adm.parametro p),
    'mudancas', (select coalesce(jsonb_agg(to_jsonb(m) order by m.id desc), '[]') from (select * from adm.mudanca order by id desc limit 50) m),
    'historico', (select coalesce(jsonb_agg(to_jsonb(h) order by h.id desc), '[]') from (select * from adm.historico order by id desc limit 100) h),
    'administradores', (select coalesce(jsonb_agg(jsonb_build_object('pessoa', a.pessoa, 'papel', a.papel) order by a.papel), '[]')
                          from rt.acesso a where a.nivel = 'administrar' and (a.fim is null or a.fim >= current_date)),
    'agenda', (select coalesce(jsonb_agg(jsonb_build_object('job', jobname, 'quando', schedule, 'ativo', active) order by jobname), '[]') from cron.job where jobname like 'imts-%'));
end $$;

-- Conexões do Ecossistema (o que existe hoje; estado e pendência conferidos em 04/10/2026) -------------------------------------------
insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, sistema, pendencia, fonte) values
 ('supabase-postgres', 'Banco Postgres do Supabase (projeto rzkfolkqdgtounqjjzss)', 'banco de dados', 'protótipo', 'https://rzkfolkqdgtounqjjzss.supabase.co', 'Integração', 'ativa', '{}', 'sql', 'true', null, null, 'projeto Supabase em uso desde 03/10/2026'),
 ('supabase-api', 'API REST do Supabase (PostgREST)', 'api', 'protótipo', 'https://rzkfolkqdgtounqjjzss.supabase.co/rest/v1/', 'Integração', 'ativa', '{}', 'http', 'https://rzkfolkqdgtounqjjzss.supabase.co/rest/v1/', null, null, 'canal de carga e do worker documental'),
 ('supabase-vault', 'Cofre de segredos (Supabase Vault)', 'segredos', 'protótipo', null, 'Governança', 'ativa', '{}', 'sql', 'exists (select 1 from pg_extension where extname = ''supabase_vault'')', null, null, 'extensão supabase_vault'),
 ('pg-cron', 'Agenda do banco (pg_cron)', 'agenda', 'protótipo', null, 'Integração', 'ativa', '{}', 'sql', '(select count(*) from cron.job where jobname like ''imts-%'' and active) >= 4', null, null, 'jobs imts-* do cron.job'),
 ('pg-net', 'Chamadas HTTP do banco (pg_net)', 'api', 'protótipo', null, 'Integração', 'ativa', '{}', 'sql', 'exists (select 1 from pg_extension where extname = ''pg_net'')', null, 'extensão no esquema public (aviso do Supabase); mover exige reinstalar a extensão', 'extensão pg_net'),
 ('edge-telegram', 'Função do canal Telegram (Edge Function telegram)', 'mensageria', 'teste', 'https://rzkfolkqdgtounqjjzss.supabase.co/functions/v1/telegram', 'Relações', 'ativa', '{imts_funcao_chave,telegram_webhook_segredo,telegram_ambiente}', 'http', 'https://rzkfolkqdgtounqjjzss.supabase.co/functions/v1/telegram?tarefa=estado', null, null, '019 e 021, função publicada em 03/10/2026'),
 ('telegram-bot-api', 'Bot API do Telegram (ambiente de teste)', 'mensageria', 'teste', 'https://api.telegram.org', 'Relações', 'pendente', '{telegram_bot_token}', 'segredo', null, 'canal-pessoa', 'Ítalo cria o bot, grava o token no Vault (vault.create_secret) e roda rt.telegram_configurar()', 'Bot API, ambiente de teste'),
 ('telegram-mini-app', 'Domínio do Mini App do Telegram', 'domínio', 'teste', null, 'Integração', 'pendente', '{}', 'manual', null, null, 'o Supabase entrega HTML de Edge Function como texto no domínio padrão: falta domínio próprio', 'teste de 03/10/2026'),
 ('doc-worker', 'Worker do motor documental (Chromium)', 'documentos', 'protótipo', null, 'Integração', 'ativa', '{doc_worker_chave}', 'sql', 'not exists (select 1 from doc.pedido where situacao = ''na_fila'' and criado_em < now() - interval ''30 minutes'')', 'motor-documental', 'no protótipo o worker roda no ambiente de trabalho do Claude; em produção, serviço a escolher', 'E12, 04/10/2026'),
 ('github-repo', 'Repositório do modelo (GitHub)', 'repositório', 'produção', 'https://github.com/italoteofilo-boop/imts-modelo-organizacional', 'Integração', 'ativa', '{}', 'manual', null, null, null, 'repositório do projeto'),
 ('google-drive-imts', 'Google Drive da IMTS (saída Google Docs)', 'documentos', 'produção', null, 'Integração', 'pendente', '{}', 'manual', null, 'motor-documental', 'conectar o Drive da IMTS para a terceira saída do motor documental', 'decisão de 04/10/2026: PDF e HTML agora, Docs depois'),
 ('erp-contabil', 'Sistema contábil e financeiro (ERP)', 'contábil', 'protótipo', null, 'Gestão', 'simulada', '{}', 'manual', null, 'erp-contabil', 'escolher o ERP da stack de produção', '014, adaptador simulado'),
 ('emissor-fiscal', 'Emissor de documentos fiscais', 'fiscal', 'protótipo', null, 'Gestão', 'simulada', '{}', 'manual', null, 'emissor-fiscal', 'escolher o emissor da stack de produção', '014, adaptador simulado'),
 ('banco', 'Bancos (extrato, pagamento, cobrança)', 'bancário', 'protótipo', null, 'Gestão', 'simulada', '{}', 'manual', null, 'banco', 'escolher os bancos e a forma de integração', '014, adaptador simulado'),
 ('assinatura-eletronica', 'Assinatura eletrônica (DocuSign)', 'assinatura', 'produção', null, 'Governança', 'pendente', '{}', 'manual', null, 'motor-documental', 'conectar a DocuSign; as âncoras /ass_A/, /ass_B/, /ass_T1/ e /ass_T2/ já saem no PDF', 'decisão de 28/09/2026 (motor de contratos)'),
 ('agentes-ia', 'Provedor dos agentes de IA', 'ia', 'protótipo', null, 'Integração', 'simulada', '{}', 'manual', null, 'agente-ia', 'escolher o provedor e liberar cada agente pela IT-06', '005, adaptador simulado')
on conflict (codigo) do nothing;

-- Parâmetros: cada um com o destino onde vale; o valor inicial é o que roda hoje ----------------------------------------------------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('telegram.autodestruicao_horas', 'telegram', 'Horas até o bot apagar a mensagem enviada (o Telegram só deixa apagar até 48 h)', 'inteiro', '47', '47', '{"min":1,"max":47}', true, '{rt.config:autodestruicao_horas}', 'rt.config; limite do deleteMessage'),
 ('telegram.manutencao_minutos', 'telegram', 'Intervalo da manutenção do canal (fila de envio e autodestruição)', 'inteiro', '10', '10', '{"min":1,"max":59}', false, '{cron:imts-telegram-manutencao}', '021'),
 ('simulacao.intervalo_minutos', 'simulação', 'Intervalo da simulação contínua (uma execução por vez)', 'inteiro', '5', '5', '{"min":1,"max":59}', false, '{cron:imts-simulacao-continua,rt.config:simulacao_continua_minutos}', 'escolha de 03/10/2026, 21:05, por custo'),
 ('simulacao.retencao_dias', 'simulação', 'Dias que os dados simulados ficam antes da limpeza', 'inteiro', '30', '30', '{"min":1,"max":365}', true, '{cron_comando:imts-limpeza-simulado}', '016'),
 ('simulacao.tempo_pessoa', 'simulação', 'Tempo simulado de tarefa de pessoa do círculo (P), em minutos', 'faixa', '{"min":30,"max":240}', '{"min":30,"max":240}', '{}', false, '{rt.parametro_simulacao:P}', 'hipótese do protótipo, a calibrar no G9'),
 ('simulacao.tempo_agente', 'simulação', 'Tempo simulado de tarefa de agente (A), em minutos', 'faixa', '{"min":2,"max":20}', '{"min":2,"max":20}', '{}', false, '{rt.parametro_simulacao:A}', 'hipótese do protótipo, a calibrar no G9'),
 ('simulacao.tempo_automacao', 'simulação', 'Tempo simulado de automação (R), em minutos', 'faixa', '{"min":0.1,"max":2}', '{"min":0.1,"max":2}', '{}', false, '{rt.parametro_simulacao:R}', 'hipótese do protótipo, a calibrar no G9'),
 ('simulacao.tempo_fora', 'simulação', 'Tempo simulado de quem é de fora do círculo (H), em minutos', 'faixa', '{"min":60,"max":2880}', '{"min":60,"max":2880}', '{}', false, '{rt.parametro_simulacao:H}', 'hipótese do protótipo, a calibrar no G9'),
 ('simulacao.tempo_outro_circulo', 'simulação', 'Tempo simulado de troca com outro círculo (C), em minutos', 'faixa', '{"min":60,"max":2880}', '{"min":60,"max":2880}', '{}', false, '{rt.parametro_simulacao:C}', 'hipótese do protótipo, a calibrar no G9'),
 ('simulacao.tempo_assessoria', 'simulação', 'Tempo simulado de assessoria externa (X), em minutos', 'faixa', '{"min":1440,"max":7200}', '{"min":1440,"max":7200}', '{}', false, '{rt.parametro_simulacao:X}', 'hipótese do protótipo, a calibrar no G9'),
 ('documental.tentativas_maximas', 'documental', 'Tentativas do worker antes de o pedido parar em erro', 'inteiro', '3', '3', '{"min":1,"max":10}', false, '{}', 'E12, 04/10/2026'),
 ('documental.destravar_minutos', 'documental', 'Minutos para um pedido preso em emissão voltar à fila', 'inteiro', '15', '15', '{"min":5,"max":240}', false, '{}', 'E12, 04/10/2026'),
 ('administracao.verificacao_minutos', 'administração', 'Intervalo da verificação de saúde das conexões', 'inteiro', '30', '30', '{"min":5,"max":59}', false, '{cron:imts-adm-verificacao}', 'E13, 04/10/2026')
on conflict (chave) do nothing;

-- o motor documental lê documental.tentativas_maximas e documental.destravar_minutos daqui por doc._param (025)

-- verificação periódica das conexões e destravamento da fila de documentos
do $$ begin
  if not exists (select 1 from cron.job where jobname = 'imts-adm-verificacao') then
    perform cron.schedule('imts-adm-verificacao', '*/30 * * * *', 'select adm.verificar_conexoes(); select doc.destravar();');
  end if;
end $$;

-- Segurança ------------------------------------------------------------------------------------------------------------------------
alter table adm.conexao enable row level security; alter table adm.parametro enable row level security;
alter table adm.mudanca enable row level security; alter table adm.historico enable row level security; alter table adm.verificacao_http enable row level security;
drop policy if exists leitura on adm.conexao; drop policy if exists leitura on adm.parametro; drop policy if exists leitura on adm.mudanca; drop policy if exists leitura on adm.historico;
create policy leitura on adm.conexao for select to authenticated using (rt.pode_estrito(rt.eu(), null, null, 'administrar'));
create policy leitura on adm.parametro for select to authenticated using (rt.pode(rt.eu(), null, null, 'ler'));
create policy leitura on adm.mudanca for select to authenticated using (rt.pode_estrito(rt.eu(), null, null, 'administrar'));
create policy leitura on adm.historico for select to authenticated using (rt.pode_estrito(rt.eu(), null, null, 'administrar'));
grant select on adm.conexao, adm.parametro, adm.mudanca, adm.historico to authenticated;
grant all on all tables in schema adm to service_role;
revoke all on all functions in schema adm from public;
grant execute on function adm.alterar_parametro(text, jsonb, text, uuid), adm.decidir_mudanca(bigint, text, text, uuid), adm.alterar_conexao(text, jsonb, text, uuid),
  adm.painel(), adm.valor(text, jsonb) to authenticated, service_role;
grant execute on function adm.verificar_conexoes() to service_role;
grant execute on function adm._nomes_de_segredo_ok(text[]) to authenticated, service_role;
commit;
