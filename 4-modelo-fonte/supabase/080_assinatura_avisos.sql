-- Assinatura eletrônica avançada (076), três complementos:
--  1. aviso por e-mail de que chegou a vez de assinar (e um lembrete único perto do fim do prazo): o banco enfileira em
--     doc.assinatura_aviso e pede o envio à função do servidor avisos pelo pg_net (X-IMTS-Chave, como o selo); a rotina
--     imts-assinatura também drena a fila. Gmail da conta do sistema. Até 5 tentativas; esgotou, vira alerta de operação.
--     O e-mail leva título, quem pediu, prazo e o link da Central (equipe) ou do Portal (cliente e parceiro); nenhum segredo.
--  2. limite de consultas na verificação pública: contador por minuto, por IP e por código, guardado só como hash com sal
--     do cofre (segredo verificar_sal, gerado pelo próprio banco); limpeza automática pela rotina.
--  3. rotação da chave do selo: adm.assinatura_chave_rotacionar(motivo), só administração; a chave pública aposentada fica
--     na tabela para conferir os selos antigos pelo kid; a privada é destruída dentro do cofre; a próxima selagem gera outra.
-- Idempotente: pode rodar de novo.
begin;

-- ---------- parâmetros ----------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('assinatura.url_app', 'documental', 'Endereço do aplicativo usado no link dos avisos de assinatura (Central para a equipe, Portal para cliente e parceiro)', 'texto',
  '"https://www.imts.global"', '"https://www.imts.global"', '{}', true, '{}', 'Avisos de assinatura (080)'),
 ('assinatura.lembrete_horas', 'documental', 'Horas antes do fim do prazo em que sai o lembrete único para quem está na vez de assinar', 'inteiro',
  '24', '24', '{"min":1,"max":168}', true, '{}', 'Avisos de assinatura (080)'),
 ('verificar.limite_por_minuto', 'documental', 'Consultas por minuto aceitas na verificação pública, contadas por IP e por código; acima disso a função verificar responde 429', 'inteiro',
  '30', '30', '{"min":1,"max":600}', true, '{}', 'Avisos de assinatura (080)')
on conflict (chave) do nothing;

-- ---------- 1. fila de avisos por e-mail ----------
create table if not exists doc.assinatura_aviso (
  id bigint generated always as identity primary key,
  pedido bigint not null references doc.assinatura_pedido(id),
  signatario bigint not null references doc.assinatura_signatario(id),
  tipo text not null check (tipo in ('vez', 'lembrete')),
  situacao text not null default 'pendente' check (situacao in ('pendente', 'enviado', 'falhou', 'descartado')),
  tentativas smallint not null default 0 check (tentativas between 0 and 5),
  proxima_em timestamptz not null default now(),
  ultimo_erro text,
  criado_em timestamptz not null default now(),
  enviado_em timestamptz,
  encerrado_em timestamptz,
  unique (signatario, tipo),                                   -- um aviso por signatário por vez e um lembrete só
  check (situacao <> 'enviado' or enviado_em is not null)
);
create index if not exists assinatura_aviso_fila on doc.assinatura_aviso (proxima_em) where situacao = 'pendente';
create index if not exists assinatura_aviso_pedido on doc.assinatura_aviso (pedido);
alter table doc.assinatura_aviso enable row level security;   -- sem política: ninguém lê pela API
revoke all on doc.assinatura_aviso from anon, public, authenticated;
grant all on doc.assinatura_aviso to service_role;

