-- P6 do inventário: Google Docs como terceira saída dos documentos emitidos (as duas primeiras são o PDF e o HTML do motor),
-- gerado pela conta de serviço do Workspace na pasta do acervo da empresa.
--
-- Desenho (o mais simples que não abre porta nova para o navegador):
--  * Ao gravar o HTML de uma emissão pronta (gatilho em doc.arquivo), se o parâmetro documentos.saida_google_docs estiver ligado e o
--    tipo do documento tiver google_docs = true, o banco põe o pedido de Doc na fila doc.google_doc e chama a Edge Function docs
--    pelo pg_net com X-IMTS-Chave (como o selo da assinatura, 076, e a rotina de alertas, 066). O pg_net só envia depois do commit:
--    emissão desfeita não gera Doc.
--  * A função docs (verify_jwt desligado, só aceita X-IMTS-Chave) toma até 5 pedidos vencidos e sobe o HTML emitido com conversão para
--    Google Docs. A função google (verify_jwt ligado) ganha a ação docs_criar, para o botão "Gerar Google Doc" da tela, com o login de
--    quem pede e a permissão decidida aqui (adm.servidor_autorizar). As duas usam o mesmo código (functions/google/tratar.ts) e as
--    mesmas funções do banco: doc.gdoc_tomar / doc.gdoc_proximos, doc.gdoc_concluir e doc.gdoc_falhar.
--  * Falha nunca toca no PDF nem no HTML: o pedido volta à fila com espera crescente (5, 10, 20... minutos, até 6 horas); a rotina
--    imts-docs-google (a cada 10 minutos) chama a função docs enquanto houver pedido vencido. Esgotadas as tentativas
--    (documentos.google_docs_tentativas), vira alerta de operação (adm._alertar, tipo erro) e fica parado até alguém pedir de novo.
--  * O id e o link do Doc ficam no registro da emissão (doc.emissao.google_doc_id e google_doc_link) e cada tentativa fica em
--    adm.registro_servidor (função google, ação docs_criar).
-- Por que não um só caminho: a função google confia na verificação de JWT da plataforma (lerUsuario não confere a assinatura); abrir
-- nela uma entrada por chave exigiria desligar o verify_jwt de todas as ações. Por isso a fila tem a sua função, como o selo.
-- Idempotente: pode rodar de novo.
begin;

-- ---------- parâmetros ----------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('documentos.saida_google_docs', 'documental', 'Gera também um Google Doc editável na pasta do acervo da empresa a cada documento emitido (só dos tipos com google_docs ligado). Deixe desligado até o Google estar configurado (google.usuario_sistema, google.drive_raiz e o segredo google_conta_servico)', 'booleano', 'false', 'false', '{}', true, '{}', 'Inventário P6 (084)'),
 ('documentos.google_docs_tentativas', 'documental', 'Tentativas de gerar o Google Doc de uma emissão antes de virar alerta de operação', 'inteiro', '5', '5', '{"min":1,"max":20}', true, '{}', 'Inventário P6 (084)')
on conflict (chave) do nothing;

-- ---------- por tipo de documento: gera ou não, e em que pasta do acervo ----------
alter table doc.tipo add column if not exists google_docs boolean not null default true;
alter table doc.tipo add column if not exists google_docs_pasta text references acervo.pasta(codigo);
comment on column doc.tipo.google_docs is 'Gera Google Doc ao emitir quando o parâmetro documentos.saida_google_docs está ligado (084)';
comment on column doc.tipo.google_docs_pasta is 'Pasta do acervo do Google Doc; vazio = pela família (contratual em 06, ata em 09, o resto em 00 Entrada) (084)';

-- ---------- no registro da emissão: o Doc gerado ----------
alter table doc.emissao add column if not exists google_doc_id text;
alter table doc.emissao add column if not exists google_doc_link text;
alter table doc.emissao add column if not exists google_doc_em timestamptz;

-- ---------- fila ----------
create table if not exists doc.google_doc (
  emissao bigint primary key references doc.emissao(id),
  empresa uuid not null references org.empresa(id),
  pasta text not null references acervo.pasta(codigo),
  situacao text not null default 'na_fila' check (situacao in ('na_fila', 'gerando', 'pronto', 'falhou')),
  origem text not null check (origem in ('emissao', 'pessoa')),
  pedido_por uuid references rt.pessoa(pseudonimo),
  tentativas smallint not null default 0,
  proxima_em timestamptz not null default now(),
  erro text,
  drive_id text,
  link text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  gerado_em timestamptz
);
create index if not exists google_doc_fila on doc.google_doc (proxima_em) where situacao in ('na_fila', 'gerando');
create index if not exists google_doc_empresa on doc.google_doc (empresa);
alter table doc.google_doc enable row level security;
drop policy if exists leitura on doc.google_doc;
create policy leitura on doc.google_doc for select to authenticated using (rt.pode((select rt.eu()), empresa, null, 'ler'));
revoke all on doc.google_doc from anon, public, authenticated;
grant select on doc.google_doc to authenticated;
grant all on doc.google_doc to service_role;

