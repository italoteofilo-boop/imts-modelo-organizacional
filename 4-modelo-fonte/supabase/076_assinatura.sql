-- Assinatura eletrônica AVANÇADA própria do IMTS.OS (aprovada pelo Ítalo em 05/10/2026).
--
-- Base legal (só estas; nada além delas é citado aqui):
--  * Lei 14.063/2020, art. 4º, II (https://www.planalto.gov.br/ccivil_03/_ato2019-2022/2020/lei/l14063.htm): a assinatura
--    eletrônica avançada está associada ao signatário de maneira unívoca, usa dados para a criação da assinatura sob o controle
--    exclusivo do signatário e está relacionada aos dados a ela associados de modo que qualquer modificação posterior seja detectável.
--  * MP 2.200-2/2001, art. 10, § 2º (https://www.planalto.gov.br/ccivil_03/mpv/antigas_2001/2200-2.htm): admite outros meios de
--    comprovação da autoria e da integridade de documentos eletrônicos, desde que admitidos pelas partes como válidos ou aceitos
--    pela pessoa a quem for oposto o documento.
--
-- Como cada exigência do art. 4º, II é atendida:
--  * associada de maneira unívoca: o signatário só assina com o próprio login (Google do Workspace para a equipe, link por e-mail
--    para cliente e parceiro) e a assinatura fica ligada ao pseudônimo da pessoa ou ao usuário do portal, com nome e e-mail;
--  * controle exclusivo: além do login, um código de 6 dígitos enviado ao e-mail do signatário (Edge Function assinatura, Gmail
--    da conta do sistema), com validade curta, limite de tentativas e guardado só como hash;
--  * modificação detectável: o pedido guarda o SHA-256 do PDF; a assinatura só acontece se o PDF ainda tiver o mesmo hash; cada
--    evento entra numa trilha encadeada por hash (sha256(hash_anterior || conteúdo canônico)) que não aceita alteração nem exclusão;
--    no fim, o manifesto (hash do PDF, signatários, evidências e hash final da trilha) recebe o selo do IMTS (ECDSA P-256).
--
-- LIMITE: quando a lei ou o órgão público exigir assinatura QUALIFICADA (certificado ICP-Brasil), esta assinatura NÃO serve.
-- O pedido marcado "exige ICP-Brasil" não aceita código nem assinatura aqui: só registra que cada parte assinou fora, com a
-- referência informada por quem pediu, e não recebe o selo do IMTS.
--
-- Fluxo: pedir (rascunho ou aguardando) -> cada signatário, na ordem, pede o código (Edge Function assinatura) e assina com o
-- código pela porta única -> concluido -> o selo do manifesto é assinado e a página de manifesto é anexada ao PDF (Edge Function
-- assinatura, a pedido de quem assina, ou Edge Function selo, chamada pelo banco ao concluir e pela rotina) -> verificação pública
-- pelo código (Edge Function verificar, sem login). Recusa encerra; quem pediu cancela; o prazo vence (rotina e leitura).
-- Idempotente: pode rodar de novo.
begin;

-- ---------- registro das funções do servidor: assinatura e verificar ----------
alter table adm.registro_servidor drop constraint if exists registro_servidor_funcao_check;
alter table adm.registro_servidor add constraint registro_servidor_funcao_check
  check (funcao in ('google', 'ia', 'alertas', 'conexoes', 'assinatura', 'verificar'));

-- ---------- parâmetros ----------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('assinatura.codigo_validade_min', 'documental', 'Minutos de validade do código de 6 dígitos enviado por e-mail para assinar', 'inteiro', '10', '10', '{"min":2,"max":30}', true, '{}', 'Assinatura eletrônica avançada (076)'),
 ('assinatura.codigo_tentativas', 'documental', 'Tentativas com código errado antes de o código ser bloqueado (a pessoa pede outro)', 'inteiro', '5', '5', '{"min":3,"max":10}', true, '{}', 'Assinatura eletrônica avançada (076)'),
 ('assinatura.codigos_por_hora', 'documental', 'Códigos que um signatário pode pedir por hora', 'inteiro', '5', '5', '{"min":2,"max":20}', true, '{}', 'Assinatura eletrônica avançada (076)'),
 ('assinatura.prazo_padrao_dias', 'documental', 'Prazo padrão, em dias, para todos assinarem um pedido', 'inteiro', '15', '15', '{"min":1,"max":180}', true, '{}', 'Assinatura eletrônica avançada (076)'),
 ('assinatura.url_verificacao', 'documental', 'Endereço público da página de verificação (o código vai no parâmetro c)', 'texto', '"https://www.imts.global/verificar.html"', '"https://www.imts.global/verificar.html"', '{}', true, '{}', 'Assinatura eletrônica avançada (076)')
on conflict (chave) do nothing;

-- ---------- tabelas ----------
create table if not exists doc.assinatura_pedido (
  id bigint generated always as identity primary key,
  empresa uuid not null references org.empresa(id),
  emissao bigint not null references doc.emissao(id),
  titulo text not null check (length(btrim(titulo)) between 1 and 300),
  hash_documento text not null check (hash_documento ~ '^[0-9a-f]{64}$'),
  bytes_documento int not null check (bytes_documento > 0),
  codigo text not null unique check (codigo ~ '^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$'),
  situacao text not null default 'rascunho' check (situacao in ('rascunho', 'aguardando', 'concluido', 'recusado', 'cancelado', 'vencido')),
  exige_icp boolean not null default false,
  prazo timestamptz not null,
  pedido_por uuid not null references rt.pessoa(pseudonimo),
  criado_em timestamptz not null default now(),
  enviado_em timestamptz, concluido_em timestamptz,
  encerrado_em timestamptz, encerrado_motivo text,
  check (situacao not in ('recusado', 'cancelado') or coalesce(length(btrim(encerrado_motivo)), 0) > 0),
  check (situacao <> 'concluido' or concluido_em is not null)
);
create table if not exists doc.assinatura_signatario (
  id bigint generated always as identity primary key,
  pedido bigint not null references doc.assinatura_pedido(id),
  ordem smallint not null check (ordem between 1 and 20),
  pessoa uuid references rt.pessoa(pseudonimo),
  usuario uuid references ext.usuario(auth_uid),
  nome text not null,
  email text not null,
  situacao text not null default 'pendente' check (situacao in ('pendente', 'assinado', 'recusado', 'assinado_fora')),
  assinado_em timestamptz,
  recusado_motivo text,
  evidencia jsonb,
  fora_referencia text,
  check (num_nonnulls(pessoa, usuario) = 1),
  check (situacao <> 'assinado' or (assinado_em is not null and evidencia is not null)),
  check (situacao <> 'assinado_fora' or coalesce(length(btrim(fora_referencia)), 0) > 0),
  unique (pedido, ordem)
);
create unique index if not exists assinatura_signatario_pessoa on doc.assinatura_signatario (pedido, pessoa) where pessoa is not null;
create unique index if not exists assinatura_signatario_usuario on doc.assinatura_signatario (pedido, usuario) where usuario is not null;
create index if not exists assinatura_signatario_pessoa_i on doc.assinatura_signatario (pessoa) where pessoa is not null;
create index if not exists assinatura_signatario_usuario_i on doc.assinatura_signatario (usuario) where usuario is not null;
create index if not exists assinatura_pedido_empresa on doc.assinatura_pedido (empresa, situacao);
create index if not exists assinatura_pedido_emissao on doc.assinatura_pedido (emissao);
create index if not exists assinatura_pedido_por on doc.assinatura_pedido (pedido_por);

-- código do segundo fator: só o hash (com sal); nunca o número
create table if not exists doc.assinatura_codigo (
  id bigint generated always as identity primary key,
  signatario bigint not null references doc.assinatura_signatario(id),
  hash text not null,
  sal text not null,
  criado_em timestamptz not null default now(),
  valido_ate timestamptz not null,
  tentativas smallint not null default 0,
  usado_em timestamptz,
  invalidado_em timestamptz
);
create index if not exists assinatura_codigo_signatario on doc.assinatura_codigo (signatario, criado_em desc);

-- trilha de eventos encadeada por hash, imutável
create table if not exists doc.assinatura_evento (
  id bigint generated always as identity primary key,
  pedido bigint not null references doc.assinatura_pedido(id),
  seq int not null,
  tipo text not null check (tipo in ('pedido', 'enviado', 'codigo_enviado', 'codigo_nao_enviado', 'codigo_errado', 'codigo_bloqueado',
                                     'assinado', 'assinado_fora', 'recusado', 'cancelado', 'vencido', 'concluido', 'selado')),
  signatario bigint references doc.assinatura_signatario(id),
  dados jsonb not null default '{}',
  em timestamptz not null default clock_timestamp(),
  hash_anterior text not null,
  hash text not null,
  unique (pedido, seq)
);
create index if not exists assinatura_evento_signatario on doc.assinatura_evento (signatario) where signatario is not null;

-- chave pública do selo do IMTS (a privada fica só no cofre: assinatura_chave_privada, em JWK)
create table if not exists doc.assinatura_chave (
  kid text primary key,
  publica jsonb not null,
  algoritmo text not null default 'ES256' check (algoritmo = 'ES256'),
  ativa boolean not null default true,
  criada_em timestamptz not null default now()
);
create unique index if not exists assinatura_chave_uma_ativa on doc.assinatura_chave ((true)) where ativa;

-- selo: manifesto canônico, assinatura ECDSA e o PDF final (original com a página de manifesto, ou só o manifesto)
create table if not exists doc.assinatura_selo (
  pedido bigint primary key references doc.assinatura_pedido(id),
  manifesto text not null,
  hash_manifesto text not null,
  assinatura text not null,
  kid text not null references doc.assinatura_chave(kid),
  pdf bytea not null,
  hash_pdf text not null,
  bytes int not null,
  formato text not null check (formato in ('original_com_manifesto', 'manifesto_separado')),
  selado_em timestamptz not null default now()
);
create index if not exists assinatura_selo_kid on doc.assinatura_selo (kid);

alter table doc.assinatura_pedido enable row level security;
alter table doc.assinatura_signatario enable row level security;
alter table doc.assinatura_codigo enable row level security;
alter table doc.assinatura_evento enable row level security;
alter table doc.assinatura_chave enable row level security;
alter table doc.assinatura_selo enable row level security;

-- quem lê um pedido: a equipe com leitura na empresa; o signatário (de dentro ou de fora) lê o seu
create or replace function doc._ass_le(p_pedido bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from doc.assinatura_pedido p where p.id = p_pedido
                   and ((rt.eu() is not null and rt.pode(rt.eu(), p.empresa, null, 'ler'))
                        or exists (select 1 from doc.assinatura_signatario s where s.pedido = p.id
                                     and ((s.pessoa is not null and s.pessoa = rt.eu()) or (s.usuario is not null and s.usuario = auth.uid()))))) $$;
drop policy if exists leitura on doc.assinatura_pedido;
create policy leitura on doc.assinatura_pedido for select to authenticated using (doc._ass_le(id));
drop policy if exists leitura on doc.assinatura_signatario;
create policy leitura on doc.assinatura_signatario for select to authenticated using (doc._ass_le(pedido));
drop policy if exists leitura on doc.assinatura_evento;
create policy leitura on doc.assinatura_evento for select to authenticated
  using (rt.eu() is not null and exists (select 1 from doc.assinatura_pedido p where p.id = pedido and rt.pode(rt.eu(), p.empresa, null, 'ler')));
drop policy if exists leitura on doc.assinatura_selo;
create policy leitura on doc.assinatura_selo for select to authenticated using (doc._ass_le(pedido));
drop policy if exists leitura on doc.assinatura_chave;
create policy leitura on doc.assinatura_chave for select to authenticated using (true);
-- código: sem política de leitura (ninguém lê pela API)
revoke all on doc.assinatura_pedido, doc.assinatura_signatario, doc.assinatura_codigo, doc.assinatura_evento, doc.assinatura_chave, doc.assinatura_selo from anon, public, authenticated;
grant select on doc.assinatura_pedido, doc.assinatura_signatario, doc.assinatura_evento, doc.assinatura_chave, doc.assinatura_selo to authenticated;
grant all on doc.assinatura_pedido, doc.assinatura_signatario, doc.assinatura_codigo, doc.assinatura_evento, doc.assinatura_chave, doc.assinatura_selo to service_role;

-- ---------- apoio ----------
create or replace function doc._ass_iso(p timestamptz) returns text language sql immutable set search_path = '' as $$
  select to_char(p at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') $$;

create or replace function doc._ass_sha256(p text) returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest(convert_to(p, 'UTF8'), 'sha256'), 'hex') $$;

-- conteúdo canônico de um evento: jsonb normalizado (chaves em ordem fixa do Postgres) em texto
create or replace function doc._ass_canonico(p_pedido bigint, p_seq int, p_tipo text, p_signatario bigint, p_em timestamptz, p_dados jsonb) returns text
language sql immutable set search_path = '' as $$
  select jsonb_build_object('pedido', p_pedido, 'seq', p_seq, 'tipo', p_tipo, 'signatario', p_signatario, 'em', doc._ass_iso(p_em), 'dados', coalesce(p_dados, '{}'::jsonb))::text $$;

create or replace function doc._ass_hash_evento(p_anterior text, p_pedido bigint, p_seq int, p_tipo text, p_signatario bigint, p_em timestamptz, p_dados jsonb) returns text
language sql immutable set search_path = '' as $$
  select doc._ass_sha256(p_anterior || doc._ass_canonico(p_pedido, p_seq, p_tipo, p_signatario, p_em, p_dados)) $$;

-- a trilha se encadeia sozinha: quem insere não escolhe seq, hora nem hash
create or replace function doc._ass_evento_encadear() returns trigger language plpgsql set search_path = '' as $$
declare v_seq int; v_ant text;
begin
  perform pg_advisory_xact_lock(hashtextextended('assinatura_evento:' || new.pedido, 0));
  select e.seq, e.hash into v_seq, v_ant from doc.assinatura_evento e where e.pedido = new.pedido order by e.seq desc limit 1;
  if v_seq is null then
    v_seq := 0; select hash_documento into v_ant from doc.assinatura_pedido where id = new.pedido;   -- o primeiro elo é o hash do documento
  end if;
  new.seq := v_seq + 1; new.em := clock_timestamp(); new.hash_anterior := v_ant; new.dados := coalesce(new.dados, '{}');
  new.hash := doc._ass_hash_evento(v_ant, new.pedido, new.seq, new.tipo, new.signatario, new.em, new.dados);
  return new;
end $$;
drop trigger if exists encadear on doc.assinatura_evento;
create trigger encadear before insert on doc.assinatura_evento for each row execute function doc._ass_evento_encadear();

create or replace function doc._ass_imutavel() returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'a trilha de assinatura é imutável: % não é permitido em %', lower(tg_op), tg_table_name;
end $$;
drop trigger if exists imutavel on doc.assinatura_evento;
create trigger imutavel before update or delete on doc.assinatura_evento for each row execute function doc._ass_imutavel();
drop trigger if exists imutavel_truncate on doc.assinatura_evento;
create trigger imutavel_truncate before truncate on doc.assinatura_evento for each statement execute function doc._ass_imutavel();
drop trigger if exists imutavel on doc.assinatura_selo;
create trigger imutavel before update or delete on doc.assinatura_selo for each row execute function doc._ass_imutavel();
drop trigger if exists imutavel_truncate on doc.assinatura_selo;
create trigger imutavel_truncate before truncate on doc.assinatura_selo for each statement execute function doc._ass_imutavel();

-- o que identifica o pedido não muda depois de criado
create or replace function doc._ass_pedido_guarda() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'pedido de assinatura não se apaga: cancele com motivo'; end if;
  if new.hash_documento <> old.hash_documento or new.emissao <> old.emissao or new.codigo <> old.codigo or new.empresa <> old.empresa or new.pedido_por <> old.pedido_por
     or new.exige_icp <> old.exige_icp then
    raise exception 'documento, código, empresa, solicitante e exigência de ICP-Brasil do pedido não mudam'; end if;
  if old.situacao in ('concluido', 'recusado', 'cancelado', 'vencido') and new.situacao <> old.situacao then
    raise exception 'pedido encerrado (%) não muda de situação', old.situacao; end if;
  return new;
end $$;
drop trigger if exists guarda on doc.assinatura_pedido;
create trigger guarda before update or delete on doc.assinatura_pedido for each row execute function doc._ass_pedido_guarda();

create or replace function doc._ass_signatario_guarda() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'signatário não se apaga'; end if;
  if new.pedido <> old.pedido or new.ordem <> old.ordem or new.pessoa is distinct from old.pessoa or new.usuario is distinct from old.usuario
     or new.nome <> old.nome or new.email <> old.email then raise exception 'quem assina e em que ordem não muda depois do pedido'; end if;
  if old.situacao <> 'pendente' and (new.situacao <> old.situacao or new.evidencia is distinct from old.evidencia or new.assinado_em is distinct from old.assinado_em) then
    raise exception 'assinatura registrada não muda'; end if;
  return new;
end $$;
drop trigger if exists guarda on doc.assinatura_signatario;
create trigger guarda before update or delete on doc.assinatura_signatario for each row execute function doc._ass_signatario_guarda();

-- eventos
create or replace function doc._ass_evento(p_pedido bigint, p_tipo text, p_signatario bigint, p_dados jsonb) returns text
language plpgsql security definer set search_path = '' as $$
declare h text;
begin
  insert into doc.assinatura_evento (pedido, tipo, signatario, dados, hash_anterior, hash) values (p_pedido, p_tipo, p_signatario, coalesce(p_dados, '{}'), '', '')
  returning hash into h;
  return h;
end $$;

-- confere a trilha inteira (ou até o evento p_ate): sequência sem buraco, elo anterior certo e hash recalculado igual
create or replace function doc._ass_trilha(p_pedido bigint, p_ate int default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare e record; v_ant text; v_n int := 0; ok boolean := true;
begin
  select hash_documento into v_ant from doc.assinatura_pedido where id = p_pedido;
  if v_ant is null then return jsonb_build_object('ok', false, 'eventos', 0, 'hash_final', null); end if;
  for e in select * from doc.assinatura_evento where pedido = p_pedido and (p_ate is null or seq <= p_ate) order by seq loop
    v_n := v_n + 1;
    if e.seq <> v_n or e.hash_anterior <> v_ant or e.hash <> doc._ass_hash_evento(v_ant, e.pedido, e.seq, e.tipo, e.signatario, e.em, e.dados) then ok := false; end if;
    v_ant := e.hash;
  end loop;
  return jsonb_build_object('ok', ok and v_n > 0, 'eventos', v_n, 'hash_final', v_ant);
end $$;

create or replace function doc._ass_hash_atual(p_emissao bigint) returns text language sql stable security definer set search_path = '' as $$
  select encode(extensions.digest(conteudo, 'sha256'), 'hex') from doc.arquivo where emissao = p_emissao and formato = 'pdf' $$;

create or replace function doc._ass_mascarar(p_email text) returns text language sql immutable set search_path = '' as $$
  select case when p_email is null or position('@' in p_email) = 0 then null
              else left(split_part(p_email, '@', 1), 2) || '***@' || split_part(p_email, '@', 2) end $$;

create or replace function doc._ass_param(p_chave text, p_padrao int) returns int language sql stable security definer set search_path = '' as $$
  select coalesce((adm.valor(p_chave, to_jsonb(p_padrao)) #>> '{}')::int, p_padrao) $$;

-- código curto de verificação: 12 caracteres sem ambiguidade (sem 0, O, 1, I), em três grupos
create or replace function doc._ass_codigo_verificacao() returns text language plpgsql volatile security definer set search_path = '' as $$
declare alfa text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea; c text; i int;
begin
  loop
    b := extensions.gen_random_bytes(12); c := '';
    for i in 0..11 loop c := c || substr(alfa, (get_byte(b, i) % 32) + 1, 1); if i in (3, 7) then c := c || '-'; end if; end loop;
    exit when not exists (select 1 from doc.assinatura_pedido where codigo = c);
  end loop;
  return c;
end $$;

-- texto de consentimento: o signatário aceita este texto, com o hash do documento, ao assinar
create or replace function doc._ass_consentimento(p_hash text) returns text language sql immutable set search_path = '' as $$
  select 'Declaro que li o documento identificado pelo resumo SHA-256 ' || p_hash || ' e que o assino por meio eletrônico. '
      || 'Esta é uma assinatura eletrônica avançada nos termos do art. 4º, inciso II, da Lei nº 14.063/2020: fica associada a mim de maneira unívoca, '
      || 'pelo meu acesso autenticado e por um código de uso único enviado ao meu e-mail, que está sob o meu controle exclusivo, e fica relacionada '
      || 'ao documento de modo que qualquer modificação posterior seja detectável. Concordo com este meio de comprovação de autoria e de integridade, '
      || 'admitido entre as partes conforme o art. 10, § 2º, da Medida Provisória nº 2.200-2/2001. '
      || 'Esta assinatura não substitui a assinatura qualificada (ICP-Brasil) quando a lei ou o órgão público a exigir.' $$;

-- evidências da requisição (quando houver): IP e agente do navegador vindos dos cabeçalhos; método de login do token
create or replace function doc._ass_evidencia() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare h jsonb; c jsonb; v_ip text;
begin
  begin h := nullif(current_setting('request.headers', true), '')::jsonb; exception when others then h := null; end;
  begin c := nullif(current_setting('request.jwt.claims', true), '')::jsonb; exception when others then c := null; end;
  v_ip := coalesce(h->>'cf-connecting-ip', h->>'x-real-ip', nullif(btrim(split_part(coalesce(h->>'x-forwarded-for', ''), ',', 1)), ''));
  return jsonb_strip_nulls(jsonb_build_object('ip', left(v_ip, 64), 'agente', left(h->>'user-agent', 400),
    'login', case when jsonb_typeof(c->'amr') = 'array' then (select string_agg(distinct coalesce(x->>'method', x #>> '{}'), ', ') from jsonb_array_elements(c->'amr') x) end,
    'sessao', left(c->>'session_id', 64)));
end $$;

-- o prazo passou: vence (rotina e leitura)
create or replace function doc._ass_vencer(p_pedido bigint) returns boolean language plpgsql security definer set search_path = '' as $$
declare p doc.assinatura_pedido;
begin
  select * into p from doc.assinatura_pedido where id = p_pedido for update;
  if p.id is null or p.situacao not in ('rascunho', 'aguardando') or p.prazo >= now() then return false; end if;
  update doc.assinatura_pedido set situacao = 'vencido', encerrado_em = now(), encerrado_motivo = 'prazo vencido sem todas as assinaturas' where id = p.id;
  perform doc._ass_evento(p.id, 'vencido', null, jsonb_build_object('prazo', doc._ass_iso(p.prazo)));
  return true;
end $$;

-- aviso pelo Telegram ao usuário externo da vez (se ele ligou o Telegram); a pessoa de dentro vê na Central
create or replace function doc._ass_avisar_vez(p_pedido bigint) returns void language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario; p doc.assinatura_pedido;
begin
  select * into p from doc.assinatura_pedido where id = p_pedido;
  if p.situacao <> 'aguardando' then return; end if;
  select * into s from doc.assinatura_signatario where pedido = p_pedido and situacao = 'pendente' order by ordem limit 1;
  if s.usuario is null then return; end if;
  insert into rt.fila_envio (chat_ref, texto, simulado)
  select t.chat_ref, left('IMTS.OS: o documento "' || p.titulo || '" aguarda a sua assinatura no portal, até ' || to_char(p.prazo at time zone 'America/Fortaleza', 'DD/MM/YYYY') || '.', 3500), t.simulado
    from ext.telegram t where t.auth_uid = s.usuario and t.vinculado_em is not null and t.chat_ref is not null;
end $$;

-- pede o selo à Edge Function selo (vai pela fila do pg_net depois do commit); sem endereço configurado, a rotina tenta depois
create or replace function doc._ass_pedir_selo() returns bigint language plpgsql security definer set search_path = '' as $$
declare u text := rt._url_funcao('selo');
begin
  if u is null or rt._segredo('imts_funcao_chave') is null then return null; end if;
  return net.http_post(url := u, headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{"acao":"selar"}'::jsonb, timeout_milliseconds := 60000);
end $$;

-- ---------- pedir assinatura ----------
create or replace function doc._ass_enviar(p_pedido bigint, p_por uuid) returns void language plpgsql security definer set search_path = '' as $$
declare p doc.assinatura_pedido;
begin
  select * into p from doc.assinatura_pedido where id = p_pedido for update;
  if p.situacao <> 'rascunho' then raise exception 'só pedido em rascunho se envia (este está %)', p.situacao; end if;
  if p.prazo < now() then raise exception 'o prazo do pedido já passou: crie outro pedido'; end if;
  if doc._ass_hash_atual(p.emissao) is distinct from p.hash_documento then raise exception 'o documento mudou depois do pedido: crie outro pedido'; end if;
  update doc.assinatura_pedido set situacao = 'aguardando', enviado_em = now() where id = p.id;
  perform doc._ass_evento(p.id, 'enviado', null, jsonb_build_object('por', p_por));
  perform doc._ass_avisar_vez(p.id);
end $$;

create or replace function doc.assinatura_pedir(p_emissao bigint, p_signatarios jsonb, p_prazo timestamptz default null, p_titulo text default null,
  p_exige_icp boolean default false, p_enviar boolean default true) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu(); em doc.emissao; ped doc.pedido; v_hash text; v_bytes int; v_prazo timestamptz; v_titulo text; p doc.assinatura_pedido;
  s jsonb; k int := 0; v_pes uuid; v_usu uuid; v_nome text; v_email text; lista jsonb := '[]'; vistos text[] := '{}';
begin
  if v is null then raise exception 'só a equipe do IMTS pede assinatura'; end if;
  select * into em from doc.emissao where id = p_emissao;
  if em.id is null then raise exception 'documento emitido inexistente: %', p_emissao; end if;
  select * into ped from doc.pedido where id = em.pedido;
  if not rt.pode(v, ped.empresa, null, 'operar') then raise exception 'sem acesso de operar na empresa do documento'; end if;
  if em.situacao not in ('emitido', 'emitido_com_alertas') then raise exception 'só documento emitido pelo motor documental vai para assinatura (este ficou %)', em.situacao; end if;
  select encode(extensions.digest(conteudo, 'sha256'), 'hex'), length(conteudo) into v_hash, v_bytes from doc.arquivo where emissao = em.id and formato = 'pdf';
  if v_hash is null then raise exception 'o documento não tem PDF guardado'; end if;
  v_prazo := coalesce(p_prazo, now() + make_interval(days => doc._ass_param('assinatura.prazo_padrao_dias', 15)));
  if v_prazo < now() + interval '1 hour' then raise exception 'o prazo precisa ser de pelo menos uma hora a partir de agora'; end if;
  if v_prazo > now() + interval '180 days' then raise exception 'o prazo não pode passar de 180 dias'; end if;
  v_titulo := nullif(doc._nd_texto(coalesce(nullif(btrim(p_titulo), ''), ped.conteudo->>'titulo', 'Documento nº ' || em.id), 'título'), '');
  if v_titulo is null or length(v_titulo) > 300 then raise exception 'informe um título de até 300 caracteres'; end if;
  if jsonb_typeof(p_signatarios) is distinct from 'array' or jsonb_array_length(p_signatarios) = 0 then raise exception 'inclua ao menos um signatário'; end if;
  if jsonb_array_length(p_signatarios) > 20 then raise exception 'no máximo 20 signatários por pedido'; end if;
  -- confere todos antes de gravar
  for s in select * from jsonb_array_elements(p_signatarios) loop
    k := k + 1; v_pes := null; v_usu := null;
    begin v_pes := nullif(s->>'pessoa', '')::uuid; v_usu := nullif(s->>'usuario', '')::uuid; exception when others then raise exception 'signatário %: identificador inválido', k; end;
    if num_nonnulls(v_pes, v_usu) <> 1 then raise exception 'signatário %: informe a pessoa da equipe ou o usuário do portal', k; end if;
    if v_pes is not null then
      select i.nome, i.email into v_nome, v_email from rt.pessoa x join rt_chave.identidade i on i.pseudonimo = x.pseudonimo where x.pseudonimo = v_pes;
      if v_nome is null then raise exception 'signatário %: pessoa inexistente', k; end if;
      if not rt.pode(v_pes, ped.empresa, null, 'ler') then raise exception 'signatário %: % não tem acesso à empresa do documento', k, v_nome; end if;
    else
      select u.nome, a.email into v_nome, v_email from ext.usuario u join ext.contraparte c on c.id = u.contraparte left join auth.users a on a.id = u.auth_uid
       where u.auth_uid = v_usu and u.ativo and c.ativa and c.empresa = ped.empresa;
      if v_nome is null then raise exception 'signatário %: usuário do portal inexistente, inativo ou de outra empresa', k; end if;
    end if;
    if coalesce(v_email, '') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'signatário %: % não tem e-mail para receber o código', k, v_nome; end if;
    if coalesce(v_pes::text, v_usu::text) = any (vistos) then raise exception 'signatário %: % aparece duas vezes', k, v_nome; end if;
    vistos := vistos || coalesce(v_pes::text, v_usu::text);
    lista := lista || jsonb_build_object('ordem', k, 'tipo', case when v_pes is not null then 'interno' else 'externo' end, 'pessoa', v_pes, 'usuario', v_usu,
                                         'nome', v_nome, 'email', lower(v_email));
  end loop;
  insert into doc.assinatura_pedido (empresa, emissao, titulo, hash_documento, bytes_documento, codigo, exige_icp, prazo, pedido_por)
  values (ped.empresa, em.id, v_titulo, v_hash, v_bytes, doc._ass_codigo_verificacao(), coalesce(p_exige_icp, false), v_prazo, v)
  returning * into p;
  for s in select * from jsonb_array_elements(lista) loop
    insert into doc.assinatura_signatario (pedido, ordem, pessoa, usuario, nome, email)
    values (p.id, (s->>'ordem')::smallint, nullif(s->>'pessoa', '')::uuid, nullif(s->>'usuario', '')::uuid, s->>'nome', s->>'email');
  end loop;
  perform doc._ass_evento(p.id, 'pedido', null, jsonb_build_object('emissao', em.id, 'hash_documento', v_hash, 'bytes', v_bytes, 'titulo', v_titulo,
    'prazo', doc._ass_iso(v_prazo), 'exige_icp', p.exige_icp, 'por', v, 'codigo', p.codigo,
    'signatarios', (select jsonb_agg(x - 'pessoa' - 'usuario' order by (x->>'ordem')::int) from jsonb_array_elements(lista) x)));
  if coalesce(p_enviar, true) then perform doc._ass_enviar(p.id, v); end if;
  select * into p from doc.assinatura_pedido where id = p.id;
  return jsonb_build_object('id', p.id, 'codigo', p.codigo, 'situacao', p.situacao, 'hash_documento', p.hash_documento, 'prazo', p.prazo, 'exige_icp', p.exige_icp);
end $$;

create or replace function doc.assinatura_enviar(p_pedido bigint) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu(); p doc.assinatura_pedido;
begin
  select * into p from doc.assinatura_pedido where id = p_pedido;
  if v is null or p.id is null or not rt.pode(v, p.empresa, null, 'operar') then raise exception 'pedido de assinatura inexistente ou sem acesso'; end if;
  if p.pedido_por <> v then raise exception 'só quem pediu envia o pedido'; end if;
  perform doc._ass_enviar(p.id, v);
  return jsonb_build_object('id', p.id, 'situacao', 'aguardando');
end $$;

-- cancelar: só quem pediu, com motivo, enquanto ninguém encerrou
create or replace function doc.assinatura_cancelar(p_pedido bigint, p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu(); p doc.assinatura_pedido;
begin
  select * into p from doc.assinatura_pedido where id = p_pedido for update;
  if v is null or p.id is null or not doc._ass_le(p.id) then raise exception 'pedido de assinatura inexistente ou sem acesso'; end if;
  if p.pedido_por <> v then raise exception 'só quem pediu a assinatura cancela o pedido'; end if;
  if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'cancelar exige motivo'; end if;
  if p.situacao not in ('rascunho', 'aguardando') then raise exception 'pedido % não se cancela', p.situacao; end if;
  update doc.assinatura_pedido set situacao = 'cancelado', encerrado_em = now(), encerrado_motivo = btrim(p_motivo) where id = p.id;
  update doc.assinatura_codigo c set invalidado_em = now() from doc.assinatura_signatario s
   where s.id = c.signatario and s.pedido = p.id and c.usado_em is null and c.invalidado_em is null;
  perform doc._ass_evento(p.id, 'cancelado', null, jsonb_build_object('por', v, 'motivo', btrim(p_motivo)));
  return jsonb_build_object('id', p.id, 'situacao', 'cancelado');
end $$;

-- ---------- regras da vez do signatário (código e assinatura) ----------
-- devolve o signatário se ele pode agir agora; senão recusa com o motivo
create or replace function doc._ass_da_vez(p_signatario bigint, p_pessoa uuid, p_usuario uuid) returns doc.assinatura_signatario
language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario; p doc.assinatura_pedido;
begin
  select * into s from doc.assinatura_signatario where id = p_signatario;
  if s.id is null or not ((p_pessoa is not null and s.pessoa = p_pessoa) or (p_usuario is not null and s.usuario = p_usuario)) then
    raise exception 'esta assinatura não é sua'; end if;
  select * into p from doc.assinatura_pedido where id = s.pedido;
  if p.exige_icp then raise exception 'este pedido exige assinatura qualificada (ICP-Brasil): assine fora, no seu certificado, e quem pediu registra aqui'; end if;
  if p.situacao <> 'aguardando' or p.prazo < now() then
    raise exception 'o pedido não aceita assinatura (está %)', case when p.situacao = 'aguardando' then 'vencido' else p.situacao end; end if;
  if s.situacao <> 'pendente' then raise exception 'você já % neste pedido', case s.situacao when 'recusado' then 'recusou' else 'assinou' end; end if;
  if exists (select 1 from doc.assinatura_signatario x where x.pedido = s.pedido and x.ordem < s.ordem and x.situacao not in ('assinado', 'assinado_fora')) then
    raise exception 'ainda não é a sua vez: falta a assinatura de quem vem antes na ordem'; end if;
  return s;
end $$;

-- código do segundo fator: gerado aqui e devolvido só à Edge Function (chave de serviço), que o manda por e-mail
create or replace function doc.assinatura_codigo_emitir(p_signatario bigint) returns jsonb language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario; p doc.assinatura_pedido; v_cod text; v_sal text; v_val int := doc._ass_param('assinatura.codigo_validade_min', 10);
  v_ate timestamptz; ultimo timestamptz; n int;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select * into s from doc.assinatura_signatario where id = p_signatario;
  if s.id is null then raise exception 'signatário inexistente'; end if;
  perform pg_advisory_xact_lock(hashtextextended('assinatura_codigo:' || s.id, 0));
  s := doc._ass_da_vez(s.id, s.pessoa, s.usuario);
  select * into p from doc.assinatura_pedido where id = s.pedido;
  if doc._ass_hash_atual(p.emissao) is distinct from p.hash_documento then raise exception 'o documento mudou depois do pedido: a assinatura está bloqueada'; end if;
  select max(criado_em), count(*) filter (where criado_em > now() - interval '1 hour') into ultimo, n from doc.assinatura_codigo where signatario = s.id;
  if ultimo > now() - interval '60 seconds' then raise exception 'aguarde um minuto para pedir outro código'; end if;
  if n >= doc._ass_param('assinatura.codigos_por_hora', 5) then raise exception 'limite de códigos por hora atingido: tente mais tarde'; end if;
  update doc.assinatura_codigo set invalidado_em = now() where signatario = s.id and usado_em is null and invalidado_em is null;
  v_cod := lpad((('x' || encode(extensions.gen_random_bytes(6), 'hex'))::bit(48)::bigint % 1000000)::text, 6, '0');
  v_sal := encode(extensions.gen_random_bytes(16), 'hex');
  v_ate := now() + make_interval(mins => v_val);
  insert into doc.assinatura_codigo (signatario, hash, sal, valido_ate) values (s.id, doc._ass_sha256(v_sal || ':' || s.id || ':' || v_cod), v_sal, v_ate);
  perform doc._ass_evento(p.id, 'codigo_enviado', s.id, jsonb_build_object('para', doc._ass_mascarar(s.email), 'valido_ate', doc._ass_iso(v_ate)));
  return jsonb_build_object('codigo', v_cod, 'email', s.email, 'nome', s.nome, 'titulo', p.titulo, 'validade_min', v_val, 'pedido', p.id,
                            'para', doc._ass_mascarar(s.email), 'tentativas', doc._ass_param('assinatura.codigo_tentativas', 5));
end $$;

-- o e-mail não saiu: o código não vale
create or replace function doc.assinatura_codigo_descartar(p_signatario bigint, p_motivo text) returns void language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select * into s from doc.assinatura_signatario where id = p_signatario;
  if s.id is null then return; end if;
  update doc.assinatura_codigo set invalidado_em = now() where signatario = s.id and usado_em is null and invalidado_em is null;
  perform doc._ass_evento(s.pedido, 'codigo_nao_enviado', s.id, jsonb_build_object('motivo', left(coalesce(p_motivo, 'falha no envio'), 300)));
end $$;

-- ---------- assinar ----------
-- código errado conta tentativa e NÃO desfaz (devolve em vez de recusar), para a contagem ficar gravada
create or replace function doc._ass_assinar(p_signatario bigint, p_codigo text, p_aceito boolean, p_pessoa uuid, p_usuario uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario; p doc.assinatura_pedido; c doc.assinatura_codigo; v_max int := doc._ass_param('assinatura.codigo_tentativas', 5);
  v_ev jsonb; v_tipo text; v_metodo text; v_hash_ev text; v_todos boolean;
begin
  select * into s from doc.assinatura_signatario where id = p_signatario;
  if s.id is not null then perform 1 from doc.assinatura_pedido where id = s.pedido for update; end if;
  s := doc._ass_da_vez(p_signatario, p_pessoa, p_usuario);
  select * into p from doc.assinatura_pedido where id = s.pedido;
  if p_aceito is not true then raise exception 'para assinar, leia e aceite o texto de consentimento'; end if;
  if doc._ass_hash_atual(p.emissao) is distinct from p.hash_documento then
    raise exception 'o documento mudou depois do pedido (o SHA-256 não confere): a assinatura está bloqueada'; end if;
  select * into c from doc.assinatura_codigo where signatario = s.id and usado_em is null and invalidado_em is null order by id desc limit 1 for update;
  if c.id is null then raise exception 'peça o código por e-mail antes de assinar'; end if;
  if c.valido_ate < now() then raise exception 'código vencido: peça outro'; end if;
  if coalesce(p_codigo, '') !~ '^[0-9]{6}$' or doc._ass_sha256(c.sal || ':' || s.id || ':' || p_codigo) <> c.hash then
    update doc.assinatura_codigo set tentativas = tentativas + 1, invalidado_em = case when tentativas + 1 >= v_max then now() end where id = c.id returning * into c;
    if c.invalidado_em is not null then
      perform doc._ass_evento(p.id, 'codigo_bloqueado', s.id, jsonb_build_object('tentativas', c.tentativas) || doc._ass_evidencia());
      return jsonb_build_object('assinado', false, 'motivo', 'código errado: o código foi bloqueado depois de ' || c.tentativas || ' tentativas; peça outro', 'restantes', 0, 'bloqueado', true);
    end if;
    perform doc._ass_evento(p.id, 'codigo_errado', s.id, jsonb_build_object('tentativas', c.tentativas) || doc._ass_evidencia());
    return jsonb_build_object('assinado', false, 'motivo', 'código errado', 'restantes', v_max - c.tentativas, 'bloqueado', false);
  end if;
  -- código certo: assina com as evidências
  update doc.assinatura_codigo set usado_em = now() where id = c.id;
  v_tipo := case when s.pessoa is not null then 'interno' else 'externo' end;
  v_metodo := case v_tipo when 'interno' then 'login Google do Workspace' else 'link de acesso enviado por e-mail' end || ' e código de 6 dígitos enviado por e-mail';
  v_ev := jsonb_build_object('nome', s.nome, 'email', s.email, 'tipo', v_tipo, 'pessoa', s.pessoa, 'usuario', s.usuario, 'autenticacao', v_metodo,
            'hash_documento', p.hash_documento, 'consentimento', doc._ass_consentimento(p.hash_documento),
            'consentimento_sha256', doc._ass_sha256(doc._ass_consentimento(p.hash_documento)), 'codigo_emitido_em', doc._ass_iso(c.criado_em),
            'assinado_em', doc._ass_iso(now())) || doc._ass_evidencia();
  v_hash_ev := doc._ass_evento(p.id, 'assinado', s.id, jsonb_strip_nulls(v_ev));
  update doc.assinatura_signatario set situacao = 'assinado', assinado_em = now(), evidencia = jsonb_strip_nulls(v_ev) || jsonb_build_object('hash_evento', v_hash_ev) where id = s.id;
  v_todos := not exists (select 1 from doc.assinatura_signatario where pedido = p.id and situacao not in ('assinado', 'assinado_fora'));
  if v_todos then
    update doc.assinatura_pedido set situacao = 'concluido', concluido_em = now() where id = p.id;
    perform doc._ass_evento(p.id, 'concluido', null, jsonb_build_object('hash_documento', p.hash_documento, 'assinaturas', (select count(*) from doc.assinatura_signatario where pedido = p.id)));
    perform doc._ass_pedir_selo();
  else
    perform doc._ass_avisar_vez(p.id);
  end if;
  return jsonb_build_object('assinado', true, 'concluido', v_todos, 'pedido', p.id, 'codigo_verificacao', p.codigo, 'hash_evento', v_hash_ev);
end $$;

create or replace function doc.assinatura_assinar(p_signatario bigint, p_codigo text, p_aceito boolean) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then raise exception 'só a equipe do IMTS assina por aqui; cliente e parceiro assinam no portal'; end if;
  return doc._ass_assinar(p_signatario, p_codigo, p_aceito, v, null);
end $$;
create or replace function ext.assinatura_assinar(p_signatario bigint, p_codigo text, p_aceito boolean) returns jsonb language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  return doc._ass_assinar(p_signatario, p_codigo, p_aceito, null, u.auth_uid);
end $$;

-- recusa com motivo: encerra o pedido (vale em qualquer ponto da ordem)
create or replace function doc._ass_recusar(p_signatario bigint, p_motivo text, p_pessoa uuid, p_usuario uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario; p doc.assinatura_pedido;
begin
  select * into s from doc.assinatura_signatario where id = p_signatario;
  if s.id is null or not ((p_pessoa is not null and s.pessoa = p_pessoa) or (p_usuario is not null and s.usuario = p_usuario)) then raise exception 'esta assinatura não é sua'; end if;
  select * into p from doc.assinatura_pedido where id = s.pedido for update;
  if p.situacao <> 'aguardando' or p.prazo < now() then raise exception 'o pedido não está aguardando assinaturas'; end if;
  if s.situacao <> 'pendente' then raise exception 'você já respondeu a este pedido'; end if;
  if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'recusar exige motivo'; end if;
  update doc.assinatura_signatario set situacao = 'recusado', recusado_motivo = left(btrim(p_motivo), 1000) where id = s.id;
  update doc.assinatura_pedido set situacao = 'recusado', encerrado_em = now(), encerrado_motivo = 'recusado por ' || s.nome || ': ' || left(btrim(p_motivo), 900) where id = p.id;
  update doc.assinatura_codigo c set invalidado_em = now() from doc.assinatura_signatario x
   where x.id = c.signatario and x.pedido = p.id and c.usado_em is null and c.invalidado_em is null;
  perform doc._ass_evento(p.id, 'recusado', s.id, jsonb_build_object('nome', s.nome, 'motivo', left(btrim(p_motivo), 1000)) || doc._ass_evidencia());
  return jsonb_build_object('id', p.id, 'situacao', 'recusado');
end $$;
create or replace function doc.assinatura_recusar(p_signatario bigint, p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then raise exception 'só a equipe do IMTS responde por aqui'; end if;
  return doc._ass_recusar(p_signatario, p_motivo, v, null);
end $$;
create or replace function ext.assinatura_recusar(p_signatario bigint, p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  return doc._ass_recusar(p_signatario, p_motivo, null, u.auth_uid);
end $$;

-- exige ICP-Brasil: a assinatura qualificada é feita fora; aqui só fica registrado, por quem pediu ou por quem opera na empresa
create or replace function doc.assinatura_registrar_fora(p_signatario bigint, p_referencia text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu(); s doc.assinatura_signatario; p doc.assinatura_pedido; v_todos boolean;
begin
  select * into s from doc.assinatura_signatario where id = p_signatario;
  select * into p from doc.assinatura_pedido where id = s.pedido for update;
  if v is null or p.id is null or not (p.pedido_por = v or rt.pode(v, p.empresa, null, 'operar')) then raise exception 'pedido de assinatura inexistente ou sem acesso'; end if;
  if not p.exige_icp then raise exception 'só pedido que exige ICP-Brasil registra assinatura feita fora'; end if;
  if p.situacao <> 'aguardando' or p.prazo < now() then raise exception 'o pedido não está aguardando assinaturas'; end if;
  if s.situacao <> 'pendente' then raise exception 'este signatário já respondeu'; end if;
  if coalesce(length(btrim(p_referencia)), 0) < 5 then raise exception 'informe a referência da assinatura qualificada (arquivo assinado, data, assinador)'; end if;
  update doc.assinatura_signatario set situacao = 'assinado_fora', fora_referencia = left(btrim(p_referencia), 500), assinado_em = now() where id = s.id;
  perform doc._ass_evento(p.id, 'assinado_fora', s.id, jsonb_build_object('nome', s.nome, 'referencia', left(btrim(p_referencia), 500), 'registrado_por', v));
  v_todos := not exists (select 1 from doc.assinatura_signatario where pedido = p.id and situacao not in ('assinado', 'assinado_fora'));
  if v_todos then
    update doc.assinatura_pedido set situacao = 'concluido', concluido_em = now() where id = p.id;
    perform doc._ass_evento(p.id, 'concluido', null, jsonb_build_object('hash_documento', p.hash_documento, 'icp_externo', true));
  end if;
  return jsonb_build_object('id', p.id, 'situacao', case when v_todos then 'concluido' else 'aguardando' end);
end $$;

-- ---------- manifesto e selo ----------
create or replace function doc._ass_manifesto(p_pedido bigint) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p doc.assinatura_pedido; v_seq int; t jsonb; url text := coalesce(nullif(adm.valor('assinatura.url_verificacao', '""') #>> '{}', ''), 'https://www.imts.global/verificar.html');
begin
  select * into p from doc.assinatura_pedido where id = p_pedido;
  if p.situacao <> 'concluido' then return null; end if;
  select seq into v_seq from doc.assinatura_evento where pedido = p.id and tipo = 'concluido' order by seq limit 1;
  t := doc._ass_trilha(p.id, v_seq);
  return jsonb_build_object(
    'versao', 1, 'emissor', 'IMTS.OS',
    'modalidade', 'assinatura eletrônica avançada (Lei 14.063/2020, art. 4º, II)',
    'aceite_entre_as_partes', 'MP 2.200-2/2001, art. 10, § 2º',
    'codigo', p.codigo, 'verificar', url || '?c=' || p.codigo,
    'pedido', p.id, 'titulo', p.titulo, 'empresa', (select nome from org.empresa where id = p.empresa),
    'documento', jsonb_build_object('emissao', p.emissao, 'sha256', p.hash_documento, 'bytes', p.bytes_documento, 'paginas', (select paginas from doc.emissao where id = p.emissao)),
    'pedido_em', doc._ass_iso(p.criado_em), 'concluido_em', doc._ass_iso(p.concluido_em),
    'signatarios', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('ordem', s.ordem, 'nome', s.nome, 'email', doc._ass_mascarar(s.email),
         'tipo', case when s.pessoa is not null then 'interno' else 'externo' end, 'autenticacao', s.evidencia->>'autenticacao',
         'assinado_em', doc._ass_iso(s.assinado_em), 'ip', s.evidencia->>'ip', 'agente', left(s.evidencia->>'agente', 120),
         'evento', (select e.seq from doc.assinatura_evento e where e.pedido = p.id and e.signatario = s.id and e.tipo = 'assinado' limit 1),
         'hash_evento', s.evidencia->>'hash_evento')) order by s.ordem), '[]') from doc.assinatura_signatario s where s.pedido = p.id),
    'trilha', jsonb_build_object('eventos', t->'eventos', 'hash_final', t->'hash_final', 'integra', t->'ok'));
end $$;

-- pedidos concluídos à espera do selo (só para a Edge Function): manifesto canônico em texto e o PDF original
create or replace function doc.assinatura_para_selar(p_pedido bigint default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('pedido', p.id, 'codigo', p.codigo, 'manifesto', doc._ass_manifesto(p.id)::text,
            'pdf', (select encode(a.conteudo, 'base64') from doc.arquivo a where a.emissao = p.emissao and a.formato = 'pdf')) order by p.id), '[]')
    from (select * from doc.assinatura_pedido p where p.situacao = 'concluido' and not p.exige_icp and (p_pedido is null or p.id = p_pedido)
            and not exists (select 1 from doc.assinatura_selo x where x.pedido = p.id) order by p.id limit 5) p);
end $$;

create or replace function doc.assinatura_chave_ativa() returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  return (select jsonb_build_object('kid', kid, 'publica', publica) from doc.assinatura_chave where ativa);
end $$;

-- a função do servidor gera o par de chaves na primeira vez: a privada vai direto para o cofre, a pública para a tabela de leitura
create or replace function doc.assinatura_chave_gravar(p_kid text, p_publica jsonb, p_privada text) returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  perform pg_advisory_xact_lock(hashtextextended('assinatura_chave', 0));
  if exists (select 1 from doc.assinatura_chave where ativa) or rt._segredo('assinatura_chave_privada') is not null then return false; end if;
  if coalesce(p_kid, '') !~ '^[A-Za-z0-9_-]{20,}$' or p_publica->>'kty' <> 'EC' or p_publica->>'crv' <> 'P-256' or p_publica ? 'd' then raise exception 'chave pública inválida'; end if;
  if coalesce(p_privada, '') not like '%"d"%' then raise exception 'chave privada inválida'; end if;
  perform vault.create_secret(p_privada, 'assinatura_chave_privada', 'chave privada do selo de assinatura do IMTS (ECDSA P-256, JWK); gerada pela função do servidor no primeiro selo');
  insert into doc.assinatura_chave (kid, publica) values (p_kid, p_publica - 'd' - 'key_ops' - 'ext');
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('conexao', 'segredo:assinatura_chave_privada', null, jsonb_build_object('kid', p_kid), null, 'serviço', 'chave do selo de assinatura gerada pela função do servidor no primeiro selo');
  return true;
end $$;

create or replace function doc.assinatura_selar(p_pedido bigint, p_manifesto text, p_assinatura text, p_kid text, p_pdf text, p_formato text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p doc.assinatura_pedido; b bytea; h text;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select * into p from doc.assinatura_pedido where id = p_pedido for update;
  if p.id is null or p.situacao <> 'concluido' or p.exige_icp then raise exception 'pedido sem selo a receber'; end if;
  if exists (select 1 from doc.assinatura_selo where pedido = p.id) then raise exception 'pedido já selado'; end if;
  if p_manifesto is distinct from doc._ass_manifesto(p.id)::text then raise exception 'manifesto diferente do registrado'; end if;
  if not exists (select 1 from doc.assinatura_chave where kid = p_kid and ativa) then raise exception 'chave do selo desconhecida'; end if;
  if coalesce(p_assinatura, '') !~ '^[A-Za-z0-9_-]{80,}$' then raise exception 'assinatura do selo inválida'; end if;
  b := decode(p_pdf, 'base64');
  if b is null or length(b) < 5 or substring(b from 1 for 5) <> '\x255044462d'::bytea then raise exception 'o arquivo final não é PDF'; end if;
  h := encode(extensions.digest(b, 'sha256'), 'hex');
  insert into doc.assinatura_selo (pedido, manifesto, hash_manifesto, assinatura, kid, pdf, hash_pdf, bytes, formato)
  values (p.id, p_manifesto, doc._ass_sha256(p_manifesto), p_assinatura, p_kid, b, h, length(b), p_formato);
  perform doc._ass_evento(p.id, 'selado', null, jsonb_build_object('kid', p_kid, 'hash_manifesto', doc._ass_sha256(p_manifesto), 'hash_pdf_final', h, 'formato', p_formato));
  return jsonb_build_object('pedido', p.id, 'hash_pdf', h, 'codigo', p.codigo);
end $$;

-- ---------- verificação pública (só pela Edge Function verificar; nada pessoal além de nome e e-mail mascarado) ----------
create or replace function doc.assinatura_verificacao(p_codigo text, p_hash text default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_cod text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g')); p doc.assinatura_pedido; sl doc.assinatura_selo; t jsonb; tc jsonb; v_seq int;
  v_hash text := lower(nullif(btrim(coalesce(p_hash, '')), ''));
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  if length(v_cod) <> 12 then return jsonb_build_object('encontrado', false); end if;
  v_cod := substr(v_cod, 1, 4) || '-' || substr(v_cod, 5, 4) || '-' || substr(v_cod, 9, 4);
  select * into p from doc.assinatura_pedido where codigo = v_cod;
  if p.id is null then return jsonb_build_object('encontrado', false); end if;
  if v_hash is not null and v_hash !~ '^[0-9a-f]{64}$' then v_hash := null; end if;
  select * into sl from doc.assinatura_selo where pedido = p.id;
  select seq into v_seq from doc.assinatura_evento where pedido = p.id and tipo = 'concluido' order by seq limit 1;
  t := doc._ass_trilha(p.id); tc := case when v_seq is not null then doc._ass_trilha(p.id, v_seq) end;
  return jsonb_build_object('encontrado', true, 'codigo', p.codigo, 'titulo', p.titulo, 'empresa', (select nome from org.empresa where id = p.empresa),
    'situacao', case when p.situacao = 'aguardando' and p.prazo < now() then 'vencido' else p.situacao end,
    'exige_icp', p.exige_icp, 'pedido_em', p.criado_em, 'concluido_em', p.concluido_em, 'prazo', p.prazo,
    'hash_documento', p.hash_documento, 'hash_documento_atual_confere', doc._ass_hash_atual(p.emissao) is not distinct from p.hash_documento,
    'hash_pdf_assinado', sl.hash_pdf, 'formato', sl.formato, 'selado_em', sl.selado_em,
    'confere_arquivo', case when v_hash is null then null when v_hash = p.hash_documento then 'original' when v_hash = sl.hash_pdf then 'assinado' else 'diferente' end,
    'signatarios', (select coalesce(jsonb_agg(jsonb_build_object('ordem', s.ordem, 'nome', s.nome, 'email', doc._ass_mascarar(s.email), 'situacao', s.situacao,
        'tipo', case when s.pessoa is not null then 'interno' else 'externo' end, 'assinado_em', s.assinado_em, 'autenticacao', s.evidencia->>'autenticacao') order by s.ordem), '[]')
        from doc.assinatura_signatario s where s.pedido = p.id),
    'trilha', jsonb_build_object('integra', (t->>'ok')::boolean, 'eventos', t->'eventos', 'hash_final', t->'hash_final',
                                 'hash_conclusao', tc->'hash_final', 'eventos_conclusao', tc->'eventos'),
    'manifesto', sl.manifesto, 'assinatura', sl.assinatura, 'kid', sl.kid, 'algoritmo', 'ECDSA P-256 com SHA-256',
    'chave_publica', (select publica from doc.assinatura_chave where kid = sl.kid),
    'manifesto_confere', case when sl.pedido is null then null else sl.manifesto = doc._ass_manifesto(p.id)::text end);
end $$;

-- ---------- rotina: vence pedidos e pede os selos que faltam ----------
create or replace function doc.assinatura_rotina() returns jsonb language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0; pend int;
begin
  for r in select id from doc.assinatura_pedido where situacao in ('rascunho', 'aguardando') and prazo < now() loop
    if doc._ass_vencer(r.id) then n := n + 1; end if;
  end loop;
  select count(*) into pend from doc.assinatura_pedido p where p.situacao = 'concluido' and not p.exige_icp and not exists (select 1 from doc.assinatura_selo s where s.pedido = p.id);
  if pend > 0 then perform doc._ass_pedir_selo(); end if;
  return jsonb_build_object('vencidos', n, 'sem_selo', pend);
end $$;
do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('imts-assinatura', '*/15 * * * *', 'select doc.assinatura_rotina()');
  end if;
end $$;

-- ---------- autorização das funções do servidor (chamada por adm.servidor_autorizar) ----------
create or replace function doc._assinatura_autorizar(p_acao text, p_dados jsonb, p_pessoa uuid, p_usuario uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario; v_ped bigint;
begin
  if p_acao = 'codigo' then
    s := doc._ass_da_vez(nullif(p_dados->>'signatario', '')::bigint, p_pessoa, p_usuario);
    return jsonb_build_object('pessoa', p_pessoa, 'usuario', p_usuario, 'signatario', s.id, 'pedido', s.pedido,
                              'usuario_sistema', nullif(adm.valor('google.usuario_sistema', '""') #>> '{}', ''));
  elsif p_acao = 'selar' then
    v_ped := nullif(p_dados->>'pedido', '')::bigint;
    if v_ped is null or not exists (select 1 from doc.assinatura_pedido p where p.id = v_ped
         and ((p_pessoa is not null and rt.pode(p_pessoa, p.empresa, null, 'ler'))
              or exists (select 1 from doc.assinatura_signatario x where x.pedido = p.id and (x.pessoa = p_pessoa or x.usuario = p_usuario)))) then
      raise exception 'pedido de assinatura inexistente ou sem acesso'; end if;
    return jsonb_build_object('pessoa', p_pessoa, 'usuario', p_usuario, 'pedido', v_ped);
  end if;
  raise exception 'ação de assinatura desconhecida: %', p_acao;
end $$;

do $$
declare d text := pg_get_functiondef('adm.servidor_autorizar(text, text, jsonb)'::regprocedure); a text;
begin
  if position('doc._assinatura_autorizar' in d) > 0 then return; end if;   -- já aplicada
  a := d;
  d := replace(d, $q$  end if;
  raise exception 'função do servidor desconhecida: %', p_funcao;$q$, $q$  elsif p_funcao = 'assinatura' then
    return doc._assinatura_autorizar(p_acao, p_dados, v, u.auth_uid);
  end if;
  raise exception 'função do servidor desconhecida: %', p_funcao;$q$);
  if d = a then raise exception 'servidor_autorizar não tem o texto esperado: revisar a 076'; end if;
  execute d;
end $$;

-- ---------- leitura para as telas ----------
create or replace function doc._ass_json(p doc.assinatura_pedido, p_pessoa uuid, p_usuario uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'codigo', p.codigo, 'titulo', p.titulo, 'emissao', p.emissao, 'hash_documento', p.hash_documento,
    'empresa', (select nome from org.empresa where id = p.empresa),
    'situacao', case when p.situacao in ('rascunho', 'aguardando') and p.prazo < now() then 'vencido' else p.situacao end,
    'exige_icp', p.exige_icp, 'prazo', p.prazo, 'criado_em', p.criado_em, 'enviado_em', p.enviado_em, 'concluido_em', p.concluido_em,
    'encerrado_em', p.encerrado_em, 'encerrado_motivo', p.encerrado_motivo,
    'pedido_por', p.pedido_por, 'pedido_por_nome', (select nome from rt_chave.identidade where pseudonimo = p.pedido_por),
    'documento_alterado', doc._ass_hash_atual(p.emissao) is distinct from p.hash_documento,
    'selado', exists (select 1 from doc.assinatura_selo x where x.pedido = p.id),
    'selado_em', (select selado_em from doc.assinatura_selo x where x.pedido = p.id),
    'consentimento', doc._ass_consentimento(p.hash_documento),
    'signatarios', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'ordem', s.ordem, 'nome', s.nome, 'email', doc._ass_mascarar(s.email),
        'tipo', case when s.pessoa is not null then 'interno' else 'externo' end, 'situacao', s.situacao, 'assinado_em', s.assinado_em,
        'recusado_motivo', s.recusado_motivo, 'fora_referencia', s.fora_referencia,
        'sou_eu', (p_pessoa is not null and s.pessoa = p_pessoa) or (p_usuario is not null and s.usuario = p_usuario),
        'vez', p.situacao = 'aguardando' and p.prazo >= now() and s.situacao = 'pendente'
               and not exists (select 1 from doc.assinatura_signatario y where y.pedido = p.id and y.ordem < s.ordem and y.situacao not in ('assinado', 'assinado_fora')))
        order by s.ordem), '[]') from doc.assinatura_signatario s where s.pedido = p.id)) $$;

create or replace function doc.painel_assinaturas(p_empresa uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then raise exception 'só a equipe do IMTS'; end if;
  if p_empresa is null or not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso a esta empresa'; end if;
  return jsonb_build_object(
    'eu', v, 'pode', jsonb_build_object('operar', rt.pode(v, p_empresa, null, 'operar')),
    'validade_min', doc._ass_param('assinatura.codigo_validade_min', 10), 'prazo_padrao_dias', doc._ass_param('assinatura.prazo_padrao_dias', 15),
    'url_verificacao', coalesce(nullif(adm.valor('assinatura.url_verificacao', '""') #>> '{}', ''), 'https://www.imts.global/verificar.html'),
    'pedidos', (select coalesce(jsonb_agg(doc._ass_json(p, v, null) order by p.id desc), '[]') from doc.assinatura_pedido p where p.empresa = p_empresa),
    -- o que está comigo, em qualquer empresa
    'comigo', (select coalesce(jsonb_agg(doc._ass_json(p, v, null) order by p.prazo), '[]') from doc.assinatura_pedido p
                where p.situacao = 'aguardando' and p.prazo >= now() and exists (select 1 from doc.assinatura_signatario s where s.pedido = p.id and s.pessoa = v and s.situacao = 'pendente')),
    'documentos', (select coalesce(jsonb_agg(jsonb_build_object('emissao', x.id, 'titulo', x.titulo, 'tipo', x.tipo, 'emitido_em', x.emitido_em, 'paginas', x.paginas) order by x.id desc), '[]')
                     from (select e.id, coalesce(pd.conteudo->>'titulo', pd.tipo) titulo, pd.tipo, e.emitido_em, e.paginas from doc.emissao e join doc.pedido pd on pd.id = e.pedido
                            where pd.empresa = p_empresa and e.situacao in ('emitido', 'emitido_com_alertas')
                              and exists (select 1 from doc.arquivo a where a.emissao = e.id and a.formato = 'pdf') order by e.id desc limit 100) x),
    'internos', (select coalesce(jsonb_agg(jsonb_build_object('pessoa', x.pseudonimo, 'nome', i.nome, 'papel', x.papel) order by i.nome), '[]')
                   from rt.pessoa x join rt_chave.identidade i on i.pseudonimo = x.pseudonimo
                  where i.email is not null and rt.pode(x.pseudonimo, p_empresa, null, 'ler') and (not x.simulado or not exists (select 1 from rt.pessoa y where not y.simulado))),
    'externos', (select coalesce(jsonb_agg(jsonb_build_object('usuario', u.auth_uid, 'nome', u.nome, 'perfil', u.perfil, 'contraparte', c.nome) order by c.nome, u.nome), '[]')
                   from ext.usuario u join ext.contraparte c on c.id = u.contraparte join auth.users a on a.id = u.auth_uid
                  where c.empresa = p_empresa and c.ativa and u.ativo and a.email is not null));
end $$;

-- PDF para quem lê o pedido: o assinado (com o manifesto) quando houver, senão o original
create or replace function doc._ass_pdf(p_pedido bigint) returns jsonb language sql stable security definer set search_path = '' as $$
  select case when s.pedido is not null then jsonb_build_object('pdf', encode(s.pdf, 'base64'), 'assinado', true, 'sha256', s.hash_pdf)
              else jsonb_build_object('pdf', (select encode(a.conteudo, 'base64') from doc.arquivo a where a.emissao = p.emissao and a.formato = 'pdf'), 'assinado', false, 'sha256', p.hash_documento) end
    from doc.assinatura_pedido p left join doc.assinatura_selo s on s.pedido = p.id where p.id = p_pedido $$;

create or replace function doc.assinatura_documento(p_pedido bigint) returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if rt.eu() is null or not doc._ass_le(p_pedido) then raise exception 'pedido de assinatura inexistente ou sem acesso'; end if;
  return doc._ass_pdf(p_pedido);
end $$;

create or replace function ext.portal_assinaturas() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  return jsonb_build_object('validade_min', doc._ass_param('assinatura.codigo_validade_min', 10),
    'url_verificacao', coalesce(nullif(adm.valor('assinatura.url_verificacao', '""') #>> '{}', ''), 'https://www.imts.global/verificar.html'),
    'pedidos', (select coalesce(jsonb_agg(doc._ass_json(p, null, u.auth_uid) - 'pedido_por' - 'emissao' order by (p.situacao = 'aguardando') desc, p.id desc), '[]')
                  from doc.assinatura_pedido p where p.situacao <> 'rascunho' and exists (select 1 from doc.assinatura_signatario s where s.pedido = p.id and s.usuario = u.auth_uid)));
end $$;

create or replace function ext.assinatura_documento(p_pedido bigint) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  if not exists (select 1 from doc.assinatura_signatario s join doc.assinatura_pedido p on p.id = s.pedido
                  where s.pedido = p_pedido and s.usuario = u.auth_uid and p.situacao <> 'rascunho') then
    raise exception 'documento não está com você para assinar'; end if;
  return doc._ass_pdf(p_pedido);
end $$;

-- ---------- catálogo: as duas funções do servidor novas ----------
insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('edge-assinatura', 'Função do servidor assinatura (código por e-mail e selo pedido por quem assina)', 'assinatura', 'produção', null, 'Governança', 'pendente',
  '{google_conta_servico}', 'manual', null, 'publicar a função com verificação de JWT LIGADA (só quem tem login chama)', '076'),
 ('edge-selo', 'Função do servidor selo (selo ECDSA do IMTS nos pedidos concluídos, chamada pelo banco e pela rotina)', 'assinatura', 'produção', null, 'Governança', 'pendente',
  '{imts_funcao_chave}', 'manual', null,
  'publicar a função com verificação de JWT desligada (só aceita a chave X-IMTS-Chave); a chave do selo nasce no cofre no primeiro selo', '076'),
 ('edge-verificar', 'Função do servidor verificar (verificação pública da assinatura, sem login)', 'assinatura', 'produção', null, 'Governança', 'pendente', '{}', 'manual', null,
  'publicar a função com verificação de JWT desligada e publicar verificar.html em www.imts.global', '076')
on conflict (codigo) do update set nome = excluded.nome, segredos = excluded.segredos, pendencia = excluded.pendencia where adm.conexao.estado = 'pendente';

-- ---------- porta única ----------
insert into adm.api_funcao (nome, quem, descricao) values
 ('doc.painel_assinaturas', 'interno', 'Central: assinaturas'),
 ('doc.assinatura_pedir', 'interno', 'pedir assinatura eletrônica avançada de um documento emitido'),
 ('doc.assinatura_enviar', 'interno', 'enviar pedido de assinatura em rascunho'),
 ('doc.assinatura_cancelar', 'interno', 'cancelar pedido de assinatura (só quem pediu)'),
 ('doc.assinatura_assinar', 'interno', 'assinar com o código enviado por e-mail'),
 ('doc.assinatura_recusar', 'interno', 'recusar assinatura com motivo'),
 ('doc.assinatura_registrar_fora', 'interno', 'registrar assinatura qualificada (ICP-Brasil) feita fora'),
 ('doc.assinatura_documento', 'interno', 'baixar o PDF do pedido de assinatura'),
 ('ext.portal_assinaturas', 'externo', 'assinaturas'),
 ('ext.assinatura_assinar', 'externo', 'assinar com o código enviado por e-mail'),
 ('ext.assinatura_recusar', 'externo', 'recusar assinatura com motivo'),
 ('ext.assinatura_documento', 'externo', 'baixar o PDF para assinar')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;

-- ---------- permissões: anon nunca; authenticated só a porta única; o resto só a chave de serviço ----------
revoke all on function doc._ass_le(bigint), doc._ass_iso(timestamptz), doc._ass_sha256(text), doc._ass_canonico(bigint, int, text, bigint, timestamptz, jsonb),
  doc._ass_hash_evento(text, bigint, int, text, bigint, timestamptz, jsonb), doc._ass_evento_encadear(), doc._ass_imutavel(), doc._ass_pedido_guarda(),
  doc._ass_signatario_guarda(), doc._ass_evento(bigint, text, bigint, jsonb), doc._ass_trilha(bigint, int), doc._ass_hash_atual(bigint), doc._ass_mascarar(text),
  doc._ass_param(text, int), doc._ass_codigo_verificacao(), doc._ass_consentimento(text), doc._ass_evidencia(), doc._ass_vencer(bigint), doc._ass_avisar_vez(bigint),
  doc._ass_pedir_selo(), doc._ass_enviar(bigint, uuid), doc._ass_da_vez(bigint, uuid, uuid), doc._ass_assinar(bigint, text, boolean, uuid, uuid),
  doc._ass_recusar(bigint, text, uuid, uuid), doc._ass_manifesto(bigint), doc._assinatura_autorizar(text, jsonb, uuid, uuid),
  doc._ass_json(doc.assinatura_pedido, uuid, uuid), doc._ass_pdf(bigint),
  doc.assinatura_codigo_emitir(bigint), doc.assinatura_codigo_descartar(bigint, text), doc.assinatura_para_selar(bigint), doc.assinatura_chave_ativa(),
  doc.assinatura_chave_gravar(text, jsonb, text), doc.assinatura_selar(bigint, text, text, text, text, text), doc.assinatura_verificacao(text, text), doc.assinatura_rotina()
  from public, anon, authenticated;
-- a política de linha chama doc._ass_le com o papel de quem lê
grant execute on function doc._ass_le(bigint) to authenticated, service_role;
grant execute on function doc.assinatura_codigo_emitir(bigint), doc.assinatura_codigo_descartar(bigint, text), doc.assinatura_para_selar(bigint), doc.assinatura_chave_ativa(),
  doc.assinatura_chave_gravar(text, jsonb, text), doc.assinatura_selar(bigint, text, text, text, text, text), doc.assinatura_verificacao(text, text), doc.assinatura_rotina()
  to service_role;
revoke all on function doc.painel_assinaturas(uuid), doc.assinatura_pedir(bigint, jsonb, timestamptz, text, boolean, boolean), doc.assinatura_enviar(bigint),
  doc.assinatura_cancelar(bigint, text), doc.assinatura_assinar(bigint, text, boolean), doc.assinatura_recusar(bigint, text), doc.assinatura_registrar_fora(bigint, text),
  doc.assinatura_documento(bigint), ext.portal_assinaturas(), ext.assinatura_assinar(bigint, text, boolean), ext.assinatura_recusar(bigint, text), ext.assinatura_documento(bigint)
  from public, anon;
grant execute on function doc.painel_assinaturas(uuid), doc.assinatura_pedir(bigint, jsonb, timestamptz, text, boolean, boolean), doc.assinatura_enviar(bigint),
  doc.assinatura_cancelar(bigint, text), doc.assinatura_assinar(bigint, text, boolean), doc.assinatura_recusar(bigint, text), doc.assinatura_registrar_fora(bigint, text),
  doc.assinatura_documento(bigint), ext.portal_assinaturas(), ext.assinatura_assinar(bigint, text, boolean), ext.assinatura_recusar(bigint, text), ext.assinatura_documento(bigint)
  to authenticated, service_role;
commit;
