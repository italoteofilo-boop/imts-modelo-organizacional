-- E16 · Projeção externa e E14 · Portal externo (aprovados por Ítalo em 04/10/2026, às 10:13).
-- Regra central: quem é de fora nunca lê dado interno filtrado; lê só o que uma regra explícita publica (lista de permissão).
-- Um portal, dois perfis: cliente e parceiro. Cada contraparte vê só o que é dela, e cada perfil só o que é do seu papel.
begin;
create schema if not exists ext;
revoke all on schema ext from anon;
grant usage on schema ext to authenticated, service_role;

-- o cartão da Mesa passa a aceitar as origens externo (pedido de fora) e agente (agente residente, E15)
alter table rt.cartao drop constraint if exists cartao_origem_check;
alter table rt.cartao add constraint cartao_origem_check check (origem in ('motor', 'mesa', 'telegram', 'voz', 'externo', 'agente'));

create table if not exists adm.erro (id bigint generated always as identity primary key, origem text not null, detalhe text not null,
  contexto jsonb not null default '{}', em timestamptz not null default now(), visto boolean not null default false);
alter table adm.erro enable row level security;

create table if not exists ext.empresa_marca (empresa uuid primary key references org.empresa(id), marca text not null references doc.marca(id));

create table if not exists ext.contraparte (
  id uuid primary key default gen_random_uuid(), empresa uuid not null references org.empresa(id),
  tipo text not null check (tipo in ('cliente','parceiro')), nome text not null, documento text,
  setor_publico boolean not null default false, simulado boolean not null default false, ativa boolean not null default true,
  criado_em timestamptz not null default now());

-- usuário externo: login próprio (auth), ligado a uma contraparte, com um perfil
create table if not exists ext.usuario (
  auth_uid uuid primary key, contraparte uuid not null references ext.contraparte(id), nome text not null,
  perfil text not null check (perfil in ('gestor','fiscal','financeiro','operacional')),
  simulado boolean not null default false, ativo boolean not null default true, criado_em timestamptz not null default now());

-- a regra: só o que está aqui sai. etapa nula = fim da jornada
create table if not exists ext.regra (
  id bigint generated always as identity primary key, jornada text not null references org.jornada(codigo), etapa smallint,
  tipo text not null check (tipo in ('cliente','parceiro')), estado text not null, mensagem text not null,
  perfis text[] not null, acao text check (acao in ('aceite')), unique (jornada, etapa, tipo));

-- nome que quem é de fora vê para cada jornada (nunca o nome interno)
create table if not exists ext.jornada_externa (jornada text primary key references org.jornada(codigo), titulo text not null);

create table if not exists ext.vinculo (
  instancia bigint not null references rt.instancia(id) on delete cascade, contraparte uuid not null references ext.contraparte(id),
  criado_em timestamptz not null default now(), primary key (instancia, contraparte));

create table if not exists ext.publicacao (
  id bigint generated always as identity primary key, contraparte uuid not null references ext.contraparte(id),
  instancia bigint not null references rt.instancia(id) on delete cascade, jornada text not null, etapa smallint,
  estado text not null, mensagem text not null, perfis text[] not null, acao text, em timestamptz not null, simulado boolean not null);
-- o fim da jornada tem etapa nula: nulls not distinct para não duplicar o encerramento
delete from ext.publicacao a using ext.publicacao b where a.id > b.id and a.instancia = b.instancia and a.contraparte = b.contraparte and a.etapa is not distinct from b.etapa;
alter table ext.publicacao drop constraint if exists publicacao_instancia_contraparte_etapa_key;
alter table ext.publicacao drop constraint if exists publicacao_unica;
alter table ext.publicacao add constraint publicacao_unica unique nulls not distinct (instancia, contraparte, etapa);
create index if not exists publicacao_contraparte on ext.publicacao (contraparte, em desc);

create table if not exists ext.documento (
  contraparte uuid not null references ext.contraparte(id), emissao bigint not null references doc.emissao(id),
  perfis text[] not null default '{gestor,fiscal,financeiro,operacional}', publicado_em timestamptz not null default now(), publicado_por uuid,
  primary key (contraparte, emissao));

create table if not exists ext.pedido (
  id bigint generated always as identity primary key, contraparte uuid not null references ext.contraparte(id), usuario uuid not null references ext.usuario(auth_uid),
  tipo text not null check (tipo in ('chamado','aceite','devolucao','oportunidade','titular','adesao','duvida')),
  instancia bigint references rt.instancia(id) on delete set null, assunto text not null, texto text not null,
  situacao text not null default 'recebido' check (situacao in ('recebido','em_atendimento','respondido','encerrado','recusado')),
  resposta text, respondido_por text, cartao bigint, prazo timestamptz, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());

