-- Endurecimento das permissões de execução (achado do ensaio em banco vazio).
-- O "alter default privileges in schema ... revoke ... from public" da 041 não tem efeito: o padrão do Postgres
-- (execução para public) é global e não se revoga por esquema. Funções criadas sem revoke explícito ficaram
-- executáveis por public e, por tabela, pelo papel anon.
-- Regra: anon não executa nada dos nossos esquemas. Quem dependia do public continua com o mesmo acesso,
-- agora explícito (authenticated e service_role), porque as políticas de linha chamam funções como rt.eu() e rt.pode().
-- Idempotente: o script de implantação roda esta varredura de novo no fim.
begin;
create or replace function adm.endurecer_permissoes() returns int language plpgsql security definer set search_path = '' as $$
declare f record; n int := 0;
begin
  for f in
    select p.oid::regprocedure as assinatura
      from pg_proc p join pg_namespace s on s.oid = p.pronamespace
     where s.nspname in ('rt', 'rt_chave', 'doc', 'adm', 'ext', 'org', 'sim', 'acervo')
       and p.prokind in ('f', 'p')
       and (has_function_privilege('anon', p.oid, 'execute') or exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a where a.grantee = 0 and a.privilege_type = 'EXECUTE'))
  loop
    if exists (select 1 from aclexplode(coalesce((select proacl from pg_proc where oid = f.assinatura::oid), acldefault('f', (select proowner from pg_proc where oid = f.assinatura::oid)))) a
                where a.grantee = 0 and a.privilege_type = 'EXECUTE') then
      execute format('grant execute on function %s to authenticated, service_role', f.assinatura);
    end if;
    execute format('revoke execute on function %s from public, anon', f.assinatura);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function adm.endurecer_permissoes() from public, anon, authenticated;
select adm.endurecer_permissoes();
commit;
