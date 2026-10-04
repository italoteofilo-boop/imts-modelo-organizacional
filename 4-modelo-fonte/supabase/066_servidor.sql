-- Funções do servidor (P4: B21, B22, B23 e alerta de armazenamento do B25).
-- As Edge Functions google, ia e alertas não decidem permissão: perguntam ao banco, com o login de quem usa
-- (adm.servidor_autorizar), executam com a conta de serviço e registram tudo (adm.registro_servidor).
begin;

-- parâmetros (o time preenche na implantação; vazios = função desligada com motivo claro)
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('google.usuario_sistema', 'administração', 'Conta do Workspace que guarda o acervo no Drive (a conta de serviço age em nome dela); ex.: sistema@imts.com.br', 'texto', '""', '""', '{}', true, '{}', 'Plano de produção (B21)'),
 ('google.drive_raiz', 'administração', 'Id da pasta raiz do acervo no Drive (de preferência num drive compartilhado); a raiz de cada empresa nasce dentro dela', 'texto', '""', '""', '{}', true, '{}', 'Plano de produção (B21)'),
 ('alerta.emails', 'administração', 'E-mails que recebem os alertas de operação (além do Telegram)', 'lista', '[]', '[]', '{}', true, '{}', 'Plano de produção (B23)'),
 ('ia.modelo', 'global', 'Modelo da API da Anthropic usado nos rascunhos (ata de reunião)', 'texto', '"claude-sonnet-5-5"', '"claude-sonnet-5-5"', '{}', true, '{}', 'Plano de produção (B22)'),
 ('ia.orcamento_mensal_tokens', 'global', 'Teto mensal de tokens (entrada + saída) da função de IA; passou, a função recusa até o mês virar', 'inteiro', '2000000', '2000000', '{"min":0,"max":100000000}', true, '{}', 'Plano de produção (B22)'),
 ('documentos.limite_mb', 'documental', 'Tamanho dos PDFs e HTMLs guardados no banco que gera alerta de armazenamento', 'inteiro', '2048', '2048', '{"min":100,"max":100000}', true, '{}', 'Plano de produção (B25)')
on conflict (chave) do nothing;

-- registro de tudo o que as funções do servidor fazem
create table if not exists adm.registro_servidor (
  id bigint generated always as identity primary key,
  funcao text not null check (funcao in ('google', 'ia', 'alertas')),
  acao text not null,
  pessoa uuid references rt.pessoa(pseudonimo),
  usuario uuid,
  alvo text,
  ok boolean not null,
  detalhe text,
  tokens_entrada int, tokens_saida int,
  em timestamptz not null default now()
);
create index if not exists registro_servidor_em on adm.registro_servidor (funcao, em desc);
create index if not exists registro_servidor_pessoa on adm.registro_servidor (pessoa);
alter table adm.registro_servidor enable row level security;
drop policy if exists leitura on adm.registro_servidor;
create policy leitura on adm.registro_servidor for select to authenticated using (rt.pode_estrito((select rt.eu()), null, null, 'ler'));

alter table adm.alerta add column if not exists email_em timestamptz;
alter table adm.alerta drop constraint if exists alerta_tipo_check;
alter table adm.alerta add constraint alerta_tipo_check check (tipo in ('erro', 'conexao', 'rotina', 'fila_documentos', 'fila_envio', 'armazenamento'));

-- tokens de IA usados no mês corrente
create or replace function adm._ia_usado_no_mes() returns bigint language sql stable security definer set search_path = '' as $$
  select coalesce(sum(coalesce(tokens_entrada, 0) + coalesce(tokens_saida, 0)), 0)::bigint from adm.registro_servidor
   where funcao = 'ia' and ok and em >= date_trunc('month', now() at time zone 'America/Fortaleza') at time zone 'America/Fortaleza' $$;

