
-- Sistema do motor documental, contrato da interface e vínculo das automações que emitem documento ---------------------
insert into rt.sistema (codigo, nome, atende, descricao) values
  ('motor-documental', 'Motor documental (PDF e HTML)', 'R', 'Emite os documentos formais internos e externos das empresas: catálogo de tipos, marca por empresa, modelos de design, gates editoriais, registro com hash e aprovação em duas mãos')
on conflict (codigo) do nothing;
insert into rt.adaptador_operacao (sistema, operacao, entrada, saida, descricao) values
  ('motor-documental', 'emitir', '{"tipo":"text","marca":"text","empresa":"uuid|null","conteudo":"jsonb (titulo, data, local, blocos, anexos, assinaturas)"}', '{"pedido":"bigint"}', 'Põe o pedido na fila do worker (doc.pedir)'),
  ('motor-documental', 'situacao', '{"pedido":"bigint"}', '{"situacao":"text","emissao":"bigint","gates":"jsonb","alertas":"jsonb"}', 'Lê a situação do pedido e da última emissão'),
  ('motor-documental', 'decidir', '{"emissao":"bigint","etapa":"analise|aprovacao","decisao":"aprovado|reprovado","motivo":"text"}', '{"aprovacao":"bigint"}', 'Análise crítica e aprovação, por pessoas diferentes de quem pediu (doc.decidir)')
on conflict (sistema, operacao) do nothing;
-- automações que hoje emitem documento passam ao motor documental; agentes continuam redigindo, pessoas continuam assinando.
-- O vínculo é refeito a partir do catálogo atual: o que saiu do catálogo volta a "automacao".
update rt.vinculo set sistema = 'automacao' where sistema = 'motor-documental';
update rt.vinculo v set sistema = 'motor-documental'
  from doc.tipo_tarefa tt join org.tarefa t on t.id = tt.tarefa
 where v.tarefa = tt.tarefa and tt.papel = 'emite' and t.executor = 'R' and v.sistema = 'automacao'
   and t.nome ~* '^(publicar|emitir|gerar|lavrar|expedir|responder|enviar a proposta)';

-- Funções ------------------------------------------------------------------------------------------------------------
create or replace function doc._evento(p_pedido bigint, p_tipo text, p_dados jsonb default '{}') returns void
language sql security definer set search_path = '' as $$ insert into doc.evento (pedido, tipo, dados) values (p_pedido, p_tipo, p_dados) $$;

