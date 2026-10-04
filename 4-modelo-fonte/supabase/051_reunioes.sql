-- E21 · Reuniões remotas com gravação, transcrição, ata e encaminhamentos (aprovado por Ítalo em 04/10/2026, "Prossiga").
-- Contrato comum de adaptador: qualquer plataforma (Google Meet primeiro; Zoom, Teams e Webex depois) entrega ao banco
-- o mesmo registro: evento, link, e depois a transcrição como arquivo do acervo (pasta 09 Reuniões).
-- Regras: gravar exige consentimento registrado; a ata pode ser rascunhada por IA, mas só vale aprovada por uma pessoa;
-- a aprovação gera os encaminhamentos (cartão do responsável; se a reunião é de uma demanda, o cliente vê as datas).
begin;

alter table adm.conexao drop constraint if exists conexao_categoria_check;
alter table adm.conexao add constraint conexao_categoria_check check (categoria in ('banco de dados', 'api', 'mensageria', 'segredos', 'agenda', 'documentos', 'contábil',
  'fiscal', 'bancário', 'assinatura', 'ia', 'repositório', 'domínio', 'videoconferência'));
insert into adm.conexao (codigo, nome, categoria, ambiente, dono, estado, segredos, verificacao, pendencia, fonte) values
 ('google-meet', 'Google Meet pela Agenda Google', 'videoconferência', 'protótipo', 'Integração', 'pendente', '{}', 'manual',
  'No protótipo, a Central cria o evento com Meet pelo conector Google Calendar de quem a abre; a primeira reunião real confirma. Transcrição: arquivo do Meet no Drive, ligado à reunião.', 'E21, 04/10/2026'),
 ('zoom', 'Zoom', 'videoconferência', 'produção', 'Integração', 'pendente', '{}', 'manual',
  'registrar o app no Zoom App Marketplace (OAuth), gravar os segredos no Vault e ligar o adaptador ao contrato comum (ext.reuniao_registrar_externa e ext.reuniao_transcricao)', 'E21, 04/10/2026'),
 ('microsoft-teams', 'Microsoft Teams', 'videoconferência', 'produção', 'Integração', 'pendente', '{}', 'manual',
  'registrar o app no Microsoft Entra ID (Graph: reuniões online e transcrições), gravar os segredos no Vault e ligar o adaptador ao contrato comum', 'E21, 04/10/2026'),
 ('webex', 'Webex', 'videoconferência', 'produção', 'Integração', 'pendente', '{}', 'manual',
  'registrar a integração no Webex for Developers (OAuth), gravar os segredos no Vault e ligar o adaptador ao contrato comum', 'E21, 04/10/2026')
on conflict (codigo) do nothing;

insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('reuniao.retencao_gravacao_dias', 'global', 'Dias que a gravação e a transcrição ficam guardadas depois da ata aprovada (a ata fica)', 'inteiro', '90', '90', '{"min":7,"max":1825}', true, '{}', 'E21, 04/10/2026; valor a confirmar pela Governança'),
 ('reuniao.prazo_encaminhamento_dias', 'global', 'Prazo padrão de um encaminhamento saído de reunião, quando a ata não diz', 'inteiro', '7', '7', '{"min":1,"max":90}', false, '{}', 'E21, 04/10/2026')
on conflict (chave) do nothing;

create table if not exists ext.reuniao (
  id bigint generated always as identity primary key,
  empresa uuid not null references org.empresa(id),
  contraparte uuid references ext.contraparte(id),
  pedido bigint references ext.pedido(id),
  titulo text not null check (length(btrim(titulo)) between 3 and 200),
  inicio timestamptz not null,
  duracao_min int not null default 60 check (duracao_min between 10 and 480),
  plataforma text not null check (plataforma in ('meet', 'zoom', 'teams', 'webex', 'presencial', 'outra')),
  link text,
  evento_id text,
  gravar boolean not null default false,
  consentimentos jsonb not null default '[]',
  situacao text not null default 'agendada' check (situacao in ('agendada', 'realizada', 'cancelada')),
  transcricao bigint references acervo.arquivo(id),
  ata jsonb,
  ata_situacao text not null default 'sem' check (ata_situacao in ('sem', 'rascunho', 'aprovada')),
  ata_por uuid,
  ata_em timestamptz,
  apagar_gravacao_em date,
  criado_por uuid not null,
  criado_em timestamptz not null default now()
);
create index if not exists reuniao_empresa on ext.reuniao (empresa, inicio desc);
alter table ext.encaminhamento alter column pedido drop not null;
alter table ext.encaminhamento drop constraint if exists encaminhamento_origem_check2;
alter table ext.encaminhamento add constraint encaminhamento_origem_check2 check (pedido is not null or reuniao is not null);
alter table ext.encaminhamento drop constraint if exists encaminhamento_reuniao_fk;
alter table ext.encaminhamento add constraint encaminhamento_reuniao_fk foreign key (reuniao) references ext.reuniao(id);

