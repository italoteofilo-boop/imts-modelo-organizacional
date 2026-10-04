-- E23 · Nota de débito para ressarcimento (04/10/2026). Uma empresa do Ecossistema cobra de um cliente ou parceiro o reembolso
-- de despesas que pagou por conta dele (viagem, taxas, cópias). Não é documento fiscal: é cobrança com os comprovantes.
-- Número sequencial por empresa e ano ("ND 2026/0001"); rascunho → aprovada (por outra pessoa, nível aprovar) → emitida (PDF pelo
-- motor documental, tipo nota-debito, marca da empresa) → paga; ou cancelada com motivo. Publicação no portal pelo caminho de
-- documento do portal (ext.documento, PDF por ext.documento_pdf). Funções sem p_como: só para quem tem login.
-- Idempotente: pode rodar de novo.
begin;

-- ---------- histórico: objeto novo ----------
do $$
declare v_def text; v_lista text[];
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint where conname = 'historico_objeto_check' and conrelid = 'adm.historico'::regclass;
  v_lista := array(select m[1] from regexp_matches(coalesce(v_def, ''), '''([a-z_]+)''', 'g') m);
  if not ('nota_debito' = any (v_lista)) then
    v_lista := v_lista || 'nota_debito'::text;
    alter table adm.historico drop constraint if exists historico_objeto_check;
    execute format('alter table adm.historico add constraint historico_objeto_check check (objeto in (%s))',
                   (select string_agg(quote_literal(x), ', ') from unnest(v_lista) x));
  end if;
end $$;

-- ---------- tipo de documento (o mesmo do catálogo do motor: documentos/tipos/catalogo.json) ----------
insert into doc.tipo (id, nome, familia, modelo, alcance, regra, ligacao, origens)
values ('nota-debito', 'Nota de débito para ressarcimento de despesas', 'demonstrativo', 'demonstrativo', 'externo',
        'nota de debito|ressarcimento de despesas?|reembolso de despesas?', 'heuristica', '[]')
on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra;

-- ---------- tabelas ----------
create table if not exists doc.nota_debito (
  id bigint generated always as identity primary key,
  empresa uuid not null references org.empresa(id),
  contraparte uuid not null references ext.contraparte(id),
  ano smallint not null,
  sequencial int not null check (sequencial > 0),
  numero text not null,
  data date not null default current_date,
  vencimento date not null,
  referencia text,
  local text,
  total numeric(14,2) not null default 0 check (total >= 0),
  situacao text not null default 'rascunho' check (situacao in ('rascunho', 'aprovada', 'emitida', 'paga', 'cancelada')),
  criado_por uuid not null, criado_em timestamptz not null default now(),
  atualizado_por uuid, atualizado_em timestamptz not null default now(),
  aprovado_por uuid, aprovado_em timestamptz,
  emitido_por uuid, emitido_em timestamptz, pedido bigint references doc.pedido(id),
  emissao bigint references doc.emissao(id), publicado_por uuid, publicado_em timestamptz, publicado_perfis text[],
  pago_em date, pagamento_comprovante text, pagamento_arquivo bigint references acervo.arquivo(id), pagamento_por uuid, pagamento_registrado_em timestamptz,
  cancelado_motivo text, cancelado_por uuid, cancelado_em timestamptz,
  unique (empresa, ano, sequencial),
  check (vencimento >= data),
  check (extract(year from data)::smallint = ano),
  check (situacao <> 'cancelada' or coalesce(length(btrim(cancelado_motivo)), 0) > 0),
  check (situacao <> 'paga' or (pago_em is not null and coalesce(length(btrim(pagamento_comprovante)), 0) > 0)),
  check (aprovado_por is null or aprovado_por <> criado_por)
);
create table if not exists doc.nota_debito_item (
  id bigint generated always as identity primary key,
  nota bigint not null references doc.nota_debito(id) on delete cascade,
  ordem smallint not null,
  descricao text not null check (length(btrim(descricao)) between 1 and 300),
  data_despesa date not null,
  valor numeric(14,2) not null check (valor > 0),
  arquivo bigint references acervo.arquivo(id),
  unique (nota, ordem)
);
create index if not exists nota_debito_empresa on doc.nota_debito (empresa, situacao);
create index if not exists nota_debito_contraparte on doc.nota_debito (contraparte);
create index if not exists nota_debito_pedido on doc.nota_debito (pedido) where pedido is not null;
create index if not exists nota_debito_emissao on doc.nota_debito (emissao) where emissao is not null;
create index if not exists nota_debito_item_nota on doc.nota_debito_item (nota);
create index if not exists nota_debito_item_arquivo on doc.nota_debito_item (arquivo) where arquivo is not null;
create index if not exists nota_debito_pagamento_arquivo on doc.nota_debito (pagamento_arquivo) where pagamento_arquivo is not null;

alter table doc.nota_debito enable row level security;
alter table doc.nota_debito_item enable row level security;
drop policy if exists leitura on doc.nota_debito;
create policy leitura on doc.nota_debito for select to authenticated using (
  (rt.eu() is not null and rt.pode(rt.eu(), empresa, null, 'ler'))
  or (publicado_em is not null and contraparte = (ext.eu()).contraparte));
drop policy if exists leitura on doc.nota_debito_item;
create policy leitura on doc.nota_debito_item for select to authenticated using (exists (select 1 from doc.nota_debito n where n.id = nota));
revoke all on doc.nota_debito, doc.nota_debito_item from anon, public;
grant select on doc.nota_debito, doc.nota_debito_item to authenticated;
grant all on doc.nota_debito, doc.nota_debito_item to service_role;

-- ---------- apoio ----------
-- valor em reais no formato brasileiro, sem depender do idioma do banco
create or replace function doc._brl(p numeric) returns text language sql immutable set search_path = '' as $$
  select 'R$ ' || translate(to_char(coalesce(p, 0), 'FM999,999,999,990.00'), ',.', '.,') $$;

create or replace function doc._nd_eu() returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then raise exception 'só a equipe do IMTS mexe em nota de débito'; end if;
  return v;
end $$;

