-- Fecha o incidente de 04/10/2026, 11:05: registro no histórico (append-only) e datas coerentes com os valores restaurados.
begin;
alter table adm.historico drop constraint if exists historico_objeto_check;
alter table adm.historico add constraint historico_objeto_check
  check (objeto in ('parametro', 'conexao', 'agente', 'regra_externa', 'titulo_externo', 'tipo_documento', 'incidente'));
insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
select 'incidente', 'testes gravados em 04/10/2026, 11:05',
  jsonb_build_object('causa', 'sete suítes _testar_* chamadas com select direto, sem o envelope que desfaz',
    'transacoes', '3877 a 3917',
    'efeitos', jsonb_build_array('linhas de teste em rt, ext, doc, adm e agentes', 'parâmetros de simulação, autodestruição e tentativas alterados',
      'agenda da simulação em */7 por cerca de 25 minutos', 'quatro cartões vencidos marcados como feitos', 'fila de envio pendente esvaziada',
      'oito registros de teste neste histórico')),
  jsonb_build_object('limpeza', 'linhas das transações de teste apagadas; trava de só acréscimo desligada só durante a limpeza',
    'restaurado', 'valores anteriores tirados deste histórico (antes de cada mudança), das sementes das migrações e do evento de cada cartão',
    'sem_recuperacao', 'mensagens que estavam na fila de envio (nenhuma sairia: o bot não tem token)',
    'prevencao', 'adm.testar_tudo() roda as suítes sem gravar; aviso no LEIA-ME'),
  (select pessoa from rt.acesso where papel = 'Administrador do IMTS.OS' limit 1),
  'registro do incidente pela sessão de trabalho',
  'Limpeza aprovada por Ítalo em 04/10/2026 (resposta "Limpar tudo"); registro aprovado em 04/10/2026, 12:16';
-- datas coerentes: o valor voltou ao de antes do teste
update adm.parametro set atualizado_em = '2026-10-04 12:28:51.062611+00'
 where chave in ('simulacao.tempo_agente', 'simulacao.intervalo_minutos', 'telegram.autodestruicao_horas', 'documental.tentativas_maximas')
   and atualizado_em = '2026-10-04 14:05:02.590017+00';
update rt.config set atualizado_em = now() where chave in ('simulacao_continua_minutos', 'autodestruicao_horas') and atualizado_em = '2026-10-04 14:05:02.590017+00';
update rt.parametro_simulacao set origem = 'hipótese do protótipo, a calibrar no G9 com dado real' where executor = 'A';
commit;