drop policy if exists leitura on ext.encaminhamento;
create policy leitura on ext.encaminhamento for select to authenticated
  using ((pedido is not null and exists (select 1 from ext.pedido p where p.id = pedido)) or (reuniao is not null and exists (select 1 from ext.reuniao r where r.id = reuniao)));
-- encaminhamento de reunião sem demanda: a empresa vem da reunião
create or replace function ext.encaminhamento_concluir(p_encaminhamento bigint, p_situacao text, p_conclusao text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); e ext.encaminhamento; v_emp uuid; v_tipo text;
begin
  select * into e from ext.encaminhamento where id = p_encaminhamento for update;
  if e.id is null then raise exception 'encaminhamento inexistente'; end if;
  select c.empresa, p.tipo into v_emp, v_tipo from ext.pedido p join ext.contraparte c on c.id = p.contraparte where p.id = e.pedido;
  v_emp := coalesce(v_emp, (select empresa from ext.reuniao where id = e.reuniao));
  if v_emp is null or not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if v_tipo = 'ouvidoria' and not rt.pode(v, v_emp, 9::smallint, 'operar') then raise exception 'a ouvidoria é conduzida pela Governança'; end if;
  if e.situacao <> 'aberto' then raise exception 'encaminhamento já %', e.situacao; end if;
  if p_situacao not in ('concluido', 'cancelado') then raise exception 'situação inválida'; end if;
  if coalesce(length(btrim(p_conclusao)), 0) = 0 then raise exception 'diga o que foi feito ou por que cancelou'; end if;
  update ext.encaminhamento set situacao = p_situacao, conclusao = btrim(p_conclusao), concluido_por = v, concluido_em = now() where id = e.id;
  perform ext._fechar_cartao(e.cartao);
  if e.pedido is not null then update ext.pedido set atualizado_em = now() where id = e.pedido; end if;
end $$;

alter table ext.reuniao enable row level security;
drop policy if exists leitura on ext.reuniao;
create policy leitura on ext.reuniao for select to authenticated using (
  (contraparte = (ext.eu()).contraparte and (pedido is null or exists (select 1 from ext.pedido p where p.id = pedido)))
  or (rt.eu() is not null and rt.pode(rt.eu(), empresa, null, 'ler')));
grant select on ext.reuniao to authenticated; grant all on ext.reuniao to service_role;

create or replace function ext._reuniao_acesso(p_reuniao bigint, p_como uuid) returns ext.reuniao language plpgsql stable security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); r ext.reuniao;
begin
  select * into r from ext.reuniao where id = p_reuniao;
  if r.id is null then raise exception 'reunião inexistente'; end if;
  if not rt.pode(v, r.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  return r;
end $$;

-- agendar (o adaptador ou a página cria o evento na plataforma e devolve o link pelo contrato comum)
create or replace function ext.reuniao_agendar(p_empresa uuid, p_titulo text, p_inicio timestamptz, p_duracao_min int, p_plataforma text, p_pedido bigint default null,
  p_contraparte uuid default null, p_gravar boolean default false, p_como uuid default null) returns bigint language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); v_cp uuid := p_contraparte; v_id bigint;
