-- Vínculo do Telegram da equipe pela Mesa (decisão de Ítalo, 21/10/2026).
-- Antes: parceiro e cliente ligavam o Telegram com /vincular CÓDIGO (047); a pessoa da equipe dependia da Gestão gravar o telegram_id
-- e o consentimento no cadastro (GE-07). Agora a própria pessoa da equipe gera o código na Mesa da web, depois de aceitar o termo
-- (LGPD, art. 33, VIII), e envia /vincular CÓDIGO ao bot numa conversa privada. O caminho da GE-07 continua valendo.
-- Depende de 003, 017, 019, 028, 047 e 082. Não mexe no motor, no portal nem no Mini App.
-- 1. Parâmetros: validade do código, limite por hora e o texto do termo.
-- 2. rt_chave.tg_codigo: códigos de uso único (só o hash), com o aceite registrado; adm.historico aceita o objeto 'telegram'.
-- 3. Pessoa (porta única, login de dentro): rt.tg_vinculo (estado), rt.tg_codigo_gerar (código), rt.tg_desvincular (desliga).
-- 4. Bot: rt.receber_update passa a ser um invólucro: /vincular com código da equipe vai a rt._tg_vincular_equipe; o resto segue
--    para a função de antes (rt._receber_update_base, sem cópia). Os textos para quem ainda não tem vínculo citam a Mesa.
begin;

-- 1. Parâmetros ------------------------------------------------------------------------------------------------------------
insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('telegram.vinculo_codigo_minutos', 'telegram', 'Validade, em minutos, do código que a pessoa da equipe gera na Mesa para ligar o Telegram (/vincular CÓDIGO)',
  'inteiro', '15', '15', '{"min":5,"max":60}', true, '{rt.tg_codigo_gerar}', '089; decisão de 21/10/2026 (vínculo pela Mesa)'),
 ('telegram.vinculo_codigos_hora', 'telegram', 'Códigos de vínculo do Telegram que uma pessoa da equipe pode gerar por hora',
  'inteiro', '5', '5', '{"min":1,"max":30}', true, '{rt.tg_codigo_gerar}', '089; segurança do vínculo'),
 ('telegram.vinculo_termo', 'telegram', 'Termo que a pessoa da equipe aceita na Mesa antes de gerar o código do Telegram (consentimento do art. 33, VIII, da LGPD). O texto aceito fica guardado com o código',
  'texto', to_jsonb('Autorizo o IMTS a usar o identificador da minha conta do Telegram para me enviar e receber mensagens de trabalho pelo bot do IMTS.OS. Sei que o Telegram é um serviço com dados tratados fora do Brasil (LGPD, art. 33, VIII) e que posso desligar o Telegram na Mesa a qualquer momento, o que revoga este consentimento.'::text),
  to_jsonb('Autorizo o IMTS a usar o identificador da minha conta do Telegram para me enviar e receber mensagens de trabalho pelo bot do IMTS.OS. Sei que o Telegram é um serviço com dados tratados fora do Brasil (LGPD, art. 33, VIII) e que posso desligar o Telegram na Mesa a qualquer momento, o que revoga este consentimento.'::text),
  '{}', true, '{mesa:Ligar o Telegram}', '089; LGPD, art. 8º e art. 33, VIII')
on conflict (chave) do nothing;

-- 2. Códigos e auditoria ---------------------------------------------------------------------------------------------------
create table if not exists rt_chave.tg_codigo (
  id                 bigint generated always as identity primary key,
  pessoa             uuid not null references rt.pessoa(pseudonimo),
  codigo_hash        text not null check (codigo_hash ~ '^[0-9a-f]{64}$'),
  criado_em          timestamptz not null default now(),
  expira_em          timestamptz not null,
  consentimento_em   timestamptz not null,
  consentimento_texto text not null check (length(btrim(consentimento_texto)) > 0),
  usado_em           timestamptz,
  invalidado_em      timestamptz,
  invalidado_motivo  text,
  simulado           boolean not null,
  check (expira_em > criado_em),
  check (usado_em is null or invalidado_em is null)
);
create index if not exists tg_codigo_hash on rt_chave.tg_codigo (codigo_hash);
create index if not exists tg_codigo_pessoa on rt_chave.tg_codigo (pessoa, criado_em desc);
alter table rt_chave.tg_codigo enable row level security;
revoke all on rt_chave.tg_codigo from public, anon, authenticated;

