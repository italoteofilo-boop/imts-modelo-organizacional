-- Pacote P6 do IMTS.OS (078 automação R, 080 avisos de assinatura, 082 Mini App, 084 Google Docs, 086 agentes de IA). Colar inteiro no SQL Editor e executar: é uma transação só, idempotente.
begin;

-- ===== 078_automacao_r.sql =====
-- Automação real das tarefas de automação (executor R) que só registram, encaminham ou avisam (21/10/2026).
-- Problema: em produção (motor.maquina_assistida ligado) toda tarefa R de instância real e interativa virava cartão para uma
-- pessoa do círculo (062). Boa parte delas só registra um fato, passa algo adiante ou avisa alguém: não precisa de gente.
-- Regra nova, ligada pelo parâmetro motor.automacao_r (padrão: ligado):
--   o verbo da tarefa é a primeira palavra do nome; a tabela adm.automacao_r_regra diz o modo de cada verbo:
--     registrar  -> a automação conclui e registra no histórico da instância;
--     encaminhar -> a automação conclui e registra a passagem (a entrega à outra área já acontece pelo fluxo e pelas trocas da etapa);
--     avisar     -> a automação conclui e avisa a pessoa da raia (Telegram, se ligado; senão, cartão de aviso na Mesa, que não segura o fluxo);
--     humano     -> continua cartão no modo assistido (é o padrão de todo verbo sem regra).
--   tarefa composta ("Registrar ... e publicar ...") fica com a pessoa quando a outra ação tem regra humana.
-- Tarefa de agente (A), instância simulada e o modo assistido desligado seguem como antes.
-- Como: rt._avancar ganha um trecho mínimo (troca de texto conferida, no padrão da 074) que chama rt._automatizar_r.
-- rt.concluir_cartao e rt.decidir_cartao seguem o fluxo por rt._avancar, então ficam cobertos pela mesma troca.

-- ---------- histórico: objeto novo ----------
do $$
declare v_def text; v_lista text[];
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint where conname = 'historico_objeto_check' and conrelid = 'adm.historico'::regclass;
  v_lista := array(select m[1] from regexp_matches(coalesce(v_def, ''), '''([a-z_]+)''', 'g') m);
  if not ('automacao_r' = any (v_lista)) then
    v_lista := v_lista || 'automacao_r'::text;
    alter table adm.historico drop constraint if exists historico_objeto_check;
    execute format('alter table adm.historico add constraint historico_objeto_check check (objeto in (%s))',
                   (select string_agg(quote_literal(x), ', ') from unnest(v_lista) x));
  end if;
end $$;

-- ---------- parâmetro ----------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('motor.automacao_r', 'global', 'Modo assistido: tarefa de automação cujo verbo só registra, encaminha ou avisa é concluída pela automação, sem cartão (regras em adm.automacao_r_regra)',
  'booleano', 'true', 'true', '{}', true, '{}', 'Automação real das tarefas R, 21/10/2026')
on conflict (chave) do nothing;

-- ---------- regras por verbo ----------
create table if not exists adm.automacao_r_regra (
  verbo          text primary key check (verbo ~ '^[[:upper:]][[:lower:]]+$'),
  modo           text not null check (modo in ('registrar', 'encaminhar', 'avisar', 'humano')),
  descricao      text not null,
  atualizado_em  timestamptz not null default now(),
  atualizado_por uuid
);
alter table adm.automacao_r_regra enable row level security;
drop policy if exists leitura on adm.automacao_r_regra;
create policy leitura on adm.automacao_r_regra for select to authenticated using (true);
revoke all on adm.automacao_r_regra from public, anon, authenticated;
grant select on adm.automacao_r_regra to authenticated;
grant all on adm.automacao_r_regra to service_role;

-- carga inicial conservadora: só estes verbos saem do cartão
insert into adm.automacao_r_regra (verbo, modo, descricao)
select v, m, d from (values
  ('Registrar', 'registrar', 'registra o fato no histórico da instância'),
  ('Receber', 'registrar', 'registra o recebimento'),
  ('Atualizar', 'registrar', 'registra a atualização'),
  ('Versionar', 'registrar', 'registra a nova versão'),
  ('Guardar', 'registrar', 'registra a guarda'),
  ('Marcar', 'registrar', 'registra a marcação'),
  ('Apontar', 'registrar', 'registra o apontamento'),
  ('Arquivar', 'registrar', 'registra o arquivamento'),
  ('Enviar', 'encaminhar', 'registra a passagem; a entrega segue pelo fluxo e pelas trocas'),
  ('Encaminhar', 'encaminhar', 'registra a passagem; a entrega segue pelo fluxo e pelas trocas'),
  ('Passar', 'encaminhar', 'registra a passagem; a entrega segue pelo fluxo e pelas trocas'),
  ('Entregar', 'encaminhar', 'registra a passagem; a entrega segue pelo fluxo e pelas trocas'),
  ('Mandar', 'encaminhar', 'registra a passagem; a entrega segue pelo fluxo e pelas trocas'),
  ('Levar', 'encaminhar', 'registra a passagem; a entrega segue pelo fluxo e pelas trocas'),
  ('Devolver', 'encaminhar', 'registra a passagem; a entrega segue pelo fluxo e pelas trocas'),
  ('Pedir', 'encaminhar', 'registra o pedido; a entrega segue pelo fluxo e pelas trocas'),
  ('Avisar', 'avisar', 'avisa a pessoa da raia'),
  ('Informar', 'avisar', 'avisa a pessoa da raia'),
  ('Responder', 'avisar', 'avisa a pessoa da raia')) x(v, m, d)
on conflict (verbo) do nothing;
-- todo o resto continua com a pessoa: os primeiros verbos de todas as tarefas do modelo ficam como humano (servem também para a regra da tarefa composta)
insert into adm.automacao_r_regra (verbo, modo, descricao)
select distinct initcap(lower(split_part(btrim(t.nome), ' ', 1))), 'humano', 'continua cartão no modo assistido'
  from org.tarefa t where split_part(btrim(t.nome), ' ', 1) ~ '^[[:upper:]][[:lower:]]+$'
on conflict (verbo) do nothing;

-- ---------- modo de uma tarefa pelo nome ----------
create or replace function rt._automacao_r_modo(p_nome text) returns text language plpgsql stable security definer set search_path = '' as $$
declare v_verbo text := initcap(lower(split_part(btrim(coalesce(p_nome, '')), ' ', 1))); v_modo text; w text;
begin
  select modo into v_modo from adm.automacao_r_regra where verbo = v_verbo;
  v_modo := coalesce(v_modo, 'humano');
  if v_modo = 'humano' then return v_modo; end if;
  -- tarefa composta: "Registrar ... e publicar ..." fica com a pessoa se a outra ação tiver regra humana
  for w in select initcap(lower(m[1])) from regexp_matches(p_nome, '(?:^|[\s,])e\s+([^\s,.;:()]+)', 'g') m loop
    if exists (select 1 from adm.automacao_r_regra where verbo = w and modo = 'humano') then return 'humano'; end if;
  end loop;
  return v_modo;
end $$;

