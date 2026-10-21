-- Lista das regras por verbo da automação das tarefas R (078) para a aba "Automação e IA" da Administração (21/10/2026).
-- adm.automacao_r_regras(): uma linha por verbo de adm.automacao_r_regra, com o modo, a descrição, quantas tarefas R do modelo
-- começam com o verbo (e quantas delas ficam com a pessoa por serem compostas), quando e por quem a regra mudou por último.
-- Só quem administra (adm._so_admin), ou chamada de serviço, como em adm.agente_ia_resumo (086). Só leitura.
begin;

create or replace function adm.automacao_r_regras() returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not rt.chamada_servico() then perform adm._so_admin(); end if;
  return (
    with t as (
      select initcap(lower(split_part(btrim(t.nome), ' ', 1))) as verbo, rt._automacao_r_modo(t.nome) as modo
        from org.tarefa t where t.executor = 'R'
    ), n as (
      select verbo, count(*) as q, count(*) filter (where modo = 'humano') as q_pessoa from t group by verbo
    ), r as (
      select g.verbo, g.modo, g.descricao, g.atualizado_em, g.atualizado_por,
             (select i.nome from rt_chave.identidade i where i.pseudonimo = g.atualizado_por and i.nome not like 'eliminado em %') as atualizado_por_nome,
             coalesce(n.q, 0) as tarefas_r,
             case when g.modo = 'humano' then 0 else coalesce(n.q_pessoa, 0) end as compostas_com_pessoa
        from adm.automacao_r_regra g left join n on n.verbo = g.verbo
    )
    select jsonb_build_object(
      'total', (select count(*) from r),
      'por_modo', (select jsonb_object_agg(m, (select count(*) from r where r.modo = m)) from unnest(array['registrar', 'encaminhar', 'avisar', 'humano']) m),
      'regras', coalesce((select jsonb_agg(jsonb_build_object(
          'verbo', r.verbo, 'modo', r.modo, 'descricao', r.descricao, 'tarefas_r', r.tarefas_r, 'compostas_com_pessoa', r.compostas_com_pessoa,
          'atualizado_em', r.atualizado_em, 'atualizado_por', r.atualizado_por, 'atualizado_por_nome', r.atualizado_por_nome)
          order by r.tarefas_r desc, r.verbo) from r), '[]'::jsonb))
  );
end $$;

revoke all on function adm.automacao_r_regras() from public, anon, authenticated;
grant execute on function adm.automacao_r_regras() to authenticated, service_role;

insert into adm.api_funcao (nome, quem, descricao) values
  ('adm.automacao_r_regras', 'interno', 'Regras da automação das tarefas R por verbo: modo, descrição, quantas tarefas R usam o verbo, quando e por quem mudou (só administração)')
on conflict (nome) do nothing;
commit;
