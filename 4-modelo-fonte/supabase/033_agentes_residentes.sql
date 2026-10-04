-- E15 · Agentes residentes (aprovado por Ítalo em 04/10/2026, às 10:13). O padrão dos dots da OpenAI (responsabilidade contínua, gatilhos,
-- memória própria, aprovações) dentro do nosso motor: cada agente tem dono humano, círculo, modo, orçamento de ações, memória legível e
-- editável, execuções auditadas e botão de desligar. Toda ação passa pelas funções do motor (cartão, resposta ao externo), como a de uma pessoa.
-- O comportamento é por regra (provedor "regra"); o provedor de modelo de linguagem entra como parâmetro quando for escolhido.
begin;
create table if not exists rt.agente_residente (
  codigo text primary key check (codigo ~ '^[a-z0-9-]+$'), nome text not null, dono uuid not null references rt.pessoa(pseudonimo),
  circulo smallint references org.circulo(numero), responsabilidade text not null,
  comportamento text not null check (comportamento in ('vigia_prazos', 'vigia_vencimentos', 'atendente_externo')),
  parametros jsonb not null default '{}', intervalo_minutos int not null check (intervalo_minutos between 5 and 1440),
  modo org.modo not null, orcamento_acoes_mes int not null check (orcamento_acoes_mes > 0),
  ligado boolean not null default true, liberado boolean not null default false, liberado_por text, provedor text not null default 'regra',
  ultima_execucao timestamptz, criado_em timestamptz not null default now());

create table if not exists rt.agente_memoria (
  id bigint generated always as identity primary key, agente text not null references rt.agente_residente(codigo),
  chave text, nota text not null, fonte text not null, autor text not null check (autor in ('agente', 'pessoa')),
  ativa boolean not null default true, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create unique index if not exists agente_memoria_chave on rt.agente_memoria (agente, chave) where chave is not null;

create table if not exists rt.agente_execucao (
  id bigint generated always as identity primary key, agente text not null references rt.agente_residente(codigo),
  gatilho text not null check (gatilho in ('agenda', 'manual', 'teste')), inicio timestamptz not null default now(), fim timestamptz,
  situacao text not null check (situacao in ('ok', 'sem_acao', 'bloqueada', 'desligada', 'erro')), n_acoes int not null default 0,
  acoes jsonb not null default '[]', detalhe text);
create index if not exists agente_execucao_mes on rt.agente_execucao (agente, inicio desc);

alter table adm.historico drop constraint if exists historico_objeto_check;
alter table adm.historico add constraint historico_objeto_check check (objeto in ('parametro', 'conexao', 'agente'));

insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('agentes.ligados', 'global', 'Chave geral dos agentes residentes: desligada, nenhum agente age', 'booleano', 'true', 'true', '{}', true, '{}', 'E15, 04/10/2026'),
 ('agentes.acoes_por_execucao', 'global', 'Máximo de ações de um agente numa execução', 'inteiro', '10', '10', '{"min":1,"max":100}', false, '{}', 'E15, 04/10/2026')
on conflict (chave) do nothing;

-- memória com chave: o agente não repete o que já fez
create or replace function rt._agente_lembra(a text, k text) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from rt.agente_memoria where agente = a and chave = k and ativa) $$;
create or replace function rt._agente_anota(a text, k text, n text, f text) returns void language sql set search_path = '' as $$
  insert into rt.agente_memoria (agente, chave, nota, fonte, autor) values (a, k, n, f, 'agente')
  on conflict (agente, chave) where chave is not null do update set nota = excluded.nota, ativa = true, atualizado_em = now() $$;

create or replace function rt.agente_executar(p_codigo text, p_gatilho text default 'manual') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a rt.agente_residente; acoes jsonb := '[]'; n int := 0; v_max int; usadas int; sit text; det text; r record; v_card bigint; k text; v_exec bigint;
  nivel int; v_texto text;
