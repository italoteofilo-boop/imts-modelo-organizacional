-- Auditoria de 04/10/2026: rt.pode com empresa ou círculo nulos aceitava acesso de qualquer escopo. Objetos globais (administração) e
-- decisões com escopo (documento de uma tarefa) passam a usar rt.pode_estrito. As fontes 017, 025, 028, 030 e 033 já saem corrigidas;
-- este arquivo aplica o mesmo na base implantada.
begin;
create or replace function rt.pode_estrito(p_pessoa uuid, p_empresa uuid, p_circulo smallint, p_nivel text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from rt.acesso a
                  where a.pessoa = p_pessoa and current_date >= a.inicio and (a.fim is null or current_date <= a.fim)
                    and (a.empresa is null or a.empresa = p_empresa)
                    and (a.circulo is null or a.circulo = p_circulo)
                    and rt._nivel(a.nivel) >= rt._nivel(p_nivel)) $$;
create or replace function adm._quem(p_como uuid) returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then
    if not rt.chamada_servico() then raise exception 'sem identidade'; end if;
    v := p_como;
  end if;
  if v is null or not rt.pode_estrito(v, null, null, 'administrar') then raise exception 'sem acesso de administrar'; end if;
  return v;
end $$;
create or replace function adm.painel() returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if rt.eu() is not null and not rt.pode_estrito(rt.eu(), null, null, 'administrar') then raise exception 'sem acesso de administrar'; end if;
  if rt.eu() is null and not rt.chamada_servico() then raise exception 'sem identidade'; end if;
  return jsonb_build_object(
    'gerado_em', now(),
    'resumo', jsonb_build_object(
      'conexoes', (select count(*) from adm.conexao), 'ativas', (select count(*) from adm.conexao where estado = 'ativa'),
      'pendentes', (select count(*) from adm.conexao where estado = 'pendente'), 'simuladas', (select count(*) from adm.conexao where estado = 'simulada'),
      'saude_ok', (select count(*) from adm.conexao where saude = 'ok'), 'saude_falha', (select count(*) from adm.conexao where saude = 'falha'),
      'parametros', (select count(*) from adm.parametro), 'mudancas_pendentes', (select count(*) from adm.mudanca where situacao = 'pendente'),
      'fila_documentos', (select coalesce(jsonb_object_agg(situacao, n), '{}') from (select situacao, count(*) n from doc.pedido group by 1) x)),
    'conexoes', (select coalesce(jsonb_agg(to_jsonb(c) - 'alvo' order by c.categoria, c.codigo), '[]') from adm.conexao c),
    'parametros', (select coalesce(jsonb_agg(to_jsonb(p) order by p.escopo, p.chave), '[]') from adm.parametro p),
    'mudancas', (select coalesce(jsonb_agg(to_jsonb(m) order by m.id desc), '[]') from (select * from adm.mudanca order by id desc limit 50) m),
    'historico', (select coalesce(jsonb_agg(to_jsonb(h) order by h.id desc), '[]') from (select * from adm.historico order by id desc limit 100) h),
    'administradores', (select coalesce(jsonb_agg(jsonb_build_object('pessoa', a.pessoa, 'papel', a.papel) order by a.papel), '[]')
                          from rt.acesso a where a.nivel = 'administrar' and (a.fim is null or a.fim >= current_date)),
    'agenda', (select coalesce(jsonb_agg(jsonb_build_object('job', jobname, 'quando', schedule, 'ativo', active) order by jobname), '[]') from cron.job where jobname like 'imts-%'));