begin
  if not rt.pode(v, p_empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if p_pedido is not null then
    select contraparte into v_cp from ext.pedido where id = p_pedido;
    if v_cp is null or (select empresa from ext.contraparte where id = v_cp) <> p_empresa then raise exception 'a demanda é de outra empresa'; end if;
    if (select tipo from ext.pedido where id = p_pedido) = 'ouvidoria' and not rt.pode(v, p_empresa, 9::smallint, 'operar') then raise exception 'a ouvidoria é conduzida pela Governança'; end if;
  elsif v_cp is not null and (select empresa from ext.contraparte where id = v_cp) is distinct from p_empresa then raise exception 'contraparte de outra empresa'; end if;
  if p_inicio is null or p_inicio < now() - interval '1 day' then raise exception 'informe a data da reunião'; end if;
  insert into ext.reuniao (empresa, contraparte, pedido, titulo, inicio, duracao_min, plataforma, gravar, criado_por)
  values (p_empresa, v_cp, p_pedido, btrim(p_titulo), p_inicio, coalesce(p_duracao_min, 60), p_plataforma, coalesce(p_gravar, false), v) returning id into v_id;
  if v_cp is not null then
    perform ext._avisar(v_cp, 'Reunião marcada: ' || btrim(p_titulo) || ' em ' || to_char(p_inicio at time zone 'America/Fortaleza', 'DD/MM/YYYY HH24:MI') || '. Detalhes no portal.',
                        '{gestor,fiscal,financeiro,operacional}');
  end if;
  return v_id;
end $$;

-- contrato comum do adaptador: evento e link da plataforma
create or replace function ext.reuniao_registrar_externa(p_reuniao bigint, p_evento_id text, p_link text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare r ext.reuniao := ext._reuniao_acesso(p_reuniao, p_como);
begin
  if p_link is not null and p_link !~ '^https://' then raise exception 'link precisa ser https'; end if;
  update ext.reuniao set evento_id = coalesce(p_evento_id, evento_id), link = coalesce(p_link, link) where id = r.id;
end $$;

-- consentimento para gravar: de dentro (quem conduz registra o consentimento falado, com o nome de quem consentiu) ou de fora (pelo portal)
create or replace function ext.reuniao_consentir(p_reuniao bigint, p_quem text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare r ext.reuniao := ext._reuniao_acesso(p_reuniao, p_como);
begin
  if coalesce(length(btrim(p_quem)), 0) < 3 then raise exception 'diga quem consentiu'; end if;
  update ext.reuniao set consentimentos = consentimentos || jsonb_build_object('quem', btrim(p_quem), 'registrado_por', coalesce(rt.eu(), p_como), 'canal', 'falado na reunião', 'em', now()) where id = r.id;
end $$;
create or replace function ext.reuniao_consentir_externo(p_reuniao bigint) returns void language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu(); r ext.reuniao;
begin
  select * into r from ext.reuniao where id = p_reuniao;
  if r.id is null or r.contraparte is distinct from u.contraparte then raise exception 'reunião não é da sua organização'; end if;
  if r.situacao <> 'agendada' then raise exception 'reunião %', r.situacao; end if;
  if exists (select 1 from jsonb_array_elements(r.consentimentos) c where c->>'externo' = u.auth_uid::text) then return; end if;
  update ext.reuniao set consentimentos = consentimentos || jsonb_build_object('quem', u.nome || ' (' || u.perfil || ')', 'externo', u.auth_uid, 'canal', 'portal', 'em', now()) where id = r.id;
end $$;

-- transcrição: arquivo do acervo, só com consentimento registrado
create or replace function ext.reuniao_transcricao(p_reuniao bigint, p_nome text, p_hash text, p_mime text, p_tamanho bigint, p_texto text, p_drive_id text, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r ext.reuniao := ext._reuniao_acesso(p_reuniao, p_como); a jsonb;
begin
  if not r.gravar then raise exception 'reunião marcada sem gravação: não há transcrição a guardar'; end if;
  if jsonb_array_length(r.consentimentos) = 0 then raise exception 'sem consentimento registrado não se guarda gravação nem transcrição'; end if;
  if coalesce(length(p_texto), 0) < 20 then raise exception 'transcrição sem texto legível'; end if;
  a := acervo._registrar(r.empresa, p_nome, p_hash, p_mime, p_tamanho, p_texto, 'drive', p_drive_id, r.contraparte, coalesce(rt.eu(), p_como), null);
  if a->>'situacao' = 'duplicado' then
    update ext.reuniao set transcricao = (a->>'arquivo')::bigint, situacao = 'realizada' where id = r.id;
    return a;
  end if;
  update acervo.arquivo set pasta = '09', tipo = 'transcricao-reuniao', situacao = case when p_drive_id is null then 'entrada' else 'organizado' end, motivo = null where id = (a->>'arquivo')::bigint;
  update ext.reuniao set transcricao = (a->>'arquivo')::bigint, situacao = 'realizada' where id = r.id;
  return a || jsonb_build_object('pasta', '09');
end $$;

-- ata: rascunho (de pessoa ou de IA) e aprovação por pessoa; a aprovação cria os encaminhamentos
-- formato: {"resumo": text, "decisoes": [text], "encaminhamentos": [{"descricao": text, "responsavel": "Operações · pessoa", "prazo_dias": int}], "origem": "ia"|"pessoa"}
create or replace function ext._ata_valida(p_ata jsonb) returns void language plpgsql immutable set search_path = '' as $$
declare e jsonb;
begin
  if jsonb_typeof(p_ata) <> 'object' or coalesce(length(btrim(p_ata->>'resumo')), 0) < 10 then raise exception 'a ata precisa de resumo'; end if;
  if jsonb_typeof(coalesce(p_ata->'decisoes', '[]')) <> 'array' or jsonb_typeof(coalesce(p_ata->'encaminhamentos', '[]')) <> 'array' then raise exception 'decisões e encaminhamentos são listas'; end if;
  for e in select * from jsonb_array_elements(coalesce(p_ata->'encaminhamentos', '[]')) loop
    if coalesce(length(btrim(e->>'descricao')), 0) < 3 or coalesce(e->>'responsavel', '') = '' then raise exception 'cada encaminhamento precisa de descrição e responsável'; end if;
  end loop;
end $$;
create or replace function ext.reuniao_ata_rascunho(p_reuniao bigint, p_ata jsonb, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare r ext.reuniao := ext._reuniao_acesso(p_reuniao, p_como);
begin
  if r.ata_situacao = 'aprovada' then raise exception 'ata já aprovada'; end if;
  perform ext._ata_valida(p_ata);
  update ext.reuniao set ata = p_ata, ata_situacao = 'rascunho' where id = r.id;
end $$;
create or replace function ext.reuniao_ata_aprovar(p_reuniao bigint, p_ata jsonb, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r ext.reuniao := ext._reuniao_acesso(p_reuniao, p_como); v uuid := coalesce(rt.eu(), p_como); e jsonb; v_resp uuid; v_circ smallint; v_id bigint; v_card bigint; n int := 0; v_ata jsonb;
begin
  if r.ata_situacao = 'aprovada' then raise exception 'ata já aprovada'; end if;
  v_ata := coalesce(p_ata, r.ata);
  if v_ata is null then raise exception 'não há ata para aprovar'; end if;
  perform ext._ata_valida(v_ata);
  for e in select * from jsonb_array_elements(coalesce(v_ata->'encaminhamentos', '[]')) loop
    select pseudonimo, circulo into v_resp, v_circ from rt.pessoa where papel = e->>'responsavel' and circulo is not null order by pseudonimo limit 1;
    if v_resp is null then raise exception 'responsável desconhecido: %', e->>'responsavel'; end if;
    insert into ext.encaminhamento (pedido, descricao, responsavel, prazo, origem, reuniao, criado_por)
    values (r.pedido, btrim(e->>'descricao'), v_resp, now() + make_interval(days => coalesce((e->>'prazo_dias')::int, (adm.valor('reuniao.prazo_encaminhamento_dias', '7') #>> '{}')::int)),
            'reuniao', r.id, v) returning id into v_id;
    v_card := rt.criar_avulsa(v_resp, left('Da reunião "' || r.titulo || '": ' || btrim(e->>'descricao'), 200), (select prazo from ext.encaminhamento where id = v_id), null, 'externo', null);
    update rt.cartao set empresa = r.empresa where id = v_card;
    update ext.encaminhamento set cartao = v_card where id = v_id;
    n := n + 1;
  end loop;
  if r.pedido is not null and n > 0 then
    update ext.pedido set situacao = case when situacao in ('recebido', 'respondido') then 'em_atendimento' else situacao end, confirmar_ate = null, atualizado_em = now() where id = r.pedido;
  end if;
  update ext.reuniao set ata = v_ata, ata_situacao = 'aprovada', ata_por = v, ata_em = now(), situacao = 'realizada',
         apagar_gravacao_em = case when transcricao is not null then current_date + (adm.valor('reuniao.retencao_gravacao_dias', '90') #>> '{}')::int end where id = r.id;
  if r.contraparte is not null then perform ext._avisar(r.contraparte, 'Ata da reunião "' || r.titulo || '" aprovada; os encaminhamentos estão no portal.', '{gestor,fiscal,financeiro,operacional}'); end if;
  return jsonb_build_object('encaminhamentos', n);
end $$;
create or replace function ext.reuniao_cancelar(p_reuniao bigint, p_motivo text, p_como uuid default null) returns void language plpgsql security definer set search_path = '' as $$
declare r ext.reuniao := ext._reuniao_acesso(p_reuniao, p_como);
begin
  if r.situacao <> 'agendada' then raise exception 'reunião %', r.situacao; end if;
  if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'diga o motivo'; end if;
  update ext.reuniao set situacao = 'cancelada', ata = jsonb_build_object('cancelada', btrim(p_motivo)) where id = r.id;
  if r.contraparte is not null then perform ext._avisar(r.contraparte, 'Reunião "' || r.titulo || '" cancelada: ' || btrim(p_motivo), '{gestor,fiscal,financeiro,operacional}'); end if;
end $$;

-- o que o lado de fora vê das reuniões
create or replace function ext.portal_reunioes() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'titulo', r.titulo, 'inicio', r.inicio, 'duracao_min', r.duracao_min, 'plataforma', r.plataforma,
      'link', case when r.situacao = 'agendada' then r.link end, 'gravar', r.gravar, 'situacao', r.situacao, 'pedido', r.pedido,
      'consenti', exists (select 1 from jsonb_array_elements(r.consentimentos) c where c->>'externo' = u.auth_uid::text),
      'ata', case when r.ata_situacao = 'aprovada' then jsonb_build_object('resumo', r.ata->'resumo', 'decisoes', r.ata->'decisoes', 'em', r.ata_em) end,
      'encaminhamentos', (select coalesce(jsonb_agg(jsonb_build_object('descricao', e.descricao, 'area', split_part(p.papel, ' · ', 1), 'prazo', e.prazo, 'situacao', e.situacao, 'concluido_em', e.concluido_em) order by e.id), '[]')
          from ext.encaminhamento e left join rt.pessoa p on p.pseudonimo = e.responsavel where e.reuniao = r.id)) order by r.inicio desc), '[]')
    from ext.reuniao r left join ext.pedido x on x.id = r.pedido
   where r.contraparte = u.contraparte and (r.pedido is null or x.usuario = u.auth_uid or (u.perfil = 'gestor' and x.tipo <> 'ouvidoria')));
end $$;
create or replace function ext.portal_reunioes_como(p_usuario uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.portal_reunioes(); end $$;
create or replace function ext.reuniao_consentir_como(p_usuario uuid, p_reuniao bigint) returns void language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); perform ext.reuniao_consentir_externo(p_reuniao); end $$;

-- Central: reuniões, conexões de vídeo e contexto (empresas e pessoas que atuam)
create or replace function ext.painel_reunioes(p_empresa uuid, p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu(); gov boolean;
begin
  if v is null then if not rt.chamada_servico() then raise exception 'sem identidade'; end if; v := p_como; end if;
  if v is null or not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso de leitura nesta empresa'; end if;
  gov := rt.pode(v, p_empresa, 9::smallint, 'ler');
  return jsonb_build_object(
    'reunioes', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'titulo', r.titulo, 'inicio', r.inicio, 'duracao_min', r.duracao_min, 'plataforma', r.plataforma, 'link', r.link,
        'evento_id', r.evento_id, 'gravar', r.gravar, 'consentimentos', r.consentimentos, 'situacao', r.situacao, 'pedido', r.pedido,
        'contraparte', case when x.anonimo then 'anônima' else c.nome end, 'transcricao', a.nome, 'transcricao_drive', a.drive_id, 'ata', r.ata, 'ata_situacao', r.ata_situacao,
        'ata_em', r.ata_em, 'apagar_gravacao_em', r.apagar_gravacao_em,
        'encaminhamentos', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'descricao', e.descricao, 'responsavel', p.papel, 'prazo', e.prazo, 'situacao', e.situacao) order by e.id), '[]')
            from ext.encaminhamento e left join rt.pessoa p on p.pseudonimo = e.responsavel where e.reuniao = r.id)) order by r.inicio desc), '[]')
        from ext.reuniao r left join ext.contraparte c on c.id = r.contraparte left join ext.pedido x on x.id = r.pedido left join acervo.arquivo a on a.id = r.transcricao
       where r.empresa = p_empresa and (x.tipo is distinct from 'ouvidoria' or gov)),
    'contrapartes', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'nome', nome, 'tipo', tipo) order by tipo, nome), '[]') from ext.contraparte where empresa = p_empresa and ativa),
    'conexoes', (select jsonb_agg(jsonb_build_object('codigo', codigo, 'nome', nome, 'estado', estado, 'pendencia', pendencia) order by codigo) from adm.conexao where categoria = 'videoconferência'));