-- texto que vai para o PDF: o motor bloqueia travessão, campo pendente, sinal de modelo e número de versão; aqui a recusa vem antes
create or replace function doc._nd_texto(p text, p_campo text) returns text language plpgsql immutable set search_path = '' as $$
begin
  if p is null then return null; end if;
  if position(chr(8212) in p) > 0 then raise exception '%: sem travessão longo; use dois-pontos, vírgula ou ponto', p_campo; end if;
  if position(chr(173) in p) > 0 then raise exception '%: hífen invisível no texto', p_campo; end if;
  if p like '%[●%' or p ~ '\{\{|\{%|%\}|\}\}' then raise exception '%: marcador pendente ou sinal de modelo no texto', p_campo; end if;
  if p ~* '(^|[^[:alnum:]_])(v|vers[aã]o|rev\.?)\s?\d+' then raise exception '%: número de versão não entra no documento (a versão é a data)', p_campo; end if;
  return btrim(p);
end $$;

create or replace function doc._nd_hist(n doc.nota_debito, p_antes jsonb, p_depois jsonb, p_por uuid, p_motivo text) returns void
language sql security definer set search_path = '' as $$
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('nota_debito', n.numero || ' (' || n.id || ')', p_antes, p_depois, p_por, 'aplicativo', p_motivo) $$;

-- conteúdo do pedido ao motor documental (modelo demonstrativo, sem capa: campos, quadro das despesas com total, nota de não fiscal)
create or replace function doc._nd_conteudo(p_nota bigint) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare n doc.nota_debito; e org.empresa; c ext.contraparte; v_campos jsonb; v_linhas jsonb;
begin
  select * into n from doc.nota_debito where id = p_nota;
  select * into e from org.empresa where id = n.empresa;
  select * into c from ext.contraparte where id = n.contraparte;
  v_campos := jsonb_build_array(jsonb_build_array('Número', n.numero), jsonb_build_array('Credora', coalesce(e.razao_social, e.nome)));
  if e.cnpj is not null then v_campos := v_campos || jsonb_build_array(jsonb_build_array('CNPJ da credora', e.cnpj)); end if;
  v_campos := v_campos || jsonb_build_array(jsonb_build_array('Devedora', c.nome));
  if c.documento is not null then v_campos := v_campos || jsonb_build_array(jsonb_build_array('Documento da devedora', c.documento)); end if;
  v_campos := v_campos || jsonb_build_array(jsonb_build_array('Data', to_char(n.data, 'DD/MM/YYYY')), jsonb_build_array('Vencimento', to_char(n.vencimento, 'DD/MM/YYYY')));
  if coalesce(n.referencia, '') <> '' then v_campos := v_campos || jsonb_build_array(jsonb_build_array('Referência', n.referencia)); end if;
  v_campos := v_campos || jsonb_build_array(jsonb_build_array('Total a ressarcir', doc._brl(n.total)));
  select coalesce(jsonb_agg(jsonb_build_array(to_char(i.data_despesa, 'DD/MM/YYYY'), i.descricao,
           case when i.arquivo is null then 'sem comprovante' else 'nº ' || i.arquivo || ' no acervo' end, substr(doc._brl(i.valor), 4)) order by i.ordem), '[]')
    into v_linhas from doc.nota_debito_item i where i.nota = n.id;
  v_linhas := v_linhas || jsonb_build_array(jsonb_build_array('', 'Total', '', substr(doc._brl(n.total), 4)));
  return jsonb_build_object('titulo', 'Nota de débito ' || n.numero, 'data', to_char(n.data, 'YYYY-MM-DD'), 'local', n.local,
    'emitente', e.nome, 'capa', false, 'sumario', false, 'campos', v_campos,
    'blocos', jsonb_build_array(
      jsonb_build_object('t', 'secao', 'titulo', 'Despesas a ressarcir'),
      jsonb_build_object('t', 'p', 'texto', 'Despesas pagas pela credora por conta da devedora, com os comprovantes guardados no acervo da credora. Pagamento até '
                         || to_char(n.vencimento, 'DD/MM/YYYY') || '.'),
      jsonb_build_object('t', 'tabela', 'nome', 'Quadro 1 – Despesas (em R$)', 'cab', jsonb_build_array('Data', 'Descrição', 'Comprovante', 'Valor'),
                         'esq', jsonb_build_array(1, 2), 'linhas', v_linhas, 'total', true),
      jsonb_build_object('t', 'nota', 'texto', 'Nota de débito para ressarcimento de despesas. Não é documento fiscal: não há prestação de serviço nem venda de mercadoria, só o reembolso do que foi pago por conta da devedora.')),
    'nota_debito', n.id);
end $$;