-- ---------- conclusão pela automação ----------
-- Devolve true quando concluiu a tarefa (o token já seguiu); false quando a tarefa continua com a pessoa.
create or replace function rt._automatizar_r(p_inst bigint, p_no text, p_tarefa bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare ins rt.instancia; v_tar record; v_modo text; v_det text; v_dest uuid; v_tg bigint; v_card bigint; v_quando timestamptz;
begin
  if not coalesce((adm.valor('motor.automacao_r', 'true') #>> '{}')::boolean, true) then return false; end if;
  select * into ins from rt.instancia where id = p_inst;
  if ins.id is null or ins.simulado or not ins.interativo then return false; end if;
  select t.id, t.nome, t.raia, t.executor, e.id as etapa_id, e.numero as etapa_numero into v_tar
    from org.tarefa t join org.etapa e on e.id = t.etapa where t.id = p_tarefa;
  if v_tar.id is null or v_tar.executor <> 'R' then return false; end if;
  v_modo := rt._automacao_r_modo(v_tar.nome);
  if v_modo = 'humano' then return false; end if;

  v_quando := greatest(coalesce(ins.relogio, now()), now());
  v_det := 'concluída pela automação: ' || v_modo;
  if v_modo = 'avisar' then
    -- quem recebe o aviso: a pessoa da raia; sem ela, o líder do círculo
    v_dest := coalesce(rt._pessoa(rt._raia_humana(v_tar.raia), ins.motor), rt._pessoa('Líder do círculo', ins.motor));
    if v_dest is null then
      v_det := v_det || ' (sem pessoa no círculo para receber o aviso)';
    else
      select i.telegram_id into v_tg from rt_chave.identidade i where i.pseudonimo = v_dest and i.nome not like 'eliminado em %';
      if v_tg is not null then
        insert into rt.fila_envio (chat_ref, texto, pessoa, motor, simulado)
        values ('tg:' || v_tg, left('IMTS.OS, aviso da jornada ' || ins.jornada || ' (etapa ' || v_tar.etapa_numero || '): ' || v_tar.nome || '.', 3500),
                v_dest, ins.motor, false);
        v_det := v_det || ' (aviso pelo Telegram)';
      else
        -- sem Telegram ligado: aviso na Mesa, como tarefa avulsa; o fluxo não espera por ela
        insert into rt.cartao (tipo, titulo, circulo, instancia, jornada, etapa, dono, criado_por, origem, prazo, simulado)
        values ('avulsa', left('Aviso: ' || v_tar.nome, 200), ins.motor, p_inst, ins.jornada, v_tar.etapa_id, v_dest, v_dest, 'motor', now() + interval '1 day', false)
        returning id into v_card;
        perform rt._ev(p_inst, v_card, 'cartao_criado', 'aviso: ' || v_tar.nome, v_dest, ins.motor, ins.jornada, v_tar.etapa_id, v_tar.id, 'R', v_quando, null, false);
        v_det := v_det || ' (aviso na Mesa)';
      end if;
    end if;
  end if;

  perform rt._ev(p_inst, null, 'fim', v_det, null, ins.motor, ins.jornada, v_tar.etapa_id, v_tar.id, 'R', v_quando, v_quando, false);
  update rt.instancia set relogio = v_quando where id = p_inst;
  -- trocas que saem na etapa (uma vez por etapa), como no caminho automático e na conclusão de cartão
  perform rt._trocas_da_etapa(p_inst, v_tar.etapa_id);
  insert into rt.token (instancia, no) select p_inst, para from rt.fluxo where jornada = ins.jornada and de = p_no order by id;
  return true;
end $$;

-- ---------- trecho mínimo em rt._avancar (troca conferida, sem copiar o corpo) ----------
do $$
declare d text := pg_get_functiondef('rt._avancar(bigint, integer)'::regprocedure); a text;
  alvo text := $q$      if ins.interativo and (v_tar.executor in ('P', 'H', 'X') or (v_tar.executor in ('A', 'R') and rt._assistido(ins))) then$q$;
begin
  if position('rt._automatizar_r' in d) > 0 then return; end if;
  a := d;
  d := replace(d, alvo, $q$      -- automação real (078): tarefa R que só registra, encaminha ou avisa é concluída na hora, sem cartão
      if v_tar.executor = 'R' and ins.interativo and rt._assistido(ins) and rt._automatizar_r(p_inst, tk.no, v_tar.id) then
        select * into ins from rt.instancia where id = p_inst;
        continue;
      end if;
$q$ || alvo);
  if d = a or (length(d) - length(replace(d, 'rt._automatizar_r(', ''))) / length('rt._automatizar_r(') <> 1 then
    raise exception 'rt._avancar não tem o texto esperado: revisar a 078'; end if;
  execute d;
end $$;

-- ---------- regra: só quem administra altera ----------
create or replace function adm.automacao_r_definir(p_verbo text, p_modo text, p_motivo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._so_admin(); v_verbo text := initcap(lower(btrim(coalesce(p_verbo, '')))); antes adm.automacao_r_regra; depois adm.automacao_r_regra;
begin
  if v_verbo !~ '^[[:upper:]][[:lower:]]+$' then raise exception 'verbo: uma palavra só, sem espaço'; end if;
  if coalesce(p_modo, '') not in ('registrar', 'encaminhar', 'avisar', 'humano') then raise exception 'modo: registrar, encaminhar, avisar ou humano'; end if;
  if coalesce(btrim(p_motivo), '') = '' then raise exception 'informe o motivo'; end if;
  select * into antes from adm.automacao_r_regra where verbo = v_verbo for update;
  insert into adm.automacao_r_regra (verbo, modo, descricao, atualizado_em, atualizado_por)
  values (v_verbo, p_modo, left(btrim(p_motivo), 300), now(), v)
  on conflict (verbo) do update set modo = excluded.modo, descricao = excluded.descricao, atualizado_em = now(), atualizado_por = v
  returning * into depois;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('automacao_r', v_verbo, to_jsonb(antes), to_jsonb(depois), v, 'app', p_motivo);
  return to_jsonb(depois);
end $$;

-- ---------- conferência ----------
create or replace function adm.automacao_r_resumo() returns jsonb language sql stable security definer set search_path = '' as $$
  with t as (
    select t.id, initcap(lower(split_part(btrim(t.nome), ' ', 1))) as verbo, rt._automacao_r_modo(t.nome) as modo
      from org.tarefa t where t.executor = 'R'
  ), n as (select modo, count(*) as q from t group by modo)
  select jsonb_build_object(
    'ligado', coalesce((adm.valor('motor.automacao_r', 'true') #>> '{}')::boolean, true),
    'modo_assistido', coalesce((adm.valor('motor.maquina_assistida', 'false') #>> '{}')::boolean, false),
    'tarefas_r', (select count(*) from t),
    'por_modo', (select jsonb_object_agg(m, coalesce((select q from n where n.modo = m), 0)) from unnest(array['registrar', 'encaminhar', 'avisar', 'humano']) m),
    'automaticas', (select count(*) from t where modo <> 'humano'),
    'humanas', (select count(*) from t where modo = 'humano'),
    'compostas_humanas', (select count(*) from t join adm.automacao_r_regra r on r.verbo = t.verbo where r.modo <> 'humano' and t.modo = 'humano'),
    'verbos_sem_regra', (select coalesce(jsonb_agg(distinct t.verbo), '[]') from t where not exists (select 1 from adm.automacao_r_regra r where r.verbo = t.verbo)))
$$;

-- ---------- permissões ----------
revoke all on function rt._automacao_r_modo(text), rt._automatizar_r(bigint, text, bigint),
  adm.automacao_r_definir(text, text, text), adm.automacao_r_resumo() from public, anon, authenticated;
grant execute on function rt._automacao_r_modo(text), rt._automatizar_r(bigint, text, bigint) to service_role;
grant execute on function adm.automacao_r_definir(text, text, text), adm.automacao_r_resumo() to authenticated, service_role;

insert into adm.api_funcao (nome, quem, descricao) values
  ('adm.automacao_r_resumo', 'interno', 'Tarefas de automação (R) por modo: quantas a automação conclui e quantas continuam com a pessoa'),
  ('adm.automacao_r_definir', 'interno', 'Definir o modo da automação de um verbo de tarefa R (só administração)')
on conflict (nome) do nothing;


-- ===== 080_assinatura_avisos.sql =====
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


-- ===== 082_telegram_miniapp.sql =====
-- P6 do inventário: Telegram Mini App do IMTS.OS (app/tg.html em www.imts.global; homologação em homolog.imts.global).
-- A página abre dentro do Telegram e manda o initData à função do servidor telegram_app (verify_jwt desligado). A função confere a
-- assinatura com o token do bot, acha a pessoa pelo Telegram ligado (rt_chave.identidade) e o login dela (rt_chave.login) e então chama
-- o banco COM A IDENTIDADE DESSA PESSOA, pela porta única (public.imts). Quem decide o que pode é o banco, como na Mesa da web.
-- Depende de 017, 019, 047, 057, 065 e 066. Não mexe no motor nem na assinatura.
-- 1. Parâmetros do Mini App (endereço, validade do initData, limite de tentativas).
-- 2. adm.registro_servidor aceita a função telegram_app.
-- 3. Serviço: rt.tg_app_identificar (quem é o usuário do Telegram) e adm.tg_app_limite (limite de tentativas), só pela chave de serviço.
-- 4. Pessoa: rt.tg_mesa (as tarefas abertas, sem ids internos) e rt.tg_agir (concluir, decidir, aceitar, recusar), pela porta única.
-- 5. Bot: /mesa abre o Mini App e o /quadro ganha o botão "Abrir a Mesa" (botão web_app; em grupo a função telegram troca por link).

-- 1. Parâmetros ---------------------------------------------------------------------------------------------------------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('telegram_app.url', 'telegram', 'Endereço do Mini App do Telegram (a Mesa no Telegram). Produção: https://www.imts.global/tg.html; homologação: https://homolog.imts.global/tg.html. Vazio desliga o botão no bot',
  'texto', '"https://www.imts.global/tg.html"', '"https://www.imts.global/tg.html"', '{}', true, '{bot:menu,bot:/mesa,bot:/quadro}', 'P6 do inventário (Telegram Mini App, em imts.global)'),
 ('telegram_app.validade_segundos', 'telegram', 'Idade máxima, em segundos, dos dados de abertura do Mini App (auth_date do initData); passou, a pessoa fecha e abre de novo pelo bot',
  'inteiro', '3600', '3600', '{"min":60,"max":86400}', true, '{functions:telegram_app}', 'P6; documentação do Telegram, validação do initData'),
 ('telegram_app.tentativas_max', 'telegram', 'Tentativas sem sucesso (assinatura inválida, sem vínculo, recusa) aceitas na janela antes de bloquear, por IP ou por usuário do Telegram',
  'inteiro', '10', '10', '{"min":3,"max":100}', true, '{functions:telegram_app}', 'P6; segurança do Mini App'),
 ('telegram_app.janela_minutos', 'telegram', 'Janela, em minutos, da contagem de tentativas sem sucesso do Mini App',
  'inteiro', '15', '15', '{"min":1,"max":1440}', true, '{functions:telegram_app}', 'P6; segurança do Mini App'),
 ('telegram_app.pedidos_minuto', 'telegram', 'Pedidos por minuto aceitos de um mesmo usuário do Telegram no Mini App',
  'inteiro', '60', '60', '{"min":10,"max":600}', true, '{functions:telegram_app}', 'P6; segurança do Mini App')
on conflict (chave) do nothing;

-- 2. Registro do servidor aceita telegram_app (acrescenta à lista que já existir, sem apagar a de outras migrações) ----------------
do $$
declare d text; n text;
begin
  select conname, pg_get_constraintdef(oid) into n, d from pg_constraint
   where conrelid = 'adm.registro_servidor'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%funcao%';
  if d is not null and d not like '%''telegram_app''%' then
    execute format('alter table adm.registro_servidor drop constraint %I', n);
    execute format('alter table adm.registro_servidor add constraint %I %s', n, replace(d, 'ARRAY[', 'ARRAY[''telegram_app''::text, '));
  end if;
end $$;
create index if not exists registro_servidor_alvo on adm.registro_servidor (funcao, alvo, em desc);

-- Endereço do Mini App (nulo se desligado)
create or replace function rt._tg_app_url() returns text language sql stable security definer set search_path = '' as $$
  select nullif(btrim(adm.valor('telegram_app.url', '""') #>> '{}'), '') $$;

-- 3. Serviço -------------------------------------------------------------------------------------------------------------
-- Quem é este usuário do Telegram (id já conferido pela assinatura do initData). Não devolve nada além do necessário.
-- situacao: ok | sem_vinculo | sem_login | externo | simulado
create or replace function rt.tg_app_identificar(p_telegram_id bigint, p_simulado boolean default false) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_pessoa uuid; v_sim boolean; v_nome text; v_auth uuid;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select i.pseudonimo, i.simulado, i.nome into v_pessoa, v_sim, v_nome from rt_chave.identidade i
   where i.telegram_id = p_telegram_id and i.nome not like 'eliminado em %';
  if v_pessoa is null or not exists (select 1 from rt.pessoa where pseudonimo = v_pessoa) then
    if exists (select 1 from ext.telegram t where t.telegram_id = p_telegram_id and t.vinculado_em is not null) then
      return jsonb_build_object('situacao', 'externo');
    end if;
    return jsonb_build_object('situacao', 'sem_vinculo');
  end if;
  if v_sim <> p_simulado then return jsonb_build_object('situacao', 'simulado', 'pessoa', v_pessoa); end if;
  select auth_uid into v_auth from rt_chave.login where pseudonimo = v_pessoa;
  if v_auth is null then return jsonb_build_object('situacao', 'sem_login', 'pessoa', v_pessoa); end if;
  return jsonb_build_object('situacao', 'ok', 'pessoa', v_pessoa, 'auth_uid', v_auth, 'nome', v_nome);
end $$;

-- Limite de tentativas: conta no próprio registro do servidor, pela chave (hash do IP ou do usuário do Telegram, nunca o valor em claro).
-- Devolve o motivo do bloqueio, ou nulo se pode seguir.
create or replace function adm.tg_app_limite(p_chave text) returns text language plpgsql stable security definer set search_path = '' as $$
declare
  v_max int := coalesce((adm.valor('telegram_app.tentativas_max', '10') #>> '{}')::int, 10);
  v_jan int := coalesce((adm.valor('telegram_app.janela_minutos', '15') #>> '{}')::int, 15);
  v_ppm int := coalesce((adm.valor('telegram_app.pedidos_minuto', '60') #>> '{}')::int, 60);
  v_falhas int; v_pedidos int;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  if coalesce(p_chave, '') !~ '^(ip|tg):[0-9a-f]{16,64}$' then raise exception 'chave de limite inválida'; end if;
  select count(*) filter (where not ok and em > now() - make_interval(mins => v_jan)), count(*) filter (where em > now() - interval '1 minute')
    into v_falhas, v_pedidos
    from adm.registro_servidor where funcao = 'telegram_app' and alvo = p_chave and em > now() - make_interval(mins => greatest(v_jan, 1));
  if v_falhas >= v_max then return 'muitas tentativas sem sucesso: espere ' || v_jan || ' minutos e abra de novo pelo bot'; end if;
  if v_pedidos >= v_ppm then return 'muitos pedidos em sequência: espere um minuto'; end if;
  return null;
end $$;

-- 4. Pessoa (pela porta única, com o login de quem abriu) ----------------------------------------------------------------------
-- Aprovação de pagamento (GE-04 e GE-05) se confirma fora do Telegram, na Mesa da web (segregação; plano da fase 2, seção 4)
create or replace function rt._tg_restrito(p_cartao bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from rt.cartao c join org.tarefa x on x.id = c.tarefa
                  where c.id = p_cartao and c.jornada in ('GE-04', 'GE-05') and x.nome ~* '^(aprovar|autorizar)') $$;

-- As tarefas abertas de quem abriu o Mini App. Sem pseudônimos nem ids de etapa: só o número do cartão (o mesmo do bot) e o necessário.
create or replace function rt.tg_mesa() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); q jsonb;
begin
  q := coalesce(rt.quadro(v), '[]'::jsonb);
  return jsonb_build_object(
    'nome', (select nome from rt_chave.identidade where pseudonimo = v),
    'mesa_web', 'mesa.html',
    'cartoes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', (c->>'id')::bigint,
               'titulo', c->>'titulo',
               'coluna', c->>'coluna',
               'prazo', c->'prazo',
               'tipo', coalesce(c->>'tipo', 'fluxo'),
               'jornada', c->>'jornada',
               'jornada_nome', c->>'jornada_nome',
               'etapa_nome', c->>'etapa_nome',
               'de', case when coalesce((c->>'sou_dono')::boolean, true) then null
                          else (select i.nome from rt_chave.identidade i where i.pseudonimo = (c->>'dono')::uuid) end,
               'para_aceitar', (c->>'delegado_pessoa')::uuid is not distinct from v and coalesce(c->>'aceite', '') = 'pendente',
               'delegada', (c->>'delegado_pessoa') is not null and (c->>'delegado_pessoa')::uuid is distinct from v,
               'com_agente', coalesce((c->>'delegado_agente')::boolean, false),
               'opcoes', case when c->>'coluna' = 'decidir' and jsonb_typeof(c->'opcoes') = 'array'
                              then (select coalesce(jsonb_agg(o->>'rotulo' order by k), '[]') from jsonb_array_elements(c->'opcoes') with ordinality e(o, k)) end,
               'so_na_web', rt._tg_restrito((c->>'id')::bigint))
             order by ((c->>'delegado_pessoa')::uuid is not distinct from v and coalesce(c->>'aceite', '') = 'pendente') desc, (c->>'coluna' = 'decidir') desc, c->>'prazo')
        from jsonb_array_elements(q) c where c->>'coluna' <> 'feito'), '[]'::jsonb));
end $$;

-- Uma ação sobre um cartão. A regra continua nas funções da Mesa (rt.app_*); aqui só se escolhe qual chamar e se guarda a segregação.
-- p_opcao: posição (0, 1, ...) da opção de decisão, como o bot já faz; o destino interno da opção não sai do banco.
create or replace function rt.tg_agir(p_acao text, p_cartao bigint, p_opcao int default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); c rt.cartao; v_para text; v_rot text;
begin
  select * into c from rt.cartao where id = p_cartao;
  if c.id is null then raise exception 'cartão #% não encontrado', p_cartao; end if;
  if p_acao in ('concluir', 'decidir') and rt._tg_restrito(p_cartao) then
    raise exception 'aprovação de pagamento se confirma fora do Telegram, na Mesa (segregação); o cartão #% segue aberto', p_cartao;
  end if;
  if p_acao = 'concluir' then
    perform rt.app_concluir(p_cartao);
    return jsonb_build_object('texto', 'Feito: #' || p_cartao || ' concluído.' || case when c.tipo = 'fluxo' then ' O fluxo seguiu; o que for seu chega aqui.' else '' end);
  elsif p_acao = 'decidir' then
    if c.coluna <> 'decidir' or p_opcao is null or p_opcao < 0 or jsonb_typeof(c.opcoes) <> 'array' or p_opcao >= jsonb_array_length(c.opcoes) then
      raise exception 'opção inválida para o cartão #%', p_cartao;
    end if;
    v_para := c.opcoes->p_opcao->>'para'; v_rot := c.opcoes->p_opcao->>'rotulo';
    perform rt.app_decidir(p_cartao, v_para);
    return jsonb_build_object('texto', 'Decidido: ' || coalesce(v_rot, 'opção ' || (p_opcao + 1)) || '. O fluxo seguiu.');
  elsif p_acao in ('aceitar', 'recusar') then
    perform rt.app_responder(p_cartao, p_acao = 'aceitar', null);
    return jsonb_build_object('texto', case when p_acao = 'aceitar' then 'Aceito: #' || p_cartao || ' está no seu quadro.' else 'Recusado: #' || p_cartao || ' volta para quem pediu.' end);
  end if;
  raise exception 'ação desconhecida: %', p_acao;
end $$;

insert into adm.api_funcao (nome, quem, descricao) values
 ('rt.tg_mesa', 'interno', 'Mesa no Telegram (Mini App): tarefas abertas de quem abriu'),
 ('rt.tg_agir', 'interno', 'Mesa no Telegram (Mini App): concluir, decidir, aceitar ou recusar')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;

-- 5. Bot: /mesa e o botão no /quadro ------------------------------------------------------------------------------------------
-- A interpretação que já existe fica como rt._interpretar_base (sem cópia: o que as migrações anteriores definiram continua valendo).
do $$
begin
  if to_regprocedure('rt._interpretar_base(uuid, text)') is null then
    alter function rt.interpretar(uuid, text) rename to _interpretar_base;
  end if;
end $$;

create or replace function rt.interpretar(p_pessoa uuid, p_texto text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t text := btrim(coalesce(p_texto, '')); cmd text; u text := rt._tg_app_url(); r jsonb;
  botao jsonb;
begin
  cmd := regexp_replace(lower(split_part(t, ' ', 1)), '@.*$', '');
  botao := case when u is not null then jsonb_build_array(jsonb_build_object('text', 'Abrir a Mesa', 'web_app', jsonb_build_object('url', u))) end;
  if cmd in ('/mesa', 'mesa') then
    if botao is null then return jsonb_build_object('texto', 'A Mesa no Telegram ainda não está ligada (parâmetro telegram_app.url). Use /quadro.'); end if;
    return jsonb_build_object('texto', 'Sua Mesa: tarefas abertas, decisões e pedidos para aceitar. Toque no botão para abrir.', 'botoes', jsonb_build_array(botao));
  end if;
  r := rt._interpretar_base(p_pessoa, p_texto);
  if botao is not null and (cmd in ('/quadro', 'quadro') or lower(t) in ('minhas tarefas', 'o que tenho')) then
    r := jsonb_set(r, '{botoes}', coalesce(r->'botoes', '[]'::jsonb) || jsonb_build_array(botao));
  elsif botao is not null and cmd in ('/start', '/ajuda', 'ajuda', '/help') then
    r := jsonb_set(r, '{texto}', to_jsonb((r->>'texto') || ' /mesa abre a Mesa aqui no Telegram.'));
  end if;
  return r;
end $$;

-- Permissões ------------------------------------------------------------------------------------------------------------------
revoke all on function rt._tg_app_url(), rt.tg_app_identificar(bigint, boolean), adm.tg_app_limite(text), rt._tg_restrito(bigint),
  rt.tg_mesa(), rt.tg_agir(text, bigint, int), rt.interpretar(uuid, text) from public, anon;
revoke all on function rt.tg_app_identificar(bigint, boolean), adm.tg_app_limite(text), rt._tg_restrito(bigint), rt.interpretar(uuid, text) from authenticated;
grant execute on function rt.tg_app_identificar(bigint, boolean), adm.tg_app_limite(text), rt.interpretar(uuid, text), rt._tg_app_url() to service_role;
grant execute on function rt.tg_mesa(), rt.tg_agir(text, bigint, int) to authenticated, service_role;


-- ===== 084_docs_google.sql =====
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


-- ===== 086_agentes_ia.sql =====
-- Agentes com IA real para as tarefas de agente (executor A), B39 (21/10/2026).
-- Problema: no modo assistido (062) toda tarefa A de instância real e interativa virava cartão para uma pessoa do círculo,
-- porque não havia adaptador de IA. A função ia (070) já fala com dois provedores (Anthropic e Kimi, com reserva).
-- Regra nova, ligada pelo parâmetro motor.agente_ia (padrão: ligado):
--   tarefa A no modo assistido -> pedido na fila rt.fila_ia (prompt montado com tarefa, jornada, etapa, entradas, saídas e o que
--   já foi feito na instância); o token fica aguardando, como no cartão.
--   A função agente (nova, verify_jwt desligado, chamada pelo banco com X-IMTS-Chave) consome a fila, chama o provedor pelo
--   mesmo código da função ia (que continua com verify_jwt ligado, por causa do login) e grava o resultado como rascunho:
--     padrão: cartão de REVISÃO para a pessoa da raia, com o rascunho ligado ao cartão (rt.agente_ia_rascunho); concluir o
--     cartão faz o token seguir, como em qualquer cartão de fluxo;
--     motor.agente_ia_autonomo ligado: o agente conclui a tarefa sem revisão e o token segue.
--   Sem provedor configurado, sem endereço das funções, limite diário atingido, orçamento mensal esgotado ou falha nos dois
--   provedores (depois de motor.agente_ia_tentativas): cai no cartão humano de antes, com o motivo registrado.
-- Instância simulada, modo assistido desligado e o parâmetro desligado seguem como antes.
-- Como: rt._avancar ganha um trecho mínimo (troca conferida, como na 078) que chama rt._agente_ia_enfileirar.
-- Auditoria: rt.evento (delegado ao agente, cartão criado, fim), adm.historico (objeto agente_ia, desfecho de cada pedido)
-- e adm.registro_servidor (cada chamada da função, com tokens; conta no orçamento mensal ia.orcamento_mensal_tokens).

-- ---------- histórico: objeto novo ----------
do $$
declare v_def text; v_lista text[];
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint where conname = 'historico_objeto_check' and conrelid = 'adm.historico'::regclass;
  v_lista := array(select m[1] from regexp_matches(coalesce(v_def, ''), '''([a-z_]+)''', 'g') m);
  if not ('agente_ia' = any (v_lista)) then
    v_lista := v_lista || 'agente_ia'::text;
    alter table adm.historico drop constraint if exists historico_objeto_check;
    execute format('alter table adm.historico add constraint historico_objeto_check check (objeto in (%s))',
                   (select string_agg(quote_literal(x), ', ') from unnest(v_lista) x));
  end if;
end $$;

-- ---------- parâmetros ----------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('motor.agente_ia', 'global', 'Modo assistido: tarefa de agente (A) vai à fila da IA (função agente) em vez de virar cartão; sem IA disponível, volta ao cartão',
  'booleano', 'true', 'true', '{}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_autonomo', 'global', 'Agente de IA conclui a tarefa sem revisão humana; desligado, o rascunho vira cartão de revisão para a pessoa da raia',
  'booleano', 'false', 'false', '{}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_chamadas_dia', 'global', 'Limite diário de pedidos ao agente de IA (horário de Fortaleza); atingido, a tarefa vira cartão humano',
  'inteiro', '200', '200', '{"min": 0, "max": 100000}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_tokens_dia', 'global', 'Limite diário de tokens do agente de IA (entrada mais saída); atingido, a tarefa vira cartão humano',
  'inteiro', '400000', '400000', '{"min": 0, "max": 100000000}', true, '{}', 'Agentes com IA real (B39), 21/10/2026'),
 ('motor.agente_ia_tentativas', 'global', 'Tentativas por pedido quando os provedores falham; esgotadas, a tarefa vira cartão humano',
  'inteiro', '2', '2', '{"min": 1, "max": 5}', true, '{}', 'Agentes com IA real (B39), 21/10/2026')
on conflict (chave) do nothing;

-- ---------- fila ----------
create table if not exists rt.fila_ia (
  id             bigint generated always as identity primary key,
  instancia      bigint not null references rt.instancia(id),
  no             text not null,
  tarefa         bigint not null references org.tarefa(id),
  circulo        smallint not null,
  jornada        text not null,
  etapa          bigint references org.etapa(id),
  prompt         text not null,
  contexto       jsonb not null default '{}',
  na_fila        boolean not null,                  -- false: nem entrou na fila (IA indisponível na hora), foi direto ao cartão
  estado         text not null default 'pendente' check (estado in ('pendente', 'executando', 'feito', 'erro', 'cancelado')),
  tentativas     int not null default 0,
  resultado      text,                              -- rascunho devolvido pela IA
  provedor       text,
  modelo         text,
  tokens_entrada int,
  tokens_saida   int,
  motivo         text,                              -- por que caiu no cartão humano ou voltou à fila
  desfecho       text check (desfecho in ('revisao', 'autonomo', 'cartao_humano')),
  cartao         bigint references rt.cartao(id),
  criado_em      timestamptz not null default now(),
  iniciado_em    timestamptz,
  concluido_em   timestamptz
);
create index if not exists fila_ia_pendente on rt.fila_ia (id) where estado in ('pendente', 'executando');
create index if not exists fila_ia_instancia on rt.fila_ia (instancia);
create index if not exists fila_ia_cartao on rt.fila_ia (cartao) where cartao is not null;
create index if not exists fila_ia_criado on rt.fila_ia (criado_em);
create unique index if not exists fila_ia_um_por_no on rt.fila_ia (instancia, no) where estado in ('pendente', 'executando');
alter table rt.fila_ia enable row level security;   -- sem política: ninguém lê pela API; o Admin vê pelo resumo e a pessoa pelo rascunho do seu cartão
revoke all on rt.fila_ia from public, anon, authenticated;
grant all on rt.fila_ia to service_role;

-- ---------- uso do dia (horário de Fortaleza) ----------
create or replace function rt._agente_ia_uso_hoje() returns jsonb language sql stable security definer set search_path = '' as $$
  with h as (select date_trunc('day', now() at time zone 'America/Fortaleza') at time zone 'America/Fortaleza' as ini)
  select jsonb_build_object(
    'chamadas', (select coalesce(sum(greatest(f.tentativas, 1)), 0) from rt.fila_ia f, h where f.na_fila and f.criado_em >= h.ini),
    'tokens', (select coalesce(sum(coalesce(f.tokens_entrada, 0) + coalesce(f.tokens_saida, 0)), 0) from rt.fila_ia f, h where f.concluido_em >= h.ini)) $$;

-- ---------- a IA está disponível? devolve o motivo quando não está ----------
create or replace function rt._agente_ia_indisponivel(p_checar_endereco boolean default true) returns text
language plpgsql stable security definer set search_path = '' as $$
declare u jsonb := rt._agente_ia_uso_hoje(); lim_c bigint; lim_t bigint; teto bigint;
begin
  if rt._segredo('anthropic_chave') is null
     and (rt._segredo('kimi_chave') is null or coalesce(adm.valor('ia.kimi_url', '""') #>> '{}', '') = '' or coalesce(adm.valor('ia.kimi_modelo', '""') #>> '{}', '') = '') then
    return 'nenhum provedor de IA configurado (falta anthropic_chave ou kimi_chave no cofre)'; end if;
  if p_checar_endereco and rt._url_funcao('agente') is null then
    return 'endereço das funções não configurado (servidor.url_funcoes)'; end if;
  lim_c := coalesce((adm.valor('motor.agente_ia_chamadas_dia', '200') #>> '{}')::bigint, 200);
  if (u->>'chamadas')::bigint >= lim_c then return 'limite diário de chamadas do agente de IA atingido (' || lim_c || ')'; end if;
  lim_t := coalesce((adm.valor('motor.agente_ia_tokens_dia', '400000') #>> '{}')::bigint, 400000);
  if (u->>'tokens')::bigint >= lim_t then return 'limite diário de tokens do agente de IA atingido (' || lim_t || ')'; end if;
  teto := coalesce((adm.valor('ia.orcamento_mensal_tokens', '0') #>> '{}')::bigint, 0);
  if adm._ia_usado_no_mes() >= teto then return 'orçamento mensal da IA esgotado (ia.orcamento_mensal_tokens)'; end if;
  return null;
end $$;

-- ---------- prompt: só o que o modelo e a instância já têm (sem nome de pessoa) ----------
create or replace function rt._agente_ia_prompt(p_inst bigint, p_tarefa bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare t record; v text; ctx jsonb;
begin
  select tf.id, tf.nome, tf.raia, tf.ordem, tf.condicao, e.id as etapa_id, e.numero, e.nome as etapa_nome, e.modo::text as modo, e.risco::text as risco,
         j.codigo, j.nome as jornada_nome, j.objetivo, c.nome as circulo_nome
    into t from org.tarefa tf join org.etapa e on e.id = tf.etapa join org.jornada j on j.codigo = e.jornada left join org.circulo c on c.numero = j.circulo
   where tf.id = p_tarefa;
  ctx := jsonb_build_object(
    'tarefa', t.nome, 'papel', t.raia, 'jornada', t.codigo, 'etapa', t.numero, 'circulo', t.circulo_nome,
    'entradas', (select coalesce(jsonb_agg(jsonb_build_object('produto', produto, 'origem', origem) order by id), '[]') from org.entrada where etapa = t.etapa_id),
    'saidas', (select coalesce(jsonb_agg(jsonb_build_object('produto', produto, 'destinos', destinos) order by id), '[]') from org.saida where etapa = t.etapa_id),
    'tarefas_da_etapa', (select coalesce(jsonb_agg(x.nome || ' (' || x.executor || ')' order by x.ordem), '[]') from org.tarefa x where x.etapa = t.etapa_id),
    'feito_na_instancia', (select coalesce(jsonb_agg(y.nome order by y.id), '[]') from (
        select ev.id, tx.nome from rt.evento ev join org.tarefa tx on tx.id = ev.tarefa
         where ev.instancia = p_inst and ev.tipo in ('fim', 'concluido') and ev.tarefa is not null order by ev.id desc limit 30) y),
    'rascunhos_anteriores', (select coalesce(jsonb_agg(jsonb_build_object('tarefa', z.nome, 'texto', left(z.resultado, 1500)) order by z.id), '[]') from (
        select f.id, tx.nome, f.resultado from rt.fila_ia f join org.tarefa tx on tx.id = f.tarefa
         where f.instancia = p_inst and f.estado = 'feito' and f.resultado is not null order by f.id desc limit 3) z));
  v := 'Tarefa: ' || t.nome || E'\n'
    || 'Papel: ' || t.raia || coalesce(' (círculo ' || t.circulo_nome || ')', '') || E'\n'
    || 'Jornada: ' || t.codigo || ' ' || t.jornada_nome || coalesce(E'\nObjetivo da jornada: ' || t.objetivo, '') || E'\n'
    || 'Etapa ' || t.numero || ': ' || t.etapa_nome || ' (modo ' || coalesce(t.modo, '?') || ', risco ' || coalesce(t.risco, '?') || ')' || E'\n'
    || coalesce('Condição da tarefa: ' || t.condicao || E'\n', '')
    || E'\nEntradas da etapa:\n' || coalesce((select string_agg('- ' || (e->>'produto') || ' (vem de ' || (e->>'origem') || ')', E'\n') from jsonb_array_elements(ctx->'entradas') e), '- nenhuma registrada')
    || E'\n\nSaídas esperadas da etapa:\n' || coalesce((select string_agg('- ' || (s->>'produto') || ' (para ' || array_to_string(array(select jsonb_array_elements_text(s->'destinos')), ', ') || ')', E'\n') from jsonb_array_elements(ctx->'saidas') s), '- nenhuma registrada')
    || E'\n\nTarefas da etapa, em ordem:\n' || coalesce((select string_agg('- ' || x, E'\n') from jsonb_array_elements_text(ctx->'tarefas_da_etapa') x), '- nenhuma')
    || E'\n\nJá feito nesta instância (mais recente primeiro):\n' || coalesce((select string_agg('- ' || x, E'\n') from jsonb_array_elements_text(ctx->'feito_na_instancia') x), '- nada ainda')
    || coalesce(E'\n\nRascunhos anteriores do agente nesta instância:\n' || (select string_agg('### ' || (r->>'tarefa') || E'\n' || (r->>'texto'), E'\n\n') from jsonb_array_elements(ctx->'rascunhos_anteriores') r), '');
  return jsonb_build_object('prompt', left(v, 20000), 'contexto', ctx);
end $$;

-- ---------- pede à função agente que consuma a fila (pelo pg_net, depois do commit); sem endereço, a rotina tenta depois ----------
create or replace function rt._agente_ia_chamar() returns bigint language plpgsql security definer set search_path = '' as $$
declare u text := rt._url_funcao('agente');
begin
  if u is null or rt._segredo('imts_funcao_chave') is null or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then return null; end if;
  return net.http_post(url := u, headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{"acao":"agente_executar"}'::jsonb, timeout_milliseconds := 120000);
end $$;

-- ---------- cartão para pessoa: revisão do rascunho, ou o cartão humano de antes (com o motivo) ----------
create or replace function rt._agente_ia_cartao(p_fila bigint, p_revisao boolean, p_motivo text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_ia; ins rt.instancia; v_tar record; v_dono uuid; v_card bigint; v_ini timestamptz;
begin
  select * into f from rt.fila_ia where id = p_fila;
  select * into ins from rt.instancia where id = f.instancia;
  select t.id, t.nome, t.raia, t.executor, e.id as etapa_id into v_tar from org.tarefa t join org.etapa e on e.id = t.etapa where t.id = f.tarefa;
  v_dono := coalesce(rt._pessoa(rt._raia_humana(v_tar.raia), ins.motor), rt._pessoa('Líder do círculo', ins.motor));
  v_ini := greatest(coalesce(ins.relogio, now()), now());
  insert into rt.cartao (tipo, titulo, circulo, instancia, no, jornada, etapa, tarefa, papel, dono, criado_por, origem, prazo, simulado)
  values ('fluxo',
          case when p_revisao then left('Revisar rascunho da IA: ' || v_tar.nome, 200) else v_tar.nome || ' (assistida: ' || lower(v_tar.raia) || ')' end,
          ins.motor, ins.id, f.no, ins.jornada, v_tar.etapa_id, v_tar.id, v_tar.raia, v_dono, v_dono, case when p_revisao then 'agente' else 'motor' end,
          v_ini + make_interval(mins => coalesce((select max_minutos from rt.parametro_simulacao where executor = 'P'), 240)::int), false)
  returning id into v_card;
  perform rt._ev(ins.id, v_card, 'cartao_criado',
                 case when p_revisao then 'revisar rascunho da IA: ' || v_tar.nome else left('a fazer: ' || v_tar.nome || coalesce(' (agente de IA: ' || p_motivo || ')', ''), 500) end,
                 v_dono, ins.motor, ins.jornada, v_tar.etapa_id, v_tar.id, 'A', v_ini, null, false);
  update rt.fila_ia set cartao = v_card where id = p_fila;
  return v_card;
end $$;

-- ---------- auditoria do desfecho de cada pedido ----------
create or replace function rt._agente_ia_auditar(p_fila bigint, p_antes text, p_motivo text) returns void
language sql security definer set search_path = '' as $$
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  select 'agente_ia', 'fila:' || f.id, jsonb_build_object('estado', p_antes),
         jsonb_build_object('estado', f.estado, 'desfecho', f.desfecho, 'instancia', f.instancia, 'tarefa', f.tarefa, 'cartao', f.cartao,
                            'provedor', f.provedor, 'modelo', f.modelo, 'tentativas', f.tentativas, 'tokens_entrada', f.tokens_entrada, 'tokens_saida', f.tokens_saida),
         null, 'motor', left(p_motivo, 1000)
    from rt.fila_ia f where f.id = p_fila $$;

-- ---------- entrada: chamada por rt._avancar quando a tarefa A cai no modo assistido ----------
-- Devolve true quando cuidou da tarefa (pedido na fila, ou cartão humano com o motivo); false quando o fluxo segue como antes.
create or replace function rt._agente_ia_enfileirar(p_inst bigint, p_no text, p_tarefa bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare ins rt.instancia; v_tar record; v_motivo text; p jsonb; v_id bigint;
begin
  if not coalesce((adm.valor('motor.agente_ia', 'true') #>> '{}')::boolean, true) then return false; end if;
  select * into ins from rt.instancia where id = p_inst;
  if ins.id is null or ins.simulado or not ins.interativo then return false; end if;
  select t.id, t.nome, t.executor, e.id as etapa_id into v_tar from org.tarefa t join org.etapa e on e.id = t.etapa where t.id = p_tarefa;
  if v_tar.id is null or v_tar.executor <> 'A' then return false; end if;

  v_motivo := rt._agente_ia_indisponivel(true);
  p := rt._agente_ia_prompt(p_inst, p_tarefa);
  insert into rt.fila_ia (instancia, no, tarefa, circulo, jornada, etapa, prompt, contexto, na_fila, estado, motivo, desfecho, concluido_em)
  values (p_inst, p_no, p_tarefa, ins.motor, ins.jornada, v_tar.etapa_id, p->>'prompt', p->'contexto', v_motivo is null,
          case when v_motivo is null then 'pendente' else 'erro' end, v_motivo,
          case when v_motivo is not null then 'cartao_humano' end, case when v_motivo is not null then now() end)
  returning id into v_id;
  insert into rt.token (instancia, no, estado) values (p_inst, p_no, 'aguardando');
  if v_motivo is not null then
    -- IA indisponível: o cartão humano de antes, com o motivo no evento e no pedido
    perform rt._agente_ia_cartao(v_id, false, v_motivo);
    perform rt._agente_ia_auditar(v_id, null, v_motivo);
    return true;
  end if;
  perform rt._ev(p_inst, null, 'delegado', left('ao agente de IA: ' || v_tar.nome || ' (pedido ' || v_id || ')', 500), null, ins.motor, ins.jornada,
                 v_tar.etapa_id, v_tar.id, 'A', greatest(coalesce(ins.relogio, now()), now()), null, false);
  perform rt._agente_ia_chamar();
  return true;
end $$;

-- ---------- falha: volta à fila enquanto houver tentativa; esgotou (ou falha definitiva), cartão humano ----------
create or replace function rt._agente_ia_falhar(p_fila bigint, p_motivo text, p_definitivo boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_ia; v_max int := coalesce((adm.valor('motor.agente_ia_tentativas', '2') #>> '{}')::int, 2); v_card bigint;
begin
  select * into f from rt.fila_ia where id = p_fila for update;
  if f.id is null then raise exception 'pedido da IA inexistente'; end if;
  if f.estado not in ('pendente', 'executando') then return jsonb_build_object('fila', f.id, 'desfecho', 'ignorado', 'estado', f.estado); end if;
  if not exists (select 1 from rt.token where instancia = f.instancia and no = f.no and estado = 'aguardando') then
    update rt.fila_ia set estado = 'cancelado', motivo = 'a instância não espera mais esta tarefa', concluido_em = now() where id = p_fila;
    perform rt._agente_ia_auditar(p_fila, f.estado, 'a instância não espera mais esta tarefa');
    return jsonb_build_object('fila', f.id, 'desfecho', 'cancelado');
  end if;
  if not coalesce(p_definitivo, false) and f.tentativas < v_max then
    update rt.fila_ia set estado = 'pendente', motivo = left(p_motivo, 1000) where id = p_fila;
    return jsonb_build_object('fila', f.id, 'desfecho', 'nova_tentativa', 'tentativas', f.tentativas);
  end if;
  update rt.fila_ia set estado = 'erro', motivo = left(p_motivo, 1000), desfecho = 'cartao_humano', concluido_em = now() where id = p_fila;
  v_card := rt._agente_ia_cartao(p_fila, false, left(p_motivo, 300));
  perform rt._agente_ia_auditar(p_fila, f.estado, p_motivo);
  return jsonb_build_object('fila', f.id, 'desfecho', 'cartao_humano', 'cartao', v_card);
end $$;

-- ---------- função agente: pega o lote ----------
create or replace function rt.agente_ia_pegar(p_lote int default 5) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record; v_motivo text; itens jsonb := '[]'; degradados int := 0;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  -- quem ficou executando por mais de 15 minutos (a função caiu no meio) volta para a fila
  update rt.fila_ia set estado = 'pendente', motivo = 'execução interrompida' where estado = 'executando' and iniciado_em < now() - interval '15 minutes';
  for r in select id from rt.fila_ia where estado = 'pendente' order by id limit greatest(least(coalesce(p_lote, 5), 20), 1) for update skip locked loop
    v_motivo := case when not coalesce((adm.valor('motor.agente_ia', 'true') #>> '{}')::boolean, true) then 'agente de IA desligado (motor.agente_ia)'
                     else rt._agente_ia_indisponivel(false) end;
    if v_motivo is not null then
      perform rt._agente_ia_falhar(r.id, v_motivo, true); degradados := degradados + 1; continue;
    end if;
    update rt.fila_ia set estado = 'executando', tentativas = tentativas + 1, iniciado_em = now() where id = r.id;
    itens := itens || (select jsonb_build_object('id', f.id, 'prompt', f.prompt, 'tarefa', t.nome, 'tentativa', f.tentativas)
                         from rt.fila_ia f join org.tarefa t on t.id = f.tarefa where f.id = r.id);
  end loop;
  return jsonb_build_object('itens', itens, 'degradados', degradados, 'config', jsonb_build_object(
    'provedor', coalesce(adm.valor('ia.provedor', '"anthropic"') #>> '{}', 'anthropic'),
    'modelo', adm.valor('ia.modelo', '"claude-sonnet-5-5"') #>> '{}',
    'kimi_modelo', nullif(adm.valor('ia.kimi_modelo', '""') #>> '{}', ''),
    'kimi_url', nullif(rtrim(coalesce(adm.valor('ia.kimi_url', '""') #>> '{}', ''), '/'), '')));
end $$;

-- ---------- função agente: grava o resultado (rascunho) e decide revisão ou conclusão autônoma ----------
create or replace function rt.agente_ia_concluir(p_fila bigint, p_resultado text, p_provedor text, p_modelo text,
  p_tokens_entrada int default null, p_tokens_saida int default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare f rt.fila_ia; ins rt.instancia; v_card bigint; v_quando timestamptz; v_estado text; v_auto boolean;
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  select * into f from rt.fila_ia where id = p_fila for update;
  if f.id is null then raise exception 'pedido da IA inexistente'; end if;
  if f.estado not in ('pendente', 'executando') then return jsonb_build_object('fila', f.id, 'desfecho', 'ignorado', 'estado', f.estado); end if;
  if coalesce(btrim(p_resultado), '') = '' then return rt._agente_ia_falhar(p_fila, 'a IA devolveu resposta vazia', false); end if;
  if not exists (select 1 from rt.token where instancia = f.instancia and no = f.no and estado = 'aguardando') then
    return rt._agente_ia_falhar(p_fila, 'a instância não espera mais esta tarefa', true); end if;
  v_auto := coalesce((adm.valor('motor.agente_ia_autonomo', 'false') #>> '{}')::boolean, false);
  update rt.fila_ia set estado = 'feito', resultado = left(p_resultado, 20000), provedor = left(p_provedor, 40), modelo = left(p_modelo, 120),
         tokens_entrada = p_tokens_entrada, tokens_saida = p_tokens_saida, motivo = null, concluido_em = now(),
         desfecho = case when v_auto then 'autonomo' else 'revisao' end
   where id = p_fila;

  if not v_auto then
    -- human-in-the-loop: cartão de revisão com o rascunho; concluir o cartão faz o token seguir
    v_card := rt._agente_ia_cartao(p_fila, true);
    perform rt._agente_ia_auditar(p_fila, f.estado, 'rascunho pronto para revisão');
    return jsonb_build_object('fila', f.id, 'desfecho', 'revisao', 'cartao', v_card);
  end if;

  -- autônomo: o agente conclui a tarefa e o token segue (como a conclusão de cartão de fluxo)
  select * into ins from rt.instancia where id = f.instancia for update;
  v_quando := greatest(coalesce(ins.relogio, now()), now());
  perform rt._ev(f.instancia, null, 'fim', left('concluída pelo agente de IA (' || coalesce(p_provedor, '?') || ', sem revisão)', 500), null, ins.motor, ins.jornada,
                 f.etapa, f.tarefa, 'A', least(f.criado_em, v_quando), v_quando, false);
  update rt.instancia set relogio = v_quando where id = f.instancia;
  perform rt._trocas_da_etapa(f.instancia, f.etapa);
  delete from rt.token where instancia = f.instancia and no = f.no and estado = 'aguardando';
  insert into rt.token (instancia, no) select f.instancia, para from rt.fluxo where jornada = f.jornada and de = f.no order by id;
  perform rt._agente_ia_auditar(p_fila, f.estado, 'concluída pelo agente de IA sem revisão');
  v_estado := rt._avancar(f.instancia);
  return jsonb_build_object('fila', f.id, 'desfecho', 'autonomo', 'instancia', v_estado);
end $$;

-- ---------- função agente: falha nos provedores ----------
create or replace function rt.agente_ia_falhar(p_fila bigint, p_motivo text, p_definitivo boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then raise exception 'só pela chave de serviço'; end if;
  return rt._agente_ia_falhar(p_fila, coalesce(nullif(btrim(p_motivo), ''), 'falha sem detalhe'), p_definitivo);
end $$;

-- ---------- Mesa: o rascunho ligado ao cartão (quem é dono ou recebeu a tarefa, ou aprova no círculo) ----------
create or replace function rt.agente_ia_rascunho(p_cartao bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu(); c rt.cartao; f rt.fila_ia;
begin
  select * into c from rt.cartao where id = p_cartao;
  if c.id is null then raise exception 'cartão inexistente'; end if;
  if v is null or not (rt._pode_agir(c, v) or rt.pode(v, c.empresa, c.circulo, 'aprovar')) then raise exception 'sem acesso a este cartão'; end if;
  select * into f from rt.fila_ia where cartao = p_cartao order by id desc limit 1;
  if f.id is null then return null; end if;
  return jsonb_build_object('cartao', c.id, 'tarefa', (select nome from org.tarefa where id = f.tarefa), 'desfecho', f.desfecho,
    'rascunho', f.resultado, 'provedor', f.provedor, 'modelo', f.modelo, 'gerado_em', f.concluido_em, 'motivo', f.motivo,
    'aviso', case when f.desfecho = 'revisao' then 'Rascunho feito por IA: confira antes de concluir o cartão.' end);
end $$;

-- ---------- Admin: conferência ----------
create or replace function adm.agente_ia_resumo() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u jsonb;
begin
  if not rt.chamada_servico() then perform adm._so_admin(); end if;
  u := rt._agente_ia_uso_hoje();
  return jsonb_build_object(
    'ligado', coalesce((adm.valor('motor.agente_ia', 'true') #>> '{}')::boolean, true),
    'autonomo', coalesce((adm.valor('motor.agente_ia_autonomo', 'false') #>> '{}')::boolean, false),
    'modo_assistido', coalesce((adm.valor('motor.maquina_assistida', 'false') #>> '{}')::boolean, false),
    'provedor', coalesce(adm.valor('ia.provedor', '"anthropic"') #>> '{}', 'anthropic'),
    'chave_anthropic', rt._segredo('anthropic_chave') is not null,
    'chave_kimi', rt._segredo('kimi_chave') is not null,
    'endereco_funcoes', rt._url_funcao('agente') is not null,
    'disponivel', rt._agente_ia_indisponivel(true) is null,
    'motivo_indisponivel', rt._agente_ia_indisponivel(true),
    'tarefas_a', (select count(*) from org.tarefa where executor = 'A'),
    'hoje', u || jsonb_build_object('limite_chamadas', (adm.valor('motor.agente_ia_chamadas_dia', '200') #>> '{}')::bigint,
                                    'limite_tokens', (adm.valor('motor.agente_ia_tokens_dia', '400000') #>> '{}')::bigint),
    'por_estado', (select jsonb_object_agg(e, (select count(*) from rt.fila_ia where estado = e)) from unnest(array['pendente', 'executando', 'feito', 'erro', 'cancelado']) e),
    'por_desfecho', (select jsonb_object_agg(d, (select count(*) from rt.fila_ia where desfecho = d)) from unnest(array['revisao', 'autonomo', 'cartao_humano']) d),
    'revisoes_abertas', (select count(*) from rt.fila_ia f join rt.cartao c on c.id = f.cartao where f.desfecho = 'revisao' and c.coluna <> 'feito'),
    'tokens_30_dias', (select coalesce(sum(coalesce(tokens_entrada, 0) + coalesce(tokens_saida, 0)), 0) from rt.fila_ia where concluido_em >= now() - interval '30 days'),
    'motivos_recentes', (select coalesce(jsonb_agg(jsonb_build_object('motivo', m, 'vezes', q) order by q desc), '[]') from (
        select motivo as m, count(*) as q from rt.fila_ia where motivo is not null and criado_em >= now() - interval '7 days' group by motivo order by count(*) desc limit 5) x));
end $$;

-- ---------- trecho mínimo em rt._avancar (troca conferida, sem copiar o corpo) ----------
do $$
declare d text := pg_get_functiondef('rt._avancar(bigint, integer)'::regprocedure); a text;
  alvo text := $q$      if ins.interativo and (v_tar.executor in ('P', 'H', 'X') or (v_tar.executor in ('A', 'R') and rt._assistido(ins))) then$q$;
begin
  if position('rt._agente_ia_enfileirar' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, alvo, ''))) / length(alvo) <> 1 then raise exception 'rt._avancar não tem o texto esperado: revisar a 086'; end if;
  a := d;
  d := replace(d, alvo, $q$      -- agente de IA (086): tarefa A no modo assistido vai à fila da IA (ou ao cartão humano com o motivo); o token espera
      if v_tar.executor = 'A' and ins.interativo and rt._assistido(ins) and rt._agente_ia_enfileirar(p_inst, tk.no, v_tar.id) then
        continue;
      end if;
$q$ || alvo);
  if d = a or (length(d) - length(replace(d, 'rt._agente_ia_enfileirar(', ''))) / length('rt._agente_ia_enfileirar(') <> 1 then
    raise exception 'rt._avancar não tem o texto esperado: revisar a 086'; end if;
  execute d;
end $$;

-- ---------- rotina: a cada 5 minutos, se houver pedido pendente, chama a função agente (rede de segurança do pg_net) ----------
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'imts-agente-ia';
    perform cron.schedule('imts-agente-ia', '*/5 * * * *', $c$select rt._agente_ia_chamar() where exists (select 1 from rt.fila_ia where estado = 'pendente')$c$);
  end if;
end $$;

-- ---------- permissões ----------
revoke all on function rt._agente_ia_uso_hoje(), rt._agente_ia_indisponivel(boolean), rt._agente_ia_prompt(bigint, bigint), rt._agente_ia_chamar(),
  rt._agente_ia_cartao(bigint, boolean, text), rt._agente_ia_auditar(bigint, text, text), rt._agente_ia_enfileirar(bigint, text, bigint),
  rt._agente_ia_falhar(bigint, text, boolean), rt.agente_ia_pegar(int), rt.agente_ia_concluir(bigint, text, text, text, int, int),
  rt.agente_ia_falhar(bigint, text, boolean), rt.agente_ia_rascunho(bigint), adm.agente_ia_resumo() from public, anon, authenticated;
grant execute on function rt._agente_ia_uso_hoje(), rt._agente_ia_indisponivel(boolean), rt._agente_ia_prompt(bigint, bigint), rt._agente_ia_chamar(),
  rt._agente_ia_cartao(bigint, boolean, text), rt._agente_ia_auditar(bigint, text, text), rt._agente_ia_enfileirar(bigint, text, bigint),
  rt._agente_ia_falhar(bigint, text, boolean), rt.agente_ia_pegar(int), rt.agente_ia_concluir(bigint, text, text, text, int, int),
  rt.agente_ia_falhar(bigint, text, boolean) to service_role;
grant execute on function rt.agente_ia_rascunho(bigint), adm.agente_ia_resumo() to authenticated, service_role;

insert into adm.api_funcao (nome, quem, descricao) values
  ('adm.agente_ia_resumo', 'interno', 'Agente de IA das tarefas A: ligado, autônomo, provedores, uso do dia contra os limites, fila por estado e desfecho, motivos de queda para o cartão'),
  ('rt.agente_ia_rascunho', 'interno', 'Rascunho do agente de IA ligado a um cartão de revisão (quem é dono, recebeu a tarefa ou aprova no círculo)')
on conflict (nome) do nothing;

insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('edge-agente', 'Função agente: executa a fila das tarefas de agente pela IA', 'ia', 'produção', null, 'Integração', 'pendente', '{anthropic_chave,imts_funcao_chave}', 'manual', null,
  'gravar anthropic_chave (ou kimi_chave com ia.kimi_url e ia.kimi_modelo) no cofre, preencher servidor.url_funcoes e implantar a função agente com verify_jwt desligado (o banco chama com X-IMTS-Chave)', '086, B39')
on conflict (codigo) do nothing;


-- ===== homolog_param.sql =====
-- homologação: links do aplicativo apontam para homolog.imts.global
update adm.parametro set valor = '"https://homolog.imts.global"' where chave = 'assinatura.url_app';
update adm.parametro set valor = '"https://homolog.imts.global/tg.html"' where chave = 'telegram_app.url';

commit;
