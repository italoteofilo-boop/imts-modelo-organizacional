-- E20 · Atendimento ao cliente (aprovado por Ítalo em 04/10/2026, "Prossiga").
-- SAC é o canal (chamado, dúvida, reclamação, ordem de serviço); a ouvidoria é independente, da Governança, e pode ser anônima.
-- Cada demanda vira encaminhamentos datados, com responsável e prazo, que o cliente acompanha. Encerrar exige todos os
-- encaminhamentos fechados e a confirmação do cliente, ou o aceite tácito depois do prazo do parâmetro.
begin;

alter table ext.pedido drop constraint if exists pedido_tipo_check;
alter table ext.pedido add constraint pedido_tipo_check
  check (tipo in ('chamado', 'aceite', 'devolucao', 'oportunidade', 'titular', 'adesao', 'duvida', 'reclamacao', 'os', 'ouvidoria'));
alter table ext.pedido add column if not exists anonimo boolean not null default false,
  add column if not exists confirmar_ate timestamptz, add column if not exists encerrado_como text check (encerrado_como in ('confirmado', 'tacito')),
  add column if not exists avaliacao smallint check (avaliacao between 1 and 5), add column if not exists comentario text,
  add column if not exists reaberturas int not null default 0, add column if not exists encerrado_em timestamptz;
alter table ext.pedido drop constraint if exists pedido_anonimo_check;
alter table ext.pedido add constraint pedido_anonimo_check check (not anonimo or tipo = 'ouvidoria');

insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('atendimento.aceite_tacito_dias', 'global', 'Dias para o cliente confirmar o encerramento; depois disso o atendimento se encerra por aceite tácito', 'inteiro', '5', '5', '{"min":1,"max":30}', false, '{}', 'E20, 04/10/2026; valor a confirmar por Relações'),
 ('atendimento.prazo_os_horas', 'global', 'Prazo para a primeira resposta a uma ordem de serviço', 'inteiro', '72', '72', '{"min":4,"max":720}', false, '{}', 'E20, 04/10/2026; valor a confirmar por Operações'),
 ('atendimento.prazo_ouvidoria_dias', 'global', 'Prazo para a ouvidoria responder a manifestação', 'inteiro', '10', '10', '{"min":1,"max":30}', true, '{}', 'E20, 04/10/2026; valor a confirmar pela Governança')
on conflict (chave) do nothing;

create table if not exists ext.encaminhamento (
  id bigint generated always as identity primary key,
  pedido bigint not null references ext.pedido(id),
  descricao text not null check (length(btrim(descricao)) between 3 and 1000),
  responsavel uuid not null,
  prazo timestamptz not null,
  situacao text not null default 'aberto' check (situacao in ('aberto', 'concluido', 'cancelado')),
  conclusao text,
  cartao bigint,
  origem text not null default 'central' check (origem in ('central', 'reuniao')),
  reuniao bigint,
  criado_por uuid not null,
  criado_em timestamptz not null default now(),
  concluido_por uuid,
  concluido_em timestamptz
);
create index if not exists encaminhamento_pedido on ext.encaminhamento (pedido);