-- ---------- criar ou editar rascunho ----------
create or replace function doc.nota_debito_salvar(p_empresa uuid, p_contraparte uuid, p_vencimento date, p_itens jsonb, p_nota bigint default null,
  p_data date default null, p_referencia text default null, p_local text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := doc._nd_eu(); n doc.nota_debito; antes jsonb; v_data date; v_ano smallint; v_seq int; i jsonb; k int := 0; v_total numeric(14,2) := 0;
  v_desc text; v_dd date; v_val numeric; v_arq bigint;
begin
  if p_nota is null then
    if p_empresa is null or not rt.pode(v, p_empresa, null, 'operar') then raise exception 'sem acesso para criar nota de débito nesta empresa'; end if;
    v_data := coalesce(p_data, current_date);
  else
    select * into n from doc.nota_debito where id = p_nota for update;
    if n.id is null then raise exception 'nota de débito inexistente'; end if;
    if not rt.pode(v, n.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
    if p_empresa is not null and p_empresa <> n.empresa then raise exception 'a nota é de outra empresa'; end if;
    if n.situacao <> 'rascunho' then raise exception 'só rascunho se edita (esta nota está %)', n.situacao; end if;
    v_data := coalesce(p_data, n.data);
    if extract(year from v_data)::smallint <> n.ano then raise exception 'a data muda o ano do número %: cancele e crie outra nota', n.numero; end if;
    antes := to_jsonb(n) || jsonb_build_object('itens', (select jsonb_agg(to_jsonb(x) - 'id' - 'nota' order by x.ordem) from doc.nota_debito_item x where x.nota = n.id));
  end if;
  if not exists (select 1 from ext.contraparte where id = p_contraparte and ativa and empresa = coalesce(n.empresa, p_empresa)) then
    raise exception 'cliente ou parceiro inexistente nesta empresa'; end if;
  if p_vencimento is null or p_vencimento < v_data then raise exception 'o vencimento não pode ser antes da data da nota'; end if;
  if v_data > current_date then raise exception 'a data da nota não pode ser futura'; end if;
  if jsonb_typeof(p_itens) is distinct from 'array' or jsonb_array_length(p_itens) = 0 then raise exception 'inclua ao menos uma despesa'; end if;
  if jsonb_array_length(p_itens) > 100 then raise exception 'no máximo 100 despesas por nota'; end if;
  -- confere todas as despesas antes de gravar
  for i in select * from jsonb_array_elements(p_itens) loop
    k := k + 1;
    v_desc := doc._nd_texto(i->>'descricao', 'despesa ' || k);
    if coalesce(v_desc, '') = '' then raise exception 'despesa %: descreva a despesa', k; end if;
    if length(v_desc) > 300 then raise exception 'despesa %: descrição com mais de 300 caracteres', k; end if;
    begin v_dd := (i->>'data')::date; exception when others then raise exception 'despesa %: data inválida', k; end;
    if v_dd is null then raise exception 'despesa %: informe a data da despesa', k; end if;
    if v_dd > v_data then raise exception 'despesa %: a despesa não pode ser depois da data da nota', k; end if;
    begin v_val := (i->>'valor')::numeric; exception when others then raise exception 'despesa %: valor inválido', k; end;
    if v_val is null or v_val <= 0 then raise exception 'despesa %: o valor tem de ser maior que zero', k; end if;
    if v_val <> round(v_val, 2) then raise exception 'despesa %: valor com mais de dois decimais', k; end if;
    v_arq := nullif(i->>'arquivo', '')::bigint;
    if v_arq is not null and not exists (select 1 from acervo.arquivo where id = v_arq and empresa = coalesce(n.empresa, p_empresa)) then
      raise exception 'despesa %: comprovante % não está no acervo desta empresa', k, v_arq; end if;
    v_total := v_total + v_val;
  end loop;
  if p_nota is null then
    v_ano := extract(year from v_data)::smallint;
    -- numeração sem buraco nem repetição: uma nota de cada vez por empresa e ano
    perform pg_advisory_xact_lock(hashtextextended('nota_debito:' || p_empresa || ':' || v_ano, 0));
    select coalesce(max(sequencial), 0) + 1 into v_seq from doc.nota_debito where empresa = p_empresa and ano = v_ano;
    insert into doc.nota_debito (empresa, contraparte, ano, sequencial, numero, data, vencimento, referencia, local, criado_por, atualizado_por)
    values (p_empresa, p_contraparte, v_ano, v_seq, 'ND ' || v_ano || '/' || lpad(v_seq::text, 4, '0'), v_data, p_vencimento,
            nullif(doc._nd_texto(p_referencia, 'referência'), ''), nullif(doc._nd_texto(p_local, 'local'), ''), v, v)
    returning * into n;
  else
    update doc.nota_debito set contraparte = p_contraparte, data = v_data, vencimento = p_vencimento,
      referencia = nullif(doc._nd_texto(p_referencia, 'referência'), ''), local = nullif(doc._nd_texto(p_local, 'local'), ''),
      atualizado_por = v, atualizado_em = now() where id = n.id returning * into n;
    delete from doc.nota_debito_item where nota = n.id;
  end if;
  k := 0;
  for i in select * from jsonb_array_elements(p_itens) loop
    k := k + 1;
    insert into doc.nota_debito_item (nota, ordem, descricao, data_despesa, valor, arquivo)
    values (n.id, k, doc._nd_texto(i->>'descricao', 'despesa ' || k), (i->>'data')::date, (i->>'valor')::numeric, nullif(i->>'arquivo', '')::bigint);
  end loop;
  update doc.nota_debito set total = (select coalesce(sum(valor), 0) from doc.nota_debito_item where nota = n.id) where id = n.id returning * into n;
  perform doc._nd_hist(n, antes, to_jsonb(n) || jsonb_build_object('itens', (select jsonb_agg(to_jsonb(x) - 'id' - 'nota' order by x.ordem) from doc.nota_debito_item x where x.nota = n.id)),
                       v, case when antes is null then 'rascunho criado' else 'rascunho editado' end);
  return jsonb_build_object('id', n.id, 'numero', n.numero, 'total', n.total, 'situacao', n.situacao);
end $$;

-- ---------- aprovar: outra pessoa, com nível aprovar na empresa ----------
create or replace function doc.nota_debito_aprovar(p_nota bigint) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := doc._nd_eu(); n doc.nota_debito;
begin
  select * into n from doc.nota_debito where id = p_nota for update;
  if n.id is null then raise exception 'nota de débito inexistente'; end if;
  if not rt.pode(v, n.empresa, null, 'ler') then raise exception 'sem acesso a esta empresa'; end if;
  if n.situacao <> 'rascunho' then raise exception 'só rascunho se aprova (esta nota está %)', n.situacao; end if;
  if v = n.criado_por or v = n.atualizado_por then raise exception 'quem criou ou editou a nota não aprova: precisa de outra pessoa'; end if;
  if not rt.pode(v, n.empresa, null, 'aprovar') then raise exception 'aprovar nota de débito pede o nível aprovar nesta empresa'; end if;
  if n.total <= 0 or not exists (select 1 from doc.nota_debito_item where nota = n.id) then raise exception 'nota sem despesas'; end if;
  if n.total <> (select sum(valor) from doc.nota_debito_item where nota = n.id) then raise exception 'total diferente da soma das despesas'; end if;
  if coalesce(n.local, '') = '' then raise exception 'informe o local de emissão (cidade/UF) no rascunho antes de aprovar'; end if;
  update doc.nota_debito set situacao = 'aprovada', aprovado_por = v, aprovado_em = now(), atualizado_em = now() where id = n.id returning * into n;
  perform doc._nd_hist(n, jsonb_build_object('situacao', 'rascunho'), jsonb_build_object('situacao', 'aprovada', 'total', n.total), v, 'aprovada');
  return jsonb_build_object('id', n.id, 'numero', n.numero, 'situacao', n.situacao);
end $$;

-- ---------- emitir: pede o PDF ao motor documental (fila do worker) ----------
create or replace function doc.nota_debito_emitir(p_nota bigint) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := doc._nd_eu(); n doc.nota_debito; v_sit_ped text; v_marca text; v_ped bigint;
begin
  select * into n from doc.nota_debito where id = p_nota for update;
  if n.id is null then raise exception 'nota de débito inexistente'; end if;
  if not rt.pode(v, n.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if n.situacao = 'emitida' then
    select situacao into v_sit_ped from doc.pedido where id = n.pedido;
    if v_sit_ped not in ('bloqueado', 'recusado', 'erro', 'reprovado') then raise exception 'a nota já foi emitida (documento %)', replace(coalesce(v_sit_ped, 'sem pedido'), '_', ' '); end if;
  elsif n.situacao <> 'aprovada' then raise exception 'só nota aprovada se emite (esta está %)', n.situacao;
  end if;
  v_marca := coalesce((select marca from ext.empresa_marca where empresa = n.empresa), 'neutra');
  v_ped := doc.pedir('nota-debito', v_marca, doc._nd_conteudo(n.id), n.empresa, null, null, null);
  update doc.nota_debito set situacao = 'emitida', emitido_por = v, emitido_em = now(), pedido = v_ped, emissao = null, atualizado_em = now() where id = n.id returning * into n;
  perform doc._nd_hist(n, jsonb_build_object('situacao', 'aprovada'), jsonb_build_object('situacao', 'emitida', 'pedido', v_ped, 'marca', v_marca), v,
                       case when v_sit_ped is null then 'pedido de emissão ao motor documental' else 'nova emissão: a anterior ficou ' || v_sit_ped end);
  return jsonb_build_object('id', n.id, 'numero', n.numero, 'situacao', n.situacao, 'pedido', v_ped, 'marca', v_marca);
end $$;

-- ---------- publicar no portal do cliente ou parceiro (ext.documento; o PDF sai por ext.documento_pdf) ----------
create or replace function doc.nota_debito_publicar(p_nota bigint, p_perfis text[] default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := doc._nd_eu(); n doc.nota_debito; e doc.emissao; v_perfis text[] := coalesce(p_perfis, '{gestor,fiscal,financeiro,operacional}');
begin
  select * into n from doc.nota_debito where id = p_nota for update;
  if n.id is null then raise exception 'nota de débito inexistente'; end if;
  if not rt.pode(v, n.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if n.situacao not in ('emitida', 'paga') then raise exception 'só nota emitida vai para o portal (esta está %)', n.situacao; end if;
  if not (v_perfis <@ array['gestor', 'fiscal', 'financeiro', 'operacional']) or cardinality(v_perfis) = 0 then raise exception 'perfis: gestor, fiscal, financeiro ou operacional'; end if;
  select * into e from doc.emissao where pedido = n.pedido order by id desc limit 1;
  if e.id is null then raise exception 'o PDF ainda não foi gerado: o pedido está na fila do motor documental'; end if;
  if e.situacao not in ('emitido', 'emitido_com_alertas') then raise exception 'a emissão ficou % no motor documental: emita de novo', e.situacao; end if;
  if (select empresa from ext.contraparte where id = n.contraparte) <> n.empresa then raise exception 'o documento e a contraparte são de empresas diferentes'; end if;
  insert into ext.documento (contraparte, emissao, perfis, publicado_por) values (n.contraparte, e.id, v_perfis, v)
  on conflict (contraparte, emissao) do update set perfis = excluded.perfis;
  update doc.nota_debito set emissao = e.id, publicado_por = v, publicado_em = now(), publicado_perfis = v_perfis, atualizado_em = now() where id = n.id returning * into n;
  perform ext._avisar(n.contraparte, 'Nota de débito ' || n.numero || ' no portal: ' || doc._brl(n.total) || ', vencimento ' || to_char(n.vencimento, 'DD/MM/YYYY') || '.');
  perform doc._nd_hist(n, null, jsonb_build_object('publicada', true, 'emissao', e.id, 'perfis', v_perfis), v, 'publicada no portal');
  return jsonb_build_object('id', n.id, 'numero', n.numero, 'emissao', e.id);
end $$;

-- ---------- registrar o pagamento (quem aprovou não registra) ----------
create or replace function doc.nota_debito_pagar(p_nota bigint, p_data date, p_comprovante text, p_arquivo bigint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := doc._nd_eu(); n doc.nota_debito;
begin
  select * into n from doc.nota_debito where id = p_nota for update;
  if n.id is null then raise exception 'nota de débito inexistente'; end if;
  if not rt.pode(v, n.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if n.situacao <> 'emitida' then raise exception 'só nota emitida recebe pagamento (esta está %)', n.situacao; end if;
  if v = n.aprovado_por then raise exception 'quem aprovou a nota não registra o pagamento'; end if;
  if p_data is null or p_data > current_date then raise exception 'informe a data do pagamento (não futura)'; end if;
  if p_data < n.data then raise exception 'o pagamento não pode ser antes da data da nota'; end if;
  if coalesce(length(btrim(p_comprovante)), 0) = 0 then raise exception 'informe a referência do comprovante de pagamento'; end if;
  if p_arquivo is not null and not exists (select 1 from acervo.arquivo where id = p_arquivo and empresa = n.empresa) then raise exception 'comprovante % não está no acervo desta empresa', p_arquivo; end if;
  update doc.nota_debito set situacao = 'paga', pago_em = p_data, pagamento_comprovante = btrim(p_comprovante), pagamento_arquivo = p_arquivo,
    pagamento_por = v, pagamento_registrado_em = now(), atualizado_em = now() where id = n.id returning * into n;
  if n.publicado_em is not null then perform ext._avisar(n.contraparte, 'Pagamento da nota de débito ' || n.numero || ' registrado: ' || doc._brl(n.total) || '.'); end if;
  perform doc._nd_hist(n, jsonb_build_object('situacao', 'emitida'), jsonb_build_object('situacao', 'paga', 'pago_em', p_data, 'comprovante', n.pagamento_comprovante, 'arquivo', p_arquivo), v, 'pagamento registrado');
  return jsonb_build_object('id', n.id, 'numero', n.numero, 'situacao', n.situacao);
end $$;

-- ---------- cancelar com motivo (o número fica, a cobrança sai do portal) ----------
create or replace function doc.nota_debito_cancelar(p_nota bigint, p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := doc._nd_eu(); n doc.nota_debito; v_antes text;
begin
  select * into n from doc.nota_debito where id = p_nota for update;
  if n.id is null then raise exception 'nota de débito inexistente'; end if;
  if not rt.pode(v, n.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'cancelar exige motivo'; end if;
  if n.situacao in ('paga', 'cancelada') then raise exception 'nota % não se cancela', n.situacao; end if;
  if n.situacao <> 'rascunho' and not rt.pode(v, n.empresa, null, 'aprovar') then raise exception 'cancelar nota já aprovada pede o nível aprovar nesta empresa'; end if;
  v_antes := n.situacao;
  if n.pedido is not null then
    delete from ext.documento d where d.contraparte = n.contraparte and d.emissao in (select id from doc.emissao where pedido = n.pedido);
  end if;
  update doc.nota_debito set situacao = 'cancelada', cancelado_motivo = btrim(p_motivo), cancelado_por = v, cancelado_em = now(), emissao = null, atualizado_em = now()
   where id = n.id returning * into n;
  if n.publicado_em is not null then perform ext._avisar(n.contraparte, 'Nota de débito ' || n.numero || ' cancelada: ' || n.cancelado_motivo); end if;
  perform doc._nd_hist(n, jsonb_build_object('situacao', v_antes), jsonb_build_object('situacao', 'cancelada'), v, btrim(p_motivo));
  return jsonb_build_object('id', n.id, 'numero', n.numero, 'situacao', n.situacao);
end $$;

-- ---------- painel da empresa (Central de atendimento, aba Notas de débito) ----------
create or replace function doc.painel_notas_debito(p_empresa uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := doc._nd_eu();
begin
  if p_empresa is null or not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso a esta empresa'; end if;
  return jsonb_build_object(
    'pode', jsonb_build_object('operar', rt.pode(v, p_empresa, null, 'operar'), 'aprovar', rt.pode(v, p_empresa, null, 'aprovar')),
    'eu', v,
    'notas', (select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'numero', n.numero, 'data', n.data, 'vencimento', n.vencimento, 'referencia', n.referencia, 'local', n.local,
        'contraparte', jsonb_build_object('id', c.id, 'nome', c.nome, 'tipo', c.tipo), 'total', n.total, 'situacao', n.situacao,
        'vencida', n.situacao = 'emitida' and n.vencimento < current_date,
        'criado_por', n.criado_por, 'criado_por_nome', (select nome from rt_chave.identidade where pseudonimo = n.criado_por), 'criado_em', n.criado_em,
        'atualizado_por', n.atualizado_por, 'aprovado_por_nome', (select nome from rt_chave.identidade where pseudonimo = n.aprovado_por), 'aprovado_por', n.aprovado_por, 'aprovado_em', n.aprovado_em,
        'emitido_em', n.emitido_em, 'pedido', n.pedido, 'pedido_situacao', p.situacao, 'pedido_erro', p.erro,
        'emissao_pronta', (select e.id from doc.emissao e where e.pedido = n.pedido and e.situacao in ('emitido', 'emitido_com_alertas') and e.id = (select max(id) from doc.emissao where pedido = n.pedido)),
        'publicado_em', n.publicado_em, 'emissao', n.emissao,
        'pago_em', n.pago_em, 'pagamento_comprovante', n.pagamento_comprovante, 'pagamento_arquivo', n.pagamento_arquivo,
        'pagamento_por_nome', (select nome from rt_chave.identidade where pseudonimo = n.pagamento_por),
        'cancelado_motivo', n.cancelado_motivo, 'cancelado_em', n.cancelado_em,
        'itens', (select coalesce(jsonb_agg(jsonb_build_object('descricao', i.descricao, 'data', i.data_despesa, 'valor', i.valor, 'arquivo', i.arquivo,
                    'arquivo_nome', (select a.nome from acervo.arquivo a where a.id = i.arquivo)) order by i.ordem), '[]') from doc.nota_debito_item i where i.nota = n.id))
        order by n.ano desc, n.sequencial desc), '[]')
        from doc.nota_debito n join ext.contraparte c on c.id = n.contraparte left join doc.pedido p on p.id = n.pedido where n.empresa = p_empresa),
    'contrapartes', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'nome', c.nome, 'tipo', c.tipo) order by c.nome), '[]') from ext.contraparte c where c.empresa = p_empresa and c.ativa),
    'arquivos', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'nome', a.nome, 'criado_em', a.criado_em) order by a.id desc), '[]')
                   from (select * from acervo.arquivo where empresa = p_empresa and situacao <> 'substituido' order by id desc limit 200) a),
    'ultimo_local', (select local from doc.nota_debito where empresa = p_empresa and local is not null order by id desc limit 1));
