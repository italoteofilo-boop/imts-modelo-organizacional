-- Simulação contínua (E10): uma execução simulada a cada 5 minutos (escolha de 03/10/2026, 21:05), sorteando a jornada entre os motores ligados,
-- e limpeza diária do dado simulado com mais de 30 dias. O agendamento usa o pg_cron quando a extensão existe (Supabase); sem ela, nada é agendado.
begin;

-- Uma execução simulada de uma jornada sorteada entre os motores em piloto ou ativos
create or replace function rt.simular_continuo() returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_j text;
begin
  select j.codigo into v_j from org.jornada j join rt.motor m on m.circulo = j.circulo
   where m.estado in ('piloto', 'ativo') order by random() limit 1;
  if v_j is null then return null; end if;
  return rt.executar_simulada(v_j, random(), now());
end $$;

-- Apaga o dado simulado antigo: execuções simuladas, os seus eventos, cartões e trocas. O dado real nunca é tocado.
create or replace function rt.limpar_simulado(p_dias integer default 30) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_ids bigint[]; a int; b int; c int; d int;
begin
  select coalesce(array_agg(id), '{}') into v_ids from rt.instancia
   where simulado and estado <> 'rodando' and coalesce(fim, inicio) < now() - make_interval(days => p_dias);
  delete from rt.troca_envio where simulado and (payload->>'instancia')::bigint = any (v_ids); get diagnostics a = row_count;
  delete from rt.evento where instancia = any (v_ids) and simulado; get diagnostics b = row_count;
  delete from rt.cartao where instancia = any (v_ids) and simulado; get diagnostics c = row_count;
  delete from rt.instancia where id = any (v_ids); get diagnostics d = row_count;
  return jsonb_build_object('instancias', d, 'eventos', b, 'trocas', a, 'cartoes', c);
end $$;

revoke all on function rt.simular_continuo(), rt.limpar_simulado(integer) from public;
grant execute on function rt.simular_continuo(), rt.limpar_simulado(integer) to service_role;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname in ('imts-simulacao-continua', 'imts-limpeza-simulado');
    perform cron.schedule('imts-simulacao-continua', '*/5 * * * *', 'select rt.simular_continuo()');
    perform cron.schedule('imts-limpeza-simulado', '17 3 * * *', 'select rt.limpar_simulado(30)');
  end if;
end $$;

commit;
