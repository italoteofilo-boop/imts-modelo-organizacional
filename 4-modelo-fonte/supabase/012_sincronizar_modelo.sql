-- Migração versionada do modelo (esquema org): leva uma versão nova do modelo à base sem perder o que o runtime já gravou.
-- Como usar: carregar a versão nova num esquema à parte (org_novo: 001 e 002 com "org." trocado por "org_novo."; ver preparar_versao.py),
-- rodar  select org.sincronizar_modelo();  e apagar o esquema org_novo.
-- Regra: o que o runtime referencia (círculo, jornada, etapa, tarefa, troca) é atualizado no lugar, casado pela chave natural,
-- e mantém o id; o resto (entradas, saídas, decisões, fontes, limites, parâmetros, gates, auditoria) é recarregado.
-- Se uma etapa, tarefa ou troca saiu do modelo e o runtime ainda a referencia, a migração para, e nada muda.
begin;

create or replace function org.sincronizar_modelo() returns jsonb
language plpgsql set search_path = '' as $$
declare
  r jsonb := '{}'::jsonb; n int; t text; cols text;
  simples text[] := array['dominio','limite','decisao_registrada','fonte_uso','jornada_fonte','cadeia_elo','evento','parametro','gate','achado_auditoria'];
begin
  if to_regnamespace('org_novo') is null then raise exception 'carregue a versão nova no esquema org_novo antes'; end if;

  -- 1. tipos de executor e círculos: atualizados no lugar
  insert into org.executor_tipo (codigo, nome, e_pessoa, e_maquina) select codigo, nome, e_pessoa, e_maquina from org_novo.executor_tipo
    on conflict (codigo) do update set nome = excluded.nome, e_pessoa = excluded.e_pessoa, e_maquina = excluded.e_maquina;
  select string_agg(format('%I = x.%I', column_name, column_name), ', ') into cols
    from information_schema.columns where table_schema = 'org' and table_name = 'circulo' and column_name <> 'numero';
  execute format('update org.circulo c set %s from org_novo.circulo x where x.numero = c.numero', cols);
  select string_agg(quote_ident(column_name), ', ') into cols from information_schema.columns where table_schema = 'org' and table_name = 'circulo';
  execute format('insert into org.circulo (%s) select %s from org_novo.circulo x where not exists (select 1 from org.circulo c where c.numero = x.numero)', cols, cols);

  -- 2. tabelas sem referência de fora: apagadas antes (os filhos primeiro)
  delete from org.entrada; delete from org.saida; delete from org.decisao_caminho;
  foreach t in array simples loop execute format('delete from org.%I', t); end loop;
  delete from org.cadeia; delete from org.fonte;

  -- 3. jornadas: atualizadas no lugar pelo código
  select string_agg(format('%I = x.%I', column_name, column_name), ', ') into cols
    from information_schema.columns where table_schema = 'org' and table_name = 'jornada' and column_name <> 'codigo';
  execute format('update org.jornada j set %s from org_novo.jornada x where x.codigo = j.codigo', cols);
  select string_agg(quote_ident(column_name), ', ') into cols from information_schema.columns where table_schema = 'org' and table_name = 'jornada';
  execute format('insert into org.jornada (%s) select %s from org_novo.jornada x where not exists (select 1 from org.jornada j where j.codigo = x.codigo)', cols, cols);
  get diagnostics n = row_count; r := r || jsonb_build_object('jornadas_novas', n);

  -- 4. etapas: casadas pelo nome dentro da jornada; a que mudou de nome, pelo número
  create temp table _me on commit drop as
    select o.id as velho, x.id as novo from org.etapa o join org_novo.etapa x on x.jornada = o.jornada and x.nome = o.nome;
  insert into _me select o.id, x.id from org.etapa o join org_novo.etapa x on x.jornada = o.jornada and x.numero = o.numero
   where o.id not in (select velho from _me) and x.id not in (select novo from _me);
  if exists (select 1 from org.etapa o where o.id not in (select velho from _me)
               and (exists (select 1 from rt.evento e where e.etapa = o.id) or exists (select 1 from rt.cartao c where c.etapa = o.id))) then
    raise exception 'uma etapa que saiu do modelo ainda é referenciada pelo runtime';
  end if;
  delete from org.tarefa where etapa in (select id from org.etapa where id not in (select velho from _me));
  delete from org.etapa where id not in (select velho from _me);
  update org.etapa set numero = -numero where id in (select velho from _me);          -- libera a unicidade (jornada, numero)
  update org.etapa o set numero = x.numero, nome = x.nome, dono = x.dono, modo = x.modo::text::org.modo, risco = x.risco::text::org.risco, classe_real = x.classe_real
    from _me m join org_novo.etapa x on x.id = m.novo where o.id = m.velho;
  insert into org.etapa (jornada, numero, nome, dono, modo, risco, classe_real)
    select x.jornada, x.numero, x.nome, x.dono, x.modo::text::org.modo, x.risco::text::org.risco, x.classe_real from org_novo.etapa x where x.id not in (select novo from _me);
  get diagnostics n = row_count; r := r || jsonb_build_object('etapas_novas', n);
  create temp table _e on commit drop as
    select o.id as velho, x.id as novo from org.etapa o join org_novo.etapa x on x.jornada = o.jornada and x.numero = o.numero;

  -- 5. tarefas: casadas pelo nome dentro da etapa; a que mudou de nome, pela ordem
  create temp table _mt on commit drop as
    select o.id as velho, x.id as novo from org.tarefa o join _e on _e.velho = o.etapa join org_novo.tarefa x on x.etapa = _e.novo and x.nome = o.nome;
  delete from _mt a using _mt b where a.velho = b.velho and a.novo > b.novo;        -- nome repetido na etapa: fica o primeiro
  delete from _mt a using _mt b where a.novo = b.novo and a.velho > b.velho;
  insert into _mt select o.id, x.id from org.tarefa o join _e on _e.velho = o.etapa join org_novo.tarefa x on x.etapa = _e.novo and x.ordem = o.ordem
   where o.id not in (select velho from _mt) and x.id not in (select novo from _mt);
  if exists (select 1 from org.tarefa o where o.id not in (select velho from _mt)
               and (exists (select 1 from rt.evento e where e.tarefa = o.id) or exists (select 1 from rt.cartao c where c.tarefa = o.id))) then
    raise exception 'uma tarefa que saiu do modelo ainda é referenciada pelo runtime';
  end if;
  delete from rt.vinculo where tarefa in (select id from org.tarefa where id not in (select velho from _mt));
  update rt.no set tarefa = null where tarefa in (select id from org.tarefa where id not in (select velho from _mt));
  delete from org.tarefa where id not in (select velho from _mt);
  update org.tarefa set ordem = -ordem where id in (select velho from _mt);
  update org.tarefa o set etapa = _e.velho, ordem = x.ordem, nome = x.nome, executor = x.executor, raia = x.raia, tipo_bpmn = x.tipo_bpmn, condicao = x.condicao
    from _mt m join org_novo.tarefa x on x.id = m.novo join _e on _e.novo = x.etapa where o.id = m.velho;
  insert into org.tarefa (etapa, ordem, nome, executor, raia, tipo_bpmn, condicao)
    select _e.velho, x.ordem, x.nome, x.executor, x.raia, x.tipo_bpmn, x.condicao from org_novo.tarefa x join _e on _e.novo = x.etapa where x.id not in (select novo from _mt);
  get diagnostics n = row_count; r := r || jsonb_build_object('tarefas_novas', n);

  -- 6. trocas: casadas por produto, origem e destino
  create temp table _mx on commit drop as
    select o.id as velho, x.id as novo from org.troca o join org_novo.troca x on x.produto = o.produto and x.de_circulo = o.de_circulo and x.para_circulo = o.para_circulo;
  if exists (select 1 from org.troca o where o.id not in (select velho from _mx) and exists (select 1 from rt.troca_envio e where e.troca = o.id)) then
    raise exception 'uma troca que saiu do modelo ainda é referenciada pelo runtime';
  end if;
  delete from org.troca where id not in (select velho from _mx);
  update org.troca o set via = x.via, sai_em = x.sai_em, entra_em = x.entra_em from _mx m join org_novo.troca x on x.id = m.novo where o.id = m.velho;
  insert into org.troca (produto, de_circulo, para_circulo, via, sai_em, entra_em)
    select produto, de_circulo, para_circulo, via, sai_em, entra_em from org_novo.troca x where x.id not in (select novo from _mx);
  get diagnostics n = row_count; r := r || jsonb_build_object('trocas_novas', n);

  -- 7. recarga do resto, com a etapa traduzida para o id que ficou
  insert into org.entrada (etapa, produto, origem) select _e.velho, x.produto, x.origem from org_novo.entrada x join _e on _e.novo = x.etapa order by x.id;
  insert into org.saida (etapa, produto, destinos) select _e.velho, x.produto, x.destinos from org_novo.saida x join _e on _e.novo = x.etapa order by x.id;
  insert into org.decisao_caminho (etapa, ordem, pergunta, quem, saidas) select _e.velho, x.ordem, x.pergunta, x.quem, x.saidas from org_novo.decisao_caminho x join _e on _e.novo = x.etapa order by x.id;
  select string_agg(quote_ident(column_name), ', ') into cols from information_schema.columns where table_schema = 'org' and table_name = 'fonte';
  execute format('insert into org.fonte (%s) select %s from org_novo.fonte', cols, cols);
  select string_agg(quote_ident(column_name), ', ') into cols from information_schema.columns where table_schema = 'org' and table_name = 'cadeia';
  execute format('insert into org.cadeia (%s) select %s from org_novo.cadeia', cols, cols);
  foreach t in array simples loop
    select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols from information_schema.columns
     where table_schema = 'org' and table_name = t and is_identity = 'NO';
    execute format('insert into org.%I (%s) select %s from org_novo.%I order by 1', t, cols, cols, t);
  end loop;

  -- 8. jornadas que saíram do modelo (só se nada as referencia)
  delete from org.jornada j where not exists (select 1 from org_novo.jornada x where x.codigo = j.codigo)
     and not exists (select 1 from rt.instancia i where i.jornada = j.codigo);

  select r || jsonb_build_object('jornadas', (select count(*) from org.jornada), 'etapas', (select count(*) from org.etapa),
         'tarefas', (select count(*) from org.tarefa), 'trocas', (select count(*) from org.troca),
         'conferencia', (select count(*) from org.tarefa) = (select count(*) from org_novo.tarefa)
                        and (select count(*) from org.etapa) = (select count(*) from org_novo.etapa)
                        and (select count(*) from org.entrada) = (select count(*) from org_novo.entrada)) into r;
  return r;
end $$;

revoke all on function org.sincronizar_modelo() from public;
grant execute on function org.sincronizar_modelo() to service_role;

commit;