-- quem chama pelo app precisa de acesso "operar" na empresa; sem identidade, só o service_role (motor, testes)
create or replace function doc.pedir(p_tipo text, p_marca text, p_conteudo jsonb, p_empresa uuid default null, p_tarefa bigint default null,
  p_instancia bigint default null, p_modelo text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_eu uuid := rt.eu(); v_tipo doc.tipo; v_marca doc.marca; v_id bigint;
begin
  if v_eu is null and not rt.chamada_servico() then raise exception 'pedido sem identidade'; end if;
  if v_eu is not null and not rt.pode(v_eu, p_empresa, null, 'operar') then raise exception 'sem acesso para pedir documento nesta empresa'; end if;
  select * into v_tipo from doc.tipo where id = p_tipo; if not found then raise exception 'tipo fora do catálogo: %', p_tipo; end if;
  select * into v_marca from doc.marca where id = p_marca; if not found then raise exception 'marca sem pacote: %', p_marca; end if;
  if v_marca.situacao = 'provisoria' and v_tipo.alcance = 'externo' then raise exception 'marca provisória não emite documento externo (%)', p_tipo; end if;
  if p_modelo is not null and not exists (select 1 from doc.modelo where id = p_modelo) then raise exception 'modelo desconhecido: %', p_modelo; end if;
  -- todo documento é de uma empresa: sem empresa não há marca, nem acesso, nem publicação para fora
  if p_empresa is null then raise exception 'informe a empresa do documento'; end if;
  if not exists (select 1 from org.empresa where id = p_empresa and ativa) then raise exception 'empresa inexistente ou inativa'; end if;
  if coalesce(p_conteudo->>'titulo', '') = '' or coalesce(p_conteudo->>'data', '') = '' or coalesce(p_conteudo->>'local', '') = '' then
    raise exception 'conteúdo sem título, data ou local'; end if;
  insert into doc.pedido (tipo, marca, modelo, empresa, tarefa, instancia, conteudo, pedido_por)
  values (p_tipo, p_marca, p_modelo, p_empresa, p_tarefa, p_instancia, p_conteudo, v_eu) returning id into v_id;
  perform doc._evento(v_id, 'pedido', jsonb_build_object('tipo', p_tipo, 'marca', p_marca, 'por', v_eu));
  return v_id;
end $$;

create or replace function doc._chave_ok(p_chave text) returns boolean language sql stable security definer set search_path = '' as $$
  select p_chave is not null and length(p_chave) >= 32 and p_chave = rt._segredo('doc_worker_chave') $$;

-- worker: pega o próximo pedido (um por vez, sem disputa entre workers)
create or replace function doc.worker_proximo(p_chave text, p_worker text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v doc.pedido;
begin
  if not doc._chave_ok(p_chave) then raise exception 'não autorizado'; end if;
  update doc.pedido set situacao = 'em_emissao', worker = p_worker, atualizado_em = now()
   where id = (select id from doc.pedido where situacao = 'na_fila' order by criado_em for update skip locked limit 1)
  returning * into v;
  if v.id is null then return null; end if;
  perform doc._evento(v.id, 'em_emissao', jsonb_build_object('worker', p_worker));
  -- o modelo nunca vem do conteúdo: é o do pedido (validado em doc.pedir) ou o do tipo
  -- o pacote de marca vem do banco (aprovado em duas mãos, 045); o conteúdo do pedido não consegue trocá-lo
  return (v.conteudo - 'modelo' - 'id' - 'tipo' - 'marca' - '_marca_dados') || jsonb_build_object('id', 'pedido-' || v.id, 'tipo', v.tipo, 'marca', v.marca, 'pedido', v.id,
         'modelo', coalesce(v.modelo, (select modelo from doc.tipo where id = v.tipo)), '_marca_dados', (select dados from doc.marca where id = v.marca));
end $$;

drop function if exists doc.worker_registrar(text, bigint, jsonb, text, text);
drop function if exists public.doc_worker_registrar(text, bigint, jsonb, text, text);
create or replace function doc.worker_registrar(p_chave text, p_worker text, p_pedido bigint, p_registro jsonb, p_pdf text, p_html text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_em bigint; v_sit text; v_pdf bytea; v_html bytea; v_ped doc.pedido;
begin
  if not doc._chave_ok(p_chave) then raise exception 'não autorizado'; end if;
  select * into v_ped from doc.pedido where id = p_pedido for update;
  if v_ped.id is null or v_ped.situacao <> 'em_emissao' then raise exception 'pedido % não está em emissão', p_pedido; end if;
  if v_ped.worker is distinct from p_worker then raise exception 'o pedido % está com outro worker', p_pedido; end if;
  -- a situação é recalculada pelo banco a partir dos gates e alertas; o que o worker declara não vale
  v_sit := case when p_registro->>'situacao' = 'recusado' then 'recusado'
                when exists (select 1 from jsonb_array_elements(coalesce(p_registro->'gates', '[]')) g where g->>'nivel' = 'bloqueia') then 'bloqueado'
                when jsonb_array_length(coalesce(p_registro->'alertas', '[]')) > 0 then 'emitido_com_alertas' else 'emitido' end;
  if v_sit = 'recusado' then
    update doc.pedido set situacao = 'recusado', erro = p_registro->>'erros', atualizado_em = now() where id = p_pedido;
    perform doc._evento(p_pedido, 'recusado', p_registro); return null;
  end if;
  v_pdf := decode(p_pdf, 'base64'); v_html := decode(p_html, 'base64');
  if encode(extensions.digest(v_pdf, 'sha256'), 'hex') <> p_registro->>'hash_pdf' then raise exception 'hash do PDF não confere'; end if;
  if encode(extensions.digest(v_html, 'sha256'), 'hex') <> p_registro->>'hash_html' then raise exception 'hash do HTML não confere'; end if;
  insert into doc.emissao (pedido, situacao, paginas, hash_pedido, hash_pdf, hash_html, gates, alertas, registro, worker)
  values (p_pedido, v_sit, (p_registro->>'paginas')::int, p_registro->>'hash_pedido', p_registro->>'hash_pdf', p_registro->>'hash_html',
          coalesce(p_registro->'gates', '[]'), coalesce(p_registro->'alertas', '[]'), p_registro, (select worker from doc.pedido where id = p_pedido))
  returning id into v_em;
  insert into doc.arquivo values (v_em, 'pdf', v_pdf, p_registro->>'hash_pdf', length(v_pdf)),
                                 (v_em, 'html', v_html, encode(extensions.digest(v_html, 'sha256'), 'hex'), length(v_html));
  update doc.pedido set situacao = v_sit, erro = null, atualizado_em = now() where id = p_pedido;
  perform doc._evento(p_pedido, v_sit, jsonb_build_object('emissao', v_em, 'gates', jsonb_array_length(coalesce(p_registro->'gates', '[]')),
                                                          'alertas', jsonb_array_length(coalesce(p_registro->'alertas', '[]'))));
  return v_em;
end $$;

-- parâmetro inteiro da administração (adm.valor); enquanto a administração não estiver implantada, vale o padrão
create or replace function doc._param(p_chave text, p_padrao int) returns int language plpgsql stable security definer set search_path = '' as $$
declare v int;
begin
  if to_regprocedure('adm.valor(text,jsonb)') is null then return p_padrao; end if;
  execute 'select (adm.valor($1, to_jsonb($2)) #>> ''{}'')::int' into v using p_chave, p_padrao;
  return coalesce(v, p_padrao);
end $$;
revoke all on function doc._param(text, int) from public, anon, authenticated;

create or replace function doc.worker_falhar(p_chave text, p_pedido bigint, p_erro text) returns text
language plpgsql security definer set search_path = '' as $$
declare v_sit text; v_max int := doc._param('documental.tentativas_maximas', 3);
begin
  if not doc._chave_ok(p_chave) then raise exception 'não autorizado'; end if;
  update doc.pedido set tentativas = tentativas + 1, erro = left(p_erro, 2000), atualizado_em = now(),
         situacao = case when tentativas + 1 >= v_max then 'erro' else 'na_fila' end
   where id = p_pedido and situacao = 'em_emissao' returning situacao into v_sit;
  perform doc._evento(p_pedido, 'falha', jsonb_build_object('erro', left(p_erro, 500), 'situacao', v_sit));
  return v_sit;
end $$;

-- pedido preso em emissão (worker caiu) volta para a fila depois do prazo da administração (padrão 15 minutos)
create or replace function doc.destravar() returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  with x as (update doc.pedido set situacao = 'na_fila', worker = null, atualizado_em = now()
              where situacao = 'em_emissao' and atualizado_em < now() - make_interval(mins => doc._param('documental.destravar_minutos', 15)) returning id)
  select count(*)::int into n from x;
  return n;
end $$;

-- análise crítica e aprovação: duas mãos, nunca quem pediu; bloqueado não se submete; alerta mantido exige justificativa
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

create unique index if not exists aprovacao_unica on doc.aprovacao (emissao, etapa) where decisao = 'aprovado';
create index if not exists emissao_pedido on doc.emissao (pedido, id desc);
create index if not exists aprovacao_emissao on doc.aprovacao (emissao);
create index if not exists evento_pedido on doc.evento (pedido);
create index if not exists pedido_situacao on doc.pedido (situacao);

create or replace view doc.v_fila with (security_invoker = true) as
  select situacao, count(*) as pedidos, min(criado_em) as mais_antigo from doc.pedido group by situacao;

-- Entrada pública do worker (PostgREST só expõe public): protegida pela chave do Vault doc_worker_chave -----------------
create or replace function public.doc_worker_proximo(p_chave text, p_worker text) returns jsonb language sql security definer set search_path = '' as $$ select doc.worker_proximo(p_chave, p_worker) $$;
create or replace function public.doc_worker_registrar(p_chave text, p_worker text, p_pedido bigint, p_registro jsonb, p_pdf text, p_html text) returns bigint language sql security definer set search_path = '' as $$ select doc.worker_registrar(p_chave, p_worker, p_pedido, p_registro, p_pdf, p_html) $$;
create or replace function public.doc_worker_falhar(p_chave text, p_pedido bigint, p_erro text) returns text language sql security definer set search_path = '' as $$ select doc.worker_falhar(p_chave, p_pedido, p_erro) $$;

-- Segurança ------------------------------------------------------------------------------------------------------------
do $$ declare t text; begin
  foreach t in array array['marca','modelo','tipo','tipo_tarefa','pedido','emissao','arquivo','aprovacao','evento'] loop
    execute format('alter table doc.%I enable row level security', t);
    execute format('drop policy if exists leitura on doc.%I', t);
  end loop;
end $$;
create policy leitura on doc.marca for select to authenticated using (true);
create policy leitura on doc.modelo for select to authenticated using (true);
create policy leitura on doc.tipo for select to authenticated using (true);
create policy leitura on doc.tipo_tarefa for select to authenticated using (true);
create policy leitura on doc.pedido for select to authenticated using (rt.pode(rt.eu(), empresa, null, 'ler'));
create policy leitura on doc.emissao for select to authenticated using (exists (select 1 from doc.pedido p where p.id = pedido and rt.pode(rt.eu(), p.empresa, null, 'ler')));
create policy leitura on doc.arquivo for select to authenticated using (exists (select 1 from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = emissao and rt.pode(rt.eu(), p.empresa, null, 'ler')));
create policy leitura on doc.aprovacao for select to authenticated using (exists (select 1 from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = emissao and rt.pode(rt.eu(), p.empresa, null, 'ler')));
create policy leitura on doc.evento for select to authenticated using (exists (select 1 from doc.pedido p where p.id = pedido and rt.pode(rt.eu(), p.empresa, null, 'ler')));
grant select on all tables in schema doc to authenticated;
grant all on all tables in schema doc to service_role;
revoke all on all functions in schema doc from public;
grant execute on function doc.pedir(text, text, jsonb, uuid, bigint, bigint, text), doc.decidir(bigint, text, text, text) to authenticated, service_role;
grant execute on function doc.destravar(), doc.worker_proximo(text, text), doc.worker_registrar(text, text, bigint, jsonb, text, text), doc.worker_falhar(text, bigint, text) to service_role;
revoke all on function public.doc_worker_proximo(text, text), public.doc_worker_registrar(text, text, bigint, jsonb, text, text), public.doc_worker_falhar(text, bigint, text) from public;
grant execute on function public.doc_worker_proximo(text, text), public.doc_worker_registrar(text, text, bigint, jsonb, text, text), public.doc_worker_falhar(text, bigint, text) to anon, authenticated, service_role;