end $$;
drop policy if exists leitura on adm.conexao; drop policy if exists leitura on adm.parametro; drop policy if exists leitura on adm.mudanca; drop policy if exists leitura on adm.historico;
create policy leitura on adm.conexao for select to authenticated using (rt.pode_estrito(rt.eu(), null, null, 'administrar'));
create policy leitura on adm.parametro for select to authenticated using (rt.pode(rt.eu(), null, null, 'ler'));
create policy leitura on adm.mudanca for select to authenticated using (rt.pode_estrito(rt.eu(), null, null, 'administrar'));
create policy leitura on adm.historico for select to authenticated using (rt.pode_estrito(rt.eu(), null, null, 'administrar'));
drop policy if exists leitura on ext.usuario;
create policy leitura on ext.usuario for select to authenticated using (auth_uid = auth.uid() or rt.pode_estrito(rt.eu(), null, null, 'administrar'));
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
create or replace function doc.decidir(p_emissao bigint, p_etapa text, p_decisao text, p_motivo text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_eu uuid := rt.eu(); e doc.emissao; p doc.pedido; v_id bigint; v_circ smallint;
begin
  if v_eu is null then raise exception 'decisão sem identidade'; end if;
  select * into e from doc.emissao where id = p_emissao; if not found then raise exception 'emissão inexistente'; end if;
  select * into p from doc.pedido where id = e.pedido for update;
  if p.situacao not in ('emitido', 'emitido_com_alertas') then raise exception 'pedido em situação % não recebe decisão', p.situacao; end if;
  if p_etapa not in ('analise', 'aprovacao') or p_decisao not in ('aprovado', 'reprovado') then raise exception 'etapa ou decisão inválida'; end if;
  -- alçada no escopo do documento: empresa do pedido e círculo da tarefa que o gerou; sem tarefa, só quem aprova sem restrição de círculo
  select j.circulo into v_circ from org.tarefa t join org.etapa et on et.id = t.etapa join org.jornada j on j.codigo = et.jornada where t.id = p.tarefa;
  if not rt.pode_estrito(v_eu, p.empresa, v_circ, 'aprovar') then raise exception 'sem alçada para decidir este documento (empresa e círculo)'; end if;
  if e.id <> (select max(id) from doc.emissao where pedido = p.id) then raise exception 'há emissão mais nova deste pedido'; end if;
  if e.situacao in ('bloqueado', 'recusado') then raise exception 'emissão % não pode ser submetida', e.situacao; end if;
  if p.pedido_por = v_eu then raise exception 'quem pediu não decide o próprio documento'; end if;
  if p_decisao = 'aprovado' and jsonb_array_length(e.alertas) > 0 and coalesce(length(trim(p_motivo)), 0) = 0 then
    raise exception 'há alertas tipográficos: justifique a manutenção no motivo'; end if;
  if p_etapa = 'analise' and exists (select 1 from doc.aprovacao where emissao = e.id and etapa = 'analise' and decisao = 'aprovado') then
    raise exception 'a análise crítica desta emissão já foi feita'; end if;
  if p_etapa = 'aprovacao' then
    -- vale a última análise: análise reprovada não se compensa com outra aprovada
    if (select decisao from doc.aprovacao where emissao = e.id and etapa = 'analise' order by id desc limit 1) is distinct from 'aprovado' then raise exception 'falta a análise crítica aprovada'; end if;
    if exists (select 1 from doc.aprovacao where emissao = e.id and etapa = 'analise' and pessoa = v_eu) then raise exception 'quem analisou não aprova'; end if;
  end if;
  insert into doc.aprovacao (emissao, etapa, pessoa, decisao, motivo) values (e.id, p_etapa, v_eu, p_decisao, p_motivo) returning id into v_id;
  if p_decisao = 'reprovado' then update doc.pedido set situacao = 'reprovado', atualizado_em = now() where id = p.id;
  elsif p_etapa = 'aprovacao' then update doc.pedido set situacao = 'aprovado', atualizado_em = now() where id = p.id; end if;
  perform doc._evento(p.id, p_etapa || ':' || p_decisao, jsonb_build_object('emissao', e.id, 'por', v_eu));
  return v_id;
end $$;
revoke all on function rt.pode_estrito(uuid, uuid, smallint, text) from public, anon;
grant execute on function rt.pode_estrito(uuid, uuid, smallint, text) to authenticated, service_role;
-- políticas de leitura do ext por empresa da contraparte
create or replace function ext._le(p_contraparte uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select rt.eu() is not null and rt.pode(rt.eu(), (select empresa from ext.contraparte where id = p_contraparte), null, 'ler') $$;
drop policy if exists leitura on ext.contraparte;
create policy leitura on ext.contraparte for select to authenticated using (id = (ext.eu()).contraparte or ext._le(id));
drop policy if exists leitura on ext.publicacao;
create policy leitura on ext.publicacao for select to authenticated using ((contraparte = (ext.eu()).contraparte and (ext.eu()).perfil = any (perfis)) or ext._le(contraparte));
drop policy if exists leitura on ext.pedido;
create policy leitura on ext.pedido for select to authenticated using ((contraparte = (ext.eu()).contraparte and ((ext.eu()).perfil = 'gestor' or usuario = auth.uid())) or ext._le(contraparte));
drop policy if exists leitura on ext.oportunidade;
create policy leitura on ext.oportunidade for select to authenticated using (contraparte = (ext.eu()).contraparte or ext._le(contraparte));
drop policy if exists leitura on ext.documento;
create policy leitura on ext.documento for select to authenticated using ((contraparte = (ext.eu()).contraparte and (ext.eu()).perfil = any (perfis)) or ext._le(contraparte));
drop policy if exists leitura on ext.vinculo;
create policy leitura on ext.vinculo for select to authenticated using (ext._le(contraparte));
revoke all on function ext._le(uuid) from public, anon;
grant execute on function ext._le(uuid) to authenticated, service_role;
update doc.pedido p set empresa = em.empresa from ext.empresa_marca em where p.empresa is null and em.marca = p.marca;
-- toda função criada daqui em diante nasce sem execução para public (o 035 só revogou as que existiam)
alter default privileges in schema rt, doc, adm, ext, org, sim revoke execute on functions from public;
-- documento sempre de uma empresa (doc.pedir já exige; agora o banco também)
alter table doc.pedido alter column empresa set not null;
commit;
