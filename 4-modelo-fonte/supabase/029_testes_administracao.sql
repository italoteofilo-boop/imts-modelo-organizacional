-- Testes da administração geral (E13) como função; rodar sem gravar nada: do $$ begin raise exception '%', adm._testar_administracao(); end $$;
begin;
create or replace function adm._testar_administracao() returns text language plpgsql set search_path = '' as $$
declare a1 uuid; a2 uuid; p1 uuid; u1 uuid := gen_random_uuid(); ok boolean; r jsonb; m bigint; n int; s text; ped bigint; ch text; j jsonb;
begin
  select pessoa into a1 from rt.acesso where nivel = 'administrar' order by papel limit 1;
  select pessoa into a2 from rt.acesso where nivel = 'administrar' and pessoa <> a1 order by papel limit 1;
  select pessoa into p1 from rt.acesso where nivel = 'operar' order by pessoa limit 1;
  if a1 is null or a2 is null then raise exception 'FALHA A0: faltam dois administradores'; end if;

  -- A1. Registro: conexões e parâmetros semeados; segredo só por nome
  if (select count(*) from adm.conexao) < 16 or (select count(*) from adm.parametro) < 15 then raise exception 'FALHA A1: registro incompleto'; end if;
  ok := false; begin insert into adm.conexao (codigo, nome, categoria, ambiente, dono, estado, segredos, verificacao, fonte)
    values ('x', 'x', 'api', 'teste', 'x', 'pendente', '{0123456789abcdef0123456789abcdef}', 'manual', 'teste'); exception when check_violation then ok := true; end;
  if not ok then raise exception 'FALHA A1: aceitou valor de segredo no lugar do nome'; end if;

  -- A2. Só quem administra altera; pelo app vale a pessoa do login
  insert into rt_chave.login (auth_uid, pseudonimo) values (u1, p1);
  perform set_config('request.jwt.claim.sub', u1::text, true);
  ok := false; begin perform adm.alterar_parametro('simulacao.tempo_agente', '{"min":3,"max":20}', 'teste'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A2: quem opera alterou parâmetro'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  ok := false; begin perform adm.alterar_parametro('simulacao.tempo_agente', '{"min":3,"max":20}', 'teste', p1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A2: serviço atuou como quem não administra'; end if;

  -- A3. Validação e motivo
  ok := false; begin perform adm.alterar_parametro('telegram.autodestruicao_horas', '72', 'acima do limite do Telegram', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A3: aceitou 72 h'; end if;
  ok := false; begin perform adm.alterar_parametro('telegram.canal_padrao', '"email"', 'fora das opções', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A3: aceitou opção inexistente'; end if;
  ok := false; begin perform adm.alterar_parametro('simulacao.tempo_agente', '{"min":30,"max":20}', 'faixa invertida', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A3: aceitou faixa invertida'; end if;
  ok := false; begin perform adm.alterar_parametro('simulacao.tempo_agente', '{"min":3,"max":20}', ' ', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A3: aceitou sem motivo'; end if;

  -- A4. Mudança comum: aplica e propaga ao destino (simulação e agenda), com histórico
  r := adm.alterar_parametro('simulacao.tempo_agente', '{"min":3,"max":25}', 'teste de propagação', a1);
  if r->>'situacao' <> 'aplicada' or (select max_minutos from rt.parametro_simulacao where executor::text = 'A') <> 25 then raise exception 'FALHA A4: não propagou à simulação (%)', r; end if;
  perform adm.alterar_parametro('simulacao.intervalo_minutos', '7', 'teste de agenda', a1);
  if (select schedule from cron.job where jobname = 'imts-simulacao-continua') <> '*/7 * * * *' then raise exception 'FALHA A4: agenda não mudou'; end if;
  if exists (select 1 from rt.config where chave = 'simulacao_continua_minutos' and valor <> '7'::jsonb) then raise exception 'FALHA A4: rt.config não mudou nos nove motores'; end if;
  if (select count(*) from adm.historico where chave in ('simulacao.tempo_agente', 'simulacao.intervalo_minutos') and por = a1) < 2 then raise exception 'FALHA A4: sem histórico'; end if;

  -- A5. Sensível: fica pendente; quem pediu não decide; recusa exige motivo; outra pessoa aprova e aí propaga
  r := adm.alterar_parametro('telegram.autodestruicao_horas', '24', 'menos tempo de mensagem no celular', a1);
  m := (r->>'mudanca')::bigint;
  if r->>'situacao' <> 'pendente' or exists (select 1 from rt.config where chave = 'autodestruicao_horas' and valor = '24'::jsonb) then raise exception 'FALHA A5: sensível aplicou sem aprovação'; end if;
  ok := false; begin perform adm.decidir_mudanca(m, 'aprovada', 'ok', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A5: quem pediu aprovou'; end if;
  ok := false; begin perform adm.decidir_mudanca(m, 'recusada', '', a2); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A5: recusa sem motivo'; end if;
  perform adm.decidir_mudanca(m, 'aprovada', 'de acordo', a2);
  if exists (select 1 from rt.config where chave = 'autodestruicao_horas' and valor <> '24'::jsonb) or (select valor from adm.parametro where chave = 'telegram.autodestruicao_horas') <> '24'::jsonb then
    raise exception 'FALHA A5: aprovada e não propagada'; end if;

  -- A6. Conexão: só campos de cadastro; alvo da verificação não muda por aqui; histórico
  ok := false; begin perform adm.alterar_conexao('pg-cron', '{"alvo":"true"}', 'tentar mudar o alvo', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A6: mudou o alvo da verificação'; end if;
  ok := false; begin perform adm.alterar_conexao('telegram-bot-api', '{"segredos":["123456:ABCdefGHIjklMNOpqrSTUvwxYZ0123456789ab"]}', 'colou o token', a1); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A6: aceitou token no lugar do nome'; end if;
  perform adm.alterar_conexao('erp-contabil', '{"pendencia":"comparar três ERPs com plano de contas multiempresa"}', 'teste', a1);
  if not exists (select 1 from adm.historico where objeto = 'conexao' and chave = 'erp-contabil') then raise exception 'FALHA A6: sem histórico da conexão'; end if;

  -- A7. Saúde: roda, marca falha onde falta segredo e não expõe valor
  r := adm.verificar_conexoes();
  if (r->>'ok')::int < 1 then raise exception 'FALHA A7: nenhuma conexão saudável (%)', r; end if;
  if rt._segredo('telegram_bot_token') is null and (select saude from adm.conexao where codigo = 'telegram-bot-api') <> 'falha' then raise exception 'FALHA A7: token ausente sem falha'; end if;

  -- A8. Painel: tem o que a página precisa e nenhum valor de segredo
  j := adm.painel();
  if not (j ? 'conexoes' and j ? 'parametros' and j ? 'mudancas' and j ? 'historico' and j ? 'resumo' and j ? 'agenda') then raise exception 'FALHA A8: painel incompleto'; end if;
  if j::text like '%"alvo"%' then raise exception 'FALHA A8: painel expõe o alvo SQL'; end if;
  ch := rt._segredo('doc_worker_chave');
  if ch is not null and position(ch in j::text) > 0 then raise exception 'FALHA A8: painel expõe segredo'; end if;

  -- A9. O motor documental lê os seus parâmetros daqui
  perform adm.alterar_parametro('documental.tentativas_maximas', '1', 'teste', a1);
  ped := doc.pedir('ata', 'imts', '{"titulo":"t","data":"2026-10-04","local":"x"}');
  update doc.pedido set situacao = 'em_emissao' where id = ped;
  if ch is null then ch := encode(extensions.gen_random_bytes(24), 'hex');
    if to_regclass('vault.secrets') is not null then perform vault.create_secret(ch, 'doc_worker_chave'); else insert into vault.decrypted_secrets values ('doc_worker_chave', ch); end if; end if;
  s := doc.worker_falhar(ch, ped, 'teste');
  if s <> 'erro' then raise exception 'FALHA A9: limite de tentativas não veio da administração (%)', s; end if;
  return 'administração: 9 de 9 ok';
end $$;
revoke all on function adm._testar_administracao() from public;
commit;