create unique index if not exists aceite_unico on ext.pedido (instancia, contraparte) where tipo in ('aceite','devolucao') and situacao <> 'recusado';
create index if not exists pedido_contraparte on ext.pedido (contraparte, id desc);
create index if not exists pedido_situacao on ext.pedido (situacao) where situacao = 'recebido';

create table if not exists ext.oportunidade (
  id bigint generated always as identity primary key, pedido bigint not null references ext.pedido(id), contraparte uuid not null references ext.contraparte(id),
  cliente_final text not null, chave text not null, exclusiva_ate date not null,
  situacao text not null default 'registrada' check (situacao in ('registrada','em_negociacao','ganha','perdida','expirada')));
drop index if exists ext.oportunidade_chave;
create unique index if not exists oportunidade_ativa on ext.oportunidade (chave) where situacao in ('registrada','em_negociacao');

-- Parâmetros do portal na administração geral
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('externo.prazo_resposta_horas', 'global', 'Prazo para responder o pedido de cliente ou parceiro (chamado, dúvida, oportunidade)', 'inteiro', '48', '48', '{"min":1,"max":240}', false, '{}', 'E14, 04/10/2026'),
 ('externo.prazo_aceite_horas', 'global', 'Prazo para tratar o aceite ou a devolução de entrega', 'inteiro', '24', '24', '{"min":1,"max":240}', false, '{}', 'E14, 04/10/2026'),
 ('externo.prazo_titular_dias', 'global', 'Prazo para responder o titular de dados (LGPD, art. 19, II: até 15 dias)', 'inteiro', '15', '15', '{"min":1,"max":15}', true, '{}', 'Lei 13.709/2018, art. 19, II'),
 ('externo.exclusividade_dias', 'global', 'Dias de exclusividade da oportunidade registrada pelo parceiro', 'inteiro', '90', '90', '{"min":15,"max":365}', true, '{}', 'E14, 04/10/2026')
on conflict (chave) do nothing;