end $$;

-- ---------- PDF da nota para quem é de dentro (conferir antes de publicar) ----------
create or replace function doc.nota_debito_pdf(p_nota bigint) returns text language plpgsql stable security definer set search_path = '' as $$
declare v uuid := doc._nd_eu(); n doc.nota_debito; v_em bigint;
begin
  select * into n from doc.nota_debito where id = p_nota;
  if n.id is null or not rt.pode(v, n.empresa, null, 'ler') then raise exception 'nota de débito inexistente ou sem acesso'; end if;
  select e.id into v_em from doc.emissao e where e.pedido = n.pedido and e.situacao in ('emitido', 'emitido_com_alertas') order by e.id desc limit 1;
  if v_em is null then raise exception 'o PDF desta nota ainda não foi gerado'; end if;
  return (select encode(conteudo, 'base64') from doc.arquivo where emissao = v_em and formato = 'pdf');
end $$;

-- ---------- portal: as notas de débito publicadas para a organização de quem entra ----------
create or replace function ext.portal_notas_debito() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario := ext._exigir_eu();
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'numero', n.numero, 'data', n.data, 'vencimento', n.vencimento, 'referencia', n.referencia,
      'empresa', (select nome from org.empresa where id = n.empresa), 'total', n.total, 'situacao', n.situacao,
      'vencida', n.situacao = 'emitida' and n.vencimento < current_date, 'pago_em', n.pago_em, 'cancelado_motivo', n.cancelado_motivo,
      'publicado_em', n.publicado_em,
      'emissao', case when d.emissao is not null then n.emissao end, 'paginas', (select paginas from doc.emissao where id = d.emissao),
      'itens', (select coalesce(jsonb_agg(jsonb_build_object('descricao', i.descricao, 'data', i.data_despesa, 'valor', i.valor, 'comprovante', i.arquivo is not null) order by i.ordem), '[]')
                  from doc.nota_debito_item i where i.nota = n.id))
      order by n.data desc, n.id desc), '[]')
    from doc.nota_debito n
    left join ext.documento d on d.contraparte = n.contraparte and d.emissao = n.emissao and u.perfil = any (d.perfis)
   where n.contraparte = u.contraparte and n.publicado_em is not null
     and (d.emissao is not null or (n.situacao = 'cancelada' and u.perfil = any (n.publicado_perfis))));