end $$;
create or replace function ext.contexto_central() returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'empresas', (select jsonb_agg(jsonb_build_object('id', id, 'nome', nome) order by nome) from org.empresa where ativa),
    'pessoas', (select jsonb_agg(jsonb_build_object('pessoa', p.pseudonimo, 'papel', p.papel, 'circulo', p.circulo, 'nivel', a.nivel) order by p.circulo nulls first, p.papel)
                  from rt.pessoa p join rt.acesso a on a.pessoa = p.pseudonimo
                 where a.fim is null and a.nivel in ('operar', 'aprovar', 'administrar') and (p.papel like '%· pessoa' or p.papel in ('Administrador do IMTS.OS', 'Sócios')))) $$;

revoke all on function ext._reuniao_acesso(bigint, uuid), ext.reuniao_agendar(uuid, text, timestamptz, int, text, bigint, uuid, boolean, uuid), ext.reuniao_registrar_externa(bigint, text, text, uuid),
  ext.reuniao_consentir(bigint, text, uuid), ext.reuniao_consentir_externo(bigint), ext.reuniao_transcricao(bigint, text, text, text, bigint, text, text, uuid), ext._ata_valida(jsonb),
  ext.reuniao_ata_rascunho(bigint, jsonb, uuid), ext.reuniao_ata_aprovar(bigint, jsonb, uuid), ext.reuniao_cancelar(bigint, text, uuid), ext.portal_reunioes(), ext.portal_reunioes_como(uuid),
  ext.reuniao_consentir_como(uuid, bigint), ext.painel_reunioes(uuid, uuid), ext.contexto_central() from public, anon, authenticated;