begin
  select * into a from rt.agente_residente where codigo = p_codigo for update;
  if not found then raise exception 'agente desconhecido: %', p_codigo; end if;
  v_max := (adm.valor('agentes.acoes_por_execucao', '10') #>> '{}')::int;
  nivel := case a.modo::text when 'Assistido' then 1 when 'Copiloto' then 2 else 3 end;
  select coalesce(sum(n_acoes), 0) into usadas from rt.agente_execucao where agente = a.codigo and inicio >= date_trunc('month', now());
  if not (adm.valor('agentes.ligados', 'true') #>> '{}')::boolean or not a.ligado then sit := 'desligada'; det := 'agente ou chave geral desligados';
  elsif not a.liberado then sit := 'bloqueada'; det := 'aguarda liberação pela IT-06';
  elsif usadas >= a.orcamento_acoes_mes then
    sit := 'bloqueada'; det := 'orçamento de ações do mês esgotado';
    k := 'orcamento:' || to_char(now(), 'YYYY-MM');
    if not rt._agente_lembra(a.codigo, k) then
      perform rt.criar_avulsa(a.dono, left('Agente ' || a.nome || ' parou: orçamento de ações do mês esgotado', 200), now() + interval '1 day', null, 'agente', null);
      perform rt._agente_anota(a.codigo, k, 'Avisei o dono do orçamento esgotado', 'orçamento');
    end if;
  else
    -- o que sobra do orçamento limita esta rodada (só ações que contam: copiloto e autopiloto)
    if nivel >= 2 then v_max := least(v_max, a.orcamento_acoes_mes - usadas); end if;
    if a.comportamento = 'vigia_prazos' then
      for r in select c.id, c.titulo, c.prazo, p.papel from rt.cartao c left join rt.pessoa p on p.pseudonimo = c.dono
                where c.coluna <> 'feito' and c.prazo < now() and (a.circulo is null or c.circulo = a.circulo) and c.origem <> 'agente'
                  and not rt._agente_lembra(a.codigo, 'cartao:' || c.id) order by c.prazo limit v_max loop
        if nivel >= 2 then
          v_card := rt.criar_avulsa(a.dono, left('Prazo vencido: ' || r.titulo || ' (com ' || coalesce(r.papel, 'sem dono') || ')', 200), now() + interval '1 day', null, 'agente', null);
          perform rt._agente_anota(a.codigo, 'cartao:' || r.id, 'Avisei o dono do agente do prazo vencido em ' || to_char(r.prazo, 'DD/MM HH24:MI'), 'rt.cartao ' || r.id);
          acoes := acoes || jsonb_build_object('acao', 'aviso', 'cartao', r.id, 'novo_cartao', v_card);
        else acoes := acoes || jsonb_build_object('acao', 'sugestão (modo assistido)', 'cartao', r.id); end if;
        n := n + 1;
      end loop;
    elsif a.comportamento = 'vigia_vencimentos' then
      for r in
        select 'oportunidade:' || o.id as k, 'Exclusividade da oportunidade vence em ' || to_char(o.exclusiva_ate, 'DD/MM') || ': ' || o.cliente_final as t, 'ext.oportunidade ' || o.id as f
          from ext.oportunidade o where o.situacao in ('registrada', 'em_negociacao') and o.exclusiva_ate between current_date and current_date + 7
        union all
        select 'documento:' || e.id, 'Documento aguarda decisão há mais de 48 horas: ' || coalesce(p.conteudo->>'titulo', p.tipo), 'doc.emissao ' || e.id
          from doc.emissao e join doc.pedido p on p.id = e.pedido where p.situacao in ('emitido', 'emitido_com_alertas') and e.emitido_em < now() - interval '48 hours'
           and e.id = (select max(id) from doc.emissao where pedido = p.id)
        union all
        select 'mudanca:' || m.id, 'Mudança de parâmetro aguarda aprovação há mais de 24 horas: ' || m.chave, 'adm.mudanca ' || m.id
          from adm.mudanca m where m.situacao = 'pendente' and m.pedido_em < now() - interval '24 hours'
      loop
        exit when n >= v_max;
        continue when rt._agente_lembra(a.codigo, r.k);
        if nivel >= 2 then
          v_card := rt.criar_avulsa(a.dono, left(r.t, 200), now() + interval '1 day', null, 'agente', null);
          perform rt._agente_anota(a.codigo, r.k, 'Avisei: ' || r.t, r.f);
          acoes := acoes || jsonb_build_object('acao', 'aviso', 'ref', r.f, 'novo_cartao', v_card);
        else acoes := acoes || jsonb_build_object('acao', 'sugestão (modo assistido)', 'ref', r.f); end if;
        n := n + 1;
      end loop;
    elsif a.comportamento = 'atendente_externo' then
      for r in select p.id, p.tipo, p.prazo, c.nome from ext.pedido p join ext.contraparte c on c.id = p.contraparte
                where p.situacao = 'recebido' and not rt._agente_lembra(a.codigo, 'pedido:' || p.id) and not rt._agente_lembra(a.codigo, 'rascunho:' || p.id)
                  and (a.circulo is null or rt.pode(a.dono, c.empresa, null, 'ler')) order by p.id limit v_max loop
        -- só confirma o recebimento, o responsável e o prazo; nunca responde o mérito (regra do dono, na memória)
        v_texto := 'Recebemos o seu pedido. A área responsável é ' ||
          case r.tipo when 'oportunidade' then 'Negócios' when 'adesao' then 'Negócios' when 'titular' then 'Governança (proteção de dados)'
                      when 'duvida' then 'Relações' else 'Operações' end || ', com resposta até ' || to_char(r.prazo at time zone 'America/Fortaleza', 'DD/MM/YYYY "às" HH24:MI') || ' (horário de Fortaleza).';
        if nivel >= 3 then
          perform ext._responder(r.id, v_texto, 'em_atendimento', 'Atendimento automático (agente residente)');
          perform rt._agente_anota(a.codigo, 'pedido:' || r.id, 'Confirmei o recebimento do pedido ' || r.id || ' (' || r.tipo || ')', 'ext.pedido ' || r.id);
          acoes := acoes || jsonb_build_object('acao', 'confirmação enviada', 'pedido', r.id);
        elsif nivel = 2 then
          v_card := rt.criar_avulsa(a.dono, left('Confirmar a resposta automática ao pedido ' || r.id || ' de ' || r.nome, 200), now() + interval '4 hours', null, 'agente', null);
          -- o rascunho fica na memória, ligado ao cartão; a pessoa aprova com rt.agente_aprovar_rascunho
          perform rt._agente_anota(a.codigo, 'rascunho:' || r.id, v_texto, 'cartao ' || v_card);
          acoes := acoes || jsonb_build_object('acao', 'rascunho para aprovar', 'pedido', r.id, 'novo_cartao', v_card, 'texto', v_texto);
        else acoes := acoes || jsonb_build_object('acao', 'sugestão (modo assistido)', 'pedido', r.id); end if;
        n := n + 1;
      end loop;
    end if;
    sit := case when n = 0 then 'sem_acao' else 'ok' end;
  end if;
  insert into rt.agente_execucao (agente, gatilho, fim, situacao, n_acoes, acoes, detalhe)
  values (a.codigo, p_gatilho, now(), sit, case when sit = 'ok' and nivel >= 2 then n else 0 end, acoes, det) returning id into v_exec;
  update rt.agente_residente set ultima_execucao = now() where codigo = a.codigo;
  return jsonb_build_object('execucao', v_exec, 'situacao', sit, 'acoes', n, 'detalhe', det);
exception when others then
  insert into rt.agente_execucao (agente, gatilho, fim, situacao, detalhe) values (p_codigo, p_gatilho, now(), 'erro', left(sqlerrm, 500));
  insert into adm.erro (origem, detalhe, contexto) values ('rt.agente_executar', left(sqlerrm, 500), jsonb_build_object('agente', p_codigo, 'gatilho', p_gatilho));
  update rt.agente_residente set ultima_execucao = now() where codigo = p_codigo;
  return jsonb_build_object('situacao', 'erro', 'detalhe', sqlerrm);
end $$;

-- a agenda acorda quem passou do seu intervalo
create or replace function rt.agentes_acordar() returns jsonb language plpgsql security definer set search_path = '' as $$
declare r record; out jsonb := '[]';
begin
  for r in select codigo from rt.agente_residente where ligado and (ultima_execucao is null or ultima_execucao < now() - make_interval(mins => intervalo_minutos)) order by codigo loop
    out := out || jsonb_build_object(r.codigo, rt.agente_executar(r.codigo, 'agenda'));
  end loop;
  return out;
end $$;

-- administração do agente: ligar e desligar, liberar, editar a memória; tudo com motivo e histórico
create or replace function rt.agente_ligar(p_codigo text, p_ligado boolean, p_motivo text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._quem(p_como); antes boolean;
begin
  if coalesce(length(trim(p_motivo)), 0) = 0 then raise exception 'informe o motivo'; end if;
  select ligado into antes from rt.agente_residente where codigo = p_codigo for update; if not found then raise exception 'agente desconhecido'; end if;
  update rt.agente_residente set ligado = p_ligado where codigo = p_codigo;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo) values ('agente', p_codigo, jsonb_build_object('ligado', antes), jsonb_build_object('ligado', p_ligado), v,
    case when rt.eu() is null then 'página de administração (protótipo)' else 'app' end, p_motivo);
end $$;

create or replace function rt.agente_liberar(p_codigo text, p_liberado boolean, p_motivo text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._quem(p_como); antes boolean;
begin
  if coalesce(length(trim(p_motivo)), 0) = 0 then raise exception 'informe o motivo'; end if;
  select liberado into antes from rt.agente_residente where codigo = p_codigo for update; if not found then raise exception 'agente desconhecido'; end if;
  update rt.agente_residente set liberado = p_liberado, liberado_por = case when p_liberado then 'IT-06: ' || p_motivo else null end where codigo = p_codigo;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo) values ('agente', p_codigo, jsonb_build_object('liberado', antes), jsonb_build_object('liberado', p_liberado), v,
    case when rt.eu() is null then 'página de administração (protótipo)' else 'app' end, p_motivo);
end $$;

create or replace function rt.agente_memoria_editar(p_id bigint, p_nota text, p_ativa boolean, p_motivo text, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._quem(p_como); m rt.agente_memoria;
begin
  if coalesce(length(trim(p_motivo)), 0) = 0 then raise exception 'informe o motivo'; end if;
  select * into m from rt.agente_memoria where id = p_id for update; if not found then raise exception 'nota inexistente'; end if;
  update rt.agente_memoria set nota = coalesce(nullif(trim(p_nota), ''), nota), ativa = p_ativa, autor = 'pessoa', atualizado_em = now() where id = p_id;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo) values ('agente', m.agente || ' · memória ' || p_id,
    jsonb_build_object('nota', m.nota, 'ativa', m.ativa), jsonb_build_object('nota', coalesce(nullif(trim(p_nota), ''), m.nota), 'ativa', p_ativa), v,
    case when rt.eu() is null then 'página de administração (protótipo)' else 'app' end, p_motivo);
end $$;

-- a pessoa (dono do agente ou quem opera no círculo) aprova o rascunho do copiloto: a resposta sai e o cartão fecha
create or replace function rt.agente_aprovar_rascunho(p_cartao bigint, p_como uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); m rt.agente_memoria; v_ped bigint; c rt.cartao;
begin
  select * into m from rt.agente_memoria where fonte = 'cartao ' || p_cartao and chave like 'rascunho:%' and ativa;
  if m.id is null then raise exception 'cartão sem rascunho de agente'; end if;
  select * into c from rt.cartao where id = p_cartao;
  if c.dono <> v and not rt.pode(v, null, c.circulo, 'aprovar') then raise exception 'só o dono do cartão ou quem aprova no círculo'; end if;
  v_ped := split_part(m.chave, ':', 2)::bigint;
  perform ext._responder(v_ped, m.nota, 'em_atendimento', 'Atendimento automático aprovado por ' || (select papel from rt.pessoa where pseudonimo = v));
  update rt.agente_memoria set ativa = false, atualizado_em = now() where id = m.id;
  perform rt._agente_anota(m.agente, 'pedido:' || v_ped, 'Resposta ao pedido ' || v_ped || ' aprovada por pessoa e enviada', 'cartao ' || p_cartao);
  perform rt.concluir_cartao(p_cartao, c.dono);
end $$;

create or replace function rt.agentes_painel() returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if rt.eu() is null and not rt.chamada_servico() then raise exception 'sem identidade'; end if;
  if rt.eu() is not null and not rt.pode_estrito(rt.eu(), null, null, 'administrar') then raise exception 'sem acesso de administrar'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
    'codigo', a.codigo, 'nome', a.nome, 'responsabilidade', a.responsabilidade, 'comportamento', a.comportamento, 'circulo', (select nome from org.circulo where numero = a.circulo),
    'dono', (select papel from rt.pessoa where pseudonimo = a.dono), 'modo', a.modo, 'intervalo_minutos', a.intervalo_minutos, 'ligado', a.ligado, 'liberado', a.liberado,
    'liberado_por', a.liberado_por, 'provedor', a.provedor, 'orcamento_acoes_mes', a.orcamento_acoes_mes, 'ultima_execucao', a.ultima_execucao,
    'acoes_no_mes', (select coalesce(sum(n_acoes), 0) from rt.agente_execucao where agente = a.codigo and inicio >= date_trunc('month', now())),
    'execucoes', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'inicio', e.inicio, 'gatilho', e.gatilho, 'situacao', e.situacao, 'n_acoes', e.n_acoes, 'acoes', e.acoes, 'detalhe', e.detalhe) order by e.id desc), '[]')
                    from (select * from rt.agente_execucao where agente = a.codigo order by id desc limit 8) e),
    'memoria', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'nota', m.nota, 'fonte', m.fonte, 'autor', m.autor, 'ativa', m.ativa, 'atualizado_em', m.atualizado_em) order by m.autor desc, m.id desc), '[]')
                    from (select * from rt.agente_memoria where agente = a.codigo order by (autor = 'pessoa') desc, id desc limit 15) m),
    'rascunhos', (select coalesce(jsonb_agg(jsonb_build_object('cartao', split_part(m.fonte, ' ', 2)::bigint, 'pedido', split_part(m.chave, ':', 2)::bigint, 'texto', m.nota, 'em', m.criado_em) order by m.id), '[]')
                    from rt.agente_memoria m where m.agente = a.codigo and m.chave like 'rascunho:%' and m.ativa and m.fonte like 'cartao %')
  ) order by a.codigo), '[]') from rt.agente_residente a);
