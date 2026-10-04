-- E22 · Simulação completa e passagem para a base de produção (pedido de Ítalo em 04/10/2026, 14:14).
-- 1. Plataforma formal: Google Workspace (Meet). Zoom, Teams e Webex: a IMTS participa das reuniões de terceiros pelo link do convite,
--    entrando com a conta Google; não há app a registrar. No protótipo, a agenda e o Meet são os da conta Gmail de Ítalo.
-- 2. adm.simular_ecossistema(): gera, pelas funções reais, um ciclo completo de parceiro, cliente, ouvidoria, reunião, acervo e Telegram.
-- 3. adm.zerar_simulacoes(): apaga o movimento simulado (em lotes), desliga a simulação contínua e registra o corte no histórico.
--    Ficam: o modelo, os catálogos, os parâmetros, as conexões, as marcas e as trilhas de auditoria (que por regra não se apagam).
--    Os cadastros simulados (empresas, pessoas, clientes e parceiros) só saem quando houver cadastro real para operar no lugar.
begin;

alter table adm.historico drop constraint if exists historico_objeto_check;
alter table adm.historico add constraint historico_objeto_check
  check (objeto in ('parametro', 'conexao', 'agente', 'regra_externa', 'titulo_externo', 'tipo_documento', 'incidente', 'acervo', 'marca',
                    'contrato_parceria', 'comissao', 'prestacao', 'atendimento', 'reuniao', 'simulacao'));

insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('simulacao.ativa', 'simulação', 'Simulação contínua ligada (instâncias simuladas a cada 5 minutos e vínculos simulados do portal). Zerar as simulações desliga', 'booleano', 'true', 'true', '{}', true, '{}', 'E22, 04/10/2026')
on conflict (chave) do nothing;

