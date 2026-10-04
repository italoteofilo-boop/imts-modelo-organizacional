-- Testes do motor (004 e 005). Roda numa transação e desfaz tudo no fim. Uso: psql -v ON_ERROR_STOP=1 -f testar_motor.sql
begin;

do $$
declare n int; m int; i1 bigint; i2 bigint; j record; v_inst bigint;
begin
  -- T1. Cada tarefa está ligada a um sistema coerente com o executor (G7)
  select count(*) into n from org.tarefa t left join rt.vinculo v on v.tarefa = t.id where v.tarefa is null;
  if n <> 0 then raise exception 'FALHA T1: % tarefas sem sistema', n; end if;
  select count(*) into n from rt.vinculo v join org.tarefa t on t.id = v.tarefa
   where not (v.sistema = case t.executor when 'P' then 'canal-pessoa' when 'H' then 'canal-pessoa' when 'A' then 'agente-ia'
                                      when 'R' then 'automacao' when 'C' then 'troca-circulo' when 'X' then 'canal-externo' end
              or (t.executor = 'R' and v.sistema in ('erp-contabil', 'banco', 'emissor-fiscal')));
  if n <> 0 then raise exception 'FALHA T1: % tarefas no sistema errado', n; end if;

  -- T2. Toda raia de pessoa tem usuário simulado em todos os motores que a usam
  select count(*) into n from (
    select distinct t.raia, jo.circulo from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada jo on jo.codigo = e.jornada
     where t.executor in ('P', 'H', 'X', 'C')) x
   where rt._pessoa(x.raia, x.circulo) is null;
  if n <> 0 then raise exception 'FALHA T2: % raias sem pessoa simulada', n; end if;
  if exists (select 1 from rt.pessoa where not simulado) then raise exception 'FALHA T2: pessoa real na carga'; end if;

  -- T3. O grafo bate com o modelo: todas as tarefas, cada uma num nó; toda jornada tem início e fim
  select count(*) into n from rt.no where tarefa is not null;
  if n <> (select count(*) from org.tarefa) then raise exception 'FALHA T3: % nós de tarefa', n; end if;
  select count(*) into n from org.jornada jo where not exists (select 1 from rt.no where jornada = jo.codigo and tipo = 'startEvent')
                                                  or not exists (select 1 from rt.no where jornada = jo.codigo and tipo = 'endEvent');
  if n <> 0 then raise exception 'FALHA T3: % jornadas sem início ou fim', n; end if;

  -- T4. As cinco jornadas da Identidade (piloto) rodam até um fim, 10 vezes cada
  for j in select codigo from org.jornada where circulo = 1 loop
    for k in 1..10 loop
      v_inst := rt.executar_simulada(j.codigo, k / 11.0, timestamptz '2026-10-05 08:00-03');
      if (select estado from rt.instancia where id = v_inst) <> 'concluida' then
        raise exception 'FALHA T4: % semente % terminou em %', j.codigo, k, (select detalhe from rt.instancia where id = v_inst);
      end if;
    end loop;
  end loop;

  -- T5. Mesma semente, mesmo caminho
  i1 := rt.executar_simulada('ID-02', 0.3, timestamptz '2026-10-05 08:00-03');
  i2 := rt.executar_simulada('ID-02', 0.3, timestamptz '2026-10-05 08:00-03');
  if (select array_agg(coalesce(tarefa::text, resultado) order by id) from rt.evento where instancia = i1)
     is distinct from (select array_agg(coalesce(tarefa::text, resultado) order by id) from rt.evento where instancia = i2) then
    raise exception 'FALHA T5: mesma semente deu caminhos diferentes';
  end if;

  -- T6. Eventos: todos simulados; na execução da tarefa, pessoa nas tarefas de gente, nenhuma nas de máquina; relógio não volta
  select count(*) into n from rt.evento where instancia is not null and not simulado;
  if n <> 0 then raise exception 'FALHA T6: % eventos sem marca de simulado', n; end if;
  select count(*) into n from rt.evento where tarefa is not null and tipo = 'fim' and ((executor in ('A', 'R') and pessoa is not null) or (executor not in ('A', 'R') and pessoa is null));
  if n <> 0 then raise exception 'FALHA T6: % eventos com pessoa errada', n; end if;
  select count(*) into n from rt.evento e join org.tarefa t on t.id = e.tarefa join rt.pessoa p on p.pseudonimo = e.pessoa where e.tipo = 'fim' and p.papel <> t.raia;
  if n <> 0 then raise exception 'FALHA T6: % eventos com pessoa de outro papel', n; end if;
  select count(*) into n from (select fim, lag(fim) over (partition by instancia order by id) as ant from rt.evento where tarefa is not null) x where fim < ant;
  if n <> 0 then raise exception 'FALHA T6: relógio voltou % vezes', n; end if;

  -- T7. Trocas: toda troca enviada vai ao motor do círculo de destino
  select count(*) into n from rt.troca_envio te join org.troca t on t.id = te.troca join org.circulo c on c.nome = t.para_circulo
   where te.para_motor <> c.numero;
  if n <> 0 then raise exception 'FALHA T7: % trocas no motor errado', n; end if;
  if not exists (select 1 from rt.troca_envio) then raise exception 'FALHA T7: nenhuma troca enviada'; end if;

  -- T8. Voltas cortadas: cada fluxo de volta passa no máximo duas vezes, então uma tarefa roda no máximo 1 + 2 × (fluxos de volta da jornada)
  select count(*) into n from (select e.instancia, e.tarefa, i.jornada, count(*) c from rt.evento e join rt.instancia i on i.id = e.instancia
                                where e.tarefa is not null and e.tipo = 'fim' group by 1, 2, 3) x
   where c > 1 + 2 * (select count(*) from rt.fluxo f where f.jornada = x.jornada and f.volta);
  if n <> 0 then raise exception 'FALHA T8: % tarefas rodaram mais de 3 vezes', n; end if;

  -- T9. Todas as jornadas rodam (uma vez cada) sem erro: o motor serve aos nove círculos
  for j in select codigo from org.jornada loop
    v_inst := rt.executar_simulada(j.codigo, 0.77, timestamptz '2026-10-05 08:00-03');
    if (select estado from rt.instancia where id = v_inst) <> 'concluida' then
      raise exception 'FALHA T9: % terminou em %', j.codigo, (select detalhe from rt.instancia where id = v_inst);
    end if;
  end loop;

  raise notice 'MOTOR: 9 testes, 0 falhas';
end $$;

rollback;