-- Funções ------------------------------------------------------------------------------------------------------------------------
create or replace function ext._norm(t text) returns text language sql immutable set search_path = '' as $$
  select trim(regexp_replace(translate(lower(t), 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc'), '[^a-z0-9]+', ' ', 'g')) $$;

-- publica o que a regra permite para uma instância ligada; idempotente
create or replace function ext.projetar(p_inst bigint) returns int language plpgsql security definer set search_path = '' as $$
declare n int := 0; v record;
begin
  for v in
    select x.contraparte, i.jornada, g.numero as etapa, case when i.simulado then min(e.criado_em) else min(e.inicio) end as em, i.simulado
      from ext.vinculo x join rt.instancia i on i.id = x.instancia join rt.evento e on e.instancia = i.id join org.etapa g on g.id = e.etapa
     where x.instancia = p_inst group by 1, 2, 3, 5
    union all
    select x.contraparte, i.jornada, null::smallint, case when i.simulado then max(e.criado_em) else coalesce(i.fim, max(e.criado_em)) end, i.simulado
      from ext.vinculo x join rt.instancia i on i.id = x.instancia join rt.evento e on e.instancia = i.id
     where x.instancia = p_inst and e.tipo = 'fim' and e.etapa is null group by 1, 2, i.fim, 5
  loop
    insert into ext.publicacao (contraparte, instancia, jornada, etapa, estado, mensagem, perfis, acao, em, simulado)
    select v.contraparte, p_inst, v.jornada, v.etapa, r.estado, r.mensagem, r.perfis, r.acao, coalesce(v.em, now()), v.simulado
      from ext.regra r join ext.contraparte c on c.id = v.contraparte and c.tipo = r.tipo
     where r.jornada = v.jornada and r.etapa is not distinct from v.etapa
    on conflict (instancia, contraparte, etapa) do nothing;
    if found then n := n + 1; end if;
  end loop;
  return n;
end $$;

create or replace function ext._ao_evento() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from ext.vinculo where instancia = new.instancia) then
    begin perform ext.projetar(new.instancia);
    exception when others then
      insert into adm.erro (origem, detalhe, contexto) values ('ext.projetar', sqlerrm, jsonb_build_object('instancia', new.instancia, 'evento', new.id));
    end;
  end if;
  return null;
end $$;
drop trigger if exists projetar_externo on rt.evento;
create trigger projetar_externo after insert on rt.evento for each row when (new.instancia is not null) execute function ext._ao_evento();

create or replace function ext.vincular(p_inst bigint, p_contraparte uuid) returns int language plpgsql security definer set search_path = '' as $$
begin
  insert into ext.vinculo (instancia, contraparte) values (p_inst, p_contraparte) on conflict do nothing;
  return ext.projetar(p_inst);
end $$;

-- simulação: liga as instâncias simuladas recentes das jornadas com regra às contrapartes simuladas do tipo certo
create or replace function ext.vincular_simulados(p_limite int default 40) returns int language plpgsql security definer set search_path = '' as $$
declare n int := 0; r record; cs uuid[];
begin
  for r in
    select i.id, (select tipo from ext.regra where jornada = i.jornada limit 1) as tipo from rt.instancia i
     where i.simulado and i.inicio > now() - interval '2 days' and i.jornada in (select jornada from ext.regra)
       and not exists (select 1 from ext.vinculo v where v.instancia = i.id)
     order by i.id desc limit p_limite
  loop
    select array_agg(id order by id) into cs from ext.contraparte where simulado and ativa and tipo = r.tipo;
    if cs is null then continue; end if;
    perform ext.vincular(r.id, cs[1 + (r.id % array_length(cs, 1))::int]);
    n := n + 1;
  end loop;
  return n;
end $$;

-- quem está do lado de fora
create or replace function ext.eu() returns ext.usuario language sql stable security definer set search_path = '' as $$
  select u from ext.usuario u where u.auth_uid = auth.uid() and u.ativo $$;

create or replace function ext._exigir_eu() returns ext.usuario language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext.eu();
begin
  if u.auth_uid is null then raise exception 'acesso externo não reconhecido'; end if;
  if not exists (select 1 from ext.contraparte where id = u.contraparte and ativa) then raise exception 'contraparte inativa'; end if;
  return u;
end $$;

create or replace function ext.portal() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu(); c ext.contraparte;
begin
  select * into c from ext.contraparte where id = u.contraparte;
  return jsonb_build_object(
    'eu', jsonb_build_object('nome', u.nome, 'perfil', u.perfil),
    'contraparte', jsonb_build_object('nome', c.nome, 'tipo', c.tipo, 'setor_publico', c.setor_publico, 'simulado', c.simulado,
       'empresa', (select nome from org.empresa where id = c.empresa), 'marca', (select jsonb_build_object('nome', m.dados->'nome', 'cores', m.dados->'cores', 'logos', m.dados->'logos',   -- só o que é público: nada de inferências, fontes internas ou regras do motor
            'tipografia', jsonb_build_object('texto', m.dados->'tipografia'->'texto', 'display', m.dados->'tipografia'->'display', 'fallback', m.dados->'tipografia'->'fallback'))
          from doc.marca m join ext.empresa_marca em on em.marca = m.id where em.empresa = c.empresa)),
    'andamentos', (select coalesce(jsonb_agg(a order by a->>'atualizado' desc), '[]') from (
        select jsonb_build_object('ref', p.instancia, 'jornada', p.jornada,
          'assunto', (select titulo from ext.jornada_externa where jornada = p.jornada),
          'estado', (array_agg(p.estado order by p.em desc, p.etapa desc nulls first))[1],
          'acao', (array_agg(p.acao order by p.em desc, p.etapa desc nulls first))[1],
          'concluido', bool_or(p.etapa is null), 'atualizado', max(p.em),
          'linha', jsonb_agg(jsonb_build_object('estado', p.estado, 'mensagem', p.mensagem, 'em', p.em) order by p.em, p.etapa nulls last),
          'aceite', (select jsonb_build_object('tipo', x.tipo, 'situacao', x.situacao, 'em', x.criado_em) from ext.pedido x where x.instancia = p.instancia and x.contraparte = c.id and x.tipo in ('aceite','devolucao') order by x.id desc limit 1)) a
          from ext.publicacao p where p.contraparte = c.id and u.perfil = any (p.perfis) group by p.instancia, p.jornada
          order by max(p.em) desc limit 60) z(a)),
    'documentos', (select coalesce(jsonb_agg(jsonb_build_object('emissao', e.id, 'titulo', d.conteudo->>'titulo', 'tipo', t.nome, 'paginas', e.paginas,
          'hash', e.hash_pdf, 'publicado_em', x.publicado_em) order by x.publicado_em desc), '[]')
          from ext.documento x join doc.emissao e on e.id = x.emissao join doc.pedido d on d.id = e.pedido join doc.tipo t on t.id = d.tipo
         where x.contraparte = c.id and u.perfil = any (x.perfis)),
    'pedidos', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'tipo', p.tipo, 'assunto', p.assunto, 'situacao', p.situacao, 'resposta', p.resposta,
          'prazo', p.prazo, 'criado_em', p.criado_em, 'atualizado_em', p.atualizado_em) order by p.id desc), '[]')
          from ext.pedido p where p.contraparte = c.id and (u.perfil = 'gestor' or p.usuario = u.auth_uid)),
    'oportunidades', (select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'cliente_final', o.cliente_final, 'exclusiva_ate', o.exclusiva_ate, 'situacao', o.situacao) order by o.id desc), '[]')
          from ext.oportunidade o where o.contraparte = c.id),
    'pode', jsonb_build_object('aceite', u.perfil in ('gestor','fiscal'), 'oportunidade', c.tipo = 'parceiro',
          'adesao', c.tipo = 'cliente' and c.setor_publico, 'titular', true));
