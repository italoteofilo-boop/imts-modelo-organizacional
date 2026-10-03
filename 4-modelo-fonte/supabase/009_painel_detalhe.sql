-- Detalhe de uma jornada para o drill-down do painel (E6): etapas, tarefas e as últimas execuções com os passos.
-- Uso: select rt.painel_detalhe('ID-01', 8);   e   select rt.painel_execucao(123);
begin;

create or replace function rt.painel_execucao(p_instancia bigint) returns jsonb
language sql stable set search_path = '' as $$
select jsonb_build_object('id', i.id, 'jornada', i.jornada, 'estado', i.estado, 'simulado', i.simulado, 'inicio', i.inicio, 'fim', i.fim,
  'fim_no', i.fim_no, 'passos', i.passos,
  'eventos', (select jsonb_agg(jsonb_build_array(
                 e.tipo, et.numero, e.tarefa, e.executor, coalesce(t.nome, e.resultado), coalesce(t.raia, ''),
                 extract(epoch from coalesce(e.inicio, e.fim) - i.inicio)::int, extract(epoch from coalesce(e.fim, e.inicio) - i.inicio)::int) order by e.id)
              from rt.evento e left join org.etapa et on et.id = e.etapa left join org.tarefa t on t.id = e.tarefa where e.instancia = i.id))
  from rt.instancia i where i.id = p_instancia $$;


create or replace function rt.painel_detalhe(p_jornada text, p_ultimas integer default 8) returns jsonb
language sql stable set search_path = '' as $$
with ev as (select * from rt.evento where jornada = p_jornada),
dur_t as (select tarefa, count(*) n, percentile_cont(0.5) within group (order by extract(epoch from fim - inicio) / 60) med
            from ev where tarefa is not null group by 1),
ult as (select id from rt.instancia where jornada = p_jornada order by id desc limit p_ultimas)
select jsonb_build_object(
  'jornada', p_jornada,
  'nome', (select nome from org.jornada where codigo = p_jornada),
  'circulo', (select circulo from org.jornada where codigo = p_jornada),
  'etapas', (select jsonb_agg(jsonb_build_object('n', e.numero, 'nome', e.nome, 'modo', e.modo, 'risco', e.risco, 'dono', e.dono,
      'tarefas', (select jsonb_agg(jsonb_build_object('id', t.id, 'ordem', t.ordem, 'nome', t.nome, 'executor', t.executor, 'raia', t.raia,
                    'sistema', v.sistema, 'execucoes', coalesce(d.n, 0), 'min_mediana', round(d.med::numeric, 1)) order by t.ordem)
                  from org.tarefa t left join rt.vinculo v on v.tarefa = t.id left join dur_t d on d.tarefa = t.id where t.etapa = e.id))
      order by e.numero) from org.etapa e where e.jornada = p_jornada),
  'execucoes', (select jsonb_agg(rt.painel_execucao(id) order by id desc) from ult)
) $$;

revoke all on function rt.painel_detalhe(text, integer) from public;
revoke all on function rt.painel_execucao(bigint) from public;
grant execute on function rt.painel_detalhe(text, integer), rt.painel_execucao(bigint) to service_role;

commit;