-- ouvidoria: dentro, só a Governança lê; fora, só quem escreveu
create or replace function ext._le_ouvidoria(p_contraparte uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select rt.eu() is not null and rt.pode(rt.eu(), (select empresa from ext.contraparte where id = p_contraparte), 9::smallint, 'ler') $$;
drop policy if exists leitura on ext.pedido;
create policy leitura on ext.pedido for select to authenticated using (
  (contraparte = (ext.eu()).contraparte and (usuario = auth.uid() or ((ext.eu()).perfil = 'gestor' and tipo <> 'ouvidoria')))
  or (ext._le(contraparte) and (tipo <> 'ouvidoria' or ext._le_ouvidoria(contraparte))));
alter table ext.encaminhamento enable row level security;
drop policy if exists leitura on ext.encaminhamento;
create policy leitura on ext.encaminhamento for select to authenticated
  using (exists (select 1 from ext.pedido p where p.id = pedido));   -- herda a regra do pedido (a política de ext.pedido vale dentro do exists)
grant select on ext.encaminhamento to authenticated; grant all on ext.encaminhamento to service_role;

-- o pedido de fora: mesmo núcleo para todos os tipos; ouvidoria pode ser anônima
create or replace function ext._pedir(u ext.usuario, p_tipo text, p_assunto text, p_texto text, p_instancia bigint, p_cliente_final text, p_anonimo boolean) returns bigint
language plpgsql security definer set search_path = '' as $$
declare c ext.contraparte; v_id bigint; v_raia text; v_motor smallint; v_prazo timestamptz; v_dono uuid; v_card bigint;
  v_chave text; v_conf ext.oportunidade; v_dias int;
begin
  select * into c from ext.contraparte where id = u.contraparte;
  if coalesce(length(trim(p_assunto)), 0) = 0 or coalesce(length(trim(p_texto)), 0) = 0 then raise exception 'informe o assunto e o texto'; end if;
  if length(p_texto) > 4000 then raise exception 'texto acima de 4000 caracteres'; end if;
  if coalesce(p_anonimo, false) and p_tipo <> 'ouvidoria' then raise exception 'só a manifestação de ouvidoria pode ser anônima'; end if;
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
  if p_tipo = 'os' and c.tipo <> 'cliente' then raise exception 'ordem de serviço é do cliente'; end if;
  if p_tipo = 'oportunidade' then
    if coalesce(length(trim(p_cliente_final)), 0) = 0 then raise exception 'informe o cliente final da oportunidade'; end if;
    v_chave := ext._norm(p_cliente_final) || ' | ' || ext._norm(p_assunto);
    update ext.oportunidade set situacao = 'expirada' where chave = v_chave and situacao in ('registrada', 'em_negociacao') and exclusiva_ate < current_date;
    select * into v_conf from ext.oportunidade where chave = v_chave and situacao in ('registrada', 'em_negociacao') and exclusiva_ate >= current_date limit 1;
    if found then raise exception 'oportunidade já registrada por outro canal, com exclusividade até %', to_char(v_conf.exclusiva_ate, 'DD/MM/YYYY'); end if;
  end if;
  case p_tipo
    when 'chamado', 'aceite', 'devolucao', 'reclamacao', 'os' then v_raia := 'Operações · pessoa'; v_motor := 7;
    when 'oportunidade', 'adesao' then v_raia := 'Negócios · pessoa'; v_motor := 5;
    when 'titular', 'ouvidoria' then v_raia := 'Governança · pessoa'; v_motor := 9;
    when 'duvida' then v_raia := 'Relações · pessoa'; v_motor := 4;
    else raise exception 'tipo de pedido desconhecido: %', p_tipo;
  end case;
  v_prazo := case p_tipo
    when 'titular' then now() + make_interval(days => (adm.valor('externo.prazo_titular_dias', '15') #>> '{}')::int)
    when 'ouvidoria' then now() + make_interval(days => (adm.valor('atendimento.prazo_ouvidoria_dias', '10') #>> '{}')::int)
    when 'os' then now() + make_interval(hours => (adm.valor('atendimento.prazo_os_horas', '72') #>> '{}')::int)
    when 'aceite' then now() + make_interval(hours => (adm.valor('externo.prazo_aceite_horas', '24') #>> '{}')::int)
    when 'devolucao' then now() + make_interval(hours => (adm.valor('externo.prazo_aceite_horas', '24') #>> '{}')::int)
    else now() + make_interval(hours => (adm.valor('externo.prazo_resposta_horas', '48') #>> '{}')::int) end;
  v_dono := rt._pessoa(v_raia, v_motor);
  insert into ext.pedido (contraparte, usuario, tipo, instancia, assunto, texto, prazo, anonimo)
  values (c.id, u.auth_uid, p_tipo, p_instancia, p_assunto, p_texto, v_prazo, coalesce(p_anonimo, false)) returning id into v_id;
  v_card := rt.criar_avulsa(v_dono, left(case p_tipo when 'aceite' then 'Aceite do cliente' when 'devolucao' then 'Entrega devolvida pelo cliente'
        when 'oportunidade' then 'Oportunidade registrada pelo parceiro' when 'titular' then 'Pedido de titular de dados (LGPD)'
        when 'adesao' then 'Pedido de adesão à ata' when 'chamado' then 'Chamado do cliente' when 'reclamacao' then 'Reclamação (OP-04)'
        when 'os' then 'Ordem de serviço do cliente' when 'ouvidoria' then 'Manifestação de ouvidoria' else 'Dúvida de fora' end
        || ': ' || p_assunto || case when coalesce(p_anonimo, false) then ' · anônima' else ' · ' || c.nome end, 200),
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

create or replace function ext.pedir(p_tipo text, p_assunto text, p_texto text, p_instancia bigint default null, p_cliente_final text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
begin return ext._pedir(ext._exigir_eu(), p_tipo, p_assunto, p_texto, p_instancia, p_cliente_final, false); end $$;
create or replace function ext.ouvidoria(p_assunto text, p_texto text, p_anonimo boolean default false) returns bigint
language plpgsql security definer set search_path = '' as $$
begin return ext._pedir(ext._exigir_eu(), 'ouvidoria', p_assunto, p_texto, null, null, p_anonimo); end $$;

-- resposta de dentro: nas demandas de atendimento, "respondido" é a proposta de encerramento (exige encaminhamentos fechados);
-- "encerrado" só pelo cliente ou pelo aceite tácito
create or replace function ext._responder(p_pedido bigint, p_resposta text, p_situacao text, p_por text) returns void
language plpgsql security definer set search_path = '' as $$
declare p ext.pedido;
begin
  if p_situacao not in ('em_atendimento', 'respondido', 'encerrado', 'recusado') then raise exception 'situação inválida'; end if;
  if coalesce(length(trim(p_resposta)), 0) = 0 then raise exception 'informe a resposta'; end if;
  select * into p from ext.pedido where id = p_pedido for update;
  if p.id is null then raise exception 'pedido inexistente'; end if;
  if p.situacao = 'encerrado' then raise exception 'pedido encerrado'; end if;
  if p.tipo in ('chamado', 'reclamacao', 'os', 'ouvidoria', 'duvida') then
    if p_situacao = 'encerrado' then raise exception 'quem encerra é o cliente (ou o aceite tácito): responda com a proposta de encerramento'; end if;
    if p_situacao = 'respondido' and exists (select 1 from ext.encaminhamento where pedido = p.id and situacao = 'aberto') then
      raise exception 'há encaminhamentos abertos: conclua ou cancele antes de propor o encerramento'; end if;
  end if;
  update ext.pedido set resposta = p_resposta, situacao = p_situacao, respondido_por = p_por, atualizado_em = now(),
         confirmar_ate = case when p_situacao = 'respondido' and p.tipo in ('chamado', 'reclamacao', 'os', 'ouvidoria', 'duvida')
                              then now() + make_interval(days => (adm.valor('atendimento.aceite_tacito_dias', '5') #>> '{}')::int) end
   where id = p.id;
  if p_situacao = 'respondido' then perform ext._avisar(p.contraparte, 'Pedido ' || p.id || ' respondido: confirme o encerramento no portal ou reabra.', '{gestor,fiscal,financeiro,operacional}'); end if;
end $$;
-- ouvidoria só a Governança responde
create or replace function ext.responder(p_pedido bigint, p_resposta text, p_situacao text default 'respondido', p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); v_emp uuid; v_tipo text;
begin
  select c.empresa, p.tipo into v_emp, v_tipo from ext.pedido p join ext.contraparte c on c.id = p.contraparte where p.id = p_pedido;
  if not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if v_tipo = 'ouvidoria' and not rt.pode(v, v_emp, 9::smallint, 'operar') then raise exception 'a ouvidoria é respondida pela Governança'; end if;
  perform ext._responder(p_pedido, p_resposta, p_situacao, (select papel from rt.pessoa where pseudonimo = v));
end $$;

-- encaminhamentos
create or replace function ext.encaminhar(p_pedido bigint, p_descricao text, p_responsavel uuid, p_prazo timestamptz, p_como uuid default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); p ext.pedido; v_emp uuid; v_id bigint; v_card bigint;
begin
  select * into p from ext.pedido where id = p_pedido for update;
  if p.id is null then raise exception 'pedido inexistente'; end if;
  v_emp := (select empresa from ext.contraparte where id = p.contraparte);
  if not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if p.tipo = 'ouvidoria' and not rt.pode(v, v_emp, 9::smallint, 'operar') then raise exception 'a ouvidoria é conduzida pela Governança'; end if;
  if p.tipo not in ('chamado', 'reclamacao', 'os', 'ouvidoria', 'duvida') then raise exception 'encaminhamento é para demandas de atendimento'; end if;
  if p.situacao in ('encerrado', 'recusado') then raise exception 'pedido %', p.situacao; end if;
  if not exists (select 1 from rt.pessoa where pseudonimo = p_responsavel and circulo is not null) then raise exception 'responsável precisa ser pessoa de um círculo'; end if;
  if p_prazo is null or p_prazo <= now() then raise exception 'o prazo precisa ser futuro'; end if;
  insert into ext.encaminhamento (pedido, descricao, responsavel, prazo, criado_por) values (p.id, btrim(p_descricao), p_responsavel, p_prazo, v) returning id into v_id;
  v_card := rt.criar_avulsa(p_responsavel, left('Encaminhamento do pedido ' || p.id || ': ' || btrim(p_descricao), 200), p_prazo, null, 'externo', null);
  update rt.cartao set empresa = v_emp where id = v_card;
  update ext.encaminhamento set cartao = v_card where id = v_id;
  update ext.pedido set situacao = case when situacao in ('recebido', 'respondido') then 'em_atendimento' else situacao end, confirmar_ate = null, atualizado_em = now() where id = p.id;
  return v_id;
end $$;

create or replace function ext.encaminhamento_concluir(p_encaminhamento bigint, p_situacao text, p_conclusao text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); e ext.encaminhamento; v_emp uuid; v_tipo text;
begin
  select * into e from ext.encaminhamento where id = p_encaminhamento for update;
  if e.id is null then raise exception 'encaminhamento inexistente'; end if;
  select c.empresa, p.tipo into v_emp, v_tipo from ext.pedido p join ext.contraparte c on c.id = p.contraparte where p.id = e.pedido;
  if not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if v_tipo = 'ouvidoria' and not rt.pode(v, v_emp, 9::smallint, 'operar') then raise exception 'a ouvidoria é conduzida pela Governança'; end if;
  if e.situacao <> 'aberto' then raise exception 'encaminhamento já %', e.situacao; end if;
  if p_situacao not in ('concluido', 'cancelado') then raise exception 'situação inválida'; end if;
  if coalesce(length(btrim(p_conclusao)), 0) = 0 then raise exception 'diga o que foi feito ou por que cancelou'; end if;
  update ext.encaminhamento set situacao = p_situacao, conclusao = btrim(p_conclusao), concluido_por = v, concluido_em = now() where id = e.id;
  perform ext._fechar_cartao(e.cartao);
  update ext.pedido set atualizado_em = now() where id = e.pedido;
end $$;

-- o cliente confirma o encerramento (com avaliação opcional) ou reabre com motivo
create or replace function ext._dono_do_pedido(p_pedido bigint) returns ext.pedido language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu(); p ext.pedido;
begin
  select * into p from ext.pedido where id = p_pedido;
  if p.id is null or p.contraparte <> u.contraparte or not (p.usuario = u.auth_uid or (u.perfil = 'gestor' and p.tipo <> 'ouvidoria')) then raise exception 'pedido não é seu'; end if;
  return p;
end $$;
create or replace function ext.atendimento_confirmar(p_pedido bigint, p_avaliacao smallint default null, p_comentario text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare p ext.pedido := ext._dono_do_pedido(p_pedido);
begin
  if p.situacao <> 'respondido' or p.confirmar_ate is null then raise exception 'não há proposta de encerramento para confirmar'; end if;
  update ext.pedido set situacao = 'encerrado', encerrado_como = 'confirmado', encerrado_em = now(), avaliacao = p_avaliacao, comentario = nullif(btrim(p_comentario), ''), atualizado_em = now() where id = p.id;
  perform ext._fechar_cartao(p.cartao);
end $$;
create or replace function ext.atendimento_reabrir(p_pedido bigint, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare p ext.pedido := ext._dono_do_pedido(p_pedido); v_card bigint;
begin
  if p.situacao <> 'respondido' or p.confirmar_ate is null then raise exception 'só se reabre o que foi proposto para encerrar e ainda não encerrou'; end if;
  if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'diga o que faltou'; end if;
  perform ext._fechar_cartao(p.cartao);
  v_card := ext._cartao(case p.tipo when 'ouvidoria' then 'Governança · pessoa' when 'duvida' then 'Relações · pessoa' else 'Operações · pessoa' end,
                        case p.tipo when 'ouvidoria' then 9 when 'duvida' then 4 else 7 end::smallint,
                        'Reaberto pelo cliente: ' || p.assunto || ' · ' || left(btrim(p_motivo), 80),
                        now() + make_interval(hours => (adm.valor('externo.prazo_resposta_horas', '48') #>> '{}')::int), (select empresa from ext.contraparte where id = p.contraparte));
  update ext.pedido set situacao = 'em_atendimento', confirmar_ate = null, reaberturas = reaberturas + 1, cartao = v_card, atualizado_em = now(),
         comentario = 'Reaberto: ' || btrim(p_motivo) where id = p.id;
end $$;
-- aceite tácito: depois do prazo, encerra (rotina de hora em hora)
create or replace function ext.encerrar_tacitos() returns int language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  for r in select id, cartao from ext.pedido where situacao = 'respondido' and confirmar_ate is not null and confirmar_ate < now() for update skip locked loop
    update ext.pedido set situacao = 'encerrado', encerrado_como = 'tacito', encerrado_em = now(), atualizado_em = now() where id = r.id;
    perform ext._fechar_cartao(r.cartao);
    n := n + 1;
  end loop;
  return n;
end $$;
select cron.schedule('imts-atendimento-tacito', '23 * * * *', 'select ext.encerrar_tacitos()');

-- o portal: ouvidoria só para quem escreveu; atendimento com encaminhamentos datados
create or replace function ext.portal() returns jsonb language plpgsql stable security definer set search_path = '' as $function$
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
          'prazo', p.prazo, 'criado_em', p.criado_em, 'atualizado_em', p.atualizado_em, 'anonimo', p.anonimo, 'meu', p.usuario = u.auth_uid,
          'confirmar_ate', p.confirmar_ate, 'encerrado_como', p.encerrado_como, 'encerrado_em', p.encerrado_em, 'avaliacao', p.avaliacao, 'reaberturas', p.reaberturas,
          'encaminhamentos', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'descricao', e.descricao, 'area', split_part(r.papel, ' · ', 1), 'prazo', e.prazo,
               'situacao', e.situacao, 'conclusao', e.conclusao, 'criado_em', e.criado_em, 'concluido_em', e.concluido_em) order by e.id), '[]')
               from ext.encaminhamento e left join rt.pessoa r on r.pseudonimo = e.responsavel where e.pedido = p.id)) order by p.id desc), '[]')
          from ext.pedido p where p.contraparte = c.id and (p.usuario = u.auth_uid or (u.perfil = 'gestor' and p.tipo <> 'ouvidoria'))),
    'oportunidades', (select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'cliente_final', o.cliente_final, 'exclusiva_ate', o.exclusiva_ate, 'situacao', o.situacao) order by o.id desc), '[]')
          from ext.oportunidade o where o.contraparte = c.id),
    'telegram', (select jsonb_build_object('vinculado', vinculado_em is not null, 'desde', vinculado_em) from ext.telegram where auth_uid = u.auth_uid),
    'pode', jsonb_build_object('aceite', u.perfil in ('gestor','fiscal'), 'oportunidade', c.tipo = 'parceiro',
          'adesao', c.tipo = 'cliente' and c.setor_publico, 'titular', true, 'os', c.tipo = 'cliente', 'reclamacao', true, 'ouvidoria', true));
end $function$;

-- Central de atendimento (lado de dentro)
create or replace function ext.painel_atendimento(p_empresa uuid, p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu(); gov boolean;
begin
  if v is null then if not rt.chamada_servico() then raise exception 'sem identidade'; end if; v := p_como; end if;
  if v is null or not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso de leitura nesta empresa'; end if;
  gov := rt.pode(v, p_empresa, 9::smallint, 'ler');
  return jsonb_build_object(
    've_ouvidoria', gov,
    'pedidos', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'tipo', p.tipo, 'assunto', p.assunto, 'texto', p.texto, 'situacao', p.situacao, 'resposta', p.resposta,
        'prazo', p.prazo, 'criado_em', p.criado_em, 'atualizado_em', p.atualizado_em, 'anonimo', p.anonimo,
        'contraparte', case when p.anonimo then 'anônima' else c.nome end, 'quem', case when p.anonimo then null else u.nome || ' (' || u.perfil || ')' end,
        'confirmar_ate', p.confirmar_ate, 'encerrado_como', p.encerrado_como, 'encerrado_em', p.encerrado_em, 'avaliacao', p.avaliacao, 'comentario', p.comentario, 'reaberturas', p.reaberturas,
        'atrasado', p.situacao in ('recebido', 'em_atendimento') and p.prazo < now(),
        'encaminhamentos', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'descricao', e.descricao, 'responsavel', r.papel, 'prazo', e.prazo, 'situacao', e.situacao,
             'conclusao', e.conclusao, 'origem', e.origem, 'criado_em', e.criado_em, 'concluido_em', e.concluido_em, 'atrasado', e.situacao = 'aberto' and e.prazo < now()) order by e.id), '[]')
             from ext.encaminhamento e left join rt.pessoa r on r.pseudonimo = e.responsavel where e.pedido = p.id)) order by (p.situacao in ('encerrado', 'recusado')), p.prazo), '[]')
        from ext.pedido p join ext.contraparte c on c.id = p.contraparte left join ext.usuario u on u.auth_uid = p.usuario
       where c.empresa = p_empresa and p.tipo in ('chamado', 'reclamacao', 'os', 'ouvidoria', 'duvida', 'titular', 'adesao', 'devolucao')
         and (p.tipo <> 'ouvidoria' or gov)),
    'responsaveis', (select coalesce(jsonb_agg(jsonb_build_object('pessoa', pseudonimo, 'papel', papel, 'circulo', circulo) order by circulo, papel), '[]')
        from rt.pessoa where circulo is not null and papel like '%· pessoa'));
end $$;

-- protótipo: o portal atua como usuário externo simulado (só o serviço)
create or replace function ext.ouvidoria_como(p_usuario uuid, p_assunto text, p_texto text, p_anonimo boolean) returns bigint language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.ouvidoria(p_assunto, p_texto, p_anonimo); end $$;
create or replace function ext.atendimento_confirmar_como(p_usuario uuid, p_pedido bigint, p_avaliacao smallint, p_comentario text) returns void language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); perform ext.atendimento_confirmar(p_pedido, p_avaliacao, p_comentario); end $$;
create or replace function ext.atendimento_reabrir_como(p_usuario uuid, p_pedido bigint, p_motivo text) returns void language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); perform ext.atendimento_reabrir(p_pedido, p_motivo); end $$;

revoke all on function ext._le_ouvidoria(uuid), ext._pedir(ext.usuario, text, text, text, bigint, text, boolean), ext.ouvidoria(text, text, boolean), ext.encaminhar(bigint, text, uuid, timestamptz, uuid),
  ext.encaminhamento_concluir(bigint, text, text, uuid), ext._dono_do_pedido(bigint), ext.atendimento_confirmar(bigint, smallint, text), ext.atendimento_reabrir(bigint, text),
  ext.encerrar_tacitos(), ext.painel_atendimento(uuid, uuid), ext.ouvidoria_como(uuid, text, text, boolean), ext.atendimento_confirmar_como(uuid, bigint, smallint, text),
  ext.atendimento_reabrir_como(uuid, bigint, text) from public, anon, authenticated;
grant execute on function ext._le_ouvidoria(uuid), ext.ouvidoria(text, text, boolean), ext.encaminhar(bigint, text, uuid, timestamptz, uuid), ext.encaminhamento_concluir(bigint, text, text, uuid),
  ext.atendimento_confirmar(bigint, smallint, text), ext.atendimento_reabrir(bigint, text), ext.painel_atendimento(uuid, uuid) to authenticated;
grant execute on function ext.ouvidoria(text, text, boolean), ext.encaminhar(bigint, text, uuid, timestamptz, uuid), ext.encaminhamento_concluir(bigint, text, text, uuid),
  ext.atendimento_confirmar(bigint, smallint, text), ext.atendimento_reabrir(bigint, text), ext.encerrar_tacitos(), ext.painel_atendimento(uuid, uuid),
  ext.ouvidoria_como(uuid, text, text, boolean), ext.atendimento_confirmar_como(uuid, bigint, smallint, text), ext.atendimento_reabrir_como(uuid, bigint, text) to service_role;
commit;
