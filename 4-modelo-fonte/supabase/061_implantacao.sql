-- Implantação (B08 e B11): primeiro administrador real, cobertura de papéis e conferência depois de implantar.
-- Vale em qualquer ambiente; no protótipo, a conferência aponta o que ainda é simulado.
begin;

-- Primeiro administrador: só pela chave de serviço e só enquanto não houver administrador de verdade.
-- Depois dele, todo cadastro entra pela importação (adm.importar_cadastro) ou pela Administração.
create or replace function adm.primeiro_administrador(p_nome text, p_email text) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_p uuid; v_email text := lower(btrim(p_email)); dominios jsonb := adm.valor('login.dominios', '["imts.com.br"]');
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço, na implantação'; end if;
  if exists (select 1 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
              where not p.simulado and a.nivel = 'administrar' and a.empresa is null and a.circulo is null and (a.fim is null or a.fim >= current_date)) then
    raise exception 'já existe administrador de verdade: cadastre pela Administração'; end if;
  if coalesce(btrim(p_nome), '') = '' then raise exception 'informe o nome'; end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'e-mail inválido'; end if;
  if not (dominios ? split_part(v_email, '@', 2)) then raise exception 'o e-mail precisa ser de um domínio aceito no login (%)', dominios; end if;
  if exists (select 1 from rt_chave.identidade where lower(email) = v_email) then raise exception 'e-mail já cadastrado'; end if;
  v_p := gen_random_uuid();
  insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (v_p, btrim(p_nome), v_email, false);
  insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (v_p, 'Administrador do IMTS.OS', null, false);
  insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, concedido_por, motivo)
  values (v_p, null, null, 'Administrador do IMTS.OS', 'administrar', null, 'primeiro administrador (implantação)');
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('cadastro', 'primeiro administrador', null, jsonb_build_object('pessoa', v_p, 'email', v_email), v_p, 'serviço (implantação)', 'primeiro administrador de verdade');
  return v_p;
end $$;
revoke all on function adm.primeiro_administrador(text, text) from public, anon, authenticated;
grant execute on function adm.primeiro_administrador(text, text) to service_role;

-- Papéis do modelo que recebem tarefa de pessoa e ainda não têm pessoa de verdade
create or replace function adm.cobertura_papeis() returns jsonb language sql stable security definer set search_path = '' as $$
  with exigidos as (
    -- Cliente e Parceiro são usuários do portal; Solicitante é quem pede, qualquer pessoa
    select distinct t.raia as papel from org.tarefa t where t.executor in ('P', 'H') and t.raia not in ('Cliente', 'Parceiro', 'Solicitante')
  )
  select jsonb_build_object(
    'exigidos', (select count(*) from exigidos),
    'cobertos', (select count(*) from exigidos e where exists (select 1 from rt.pessoa p where p.papel = e.papel and not p.simulado)),
    'sem_pessoa', coalesce((select jsonb_agg(e.papel order by e.papel) from exigidos e where not exists (select 1 from rt.pessoa p where p.papel = e.papel and not p.simulado)), '[]'))
$$;
revoke all on function adm.cobertura_papeis() from public, anon, authenticated;
grant execute on function adm.cobertura_papeis() to authenticated, service_role;

-- Conferência depois de implantar: não altera nada; cada item diz ok ou o que falta
create or replace function adm.conferir_implantacao() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare itens jsonb := '[]'; n int; t text; faltam text[];
  rotinas text[] := array['imts-adm-verificacao', 'imts-agentes', 'imts-atendimento-tacito', 'imts-limpeza-updates', 'imts-retencao-eventos', 'imts-vigia', 'imts-telegram-manutencao', 'imts-alertas-email'];
  segredos text[] := array['imts_funcao_chave', 'doc_worker_chave', 'telegram_bot_token', 'telegram_webhook_segredo', 'google_conta_servico', 'anthropic_chave'];
  parametros text[] := array['google.usuario_sistema', 'google.drive_raiz', 'servidor.url_funcoes', 'alerta.chat_ref'];