do $$
declare v_def text; v_lista text[];
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint where conname = 'historico_objeto_check' and conrelid = 'adm.historico'::regclass;
  v_lista := array(select m[1] from regexp_matches(coalesce(v_def, ''), '''([a-z_]+)''', 'g') m);
  if not ('telegram' = any (v_lista)) then
    v_lista := v_lista || 'telegram'::text;
    alter table adm.historico drop constraint if exists historico_objeto_check;
    execute format('alter table adm.historico add constraint historico_objeto_check check (objeto in (%s))',
                   (select string_agg(quote_literal(x), ', ') from unnest(v_lista) x));
  end if;
end $$;

-- Registro no histórico (sem o código e sem o número do Telegram: só o que aconteceu, quem e por onde)
create or replace function rt._tg_auditar(p_pessoa uuid, p_evento text, p_como text, p_motivo text, p_antes jsonb default null) returns void
language sql security definer set search_path = '' as $$
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('telegram', p_pessoa::text, p_antes, jsonb_build_object('evento', p_evento), p_pessoa, p_como, p_motivo) $$;

-- 3. Pessoa da equipe (porta única) ----------------------------------------------------------------------------------------
-- Estado do vínculo para a Mesa: ligado ou não, desde quando, código em aberto (só a validade), limites e o termo
create or replace function rt.tg_vinculo() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); i rt_chave.identidade; k rt_chave.tg_codigo;
  v_lim int := coalesce((adm.valor('telegram.vinculo_codigos_hora', '5') #>> '{}')::int, 5); v_n int;
begin
  select * into i from rt_chave.identidade where pseudonimo = v;
  select * into k from rt_chave.tg_codigo where pessoa = v and usado_em is null and invalidado_em is null and expira_em > now() order by id desc limit 1;
  select count(*) into v_n from rt_chave.tg_codigo where pessoa = v and criado_em > now() - interval '1 hour';
  return jsonb_build_object(
    'ligado', i.telegram_id is not null,
    'desde', case when i.telegram_id is not null then coalesce((select max(usado_em) from rt_chave.tg_codigo where pessoa = v and usado_em is not null), i.consentimento_art33_em) end,
    'origem', case when i.telegram_id is null then null
                   when exists (select 1 from rt_chave.tg_codigo where pessoa = v and usado_em is not null) then 'mesa' else 'cadastro' end,
    'codigo_aberto', case when k.id is not null then jsonb_build_object('expira', k.expira_em) end,
    'validade_minutos', coalesce((adm.valor('telegram.vinculo_codigo_minutos', '15') #>> '{}')::int, 15),
    'limite_hora', v_lim,
    'restantes_hora', greatest(v_lim - v_n, 0),
    'termo', adm.valor('telegram.vinculo_termo', '""') #>> '{}');
end $$;

-- Gera o código (devolvido uma única vez; guardado só o hash). Exige o aceite do termo e respeita o limite por hora.
create or replace function rt.tg_codigo_gerar(p_aceite boolean) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); i rt_chave.identidade; c text; h text; n int := 0;
  v_min int := coalesce((adm.valor('telegram.vinculo_codigo_minutos', '15') #>> '{}')::int, 15);
  v_lim int := coalesce((adm.valor('telegram.vinculo_codigos_hora', '5') #>> '{}')::int, 5);
  v_termo text := btrim(coalesce(adm.valor('telegram.vinculo_termo', '""') #>> '{}', ''));
  v_exp timestamptz;
begin
  if not coalesce(p_aceite, false) then raise exception 'para ligar o Telegram, leia e aceite o termo de uso do Telegram (LGPD, art. 33, VIII)'; end if;
  if v_termo = '' then raise exception 'termo do Telegram não configurado (parâmetro telegram.vinculo_termo): fale com a administração'; end if;
  perform pg_advisory_xact_lock(hashtext('tg_codigo:' || v::text));
  select * into i from rt_chave.identidade where pseudonimo = v;
  if i.nome like 'eliminado em %' then raise exception 'cadastro inativo'; end if;
  if i.telegram_id is not null then raise exception 'seu Telegram já está ligado; para trocar de Telegram, desligue antes'; end if;
  if (select count(*) from rt_chave.tg_codigo where pessoa = v and criado_em > now() - interval '1 hour') >= v_lim then
    raise exception 'limite de % códigos por hora atingido: espere um pouco e gere de novo', v_lim;
  end if;
  update rt_chave.tg_codigo set invalidado_em = now(), invalidado_motivo = 'código mais novo gerado'
   where pessoa = v and usado_em is null and invalidado_em is null;
  loop
    c := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 8));
    h := encode(extensions.digest(c, 'sha256'), 'hex');
    exit when not exists (select 1 from rt_chave.tg_codigo where codigo_hash = h) and not exists (select 1 from ext.telegram where codigo_hash = h);
    n := n + 1; if n > 20 then raise exception 'não foi possível gerar um código agora; tente de novo'; end if;
  end loop;
  v_exp := now() + make_interval(mins => v_min);
  insert into rt_chave.tg_codigo (pessoa, codigo_hash, expira_em, consentimento_em, consentimento_texto, simulado)
  values (v, h, v_exp, now(), v_termo, i.simulado);
  perform rt._tg_auditar(v, 'codigo_gerado', 'mesa (web)', 'código de vínculo gerado com o aceite do termo (LGPD, art. 33, VIII); vale ' || v_min || ' minutos');
  return jsonb_build_object('codigo', c, 'comando', '/vincular ' || c, 'expira', v_exp, 'validade_minutos', v_min,
    'instrucao', 'Abra o bot do IMTS.OS no Telegram, numa conversa privada (não em grupo), e envie: /vincular ' || c || '. O código vale ' || v_min || ' minutos e só pode ser usado uma vez.');
end $$;

-- Desliga o Telegram da própria pessoa: tira o vínculo, revoga o consentimento, cancela códigos em aberto e avisa o Telegram que saiu
create or replace function rt.tg_desvincular() returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); i rt_chave.identidade;
begin
  perform pg_advisory_xact_lock(hashtext('tg_codigo:' || v::text));
  select * into i from rt_chave.identidade where pseudonimo = v for update;
  update rt_chave.tg_codigo set invalidado_em = now(), invalidado_motivo = 'Telegram desligado na Mesa'
   where pessoa = v and usado_em is null and invalidado_em is null;
  if i.telegram_id is null then
    return jsonb_build_object('ligado', false, 'texto', 'O Telegram já estava desligado.');
  end if;
  update rt_chave.identidade set telegram_id = null, consentimento_art33_em = null where pseudonimo = v;
  delete from rt.rota_chat where chat_ref = 'tg:' || i.telegram_id and descricao = 'conversa privada com o bot';
  insert into rt.fila_envio (chat_ref, texto, simulado)
  values ('tg:' || i.telegram_id, 'Este Telegram foi desligado do IMTS.OS pela Mesa. Para ligar de novo, gere um código na Mesa (Ligar o Telegram).', i.simulado);
  perform rt._tg_auditar(v, 'desvinculado', 'mesa (web)', 'Telegram desligado pela própria pessoa; consentimento do art. 33, VIII, revogado',
                         jsonb_build_object('ligado', true, 'consentimento_em', i.consentimento_art33_em));
  return jsonb_build_object('ligado', false, 'texto', 'Telegram desligado. O bot não fala mais com você até um novo vínculo.');
end $$;

-- 4. Bot -------------------------------------------------------------------------------------------------------------------
-- /vincular com código da equipe. Chamada só por rt.receber_update (serviço). Devolve { texto, vinculou, pessoa }.
create or replace function rt._tg_vincular_equipe(p_from bigint, p_chat text, p_tipo_chat text, p_codigo text, p_simulado boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare k rt_chave.tg_codigo; i rt_chave.identidade; v_h text := encode(extensions.digest(upper(btrim(p_codigo)), 'sha256'), 'hex'); v_min int;
begin
  select * into k from rt_chave.tg_codigo where codigo_hash = v_h order by id desc limit 1 for update;
  if k.id is null then return null; end if;
  if k.simulado <> p_simulado then raise exception 'mistura de simulado e real no vínculo do Telegram'; end if;
  if coalesce(p_tipo_chat, '') <> 'private' then
    if k.usado_em is null and k.invalidado_em is null then
      update rt_chave.tg_codigo set invalidado_em = now(), invalidado_motivo = 'código enviado fora de conversa privada' where id = k.id;
    end if;
    perform rt._tg_auditar(k.pessoa, 'recusa', 'bot do Telegram', 'código enviado em grupo: cancelado');
    return jsonb_build_object('texto', 'Por segurança, o vínculo é feito só numa conversa privada com o bot. Este código apareceu num grupo e foi cancelado: gere outro na Mesa (Ligar o Telegram).', 'vinculou', false);
  end if;
  v_min := coalesce((adm.valor('telegram.vinculo_codigo_minutos', '15') #>> '{}')::int, 15);
  if k.usado_em is not null then
    perform rt._tg_auditar(k.pessoa, 'recusa', 'bot do Telegram', 'código já usado');
    return jsonb_build_object('texto', 'Este código já foi usado. Para ligar de novo, gere outro na Mesa (Ligar o Telegram).', 'vinculou', false);
  end if;
  if k.invalidado_em is not null then
    perform rt._tg_auditar(k.pessoa, 'recusa', 'bot do Telegram', 'código cancelado: ' || coalesce(k.invalidado_motivo, ''));
    return jsonb_build_object('texto', 'Este código foi cancelado (' || coalesce(k.invalidado_motivo, 'sem motivo') || '). Gere outro na Mesa (Ligar o Telegram).', 'vinculou', false);
  end if;
  if k.expira_em <= now() then
    perform rt._tg_auditar(k.pessoa, 'recusa', 'bot do Telegram', 'código vencido');
    return jsonb_build_object('texto', 'Código vencido. Gere outro na Mesa (Ligar o Telegram); cada código vale ' || v_min || ' minutos.', 'vinculou', false);
  end if;
  select * into i from rt_chave.identidade where pseudonimo = k.pessoa for update;
  if i.pseudonimo is null or i.nome like 'eliminado em %' or not exists (select 1 from rt.pessoa where pseudonimo = k.pessoa) then
    return jsonb_build_object('texto', 'Este cadastro não está ativo no IMTS.OS. Fale com a Gestão (GE-07).', 'vinculou', false);
  end if;
  if i.telegram_id = p_from then
    update rt_chave.tg_codigo set usado_em = now() where id = k.id;
    return jsonb_build_object('texto', 'Este Telegram já estava ligado a você, ' || i.nome || '. Nada mudou.', 'vinculou', false, 'pessoa', i.pseudonimo);
  end if;
  if i.telegram_id is not null then
    perform rt._tg_auditar(k.pessoa, 'recusa', 'bot do Telegram', 'cadastro já ligado a outro Telegram');
    return jsonb_build_object('texto', 'Seu cadastro já está ligado a outro Telegram. Primeiro desligue na Mesa (Ligar o Telegram, Desligar) e depois gere um código novo.', 'vinculou', false);
  end if;
  if exists (select 1 from rt_chave.identidade where telegram_id = p_from and pseudonimo <> k.pessoa) then
    perform rt._tg_auditar(k.pessoa, 'recusa', 'bot do Telegram', 'este Telegram já é de outra pessoa da equipe');
    return jsonb_build_object('texto', 'Este Telegram já está ligado a outra pessoa da equipe. Quem usa este Telegram precisa desligá-lo na Mesa antes.', 'vinculou', false);
  end if;
  if exists (select 1 from ext.telegram where telegram_id = p_from and vinculado_em is not null) then
    perform rt._tg_auditar(k.pessoa, 'recusa', 'bot do Telegram', 'este Telegram está ligado ao portal de parceiro ou cliente');
    return jsonb_build_object('texto', 'Este Telegram está ligado ao portal de parceiro ou cliente. Envie /desligar antes de ligá-lo à equipe.', 'vinculou', false);
  end if;
  update rt_chave.identidade set telegram_id = p_from, consentimento_art33_em = k.consentimento_em where pseudonimo = k.pessoa;
  update rt_chave.tg_codigo set usado_em = now() where id = k.id;
  update rt_chave.tg_codigo set invalidado_em = now(), invalidado_motivo = 'outro código já ligou o Telegram'
   where pessoa = k.pessoa and id <> k.id and usado_em is null and invalidado_em is null;
  delete from rt.rota_chat where chat_ref = 'tg:' || p_chat and descricao = 'conversa privada com o bot';
  perform rt._tg_auditar(k.pessoa, 'vinculado', 'bot do Telegram', 'Telegram ligado por código da Mesa; consentimento do art. 33, VIII, aceito em ' || to_char(k.consentimento_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI'));
  return jsonb_build_object('texto', 'Pronto, ' || i.nome || '. Este Telegram está ligado ao IMTS.OS. Envie /quadro para ver suas tarefas ou /mesa para abrir a Mesa aqui.', 'vinculou', true, 'pessoa', i.pseudonimo);
end $$;

-- A recepção que já existe fica como rt._receber_update_base (sem cópia: o que 019 e 047 definiram continua valendo)
do $$
begin
  if to_regprocedure('rt._receber_update_base(jsonb, boolean)') is null then
    alter function rt.receber_update(jsonb, boolean) rename to _receber_update_base;
  end if;
end $$;

create or replace function rt.receber_update(p_update jsonb, p_simulado boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_msg jsonb := p_update->'message'; m text[]; v_res jsonb; v_fila bigint; v_chat text;
begin
  if v_msg is not null and p_update->'callback_query' is null then
    m := regexp_match(btrim(coalesce(v_msg->>'text', '')), '^/vincular(?:@\S+)?\s+([0-9A-Fa-f]{8})\s*$');
    if m is not null and exists (select 1 from rt_chave.tg_codigo where codigo_hash = encode(extensions.digest(upper(m[1]), 'sha256'), 'hex')) then
      if p_update ? 'update_id' then
        insert into rt.update_recebido (update_id) values ((p_update->>'update_id')::bigint) on conflict do nothing;
        if not found then return jsonb_build_object('ignorado', 'atualização repetida'); end if;
      end if;
      v_chat := v_msg->'chat'->>'id';
      v_res := rt._tg_vincular_equipe((v_msg->'from'->>'id')::bigint, v_chat, v_msg->'chat'->>'type', m[1], p_simulado);
      insert into rt.fila_envio (chat_ref, texto, simulado) values ('tg:' || v_chat, v_res->>'texto', p_simulado) returning id into v_fila;
      return jsonb_build_object('pessoa', null, 'vinculo_equipe', true, 'vinculou', coalesce((v_res->>'vinculou')::boolean, false), 'fila', v_fila, 'callback_id', null);
    end if;
  end if;
  v_res := rt._receber_update_base(p_update, p_simulado);
  -- quem ainda não tem vínculo: a resposta passa a citar o caminho da Mesa para a equipe
  if v_res->>'pessoa' is null and v_res ? 'fila' then
    update rt.fila_envio set texto = case
        when texto like 'Você ainda não está cadastrado no IMTS.OS.%' then
          'Você ainda não está cadastrado no IMTS.OS com este Telegram. Pessoa da equipe: na Mesa (web), abra Ligar o Telegram, gere o código e envie /vincular CÓDIGO aqui; sem acesso à Mesa, peça à Gestão (GE-07). Parceiro ou cliente: gere o código no portal e envie /vincular CÓDIGO.'
        when texto like 'Código inválido ou vencido.%' then
          'Código inválido ou vencido. Gere outro: pessoa da equipe na Mesa (Ligar o Telegram); parceiro ou cliente no portal (Telegram, gerar código).'
        else texto end
     where id = (v_res->>'fila')::bigint and estado = 'pendente';
  end if;
  return v_res;
end $$;

insert into adm.api_funcao (nome, quem, descricao) values
 ('rt.tg_vinculo', 'interno', 'Ligar o Telegram (Mesa): estado do vínculo e o termo'),
 ('rt.tg_codigo_gerar', 'interno', 'Ligar o Telegram (Mesa): gerar o código de uso único, com o aceite do termo'),
 ('rt.tg_desvincular', 'interno', 'Ligar o Telegram (Mesa): desligar o próprio Telegram')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;

-- Permissões -----------------------------------------------------------------------------------------------------------------
revoke all on function rt._tg_auditar(uuid, text, text, text, jsonb), rt.tg_vinculo(), rt.tg_codigo_gerar(boolean), rt.tg_desvincular(),
  rt._tg_vincular_equipe(bigint, text, text, text, boolean), rt.receber_update(jsonb, boolean), rt._receber_update_base(jsonb, boolean) from public, anon;
revoke all on function rt._tg_auditar(uuid, text, text, text, jsonb), rt._tg_vincular_equipe(bigint, text, text, text, boolean),
  rt.receber_update(jsonb, boolean), rt._receber_update_base(jsonb, boolean) from authenticated;
grant execute on function rt.tg_vinculo(), rt.tg_codigo_gerar(boolean), rt.tg_desvincular() to authenticated, service_role;
grant execute on function rt.receber_update(jsonb, boolean), rt._receber_update_base(jsonb, boolean) to service_role;

commit;
