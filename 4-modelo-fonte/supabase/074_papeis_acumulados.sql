-- Papéis acumulados (05/10/2026): uma pessoa pode ocupar vários papéis do modelo.
-- Decisão do Ítalo: até a equipe entrar, italo.teofilo@imts.email e kamilla.marques@imts.email ocupam todos os papéis; depois os papéis passam às pessoas.
-- Como: o papel principal continua em rt.pessoa.papel; cada papel a mais é uma linha ativa em rt.acesso (já existe e já tem papel, círculo, nível e fim).
-- A segregação continua valendo: o gatilho rt._acesso_confere barra papéis incompatíveis na mesma pessoa.
begin;

-- Quem ocupa um papel: principal ou acumulado (acesso ativo), pessoa real antes da simulada, a menos carregada primeiro
create or replace function rt._pessoa(p_raia text, p_motor smallint) returns uuid language sql stable set search_path = '' as $$
  with ocupa as (
    select p.pseudonimo, p.circulo, p.simulado from rt.pessoa p where p.papel = p_raia
    union
    select p.pseudonimo, a.circulo, p.simulado from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
     where a.papel = p_raia and current_date >= a.inicio and (a.fim is null or a.fim >= current_date)
  )
  select o.pseudonimo from ocupa o
   order by (o.circulo is not distinct from p_motor) desc, o.simulado,
            (select count(*) from rt.cartao k where k.dono = o.pseudonimo and k.coluna <> 'feito'), o.circulo nulls first, o.pseudonimo
   limit 1 $$;

-- Papéis que a pessoa ocupa hoje (principal primeiro)
create or replace function rt.papeis_de(p_pessoa uuid) returns text[] language sql stable security definer set search_path = '' as $$
  select array(select x.papel from (
    select p.papel, 0 o from rt.pessoa p where p.pseudonimo = p_pessoa
    union
    select a.papel, 1 from rt.acesso a where a.pessoa = p_pessoa and current_date >= a.inicio and (a.fim is null or a.fim >= current_date)) x
    group by x.papel order by min(x.o), x.papel) $$;
revoke all on function rt.papeis_de(uuid) from public, anon;
grant execute on function rt.papeis_de(uuid) to authenticated, service_role;

-- Cobertura: o papel conta como coberto se uma pessoa real o ocupa, como principal ou acumulado
create or replace function adm.cobertura_papeis() returns jsonb language sql stable security definer set search_path = '' as $$
  with exigidos as (
    select distinct t.raia as papel from org.tarefa t where t.executor in ('P', 'H') and t.raia not in ('Cliente', 'Parceiro', 'Solicitante')
  ), coberto as (
    select e.papel from exigidos e
     where exists (select 1 from rt.pessoa p where p.papel = e.papel and not p.simulado)
        or exists (select 1 from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
                    where a.papel = e.papel and not p.simulado and current_date >= a.inicio and (a.fim is null or a.fim >= current_date))
  )
  select jsonb_build_object(
    'exigidos', (select count(*) from exigidos),
    'cobertos', (select count(*) from coberto),
    'sem_pessoa', coalesce((select jsonb_agg(e.papel order by e.papel) from exigidos e where e.papel not in (select papel from coberto)), '[]'))
$$;
revoke all on function adm.cobertura_papeis() from public, anon, authenticated;
grant execute on function adm.cobertura_papeis() to authenticated, service_role;

-- Importação: e-mail repetido (na planilha ou já cadastrado) acrescenta o papel à pessoa, em vez de ser ignorado
create or replace function adm._cadastro_incompativeis(p_dados jsonb) returns jsonb language sql stable security definer set search_path = '' as $$
  with linhas as (
    select lower(btrim(r->>'email')) email, r->>'papel' papel, (r->>'circulo') circ, n
      from jsonb_array_elements(coalesce(p_dados->'pessoas', '[]')) with ordinality x(r, n)
  ), todos as (
    select email, papel, n from linhas
    union all
    select lower(i.email), a.papel, 0 from rt.acesso a join rt_chave.identidade i on i.pseudonimo = a.pessoa
     where lower(i.email) in (select email from linhas) and (a.fim is null or a.fim >= current_date)
  )
  select coalesce(jsonb_agg(distinct jsonb_build_object('aba', 'pessoas', 'linha', a.n, 'campo', 'papel',
           'motivo', 'papel incompatível com ' || b.papel || ' na mesma pessoa (' || k.regra || ')')), '[]')
    from todos a join todos b on a.email = b.email and a.n > 0 and a.n <> b.n
    join rt.papel_incompativel k on (k.papel_a = a.papel and k.papel_b = b.papel) or (k.papel_b = a.papel and k.papel_a = b.papel)
$$;
revoke all on function adm._cadastro_incompativeis(jsonb) from public, anon, authenticated;

do $$
declare d text := pg_get_functiondef('adm.importar_cadastro(jsonb, boolean, uuid)'::regprocedure); a text;
begin
  a := d;
  -- prévia: avisa que a linha acrescenta papel, e confere a segregação entre os papéis da mesma pessoa
  d := replace(d, $q$'pessoa já cadastrada: fica como está'$q$, $q$'pessoa já cadastrada: este papel é acrescentado a ela'$q$);
  d := replace(d, $q$  -- clientes e parceiros$q$, $q$  erros := erros || adm._cadastro_incompativeis(p_dados);
  -- clientes e parceiros$q$);
  -- gravação: e-mail que já existe recebe o papel como acesso a mais
  d := replace(d, $q$    continue when exists (select 1 from rt_chave.identidade where lower(email) = lower(r->>'email'));
    v_p := gen_random_uuid();$q$, $q$    select pseudonimo into v_p from rt_chave.identidade where lower(email) = lower(btrim(r->>'email'));
    if v_p is not null then
      if not exists (select 1 from rt.acesso where pessoa = v_p and papel = r->>'papel' and (fim is null or fim >= current_date)
                       and circulo is not distinct from (r->>'circulo')::smallint) then
        insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, concedido_por, motivo)
        values (v_p, (select id from org.empresa where lower(nome) = lower(r->>'empresa') and not simulado), (r->>'circulo')::smallint, r->>'papel', r->>'nivel', v,
                'papel acumulado pela carga do cadastro');
        n_pes := n_pes + 1;
      end if;
      continue;
    end if;
    v_p := gen_random_uuid();$q$);
  if d = a or position('_cadastro_incompativeis' in d) = 0 or position('papel acumulado pela carga' in d) = 0 then
    raise exception 'importar_cadastro não tem o texto esperado: revisar a 074'; end if;
  execute d;

  -- Reunião: o responsável de um encaminhamento pode ser papel acumulado
  d := pg_get_functiondef('ext.reuniao_ata_aprovar(bigint, jsonb, uuid)'::regprocedure); a := d;
  d := replace(d, $q$select pseudonimo, circulo into v_resp, v_circ from rt.pessoa where papel = e->>'responsavel' and circulo is not null order by pseudonimo limit 1;$q$,
                  $q$select o.pseudonimo, o.circulo into v_resp, v_circ from (
      select p.pseudonimo, p.circulo, p.simulado from rt.pessoa p where p.papel = e->>'responsavel'
      union
      select p.pseudonimo, coalesce(a.circulo, p.circulo), p.simulado from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
       where a.papel = e->>'responsavel' and (a.fim is null or a.fim >= current_date)) o
     where o.circulo is not null order by o.simulado, o.pseudonimo limit 1;$q$);
  if d = a then raise exception 'reuniao_ata_aprovar não tem o texto esperado: revisar a 074'; end if;
  execute d;
end $$;

commit;