-- as rotinas de simulação só rodam com a simulação ligada
select cron.schedule('imts-simulacao-continua', '*/5 * * * *', $c$select rt.simular_continuo() where coalesce((adm.valor('simulacao.ativa', 'true') #>> '{}')::boolean, true)$c$);
select cron.schedule('imts-externo-simulado', '*/10 * * * *', $c$select ext.vincular_simulados(40) where coalesce((adm.valor('simulacao.ativa', 'true') #>> '{}')::boolean, true)$c$);

-- vídeo: Meet é a plataforma formal; Zoom, Teams e Webex por participação no convite
update adm.conexao set estado = 'ativa', ambiente = 'protótipo', saude = 'ok', verificada_em = now(), atualizado_em = now(),
       nome = 'Zoom (participação por convite)', saude_detalhe = 'sem app: entra-se pelo link do convite',
       pendencia = 'A IMTS não hospeda no Zoom: participa das reuniões de terceiros pelo link do convite, entrando com a conta Google quando o Zoom oferece. Na Central, cole o link do convite; a ata vem das anotações ou da transcrição que o anfitrião enviar.'
 where codigo = 'zoom';
update adm.conexao set estado = 'ativa', ambiente = 'protótipo', saude = 'ok', verificada_em = now(), atualizado_em = now(),
       nome = 'Microsoft Teams (participação por convite)', saude_detalhe = 'sem app: entra-se pelo link do convite',
       pendencia = 'A IMTS não hospeda no Teams: participa pelo link do convite (no navegador, como convidado ou com a conta que o anfitrião aceitar). Na Central, cole o link; a ata vem das anotações ou da transcrição enviada.'
 where codigo = 'microsoft-teams';
update adm.conexao set estado = 'ativa', ambiente = 'protótipo', saude = 'ok', verificada_em = now(), atualizado_em = now(),
       nome = 'Webex (participação por convite)', saude_detalhe = 'sem app: entra-se pelo link do convite',
       pendencia = 'A IMTS não hospeda no Webex: participa pelo link do convite, entrando com a conta Google quando o Webex oferece. Na Central, cole o link; a ata vem das anotações ou da transcrição enviada.'
 where codigo = 'webex';
update adm.conexao set nome = 'Google Meet (plataforma formal: Google Workspace)', atualizado_em = now(),
       pendencia = 'Plataforma formal de reuniões: Google Workspace. No protótipo, a Central cria o evento com Meet na agenda da conta Gmail de Ítalo (conector Google Calendar); na produção, a agenda do Workspace IMTS.'
 where codigo = 'google-meet';

-- quem pode: administração sem restrição
create or replace function adm._admin(p_como uuid) returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then if not rt.chamada_servico() then raise exception 'sem identidade'; end if; v := p_como; end if;
  if v is null or not rt.pode_estrito(v, null, null, 'administrar') then raise exception 'só a administração do IMTS.OS'; end if;
  return v;
end $$;

-- o que há de simulado hoje
create or replace function adm.simulacao_painel(p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := adm._admin(p_como);
begin
  return jsonb_build_object(
    'ativa', coalesce((adm.valor('simulacao.ativa', 'true') #>> '{}')::boolean, true),
    'movimento', jsonb_build_object(
      'instancias', (select count(*) from rt.instancia where simulado), 'eventos', (select count(*) from rt.evento where simulado),
      'cartoes', (select count(*) from rt.cartao where simulado), 'mensagens', (select count(*) from rt.mensagem where simulado) + (select count(*) from rt.fila_envio where simulado),
      'pedidos_de_fora', (select count(*) from ext.pedido p join ext.contraparte c on c.id = p.contraparte where c.simulado),
      'oportunidades', (select count(*) from ext.oportunidade o join ext.contraparte c on c.id = o.contraparte where c.simulado),
      'comissoes', (select count(*) from ext.comissao k join ext.contraparte c on c.id = k.contraparte where c.simulado),
      'prestacoes', (select count(*) from ext.prestacao x join ext.contraparte c on c.id = x.contraparte where c.simulado),
      'reunioes', (select count(*) from ext.reuniao r join org.empresa e on e.id = r.empresa where e.simulado),
      'acervo', (select count(*) from acervo.arquivo a join org.empresa e on e.id = a.empresa where e.simulado),
      'publicacoes', (select count(*) from ext.publicacao where simulado)),
    'cadastro', jsonb_build_object(
      'empresas_simuladas', (select count(*) from org.empresa where simulado), 'empresas_reais', (select count(*) from org.empresa where not simulado),
      'pessoas_simuladas', (select count(*) from rt.pessoa where simulado), 'pessoas_reais', (select count(*) from rt.pessoa where not simulado),
      'contrapartes_simuladas', (select count(*) from ext.contraparte where simulado), 'contrapartes_reais', (select count(*) from ext.contraparte where not simulado)),
    'ultimo_corte', (select jsonb_build_object('em', h.em, 'depois', h.depois) from adm.historico h where h.objeto = 'simulacao' order by h.em desc limit 1));
end $$;

-- ciclo completo, pelas mesmas funções que as páginas usam
create or replace function adm.simular_ecossistema(p_como uuid default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._admin(p_como);
  sau uuid := '80d8f119-a3fc-40ce-afaa-34d974f25d31'; edu uuid := '9ce4812d-e39d-4fb3-bbda-a59a0f4aa897';
  a2 uuid; op7 uuid; gov uuid; gest uuid; neg uuid;
  sms uuid; sme uuid; dist uuid; g_sms uuid; f_sms uuid; fin_sms uuid; g_sme uuid; g_dist uuid;
  o1 bigint; o2 bigint; k bigint[]; r jsonb; p bigint; e bigint; re bigint; n int := 0; tag text := to_char(now(), 'DDMMHH24MISS'); emp record; base text; x jsonb;
  ata jsonb;
begin
  if not coalesce((adm.valor('simulacao.ativa', 'true') #>> '{}')::boolean, true) then raise exception 'a simulação está desligada (base de produção); religue antes de simular'; end if;
  select pessoa into a2 from rt.acesso a join rt.pessoa q on q.pseudonimo = a.pessoa where q.papel = 'Sócios' limit 1;
  op7 := rt._pessoa('Operações · pessoa', 7::smallint); gov := rt._pessoa('Governança · pessoa', 9::smallint);
  gest := rt._pessoa('Gestão · pessoa', 8::smallint); neg := rt._pessoa('Negócios · pessoa', 5::smallint);
  select id into sms from ext.contraparte where empresa = sau and tipo = 'cliente' and simulado limit 1;
  select id into sme from ext.contraparte where empresa = edu and tipo = 'cliente' and simulado limit 1;
  select id into dist from ext.contraparte where empresa = edu and tipo = 'parceiro' and simulado limit 1;
  select auth_uid into g_sms from ext.usuario where contraparte = sms and perfil = 'gestor';
  select auth_uid into f_sms from ext.usuario where contraparte = sms and perfil = 'fiscal';
  select auth_uid into fin_sms from ext.usuario where contraparte = sms and perfil = 'financeiro';
  select auth_uid into g_sme from ext.usuario where contraparte = sme and perfil = 'gestor';
  select auth_uid into g_dist from ext.usuario where contraparte = dist and perfil = 'gestor';
  if sms is null or sme is null or dist is null or g_dist is null or g_sms is null then raise exception 'faltam cadastros simulados para o ciclo'; end if;

  -- Telegram do parceiro (simulado): os avisos entram na fila marcados como simulados
  insert into ext.telegram (auth_uid, telegram_id, chat_ref, vinculado_em, simulado)
  values (g_dist, -abs(hashtext(g_dist::text))::bigint, 'tg:sim-' || left(g_dist::text, 8), now(), true)
  on conflict (auth_uid) do update set vinculado_em = now(), simulado = true;

  -- Parceiro comercial (Distribuidora, educação): duas oportunidades, sala, negócio ganho, parcelas recebidas, nota conferida e aprovada
  p := ext.pedir_como(g_dist, 'oportunidade', 'Implantação do método na rede (' || tag || ')', 'Rede municipal com 12 escolas; secretaria pediu proposta até o fim do mês.', null, 'Prefeitura simulada A ' || tag);
  select id into o1 from ext.oportunidade where pedido = p;
  perform ext.sala_enviar_como(g_dist, o1, 'Secretaria confirmou interesse; pode mandar a proposta?');
  perform set_config('request.jwt.claim.sub', '', true);
  perform ext.sala_responder(o1, 'Proposta sai amanhã; reunião de alinhamento na quinta.', neg);
  perform ext.oportunidade_decidir(o1, 'ganha', 36000, 6, date_trunc('month', now())::date, null, neg);
  select array_agg(id order by parcela) into k from ext.comissao where oportunidade = o1;
  perform ext.comissao_adquirir(k[1], gest); perform ext.comissao_adquirir(k[2], gest);
  r := ext.prestacao_enviar_como(g_dist, 'nf', 'NF comissão ' || tag || '.pdf', encode(extensions.digest('sim-nf-' || tag || random()::text, 'sha256'), 'hex'), 'application/pdf', 2048,
        E'NOTA FISCAL DE SERVIÇO ELETRÔNICA\nPrestador: Distribuidora parceira (simulada) CNPJ 11.222.333/0002-62\nNúmero: ' || right(tag, 6) || E'\nValor total da nota: R$ 1.200,00', k[1:2]);
  perform set_config('request.jwt.claim.sub', '', true);
  if r->>'situacao' = 'conferida' then perform ext.prestacao_decidir((r->>'prestacao')::bigint, 'aprovado', 'conferida pela máquina e pela Gestão', gest); end if;
  perform ext.prestacao_enviar_como(g_dist, 'relatorio', 'Relatório de atividades ' || tag || '.pdf', encode(extensions.digest('sim-rel-' || tag || random()::text, 'sha256'), 'hex'), 'application/pdf', 1024,
        'Relatório de atividades do parceiro: visitas, apresentações e retorno das escolas no mês.', '{}');
  perform set_config('request.jwt.claim.sub', '', true);
  p := ext.pedir_como(g_dist, 'oportunidade', 'Formação de professores (' || tag || ')', 'Consórcio de municípios pediu formação para 300 professores.', null, 'Consórcio simulado B ' || tag);
  select id into o2 from ext.oportunidade where pedido = p;
  perform ext.oportunidade_decidir(o2, 'em_negociacao', null, null, null, null, neg);
  perform ext.sala_enviar_como(g_dist, o2, 'Consórcio quer a proposta por município; dá para dividir?');
  perform set_config('request.jwt.claim.sub', '', true);
  n := n + 2;

  -- Cliente da saúde: reclamação com encaminhamentos e reunião com ata; OS aguardando o cliente; chamado encerrado; ouvidoria anônima; dúvida nova
  p := ext.pedir_como(f_sms, 'reclamacao', 'Relatório mensal atrasado (' || tag || ')', 'O relatório de indicadores do mês não chegou na data combinada.', null, null);
  perform set_config('request.jwt.claim.sub', '', true);
  e := ext.encaminhar(p, 'Reenviar o relatório do mês com os indicadores completos', op7, now() + interval '2 days', op7);
  perform ext.encaminhamento_concluir(e, 'concluido', 'Relatório reenviado com os indicadores completos.', op7);
  perform ext.encaminhar(p, 'Rever a rotina de fechamento mensal para não atrasar', gest, now() + interval '7 days', op7);
  perform ext.responder(p, 'Relatório reenviado; estamos revendo a rotina de fechamento.', 'em_atendimento', op7);
  re := ext.reuniao_agendar(sau, 'Alinhamento sobre o relatório mensal (' || tag || ')', now() - interval '2 hours', 30, 'meet', p, null, true, op7);
  perform ext.reuniao_consentir(re, 'Fiscal do contrato, por voz no início da reunião', op7);
  perform ext.reuniao_transcricao(re, 'Transcrição ' || tag || '.txt', encode(extensions.digest('sim-tr-' || tag || random()::text, 'sha256'), 'hex'), 'text/plain', 600,
        'Transcrição (simulada). Fiscal: o relatório chegou atrasado dois meses seguidos. Operações: o fechamento depende de dados das unidades que chegam no dia 3. Combinado: dados das unidades até o dia 1 e relatório até o dia 5; Gestão revê a rotina.', null, op7);
  ata := jsonb_build_object('resumo', 'A secretaria relatou atraso do relatório mensal em dois meses seguidos. A causa é a chegada tardia dos dados das unidades.',
    'decisoes', jsonb_build_array('Dados das unidades até o dia 1', 'Relatório até o dia 5 de cada mês'),
    'encaminhamentos', jsonb_build_array(jsonb_build_object('descricao', 'Combinar com as unidades o envio dos dados até o dia 1', 'responsavel', 'Operações · pessoa', 'prazo_dias', 3)),
    'origem', 'ia');
  perform ext.reuniao_ata_aprovar(re, ata, op7);
  p := ext.pedir_como(g_sms, 'os', 'Instalar o painel na unidade 2 (' || tag || ')', 'Precisamos do painel de indicadores também na unidade 2.', null, null);
  perform set_config('request.jwt.claim.sub', '', true);
  e := ext.encaminhar(p, 'Instalar e configurar o painel na unidade 2', op7, now() + interval '1 day', op7);
  perform ext.encaminhamento_concluir(e, 'concluido', 'Painel instalado e testado com a equipe da unidade.', op7);
  perform ext.responder(p, 'Painel instalado na unidade 2. Confirme o encerramento, por favor.', 'respondido', op7);
  p := ext.pedir_como(f_sms, 'chamado', 'Acesso ao painel caiu (' || tag || ')', 'Desde a manhã o painel não abre para a equipe da regulação.', null, null);
  perform set_config('request.jwt.claim.sub', '', true);
  e := ext.encaminhar(p, 'Restabelecer o acesso da equipe da regulação', op7, now() + interval '4 hours', op7);
  perform ext.encaminhamento_concluir(e, 'concluido', 'Certificado renovado; acesso restabelecido.', op7);
  perform ext.responder(p, 'Acesso restabelecido.', 'respondido', op7);
  perform ext.atendimento_confirmar_como(f_sms, p, 5::smallint, 'Resolvido rápido.');
  perform set_config('request.jwt.claim.sub', '', true);
  p := ext.ouvidoria_como(fin_sms, 'Conduta no atendimento presencial (' || tag || ')', 'Relato sobre a postura de um atendente na visita técnica.', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform ext.encaminhar(p, 'Ouvir a equipe da visita técnica e apurar', gov, now() + interval '5 days', gov);
  p := ext.pedir_como(g_sms, 'duvida', 'Prazo de renovação do contrato (' || tag || ')', 'Qual o prazo para pedir a renovação?', null, null);
  perform set_config('request.jwt.claim.sub', '', true);
  n := n + 5;

  -- Cliente da educação: reclamação nova e reunião de terceiros no Zoom (participação pelo link do convite)
  p := ext.pedir_como(g_sme, 'reclamacao', 'Material da formação incompleto (' || tag || ')', 'Faltaram apostilas para duas turmas.', null, null);
  perform set_config('request.jwt.claim.sub', '', true);
  perform ext.reuniao_agendar(edu, 'Reunião da secretaria no Zoom, a convite dela (' || tag || ')', now() + interval '2 days', 60, 'zoom', p, null, false, op7);
  n := n + 1;

  -- Acervo: cartão CNPJ de exemplo de cada empresa simulada (proposta com duas mãos) e uma minuta de modelo na saúde
  for emp in select id, nome, row_number() over (order by nome) i from org.empresa where simulado and ativa loop
    base := '11222333' || lpad((10 + emp.i)::text, 4, '0');
    perform acervo._registrar(emp.id, 'Cartão CNPJ (simulado) ' || tag || '.pdf', encode(extensions.digest('sim-cnpj-' || emp.id || tag || random()::text, 'sha256'), 'hex'), 'application/pdf', 900,
      'COMPROVANTE DE INSCRIÇÃO E DE SITUAÇÃO CADASTRAL NÚMERO DE INSCRIÇÃO ' || acervo._cnpj_formatar(base || acervo._cnpj_dv(base)) || E'\nNOME EMPRESARIAL: ' || upper(emp.nome) || E' LTDA\nTÍTULO DO ESTABELECIMENTO',
      'upload', null, null, v, null);
  end loop;
  x := acervo._registrar_e_derivar(acervo._registrar(sau, 'Minuta de ofício (simulada) ' || tag || '.docx', encode(extensions.digest('sim-min-' || tag || random()::text, 'sha256'), 'hex'),
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 700,
         E'Minuta de ofício\nCLÁUSULA 1ª – OBJETO\n1.1 Encaminhamos o relatório mensal de indicadores.\na) anexo com os dados das unidades;\nAtenciosamente.', 'upload', null, null, v, null),
       E'Minuta de ofício\nCLÁUSULA 1ª – OBJETO\n1.1 Encaminhamos o relatório mensal de indicadores.\na) anexo com os dados das unidades;\nAtenciosamente.');

  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('simulacao', 'ciclo ' || tag, null, adm.simulacao_painel(v)->'movimento', v, case when rt.eu() is null then 'serviço (implantação ou rotina)' else 'aplicativo' end, 'ciclo completo de simulação gerado');
  return jsonb_build_object('ciclo', tag, 'demandas', n, 'movimento', adm.simulacao_painel(v)->'movimento');
end $$;

-- zerar: em lotes (a página repete até "feito"); desliga a simulação na primeira chamada
create or replace function adm.zerar_simulacoes(p_frase text, p_como uuid default null, p_lote int default 40000) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._admin(p_como); antes jsonb; n int; ap jsonb := '{}'; inst bigint[]; feito boolean;
begin
  if p_frase is distinct from 'ZERAR SIMULAÇÕES' then raise exception 'para confirmar, digite exatamente: ZERAR SIMULAÇÕES'; end if;
  antes := adm.simulacao_painel(v)->'movimento';
  update adm.parametro set valor = 'false', atualizado_em = now(), atualizado_por = v where chave = 'simulacao.ativa' and valor <> 'false'::jsonb;
  -- de fora (clientes e parceiros simulados)
  delete from ext.sala_mensagem m using ext.oportunidade o, ext.contraparte c where m.oportunidade = o.id and o.contraparte = c.id and c.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('mensagens_de_sala', n);
  delete from ext.comissao k using ext.contraparte c where k.contraparte = c.id and c.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('comissoes', n);
  delete from ext.encaminhamento e where exists (select 1 from ext.pedido p join ext.contraparte c on c.id = p.contraparte where p.id = e.pedido and c.simulado)
     or exists (select 1 from ext.reuniao r join org.empresa x on x.id = r.empresa where r.id = e.reuniao and x.simulado); get diagnostics n = row_count; ap := ap || jsonb_build_object('encaminhamentos', n);
  delete from ext.reuniao r using org.empresa x where r.empresa = x.id and x.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('reunioes', n);
  delete from ext.prestacao x using ext.contraparte c where x.contraparte = c.id and c.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('prestacoes', n);
  delete from ext.oportunidade o using ext.contraparte c where o.contraparte = c.id and c.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('oportunidades', n);
  delete from ext.pedido p using ext.contraparte c where p.contraparte = c.id and c.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('pedidos_de_fora', n);
  delete from ext.documento d using ext.contraparte c where d.contraparte = c.id and c.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('documentos_publicados', n);
  delete from ext.publicacao where simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('publicacoes', n);
  delete from ext.vinculo w using ext.contraparte c where w.contraparte = c.id and c.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('vinculos', n);
  delete from ext.telegram where simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('telegram', n);
  -- acervo, marca e minutas das empresas simuladas
  delete from doc.marca_proposta m using org.empresa x where m.empresa = x.id and x.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('propostas_de_marca', n);
  delete from doc.minuta m using org.empresa x where m.empresa = x.id and x.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('minutas', n);
  delete from acervo.divergencia d using org.empresa x where d.empresa = x.id and x.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('divergencias', n);
  delete from acervo.campo f using org.empresa x where f.empresa = x.id and x.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('dados_propostos', n);
  update acervo.arquivo a set versao_de = null from org.empresa x where a.empresa = x.id and x.simulado and a.versao_de is not null;
  delete from acervo.arquivo a using org.empresa x where a.empresa = x.id and x.simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('arquivos_do_acervo', n);
  -- runtime simulado, em lotes
  delete from rt.fila_envio where simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('fila_de_envio', n);
  delete from rt.mensagem where simulado; get diagnostics n = row_count; ap := ap || jsonb_build_object('mensagens', n);
  delete from rt.troca_envio where ctid = any (array(select ctid from rt.troca_envio where simulado limit p_lote)); get diagnostics n = row_count; ap := ap || jsonb_build_object('trocas', n);
  delete from rt.evento where ctid = any (array(select ctid from rt.evento where simulado limit p_lote)); get diagnostics n = row_count; ap := ap || jsonb_build_object('eventos', n);
  if not exists (select 1 from rt.evento where simulado) then
    update rt.cartao set pai = null where simulado and pai is not null;
    delete from rt.cartao where ctid = any (array(select ctid from rt.cartao where simulado limit p_lote)); get diagnostics n = row_count; ap := ap || jsonb_build_object('cartoes', n);
    select coalesce(array_agg(i.id), '{}') into inst from (select id from rt.instancia i where simulado
       and not exists (select 1 from rt.cartao k where k.instancia = i.id) and not exists (select 1 from doc.pedido d where d.instancia = i.id) limit p_lote) i;
    delete from rt.token where instancia = any (inst);
    delete from rt.instancia where id = any (inst); get diagnostics n = row_count; ap := ap || jsonb_build_object('instancias', n);
  end if;
  feito := not exists (select 1 from rt.evento where simulado) and not exists (select 1 from rt.troca_envio where simulado)
       and not exists (select 1 from rt.cartao where simulado)
       and not exists (select 1 from rt.instancia i where simulado and not exists (select 1 from doc.pedido d where d.instancia = i.id));
  if feito then
    insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
    values ('simulacao', 'corte ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM/YYYY HH24:MI'), antes, adm.simulacao_painel(v)->'movimento', v,
            case when rt.eu() is null then 'serviço (implantação ou rotina)' else 'aplicativo' end,
            'simulações zeradas: base de produção começa aqui; simulação contínua desligada; trilhas de auditoria e documentos emitidos ficam');
  end if;
  return jsonb_build_object('feito', feito, 'apagados', ap, 'restante', adm.simulacao_painel(v)->'movimento');
end $$;

create or replace function adm.religar_simulacao(p_como uuid default null) returns void language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._admin(p_como);
begin
  if exists (select 1 from org.empresa where not simulado) then raise exception 'já há empresa real cadastrada: a simulação não volta a rodar na base de produção'; end if;
  update adm.parametro set valor = 'true', atualizado_em = now(), atualizado_por = v where chave = 'simulacao.ativa';
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('simulacao', 'religada ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM/YYYY HH24:MI'), jsonb_build_object('ativa', false), jsonb_build_object('ativa', true), v,
          case when rt.eu() is null then 'serviço (implantação ou rotina)' else 'aplicativo' end, 'simulação religada');
end $$;

revoke all on function adm._admin(uuid), adm.simulacao_painel(uuid), adm.simular_ecossistema(uuid), adm.zerar_simulacoes(text, uuid, int), adm.religar_simulacao(uuid) from public, anon, authenticated;
grant execute on function adm.simulacao_painel(uuid), adm.simular_ecossistema(uuid), adm.zerar_simulacoes(text, uuid, int), adm.religar_simulacao(uuid) to authenticated, service_role;
commit;
