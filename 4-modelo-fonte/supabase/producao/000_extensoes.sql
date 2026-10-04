-- Pré-requisito do projeto novo (antes da 001). As migrações agendam rotinas só se o pg_cron existir:
-- sem ele, o banco sobe sem rotinas e sem aviso. Por isso a extensão é exigida aqui.
create extension if not exists pg_cron;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault;
do $$ begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then raise exception 'pg_cron não habilitado'; end if;
  if to_regclass('vault.secrets') is null then raise exception 'cofre (Vault) não disponível'; end if;
end $$;