begin
  if rt.eu() is not null and not rt.pode_estrito(rt.eu(), null, null, 'administrar') then raise exception 'só a administração do IMTS.OS'; end if;
  -- 1. perfil
  itens := itens || jsonb_build_object('item', 'simulação desligada', 'ok', not coalesce((adm.valor('simulacao.ativa', 'true') #>> '{}')::boolean, true));
  select count(*) into n from org.empresa where simulado;
  itens := itens || jsonb_build_object('item', 'sem empresa simulada', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from rt.pessoa where simulado;
  itens := itens || jsonb_build_object('item', 'sem pessoa simulada', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from ext.contraparte where simulado;
  itens := itens || jsonb_build_object('item', 'sem cliente ou parceiro simulado', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname in ('rt', 'doc', 'adm', 'ext', 'acervo') and (p.proname like '%\_como' or p.proname like '\_testar%' or p.proname in ('simular_continuo', 'executar_simulada', 'simular_ecossistema', 'vincular_simulados', 'usuarios_simulados'));
  itens := itens || jsonb_build_object('item', 'sem funções de simulação e de teste', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from rt.sistema where adaptador = 'simulado';
  itens := itens || jsonb_build_object('item', 'nenhum sistema do motor simulado', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from adm.conexao where estado = 'simulada';
  itens := itens || jsonb_build_object('item', 'nenhuma conexão simulada', 'ok', n = 0, 'detalhe', n);
  -- 2. segurança
  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname in ('rt', 'rt_chave', 'doc', 'adm', 'ext', 'org', 'sim', 'acervo') and has_function_privilege('anon', p.oid, 'execute');
  itens := itens || jsonb_build_object('item', 'anon não executa nada', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from pg_class c join pg_namespace s on s.oid = c.relnamespace
   where s.nspname in ('rt', 'rt_chave', 'doc', 'adm', 'ext', 'org', 'sim', 'acervo') and c.relkind = 'r' and not c.relrowsecurity;
  itens := itens || jsonb_build_object('item', 'todas as tabelas com segurança por linha', 'ok', n = 0, 'detalhe', n);
  select array_agg(a.nome) into faltam from adm.api_funcao a
   where not exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
                      where s.nspname || '.' || p.proname = a.nome and has_function_privilege('authenticated', p.oid, 'execute'));
  itens := itens || jsonb_build_object('item', 'porta única: toda função da lista existe e responde', 'ok', faltam is null, 'detalhe', to_jsonb(faltam));
  -- 3. rotinas
  select array_agg(r) into faltam from unnest(rotinas) r where not exists (select 1 from cron.job j where j.jobname = r and j.active);
  itens := itens || jsonb_build_object('item', 'rotinas agendadas', 'ok', faltam is null, 'detalhe', to_jsonb(faltam));
  select count(*) into n from cron.job where jobname in ('imts-simulacao-continua', 'imts-externo-simulado');
  itens := itens || jsonb_build_object('item', 'rotinas de simulação fora da agenda', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from adm.conexao where coalesce(endpoint, '') || coalesce(alvo, '') || nome like '%rzkfolkqdgtounqjjzss%';
  itens := itens || jsonb_build_object('item', 'nenhuma conexão aponta para o protótipo', 'ok', n = 0, 'detalhe', n);
  select count(*) into n from adm.conexao where ambiente = 'produção' and estado = 'pendente';
  itens := itens || jsonb_build_object('item', 'conexões de produção pendentes', 'ok', n = 0, 'detalhe', n, 'externo', true);
  -- 4. cofre (externo: o time cadastra)
  select array_agg(s) into faltam from unnest(segredos) s where rt._segredo(s) is null;
  itens := itens || jsonb_build_object('item', 'segredos no cofre', 'ok', faltam is null, 'detalhe', to_jsonb(faltam), 'externo', true);
  -- 5. cadastro
  select count(*) into n from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
   where not p.simulado and a.nivel = 'administrar' and a.empresa is null and a.circulo is null and (a.fim is null or a.fim >= current_date);
  itens := itens || jsonb_build_object('item', 'administrador de verdade', 'ok', n > 0, 'detalhe', n);
  select count(*) into n from org.empresa where not simulado and ativa;
  itens := itens || jsonb_build_object('item', 'empresas reais cadastradas', 'ok', n > 0, 'detalhe', n, 'externo', true);
  itens := itens || jsonb_build_object('item', 'todo papel com tarefa tem pessoa', 'ok', jsonb_array_length(adm.cobertura_papeis()->'sem_pessoa') = 0,
                                       'detalhe', adm.cobertura_papeis()->'sem_pessoa', 'externo', true);
  select array_agg(k) into faltam from unnest(parametros) k where coalesce(adm.valor(k, '""') #>> '{}', '') = '';
  itens := itens || jsonb_build_object('item', 'parâmetros da implantação preenchidos', 'ok', faltam is null, 'detalhe', to_jsonb(faltam), 'externo', true);
  itens := itens || jsonb_build_object('item', 'e-mails que recebem alertas', 'ok', jsonb_array_length(coalesce(adm.valor('alerta.emails', '[]'), '[]')) > 0, 'externo', true);
  return jsonb_build_object(
    'pronto', not exists (select 1 from jsonb_array_elements(itens) i where not (i->>'ok')::boolean),
    'internos_ok', not exists (select 1 from jsonb_array_elements(itens) i where not (i->>'ok')::boolean and not coalesce((i->>'externo')::boolean, false)),
    'itens', itens);
end $$;
revoke all on function adm.conferir_implantacao() from public, anon, authenticated;
grant execute on function adm.conferir_implantacao() to authenticated, service_role;
insert into adm.api_funcao (nome, quem, descricao) values
  ('adm.conferir_implantacao', 'interno', 'Conferência da implantação (só administração)'),
  ('adm.cobertura_papeis', 'interno', 'Papéis do modelo sem pessoa de verdade')
on conflict (nome) do nothing;
commit;
