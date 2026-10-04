-- Agenda do canal Telegram no Supabase: segredos no Vault (gerados dentro da base, nunca em mensagem) e a manutenção a cada 10 minutos
-- (esvaziar a fila e apagar as mensagens vencidas). Sem Vault, pg_net ou pg_cron (Postgres local), nada é feito.
create extension if not exists pg_net with schema extensions;
do $$ begin
  if to_regclass('vault.secrets') is null then return; end if;
  if not exists (select 1 from vault.secrets where name = 'telegram_webhook_segredo') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'telegram_webhook_segredo', 'segredo do webhook do bot (cabeçalho X-Telegram-Bot-Api-Secret-Token)');
  end if;
  if not exists (select 1 from vault.secrets where name = 'imts_funcao_chave') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'imts_funcao_chave', 'chave das tarefas da Edge Function telegram');
  end if;
  if not exists (select 1 from vault.secrets where name = 'telegram_ambiente') then
    perform vault.create_secret('teste', 'telegram_ambiente', 'ambiente da Bot API: teste ou producao');
  end if;
end $$;

create or replace function rt.telegram_manutencao() returns bigint language plpgsql security definer set search_path = '' as $$
begin
  return net.http_post(url := 'https://rzkfolkqdgtounqjjzss.supabase.co/functions/v1/telegram?tarefa=manutencao',
                       headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{}'::jsonb, timeout_milliseconds := 20000);
end $$;
revoke all on function rt.telegram_manutencao() from public;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'imts-telegram-manutencao';
    perform cron.schedule('imts-telegram-manutencao', '*/10 * * * *', 'select rt.telegram_manutencao()');
  end if;
end $$;

-- Ativação: depois de gravar o token do BotFather no Vault, esta função liga o webhook e os comandos do bot (resposta em net._http_response)
--   select vault.create_secret('<token do BotFather>', 'telegram_bot_token');
--   select rt.telegram_configurar();
create or replace function rt.telegram_configurar() returns bigint language plpgsql security definer set search_path = '' as $$
begin
  if rt._segredo('telegram_bot_token') is null then raise exception 'grave antes o token: select vault.create_secret(''<token do BotFather>'', ''telegram_bot_token'');'; end if;
  return net.http_post(url := 'https://rzkfolkqdgtounqjjzss.supabase.co/functions/v1/telegram?tarefa=configurar',
                       headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{}'::jsonb, timeout_milliseconds := 20000);
end $$;
revoke all on function rt.telegram_configurar() from public;
