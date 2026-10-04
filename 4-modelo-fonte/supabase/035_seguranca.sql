-- Onda 1 do plano mestre (auditoria de 04/10/2026): segurança e integridade do runtime.
-- R02/R03 identidade da chamada que bloqueia por padrão; R05 leitura só para quem é de dentro; R14 fila do pg_net; R17 webhook repetido;
-- R20 uma mudança pendente por parâmetro; R21 índices; LGPD: conteúdo apagado de verdade e eliminação do usuário externo;
-- trilha de auditoria só de acréscimo; parâmetros sem efeito saem da administração (R15); saúde das rotinas agendadas.
begin;
create table if not exists adm.erro (id bigint generated always as identity primary key, origem text not null, detalhe text not null,
  contexto jsonb not null default '{}', em timestamptz not null default now(), visto boolean not null default false);
alter table adm.erro enable row level security;

-- Quem chama. Pelo PostgREST a sessão é do "authenticator" e o papel vem do JWT (request.jwt.claims). Chamada direta ao banco
-- (cron, editor SQL, canal de carga) não tem JWT e não passa pelo authenticator. Sem JWT pela API = não é serviço (bloqueia por padrão).
create or replace function rt.chamada_servico() returns boolean language plpgsql stable security definer set search_path = '' as $$
declare v_claims text := nullif(current_setting('request.jwt.claims', true), ''); v_role text;
begin
  v_role := coalesce((v_claims::jsonb ->> 'role'), nullif(current_setting('request.jwt.claim.role', true), ''));
  if v_role is not null then return v_role = 'service_role'; end if;
  return session_user not in ('authenticator', 'anon', 'authenticated');
end $$;

-- quem é de dentro do Ecossistema e pode ler
create or replace function rt.interno() returns boolean language sql stable security definer set search_path = '' as $$
  select rt.eu() is not null and rt.pode(rt.eu(), null, null, 'ler') $$;
revoke all on function rt.chamada_servico(), rt.interno() from public;
grant execute on function rt.chamada_servico(), rt.interno() to authenticated, service_role;

-- R02: toda função que aceitava "sem login = serviço" passa a usar rt.chamada_servico()
do $$ declare f record; d text;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname in ('rt', 'doc', 'adm', 'ext') and p.prosrc like '%request.jwt.claim.role%' and p.proname <> 'chamada_servico' loop
    d := pg_get_functiondef(f.oid);
    d := replace(d, 'coalesce(nullif(current_setting(''request.jwt.claim.role'', true), ''''), ''service_role'') <> ''service_role''', 'not rt.chamada_servico()');
    execute d;
  end loop;
end $$;

-- R05: leitura para authenticated só de quem é de dentro; mensagens só da própria pessoa; rota de grupo só para o serviço
do $$ declare t record;
begin
  for t in select schemaname, tablename, policyname from pg_policies
            where schemaname in ('org', 'rt') and qual = 'true' and 'authenticated' = any (roles) loop
    execute format('drop policy %I on %I.%I', t.policyname, t.schemaname, t.tablename);
    execute format('drop policy if exists leitura_interna on %I.%I', t.schemaname, t.tablename);
    execute format('drop policy if exists leitura_propria on %I.%I', t.schemaname, t.tablename);
    if t.tablename = 'mensagem' then
      execute format('create policy leitura_propria on %I.%I for select to authenticated using (pessoa = rt.eu())', t.schemaname, t.tablename);
    elsif t.tablename = 'rota_chat' then
      null; -- só serviço
    else
      execute format('create policy leitura_interna on %I.%I for select to authenticated using (rt.interno())', t.schemaname, t.tablename);
    end if;
  end loop;
  for t in select schemaname, tablename, policyname from pg_policies
            where schemaname = 'doc' and tablename in ('marca', 'modelo', 'tipo', 'tipo_tarefa') and qual = 'true' loop
    execute format('drop policy %I on %I.%I', t.policyname, t.schemaname, t.tablename);
    execute format('drop policy if exists leitura_interna on %I.%I', t.schemaname, t.tablename);
    execute format('create policy leitura_interna on %I.%I for select to authenticated using (rt.interno())', t.schemaname, t.tablename);
  end loop;
  for t in select schemaname, tablename, policyname from pg_policies
            where schemaname = 'ext' and tablename in ('empresa_marca', 'jornada_externa') and qual = 'true' loop
    execute format('drop policy %I on %I.%I', t.policyname, t.schemaname, t.tablename);
    execute format('create policy leitura on %I.%I for select to authenticated using (rt.interno() or (ext.eu()).auth_uid is not null)', t.schemaname, t.tablename);
  end loop;