end $$;

-- ---------- porta única ----------
insert into adm.api_funcao (nome, quem, descricao) values
 ('doc.painel_notas_debito', 'interno', 'Central: notas de débito'),
 ('doc.nota_debito_salvar', 'interno', 'criar ou editar rascunho de nota de débito'),
 ('doc.nota_debito_aprovar', 'interno', 'aprovar nota de débito'),
 ('doc.nota_debito_emitir', 'interno', 'emitir o PDF da nota de débito'),
 ('doc.nota_debito_publicar', 'interno', 'publicar nota de débito no portal'),
 ('doc.nota_debito_pagar', 'interno', 'registrar pagamento da nota de débito'),
 ('doc.nota_debito_cancelar', 'interno', 'cancelar nota de débito'),
 ('doc.nota_debito_pdf', 'interno', 'baixar o PDF da nota de débito'),
 ('ext.portal_notas_debito', 'externo', 'notas de débito')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;

revoke all on function doc._brl(numeric), doc._nd_eu(), doc._nd_texto(text, text), doc._nd_hist(doc.nota_debito, jsonb, jsonb, uuid, text), doc._nd_conteudo(bigint)
  from public, anon, authenticated;
revoke all on function doc.nota_debito_salvar(uuid, uuid, date, jsonb, bigint, date, text, text), doc.nota_debito_aprovar(bigint), doc.nota_debito_emitir(bigint),
  doc.nota_debito_publicar(bigint, text[]), doc.nota_debito_pagar(bigint, date, text, bigint), doc.nota_debito_cancelar(bigint, text), doc.painel_notas_debito(uuid),
  doc.nota_debito_pdf(bigint), ext.portal_notas_debito() from public, anon;
