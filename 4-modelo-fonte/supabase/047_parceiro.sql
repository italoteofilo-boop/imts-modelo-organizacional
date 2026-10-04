-- E19 · Experiência do parceiro (aprovado por Ítalo em 04/10/2026, "Prossiga").
-- 1. sala de negócio por oportunidade: o parceiro e a IMTS conversam no mesmo fio;
-- 2. carteira de comissões: prevista (negócio ganho, parcela futura), adquirida (o cliente pagou a parcela, GE-03),
--    a pagar (nota fiscal do parceiro aprovada), paga (GE-04). A regra vem do contrato de parceria; no protótipo é SIMULADA;
-- 3. prestação de contas: nota fiscal e relatório sobem pelo portal, entram no acervo (pasta 07 Parceiros) e a nota é
--    conferida pela máquina (CNPJ do parceiro, número único, valor igual às comissões escolhidas); pessoa aprova; outra paga;
-- 4. Telegram do parceiro: vínculo por código gerado no portal; comandos de consulta, oportunidade e sala.
begin;

alter table adm.historico drop constraint if exists historico_objeto_check;
alter table adm.historico add constraint historico_objeto_check
  check (objeto in ('parametro', 'conexao', 'agente', 'regra_externa', 'titulo_externo', 'tipo_documento', 'incidente', 'acervo', 'marca',
                    'contrato_parceria', 'comissao', 'prestacao', 'atendimento', 'reuniao'));

insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('parceiro.prazo_aprovacao_horas', 'global', 'Prazo para aprovar a nota fiscal do parceiro depois de conferida', 'inteiro', '48', '48', '{"min":4,"max":240}', false, '{}', 'E19, 04/10/2026'),
 ('parceiro.prazo_pagamento_dias', 'global', 'Prazo para pagar a comissão depois da nota aprovada', 'inteiro', '10', '10', '{"min":1,"max":60}', true, '{}', 'E19, 04/10/2026'),
 ('parceiro.codigo_telegram_minutos', 'global', 'Validade do código que liga o Telegram do parceiro ou do cliente ao portal', 'inteiro', '15', '15', '{"min":5,"max":60}', false, '{}', 'E19, 04/10/2026')
on conflict (chave) do nothing;

-- contrato de parceria: a regra da comissão (uma vigente por parceiro); toda mudança vai ao histórico
create table if not exists ext.contrato_parceria (
  id bigint generated always as identity primary key,
  contraparte uuid not null references ext.contraparte(id),
  percentual numeric(5,2) not null check (percentual > 0 and percentual <= 50),
  base text not null default 'recebido' check (base in ('recebido')),   -- comissão sobre o que o cliente pagou, parcela a parcela
  parcelas_max int not null default 12 check (parcelas_max between 1 and 60),
  vigente_de date not null,
  vigente_ate date,
  simulado boolean not null,
  fonte text not null,
  criado_em timestamptz not null default now()
);
create unique index if not exists contrato_parceria_vigente on ext.contrato_parceria (contraparte) where vigente_ate is null;
drop trigger if exists historico on ext.contrato_parceria;
create trigger historico after insert or update or delete on ext.contrato_parceria for each row execute function adm._historico_regra('contrato_parceria');

insert into ext.contrato_parceria (contraparte, percentual, parcelas_max, vigente_de, simulado, fonte)
select c.id, 10, 12, date '2026-10-04', true, 'regra SIMULADA do protótipo (10% sobre o recebido); substituir pela regra do contrato de parceria assinado'
  from ext.contraparte c where c.tipo = 'parceiro' and c.simulado
   and not exists (select 1 from ext.contrato_parceria x where x.contraparte = c.id and x.vigente_ate is null);

-- oportunidade: valor e parcelas quando ganha; quem decidiu
alter table ext.oportunidade add column if not exists valor numeric(14,2), add column if not exists parcelas int,
  add column if not exists decidido_por uuid, add column if not exists decidido_em timestamptz, add column if not exists motivo text;

create table if not exists ext.sala_mensagem (
  id bigint generated always as identity primary key,
  oportunidade bigint not null references ext.oportunidade(id),
  lado text not null check (lado in ('parceiro', 'imts', 'sistema')),
  autor_externo uuid,
  autor_interno uuid,
  texto text not null check (length(btrim(texto)) between 1 and 2000),
  origem text not null default 'portal' check (origem in ('portal', 'telegram', 'central', 'sistema')),
  em timestamptz not null default now()
);
create index if not exists sala_mensagem_op on ext.sala_mensagem (oportunidade, id);

create table if not exists ext.comissao (
  id bigint generated always as identity primary key,
  contraparte uuid not null references ext.contraparte(id),
  oportunidade bigint not null references ext.oportunidade(id),
  contrato bigint not null references ext.contrato_parceria(id),
  parcela int not null,
  competencia date not null,
  base numeric(14,2) not null,
  percentual numeric(5,2) not null,
  valor numeric(14,2) not null check (valor >= 0),
  situacao text not null default 'prevista' check (situacao in ('prevista', 'adquirida', 'a_pagar', 'paga', 'cancelada')),
  prestacao bigint,
  eventos jsonb not null default '[]',
  unique (oportunidade, parcela)
);
create index if not exists comissao_contraparte on ext.comissao (contraparte, situacao);

