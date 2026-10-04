-- IA com dois provedores (aprovado em 04/10/2026): Anthropic e Kimi (Moonshot AI), com reserva automática.
-- ia.provedor escolhe o principal; se ele falhar (fora do ar ou sem chave), a função tenta o outro, quando configurado.
-- Kimi: API compatível com a da OpenAI (Chat Completions). Endereço e modelo são parâmetros, preenchidos na implantação
-- a partir da documentação oficial (platform.kimi.ai); segredo no cofre: kimi_chave.
begin;
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('ia.provedor', 'global', 'Provedor principal da IA: anthropic ou kimi; o outro fica de reserva quando configurado', 'texto', '"anthropic"', '"anthropic"', '{}', true, '{}', 'Decisão de 04/10/2026'),
 ('ia.kimi_modelo', 'global', 'Modelo da API Kimi (nome exato da lista de modelos da plataforma)', 'texto', '""', '""', '{}', true, '{}', 'Decisão de 04/10/2026'),
 ('ia.kimi_url', 'global', 'Endereço base da API Kimi compatível com a OpenAI (termina em /v1), conforme a documentação oficial', 'texto', '""', '""', '{}', true, '{}', 'Decisão de 04/10/2026')
on conflict (chave) do nothing;
create or replace function adm.servidor_autorizar(p_funcao text, p_acao text, p_dados jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu(); u ext.usuario; c ext.contraparte; emp uuid; v_pasta text; r jsonb; v_id text; usado bigint; teto bigint;
  sistema text := nullif(adm.valor('google.usuario_sistema', '""') #>> '{}', ''); raiz text := nullif(adm.valor('google.drive_raiz', '""') #>> '{}', '');
begin
  if v is null then u := ext.eu(); end if;
  if v is null and u.auth_uid is null then raise exception 'login sem cadastro'; end if;
  v_id := nullif(p_dados->>'id', '');

  if p_funcao = 'google' then
    if sistema is null then raise exception 'Google ainda não configurado: falta o parâmetro google.usuario_sistema'; end if;
    r := jsonb_build_object('usuario_sistema', sistema, 'drive_raiz', raiz, 'pessoa', v, 'usuario', u.auth_uid);

    if p_acao = 'drive_enviar' then
      if v is not null then
        emp := nullif(p_dados->>'empresa', '')::uuid; v_pasta := coalesce(nullif(p_dados->>'pasta', ''), '00');
        if emp is null or not rt.pode(v, emp, null, 'operar') then raise exception 'sem acesso de operar nesta empresa'; end if;
        if not exists (select 1 from acervo.pasta where codigo = v_pasta) then raise exception 'pasta do acervo inexistente: %', v_pasta; end if;
      else
        u := ext._exigir_eu(); select * into c from ext.contraparte where id = u.contraparte;
        emp := c.empresa; v_pasta := case c.tipo when 'parceiro' then '07' else '08' end;   -- quem é de fora só envia para a sua pasta
      end if;
      return r || jsonb_build_object('empresa', emp, 'pasta', v_pasta, 'pasta_nome', (select nome from acervo.pasta where codigo = v_pasta),
        'empresa_nome', (select nome from org.empresa where id = emp),
        'pasta_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = v_pasta),
        'raiz_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = 'raiz'));

    elsif p_acao = 'drive_pasta' then
      emp := nullif(p_dados->>'empresa', '')::uuid; v_pasta := p_dados->>'pasta';
      if v is null or emp is null or not rt.pode(v, emp, null, 'operar') then raise exception 'sem acesso de operar nesta empresa'; end if;
      if v_pasta <> 'raiz' and not exists (select 1 from acervo.pasta where codigo = v_pasta) then raise exception 'pasta do acervo inexistente: %', v_pasta; end if;
      return r || jsonb_build_object('empresa', emp, 'pasta', v_pasta, 'empresa_nome', (select nome from org.empresa where id = emp),
        'pasta_nome', case when v_pasta = 'raiz' then (select nome from org.empresa where id = emp) else (select nome from acervo.pasta where codigo = v_pasta) end,
        'pasta_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = v_pasta),
        'raiz_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = 'raiz'));

    elsif p_acao = 'drive_ler' then
      if v is null or not rt.pode(v, null, null, 'operar') then raise exception 'só a equipe lê arquivos do Drive'; end if;
      if v_id is null then raise exception 'informe o id do arquivo'; end if;
      return r || jsonb_build_object('id', v_id);

    elsif p_acao in ('drive_lixeira', 'drive_mover', 'drive_renomear') then
      if v_id is null then raise exception 'informe o id do arquivo'; end if;
      -- o arquivo precisa ser do acervo de uma empresa em que a pessoa opera, ou ter sido enviado por ela na última hora
      if not exists (select 1 from acervo.arquivo a where a.drive_id = v_id and v is not null and rt.pode(v, a.empresa, null, 'operar'))
         and not exists (select 1 from adm.registro_servidor s where s.funcao = 'google' and s.acao = 'drive_enviar' and s.ok and s.alvo = v_id
                          and s.em > now() - interval '1 hour' and (s.pessoa = v or s.usuario = u.auth_uid)) then
        raise exception 'arquivo fora do seu acervo'; end if;
      if p_acao in ('drive_lixeira', 'drive_mover') and v is null then raise exception 'só a equipe move ou apaga arquivos'; end if;
      if p_acao = 'drive_mover' then
        select a.empresa into emp from acervo.arquivo a where a.drive_id = v_id limit 1;
        emp := coalesce(emp, nullif(p_dados->>'empresa', '')::uuid); v_pasta := p_dados->>'pasta';
        if emp is null or not rt.pode(v, emp, null, 'operar') then raise exception 'sem acesso de operar nesta empresa'; end if;
        if not exists (select 1 from acervo.pasta where codigo = v_pasta) then raise exception 'pasta do acervo inexistente: %', v_pasta; end if;
        return r || jsonb_build_object('id', v_id, 'empresa', emp, 'pasta', v_pasta, 'pasta_nome', (select nome from acervo.pasta where codigo = v_pasta),
          'pasta_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = v_pasta),
          'raiz_id', (select drive_id from acervo.pasta_drive where empresa = emp and pasta_drive.pasta = 'raiz'), 'empresa_nome', (select nome from org.empresa where id = emp));
      end if;
      return r || jsonb_build_object('id', v_id);

    elsif p_acao in ('drive_listar', 'drive_baixar') then
      if v is null then raise exception 'só a equipe lista o Drive'; end if;
      -- listar: a pasta precisa estar registrada numa empresa em que a pessoa opera; baixar: um dos pais do arquivo (a função manda) também
      if not exists (select 1 from acervo.pasta_drive d where rt.pode(v, d.empresa, null, 'operar')
                       and d.drive_id = any (array(select jsonb_array_elements_text(coalesce(p_dados->'pais', jsonb_build_array(p_dados->>'pasta_id')))))) then
        raise exception 'pasta fora do acervo das suas empresas'; end if;
      return r || jsonb_build_object('id', v_id, 'pasta_id', p_dados->>'pasta_id');

    elsif p_acao in ('agenda_evento', 'agenda_cancelar') then
      if v is null or not rt.pode(v, null, null, 'operar') then raise exception 'só a equipe marca reunião'; end if;
      return r || jsonb_build_object('organizador', (select email from rt_chave.identidade where pseudonimo = v));
    end if;
    raise exception 'ação do Google desconhecida: %', p_acao;

  elsif p_funcao = 'ia' then
    if v is null or not rt.pode(v, null, null, 'operar') then raise exception 'só a equipe usa a IA'; end if;
    teto := coalesce((adm.valor('ia.orcamento_mensal_tokens', '0') #>> '{}')::bigint, 0); usado := adm._ia_usado_no_mes();
    if usado >= teto then raise exception 'orçamento mensal da IA esgotado (% de % tokens)', usado, teto; end if;
    if p_acao = 'ata_rascunho' then
      if not exists (select 1 from ext.reuniao where id = nullif(p_dados->>'reuniao', '')::bigint) then raise exception 'reunião inexistente'; end if;
      perform ext._reuniao_acesso(nullif(p_dados->>'reuniao', '')::bigint, v);
      return jsonb_build_object('pessoa', v, 'restante', teto - usado,
        'provedor', coalesce(adm.valor('ia.provedor', '"anthropic"') #>> '{}', 'anthropic'),
        'modelo', adm.valor('ia.modelo', '"claude-sonnet-5-5"') #>> '{}',
        'kimi_modelo', nullif(adm.valor('ia.kimi_modelo', '""') #>> '{}', ''),
        'kimi_url', nullif(rtrim(coalesce(adm.valor('ia.kimi_url', '""') #>> '{}', ''), '/'), ''));
    end if;
    raise exception 'ação de IA desconhecida: %', p_acao;
  end if;
  raise exception 'função do servidor desconhecida: %', p_funcao;
end $$;;
insert into adm.conexao (codigo, nome, categoria, ambiente, endpoint, dono, estado, segredos, verificacao, alvo, pendencia, fonte) values
 ('ia-kimi', 'API Kimi (Moonshot AI), reserva da IA', 'ia', 'produção', null, 'Integração', 'pendente', '{kimi_chave}', 'manual', null,
  'gravar kimi_chave no cofre e preencher ia.kimi_url e ia.kimi_modelo', '070, decisão de 04/10/2026')
on conflict (codigo) do nothing;
commit;