-- Autorização: chamada pela Edge Function com o papel authenticated e o login de quem usa.
create or replace function adm.servidor_autorizar(p_funcao text, p_acao text, p_dados jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu(); u ext.usuario; c ext.contraparte; emp uuid; v_pasta text; r jsonb; v_id text; usado bigint; teto bigint;
  sistema text := nullif(adm.valor('google.usuario_sistema', '""') #>> '{}', ''); raiz text := nullif(adm.valor('google.drive_raiz', '""') #>> '{}', '');
begin
  if v is null then u := ext.eu(); end if;
  if v is null and u.auth_uid is null then raise exception 'login sem cadastro'; end if;
  v_id := nullif(p_dados->>'id', '');

  if p_funcao = 'google' then
    if sistema is null then raise exception 'Google ainda não configurado: falta o parâmetro google.usuario_sistema'; end if;
    r := jsonb_build_object('usuario_sistema', sistema, 'drive_raiz', raiz, 'pessoa', v, 'usuario', u.auth_uid);

    if p_acao = 'drive_enviar' then
      if v is not null then
        emp := nullif(p_dados->>'empresa', '')::uuid; v_pasta := coalesce(nullif(p_dados->>'pasta', ''), '00');
        if emp is null or not rt.pode(v, emp, null, 'operar') then raise exception 'sem acesso de operar nesta empresa'; end if;
        if not exists (select 1 from acervo.pasta where codigo = v_pasta) then raise exception 'pasta do acervo inexistente: %', v_pasta; end if;
      else
        u := ext._exigir_eu(); select * into c from ext.contraparte where id = u.contraparte;
        emp := c.empresa; v_pasta := case c.tipo when 'parceiro' then '07' else '08' end;   -- quem é de fora só envia para a sua pasta
      end if;
      return r || jsonb_build_object('empresa', emp, 'pasta', v_pasta, 'pasta_nome', (select nome from acervo.pasta where codigo = v_pasta),
        'empresa_nome', (select nome from org.empresa where id = emp),
        'pasta_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = v_pasta),
        'raiz_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = 'raiz'));

    elsif p_acao = 'drive_pasta' then
      emp := nullif(p_dados->>'empresa', '')::uuid; v_pasta := p_dados->>'pasta';
      if v is null or emp is null or not rt.pode(v, emp, null, 'operar') then raise exception 'sem acesso de operar nesta empresa'; end if;
      if v_pasta <> 'raiz' and not exists (select 1 from acervo.pasta where codigo = v_pasta) then raise exception 'pasta do acervo inexistente: %', v_pasta; end if;
      return r || jsonb_build_object('empresa', emp, 'pasta', v_pasta, 'empresa_nome', (select nome from org.empresa where id = emp),
        'pasta_nome', case when v_pasta = 'raiz' then (select nome from org.empresa where id = emp) else (select nome from acervo.pasta where codigo = v_pasta) end,
        'pasta_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = v_pasta),
        'raiz_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = 'raiz'));

    elsif p_acao = 'drive_ler' then
      if v is null or not rt.pode(v, null, null, 'operar') then raise exception 'só a equipe lê arquivos do Drive'; end if;
      if v_id is null then raise exception 'informe o id do arquivo'; end if;
      return r || jsonb_build_object('id', v_id);

    elsif p_acao in ('drive_lixeira', 'drive_mover', 'drive_renomear') then
      if v_id is null then raise exception 'informe o id do arquivo'; end if;
      -- o arquivo precisa ser do acervo de uma empresa em que a pessoa opera, ou ter sido enviado por ela na última hora
      if not exists (select 1 from acervo.arquivo a where a.drive_id = v_id and v is not null and rt.pode(v, a.empresa, null, 'operar'))
         and not exists (select 1 from adm.registro_servidor s where s.funcao = 'google' and s.acao = 'drive_enviar' and s.ok and s.alvo = v_id
                          and s.em > now() - interval '1 hour' and (s.pessoa = v or s.usuario = u.auth_uid)) then
        raise exception 'arquivo fora do seu acervo'; end if;
      if p_acao in ('drive_lixeira', 'drive_mover') and v is null then raise exception 'só a equipe move ou apaga arquivos'; end if;
      if p_acao = 'drive_mover' then
        select a.empresa into emp from acervo.arquivo a where a.drive_id = v_id limit 1;
        emp := coalesce(emp, nullif(p_dados->>'empresa', '')::uuid); v_pasta := p_dados->>'pasta';
        if emp is null or not rt.pode(v, emp, null, 'operar') then raise exception 'sem acesso de operar nesta empresa'; end if;
        if not exists (select 1 from acervo.pasta where codigo = v_pasta) then raise exception 'pasta do acervo inexistente: %', v_pasta; end if;
        return r || jsonb_build_object('id', v_id, 'empresa', emp, 'pasta', v_pasta, 'pasta_nome', (select nome from acervo.pasta where codigo = v_pasta),
          'pasta_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = v_pasta),
          'raiz_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = 'raiz'), 'empresa_nome', (select nome from org.empresa where id = emp));
      end if;
      return r || jsonb_build_object('id', v_id);

    elsif p_acao in ('drive_listar', 'drive_baixar') then
      if v is null then raise exception 'só a equipe lista o Drive'; end if;
      -- listar: a pasta precisa estar registrada numa empresa em que a pessoa opera; baixar: um dos pais do arquivo (a função manda) também
      if not exists (select 1 from acervo.pasta_drive d where rt.pode(v, d.empresa, null, 'operar')
                       and d.drive_id = any (array(select jsonb_array_elements_text(coalesce(p_dados->'pais', jsonb_build_array(p_dados->>'pasta_id')))))) then
        raise exception 'pasta fora do acervo das suas empresas'; end if;
      return r || jsonb_build_object('id', v_id, 'pasta_id', p_dados->>'pasta_id');

    elsif p_acao in ('agenda_evento', 'agenda_cancelar') then
      if v is null or not rt.pode(v, null, null, 'operar') then raise exception 'só a equipe marca reunião'; end if;
      return r || jsonb_build_object('organizador', (select email from rt_chave.identidade where pseudonimo = v));
    end if;
    raise exception 'ação do Google desconhecida: %', p_acao;

  elsif p_funcao = 'ia' then
    if v is null or not rt.pode(v, null, null, 'operar') then raise exception 'só a equipe usa a IA'; end if;
    teto := coalesce((adm.valor('ia.orcamento_mensal_tokens', '0') #>> '{}')::bigint, 0); usado := adm._ia_usado_no_mes();
    if usado >= teto then raise exception 'orçamento mensal da IA esgotado (% de % tokens)', usado, teto; end if;
    if p_acao = 'ata_rascunho' then
      if not exists (select 1 from ext.reuniao where id = nullif(p_dados->>'reuniao', '')::bigint) then raise exception 'reunião inexistente'; end if;
      perform ext._reuniao_acesso(nullif(p_dados->>'reuniao', '')::bigint, v);
      return jsonb_build_object('pessoa', v, 'modelo', adm.valor('ia.modelo', '"claude-sonnet-5-5"') #>> '{}', 'restante', teto - usado);
    end if;
    raise exception 'ação de IA desconhecida: %', p_acao;
  end if;
  raise exception 'função do servidor desconhecida: %', p_funcao;
end $$;
revoke all on function adm.servidor_autorizar(text, text, jsonb) from public, anon;
grant execute on function adm.servidor_autorizar(text, text, jsonb) to authenticated, service_role;

-- Registro do que a função fez (só pela chave de serviço) e pasta criada no Drive
create or replace function adm.servidor_registrar(p_funcao text, p_acao text, p_pessoa uuid, p_usuario uuid, p_alvo text, p_ok boolean, p_detalhe text,
  p_tokens_entrada int default null, p_tokens_saida int default null) returns bigint language plpgsql security definer set search_path = '' as $$
declare n bigint;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  insert into adm.registro_servidor (funcao, acao, pessoa, usuario, alvo, ok, detalhe, tokens_entrada, tokens_saida)
  values (p_funcao, p_acao, p_pessoa, p_usuario, left(p_alvo, 300), p_ok, left(p_detalhe, 1000), p_tokens_entrada, p_tokens_saida) returning id into n;
  if not p_ok then insert into adm.erro (origem, detalhe) values (p_funcao || '.' || p_acao, left(coalesce(p_detalhe, ''), 1000)); end if;
  return n;
end $$;
create or replace function adm.servidor_pasta(p_empresa uuid, p_pasta text, p_drive_id text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  if coalesce(p_drive_id, '') !~ '^[A-Za-z0-9_-]{10,}$' then raise exception 'identificador de pasta inválido'; end if;
  insert into acervo.pasta_drive (empresa, pasta, drive_id) values (p_empresa, p_pasta, p_drive_id)
  on conflict (empresa, pasta) do update set drive_id = excluded.drive_id;
end $$;
-- Alertas que ainda não foram por e-mail (a função alertas marca o envio)
create or replace function adm.alertas_para_email() returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  return jsonb_build_object('para', adm.valor('alerta.emails', '[]'), 'remetente', adm.valor('google.usuario_sistema', '""') #>> '{}',
    'alertas', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'tipo', tipo, 'detalhe', detalhe, 'primeiro_em', primeiro_em, 'vezes', vezes) order by id), '[]')
                  from adm.alerta where resolvido_em is null and email_em is null));
end $$;
create or replace function adm.alertas_email_enviado(p_ids bigint[]) returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  update adm.alerta set email_em = now() where id = any (p_ids) and email_em is null; get diagnostics n = row_count; return n;
end $$;
revoke all on function adm.servidor_registrar(text, text, uuid, uuid, text, boolean, text, int, int), adm.servidor_pasta(uuid, text, text),
  adm.alertas_para_email(), adm.alertas_email_enviado(bigint[]), adm._ia_usado_no_mes() from public, anon, authenticated;
grant execute on function adm.servidor_registrar(text, text, uuid, uuid, text, boolean, text, int, int), adm.servidor_pasta(uuid, text, text),
  adm.alertas_para_email(), adm.alertas_email_enviado(bigint[]) to service_role;

-- rotina dos alertas por e-mail: a cada 10 minutos chama a função alertas (mesma chave das tarefas do Telegram)
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'imts-alertas-email';
    perform cron.schedule('imts-alertas-email', '*/10 * * * *', $c$select net.http_post(url := (select valor #>> '{}' from adm.parametro where chave = 'servidor.url_funcoes') || '/alertas',
      headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')), body := '{}'::jsonb)
      where exists (select 1 from adm.alerta where resolvido_em is null and email_em is null) and coalesce((select valor #>> '{}' from adm.parametro where chave = 'servidor.url_funcoes'), '') <> ''$c$);
  end if;
end $$;
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('servidor.url_funcoes', 'administração', 'Endereço das Edge Functions do projeto (https://<ref>.supabase.co/functions/v1); vazio = rotinas que chamam funções ficam paradas', 'texto', '""', '""', '{}', true, '{}', 'Plano de produção (B23)')
on conflict (chave) do nothing;
-- vigia também o armazenamento dos documentos
CREATE OR REPLACE FUNCTION adm.vigiar()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r record; v_min int := coalesce((adm.valor('alerta.fila_minutos', '30') #>> '{}')::int, 30); chat text := nullif(adm.valor('alerta.chat_ref', '""') #>> '{}', ''); n_novos int := 0; vistos text[] := '{}';
begin
  for r in select 'erro:' || origem as chave, count(*) n, max(detalhe) d from adm.erro where em > now() - interval '15 minutes' group by origem loop
    perform adm._alertar(r.chave, 'erro', r.n || ' erro(s) em ' || substr(r.chave, 6) || ': ' || coalesce(r.d, '')); vistos := vistos || r.chave;
  end loop;
  for r in select 'conexao:' || codigo as chave, nome, saude_detalhe from adm.conexao where estado = 'ativa' and saude = 'falha' loop
    perform adm._alertar(r.chave, 'conexao', r.nome || ' com falha: ' || coalesce(r.saude_detalhe, '')); vistos := vistos || r.chave;
  end loop;
  if to_regclass('cron.job_run_details') is not null then
    for r in execute $q$select 'rotina:' || j.jobname as chave, count(*) n from cron.job_run_details d join cron.job j on j.jobid = d.jobid
                         where d.status = 'failed' and d.start_time > now() - interval '1 hour' group by j.jobname$q$ loop
      perform adm._alertar(r.chave, 'rotina', 'rotina ' || substr(r.chave, 8) || ' falhou ' || r.n || ' vez(es) na última hora'); vistos := vistos || r.chave;
    end loop;
  end if;
  if exists (select 1 from doc.pedido where situacao = 'na_fila' and criado_em < now() - make_interval(mins => v_min)) then
    perform adm._alertar('fila:documentos', 'fila_documentos', (select count(*) from doc.pedido where situacao = 'na_fila' and criado_em < now() - make_interval(mins => v_min)) || ' documento(s) na fila há mais de ' || v_min || ' minutos: o worker parou?');
    vistos := vistos || 'fila:documentos'::text;
  end if;
  if exists (select 1 from rt.fila_envio where not simulado and estado in ('pendente', 'erro') and criado_em < now() - make_interval(mins => v_min)) then
    perform adm._alertar('fila:envio', 'fila_envio', (select count(*) from rt.fila_envio where not simulado and estado in ('pendente', 'erro') and criado_em < now() - make_interval(mins => v_min)) || ' mensagem(ns) do Telegram presas há mais de ' || v_min || ' minutos');
    vistos := vistos || 'fila:envio'::text;
  end if;
  -- armazenamento: PDFs e HTMLs guardados no banco acima do limite (B25: hora de levar ao Storage)
  if (select coalesce(sum(bytes), 0) from doc.arquivo) > coalesce((adm.valor('documentos.limite_mb', '2048') #>> '{}')::bigint, 2048) * 1024 * 1024 then
    perform adm._alertar('armazenamento:documentos', 'armazenamento', 'documentos emitidos ocupam ' || pg_size_pretty((select sum(bytes) from doc.arquivo)::bigint)
      || ' no banco, acima do limite de ' || (adm.valor('documentos.limite_mb', '2048') #>> '{}') || ' MB');
    vistos := vistos || 'armazenamento:documentos'::text;
  end if;
  -- fecha o que sumiu (erros fecham sozinhos depois de 1 hora sem repetir)
  update adm.alerta set resolvido_em = now() where resolvido_em is null and not (chave = any (vistos))
     and (tipo <> 'erro' or ultimo_em < now() - interval '1 hour');
  -- avisa uma vez
  for r in select id, detalhe from adm.alerta where resolvido_em is null and avisado_em is null loop
    if chat is not null then insert into rt.fila_envio (chat_ref, texto, simulado) values (chat, 'Alerta IMTS.OS: ' || r.detalhe, false); end if;
    update adm.alerta set avisado_em = now() where id = r.id; n_novos := n_novos + 1;
  end loop;
  return jsonb_build_object('abertos', (select count(*) from adm.alerta where resolvido_em is null), 'novos', n_novos);
end $function$;
commit;