end $$;

-- R14: a fila do pg_net leva cabeçalho com chave; ninguém de fora lê
do $$ begin
  execute 'revoke select on net.http_request_queue, net._http_response from anon, authenticated';
exception when others then raise notice 'pg_net: %', sqlerrm;
end $$;

-- R20: uma mudança pendente por parâmetro
create unique index if not exists mudanca_pendente_unica on adm.mudanca (chave) where situacao = 'pendente';

-- R21: índices das consultas em uso
create index if not exists cartao_vencidos on rt.cartao (prazo) where coluna <> 'feito';
create index if not exists evento_pessoa on rt.evento (pessoa) where pessoa is not null;
create index if not exists instancia_simulado_inicio on rt.instancia (simulado, inicio desc);
create index if not exists troca_envio_instancia on rt.troca_envio (((payload ->> 'instancia')::bigint));
create index if not exists oportunidade_contraparte on ext.oportunidade (contraparte);
create index if not exists agente_memoria_fonte on rt.agente_memoria (fonte) where ativa;
create index if not exists erro_em on adm.erro (em desc);

-- R17: o Telegram reenvia o webhook quando não recebe 2xx; a mesma atualização não roda duas vezes
create table if not exists rt.update_recebido (update_id bigint primary key, recebido_em timestamptz not null default now());
alter table rt.update_recebido enable row level security;
do $$ declare d text;
begin
  d := pg_get_functiondef('rt.receber_update(jsonb,boolean)'::regprocedure);
  if position('update_recebido' in d) = 0 then
    d := replace(d, E'begin\n  v_msg := p_update->''message'';',
      E'begin\n  if p_update ? ''update_id'' then\n    insert into rt.update_recebido (update_id) values ((p_update->>''update_id'')::bigint) on conflict do nothing;\n    if not found then return jsonb_build_object(''ignorado'', ''atualização repetida''); end if;\n  end if;\n  v_msg := p_update->''message'';');
    execute d;
  end if;
end $$;
-- guarda só 7 dias de update_id (o Telegram guarda as atualizações por 24 horas)
create or replace function rt.limpar_updates() returns int language sql security definer set search_path = '' as $$
  with x as (delete from rt.update_recebido where recebido_em < now() - interval '7 days' returning 1) select count(*)::int from x $$;

-- LGPD: a mensagem apagada no Telegram tem o conteúdo apagado também na base
create or replace function rt.marcar_apagada(p_mensagem bigint) returns void language sql security definer set search_path = '' as $$
  update rt.mensagem set apagada_em = now(), conteudo = '(apagada)' where id = p_mensagem and apagada_em is null $$;
update rt.mensagem set conteudo = '(apagada)' where apagada_em is not null and conteudo <> '(apagada)' and conteudo <> '(eliminado)';