-- pede o envio à função do servidor avisos (vai pela fila do pg_net depois do commit); sem endereço configurado, a rotina tenta depois
create or replace function doc._ass_pedir_aviso() returns bigint language plpgsql security definer set search_path = '' as $$
declare u text := rt._url_funcao('avisos');
begin
  if u is null or rt._segredo('imts_funcao_chave') is null then return null; end if;
  return net.http_post(url := u, headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{"acao":"avisar"}'::jsonb, timeout_milliseconds := 30000);
end $$;

-- a vez chegou: enfileira o e-mail de quem está na vez (sem duplicar) e mantém o aviso pelo Telegram ao externo (076)
create or replace function doc._ass_avisar_vez(p_pedido bigint) returns void language plpgsql security definer set search_path = '' as $$
declare s doc.assinatura_signatario; p doc.assinatura_pedido; n int;
begin
  select * into p from doc.assinatura_pedido where id = p_pedido;
  if p.situacao <> 'aguardando' then return; end if;
  select * into s from doc.assinatura_signatario where pedido = p_pedido and situacao = 'pendente' order by ordem limit 1;
  if s.id is null then return; end if;
  insert into doc.assinatura_aviso (pedido, signatario, tipo) values (p.id, s.id, 'vez') on conflict (signatario, tipo) do nothing;
  get diagnostics n = row_count;
  if n > 0 then perform doc._ass_pedir_aviso(); end if;
  if s.usuario is null then return; end if;
  insert into rt.fila_envio (chat_ref, texto, simulado)
  select t.chat_ref, left('IMTS.OS: o documento "' || p.titulo || '" aguarda a sua assinatura no portal, até ' || to_char(p.prazo at time zone 'America/Fortaleza', 'DD/MM/YYYY') || '.', 3500), t.simulado
    from ext.telegram t where t.auth_uid = s.usuario and t.vinculado_em is not null and t.chat_ref is not null;
end $$;

-- aviso que perdeu o sentido (pedido encerrado ou vencido, signatário que já respondeu, ou que não está mais na vez) não sai
create or replace function doc._ass_aviso_descartar() returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  update doc.assinatura_aviso a set situacao = 'descartado', encerrado_em = now()
    from doc.assinatura_pedido p, doc.assinatura_signatario s
   where a.situacao = 'pendente' and p.id = a.pedido and s.id = a.signatario
     and (p.situacao <> 'aguardando' or p.prazo < now() or s.situacao <> 'pendente'
          or exists (select 1 from doc.assinatura_signatario x where x.pedido = s.pedido and x.ordem < s.ordem and x.situacao not in ('assinado', 'assinado_fora')));
  get diagnostics n = row_count;
  return n;
end $$;

-- falhou de vez: alerta de operação (um alerta aberto por vez; as repetições somam)
create or replace function doc._ass_aviso_esgotado(p_id bigint, p_erro text) returns void language plpgsql security definer set search_path = '' as $$
declare a record;
begin
  update doc.assinatura_aviso set situacao = 'falhou', encerrado_em = now(), ultimo_erro = left(coalesce(p_erro, ultimo_erro, 'sem resposta da função avisos'), 500)
   where id = p_id and situacao = 'pendente';
  select v.id, v.tipo, v.ultimo_erro, p.id pedido, p.titulo, s.email into a
    from doc.assinatura_aviso v join doc.assinatura_pedido p on p.id = v.pedido join doc.assinatura_signatario s on s.id = v.signatario where v.id = p_id;
  perform adm._alertar('assinatura:avisos', 'erro',
    'aviso de assinatura (' || case a.tipo when 'vez' then 'vez de assinar' else 'lembrete de prazo' end || ') não saiu depois de 5 tentativas: pedido nº ' || a.pedido
    || ' "' || left(a.titulo, 120) || '", para ' || coalesce(doc._ass_mascarar(a.email), '?') || '. Último erro: ' || coalesce(a.ultimo_erro, 'não informado')
    || '. Confira google.usuario_sistema, o segredo google_conta_servico e a função avisos.');
end $$;

-- lote para a função avisos (só a chave de serviço): descarta o que perdeu o sentido, fecha o que esgotou e reserva até p_limite
-- avisos (cada reserva conta uma tentativa e segura o aviso por 10 minutos, para duas chamadas não mandarem o mesmo e-mail)
create or replace function doc.assinatura_avisos_para_enviar(p_limite int default 10) returns jsonb language plpgsql security definer set search_path = '' as $$
declare r record; v_base text := coalesce(nullif(rtrim(coalesce(adm.valor('assinatura.url_app', '""') #>> '{}', ''), '/'), ''), 'https://www.imts.global');
  ids bigint[];
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  perform doc._ass_aviso_descartar();
  for r in select id from doc.assinatura_aviso where situacao = 'pendente' and tentativas >= 5 and proxima_em <= now() for update skip locked loop
    perform doc._ass_aviso_esgotado(r.id, null);
  end loop;
  with lote as (select id from doc.assinatura_aviso where situacao = 'pendente' and proxima_em <= now() order by proxima_em, id
                 limit greatest(1, least(coalesce(p_limite, 10), 50)) for update skip locked),
       reservados as (update doc.assinatura_aviso a set tentativas = a.tentativas + 1, proxima_em = now() + interval '10 minutes' from lote where a.id = lote.id returning a.id)
  select array_agg(id) into ids from reservados;
  return jsonb_build_object('remetente', nullif(adm.valor('google.usuario_sistema', '""') #>> '{}', ''),
    'avisos', (select coalesce(jsonb_agg(jsonb_build_object('id', v.id, 'tipo', v.tipo, 'tentativa', v.tentativas, 'para', s.email, 'nome', s.nome,
        'titulo', p.titulo, 'empresa', (select nome from org.empresa where id = p.empresa),
        'pedido_por', coalesce((select nome from rt_chave.identidade where pseudonimo = p.pedido_por), 'a equipe do IMTS'),
        'prazo', p.prazo, 'prazo_texto', to_char(p.prazo at time zone 'America/Sao_Paulo', 'DD/MM/YYYY "às" HH24:MI'),
        'exige_icp', p.exige_icp, 'interno', s.pessoa is not null,
        'link', v_base || case when s.pessoa is not null then '/central.html#assinaturas' else '/portal.html#assinaturas' end) order by v.id), '[]')
      from doc.assinatura_aviso v join doc.assinatura_signatario s on s.id = v.signatario join doc.assinatura_pedido p on p.id = v.pedido
     where v.id = any (coalesce(ids, '{}'))));
end $$;

-- resultado do envio de um aviso (só a chave de serviço): enviado; ou falha, que volta para a fila com espera crescente até a 5ª tentativa
create or replace function doc.assinatura_aviso_resultado(p_id bigint, p_ok boolean, p_erro text default null) returns text
language plpgsql security definer set search_path = '' as $$
declare a doc.assinatura_aviso;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select * into a from doc.assinatura_aviso where id = p_id for update;
  if a.id is null then raise exception 'aviso inexistente: %', p_id; end if;
  if a.situacao <> 'pendente' then return a.situacao; end if;
  if coalesce(p_ok, false) then
    update doc.assinatura_aviso set situacao = 'enviado', enviado_em = now(), encerrado_em = now(), ultimo_erro = null where id = a.id;
    return 'enviado';
  end if;
  if a.tentativas >= 5 then
    perform doc._ass_aviso_esgotado(a.id, coalesce(nullif(btrim(p_erro), ''), 'falha no envio'));
    return 'falhou';
  end if;
  update doc.assinatura_aviso set ultimo_erro = left(coalesce(nullif(btrim(p_erro), ''), 'falha no envio'), 500),
         proxima_em = now() + make_interval(mins => 5 * power(2, greatest(a.tentativas - 1, 0))::int) where id = a.id;
  return 'pendente';
end $$;

-- ---------- 2. limite de consultas na verificação pública ----------
create table if not exists doc.verificar_consulta (
  chave text not null check (chave ~ '^(ip|codigo):[0-9a-f]{64}$'),   -- só hash com sal: nem IP nem código em claro
  janela timestamptz not null,
  n int not null default 1,
  primary key (chave, janela)
);
create index if not exists verificar_consulta_janela on doc.verificar_consulta (janela);
alter table doc.verificar_consulta enable row level security;
revoke all on doc.verificar_consulta from anon, public, authenticated;
grant all on doc.verificar_consulta to service_role;

-- sal do contador: segredo do cofre gerado pelo próprio banco na primeira vez
create or replace function doc._verificar_sal() returns text language plpgsql volatile security definer set search_path = '' as $$
declare v text := rt._segredo('verificar_sal');
begin
  if v is not null then return v; end if;
  perform pg_advisory_xact_lock(hashtextextended('verificar_sal', 0));
  v := rt._segredo('verificar_sal');
  if v is null then
    v := encode(extensions.gen_random_bytes(32), 'hex');
    perform vault.create_secret(v, 'verificar_sal', 'sal do contador de consultas da verificação pública (hash do IP e do código); gerado pelo banco');
  end if;
  return v;
end $$;

-- conta a consulta (por IP e, se houver, por código) na janela do minuto e diz se ela passa
create or replace function doc.verificar_contar(p_ip text, p_codigo text default null) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_lim int := doc._ass_param('verificar.limite_por_minuto', 30); v_j timestamptz := date_trunc('minute', clock_timestamp()); v_sal text := doc._verificar_sal();
  v_cod text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g')); n_ip int; n_cod int := 0;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  insert into doc.verificar_consulta as c (chave, janela) values ('ip:' || doc._ass_sha256(v_sal || ':ip:' || coalesce(nullif(left(btrim(coalesce(p_ip, '')), 64), ''), 'desconhecido')), v_j)
  on conflict (chave, janela) do update set n = c.n + 1 returning c.n into n_ip;
  if v_cod <> '' then
    insert into doc.verificar_consulta as c (chave, janela) values ('codigo:' || doc._ass_sha256(v_sal || ':codigo:' || left(v_cod, 40)), v_j)
    on conflict (chave, janela) do update set n = c.n + 1 returning c.n into n_cod;
  end if;
  if random() < 0.02 then delete from doc.verificar_consulta where janela < now() - interval '1 hour'; end if;
  return jsonb_build_object('permitido', n_ip <= v_lim and n_cod <= v_lim, 'limite', v_lim,
    'por', case when n_ip > v_lim then 'ip' when n_cod > v_lim then 'codigo' end,
    'tentar_em', greatest(1, ceil(extract(epoch from (v_j + interval '1 minute' - clock_timestamp())))::int));
end $$;

-- ---------- 3. rotação da chave do selo ----------
alter table doc.assinatura_chave add column if not exists aposentada_em timestamptz;
alter table doc.assinatura_chave add column if not exists aposentada_motivo text;
alter table doc.assinatura_chave add column if not exists aposentada_por uuid;
alter table doc.assinatura_chave drop constraint if exists assinatura_chave_aposentada;
alter table doc.assinatura_chave add constraint assinatura_chave_aposentada check (ativa = (aposentada_em is null));

-- a chave pública confere os selos já emitidos: não se apaga, não muda e, aposentada, não volta
create or replace function doc._ass_chave_guarda() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op in ('DELETE', 'TRUNCATE') then raise exception 'a chave do selo não se apaga: ela confere os selos já emitidos'; end if;
  if new.kid <> old.kid or new.publica <> old.publica or new.algoritmo <> old.algoritmo or new.criada_em <> old.criada_em then
    raise exception 'a chave pública do selo não muda'; end if;
  if not old.ativa and new.ativa then raise exception 'chave do selo aposentada não volta a valer: a próxima selagem gera outra'; end if;
  if not old.ativa and (new.aposentada_em is distinct from old.aposentada_em or new.aposentada_motivo is distinct from old.aposentada_motivo) then
    raise exception 'registro de aposentadoria da chave não muda'; end if;
  return new;
end $$;
drop trigger if exists guarda on doc.assinatura_chave;
create trigger guarda before update or delete on doc.assinatura_chave for each row execute function doc._ass_chave_guarda();
drop trigger if exists guarda_truncate on doc.assinatura_chave;
create trigger guarda_truncate before truncate on doc.assinatura_chave for each statement execute function doc._ass_chave_guarda();

-- só a administração: aposenta a chave ativa (a pública fica para conferir pelo kid), destrói a privada dentro do cofre e
-- deixa a próxima selagem gerar outro par (doc.assinatura_chave_gravar). A chave privada nunca sai do cofre.
create or replace function adm.assinatura_chave_rotacionar(p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._so_admin(); k doc.assinatura_chave; n int; pend int;
begin
  if coalesce(length(btrim(p_motivo)), 0) < 5 then raise exception 'informe o motivo da rotação da chave do selo'; end if;
  perform pg_advisory_xact_lock(hashtextextended('assinatura_chave', 0));
  select * into k from doc.assinatura_chave where ativa for update;
  if k.kid is null then raise exception 'não há chave do selo ativa: a próxima selagem já gera uma nova'; end if;
  update doc.assinatura_chave set ativa = false, aposentada_em = now(), aposentada_motivo = left(btrim(p_motivo), 500), aposentada_por = v where kid = k.kid;
  delete from vault.secrets where name = 'assinatura_chave_privada';
  get diagnostics n = row_count;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('conexao', 'segredo:assinatura_chave_privada', jsonb_build_object('kid', k.kid, 'ativa', true),
          jsonb_build_object('kid', k.kid, 'ativa', false, 'privada_destruida_no_cofre', n > 0), v, 'app', left(btrim(p_motivo), 500));
  select count(*) into pend from doc.assinatura_pedido p where p.situacao = 'concluido' and not p.exige_icp and not exists (select 1 from doc.assinatura_selo s where s.pedido = p.id);
  return jsonb_build_object('kid_aposentada', k.kid, 'aposentada_em', now(), 'selos_com_esta_chave', (select count(*) from doc.assinatura_selo where kid = k.kid),
    'pendentes_de_selo', pend, 'proxima', 'a próxima selagem gera uma chave nova; os selos antigos continuam conferindo pela chave pública aposentada');
end $$;

-- ---------- rotina: vence, lembra, pede selos e avisos, limpa o contador da verificação ----------
create or replace function doc.assinatura_rotina() returns jsonb language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0; pend int; v_h int := doc._ass_param('assinatura.lembrete_horas', 24); n_lemb int; n_av int;
begin
  for r in select id from doc.assinatura_pedido where situacao in ('rascunho', 'aguardando') and prazo < now() loop
    if doc._ass_vencer(r.id) then n := n + 1; end if;
  end loop;
  perform doc._ass_aviso_descartar();
  -- lembrete único para quem está na vez há mais tempo que a janela do lembrete (quem chegou à vez dentro dela já recebeu o prazo no aviso)
  insert into doc.assinatura_aviso (pedido, signatario, tipo)
  select p.id, s.id, 'lembrete' from doc.assinatura_pedido p
    join lateral (select x.id from doc.assinatura_signatario x where x.pedido = p.id and x.situacao = 'pendente' order by x.ordem limit 1) s on true
   where p.situacao = 'aguardando' and p.prazo > now() and p.prazo <= now() + make_interval(hours => v_h)
     and exists (select 1 from doc.assinatura_aviso a where a.signatario = s.id and a.tipo = 'vez' and a.criado_em < p.prazo - make_interval(hours => v_h))
  on conflict (signatario, tipo) do nothing;
  get diagnostics n_lemb = row_count;
  select count(*) into pend from doc.assinatura_pedido p where p.situacao = 'concluido' and not p.exige_icp and not exists (select 1 from doc.assinatura_selo s where s.pedido = p.id);
  if pend > 0 then perform doc._ass_pedir_selo(); end if;
  select count(*) into n_av from doc.assinatura_aviso where situacao = 'pendente' and proxima_em <= now();
  if n_av > 0 then perform doc._ass_pedir_aviso(); end if;
  delete from doc.verificar_consulta where janela < now() - interval '1 hour';
  return jsonb_build_object('vencidos', n, 'sem_selo', pend, 'lembretes', n_lemb, 'avisos_pendentes', n_av);
end $$;

-- ---------- catálogo e porta única ----------
insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('edge-avisos', 'Função do servidor avisos (e-mail de vez de assinar e lembrete de prazo, chamada pelo banco e pela rotina)', 'assinatura', 'produção', null, 'Governança', 'pendente',
  '{imts_funcao_chave,google_conta_servico}', 'manual', null,
  'publicar a função com verificação de JWT desligada (só aceita a chave X-IMTS-Chave) e preencher servidor.url_funcoes e google.usuario_sistema', '080')
on conflict (codigo) do update set nome = excluded.nome, segredos = excluded.segredos, pendencia = excluded.pendencia where adm.conexao.estado = 'pendente';
update adm.conexao set segredos = array_append(segredos, 'verificar_sal')
 where codigo = 'edge-verificar' and not ('verificar_sal' = any (segredos));

insert into adm.api_funcao (nome, quem, descricao) values
 ('adm.assinatura_chave_rotacionar', 'interno', 'Rotacionar a chave do selo de assinatura (só administração)')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;

-- o sal nasce já na implantação (o contador também o cria se faltar)
do $$ begin
  if to_regclass('vault.secrets') is not null then perform doc._verificar_sal(); end if;
end $$;

-- ---------- permissões ----------
revoke all on function doc._ass_pedir_aviso(), doc._ass_avisar_vez(bigint), doc._ass_aviso_descartar(), doc._ass_aviso_esgotado(bigint, text),
  doc.assinatura_avisos_para_enviar(int), doc.assinatura_aviso_resultado(bigint, boolean, text), doc._verificar_sal(), doc.verificar_contar(text, text),
  doc._ass_chave_guarda(), doc.assinatura_rotina() from public, anon, authenticated;
grant execute on function doc.assinatura_avisos_para_enviar(int), doc.assinatura_aviso_resultado(bigint, boolean, text), doc.verificar_contar(text, text),
  doc.assinatura_rotina() to service_role;
revoke all on function adm.assinatura_chave_rotacionar(text) from public, anon;
grant execute on function adm.assinatura_chave_rotacionar(text) to authenticated, service_role;
commit;
