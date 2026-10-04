-- Integrações cadastradas e configuradas pela Administração, de forma guiada (aprovado em 04/10/2026).
--  * serviços externos (ERP, emissor fiscal, bancos, assinatura e outros) cadastrados como conexões, com fornecedor,
--    endereço, configuração sem segredo e os nomes dos segredos;
--  * segredos gravados no cofre pela tela, só por quem administra: o valor nunca volta, nem para a tela nem para o histórico
--    (fica só a impressão de 8 caracteres do SHA-256 para conferência);
--  * teste de cada conexão pela função do servidor conexoes (Telegram, Anthropic, Kimi, Google e endereço HTTP);
--  * catálogo de sistemas do motor com o modo de cada um: simulado (só protótipo), assistido (pessoa faz) ou real (integrado).
begin;
alter table adm.conexao add column if not exists fornecedor text;
alter table adm.conexao add column if not exists config jsonb not null default '{}';
alter table adm.registro_servidor drop constraint if exists registro_servidor_funcao_check;
alter table adm.registro_servidor add constraint registro_servidor_funcao_check check (funcao in ('google', 'ia', 'alertas', 'conexoes'));

alter table rt.sistema drop constraint if exists sistema_adaptador_check;
alter table rt.sistema add constraint sistema_adaptador_check check (adaptador in ('simulado', 'assistido', 'real'));
alter table rt.sistema add column if not exists conexao text references adm.conexao(codigo);

-- quem administra (sem atuação simulada)
create or replace function adm._so_admin() returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null or not rt.pode_estrito(v, null, null, 'administrar') then raise exception 'só a administração do IMTS.OS'; end if;
  return v;
end $$;

create or replace function adm.conexao_criar(p_codigo text, p_nome text, p_categoria text, p_fornecedor text, p_endpoint text,
  p_segredos text[], p_config jsonb, p_motivo text) returns void language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._so_admin();
begin
  if coalesce(p_codigo, '') !~ '^[a-z][a-z0-9-]{2,40}$' then raise exception 'código: letras minúsculas, números e hífen'; end if;
  if coalesce(btrim(p_nome), '') = '' or coalesce(btrim(p_motivo), '') = '' then raise exception 'informe o nome e o motivo'; end if;
  if coalesce(p_endpoint, '') <> '' and p_endpoint !~ '^https://' then raise exception 'o endereço precisa começar com https://'; end if;
  if jsonb_typeof(coalesce(p_config, '{}')) <> 'object' then raise exception 'configuração inválida'; end if;
  insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, fornecedor, config, pendencia, fonte)
  values (p_codigo, btrim(p_nome), p_categoria, 'produção', nullif(p_endpoint, ''), 'Integração', 'pendente', coalesce(p_segredos, '{}'),
          case when coalesce(p_endpoint, '') <> '' then 'http' else 'manual' end, nullif(btrim(p_fornecedor), ''), coalesce(p_config, '{}'),
          'gravar os segredos e testar', 'Administração, ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM/YYYY'));
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('conexao', p_codigo, null, (select to_jsonb(c) from adm.conexao c where codigo = p_codigo), v, 'app', p_motivo);
end $$;

create or replace function adm.conexao_configurar(p_codigo text, p_fornecedor text, p_endpoint text, p_config jsonb, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._so_admin(); antes adm.conexao; depois adm.conexao;
begin
  select * into antes from adm.conexao where codigo = p_codigo for update;
  if antes.codigo is null then raise exception 'conexão desconhecida: %', p_codigo; end if;
  if coalesce(btrim(p_motivo), '') = '' then raise exception 'informe o motivo'; end if;
  if coalesce(p_endpoint, '') <> '' and p_endpoint !~ '^https://' then raise exception 'o endereço precisa começar com https://'; end if;
  if jsonb_typeof(coalesce(p_config, '{}')) <> 'object' then raise exception 'configuração inválida'; end if;
  update adm.conexao set fornecedor = coalesce(nullif(btrim(p_fornecedor), ''), fornecedor), endpoint = coalesce(nullif(p_endpoint, ''), endpoint),
         config = config || coalesce(p_config, '{}'), atualizado_em = now() where codigo = p_codigo returning * into depois;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo) values ('conexao', p_codigo, to_jsonb(antes), to_jsonb(depois), v, 'app', p_motivo);
end $$;