grant execute on function doc.nota_debito_salvar(uuid, uuid, date, jsonb, bigint, date, text, text), doc.nota_debito_aprovar(bigint), doc.nota_debito_emitir(bigint),
  doc.nota_debito_publicar(bigint, text[]), doc.nota_debito_pagar(bigint, date, text, bigint), doc.nota_debito_cancelar(bigint, text), doc.painel_notas_debito(uuid),
  doc.nota_debito_pdf(bigint), ext.portal_notas_debito() to authenticated, service_role;

-- ---------- testes (rodar sempre no bloco que desfaz: do $$ begin raise exception '%', doc._testar_nota_debito(); end $$;) ----------
create or replace function doc._testar_nota_debito() returns text language plpgsql set search_path = '' as $$
declare a1 uuid; dom text := adm.valor('login.dominios', '["imts.com.br"]') ->> 0; r jsonb; ok boolean; e1 uuid; e2 uuid; ca uuid; cb uuid; arq bigint;
  u_cria uuid := gen_random_uuid(); u_aprova uuid := gen_random_uuid(); u_aprova2 uuid := gen_random_uuid(); u_fora uuid := gen_random_uuid();
  u_cli_a uuid := gen_random_uuid(); u_cli_b uuid := gen_random_uuid(); n1 bigint; n2 bigint; n3 bigint; nx bigint; v_ped bigint; v_em bigint; v_marca text;
  itens jsonb := '[{"descricao": "Passagem aérea para a reunião de implantação", "data": "2026-01-02", "valor": 100.10}, {"descricao": "Táxi do aeroporto", "data": "2026-01-02", "valor": 50.25}]';
  b1 text := '771110000001'; b2 text := '771110000002'; n_testes int := 10;