grant execute on function ext.reuniao_agendar(uuid, text, timestamptz, int, text, bigint, uuid, boolean, uuid), ext.reuniao_registrar_externa(bigint, text, text, uuid), ext.reuniao_consentir(bigint, text, uuid),
  ext.reuniao_consentir_externo(bigint), ext.reuniao_transcricao(bigint, text, text, text, bigint, text, text, uuid), ext.reuniao_ata_rascunho(bigint, jsonb, uuid), ext.reuniao_ata_aprovar(bigint, jsonb, uuid),
  ext.reuniao_cancelar(bigint, text, uuid), ext.portal_reunioes(), ext.painel_reunioes(uuid, uuid) to authenticated;
grant execute on function ext.reuniao_agendar(uuid, text, timestamptz, int, text, bigint, uuid, boolean, uuid), ext.reuniao_registrar_externa(bigint, text, text, uuid), ext.reuniao_consentir(bigint, text, uuid),
  ext.reuniao_transcricao(bigint, text, text, text, bigint, text, text, uuid), ext.reuniao_ata_rascunho(bigint, jsonb, uuid), ext.reuniao_ata_aprovar(bigint, jsonb, uuid), ext.reuniao_cancelar(bigint, text, uuid),
  ext.portal_reunioes(), ext.portal_reunioes_como(uuid), ext.reuniao_consentir_como(uuid, bigint), ext.painel_reunioes(uuid, uuid), ext.contexto_central() to service_role;
commit;