-- ---------- apoio ----------
create or replace function doc._gdoc_pasta(p_tipo text) returns text language sql stable security definer set search_path = '' as $$
  select coalesce(t.google_docs_pasta, case t.familia when 'contratual' then '06' when 'ata' then '09' else '00' end) from doc.tipo t where t.id = p_tipo $$;

create or replace function doc._gdoc_tentativas() returns int language sql stable security definer set search_path = '' as $$
  select greatest(1, coalesce((adm.valor('documentos.google_docs_tentativas', '5') #>> '{}')::int, 5)) $$;

-- põe na fila (ou devolve à fila o que falhou de vez, quando uma pessoa pede de novo); o que está na fila, gerando ou pronto fica como está
create or replace function doc._gdoc_enfileirar(p_emissao bigint, p_origem text, p_pessoa uuid) returns doc.google_doc
language plpgsql security definer set search_path = '' as $$
declare g doc.google_doc; v_emp uuid; v_tipo text;
begin
  select p.empresa, p.tipo into v_emp, v_tipo from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = p_emissao;
  if v_emp is null then raise exception 'emissão inexistente: %', p_emissao; end if;
  insert into doc.google_doc (emissao, empresa, pasta, origem, pedido_por)
  values (p_emissao, v_emp, doc._gdoc_pasta(v_tipo), p_origem, p_pessoa)
  on conflict (emissao) do update set situacao = 'na_fila', tentativas = 0, proxima_em = now(), erro = null, origem = excluded.origem,
    pedido_por = excluded.pedido_por, atualizado_em = now()
  where doc.google_doc.situacao = 'falhou' and excluded.origem = 'pessoa';
  select * into g from doc.google_doc where emissao = p_emissao;
  return g;
end $$;

-- chama a função docs pela fila do pg_net (sai depois do commit); sem endereço ou sem chave, a rotina tenta depois
create or replace function doc._gdoc_chamar() returns bigint language plpgsql security definer set search_path = '' as $$
declare u text := rt._url_funcao('docs');
begin
  if u is null or rt._segredo('imts_funcao_chave') is null or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then return null; end if;
  return net.http_post(url := u, headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{"acao":"fila"}'::jsonb, timeout_milliseconds := 60000);
end $$;

-- gatilho: HTML de emissão pronta gravado -> pedido de Doc, se o parâmetro e o tipo mandarem
create or replace function doc._gdoc_apos_arquivo() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.formato = 'html'
     and coalesce((adm.valor('documentos.saida_google_docs', 'false') #>> '{}')::boolean, false)
     and exists (select 1 from doc.emissao e join doc.pedido p on p.id = e.pedido join doc.tipo t on t.id = p.tipo
                  where e.id = new.emissao and e.situacao in ('emitido', 'emitido_com_alertas') and t.google_docs) then
    perform doc._gdoc_enfileirar(new.emissao, 'emissao', null);
    perform doc._gdoc_chamar();
  end if;
  return null;
end $$;
drop trigger if exists google_doc on doc.arquivo;
create trigger google_doc after insert on doc.arquivo for each row execute function doc._gdoc_apos_arquivo();

-- o que a função precisa para gerar um Doc: pasta (ids já registrados no acervo), nome e o HTML emitido em base64
create or replace function doc._gdoc_item(p_emissao bigint) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('emissao', g.emissao, 'empresa', g.empresa, 'empresa_nome', emp.nome, 'pasta', g.pasta,
    'pasta_nome', (select nome from acervo.pasta where codigo = g.pasta),
    'pasta_id', (select drive_id from acervo.pasta_drive d where d.empresa = g.empresa and d.pasta = g.pasta),
    'raiz_id', (select drive_id from acervo.pasta_drive d where d.empresa = g.empresa and d.pasta = 'raiz'),
    'nome', left(coalesce(nullif(btrim(p.conteudo->>'titulo'), ''), t.nome) || ' (emissão nº ' || g.emissao || ')', 200),
    'tentativa', g.tentativas,
    'html', translate(encode(a.conteudo, 'base64'), E'\n\r', ''))
    from doc.google_doc g join doc.emissao e on e.id = g.emissao join doc.pedido p on p.id = e.pedido join doc.tipo t on t.id = p.tipo
    join org.empresa emp on emp.id = g.empresa join doc.arquivo a on a.emissao = g.emissao and a.formato = 'html'
   where g.emissao = p_emissao $$;

create or replace function doc._gdoc_config() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare sistema text := nullif(adm.valor('google.usuario_sistema', '""') #>> '{}', '');
begin
  if sistema is null then raise exception 'Google ainda não configurado: falta o parâmetro google.usuario_sistema'; end if;
  return jsonb_build_object('usuario_sistema', sistema, 'drive_raiz', nullif(adm.valor('google.drive_raiz', '""') #>> '{}', ''));
end $$;

-- ---------- autorização da ação docs_criar (chamada por adm.servidor_autorizar, com o login de quem pede) ----------
create or replace function doc._gdoc_autorizar(p_dados jsonb, p_pessoa uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_em bigint; v_emp uuid; v_sit text;
begin
  if p_pessoa is null then raise exception 'só a equipe gera Google Doc'; end if;
  begin v_em := nullif(p_dados->>'emissao', '')::bigint; exception when others then raise exception 'emissão inválida'; end;
  if v_em is null then raise exception 'informe a emissão'; end if;
  select p.empresa, e.situacao into v_emp, v_sit from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = v_em;
  if v_emp is null then raise exception 'emissão inexistente: %', v_em; end if;
  if not rt.pode(p_pessoa, v_emp, null, 'operar') then raise exception 'sem acesso de operar nesta empresa'; end if;
  if v_sit not in ('emitido', 'emitido_com_alertas') then raise exception 'só documento emitido vira Google Doc (esta emissão está %)', v_sit; end if;
  if not exists (select 1 from doc.arquivo where emissao = v_em and formato = 'html') then raise exception 'esta emissão não tem o HTML: emita de novo'; end if;
  return jsonb_build_object('emissao', v_em, 'empresa', v_emp);
end $$;

-- a ação nova entra em adm.servidor_autorizar sem reescrever o resto da função (outras migrações também mexem nela)
do $$
declare def text; ancora text := E'    if p_acao = ''drive_enviar'' then\n'; n int;
begin
  def := pg_get_functiondef('adm.servidor_autorizar(text, text, jsonb)'::regprocedure);
  if position('docs_criar' in def) > 0 then return; end if;
  n := (length(def) - length(replace(def, ancora, ''))) / length(ancora);
  if n <> 1 then raise exception 'adm.servidor_autorizar mudou: o trecho da ação drive_enviar aparece % vez(es); ajuste a 084', n; end if;
  execute replace(def, ancora, E'    if p_acao = ''docs_criar'' then\n      return r || doc._gdoc_autorizar(p_dados, v);\n    elsif p_acao = ''drive_enviar'' then\n');
end $$;

-- ---------- serviço (só a chave de serviço): tomar, concluir, falhar ----------
-- pedido de uma pessoa (função google, ação docs_criar): entra na fila se faltar e é tomado na hora
create or replace function doc.gdoc_tomar(p_emissao bigint, p_pessoa uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare g doc.google_doc;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  perform doc._gdoc_enfileirar(p_emissao, 'pessoa', p_pessoa);
  select * into g from doc.google_doc where emissao = p_emissao for update;
  if g.situacao = 'pronto' then return jsonb_build_object('pronto', true, 'id', g.drive_id, 'link', g.link); end if;
  if g.situacao = 'gerando' and g.atualizado_em > now() - interval '15 minutes' then
    raise exception 'o Google Doc desta emissão já está sendo gerado: aguarde e atualize'; end if;
  update doc.google_doc set situacao = 'gerando', tentativas = tentativas + 1, atualizado_em = now(), pedido_por = coalesce(p_pessoa, pedido_por)
   where emissao = p_emissao;
  return doc._gdoc_config() || doc._gdoc_item(p_emissao) || jsonb_build_object('pronto', false);
end $$;

-- fila (função docs): toma até p_limite pedidos vencidos; o que ficou "gerando" mais de 15 minutos (função caiu no meio) volta a valer
create or replace function doc.gdoc_proximos(p_limite int default 5) returns jsonb language plpgsql security definer set search_path = '' as $$
declare cfg jsonb; ids bigint[];
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  cfg := doc._gdoc_config();
  with alvo as (
    select emissao from doc.google_doc
     where (situacao = 'na_fila' and proxima_em <= now()) or (situacao = 'gerando' and atualizado_em < now() - interval '15 minutes')
     order by proxima_em, emissao limit greatest(1, least(coalesce(p_limite, 5), 20)) for update skip locked),
  feitos as (
    update doc.google_doc g set situacao = 'gerando', tentativas = g.tentativas + 1, atualizado_em = now()
      from alvo where g.emissao = alvo.emissao returning g.emissao)
  select coalesce(array_agg(emissao order by emissao), '{}') into ids from feitos;
  return cfg || jsonb_build_object('itens', (select coalesce(jsonb_agg(doc._gdoc_item(i) order by i), '[]') from unnest(ids) i));
end $$;

create or replace function doc.gdoc_concluir(p_emissao bigint, p_drive_id text, p_link text, p_pessoa uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare g doc.google_doc;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  if coalesce(p_drive_id, '') !~ '^[A-Za-z0-9_-]{10,}$' then raise exception 'identificador do Google Doc inválido'; end if;
  if coalesce(p_link, '') !~ '^https://(docs|drive)\.google\.com/' then raise exception 'link do Google Doc inválido'; end if;
  update doc.google_doc set situacao = 'pronto', drive_id = p_drive_id, link = left(p_link, 500), erro = null, gerado_em = now(), atualizado_em = now()
   where emissao = p_emissao and situacao = 'gerando' returning * into g;
  if g.emissao is null then raise exception 'o Google Doc da emissão % não estava sendo gerado', p_emissao; end if;
  update doc.emissao set google_doc_id = p_drive_id, google_doc_link = left(p_link, 500), google_doc_em = now() where id = p_emissao;
  perform doc._evento((select pedido from doc.emissao where id = p_emissao), 'google_doc', jsonb_build_object('emissao', p_emissao, 'drive_id', p_drive_id, 'tentativa', g.tentativas));
  insert into adm.registro_servidor (funcao, acao, pessoa, alvo, ok, detalhe)
  values ('google', 'docs_criar', coalesce(p_pessoa, g.pedido_por), p_drive_id, true, 'emissão nº ' || p_emissao || ', tentativa ' || g.tentativas || case when p_pessoa is null then ' (fila)' else ' (pedido na tela)' end);
  update adm.alerta set resolvido_em = now() where chave = 'docs_google:' || p_emissao and resolvido_em is null;
  return jsonb_build_object('emissao', p_emissao, 'id', p_drive_id, 'link', left(p_link, 500));
end $$;

-- falha: nunca mexe no PDF; volta à fila com espera crescente; esgotou, alerta de operação (sem gerar um erro por tentativa)
create or replace function doc.gdoc_falhar(p_emissao bigint, p_erro text, p_pessoa uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare g doc.google_doc; v_max int := doc._gdoc_tentativas(); v_esgotou boolean;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select * into g from doc.google_doc where emissao = p_emissao for update;
  if g.emissao is null then raise exception 'sem pedido de Google Doc para a emissão %', p_emissao; end if;
  if g.situacao <> 'gerando' then return jsonb_build_object('emissao', p_emissao, 'situacao', g.situacao); end if;
  v_esgotou := g.tentativas >= v_max;
  update doc.google_doc set situacao = case when v_esgotou then 'falhou' else 'na_fila' end, erro = left(coalesce(p_erro, 'falha sem detalhe'), 1000),
    proxima_em = case when v_esgotou then proxima_em else now() + make_interval(mins => least(360, 5 * power(2, greatest(g.tentativas, 1) - 1)::int)) end,
    atualizado_em = now()
   where emissao = p_emissao returning * into g;
  insert into adm.registro_servidor (funcao, acao, pessoa, alvo, ok, detalhe)
  values ('google', 'docs_criar', coalesce(p_pessoa, g.pedido_por), 'emissao:' || p_emissao, false,
          left('tentativa ' || g.tentativas || ' de ' || v_max || ': ' || coalesce(p_erro, ''), 1000));
  if v_esgotou then
    perform adm._alertar('docs_google:' || p_emissao, 'erro', 'Google Doc da emissão nº ' || p_emissao || ' não foi gerado depois de ' || g.tentativas
      || ' tentativa(s): ' || coalesce(p_erro, '') || '. O PDF segue valendo; gere de novo pelo Acervo, aba Emitidos.');
  end if;
  return jsonb_build_object('emissao', p_emissao, 'situacao', g.situacao, 'tentativas', g.tentativas, 'proxima_em', g.proxima_em);
end $$;

-- ---------- rotina: enquanto houver pedido vencido, chama a função docs ----------
create or replace function doc.gdoc_rotina() returns jsonb language plpgsql security definer set search_path = '' as $$
declare n int; chamada bigint;
begin
  select count(*) into n from doc.google_doc
   where (situacao = 'na_fila' and proxima_em <= now()) or (situacao = 'gerando' and atualizado_em < now() - interval '15 minutes');
  if n > 0 then chamada := doc._gdoc_chamar(); end if;
  return jsonb_build_object('vencidos', n, 'chamada', chamada);
end $$;
do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('imts-docs-google', '*/10 * * * *', 'select doc.gdoc_rotina()');
  end if;
end $$;

-- ---------- tela: documentos emitidos da empresa e o Google Doc de cada um (porta única) ----------
create or replace function doc.painel_docs_google(p_empresa uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null or p_empresa is null or not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso a esta empresa'; end if;
  return jsonb_build_object(
    'ligado', nullif(adm.valor('google.usuario_sistema', '""') #>> '{}', '') is not null,
    'automatico', coalesce((adm.valor('documentos.saida_google_docs', 'false') #>> '{}')::boolean, false),
    'pode_operar', rt.pode(v, p_empresa, null, 'operar'),
    'tentativas', doc._gdoc_tentativas(),
    'emissoes', (select coalesce(jsonb_agg(x.j order by x.id desc), '[]') from (
      select e.id, jsonb_build_object('emissao', e.id, 'pedido', p.id, 'tipo', p.tipo, 'tipo_nome', t.nome,
        'titulo', coalesce(nullif(btrim(p.conteudo->>'titulo'), ''), t.nome), 'situacao', e.situacao, 'paginas', e.paginas, 'emitido_em', e.emitido_em,
        'google_docs_tipo', t.google_docs, 'pasta', doc._gdoc_pasta(p.tipo),
        'google', case when g.emissao is null and e.google_doc_link is null then null else jsonb_build_object(
          'situacao', coalesce(g.situacao, 'pronto'), 'link', coalesce(g.link, e.google_doc_link), 'tentativas', g.tentativas,
          'erro', g.erro, 'proxima_em', g.proxima_em, 'gerado_em', coalesce(g.gerado_em, e.google_doc_em)) end) as j
        from doc.emissao e join doc.pedido p on p.id = e.pedido join doc.tipo t on t.id = p.tipo
        left join doc.google_doc g on g.emissao = e.id
       where p.empresa = p_empresa and e.situacao in ('emitido', 'emitido_com_alertas')
         and exists (select 1 from doc.arquivo a where a.emissao = e.id and a.formato = 'html')
       order by e.id desc limit 50) x));
end $$;

insert into adm.api_funcao (nome, quem, descricao) values
 ('doc.painel_docs_google', 'interno', 'Acervo: documentos emitidos e o Google Doc de cada um')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;

-- ---------- catálogo de conexões: a função nova ----------
insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('edge-docs', 'Função do servidor docs (fila dos Google Docs dos documentos emitidos, chamada pelo banco e pela rotina)', 'documentos', 'produção', null, 'Integração', 'pendente',
  '{imts_funcao_chave,google_conta_servico}', 'manual', null,
  'publicar a função com verificação de JWT desligada (só aceita a chave X-IMTS-Chave), republicar a função google (ação docs_criar) e ligar documentos.saida_google_docs', '084')
on conflict (codigo) do update set nome = excluded.nome, segredos = excluded.segredos, pendencia = excluded.pendencia where adm.conexao.estado = 'pendente';

-- ---------- permissões: anon nunca; authenticated só a porta única (e o que a autorização chama por dentro); o resto, a chave de serviço ----------
revoke all on function doc._gdoc_pasta(text), doc._gdoc_tentativas(), doc._gdoc_enfileirar(bigint, text, uuid), doc._gdoc_chamar(), doc._gdoc_apos_arquivo(),
  doc._gdoc_item(bigint), doc._gdoc_config(), doc._gdoc_autorizar(jsonb, uuid), doc.gdoc_tomar(bigint, uuid), doc.gdoc_proximos(int),
  doc.gdoc_concluir(bigint, text, text, uuid), doc.gdoc_falhar(bigint, text, uuid), doc.gdoc_rotina(), doc.painel_docs_google(uuid)
  from public, anon, authenticated;
grant execute on function doc.gdoc_tomar(bigint, uuid), doc.gdoc_proximos(int), doc.gdoc_concluir(bigint, text, text, uuid), doc.gdoc_falhar(bigint, text, uuid),
  doc.gdoc_rotina() to service_role;
grant execute on function doc.painel_docs_google(uuid) to authenticated, service_role;
commit;