-- LGPD: exportar e eliminar o usuário externo (art. 18, II, V e VI)
create or replace function ext.exportar_usuario(p_usuario uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('usuario', to_jsonb(u) - 'auth_uid', 'contraparte', (select nome from ext.contraparte where id = u.contraparte),
    'pedidos', (select coalesce(jsonb_agg(jsonb_build_object('tipo', tipo, 'assunto', assunto, 'texto', texto, 'situacao', situacao, 'resposta', resposta, 'criado_em', criado_em) order by id), '[]')
                  from ext.pedido where usuario = u.auth_uid), 'gerado_em', now())
    from ext.usuario u where u.auth_uid = p_usuario $$;
create or replace function ext.eliminar_usuario(p_usuario uuid, p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare a int; b int;
begin
  if coalesce(length(trim(p_motivo)), 0) < 5 then raise exception 'diga o motivo da eliminação'; end if;
  update ext.usuario set nome = 'eliminado em ' || to_char(now(), 'DD/MM/YYYY'), ativo = false where auth_uid = p_usuario and ativo; get diagnostics a = row_count;
  update ext.pedido set texto = '(eliminado)', assunto = '(eliminado)' where usuario = p_usuario and texto <> '(eliminado)'; get diagnostics b = row_count;
  insert into adm.erro (origem, detalhe, contexto, visto) values ('lgpd', 'eliminação de usuário externo', jsonb_build_object('motivo', p_motivo, 'pedidos', b), true);
  return jsonb_build_object('usuario_eliminado', a > 0, 'pedidos_apagados', b);
end $$;
revoke all on function ext.exportar_usuario(uuid), ext.eliminar_usuario(uuid, text), rt.limpar_updates() from public;
grant execute on function ext.exportar_usuario(uuid), ext.eliminar_usuario(uuid, text), rt.limpar_updates() to service_role;

-- trilha de auditoria só de acréscimo: histórico da administração, eventos de documento e execuções de agente
create or replace function adm._so_acrescimo() returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'trilha de auditoria: % não altera nem apaga', tg_table_schema || '.' || tg_table_name; end $$;
drop trigger if exists so_acrescimo on adm.historico;
create trigger so_acrescimo before update or delete on adm.historico for each row execute function adm._so_acrescimo();
drop trigger if exists so_acrescimo on doc.evento;
create trigger so_acrescimo before update or delete on doc.evento for each row execute function adm._so_acrescimo();
drop trigger if exists so_acrescimo on rt.agente_execucao;
create trigger so_acrescimo before update or delete on rt.agente_execucao for each row execute function adm._so_acrescimo();
drop trigger if exists so_acrescimo on doc.aprovacao;
create trigger so_acrescimo before update or delete on doc.aprovacao for each row execute function adm._so_acrescimo();

-- R15: parâmetros que nada lia saem da administração (as regras de canal estão no código do Telegram)
delete from adm.parametro where chave in ('telegram.canal_padrao', 'telegram.fora_do_telegram')
  and not exists (select 1 from adm.mudanca m where m.chave = adm.parametro.chave);

-- Observabilidade: falhas das rotinas agendadas e erros registrados entram no painel
create or replace function adm.saude_rotinas() returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'rotinas', (select coalesce(jsonb_agg(jsonb_build_object('job', j.jobname, 'quando', j.schedule, 'ativo', j.active,
        'ultima', (select max(d.start_time) from cron.job_run_details d where d.jobid = j.jobid),
        'falhas_24h', (select count(*) from cron.job_run_details d where d.jobid = j.jobid and d.status = 'failed' and d.start_time > now() - interval '24 hours'))
        order by j.jobname), '[]') from cron.job j where j.jobname like 'imts-%'),
    'erros', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'origem', e.origem, 'detalhe', e.detalhe, 'em', e.em) order by e.id desc), '[]')
                from (select * from adm.erro where not visto order by id desc limit 30) e)) $$;
create or replace function adm.painel_completo() returns jsonb language sql stable security definer set search_path = '' as $$
  select adm.painel() || jsonb_build_object('agentes', rt.agentes_painel(), 'saude', adm.saude_rotinas()) $$;
revoke all on function adm.saude_rotinas(), adm.painel_completo() from public;
grant execute on function adm.saude_rotinas(), adm.painel_completo() to authenticated, service_role;

-- defesa em profundidade: nenhuma função dos nossos esquemas fica executável por PUBLIC ou anon; o serviço continua com tudo,
-- e authenticated só com o que foi concedido de propósito (app_*, pedir, portal, decidir, administração)
do $$ declare sch text;
begin
  foreach sch in array array['rt', 'doc', 'adm', 'ext', 'org', 'sim'] loop
    execute format('revoke execute on all functions in schema %I from public, anon', sch);
    execute format('grant execute on all functions in schema %I to service_role', sch);
  end loop;
end $$;

do $$ begin
  if not exists (select 1 from cron.job where jobname = 'imts-limpeza-updates') then perform cron.schedule('imts-limpeza-updates', '41 3 * * *', 'select rt.limpar_updates();'); end if;
end $$;
commit;
