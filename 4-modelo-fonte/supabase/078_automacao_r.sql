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
begin;

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
commit;