end $$;

-- o painel da administração passa a mostrar os agentes
create or replace function adm.painel_completo() returns jsonb language sql stable security definer set search_path = '' as $$
  select adm.painel() || jsonb_build_object('agentes', rt.agentes_painel()) $$;

-- Os três residentes do protótipo (liberados no protótipo; a liberação real é pela IT-06) --------------------------------------------
insert into rt.agente_residente (codigo, nome, dono, circulo, responsabilidade, comportamento, intervalo_minutos, modo, orcamento_acoes_mes, liberado, liberado_por) values
 ('guardiao-prazos-operacoes', 'Guardião de prazos de Operações', rt._pessoa('Líder do círculo', 7::smallint), 7,
  'Manter as entregas de Operações no prazo: vigiar cartões vencidos e avisar o líder antes que o cliente perceba.', 'vigia_prazos', 30, 'Copiloto', 300, true, 'protótipo, 04/10/2026'),
 ('vigia-vencimentos', 'Vigia de vencimentos', rt._pessoa('Líder do círculo', 9::smallint), 9,
  'Nada vence em silêncio: exclusividade de oportunidade de parceiro, documento parado sem decisão e mudança de parâmetro sem aprovação.', 'vigia_vencimentos', 60, 'Copiloto', 300, true, 'protótipo, 04/10/2026'),
 ('atendente-externo', 'Atendente do portal externo', rt._pessoa('Líder do círculo', 4::smallint), 4,
  'Todo pedido de cliente ou parceiro recebe, em minutos, a confirmação com a área responsável e o prazo; o mérito fica com as pessoas.', 'atendente_externo', 5, 'Autopiloto', 1000, true, 'protótipo, 04/10/2026')
