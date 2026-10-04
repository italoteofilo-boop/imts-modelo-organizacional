-- Fechamento das travas do protótipo (04/10/2026, 14:01, "resolva todas as travas").
begin;
-- Google Meet: verificado com um evento real criado e apagado em seguida (04/10/2026, 14:03); a resposta traz o link em conferenceUrl
update adm.conexao set estado = 'ativa', saude = 'ok', saude_detalhe = 'evento de teste com Meet criado e apagado em 04/10/2026; link em conferenceUrl',
       verificada_em = now(), atualizado_em = now(),
       pendencia = 'No protótipo a agenda usada é a do conector Google Calendar de quem abre a Central (hoje a conta pessoal do Gmail). Para usar a agenda do Workspace IMTS, conectar o Google Calendar com a conta @imts.com.br.'
 where codigo = 'google-meet';
-- Prazos de atendimento: referências conferidas; os valores de partida ficam mais rigorosos que elas
update adm.parametro set fonte = 'E20, 04/10/2026. Referência: Decreto 11.034/2022, art. 13 (SAC de serviço regulado pelo governo federal responde em 7 dias corridos); aqui 72 horas para a primeira resposta', atualizado_em = now()
 where chave = 'atendimento.prazo_os_horas';
update adm.parametro set fonte = 'E20, 04/10/2026. Referência: Lei 13.460/2017, art. 16 (ouvidoria pública responde em até 30 dias, prorrogáveis por 30); aqui 10 dias', atualizado_em = now()
 where chave = 'atendimento.prazo_ouvidoria_dias';
update adm.parametro set fonte = 'E20, 04/10/2026. Sem norma que fixe; 5 dias corridos depois da proposta de encerramento, com aviso no portal e no Telegram', atualizado_em = now()
 where chave = 'atendimento.aceite_tacito_dias';
update adm.parametro set fonte = 'E21, 04/10/2026. LGPD, art. 15 e 16: dado pessoal é eliminado quando a finalidade se cumpre; a ata aprovada fica, a gravação e a transcrição saem 90 dias depois', atualizado_em = now()
 where chave = 'reuniao.retencao_gravacao_dias';
alter table ext.reuniao add column if not exists gravacao_apagada_em timestamptz;
-- retenção: depois do prazo, a Central manda a transcrição do Drive para a lixeira e registra aqui; a ata fica
create or replace function ext.reuniao_gravacao_apagada(p_reuniao bigint, p_como uuid default null) returns void language plpgsql security definer set search_path = '' as $$
declare r ext.reuniao := ext._reuniao_acesso(p_reuniao, p_como);
begin
  if r.transcricao is null or r.gravacao_apagada_em is not null then raise exception 'não há gravação a apagar'; end if;
  if r.apagar_gravacao_em is null or r.apagar_gravacao_em > current_date then raise exception 'o prazo de retenção ainda não venceu (%)', to_char(r.apagar_gravacao_em, 'DD/MM/YYYY'); end if;
  update acervo.arquivo set drive_id = null, motivo = 'transcrição eliminada em ' || to_char(current_date, 'DD/MM/YYYY') || ' pela retenção da reunião ' || r.id, atualizado_em = now() where id = r.transcricao;
  update ext.reuniao set gravacao_apagada_em = now() where id = r.id;
end $$;
revoke all on function ext.reuniao_gravacao_apagada(bigint, uuid) from public, anon, authenticated;
grant execute on function ext.reuniao_gravacao_apagada(bigint, uuid) to authenticated, service_role;
create or replace function ext.painel_reunioes(p_empresa uuid, p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu(); gov boolean;
begin
  if v is null then if not rt.chamada_servico() then raise exception 'sem identidade'; end if; v := p_como; end if;
  if v is null or not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso de leitura nesta empresa'; end if;
  gov := rt.pode(v, p_empresa, 9::smallint, 'ler');
  return jsonb_build_object(
    'reunioes', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'titulo', r.titulo, 'inicio', r.inicio, 'duracao_min', r.duracao_min, 'plataforma', r.plataforma, 'link', r.link,
        'evento_id', r.evento_id, 'gravar', r.gravar, 'consentimentos', r.consentimentos, 'situacao', r.situacao, 'pedido', r.pedido,
        'contraparte', case when x.anonimo then 'anônima' else c.nome end, 'transcricao', a.nome, 'transcricao_drive', a.drive_id, 'ata', r.ata, 'ata_situacao', r.ata_situacao,
        'ata_em', r.ata_em, 'apagar_gravacao_em', r.apagar_gravacao_em, 'gravacao_apagada_em', r.gravacao_apagada_em,
        'encaminhamentos', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'descricao', e.descricao, 'responsavel', p.papel, 'prazo', e.prazo, 'situacao', e.situacao) order by e.id), '[]')
            from ext.encaminhamento e left join rt.pessoa p on p.pseudonimo = e.responsavel where e.reuniao = r.id)) order by r.inicio desc), '[]')
        from ext.reuniao r left join ext.contraparte c on c.id = r.contraparte left join ext.pedido x on x.id = r.pedido left join acervo.arquivo a on a.id = r.transcricao
       where r.empresa = p_empresa and (x.tipo is distinct from 'ouvidoria' or gov)),
    'contrapartes', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'nome', nome, 'tipo', tipo) order by tipo, nome), '[]') from ext.contraparte where empresa = p_empresa and ativa),
    'conexoes', (select jsonb_agg(jsonb_build_object('codigo', codigo, 'nome', nome, 'estado', estado, 'pendencia', pendencia) order by codigo) from adm.conexao where categoria = 'videoconferência'));
end $$;
-- parceiros simulados com CNPJ de exemplo (11.222.333/0001-81 é o número de exemplo usado em validadores; filial 0002 com dígito calculado),
-- para a conferência da nota rodar de ponta a ponta no protótipo; parceiro real entra com o CNPJ do contrato
update ext.contraparte set documento = '11.222.333/0001-81' where simulado and tipo = 'parceiro' and nome like 'Escritório regional%' and documento is null;
update ext.contraparte set documento = '11.222.333/0002-62' where simulado and tipo = 'parceiro' and nome like 'Distribuidora parceira%' and documento is null;
-- rodada única com as 15 suítes (vale esta definição; os arquivos de teste anteriores redefinem a função com menos suítes)
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes'] loop
    begin
      execute format('select %s()', s) into msg;
      raise exception using errcode = 'P0099', message = msg;
    exception when sqlstate 'P0099' then res := res || jsonb_build_object(s, jsonb_build_object('ok', true, 'resultado', sqlerrm));
              when others then res := res || jsonb_build_object(s, jsonb_build_object('ok', false, 'resultado', sqlerrm));
    end;
  end loop;
  return jsonb_build_object('todas_ok', not exists (select 1 from jsonb_each(res) e where not (e.value->>'ok')::boolean), 'suites', res);
end $f$;
commit;