create table if not exists ext.prestacao (
  id bigint generated always as identity primary key,
  contraparte uuid not null references ext.contraparte(id),
  tipo text not null check (tipo in ('nf', 'relatorio')),
  arquivo bigint references acervo.arquivo(id),
  numero text,
  valor numeric(14,2),
  comissoes bigint[] not null default '{}',
  situacao text not null default 'enviada' check (situacao in ('enviada', 'conferida', 'divergente', 'aprovada', 'recusada', 'paga')),
  conferencia jsonb not null default '[]',
  decisoes jsonb not null default '[]',
  cartao bigint,
  enviado_por uuid,
  origem text not null default 'portal' check (origem in ('portal', 'telegram')),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
-- número da nota não se repete para o mesmo parceiro (as recusadas e divergentes não contam: o parceiro reenvia corrigida)
create unique index if not exists prestacao_nf_unica on ext.prestacao (contraparte, numero) where tipo = 'nf' and situacao not in ('recusada', 'divergente');
alter table ext.comissao drop constraint if exists comissao_prestacao_fk;
alter table ext.comissao add constraint comissao_prestacao_fk foreign key (prestacao) references ext.prestacao(id);

-- Telegram de quem é de fora: código de uso único, guardado só como hash
create table if not exists ext.telegram (
  auth_uid uuid primary key references ext.usuario(auth_uid),
  telegram_id bigint unique,
  chat_ref text,
  codigo_hash text,
  codigo_expira timestamptz,
  vinculado_em timestamptz,
  simulado boolean not null default false
);

alter table ext.contrato_parceria enable row level security; alter table ext.sala_mensagem enable row level security;
alter table ext.comissao enable row level security; alter table ext.prestacao enable row level security; alter table ext.telegram enable row level security;
drop policy if exists leitura on ext.contrato_parceria;
create policy leitura on ext.contrato_parceria for select to authenticated using ((contraparte = (ext.eu()).contraparte and (ext.eu()).perfil in ('gestor', 'financeiro')) or ext._le(contraparte));
drop policy if exists leitura on ext.sala_mensagem;
create policy leitura on ext.sala_mensagem for select to authenticated
  using (exists (select 1 from ext.oportunidade o where o.id = oportunidade and (o.contraparte = (ext.eu()).contraparte or ext._le(o.contraparte))));
drop policy if exists leitura on ext.comissao;
create policy leitura on ext.comissao for select to authenticated using ((contraparte = (ext.eu()).contraparte and (ext.eu()).perfil in ('gestor', 'financeiro')) or ext._le(contraparte));
drop policy if exists leitura on ext.prestacao;
create policy leitura on ext.prestacao for select to authenticated using ((contraparte = (ext.eu()).contraparte and (ext.eu()).perfil in ('gestor', 'financeiro')) or ext._le(contraparte));
drop policy if exists leitura on ext.telegram;
create policy leitura on ext.telegram for select to authenticated using (auth_uid = auth.uid());
grant select on ext.contrato_parceria, ext.sala_mensagem, ext.comissao, ext.prestacao, ext.telegram to authenticated;
grant all on ext.contrato_parceria, ext.sala_mensagem, ext.comissao, ext.prestacao, ext.telegram to service_role;

-- cartões que nascem de fora levam a empresa da contraparte (corrige os pedidos de fora, que nasciam sem empresa)
create or replace function ext._cartao_empresa() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.cartao is not null and new.cartao is distinct from old.cartao then
    update rt.cartao set empresa = (select empresa from ext.contraparte where id = new.contraparte) where id = new.cartao and empresa is null;
  end if;
  return new;
end $$;
drop trigger if exists cartao_empresa on ext.pedido;
create trigger cartao_empresa after update of cartao on ext.pedido for each row execute function ext._cartao_empresa();
update rt.cartao k set empresa = c.empresa from ext.pedido p join ext.contraparte c on c.id = p.contraparte where p.cartao = k.id and k.empresa is null;

create or replace function ext._cartao(p_raia text, p_motor smallint, p_titulo text, p_prazo timestamptz, p_empresa uuid) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v bigint;
begin
  v := rt.criar_avulsa(rt._pessoa(p_raia, p_motor), left(p_titulo, 200), p_prazo, null, 'externo', null);
  update rt.cartao set empresa = p_empresa where id = v;
  return v;
end $$;
create or replace function ext._fechar_cartao(p_cartao bigint) returns void language plpgsql security definer set search_path = '' as $$
declare c rt.cartao;
begin
  select * into c from rt.cartao where id = p_cartao;
  if c.id is not null and c.coluna not in ('feito', 'decidir') then perform rt.concluir_cartao(c.id, c.dono); end if;
end $$;

-- aviso no Telegram de quem é de fora, se ligado (nada sai se não estiver ligado)
create or replace function ext._avisar(p_contraparte uuid, p_texto text, p_perfis text[] default '{gestor,financeiro}') returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  insert into rt.fila_envio (chat_ref, texto, simulado)
  select t.chat_ref, left(p_texto, 3500), t.simulado from ext.telegram t join ext.usuario u on u.auth_uid = t.auth_uid
   where u.contraparte = p_contraparte and u.ativo and u.perfil = any (p_perfis) and t.vinculado_em is not null and t.chat_ref is not null;
  get diagnostics n = row_count;
  return n;
end $$;

-- quem é de fora e parceiro
create or replace function ext._parceiro(p_perfis text[] default null) returns ext.usuario language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  if (select tipo from ext.contraparte where id = u.contraparte) <> 'parceiro' then raise exception 'disponível só para parceiro'; end if;
  if p_perfis is not null and not (u.perfil = any (p_perfis)) then raise exception 'perfil % não faz isto (cabe a: %)', u.perfil, array_to_string(p_perfis, ', '); end if;
  return u;
end $$;

-- ---------- sala de negócio ----------
create or replace function ext.sala_enviar(p_oportunidade bigint, p_texto text, p_origem text default 'portal') returns bigint
language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._parceiro(); o ext.oportunidade; v bigint;
begin
  select * into o from ext.oportunidade where id = p_oportunidade;
  if o.id is null or o.contraparte <> u.contraparte then raise exception 'oportunidade não é desta organização'; end if;
  if coalesce(length(btrim(p_texto)), 0) = 0 then raise exception 'escreva a mensagem'; end if;
  insert into ext.sala_mensagem (oportunidade, lado, autor_externo, texto, origem) values (o.id, 'parceiro', u.auth_uid, btrim(p_texto), p_origem) returning id into v;
  update ext.pedido set atualizado_em = now() where id = o.pedido;
  return v;
end $$;

create or replace function ext.sala_responder(p_oportunidade bigint, p_texto text, p_como uuid default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); o ext.oportunidade; v_id bigint;
begin
  select * into o from ext.oportunidade where id = p_oportunidade;
  if o.id is null then raise exception 'oportunidade inexistente'; end if;
  if not rt.pode(v, (select empresa from ext.contraparte where id = o.contraparte), null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if coalesce(length(btrim(p_texto)), 0) = 0 then raise exception 'escreva a mensagem'; end if;
  insert into ext.sala_mensagem (oportunidade, lado, autor_interno, texto, origem) values (o.id, 'imts', v, btrim(p_texto), 'central') returning id into v_id;
  perform ext._avisar(o.contraparte, 'Nova mensagem na sala da oportunidade ' || o.id || ' (' || o.cliente_final || '): ' || left(btrim(p_texto), 500), '{gestor,financeiro,operacional,fiscal}');
  return v_id;
end $$;

-- ---------- negócio ganho ou perdido: gera a carteira prevista ----------
create or replace function ext.oportunidade_decidir(p_oportunidade bigint, p_situacao text, p_valor numeric default null, p_parcelas int default null,
  p_inicio date default null, p_motivo text default null, p_como uuid default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); o ext.oportunidade; k ext.contrato_parceria; v_emp uuid; i int; v_base numeric; v_resto numeric; n int := 0;
begin
  select * into o from ext.oportunidade where id = p_oportunidade for update;
  if o.id is null then raise exception 'oportunidade inexistente'; end if;
  v_emp := (select empresa from ext.contraparte where id = o.contraparte);
  if not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if o.situacao not in ('registrada', 'em_negociacao') then raise exception 'oportunidade % não muda mais', o.situacao; end if;
  if p_situacao not in ('em_negociacao', 'ganha', 'perdida') then raise exception 'situação inválida'; end if;
  if p_situacao = 'perdida' and coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'perda exige motivo'; end if;
  if p_situacao = 'ganha' then
    select * into k from ext.contrato_parceria where contraparte = o.contraparte and vigente_ate is null;
    if k.id is null then raise exception 'parceiro sem contrato de parceria vigente: não há regra de comissão'; end if;
    if coalesce(p_valor, 0) <= 0 then raise exception 'informe o valor do negócio'; end if;
    if coalesce(p_parcelas, 0) not between 1 and k.parcelas_max then raise exception 'parcelas entre 1 e %', k.parcelas_max; end if;
    if p_inicio is null then raise exception 'informe o mês da primeira parcela'; end if;
    v_base := trunc(p_valor / p_parcelas, 2); v_resto := p_valor - v_base * p_parcelas;
    for i in 1 .. p_parcelas loop
      insert into ext.comissao (contraparte, oportunidade, contrato, parcela, competencia, base, percentual, valor, eventos)
      values (o.contraparte, o.id, k.id, i, (date_trunc('month', p_inicio) + make_interval(months => i - 1))::date,
              v_base + case when i = p_parcelas then v_resto else 0 end, k.percentual,
              round((v_base + case when i = p_parcelas then v_resto else 0 end) * k.percentual / 100, 2),
              jsonb_build_array(jsonb_build_object('situacao', 'prevista', 'por', v, 'em', now())));
      n := n + 1;
    end loop;
  end if;
  update ext.oportunidade set situacao = p_situacao, valor = coalesce(p_valor, valor), parcelas = coalesce(p_parcelas, parcelas),
         decidido_por = v, decidido_em = now(), motivo = coalesce(nullif(btrim(p_motivo), ''), motivo) where id = o.id;
  insert into ext.sala_mensagem (oportunidade, lado, texto, origem) values (o.id, 'sistema',
    case p_situacao when 'ganha' then 'Negócio ganho: ' || to_char(p_valor, 'FM999G999G990D00') || ' em ' || p_parcelas || ' parcela(s). ' || n || ' comissão(ões) prevista(s) na sua carteira.'
                    when 'perdida' then 'Oportunidade perdida: ' || btrim(p_motivo)
                    else 'Oportunidade em negociação.' end, 'sistema');
  perform ext._avisar(o.contraparte, 'Oportunidade ' || o.id || ' (' || o.cliente_final || '): ' || replace(p_situacao, '_', ' ') || '.');
  return jsonb_build_object('situacao', p_situacao, 'comissoes', n);
end $$;

-- o cliente pagou a parcela (GE-03): a comissão daquela parcela passa a adquirida
create or replace function ext.comissao_adquirir(p_comissao bigint, p_como uuid default null) returns void language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); c ext.comissao;
begin
  select * into c from ext.comissao where id = p_comissao for update;
  if c.id is null then raise exception 'comissão inexistente'; end if;
  if not rt.pode(v, (select empresa from ext.contraparte where id = c.contraparte), null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if c.situacao <> 'prevista' then raise exception 'comissão % não passa a adquirida', c.situacao; end if;
  update ext.comissao set situacao = 'adquirida', eventos = eventos || jsonb_build_object('situacao', 'adquirida', 'por', v, 'em', now(), 'motivo', 'parcela recebida do cliente (GE-03)') where id = c.id;
  perform ext._avisar(c.contraparte, 'Comissão da parcela ' || c.parcela || ' (oportunidade ' || c.oportunidade || ') adquirida: ' || to_char(c.valor, 'FM999G999G990D00') || '. Já pode emitir a nota fiscal.');
end $$;

-- ---------- prestação de contas: nota fiscal e relatório ----------
create or replace function ext.prestacao_enviar(p_tipo text, p_nome text, p_hash text, p_mime text, p_tamanho bigint, p_texto text,
  p_comissoes bigint[] default '{}', p_drive_id text default null, p_origem text default 'portal') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._parceiro('{gestor,financeiro}'); c ext.contraparte; r jsonb; x jsonb; v_id bigint; chk jsonb := '[]'; v_num text; v_val numeric;
  v_soma numeric; v_ok boolean; v_sit text; v_card bigint; v_cnpjs text[]; v_n int;
begin
  select * into c from ext.contraparte where id = u.contraparte;
  if p_tipo not in ('nf', 'relatorio') then raise exception 'tipo de prestação inválido'; end if;
  if p_origem not in ('portal', 'telegram') then raise exception 'origem inválida'; end if;
  if coalesce(length(p_texto), 0) = 0 and p_tipo = 'nf' then raise exception 'a nota precisa de texto legível (PDF com texto ou XML)'; end if;
  r := acervo._registrar(c.empresa, p_nome, p_hash, p_mime, p_tamanho, p_texto, p_origem, p_drive_id, c.id, null, u.auth_uid);
  if r->>'situacao' = 'duplicado' then raise exception 'este arquivo já foi enviado (%)', r->>'nome'; end if;
  -- o que o parceiro manda fica na pasta dos parceiros, com o tipo da prestação
  update acervo.arquivo set pasta = '07', tipo = case p_tipo when 'nf' then 'nota-fiscal' else 'relatorio-prestacao' end,
         situacao = case when situacao = 'triagem' then 'entrada' else situacao end, motivo = null
   where id = (r->>'arquivo')::bigint;
  -- já subiu direto na pasta 07 do Drive: está organizado; a versão anterior da mesma nota fica substituída
  if p_drive_id is not null then
    update acervo.arquivo set situacao = 'organizado', atualizado_em = now() where id = (r->>'arquivo')::bigint;
    update acervo.arquivo set situacao = 'substituido', atualizado_em = now(), motivo = 'substituído pela versão ' || (r->>'arquivo')
     where id = (r->>'versao_de')::bigint and situacao = 'organizado';
  end if;
  x := r->'extraido';
  v_num := nullif(ltrim(x->'numero'->>'valor', '0'), '');
  v_val := (x->'valor_total'->>'valor')::numeric;
  if p_tipo = 'nf' then
    -- 1. comissões: deste parceiro, adquiridas e livres
    select count(*), sum(valor) into v_n, v_soma from ext.comissao where id = any (p_comissoes) and contraparte = c.id and situacao = 'adquirida' and prestacao is null;
    v_ok := cardinality(p_comissoes) > 0 and v_n = cardinality(p_comissoes);
    chk := chk || jsonb_build_object('regra', 'comissoes', 'ok', v_ok, 'detalhe',
      case when cardinality(p_comissoes) = 0 then 'escolha as comissões adquiridas que esta nota cobra'
           when v_ok then v_n || ' comissão(ões) adquirida(s), somando ' || to_char(v_soma, 'FM999G999G990D00')
           else 'há comissão que não é sua, não está adquirida ou já está em outra nota' end);
    -- 2. CNPJ do parceiro na nota
    select array_agg(distinct regexp_replace(m[1], '\D', '', 'g')) into v_cnpjs from regexp_matches(p_texto, '(\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2})', 'g') m;
    chk := chk || jsonb_build_object('regra', 'cnpj', 'ok', c.documento is not null and regexp_replace(c.documento, '\D', '', 'g') = any (coalesce(v_cnpjs, '{}')),
      'detalhe', case when c.documento is null then 'CNPJ do parceiro não cadastrado na IMTS: a conferência fica pendente até o cadastro'
                      when regexp_replace(c.documento, '\D', '', 'g') = any (coalesce(v_cnpjs, '{}')) then 'CNPJ do emitente confere com o cadastro'
                      else 'o CNPJ do cadastro do parceiro não aparece na nota' end);
    -- 3. número da nota, uma vez só
    chk := chk || jsonb_build_object('regra', 'numero', 'ok', v_num is not null and not exists (select 1 from ext.prestacao where contraparte = c.id and tipo = 'nf' and numero = v_num and situacao not in ('recusada', 'divergente')),
      'detalhe', case when v_num is null then 'número da nota não encontrado no texto'
                      when exists (select 1 from ext.prestacao where contraparte = c.id and tipo = 'nf' and numero = v_num and situacao not in ('recusada', 'divergente')) then 'a nota ' || v_num || ' já foi apresentada'
                      else 'nota ' || v_num end);
    -- 4. valor igual à soma das comissões
    chk := chk || jsonb_build_object('regra', 'valor', 'ok', v_val is not null and v_soma is not null and v_val = v_soma,
      'detalhe', case when v_val is null then 'valor total não encontrado no texto'
                      when v_soma is null then 'sem comissões válidas para comparar'
                      when v_val = v_soma then 'valor ' || to_char(v_val, 'FM999G999G990D00') || ' igual às comissões'
                      else 'valor da nota ' || to_char(v_val, 'FM999G999G990D00') || ' diferente das comissões (' || to_char(v_soma, 'FM999G999G990D00') || ')' end);
    v_sit := case when not exists (select 1 from jsonb_array_elements(chk) e where not (e->>'ok')::boolean) then 'conferida' else 'divergente' end;
  else
    v_sit := 'enviada';
  end if;
  insert into ext.prestacao (contraparte, tipo, arquivo, numero, valor, comissoes, situacao, conferencia, enviado_por, origem)
  values (c.id, p_tipo, (r->>'arquivo')::bigint, v_num, v_val, coalesce(p_comissoes, '{}'), v_sit, chk, u.auth_uid, p_origem) returning id into v_id;
  if v_sit = 'conferida' then update ext.comissao set prestacao = v_id where id = any (p_comissoes); end if;
  if v_sit in ('conferida', 'enviada') then
    v_card := ext._cartao('Gestão · pessoa', 8::smallint, case p_tipo when 'nf' then 'Aprovar nota fiscal do parceiro: NF ' || v_num || ' · ' || to_char(v_val, 'FM999G999G990D00') else 'Analisar relatório de prestação de contas' end || ' · ' || c.nome,
                      now() + make_interval(hours => (adm.valor('parceiro.prazo_aprovacao_horas', '48') #>> '{}')::int), c.empresa);
    update ext.prestacao set cartao = v_card where id = v_id;
  end if;
  return jsonb_build_object('prestacao', v_id, 'situacao', v_sit, 'conferencia', chk, 'arquivo', (r->>'arquivo')::bigint, 'nome', r->>'nome', 'pasta', '07');
end $$;

create or replace function ext.prestacao_decidir(p_prestacao bigint, p_decisao text, p_motivo text default null, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); p ext.prestacao; v_emp uuid; v_card bigint;
begin
  select * into p from ext.prestacao where id = p_prestacao for update;
  if p.id is null then raise exception 'prestação inexistente'; end if;
  v_emp := (select empresa from ext.contraparte where id = p.contraparte);
  if not rt.pode(v, v_emp, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if p_decisao not in ('aprovado', 'recusado') then raise exception 'decisão inválida'; end if;
  if p.situacao not in ('conferida', 'enviada', 'divergente') then raise exception 'prestação % não recebe decisão', p.situacao; end if;
  if p_decisao = 'aprovado' and p.situacao = 'divergente' then raise exception 'nota com divergência na conferência não se aprova: recuse com motivo e o parceiro reenvia'; end if;
  if p_decisao = 'recusado' then
    if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'recusa exige motivo'; end if;
    update ext.comissao set prestacao = null where prestacao = p.id;
    update ext.prestacao set situacao = 'recusada', atualizado_em = now(), decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'recusado', 'motivo', p_motivo, 'em', now()) where id = p.id;
    perform ext._fechar_cartao(p.cartao);
    perform ext._avisar(p.contraparte, case p.tipo when 'nf' then 'Nota fiscal ' || coalesce(p.numero, '') else 'Relatório' end || ' recusado: ' || p_motivo);
    return jsonb_build_object('situacao', 'recusada');
  end if;
  update ext.prestacao set situacao = 'aprovada', atualizado_em = now(), decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'aprovado', 'motivo', p_motivo, 'em', now()) where id = p.id;
  perform ext._fechar_cartao(p.cartao);
  if p.tipo = 'nf' then
    update ext.comissao set situacao = 'a_pagar', eventos = eventos || jsonb_build_object('situacao', 'a_pagar', 'por', v, 'em', now(), 'motivo', 'nota ' || p.numero || ' aprovada') where prestacao = p.id;
    v_card := ext._cartao('Gestão · pessoa', 8::smallint, 'Pagar comissão ao parceiro (GE-04): NF ' || p.numero || ' · ' || to_char(p.valor, 'FM999G999G990D00'),
                          now() + make_interval(days => (adm.valor('parceiro.prazo_pagamento_dias', '10') #>> '{}')::int), v_emp);
    update ext.prestacao set cartao = v_card where id = p.id;
  end if;
  perform ext._avisar(p.contraparte, case p.tipo when 'nf' then 'Nota fiscal ' || p.numero || ' aprovada; pagamento programado.' else 'Relatório de prestação de contas aprovado.' end);
  return jsonb_build_object('situacao', 'aprovada');
end $$;

-- pagar: quem aprovou a nota não paga (duas mãos no dinheiro)
create or replace function ext.prestacao_pagar(p_prestacao bigint, p_comprovante text, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); p ext.prestacao;
begin
  select * into p from ext.prestacao where id = p_prestacao for update;
  if p.id is null then raise exception 'prestação inexistente'; end if;
  if not rt.pode(v, (select empresa from ext.contraparte where id = p.contraparte), null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if p.tipo <> 'nf' or p.situacao <> 'aprovada' then raise exception 'só nota aprovada é paga'; end if;
  if exists (select 1 from jsonb_array_elements(p.decisoes) d where d->>'decisao' = 'aprovado' and (d->>'por')::uuid = v) then
    raise exception 'quem aprovou a nota não registra o pagamento'; end if;
  if coalesce(length(btrim(p_comprovante)), 0) = 0 then raise exception 'informe a referência do comprovante de pagamento'; end if;
  update ext.comissao set situacao = 'paga', eventos = eventos || jsonb_build_object('situacao', 'paga', 'por', v, 'em', now(), 'comprovante', p_comprovante) where prestacao = p.id;
  update ext.prestacao set situacao = 'paga', atualizado_em = now(), decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'pago', 'comprovante', p_comprovante, 'em', now()) where id = p.id;
  perform ext._fechar_cartao(p.cartao);
  perform ext._avisar(p.contraparte, 'Pagamento da nota ' || p.numero || ' registrado: ' || to_char(p.valor, 'FM999G999G990D00') || '.');
  return jsonb_build_object('situacao', 'paga');
end $$;

-- ---------- o que o parceiro vê ----------
create or replace function ext.portal_parceiro() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu(); c ext.contraparte; fin boolean;
begin
  select * into c from ext.contraparte where id = u.contraparte;
  if c.tipo <> 'parceiro' then return null; end if;
  fin := u.perfil in ('gestor', 'financeiro');
  return jsonb_build_object(
    'contrato', case when fin then (select jsonb_build_object('percentual', percentual, 'base', base, 'parcelas_max', parcelas_max, 'vigente_de', vigente_de, 'simulado', simulado, 'fonte', fonte)
                  from ext.contrato_parceria where contraparte = c.id and vigente_ate is null) end,
    'cnpj_cadastrado', c.documento is not null,
    'carteira', case when fin then jsonb_build_object(
        'totais', (select coalesce(jsonb_object_agg(situacao, jsonb_build_object('quantidade', n, 'valor', s)), '{}') from (select situacao, count(*) n, sum(valor) s from ext.comissao where contraparte = c.id group by 1) z),
        'itens', (select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'oportunidade', k.oportunidade, 'cliente_final', o.cliente_final, 'parcela', k.parcela, 'parcelas', o.parcelas,
                   'competencia', k.competencia, 'base', k.base, 'percentual', k.percentual, 'valor', k.valor, 'situacao', k.situacao, 'prestacao', k.prestacao) order by k.competencia, k.id), '[]')
                   from ext.comissao k join ext.oportunidade o on o.id = k.oportunidade where k.contraparte = c.id and k.situacao <> 'cancelada')) end,
    'prestacoes', case when fin then (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'tipo', p.tipo, 'numero', p.numero, 'valor', p.valor, 'situacao', p.situacao, 'conferencia', p.conferencia,
                   'motivo', (select d->>'motivo' from jsonb_array_elements(p.decisoes) d where d->>'decisao' = 'recusado' limit 1), 'arquivo', a.nome, 'em', p.criado_em) order by p.id desc), '[]')
                   from ext.prestacao p left join acervo.arquivo a on a.id = p.arquivo where p.contraparte = c.id) end,
    'salas', (select coalesce(jsonb_agg(jsonb_build_object('oportunidade', o.id, 'cliente_final', o.cliente_final, 'situacao', o.situacao, 'exclusiva_ate', o.exclusiva_ate, 'valor', o.valor,
                   'mensagens', (select coalesce(jsonb_agg(jsonb_build_object('lado', m.lado, 'texto', m.texto, 'em', m.em, 'origem', m.origem) order by m.id), '[]')
                                  from (select * from ext.sala_mensagem where oportunidade = o.id order by id desc limit 50) m)) order by o.id desc), '[]')
                   from ext.oportunidade o where o.contraparte = c.id),
    'telegram', (select jsonb_build_object('vinculado', vinculado_em is not null, 'desde', vinculado_em) from ext.telegram where auth_uid = u.auth_uid),
    'pode', jsonb_build_object('carteira', fin, 'prestacao', fin, 'sala', true));
end $$;

-- código para ligar o Telegram (vale para parceiro e cliente); devolvido uma vez, guardado só o hash
create or replace function ext.telegram_codigo() returns jsonb language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu(); v text; v_min int := (adm.valor('parceiro.codigo_telegram_minutos', '15') #>> '{}')::int;
begin
  v := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 8));
  insert into ext.telegram (auth_uid, codigo_hash, codigo_expira, simulado) values (u.auth_uid, encode(extensions.digest(v, 'sha256'), 'hex'), now() + make_interval(mins => v_min), u.simulado)
  on conflict (auth_uid) do update set codigo_hash = excluded.codigo_hash, codigo_expira = excluded.codigo_expira;
  return jsonb_build_object('codigo', v, 'expira', now() + make_interval(mins => v_min), 'instrucao', 'Abra o bot da IMTS no Telegram e envie: /vincular ' || v);
