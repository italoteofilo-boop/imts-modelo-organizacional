-- Ajuste do painel (03/10/2026, E10 e Mesa): execuções interativas ainda abertas não têm fim, e os eventos de cartão não são passos.
-- Mesmo rt.painel() do 008, com o fim em andamento nomeado e só os eventos de execução de tarefa nas voltas e nas durações.
-- Uso: select rt.painel();
begin;

create or replace function rt.painel() returns jsonb language sql stable set search_path = '' as $$
with
ev as (select * from rt.evento),
inst as (select *, extract(epoch from fim - inicio) / 3600.0 as horas from rt.instancia),
voltas as (
  select instancia, count(*) > 0 as voltou from (
    select instancia, tarefa from ev where tarefa is not null and tipo = 'fim' group by 1, 2 having count(*) > 1) x group by 1),
etapa_dur as (
  select e.instancia, e.jornada, e.etapa, extract(epoch from max(e.fim) - min(e.inicio)) / 60 as minutos
    from ev e where e.tarefa is not null and e.tipo = 'fim' group by 1, 2, 3)
select jsonb_build_object(
  'gerado_em', now(),
  'modelo', jsonb_build_object(
    'circulos', (select count(*) from org.circulo), 'jornadas', (select count(*) from org.jornada),
    'etapas', (select count(*) from org.etapa), 'tarefas', (select count(*) from org.tarefa),
    'trocas', (select count(*) from org.troca), 'tarefas_ligadas', (select count(*) from rt.vinculo),
    'pessoas_simuladas', (select count(*) from rt.pessoa where simulado),
    'pessoas_reais', (select count(*) from rt.pessoa where not simulado)),
  'operacao', jsonb_build_object(
    'instancias', (select count(*) from inst),
    'instancias_reais', (select count(*) from inst where not simulado),
    'concluidas', (select count(*) from inst where estado = 'concluida'),
    'erros', (select count(*) from inst where estado = 'erro'),
    'eventos', (select count(*) from ev), 'eventos_reais', (select count(*) from ev where not simulado),
    'trocas_enviadas', (select count(*) from rt.troca_envio),
    'mensagens', (select count(*) from rt.mensagem),
    'a_apagar', (select count(*) from rt.v_a_apagar),
    'atualizacoes_pendentes', (select count(*) from rt.atualizacao where estado = 'pendente'),
    'versao_base', (select max(versao) from rt.versao_base)),
  'motores', (select jsonb_agg(jsonb_build_object(
      'circulo', m.circulo, 'nome', c.nome, 'motor', m.nome, 'estado', m.estado, 'versao', m.versao_base,
      'jornadas', (select count(*) from org.jornada j where j.circulo = m.circulo),
      'tarefas', cv.tarefas, 'tarefas_executadas', cv.tarefas_executadas,
      'instancias', (select count(*) from inst i where i.motor = m.circulo),
      'trocas_envia', (select count(*) from rt.troca_envio t where t.de_motor = m.circulo),
      'trocas_recebe', (select count(*) from rt.troca_envio t where t.para_motor = m.circulo)) order by m.circulo)
    from rt.motor m join org.circulo c on c.numero = m.circulo left join rt.v_cobertura cv on cv.motor = m.circulo),
  'jornadas', (select jsonb_agg(x order by x->>'codigo') from (
      select jsonb_build_object('codigo', j.codigo, 'nome', j.nome, 'circulo', j.circulo,
        'instancias', count(i.id),
        'horas_mediana', round((percentile_cont(0.5) within group (order by i.horas))::numeric, 1),
        'horas_p90', round((percentile_cont(0.9) within group (order by i.horas))::numeric, 1),
        'voltas_pct', round(100.0 * count(*) filter (where v.voltou) / nullif(count(i.id), 0), 1),
        'fins', (select jsonb_object_agg(f, n) from (select coalesce(fim_no, '(em andamento)') as f, count(*) as n from inst i2 where i2.jornada = j.codigo group by 1) y)) as x
        from org.jornada j join inst i on i.jornada = j.codigo left join voltas v on v.instancia = i.id
       group by j.codigo, j.nome, j.circulo) z),
  'etapas', (select jsonb_agg(x order by (x->>'jornada'), (x->>'etapa')::int) from (
      select jsonb_build_object('jornada', d.jornada, 'etapa', et.numero, 'nome', et.nome, 'modo', et.modo,
        'execucoes', count(*), 'min_mediana', round((percentile_cont(0.5) within group (order by d.minutos))::numeric, 0),
        'min_p75', round((percentile_cont(0.75) within group (order by d.minutos))::numeric, 0)) as x
        from etapa_dur d join org.etapa et on et.id = d.etapa group by d.jornada, et.numero, et.nome, et.modo) z),
  'executores', (select jsonb_agg(jsonb_build_object('executor', executor, 'tarefas', n, 'min_mediana', med) order by executor)
      from (select executor, count(*) n, round((percentile_cont(0.5) within group (order by extract(epoch from fim - inicio) / 60))::numeric, 1) med
              from ev where tarefa is not null and tipo = 'fim' group by 1) x),
  'trocas', (select jsonb_agg(jsonb_build_object('de', de_motor, 'para', para_motor, 'n', n) order by n desc)
      from (select de_motor, para_motor, count(*) n from rt.troca_envio group by 1, 2) x),
  'modelos', (select jsonb_agg(jsonb_build_object('nome', nome, 'versao', versao, 'tipo', tipo, 'dado', dado, 'amostras', amostras,
        'metricas', metricas, 'em_uso', em_uso, 'treinado_em', treinado_em) order by nome) from rt.modelo),
  'parametros_simulacao', (select jsonb_agg(jsonb_build_object('executor', executor, 'min', min_minutos, 'max', max_minutos) order by executor)
      from rt.parametro_simulacao)
)
$$;
revoke all on function rt.painel() from public;
grant execute on function rt.painel() to service_role;

commit;