begin
  select p.pseudonimo into a1 from rt.pessoa p where rt.pode_estrito(p.pseudonimo, null, null, 'administrar') order by p.simulado, p.pseudonimo limit 1;
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  r := adm.importar_cadastro(jsonb_build_object(
    'empresas', jsonb_build_array(
      jsonb_build_object('nome', 'Empresa ND Um', 'cnpj', acervo._cnpj_formatar(b1 || acervo._cnpj_dv(b1)), 'regime_tributario', 'Lucro Presumido', 'marca', 'imts'),
      jsonb_build_object('nome', 'Empresa ND Dois', 'cnpj', acervo._cnpj_formatar(b2 || acervo._cnpj_dv(b2)), 'regime_tributario', 'Lucro Presumido', 'marca', 'onni')),
    'pessoas', jsonb_build_array(
      jsonb_build_object('nome', 'Cria ND', 'email', 'cria.nd@' || dom, 'papel', 'Operações · pessoa', 'circulo', 7, 'nivel', 'operar', 'empresa', 'Empresa ND Um'),
      jsonb_build_object('nome', 'Aprova ND', 'email', 'aprova.nd@' || dom, 'papel', 'Líder do círculo', 'circulo', 7, 'nivel', 'aprovar', 'empresa', 'Empresa ND Um'),
      jsonb_build_object('nome', 'Aprova Dois ND', 'email', 'aprova2.nd@' || dom, 'papel', 'Líder do círculo', 'circulo', 8, 'nivel', 'aprovar', 'empresa', 'Empresa ND Um'),
      jsonb_build_object('nome', 'Fora ND', 'email', 'fora.nd@' || dom, 'papel', 'Líder do círculo', 'circulo', 7, 'nivel', 'aprovar', 'empresa', 'Empresa ND Dois')),
    'contrapartes', jsonb_build_array(
      jsonb_build_object('empresa', 'Empresa ND Um', 'tipo', 'cliente', 'nome', 'Cliente ND A', 'setor_publico', true),
      jsonb_build_object('empresa', 'Empresa ND Um', 'tipo', 'parceiro', 'nome', 'Parceiro ND B', 'setor_publico', false),
      jsonb_build_object('empresa', 'Empresa ND Dois', 'tipo', 'cliente', 'nome', 'Cliente ND C', 'setor_publico', true)),
    'usuarios_externos', jsonb_build_array(
      jsonb_build_object('contraparte', 'Cliente ND A', 'nome', 'Cli A', 'email', 'cli.a@nd-teste.gov.br', 'perfil', 'gestor'),
      jsonb_build_object('contraparte', 'Parceiro ND B', 'nome', 'Cli B', 'email', 'cli.b@nd-teste.com.br', 'perfil', 'gestor'))), true, a1);
  if not (r->>'confirmado')::boolean then raise exception 'FALHA preparo: %', r; end if;
  select id into e1 from org.empresa where nome = 'Empresa ND Um'; select id into e2 from org.empresa where nome = 'Empresa ND Dois';
  select id into ca from ext.contraparte where nome = 'Cliente ND A'; select id into cb from ext.contraparte where nome = 'Parceiro ND B';
  insert into auth.users (id, email, aud, role) values (u_cria, 'cria.nd@' || dom, 'authenticated', 'authenticated'), (u_aprova, 'aprova.nd@' || dom, 'authenticated', 'authenticated'),
    (u_aprova2, 'aprova2.nd@' || dom, 'authenticated', 'authenticated'), (u_fora, 'fora.nd@' || dom, 'authenticated', 'authenticated'),
    (u_cli_a, 'cli.a@nd-teste.gov.br', 'authenticated', 'authenticated'), (u_cli_b, 'cli.b@nd-teste.com.br', 'authenticated', 'authenticated');
  insert into acervo.arquivo (empresa, pasta, nome_original, nome, hash, origem, situacao, criado_em)
  values (e1, '99', 'recibo-taxi.pdf', 'recibo-taxi.pdf', repeat('a', 64), 'upload', 'triagem', now()) returning id into arq;

  -- N1. numeração por empresa e ano, sem repetir; outra empresa começa do 1
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cria, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cria::text, true);
  n1 := (doc.nota_debito_salvar(e1, ca, current_date + 15, itens, null, current_date, 'Implantação', 'Fortaleza/CE')->>'id')::bigint;
  n2 := (doc.nota_debito_salvar(e1, cb, current_date + 15, itens, null, current_date, null, 'Fortaleza/CE')->>'id')::bigint;
  if (select numero from doc.nota_debito where id = n1) <> 'ND ' || extract(year from current_date) || '/0001'
     or (select numero from doc.nota_debito where id = n2) <> 'ND ' || extract(year from current_date) || '/0002' then
    raise exception 'FALHA N1: numeração %', (select string_agg(numero, ', ') from doc.nota_debito where id in (n1, n2)); end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_fora, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_fora::text, true);
  -- quem só tem a Empresa ND Dois não cria nota com cliente da Empresa ND Um
  ok := false; begin perform doc.nota_debito_salvar(e2, ca, current_date + 15, itens, null, current_date, null, 'Recife/PE'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA N1: nota com cliente de outra empresa'; end if;
  r := doc.nota_debito_salvar(e2, (select id from ext.contraparte where nome = 'Cliente ND C'), current_date + 15, itens, null, current_date, null, 'Recife/PE');
  if r->>'numero' <> 'ND ' || extract(year from current_date) || '/0001' then raise exception 'FALHA N1: outra empresa não começa do 1: %', r->>'numero'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cria, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cria::text, true);

  -- N2. total calculado das despesas; a edição troca as despesas e recalcula; comprovante só do acervo da empresa
  if (select total from doc.nota_debito where id = n1) <> 150.35 then raise exception 'FALHA N2: total %', (select total from doc.nota_debito where id = n1); end if;
  r := doc.nota_debito_salvar(e1, ca, current_date + 20, itens || jsonb_build_array(jsonb_build_object('descricao', 'Cópias autenticadas', 'data', current_date, 'valor', 9.65, 'arquivo', arq)), n1, current_date, 'Implantação', 'Fortaleza/CE');
  if (r->>'total')::numeric <> 160.00 or (select count(*) from doc.nota_debito_item where nota = n1) <> 3 then raise exception 'FALHA N2: edição %', r; end if;
  ok := false; begin perform doc.nota_debito_salvar(e1, ca, current_date + 20, '[{"descricao": "Taxa", "data": "2026-01-01", "valor": -5}]', n1, current_date, null, 'Fortaleza/CE'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA N2: valor negativo aceito'; end if;
  ok := false; begin perform doc.nota_debito_salvar(e1, ca, current_date + 20, jsonb_build_array(jsonb_build_object('descricao', 'Passagem ' || chr(8212) || ' ida', 'data', current_date, 'valor', 1)), n1, current_date, null, 'Fortaleza/CE'); exception when others then ok := sqlerrm like '%travessão%'; end;
  if not ok then raise exception 'FALHA N2: travessão aceito'; end if;

  -- N3. quem cria não aprova (mesmo com nível aprovar); quem editou também não
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_aprova2, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_aprova2::text, true);
  n3 := (doc.nota_debito_salvar(e1, ca, current_date + 10, itens, null, current_date, null, 'Fortaleza/CE')->>'id')::bigint;
  ok := false; begin perform doc.nota_debito_aprovar(n3); exception when others then ok := sqlerrm like '%quem criou%'; end;
  if not ok then raise exception 'FALHA N3: quem criou aprovou'; end if;
  perform doc.nota_debito_salvar(e1, ca, current_date + 15, itens, n2, current_date, null, 'Fortaleza/CE');   -- aprova2 edita a nota de outra pessoa
  ok := false; begin perform doc.nota_debito_aprovar(n2); exception when others then ok := sqlerrm like '%quem criou ou editou%'; end;
  if not ok then raise exception 'FALHA N3: quem editou aprovou'; end if;

  -- N4. nível: quem só opera não aprova; com nível aprovar, outra pessoa aprova; aprovada não se edita
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cria, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cria::text, true);
  ok := false; begin perform doc.nota_debito_aprovar(n3); exception when others then ok := sqlerrm like '%nível aprovar%'; end;
  if not ok then raise exception 'FALHA N4: quem só opera aprovou'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_aprova, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_aprova::text, true);
  perform doc.nota_debito_aprovar(n1);
  if (select situacao from doc.nota_debito where id = n1) <> 'aprovada' then raise exception 'FALHA N4: não aprovou'; end if;
  ok := false; begin perform doc.nota_debito_salvar(e1, ca, current_date + 20, itens, n1, current_date, null, 'Fortaleza/CE'); exception when others then ok := sqlerrm like '%só rascunho%'; end;
  if not ok then raise exception 'FALHA N4: aprovada editada'; end if;

  -- N5. cancelar exige motivo; cancelada não se aprova; o número cancelado não volta
  ok := false; begin perform doc.nota_debito_cancelar(n3, '  '); exception when others then ok := sqlerrm like '%motivo%'; end;
  if not ok then raise exception 'FALHA N5: cancelou sem motivo'; end if;
  perform doc.nota_debito_cancelar(n3, 'Despesa já reembolsada pelo cliente');
  ok := false; begin perform doc.nota_debito_aprovar(n3); exception when others then ok := true; end;
  if not ok or (select situacao from doc.nota_debito where id = n3) <> 'cancelada' then raise exception 'FALHA N5: cancelada'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cria, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cria::text, true);
  nx := (doc.nota_debito_salvar(e1, ca, current_date + 15, itens, null, current_date, null, 'Fortaleza/CE')->>'id')::bigint;
  if (select sequencial from doc.nota_debito where id = nx) <> 4 then raise exception 'FALHA N5: número reaproveitado'; end if;

  -- N6. emitir cria o pedido ao motor documental (tipo nota-debito, marca da empresa); rascunho não se emite
  ok := false; begin perform doc.nota_debito_emitir(nx); exception when others then ok := sqlerrm like '%só nota aprovada%'; end;
  if not ok then raise exception 'FALHA N6: rascunho emitido'; end if;
  r := doc.nota_debito_emitir(n1); v_ped := (r->>'pedido')::bigint;
  select marca into v_marca from ext.empresa_marca where empresa = e1;
  if not exists (select 1 from doc.pedido where id = v_ped and tipo = 'nota-debito' and marca = v_marca and empresa = e1 and situacao = 'na_fila'
                  and conteudo->>'titulo' like 'Nota de débito ND %/0001' and jsonb_array_length(conteudo->'blocos'->2->'linhas') = 4)
     or (select situacao from doc.nota_debito where id = n1) <> 'emitida' then raise exception 'FALHA N6: pedido %', r; end if;
  ok := false; begin perform doc.nota_debito_emitir(n1); exception when others then ok := sqlerrm like '%já foi emitida%'; end;
  if not ok then raise exception 'FALHA N6: emitiu duas vezes com o pedido na fila'; end if;

  -- N7. publicar: só com o PDF pronto; aparece no portal da contraparte certa e de mais ninguém
  ok := false; begin perform doc.nota_debito_publicar(n1); exception when others then ok := sqlerrm like '%na fila%'; end;
  if not ok then raise exception 'FALHA N7: publicou sem PDF'; end if;
  insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro, worker) values (v_ped, 'emitido', 1, repeat('b', 64), '{}', 'teste') returning id into v_em;
  insert into doc.arquivo values (v_em, 'pdf', '\x255044462d', repeat('b', 64), 5);
  update doc.pedido set situacao = 'emitido' where id = v_ped;
  perform doc.nota_debito_publicar(n1);
  if doc.nota_debito_pdf(n1) <> encode('\x255044462d'::bytea, 'base64') then raise exception 'FALHA N7: PDF para quem é de dentro'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli_a, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cli_a::text, true);
  r := ext.portal_notas_debito();
  if jsonb_array_length(r) <> 1 or (r->0->>'id')::bigint <> n1 or (r->0->>'emissao')::bigint <> v_em or (r->0->>'total')::numeric <> 160.00 then raise exception 'FALHA N7: portal A %', r; end if;
  if ext.documento_pdf(v_em) is null then raise exception 'FALHA N7: PDF não sai para A'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli_b, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cli_b::text, true);
  if jsonb_array_length(ext.portal_notas_debito()) <> 0 then raise exception 'FALHA N7: B vê nota de A'; end if;
  ok := false; begin perform ext.documento_pdf(v_em); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA N7: B baixou o PDF de A'; end if;

  -- N8. outra empresa sem acesso: painel, aprovação, edição e pagamento recusados
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_fora, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_fora::text, true);
  ok := false; begin perform doc.painel_notas_debito(e1); exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'FALHA N8: painel de outra empresa'; end if;
  ok := false; begin perform doc.nota_debito_aprovar(n2); exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'FALHA N8: aprovou em outra empresa'; end if;
  ok := false; begin perform doc.nota_debito_salvar(null, ca, current_date + 15, itens, n2, null, null, null); exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'FALHA N8: editou em outra empresa'; end if;
  ok := false; begin perform doc.nota_debito_pagar(n1, current_date, 'PIX 123'); exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'FALHA N8: pagou em outra empresa'; end if;
  if jsonb_array_length(doc.painel_notas_debito(e2)->'notas') <> 1 then raise exception 'FALHA N8: notas de outra empresa no painel'; end if;

  -- N9. pagamento: quem aprovou não registra; outra pessoa registra com data e comprovante; paga não se cancela
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_aprova, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_aprova::text, true);
  ok := false; begin perform doc.nota_debito_pagar(n1, current_date, 'PIX 123'); exception when others then ok := sqlerrm like '%quem aprovou%'; end;
  if not ok then raise exception 'FALHA N9: quem aprovou registrou o pagamento'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cria, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cria::text, true);
  ok := false; begin perform doc.nota_debito_pagar(n1, current_date, ''); exception when others then ok := sqlerrm like '%comprovante%'; end;
  if not ok then raise exception 'FALHA N9: pagamento sem comprovante'; end if;
  perform doc.nota_debito_pagar(n1, current_date, 'PIX E123456', arq);
  ok := false; begin perform doc.nota_debito_cancelar(n1, 'engano'); exception when others then ok := true; end;
  if not ok or (select situacao from doc.nota_debito where id = n1) <> 'paga' then raise exception 'FALHA N9: paga'; end if;

  -- N10. trilha no histórico e cancelamento de nota publicada tira o PDF do portal
  if (select count(*) from adm.historico where objeto = 'nota_debito' and chave like '%(' || n1 || ')') < 5 then raise exception 'FALHA N10: histórico da nota'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_aprova, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_aprova::text, true);
  perform doc.nota_debito_aprovar(nx);   -- nota criada por outra pessoa
  r := doc.nota_debito_emitir(nx);
  insert into doc.emissao (pedido, situacao, paginas, hash_pdf, registro, worker) values ((r->>'pedido')::bigint, 'emitido', 1, repeat('c', 64), '{}', 'teste') returning id into v_em;
  insert into doc.arquivo values (v_em, 'pdf', '\x255044462d', repeat('c', 64), 5);
  update doc.pedido set situacao = 'emitido' where id = (r->>'pedido')::bigint;
  perform doc.nota_debito_publicar(nx);
  perform doc.nota_debito_cancelar(nx, 'Cobrança em duplicidade');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli_a, 'role', 'authenticated')::text, true); perform set_config('request.jwt.claim.sub', u_cli_a::text, true);
  r := ext.portal_notas_debito();
  if not exists (select 1 from jsonb_array_elements(r) x where (x->>'id')::bigint = nx and x->>'situacao' = 'cancelada' and x->'emissao' = 'null'::jsonb) then raise exception 'FALHA N10: portal %', r; end if;
  ok := false; begin perform ext.documento_pdf(v_em); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA N10: PDF de nota cancelada ainda sai'; end if;

  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  return 'nota de débito: ' || n_testes || ' de ' || n_testes || ' ok';
end $$;
revoke all on function doc._testar_nota_debito() from public, anon, authenticated;
commit;