on conflict (codigo) do nothing;
insert into rt.agente_memoria (agente, nota, fonte, autor)
select x.a, x.n, 'dono do agente, 04/10/2026', 'pessoa' from (values
 ('atendente-externo', 'Nunca responder o mérito do pedido: só confirmar o recebimento, a área responsável e o prazo.'),
 ('atendente-externo', 'Pedido de titular de dados tem o prazo da LGPD (art. 19, II); a resposta de mérito é da Governança.'),
 ('guardiao-prazos-operacoes', 'Avisar o líder uma vez por cartão vencido; não cobrar a pessoa diretamente.'),
 ('vigia-vencimentos', 'Avisar com sete dias de antecedência o fim da exclusividade de oportunidade de parceiro.')) x(a, n)
where not exists (select 1 from rt.agente_memoria m where m.agente = x.a and m.nota = x.n);

do $$ begin
  if not exists (select 1 from cron.job where jobname = 'imts-agentes') then perform cron.schedule('imts-agentes', '*/5 * * * *', 'select rt.agentes_acordar();'); end if;
end $$;

alter table rt.agente_residente enable row level security; alter table rt.agente_memoria enable row level security; alter table rt.agente_execucao enable row level security;
drop policy if exists leitura on rt.agente_residente; drop policy if exists leitura on rt.agente_memoria; drop policy if exists leitura on rt.agente_execucao;
create policy leitura on rt.agente_residente for select to authenticated using (rt.pode(rt.eu(), null, circulo, 'ler'));
create policy leitura on rt.agente_memoria for select to authenticated using (exists (select 1 from rt.agente_residente a where a.codigo = agente and rt.pode(rt.eu(), null, a.circulo, 'ler')));
create policy leitura on rt.agente_execucao for select to authenticated using (exists (select 1 from rt.agente_residente a where a.codigo = agente and rt.pode(rt.eu(), null, a.circulo, 'ler')));
grant select on rt.agente_residente, rt.agente_memoria, rt.agente_execucao to authenticated;
grant all on rt.agente_residente, rt.agente_memoria, rt.agente_execucao to service_role;
revoke all on function rt.agente_executar(text, text), rt.agentes_acordar(), rt._agente_lembra(text, text), rt._agente_anota(text, text, text, text),
  rt.agente_ligar(text, boolean, text, uuid), rt.agente_liberar(text, boolean, text, uuid), rt.agente_memoria_editar(bigint, text, boolean, text, uuid),
  rt.agente_aprovar_rascunho(bigint, uuid), rt.agentes_painel(), adm.painel_completo() from public;
grant execute on function rt.agente_executar(text, text), rt.agentes_acordar() to service_role;
grant execute on function rt.agente_ligar(text, boolean, text, uuid), rt.agente_liberar(text, boolean, text, uuid), rt.agente_memoria_editar(bigint, text, boolean, text, uuid),
  rt.agente_aprovar_rascunho(bigint, uuid), rt.agentes_painel(), adm.painel_completo() to authenticated, service_role;
commit;
