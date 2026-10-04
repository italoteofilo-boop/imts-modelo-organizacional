-- Endereço das Edge Functions por parâmetro (achado do ensaio de implantação): rt.telegram_manutencao e rt.telegram_configurar
-- tinham o endereço do protótipo escrito no código. Agora usam servidor.url_funcoes; vazio = não chamam nada (sem falha em rotina).
-- Também registra no catálogo de conexões as funções novas (google, ia, alertas).
begin;
create or replace function rt._url_funcao(p_nome text) returns text language sql stable security definer set search_path = '' as $$
  select nullif(rtrim(coalesce(adm.valor('servidor.url_funcoes', '""') #>> '{}', ''), '/'), '') || '/' || p_nome $$;
revoke all on function rt._url_funcao(text) from public, anon, authenticated;

create or replace function rt.telegram_manutencao() returns bigint language plpgsql security definer set search_path = '' as $$
declare u text := rt._url_funcao('telegram');
begin
  if u is null then return null; end if;   -- implantação ainda sem o endereço das funções
  return net.http_post(url := u || '?tarefa=manutencao',
                       headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{}'::jsonb, timeout_milliseconds := 20000);
end $$;
create or replace function rt.telegram_configurar() returns bigint language plpgsql security definer set search_path = '' as $$
declare u text := rt._url_funcao('telegram');
begin
  if rt._segredo('telegram_bot_token') is null then raise exception 'grave antes o token: select vault.create_secret(''<token do BotFather>'', ''telegram_bot_token'');'; end if;
  if u is null then raise exception 'preencha antes o parâmetro servidor.url_funcoes (https://<ref>.supabase.co/functions/v1)'; end if;
  return net.http_post(url := u || '?tarefa=configurar',
                       headers := jsonb_build_object('Content-Type', 'application/json', 'X-IMTS-Chave', rt._segredo('imts_funcao_chave')),
                       body := '{}'::jsonb, timeout_milliseconds := 20000);
end $$;

insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('edge-google', 'Função do servidor google (Drive do acervo e Agenda com Meet)', 'documentos', 'produção', null, 'Integração', 'pendente', '{google_conta_servico}', 'manual', null,
  'publicar a função, gravar a conta de serviço no cofre e preencher google.usuario_sistema e google.drive_raiz', '066, Plano de produção (B21)'),
 ('edge-ia', 'Função do servidor ia (rascunho de ata)', 'ia', 'produção', null, 'Integração', 'pendente', '{anthropic_chave}', 'manual', null,
  'publicar a função e gravar a chave da API no cofre', '066, Plano de produção (B22)'),
 ('edge-alertas', 'Função do servidor alertas (e-mail dos alertas de operação)', 'mensageria', 'produção', null, 'Integração', 'pendente', '{imts_funcao_chave,google_conta_servico}', 'manual', null,
  'publicar a função sem verificação de JWT e preencher alerta.emails e servidor.url_funcoes', '066, Plano de produção (B23)')
on conflict (codigo) do nothing;
commit;