end $$;

-- pedido de fora vira cartão de uma pessoa do círculo dono, com prazo; o externo vê só a situação e a resposta
create or replace function ext.pedir(p_tipo text, p_assunto text, p_texto text, p_instancia bigint default null, p_cliente_final text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu(); c ext.contraparte; v_id bigint; v_raia text; v_motor smallint; v_prazo timestamptz; v_dono uuid; v_card bigint;
  v_chave text; v_conf ext.oportunidade; v_dias int;
begin
  select * into c from ext.contraparte where id = u.contraparte;
  if coalesce(length(trim(p_assunto)), 0) = 0 or coalesce(length(trim(p_texto)), 0) = 0 then raise exception 'informe o assunto e o texto'; end if;
  if length(p_texto) > 4000 then raise exception 'texto acima de 4000 caracteres'; end if;
  if p_instancia is not null and not exists (select 1 from ext.vinculo where instancia = p_instancia and contraparte = c.id) then
    raise exception 'referência não pertence a esta organização'; end if;
  if p_tipo in ('aceite', 'devolucao') then
    if u.perfil not in ('gestor', 'fiscal') then raise exception 'o aceite é de quem fiscaliza ou gere o contrato'; end if;
    if p_instancia is null or not exists (select 1 from ext.publicacao where instancia = p_instancia and contraparte = c.id and acao = 'aceite') then
      raise exception 'não há entrega aguardando aceite nesta referência'; end if;
    if exists (select 1 from ext.pedido where instancia = p_instancia and contraparte = c.id and tipo in ('aceite', 'devolucao') and situacao <> 'recusado') then
      raise exception 'esta entrega já tem aceite ou devolução registrados'; end if;
  end if;
  if p_tipo = 'oportunidade' and c.tipo <> 'parceiro' then raise exception 'registro de oportunidade é do parceiro'; end if;
  if p_tipo = 'adesao' and not (c.tipo = 'cliente' and c.setor_publico) then raise exception 'adesão à ata é para órgão público'; end if;
  if p_tipo = 'oportunidade' then
    if coalesce(length(trim(p_cliente_final)), 0) = 0 then raise exception 'informe o cliente final da oportunidade'; end if;
    v_chave := ext._norm(p_cliente_final) || ' | ' || ext._norm(p_assunto);
    update ext.oportunidade set situacao = 'expirada' where chave = v_chave and situacao in ('registrada', 'em_negociacao') and exclusiva_ate < current_date;
    select * into v_conf from ext.oportunidade where chave = v_chave and situacao in ('registrada', 'em_negociacao') and exclusiva_ate >= current_date limit 1;
    if found then raise exception 'oportunidade já registrada por outro canal, com exclusividade até %', to_char(v_conf.exclusiva_ate, 'DD/MM/YYYY'); end if;
  end if;
  case p_tipo
    when 'chamado' then v_raia := 'Operações · pessoa'; v_motor := 7;
    when 'aceite', 'devolucao' then v_raia := 'Operações · pessoa'; v_motor := 7;
    when 'oportunidade', 'adesao' then v_raia := 'Negócios · pessoa'; v_motor := 5;
    when 'titular' then v_raia := 'Governança · pessoa'; v_motor := 9;
    when 'duvida' then v_raia := 'Relações · pessoa'; v_motor := 4;
    else raise exception 'tipo de pedido desconhecido: %', p_tipo;
  end case;
  v_prazo := case p_tipo
    when 'titular' then now() + make_interval(days => (adm.valor('externo.prazo_titular_dias', '15') #>> '{}')::int)
    when 'aceite' then now() + make_interval(hours => (adm.valor('externo.prazo_aceite_horas', '24') #>> '{}')::int)
    when 'devolucao' then now() + make_interval(hours => (adm.valor('externo.prazo_aceite_horas', '24') #>> '{}')::int)
    else now() + make_interval(hours => (adm.valor('externo.prazo_resposta_horas', '48') #>> '{}')::int) end;
  v_dono := rt._pessoa(v_raia, v_motor);
  insert into ext.pedido (contraparte, usuario, tipo, instancia, assunto, texto, prazo)
  values (c.id, u.auth_uid, p_tipo, p_instancia, p_assunto, p_texto, v_prazo) returning id into v_id;
  v_card := rt.criar_avulsa(v_dono, left(case p_tipo when 'aceite' then 'Aceite do cliente' when 'devolucao' then 'Entrega devolvida pelo cliente'
        when 'oportunidade' then 'Oportunidade registrada pelo parceiro' when 'titular' then 'Pedido de titular de dados (LGPD)'
        when 'adesao' then 'Pedido de adesão à ata' when 'chamado' then 'Chamado do cliente' else 'Dúvida de fora' end || ': ' || p_assunto || ' · ' || c.nome, 200),
        v_prazo, null, 'externo', p_instancia);
  update ext.pedido set cartao = v_card where id = v_id;
  if p_tipo = 'oportunidade' then
    v_dias := (adm.valor('externo.exclusividade_dias', '90') #>> '{}')::int;
    insert into ext.oportunidade (pedido, contraparte, cliente_final, chave, exclusiva_ate) values (v_id, c.id, p_cliente_final, v_chave, current_date + v_dias);
  end if;
  if p_tipo in ('aceite', 'devolucao') then
    insert into ext.publicacao (contraparte, instancia, jornada, etapa, estado, mensagem, perfis, acao, em, simulado)
    select c.id, p_instancia, i.jornada, -1, case p_tipo when 'aceite' then 'Aceite registrado' else 'Entrega devolvida' end,
           case p_tipo when 'aceite' then 'Você registrou o aceite desta entrega.' else 'Você devolveu esta entrega: ' || left(p_texto, 300) end,
           '{gestor,fiscal}', null, now(), i.simulado from rt.instancia i where i.id = p_instancia
    on conflict (instancia, contraparte, etapa) do nothing;
  end if;
  return v_id;
end $$;

create or replace function ext.documento_pdf(p_emissao bigint) returns text language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  if not exists (select 1 from ext.documento where contraparte = u.contraparte and emissao = p_emissao and u.perfil = any (perfis)) then
    raise exception 'documento não publicado para você'; end if;
  return (select encode(conteudo, 'base64') from doc.arquivo where emissao = p_emissao and formato = 'pdf');
end $$;

-- lado de dentro: responder o pedido e publicar documento aprovado
create or replace function ext._interno(p_como uuid) returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then
    if not rt.chamada_servico() then raise exception 'sem identidade'; end if;
    v := p_como;
  end if;
  if v is null or not rt.pode(v, null, null, 'operar') then raise exception 'sem acesso para atender de fora'; end if;
  return v;
end $$;

drop function if exists ext.responder(bigint, text, text, uuid, text);
create or replace function ext._responder(p_pedido bigint, p_resposta text, p_situacao text, p_por text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_situacao not in ('em_atendimento', 'respondido', 'encerrado', 'recusado') then raise exception 'situação inválida'; end if;
  if coalesce(length(trim(p_resposta)), 0) = 0 then raise exception 'informe a resposta'; end if;
  update ext.pedido set resposta = p_resposta, situacao = p_situacao, respondido_por = p_por, atualizado_em = now() where id = p_pedido;
  if not found then raise exception 'pedido inexistente'; end if;
end $$;
-- pela pessoa de dentro, com acesso de operar na empresa da contraparte
create or replace function ext.responder(p_pedido bigint, p_resposta text, p_situacao text default 'respondido', p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); v_emp uuid;
begin
  select c.empresa into v_emp from ext.pedido p join ext.contraparte c on c.id = p.contraparte where p.id = p_pedido;
  if not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  perform ext._responder(p_pedido, p_resposta, p_situacao, (select papel from rt.pessoa where pseudonimo = v));
end $$;

create or replace function ext.publicar_documento(p_emissao bigint, p_contraparte uuid, p_perfis text[] default null, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); v_emp uuid;
begin
  select p.empresa into v_emp from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = p_emissao;
  if v_emp is null or v_emp is distinct from (select empresa from ext.contraparte where id = p_contraparte) then
    raise exception 'o documento e a contraparte são de empresas diferentes'; end if;
  if not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if (select t.alcance from doc.emissao e join doc.pedido p on p.id = e.pedido join doc.tipo t on t.id = p.tipo where e.id = p_emissao) is distinct from 'externo' then
    raise exception 'documento de uso interno não vai para fora'; end if;
  if (select p.situacao from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = p_emissao) is distinct from 'aprovado' then
    raise exception 'só documento aprovado em duas mãos vai para fora'; end if;
  if p_emissao <> (select max(e2.id) from doc.emissao e1 join doc.emissao e2 on e2.pedido = e1.pedido where e1.id = p_emissao) then
    raise exception 'há emissão mais nova deste documento'; end if;
  insert into ext.documento (contraparte, emissao, perfis, publicado_por) values (p_contraparte, p_emissao, coalesce(p_perfis, '{gestor,fiscal,financeiro,operacional}'), v)
  on conflict (contraparte, emissao) do nothing;
end $$;

-- protótipo: a página via MCP atua como um usuário externo simulado (só o serviço, só usuário simulado)
create or replace function ext._como(p_usuario uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só o serviço atua como outro usuário'; end if;
  if not exists (select 1 from ext.usuario where auth_uid = p_usuario and simulado) then raise exception 'só usuário externo simulado'; end if;
  perform set_config('request.jwt.claim.sub', p_usuario::text, true);
end $$;
create or replace function ext.portal_como(p_usuario uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.portal(); end $$;
create or replace function ext.pedir_como(p_usuario uuid, p_tipo text, p_assunto text, p_texto text, p_instancia bigint default null, p_cliente_final text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.pedir(p_tipo, p_assunto, p_texto, p_instancia, p_cliente_final); end $$;
create or replace function ext.documento_pdf_como(p_usuario uuid, p_emissao bigint) returns text language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.documento_pdf(p_emissao); end $$;
create or replace function ext.usuarios_simulados() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', u.auth_uid, 'nome', u.nome, 'perfil', u.perfil, 'contraparte', c.nome, 'tipo', c.tipo) order by c.tipo, c.nome, u.perfil), '[]')
    from ext.usuario u join ext.contraparte c on c.id = u.contraparte where u.simulado and u.ativo $$;

-- Dados do protótipo ---------------------------------------------------------------------------------------------------------------
insert into ext.empresa_marca values
 ('80d8f119-a3fc-40ce-afaa-34d974f25d31', 'onni'), ('9ce4812d-e39d-4fb3-bbda-a59a0f4aa897', 'tron'),
 ('8995fbb2-538c-43cf-94ff-f6b0c75f7c14', 'imts'), ('54d1ee0e-6ee3-4557-9a47-fdac1d7afc48', 'neutra')
on conflict (empresa) do nothing;

do $$ declare c1 uuid; c2 uuid; p1 uuid; p2 uuid;
begin
  if exists (select 1 from ext.contraparte where simulado) then return; end if;
  insert into ext.contraparte (empresa, tipo, nome, setor_publico, simulado) values ('80d8f119-a3fc-40ce-afaa-34d974f25d31', 'cliente', 'Secretaria Municipal de Saúde (simulada)', true, true) returning id into c1;
  insert into ext.contraparte (empresa, tipo, nome, setor_publico, simulado) values ('9ce4812d-e39d-4fb3-bbda-a59a0f4aa897', 'cliente', 'Secretaria Municipal de Educação (simulada)', true, true) returning id into c2;
  insert into ext.contraparte (empresa, tipo, nome, setor_publico, simulado) values ('80d8f119-a3fc-40ce-afaa-34d974f25d31', 'parceiro', 'Escritório regional de advocacia (simulado)', false, true) returning id into p1;
  insert into ext.contraparte (empresa, tipo, nome, setor_publico, simulado) values ('9ce4812d-e39d-4fb3-bbda-a59a0f4aa897', 'parceiro', 'Distribuidora parceira (simulada)', false, true) returning id into p2;
  insert into ext.usuario (auth_uid, contraparte, nome, perfil, simulado) values
   (gen_random_uuid(), c1, 'Secretária de saúde (simulada)', 'gestor', true), (gen_random_uuid(), c1, 'Fiscal do contrato (simulado)', 'fiscal', true),
   (gen_random_uuid(), c1, 'Setor financeiro (simulado)', 'financeiro', true), (gen_random_uuid(), c2, 'Secretário de educação (simulado)', 'gestor', true),
   (gen_random_uuid(), p1, 'Sócio do escritório (simulado)', 'gestor', true), (gen_random_uuid(), p1, 'Advogada operacional (simulada)', 'operacional', true),
   (gen_random_uuid(), p2, 'Gerente da distribuidora (simulado)', 'gestor', true);
end $$;

insert into ext.regra (jornada, etapa, tipo, estado, mensagem, perfis, acao) values
 ('NE-03', 1, 'cliente', 'Oportunidade recebida', 'Recebemos o seu pedido e estamos avaliando o atendimento.', '{gestor}', null),
 ('NE-03', 3, 'cliente', 'Proposta em elaboração', 'A proposta está sendo preparada para a sua necessidade.', '{gestor}', null),
 ('NE-03', 4, 'cliente', 'Proposta enviada', 'A proposta foi enviada e aguarda a sua resposta.', '{gestor}', null),
 ('NE-03', null, 'cliente', 'Proposta encerrada', 'O ciclo da proposta foi encerrado.', '{gestor}', null),
 ('NE-04', 1, 'cliente', 'Condições em negociação', 'As condições do contrato estão em negociação.', '{gestor}', null),
 ('NE-04', 3, 'cliente', 'Contrato em formalização', 'O contrato está em formalização e assinatura.', '{gestor,fiscal}', null),
 ('NE-04', null, 'cliente', 'Contrato formalizado', 'O contrato foi formalizado; a implantação será agendada com você.', '{gestor,fiscal}', null),
 ('OP-02', 1, 'cliente', 'Entrega em planejamento', 'O plano de entrega do ciclo está sendo montado.', '{gestor,fiscal}', null),
 ('OP-02', 2, 'cliente', 'Entregas em execução', 'As entregas do ciclo estão em execução.', '{gestor,fiscal}', null),
 ('OP-02', 3, 'cliente', 'Aguardando o seu aceite', 'A entrega está pronta para a sua conferência e aceite.', '{gestor,fiscal}', 'aceite'),
 ('OP-02', null, 'cliente', 'Ciclo de entrega encerrado', 'O ciclo de entrega foi encerrado.', '{gestor,fiscal}', null),
 ('GE-03', 2, 'cliente', 'Fatura emitida', 'A fatura do período foi emitida.', '{gestor,financeiro}', null),
 ('GE-03', 3, 'cliente', 'Pagamento em aberto', 'A fatura está em aberto até a confirmação do pagamento.', '{gestor,financeiro}', null),
 ('GE-03', null, 'cliente', 'Faturamento do período encerrado', 'O faturamento do período foi encerrado.', '{gestor,financeiro}', null),
 ('RE-05', 1, 'cliente', 'Plano de sucesso em combinação', 'Estamos combinando com você os resultados esperados e os marcos.', '{gestor}', null),
 ('RE-05', 3, 'cliente', 'Apresentação de resultados', 'Os resultados do período serão apresentados a você.', '{gestor}', null),
 ('RE-05', 4, 'cliente', 'Próximo passo em decisão', 'Vamos decidir com você o próximo passo.', '{gestor}', null),
 ('NE-06', 2, 'cliente', 'Renovação ou aditivo em negociação', 'A renovação ou o aditivo do contrato está em negociação.', '{gestor,fiscal}', null),
 ('NE-06', 4, 'cliente', 'Renovação ou aditivo em formalização', 'A renovação ou o aditivo está em formalização.', '{gestor,fiscal}', null),
 ('NE-06', null, 'cliente', 'Renovação ou aditivo concluído', 'O ciclo de renovação ou aditivo foi concluído.', '{gestor,fiscal}', null),
 ('NE-07', 1, 'parceiro', 'Oportunidade recebida', 'Recebemos a oportunidade e estamos avaliando.', '{gestor,operacional}', null),
 ('NE-07', 2, 'parceiro', 'Oferta conjunta em montagem', 'A oferta conjunta e a divisão estão sendo montadas.', '{gestor}', null),
 ('NE-07', 3, 'parceiro', 'Resultado em medição', 'O resultado da venda conjunta está em medição.', '{gestor}', null),
 ('NE-07', null, 'parceiro', 'Oportunidade encerrada', 'O ciclo desta oportunidade foi encerrado.', '{gestor,operacional}', null),
 ('RE-06', 1, 'parceiro', 'Parceria em avaliação', 'O pedido de parceria está em avaliação.', '{gestor}', null),
 ('RE-06', 2, 'parceiro', 'Parceria em formalização', 'A parceria está em negociação e formalização.', '{gestor}', null),
 ('RE-06', 3, 'parceiro', 'Parceria ativa', 'A parceria está ativa.', '{gestor,operacional}', null),
 ('RE-06', 4, 'parceiro', 'Revisão da parceria', 'A parceria está em revisão periódica.', '{gestor}', null),
 ('RE-06', 5, 'parceiro', 'Uso da marca em decisão', 'O pedido de uso da marca está em decisão.', '{gestor}', null),
 ('RE-06', null, 'parceiro', 'Ciclo da parceria concluído', 'O ciclo da parceria foi concluído.', '{gestor,operacional}', null)
on conflict (jornada, etapa, tipo) do nothing;

insert into ext.jornada_externa values ('NE-03', 'Proposta'), ('NE-04', 'Contratação'), ('OP-02', 'Entregas'), ('GE-03', 'Faturamento'),
 ('RE-05', 'Acompanhamento de resultados'), ('NE-06', 'Renovação e aditivos'), ('NE-07', 'Oportunidade conjunta'), ('RE-06', 'Parceria')
on conflict (jornada) do update set titulo = excluded.titulo;

do $$ begin
  if not exists (select 1 from cron.job where jobname = 'imts-externo-simulado') then
    perform cron.schedule('imts-externo-simulado', '*/10 * * * *', 'select ext.vincular_simulados(40);');
  end if;
end $$;

-- Segurança ------------------------------------------------------------------------------------------------------------------------
do $$ declare t text; begin
  foreach t in array array['empresa_marca','jornada_externa','contraparte','usuario','regra','vinculo','publicacao','documento','pedido','oportunidade'] loop
    execute format('alter table ext.%I enable row level security', t);
    execute format('drop policy if exists leitura on ext.%I', t);
  end loop;
end $$;
-- de dentro: só quem lê na empresa da contraparte (auditoria de 04/10/2026: antes valia ler em qualquer empresa)
create or replace function ext._le(p_contraparte uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select rt.eu() is not null and rt.pode(rt.eu(), (select empresa from ext.contraparte where id = p_contraparte), null, 'ler') $$;
-- de fora: só o que é da própria contraparte e do próprio perfil; de dentro: quem lê na empresa da contraparte
create policy leitura on ext.contraparte for select to authenticated using (id = (ext.eu()).contraparte or ext._le(id));
create policy leitura on ext.publicacao for select to authenticated using ((contraparte = (ext.eu()).contraparte and (ext.eu()).perfil = any (perfis)) or ext._le(contraparte));
create policy leitura on ext.pedido for select to authenticated using ((contraparte = (ext.eu()).contraparte and ((ext.eu()).perfil = 'gestor' or usuario = auth.uid())) or ext._le(contraparte));
create policy leitura on ext.oportunidade for select to authenticated using (contraparte = (ext.eu()).contraparte or ext._le(contraparte));
create policy leitura on ext.documento for select to authenticated using ((contraparte = (ext.eu()).contraparte and (ext.eu()).perfil = any (perfis)) or ext._le(contraparte));
create policy leitura on ext.regra for select to authenticated using (rt.pode(rt.eu(), null, null, 'ler'));
create policy leitura on ext.vinculo for select to authenticated using (ext._le(contraparte));
create policy leitura on ext.usuario for select to authenticated using (auth_uid = auth.uid() or rt.pode_estrito(rt.eu(), null, null, 'administrar'));
create policy leitura on ext.empresa_marca for select to authenticated using (true);
create policy leitura on ext.jornada_externa for select to authenticated using (true);
grant select on all tables in schema ext to authenticated;
grant all on all tables in schema ext to service_role;
revoke all on all functions in schema ext from public;
grant execute on function ext.portal(), ext.pedir(text, text, text, bigint, text), ext.documento_pdf(bigint), ext.eu(),
  ext.responder(bigint, text, text, uuid), ext.publicar_documento(bigint, uuid, text[], uuid) to authenticated, service_role;
grant execute on function ext.projetar(bigint), ext.vincular(bigint, uuid), ext.vincular_simulados(int), ext.portal_como(uuid),
  ext.pedir_como(uuid, text, text, text, bigint, text), ext.documento_pdf_como(uuid, bigint), ext.usuarios_simulados() to service_role;
commit;