end $$;

create or replace function ext.telegram_desligar() returns void language plpgsql security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  update ext.telegram set telegram_id = null, chat_ref = null, vinculado_em = null, codigo_hash = null, codigo_expira = null where auth_uid = u.auth_uid;
end $$;

-- conversa de quem é de fora no bot (chamada por rt.receber_update quando o remetente não é pessoa de dentro)
create or replace function ext._telegram(p_from bigint, p_chat text, p_tipo_chat text, p_texto text, p_simulado boolean, p_documento boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t ext.telegram; u ext.usuario; c ext.contraparte; m text[]; r jsonb; v_txt text; v_id bigint; k record; parc boolean;
begin
  p_texto := btrim(coalesce(p_texto, ''));
  m := regexp_match(p_texto, '^/vincular(?:@\S+)?\s+([0-9A-Fa-f]{8})\s*$');
  if m is not null then
    if p_tipo_chat <> 'private' then return jsonb_build_object('texto', 'Faça o vínculo numa conversa privada com o bot, não em grupo.'); end if;
    select * into t from ext.telegram where codigo_hash = encode(extensions.digest(upper(m[1]), 'sha256'), 'hex') and codigo_expira > now();
    if t.auth_uid is null then return jsonb_build_object('texto', 'Código inválido ou vencido. Gere outro no portal (Telegram, gerar código).'); end if;
    if t.simulado <> p_simulado then raise exception 'mistura de simulado e real no vínculo do Telegram'; end if;
    update ext.telegram set telegram_id = null, chat_ref = null, vinculado_em = null where telegram_id = p_from and auth_uid <> t.auth_uid;
    update ext.telegram set telegram_id = p_from, chat_ref = 'tg:' || p_chat, vinculado_em = now(), codigo_hash = null, codigo_expira = null where auth_uid = t.auth_uid;
    select * into u from ext.usuario where auth_uid = t.auth_uid;
    return jsonb_build_object('texto', 'Pronto, ' || u.nome || '. Este Telegram está ligado ao portal. Envie /ajuda para ver o que dá para fazer por aqui.', 'vinculou', true);
  end if;
  select * into t from ext.telegram where telegram_id = p_from and vinculado_em is not null;
  if t.auth_uid is null then return null; end if;
  if t.simulado <> p_simulado then raise exception 'mistura de simulado e real: a atualização e o usuário de fora não são do mesmo ambiente'; end if;
  select * into u from ext.usuario where auth_uid = t.auth_uid and ativo;
  select * into c from ext.contraparte where id = u.contraparte and ativa;
  if u.auth_uid is null or c.id is null then return jsonb_build_object('texto', 'Seu acesso ao portal está inativo. Fale com a IMTS.'); end if;
  if p_tipo_chat <> 'private' then return jsonb_build_object('texto', 'Por segurança, o atendimento de fora é só em conversa privada com o bot.'); end if;
  parc := c.tipo = 'parceiro';
  perform set_config('request.jwt.claim.sub', u.auth_uid::text, true);
  begin
    if p_documento then
      v_txt := 'Nota fiscal, relatório e anexos vão pelo portal: lá o arquivo é lido, conferido e guardado no acervo. Pelo Telegram, só mensagens.';
    elsif p_texto ~* '^/(start|ajuda|help)' or p_texto = '' then
      v_txt := 'Comandos:' || case when parc then E'\n/carteira · suas comissões por situação\n/oportunidades · suas oportunidades e a exclusividade\n/oportunidade Cliente | Assunto | Detalhe · registra uma oportunidade\n/sala N texto · escreve na sala da oportunidade N\n/prestacoes · notas e relatórios enviados' else '' end
               || E'\n/pedidos · seus pedidos e a situação\n/desligar · desfaz o vínculo deste Telegram' || E'\nNota fiscal, relatório e anexos: pelo portal.';
    elsif p_texto ~* '^/desligar' then
      update ext.telegram set telegram_id = null, chat_ref = null, vinculado_em = null where auth_uid = u.auth_uid;
      v_txt := 'Vínculo desfeito. Para ligar de novo, gere um código no portal.';
    elsif p_texto ~* '^/pedidos' then
      select string_agg('#' || id || ' ' || tipo || ': ' || left(assunto, 60) || ' · ' || replace(situacao, '_', ' '), E'\n' order by id desc) into v_txt
        from (select * from ext.pedido where contraparte = c.id and (u.perfil = 'gestor' or usuario = u.auth_uid) order by id desc limit 10) z;
      v_txt := coalesce(v_txt, 'Nenhum pedido.');
    elsif parc and p_texto ~* '^/carteira' then
      if u.perfil not in ('gestor', 'financeiro') then v_txt := 'A carteira é do gestor e do financeiro do parceiro.';
      else
        select string_agg(replace(situacao, '_', ' ') || ': ' || n || ' · ' || to_char(s, 'FM999G999G990D00'), E'\n' order by ordem) into v_txt
          from (select situacao, count(*) n, sum(valor) s, array_position(array['prevista','adquirida','a_pagar','paga'], situacao) ordem from ext.comissao where contraparte = c.id and situacao <> 'cancelada' group by 1) z;
        v_txt := coalesce('Comissões' || E'\n' || v_txt, 'Nenhuma comissão ainda.');
      end if;
    elsif parc and p_texto ~* '^/oportunidades' then
      select string_agg(id || ' · ' || cliente_final || ' · ' || replace(situacao, '_', ' ') || case when situacao in ('registrada', 'em_negociacao') then ' · exclusiva até ' || to_char(exclusiva_ate, 'DD/MM/YYYY') else '' end, E'\n' order by id desc) into v_txt
        from (select * from ext.oportunidade where contraparte = c.id order by id desc limit 15) z;
      v_txt := coalesce(v_txt, 'Nenhuma oportunidade.');
    elsif parc and p_texto ~* '^/oportunidade\s' then
      m := regexp_match(p_texto, '^/oportunidade\s+([^|]+)\|([^|]+)(?:\|(.+))?$');
      if m is null then v_txt := 'Formato: /oportunidade Cliente | Assunto | Detalhe';
      else
        v_id := ext.pedir('oportunidade', btrim(m[2]), coalesce(nullif(btrim(m[3]), ''), btrim(m[2])), null, btrim(m[1]));
        v_txt := 'Oportunidade registrada (pedido ' || v_id || '), exclusiva até ' || (select to_char(exclusiva_ate, 'DD/MM/YYYY') from ext.oportunidade where pedido = v_id) || '.';
      end if;
    elsif parc and p_texto ~* '^/sala\s' then
      m := regexp_match(p_texto, '^/sala\s+(\d+)\s+(.+)$');
      if m is null then v_txt := 'Formato: /sala N texto';
      else perform ext.sala_enviar(m[1]::bigint, m[2], 'telegram'); v_txt := 'Mensagem enviada à sala da oportunidade ' || m[1] || '.'; end if;
    elsif parc and p_texto ~* '^/prestacoes' then
      if u.perfil not in ('gestor', 'financeiro') then v_txt := 'A prestação de contas é do gestor e do financeiro do parceiro.';
      else
        select string_agg(case tipo when 'nf' then 'NF ' || coalesce(numero, '?') || ' · ' || coalesce(to_char(valor, 'FM999G999G990D00'), '') else 'Relatório' end || ' · ' || situacao, E'\n' order by id desc) into v_txt
          from (select * from ext.prestacao where contraparte = c.id order by id desc limit 10) z;
        v_txt := coalesce(v_txt, 'Nada enviado ainda.');
      end if;
    else
      v_txt := 'Não entendi. Envie /ajuda.';
    end if;
  exception when others then
    v_txt := 'Não deu: ' || sqlerrm;
  end;
  perform set_config('request.jwt.claim.sub', '', true);
  return jsonb_build_object('texto', v_txt, 'externo', u.auth_uid);
end $$;

-- o bot passa a reconhecer quem é de fora antes de responder "não cadastrado"
create or replace function rt.receber_update(p_update jsonb, p_simulado boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $function$
declare
  v_msg jsonb; v_cb jsonb; v_from bigint; v_chat text; v_tipo text; v_texto text; v_msgid text; v_pessoa uuid; v_sim boolean; v_motor smallint;
  v_horas int; v_res jsonb; v_fila bigint; v_in bigint; v_circ smallint;
begin
  if p_update ? 'update_id' then
    insert into rt.update_recebido (update_id) values ((p_update->>'update_id')::bigint) on conflict do nothing;
    if not found then return jsonb_build_object('ignorado', 'atualização repetida'); end if;
  end if;
  v_msg := p_update->'message'; v_cb := p_update->'callback_query';
  if v_cb is not null then
    v_from := (v_cb->'from'->>'id')::bigint; v_chat := v_cb->'message'->'chat'->>'id'; v_tipo := v_cb->'message'->'chat'->>'type';
    v_texto := v_cb->>'data'; v_msgid := v_cb->'message'->>'message_id';
    v_texto := case when v_texto ~ '^[a-z]:' then split_part(v_texto, ':', 1) || ': ' || substr(v_texto, 3) else v_texto end;
  elsif v_msg is not null then
    v_from := (v_msg->'from'->>'id')::bigint; v_chat := v_msg->'chat'->>'id'; v_tipo := v_msg->'chat'->>'type';
    v_texto := coalesce(v_msg->>'text', v_msg->>'caption'); v_msgid := v_msg->>'message_id';
  else
    return jsonb_build_object('ignorado', 'tipo de atualização não tratado');
  end if;

  select i.pseudonimo, i.simulado into v_pessoa, v_sim from rt_chave.identidade i where i.telegram_id = v_from and i.nome not like 'eliminado em %';
  if v_pessoa is null or not exists (select 1 from rt.pessoa where pseudonimo = v_pessoa) then
    -- parceiro ou cliente com Telegram ligado ao portal (E19); a conversa de fora não é gravada, só respondida
    v_res := ext._telegram(v_from, v_chat, v_tipo, v_texto, p_simulado, v_msg is not null and (v_msg ? 'document' or v_msg ? 'photo'));
    insert into rt.fila_envio (chat_ref, texto, simulado)
    values ('tg:' || v_chat, coalesce(v_res->>'texto', 'Você ainda não está cadastrado no IMTS.OS. Pessoa da equipe: peça o seu acesso à Gestão (GE-07). Parceiro ou cliente: gere o código no portal e envie /vincular CÓDIGO.'), p_simulado)
      returning id into v_fila;
    return jsonb_build_object('pessoa', null, 'externo', v_res is not null, 'fila', v_fila, 'callback_id', v_cb->>'id');
  end if;
  if p_simulado <> v_sim then raise exception 'mistura de simulado e real: a atualização e a pessoa não são do mesmo ambiente'; end if;
  select circulo into v_circ from rt.pessoa where pseudonimo = v_pessoa;

  -- rota: chat privado vai ao motor do círculo da pessoa (sem círculo: o motor piloto, 1); grupo precisa estar cadastrado
  select motor into v_motor from rt.rota_chat where chat_ref = 'tg:' || v_chat;
  if v_motor is null then
    if v_tipo <> 'private' then
      insert into rt.fila_envio (chat_ref, texto, simulado) values ('tg:' || v_chat, 'Este grupo ainda não está ligado a um motor. Peça à Integração.', p_simulado) returning id into v_fila;
      return jsonb_build_object('pessoa', v_pessoa, 'fila', v_fila, 'callback_id', v_cb->>'id');
    end if;
    v_motor := coalesce(v_circ, 1);
    insert into rt.rota_chat (chat_ref, motor, descricao) values ('tg:' || v_chat, v_motor, 'conversa privada com o bot');
  end if;

  -- grava a entrada antes de tudo, com autodestruição pela configuração do motor (menos de 48 horas)
  select coalesce((valor #>> '{}')::int, 24) into v_horas from rt.config where motor = v_motor and chave = 'autodestruicao_horas';
  v_res := rt.interpretar(v_pessoa, case when v_cb is not null then v_texto else coalesce(v_texto, '') end);
  if v_msg is not null and v_msg ? 'voice' then
    v_res := jsonb_build_object('texto', 'Recebi o áudio. A transcrição entra quando o modelo de voz for ligado; por enquanto, escreva o pedido.');
  end if;
  v_in := rt.receber_mensagem('tg:' || v_chat, v_msgid, v_pessoa,
                              case when coalesce((v_res->>'segredo')::boolean, false) then '(apagada: possível segredo)'
                                   when v_cb is not null then 'botão: ' || coalesce(v_cb->>'data', '') else coalesce(v_texto, '(sem texto)') end,
                              p_simulado, coalesce(v_horas, 24));
  if coalesce((v_res->>'segredo')::boolean, false) then update rt.mensagem set apagar_ate = now() where id = v_in; end if;

  insert into rt.fila_envio (chat_ref, texto, botoes, pessoa, motor, simulado)
       values ('tg:' || v_chat, v_res->>'texto', v_res->'botoes', v_pessoa, v_motor, p_simulado) returning id into v_fila;
  return jsonb_build_object('pessoa', v_pessoa, 'motor', v_motor, 'mensagem', v_in, 'fila', v_fila, 'resposta', v_res, 'callback_id', v_cb->>'id');
end $function$;

-- ---------- o que a IMTS vê dos parceiros (Central) ----------
create or replace function ext.painel_parceiros(p_empresa uuid, p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then if not rt.chamada_servico() then raise exception 'sem identidade'; end if; v := p_como; end if;
  if v is null or not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso de leitura nesta empresa'; end if;
  return jsonb_build_object(
    'parceiros', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'nome', c.nome, 'cnpj', c.documento, 'simulado', c.simulado,
        'contrato', (select jsonb_build_object('id', k.id, 'percentual', k.percentual, 'parcelas_max', k.parcelas_max, 'simulado', k.simulado, 'fonte', k.fonte) from ext.contrato_parceria k where k.contraparte = c.id and k.vigente_ate is null),
        'telegram', (select count(*) from ext.telegram t join ext.usuario u on u.auth_uid = t.auth_uid where u.contraparte = c.id and t.vinculado_em is not null)) order by c.nome), '[]')
        from ext.contraparte c where c.empresa = p_empresa and c.tipo = 'parceiro'),
    'oportunidades', (select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'parceiro', c.nome, 'cliente_final', o.cliente_final, 'assunto', p.assunto, 'situacao', o.situacao,
        'exclusiva_ate', o.exclusiva_ate, 'valor', o.valor, 'parcelas', o.parcelas, 'motivo', o.motivo,
        'mensagens', (select coalesce(jsonb_agg(jsonb_build_object('lado', m.lado, 'texto', m.texto, 'em', m.em, 'origem', m.origem) order by m.id), '[]') from (select * from ext.sala_mensagem where oportunidade = o.id order by id desc limit 50) m),
        'ultima_do_parceiro', (select max(em) from ext.sala_mensagem where oportunidade = o.id and lado = 'parceiro'),
        'ultima_da_imts', (select max(em) from ext.sala_mensagem where oportunidade = o.id and lado = 'imts')) order by o.id desc), '[]')
        from ext.oportunidade o join ext.contraparte c on c.id = o.contraparte join ext.pedido p on p.id = o.pedido where c.empresa = p_empresa),
    'comissoes', (select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'parceiro', c.nome, 'oportunidade', k.oportunidade, 'cliente_final', o.cliente_final, 'parcela', k.parcela,
        'competencia', k.competencia, 'valor', k.valor, 'situacao', k.situacao, 'prestacao', k.prestacao) order by k.competencia, k.id), '[]')
        from ext.comissao k join ext.contraparte c on c.id = k.contraparte join ext.oportunidade o on o.id = k.oportunidade where c.empresa = p_empresa and k.situacao <> 'cancelada'),
    'prestacoes', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'parceiro', c.nome, 'tipo', x.tipo, 'numero', x.numero, 'valor', x.valor, 'situacao', x.situacao,
        'conferencia', x.conferencia, 'decisoes', x.decisoes, 'arquivo', a.nome, 'drive_id', a.drive_id, 'comissoes', x.comissoes, 'em', x.criado_em) order by x.id desc), '[]')
        from ext.prestacao x join ext.contraparte c on c.id = x.contraparte left join acervo.arquivo a on a.id = x.arquivo where c.empresa = p_empresa));