-- Segredo no cofre: só nomes previstos por alguma conexão; o valor nunca volta
create or replace function adm.segredo_gravar(p_nome text, p_valor text, p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._so_admin(); id_ uuid; imp text;
begin
  if not exists (select 1 from adm.conexao where p_nome = any (segredos)) then raise exception 'segredo não previsto em nenhuma conexão: %', p_nome; end if;
  if coalesce(length(p_valor), 0) < 8 or length(p_valor) > 20000 then raise exception 'valor vazio ou fora do tamanho'; end if;
  if coalesce(btrim(p_motivo), '') = '' then raise exception 'informe o motivo'; end if;
  imp := left(encode(extensions.digest(p_valor, 'sha256'), 'hex'), 8);
  select id into id_ from vault.secrets where name = p_nome;
  if id_ is null then perform vault.create_secret(p_valor, p_nome, 'gravado pela Administração');
  else perform vault.update_secret(id_, p_valor); end if;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('conexao', 'segredo:' || p_nome, null, jsonb_build_object('impressao', imp), v, 'app', p_motivo);
  return jsonb_build_object('nome', p_nome, 'impressao', imp, 'gravado', true);
end $$;

-- Situação dos segredos e das conexões (nunca o valor)
create or replace function adm.integracoes() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := adm._so_admin();
begin
  return jsonb_build_object(
    'conexoes', (select coalesce(jsonb_agg(jsonb_build_object('codigo', c.codigo, 'nome', c.nome, 'categoria', c.categoria, 'ambiente', c.ambiente,
        'estado', c.estado, 'fornecedor', c.fornecedor, 'endpoint', c.endpoint, 'config', c.config, 'saude', c.saude, 'saude_detalhe', c.saude_detalhe,
        'verificada_em', c.verificada_em, 'pendencia', c.pendencia,
        'segredos', (select coalesce(jsonb_agg(jsonb_build_object('nome', n, 'gravado', s.id is not null,
            'gravado_em', coalesce((to_jsonb(s) ->> 'updated_at')::timestamptz, s.created_at)) order by n), '[]')
          from unnest(c.segredos) n left join vault.secrets s on s.name = n)) order by c.categoria, c.nome), '[]') from adm.conexao c),
    'sistemas', (select coalesce(jsonb_agg(jsonb_build_object('codigo', s.codigo, 'nome', s.nome, 'atende', s.atende, 'adaptador', s.adaptador, 'conexao', s.conexao) order by s.codigo), '[]') from rt.sistema s),
    'parametros', (select coalesce(jsonb_object_agg(p.chave, p.valor), '{}') from adm.parametro p
                    where p.chave in ('ia.provedor', 'ia.modelo', 'ia.kimi_url', 'ia.kimi_modelo', 'ia.orcamento_mensal_tokens', 'google.usuario_sistema', 'google.drive_raiz',
                                      'servidor.url_funcoes', 'alerta.emails', 'alerta.chat_ref')));
end $$;

create or replace function adm.sistema_adaptador(p_codigo text, p_adaptador text, p_conexao text, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._so_admin(); antes rt.sistema;
begin
  select * into antes from rt.sistema where codigo = p_codigo for update;
  if antes.codigo is null then raise exception 'sistema desconhecido: %', p_codigo; end if;
  if p_adaptador not in ('assistido', 'real') then raise exception 'modo: assistido ou real'; end if;
  if p_adaptador = 'real' and (p_conexao is null or not exists (select 1 from adm.conexao where codigo = p_conexao and estado = 'ativa' and saude = 'ok')) then
    raise exception 'só vira real com uma conexão ativa e testada'; end if;
  if coalesce(btrim(p_motivo), '') = '' then raise exception 'informe o motivo'; end if;
  update rt.sistema set adaptador = p_adaptador, conexao = p_conexao where codigo = p_codigo;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('conexao', 'sistema:' || p_codigo, to_jsonb(antes), (select to_jsonb(s) from rt.sistema s where codigo = p_codigo), v, 'app', p_motivo);
end $$;

-- Resultado do teste (só a função do servidor grava)
create or replace function adm.conexao_saude(p_codigo text, p_ok boolean, p_detalhe text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  update adm.conexao set saude = case when p_ok then 'ok' else 'falha' end, saude_detalhe = left(p_detalhe, 500), verificada_em = now(),
         estado = case when p_ok and estado = 'pendente' then 'ativa' else estado end, pendencia = case when p_ok then null else pendencia end
   where codigo = p_codigo;
end $$;

-- Ligar o bot (webhook e comandos) pela tela
create or replace function adm.telegram_ligar() returns bigint language plpgsql security definer set search_path = '' as $$
begin perform adm._so_admin(); return rt.telegram_configurar(); end $$;

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
      return jsonb_build_object('pessoa', v, 'restante', teto - usado,
        'provedor', coalesce(adm.valor('ia.provedor', '"anthropic"') #>> '{}', 'anthropic'),
        'modelo', adm.valor('ia.modelo', '"claude-sonnet-5-5"') #>> '{}',
        'kimi_modelo', nullif(adm.valor('ia.kimi_modelo', '""') #>> '{}', ''),
        'kimi_url', nullif(rtrim(coalesce(adm.valor('ia.kimi_url', '""') #>> '{}', ''), '/'), ''));
    end if;
    raise exception 'ação de IA desconhecida: %', p_acao;
  elsif p_funcao = 'conexoes' then
    if v is null or not rt.pode_estrito(v, null, null, 'administrar') then raise exception 'só a administração testa conexões'; end if;
    if p_acao <> 'testar' then raise exception 'ação desconhecida: %', p_acao; end if;
    return (select jsonb_build_object('pessoa', v, 'codigo', cx.codigo, 'categoria', cx.categoria, 'endpoint', cx.endpoint, 'segredos', to_jsonb(cx.segredos), 'config', cx.config,
              'usuario_sistema', nullif(adm.valor('google.usuario_sistema', '""') #>> '{}', ''),
              'kimi_url', nullif(rtrim(coalesce(adm.valor('ia.kimi_url', '""') #>> '{}', ''), '/'), ''),
              'telegram_ambiente', coalesce(rt._segredo('telegram_ambiente'), 'teste'))
              from adm.conexao cx where cx.codigo = p_dados->>'codigo');
  end if;
  raise exception 'função do servidor desconhecida: %', p_funcao;
end $$;;

-- conexões guiadas de IA e Google que ainda não estavam no catálogo
insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('ia-anthropic', 'API Anthropic (Claude)', 'ia', 'produção', null, 'Integração', 'pendente', '{anthropic_chave}', 'manual', null, 'gravar anthropic_chave e testar', '072')
on conflict (codigo) do nothing;
update adm.conexao set segredos = '{google_conta_servico}' where codigo = 'google-drive-imts' and segredos = '{}';
update adm.conexao set segredos = array(select distinct unnest(segredos || '{telegram_bot_token}'::text[])) where codigo = 'telegram-bot-api';
update adm.conexao set categoria = 'assinatura', fornecedor = null where codigo = 'assinatura-eletronica';

revoke all on function adm._so_admin(), adm.conexao_criar(text, text, text, text, text, text[], jsonb, text), adm.conexao_configurar(text, text, text, jsonb, text),
  adm.segredo_gravar(text, text, text), adm.integracoes(), adm.sistema_adaptador(text, text, text, text), adm.conexao_saude(text, boolean, text), adm.telegram_ligar() from public, anon;
grant execute on function adm.conexao_criar(text, text, text, text, text, text[], jsonb, text), adm.conexao_configurar(text, text, text, jsonb, text),
  adm.segredo_gravar(text, text, text), adm.integracoes(), adm.sistema_adaptador(text, text, text, text), adm.telegram_ligar() to authenticated, service_role;
revoke all on function adm.conexao_saude(text, boolean, text), adm._so_admin() from authenticated;
grant execute on function adm.conexao_saude(text, boolean, text) to service_role;
insert into adm.api_funcao (nome, quem, descricao) values
  ('adm.conexao_criar', 'interno', 'Cadastrar serviço externo (só administração)'),
  ('adm.conexao_configurar', 'interno', 'Configurar serviço externo (só administração)'),
  ('adm.segredo_gravar', 'interno', 'Gravar segredo no cofre (só administração; o valor não volta)'),
  ('adm.integracoes', 'interno', 'Situação das integrações (só administração)'),
  ('adm.sistema_adaptador', 'interno', 'Modo de cada sistema do motor (só administração)'),
  ('adm.telegram_ligar', 'interno', 'Ligar o webhook e os comandos do bot (só administração)')
on conflict (nome) do nothing;
commit;
