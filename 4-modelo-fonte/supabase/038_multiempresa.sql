-- Onda 3 do plano mestre (auditoria R09): multiempresa no runtime. Toda instância, cartão e evento passa a ter empresa, e a leitura
-- de quem é de dentro respeita o acesso por empresa. De onde vem a empresa:
--   1. cabeçalho x-empresa da chamada (o app manda a empresa em que a pessoa está trabalhando), conferido contra o acesso da pessoa;
--   2. a instância de origem (cartão e evento herdam);
--   3. simulação: as empresas simuladas, em rodízio pelo id da instância;
--   4. enquanto não houver empresa real cadastrada (gate G1), a holding simulada; depois disso, instância real sem empresa é recusada.
begin;
alter table rt.instancia add column if not exists empresa uuid references org.empresa(id);
alter table rt.cartao add column if not exists empresa uuid references org.empresa(id);
alter table rt.evento add column if not exists empresa uuid;
create index if not exists instancia_empresa on rt.instancia (empresa);
create index if not exists cartao_empresa on rt.cartao (empresa);

create or replace function rt._empresa_da_chamada() returns uuid language plpgsql stable security definer set search_path = '' as $$
declare h text := nullif(current_setting('request.headers', true), ''); v uuid;
begin
  if h is null then return null; end if;
  v := nullif(h::jsonb ->> 'x-empresa', '')::uuid;
  if v is not null and rt.eu() is not null and not rt.pode(rt.eu(), v, null, 'operar') then raise exception 'sem acesso de operar na empresa informada'; end if;
  return v;
exception when invalid_text_representation then raise exception 'cabeçalho x-empresa inválido';
end $$;

create or replace function rt._instancia_empresa() returns trigger language plpgsql security definer set search_path = '' as $$
declare sims uuid[];
begin
  if new.empresa is null then new.empresa := rt._empresa_da_chamada(); end if;
  if new.empresa is null and new.simulado then
    select array_agg(id order by id) into sims from org.empresa where simulado and ativa;
    new.empresa := sims[1 + (new.id % array_length(sims, 1))::int];
  end if;
  if new.empresa is null then
    if exists (select 1 from org.empresa where not simulado and ativa) then raise exception 'instância real sem empresa: informe a empresa (x-empresa)'; end if;
    select id into new.empresa from org.empresa where simulado and nome like 'Holding%' limit 1;
  end if;
  return new;
end $$;
drop trigger if exists empresa_instancia on rt.instancia;
create trigger empresa_instancia before insert on rt.instancia for each row execute function rt._instancia_empresa();

create or replace function rt._herda_empresa() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.empresa is null and new.instancia is not null then select empresa into new.empresa from rt.instancia where id = new.instancia; end if;
  if new.empresa is null then new.empresa := rt._empresa_da_chamada(); end if;
  return new;
end $$;
drop trigger if exists empresa_cartao on rt.cartao;
create trigger empresa_cartao before insert on rt.cartao for each row execute function rt._herda_empresa();
drop trigger if exists empresa_evento on rt.evento;
create trigger empresa_evento before insert on rt.evento for each row execute function rt._herda_empresa();

-- dados existentes (todos simulados)
update rt.instancia i set empresa = s.ids[1 + (i.id % array_length(s.ids, 1))::int]
  from (select array_agg(id order by id) ids from org.empresa where simulado and ativa) s where i.empresa is null;
update rt.cartao c set empresa = i.empresa from rt.instancia i where c.instancia = i.id and c.empresa is null;
update rt.cartao set empresa = (select id from org.empresa where simulado and nome like 'Holding%' limit 1) where empresa is null;

-- ligações antigas entre empresas diferentes saem (com o que foi publicado por elas)
delete from ext.publicacao p using rt.instancia i, ext.contraparte c where p.instancia = i.id and p.contraparte = c.id and i.empresa is distinct from c.empresa;
delete from ext.vinculo v using rt.instancia i, ext.contraparte c where v.instancia = i.id and v.contraparte = c.id and i.empresa is distinct from c.empresa;

-- leitura de quem é de dentro: só das empresas a que tem acesso (acesso sem empresa = todas)
do $$ declare t text;
begin
  foreach t in array array['instancia', 'evento'] loop
    execute format('drop policy if exists leitura_interna on rt.%I', t);
    execute format('create policy leitura_interna on rt.%I for select to authenticated using (rt.interno() and (empresa is null or rt.pode(rt.eu(), empresa, null, ''ler'')))', t);
  end loop;
end $$;
-- cartão mantém a regra de 017 (fluxo do círculo que a pessoa lê; avulsa e ajuda só de quem é dono ou recebeu), agora dentro da empresa
drop policy if exists leitura_interna on rt.cartao;
drop policy if exists leitura_por_acesso on rt.cartao;
create policy leitura_por_acesso on rt.cartao for select to authenticated
  using ((tipo = 'fluxo' and rt.pode(rt.eu(), empresa, circulo, 'ler')) or dono = rt.eu() or delegado_pessoa = rt.eu());

-- a projeção externa só liga instância a contraparte da mesma empresa
create or replace function ext.vincular(p_inst bigint, p_contraparte uuid) returns int language plpgsql security definer set search_path = '' as $$
begin
  if (select empresa from rt.instancia where id = p_inst) is distinct from (select empresa from ext.contraparte where id = p_contraparte) then
    raise exception 'instância e contraparte de empresas diferentes'; end if;
  insert into ext.vinculo (instancia, contraparte) values (p_inst, p_contraparte) on conflict do nothing;
  return ext.projetar(p_inst);
end $$;
create or replace function ext.vincular_simulados(p_limite int default 40) returns int language plpgsql security definer set search_path = '' as $$
declare n int := 0; r record; cs uuid[];
begin
  for r in
    select i.id, i.empresa, (select tipo from ext.regra where jornada = i.jornada limit 1) as tipo from rt.instancia i
     where i.simulado and i.inicio > now() - interval '2 days' and i.jornada in (select jornada from ext.regra)
       and not exists (select 1 from ext.vinculo v where v.instancia = i.id)
     order by i.id desc limit p_limite
  loop
    select array_agg(id order by id) into cs from ext.contraparte where simulado and ativa and tipo = r.tipo and empresa = r.empresa;
    if cs is null then continue; end if;
    perform ext.vincular(r.id, cs[1 + (r.id % array_length(cs, 1))::int]);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function rt._empresa_da_chamada(), ext.vincular(bigint, uuid), ext.vincular_simulados(int) from public, anon;
grant execute on function ext.vincular(bigint, uuid), ext.vincular_simulados(int) to service_role;
commit;