end $$;

-- cadastro do CNPJ do parceiro (conferido pelo dígito; vai para o histórico pelo acervo)
create or replace function ext.contraparte_documento(p_contraparte uuid, p_cnpj text, p_como uuid default null) returns text language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); c ext.contraparte; d text := regexp_replace(coalesce(p_cnpj, ''), '\D', '', 'g');
begin
  select * into c from ext.contraparte where id = p_contraparte;
  if c.id is null then raise exception 'contraparte inexistente'; end if;
  if not rt.pode(v, c.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if not acervo._cnpj_valido(d) then raise exception 'CNPJ inválido (dígito verificador)'; end if;
  update ext.contraparte set documento = acervo._cnpj_formatar(d) where id = c.id;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('acervo', 'contraparte ' || c.id, jsonb_build_object('documento', c.documento), jsonb_build_object('documento', acervo._cnpj_formatar(d)), v, 'aplicativo', 'CNPJ da contraparte');
  return acervo._cnpj_formatar(d);
end $$;

-- onde o arquivo de quem é de fora mora no Drive: pasta da empresa e subpasta 07 (parceiros) ou 08 (clientes).
-- Em produção quem faz isto é a função do servidor; no protótipo, a página pelo conector do Drive, só pelo serviço.
create or replace function ext.pasta_externa_como(p_usuario uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare u ext.usuario; c ext.contraparte; v_cod text;
begin
  perform ext._como(p_usuario); u := ext._exigir_eu();
  select * into c from ext.contraparte where id = u.contraparte;
  v_cod := case c.tipo when 'parceiro' then '07' else '08' end;
  return jsonb_build_object('empresa', (select nome from org.empresa where id = c.empresa), 'codigo', v_cod, 'nome_pasta', (select nome from acervo.pasta where codigo = v_cod),
    'raiz', (select drive_id from acervo.pasta_drive where empresa = c.empresa and pasta = 'raiz'),
    'pasta', (select drive_id from acervo.pasta_drive where empresa = c.empresa and pasta = v_cod));
end $$;
create or replace function ext.pasta_externa_registrar_como(p_usuario uuid, p_pasta text, p_drive_id text) returns void language plpgsql security definer set search_path = '' as $$
declare u ext.usuario; c ext.contraparte;
begin
  perform ext._como(p_usuario); u := ext._exigir_eu();
  select * into c from ext.contraparte where id = u.contraparte;
  if p_pasta not in ('raiz', case c.tipo when 'parceiro' then '07' else '08' end) then raise exception 'pasta não permitida para quem é de fora'; end if;
  if coalesce(p_drive_id, '') !~ '^[A-Za-z0-9_-]{10,}$' then raise exception 'identificador de pasta inválido'; end if;
  insert into acervo.pasta_drive (empresa, pasta, drive_id) values (c.empresa, p_pasta, p_drive_id) on conflict (empresa, pasta) do nothing;
end $$;

-- protótipo: as páginas atuam como usuário externo simulado (só o serviço)
create or replace function ext.portal_parceiro_como(p_usuario uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.portal_parceiro(); end $$;
create or replace function ext.sala_enviar_como(p_usuario uuid, p_oportunidade bigint, p_texto text) returns bigint language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.sala_enviar(p_oportunidade, p_texto, 'portal'); end $$;
create or replace function ext.prestacao_enviar_como(p_usuario uuid, p_tipo text, p_nome text, p_hash text, p_mime text, p_tamanho bigint, p_texto text,
  p_comissoes bigint[] default '{}', p_drive_id text default null) returns jsonb language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.prestacao_enviar(p_tipo, p_nome, p_hash, p_mime, p_tamanho, p_texto, p_comissoes, p_drive_id, 'portal'); end $$;
create or replace function ext.telegram_codigo_como(p_usuario uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); return ext.telegram_codigo(); end $$;
create or replace function ext.telegram_desligar_como(p_usuario uuid) returns void language plpgsql security definer set search_path = '' as $$
begin perform ext._como(p_usuario); perform ext.telegram_desligar(); end $$;

revoke all on function ext._cartao_empresa(), ext._cartao(text, smallint, text, timestamptz, uuid), ext._fechar_cartao(bigint), ext._avisar(uuid, text, text[]), ext._parceiro(text[]),
  ext._telegram(bigint, text, text, text, boolean, boolean), ext.portal_parceiro_como(uuid), ext.sala_enviar_como(uuid, bigint, text),
  ext.prestacao_enviar_como(uuid, text, text, text, text, bigint, text, bigint[], text), ext.telegram_codigo_como(uuid), ext.telegram_desligar_como(uuid), ext.pasta_externa_como(uuid), ext.pasta_externa_registrar_como(uuid, text, text),
  ext.sala_enviar(bigint, text, text), ext.sala_responder(bigint, text, uuid), ext.oportunidade_decidir(bigint, text, numeric, int, date, text, uuid),
  ext.comissao_adquirir(bigint, uuid), ext.prestacao_enviar(text, text, text, text, bigint, text, bigint[], text, text), ext.prestacao_decidir(bigint, text, text, uuid),
  ext.prestacao_pagar(bigint, text, uuid), ext.portal_parceiro(), ext.telegram_codigo(), ext.telegram_desligar(), ext.painel_parceiros(uuid, uuid),
  ext.contraparte_documento(uuid, text, uuid) from public, anon, authenticated;
grant execute on function ext.sala_enviar(bigint, text, text), ext.prestacao_enviar(text, text, text, text, bigint, text, bigint[], text, text), ext.portal_parceiro(),
  ext.telegram_codigo(), ext.telegram_desligar(), ext.sala_responder(bigint, text, uuid), ext.oportunidade_decidir(bigint, text, numeric, int, date, text, uuid),
  ext.comissao_adquirir(bigint, uuid), ext.prestacao_decidir(bigint, text, text, uuid), ext.prestacao_pagar(bigint, text, uuid), ext.painel_parceiros(uuid, uuid),
  ext.contraparte_documento(uuid, text, uuid) to authenticated;
grant execute on function ext.portal_parceiro_como(uuid), ext.sala_enviar_como(uuid, bigint, text), ext.prestacao_enviar_como(uuid, text, text, text, text, bigint, text, bigint[], text),
  ext.telegram_codigo_como(uuid), ext.telegram_desligar_como(uuid), ext.pasta_externa_como(uuid), ext.pasta_externa_registrar_como(uuid, text, text),
  ext.sala_enviar(bigint, text, text), ext.prestacao_enviar(text, text, text, text, bigint, text, bigint[], text, text),
  ext.portal_parceiro(), ext.telegram_codigo(), ext.sala_responder(bigint, text, uuid), ext.oportunidade_decidir(bigint, text, numeric, int, date, text, uuid),
  ext.comissao_adquirir(bigint, uuid), ext.prestacao_decidir(bigint, text, text, uuid), ext.prestacao_pagar(bigint, text, uuid), ext.painel_parceiros(uuid, uuid),
  ext.contraparte_documento(uuid, text, uuid), ext._telegram(bigint, text, text, text, boolean, boolean) to service_role;
commit;
