-- E17 Alimentação: o acervo de cada empresa. Os arquivos ficam no Google Drive (pasta da empresa, árvore padrão); aqui fica o
-- registro de cada arquivo (hash, tipo, pasta, versão, dados extraídos, situação). Pasta é entrada, não fonte da verdade:
-- o sistema classifica e propõe; dado sensível só vale depois de duas pessoas aprovarem; divergência vira pendência, nunca escolha.
begin;
create schema if not exists acervo;
grant usage on schema acervo to authenticated, service_role;

alter table org.empresa add column if not exists cnpj text;
alter table org.empresa add column if not exists razao_social text;

-- árvore padrão, igual em todas as empresas
create table if not exists acervo.pasta (
  codigo text primary key,
  nome text not null,
  ordem int not null,
  descricao text not null
);
insert into acervo.pasta (codigo, nome, ordem, descricao) values
 ('00', '00 Entrada', 0, 'Onde o arquivo chega antes de ser classificado; nada fica aqui depois da classificação'),
 ('01', '01 Societário', 1, 'Contrato social, alterações, cartão CNPJ, atas de sócios, procurações'),
 ('02', '02 Fiscal e tributário', 2, 'Certidões, notas fiscais, guias e obrigações'),
 ('03', '03 Pessoas', 3, 'Documentos de pessoas: acesso restrito; o sistema não extrai dado pessoal daqui'),
 ('04', '04 Marca', 4, 'Manual de marca, logotipos, fontes'),
 ('05', '05 Modelos de documento', 5, 'Minutas e modelos que viram blocos do motor documental'),
 ('06', '06 Contratos', 6, 'Contratos com clientes, fornecedores e parceiros'),
 ('07', '07 Parceiros', 7, 'Notas fiscais e relatórios de prestação de contas dos parceiros'),
 ('08', '08 Clientes e atendimento', 8, 'Anexos de chamados, ordens de serviço e manifestações'),
 ('09', '09 Reuniões', 9, 'Gravações, transcrições e atas'),
 ('99', '99 Triagem', 99, 'O que o sistema não classificou com segurança; uma pessoa decide')
on conflict (codigo) do update set nome = excluded.nome, ordem = excluded.ordem, descricao = excluded.descricao;

-- catálogo de tipos: regra de reconhecimento pelo texto e pelo nome, pasta de destino e o que se extrai
create table if not exists acervo.tipo (
  id text primary key,
  nome text not null,
  pasta text not null references acervo.pasta(codigo),
  prioridade int not null,
  regra_texto text,                 -- expressão regular, sem diferenciar maiúsculas, sobre o texto do arquivo
  regra_nome text,                  -- expressão regular sobre o nome do arquivo
  extrai text[] not null default '{}',  -- campos da empresa que este tipo informa
  versao text not null default 'nenhuma' check (versao in ('nenhuma', 'tipo', 'numero')),  -- 'tipo': um vigente por empresa; 'numero': um por número
  sensivel boolean not null default false
);
insert into acervo.tipo (id, nome, pasta, prioridade, regra_texto, regra_nome, extrai, versao, sensivel) values
 ('cartao-cnpj', 'Cartão CNPJ', '01', 10, 'comprovante de inscri[cç][aã]o e de situa[cç][aã]o cadastral', 'cart[aã]o[ _-]?cnpj', '{cnpj,razao_social}', 'tipo', true),
 ('contrato-social', 'Contrato social', '01', 20, 'contrato social|ato constitutivo|estatuto social', 'contrato[ _-]?social|estatuto', '{cnpj,razao_social,regime_tributario}', 'tipo', true),
 ('alteracao-contratual', 'Alteração contratual', '01', 15, 'altera[cç][aã]o (do )?contrat(o|ual)', 'altera[cç][aã]o', '{cnpj,razao_social}', 'numero', true),
 ('ata-socios', 'Ata de sócios', '01', 25, 'ata da (assembleia|reuni[aã]o) (geral|de s[oó]cios|de quotistas)', null, '{}', 'nenhuma', true),
 ('procuracao', 'Procuração', '01', 26, '\mprocura[cç][aã]o\M', 'procura[cç][aã]o', '{}', 'nenhuma', true),
 ('certidao', 'Certidão', '02', 30, 'certid[aã]o (negativa|positiva)', 'certid[aã]o', '{}', 'nenhuma', false),
 ('nota-fiscal', 'Nota fiscal', '02', 31, 'nota fiscal|\mnf-?e\M|\mnfs-?e\M|\mdanfe\M', '\mnf-?s?e?\M|nota[ _-]?fiscal', '{}', 'numero', false),
 ('manual-marca', 'Manual de marca', '04', 40, 'manual (de|da) (marca|identidade)|identidade visual', 'manual|brand|marca', '{}', 'tipo', false),
 ('logotipo', 'Logotipo', '04', 41, null, 'logo', '{}', 'nenhuma', false),
 ('fonte-tipografica', 'Fonte tipográfica', '04', 42, null, '\.(ttf|otf|woff2?)$', '{}', 'nenhuma', false),
 ('modelo-documento', 'Modelo de documento', '05', 50, '\mminuta\M|modelo de (contrato|proposta|of[ií]cio|termo)', 'minuta|modelo', '{}', 'nenhuma', false),
 ('contrato', 'Contrato', '06', 60, 'contrato de (presta[cç][aã]o|fornecimento|parceria|licen[cç]a)|\mcontratante\M.*\mcontratada\M', 'contrato', '{}', 'nenhuma', false),
 ('relatorio-prestacao', 'Relatório de prestação de contas', '07', 70, 'presta[cç][aã]o de contas|relat[oó]rio de (atividades|execu[cç][aã]o)', 'presta[cç][aã]o|relat[oó]rio', '{}', 'nenhuma', false),
 ('transcricao-reuniao', 'Transcrição ou ata de reunião', '09', 90, 'transcri[cç][aã]o|ata de reuni[aã]o', 'transcri|ata', '{}', 'nenhuma', false)
on conflict (id) do update set nome = excluded.nome, pasta = excluded.pasta, prioridade = excluded.prioridade, regra_texto = excluded.regra_texto,
  regra_nome = excluded.regra_nome, extrai = excluded.extrai, versao = excluded.versao, sensivel = excluded.sensivel;

-- onde cada pasta da árvore está no Drive, por empresa ('raiz' é a pasta da empresa)
create table if not exists acervo.pasta_drive (
  empresa uuid not null references org.empresa(id),
  pasta text not null,
  drive_id text not null,
  primary key (empresa, pasta)
);

create table if not exists acervo.arquivo (
  id bigint generated always as identity primary key,
  empresa uuid not null references org.empresa(id),
  contraparte uuid references ext.contraparte(id),
  tipo text references acervo.tipo(id),
  pasta text not null references acervo.pasta(codigo),
  nome_original text not null,
  nome text not null,
  hash text not null check (hash ~ '^[0-9a-f]{64}$'),
  mime text,
  tamanho bigint,
  origem text not null check (origem in ('upload', 'drive', 'telegram', 'portal')),
  drive_id text,
  situacao text not null check (situacao in ('entrada', 'triagem', 'organizado', 'substituido')),
  confianca numeric not null default 0,
  chave text,                         -- o que identifica a versão (número da nota, número da alteração)
  versao_de bigint references acervo.arquivo(id),
  enviado_por uuid,                   -- pessoa interna
  enviado_por_externo uuid,           -- usuário externo (parceiro ou cliente)
  motivo text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (empresa, hash)
);
create index if not exists arquivo_empresa_situacao on acervo.arquivo (empresa, situacao);
create index if not exists arquivo_versao on acervo.arquivo (empresa, tipo, chave) where situacao = 'organizado';

create table if not exists acervo.campo (
  id bigint generated always as identity primary key,
  empresa uuid not null references org.empresa(id),
  chave text not null check (chave in ('cnpj', 'razao_social', 'regime_tributario')),
  valor text not null,
  arquivo bigint not null references acervo.arquivo(id),
  trecho text,
  situacao text not null check (situacao in ('proposto', 'aprovado', 'recusado', 'divergente', 'substituido')),
  decisoes jsonb not null default '[]',
  criado_em timestamptz not null default now(),
  decidido_em timestamptz
);
create index if not exists campo_empresa on acervo.campo (empresa, chave, situacao);

create table if not exists acervo.divergencia (
  id bigint generated always as identity primary key,
  empresa uuid not null references org.empresa(id),
  chave text not null,
  valores jsonb not null,             -- [{valor, campo, arquivo, nome}]
  situacao text not null default 'aberta' check (situacao in ('aberta', 'resolvida')),
  valor_escolhido text,
  resolvido_por uuid,
  motivo text,
  criado_em timestamptz not null default now(),
  resolvido_em timestamptz
);
create unique index if not exists divergencia_aberta_unica on acervo.divergencia (empresa, chave) where situacao = 'aberta';

alter table acervo.pasta enable row level security; alter table acervo.tipo enable row level security; alter table acervo.pasta_drive enable row level security;
alter table acervo.arquivo enable row level security; alter table acervo.campo enable row level security; alter table acervo.divergencia enable row level security;
drop policy if exists leitura on acervo.pasta; create policy leitura on acervo.pasta for select to authenticated using (rt.interno());
drop policy if exists leitura on acervo.tipo; create policy leitura on acervo.tipo for select to authenticated using (rt.interno());
drop policy if exists leitura on acervo.arquivo; create policy leitura on acervo.arquivo for select to authenticated using (rt.eu() is not null and rt.pode(rt.eu(), empresa, null, 'ler'));
drop policy if exists leitura on acervo.campo; create policy leitura on acervo.campo for select to authenticated using (rt.eu() is not null and rt.pode(rt.eu(), empresa, null, 'ler'));
drop policy if exists leitura on acervo.divergencia; create policy leitura on acervo.divergencia for select to authenticated using (rt.eu() is not null and rt.pode(rt.eu(), empresa, null, 'ler'));
grant select on all tables in schema acervo to authenticated; grant all on all tables in schema acervo to service_role;

-- histórico: decisões do acervo entram no histórico da administração
alter table adm.historico drop constraint if exists historico_objeto_check;
alter table adm.historico add constraint historico_objeto_check
  check (objeto in ('parametro', 'conexao', 'agente', 'regra_externa', 'titulo_externo', 'tipo_documento', 'incidente', 'acervo', 'marca'));

-- quem age: pessoa do login; sem login, só o serviço, informando como quem atua (protótipo da página)
create or replace function acervo._quem(p_como uuid, p_empresa uuid, p_nivel text) returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then
    if not rt.chamada_servico() then raise exception 'sem identidade'; end if;
    v := p_como;
  end if;
  if v is null or not rt.pode(v, p_empresa, null, p_nivel) then raise exception 'sem acesso de % nesta empresa', p_nivel; end if;
  return v;
end $$;

-- CNPJ: só dígitos e dígitos verificadores conferidos
create or replace function acervo._cnpj_dv(p_base text) returns text language plpgsql immutable set search_path = '' as $$
declare d int[] := array[]::int[]; s int; i int; p1 int[] := '{5,4,3,2,9,8,7,6,5,4,3,2}'; p2 int[] := '{6,5,4,3,2,9,8,7,6,5,4,3,2}'; r int; dv1 int; dv2 int;
begin
  for i in 1..12 loop d := d || substr(p_base, i, 1)::int; end loop;
  s := 0; for i in 1..12 loop s := s + d[i] * p1[i]; end loop; r := s % 11; dv1 := case when r < 2 then 0 else 11 - r end;
  d := d || dv1;
  s := 0; for i in 1..13 loop s := s + d[i] * p2[i]; end loop; r := s % 11; dv2 := case when r < 2 then 0 else 11 - r end;
  return dv1::text || dv2::text;
end $$;
create or replace function acervo._cnpj_valido(p text) returns boolean language sql immutable set search_path = '' as $$
  select length(regexp_replace(coalesce(p, ''), '\D', '', 'g')) = 14
     and regexp_replace(p, '\D', '', 'g') !~ '^(\d)\1{13}$'
     and right(regexp_replace(p, '\D', '', 'g'), 2) = acervo._cnpj_dv(left(regexp_replace(p, '\D', '', 'g'), 12)) $$;
create or replace function acervo._cnpj_formatar(p text) returns text language sql immutable set search_path = '' as $$
  select regexp_replace(regexp_replace(p, '\D', '', 'g'), '^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$', '\1.\2.\3/\4-\5') $$;

-- extração: só o que o texto diz, com o trecho de onde veio
create or replace function acervo._extrair(p_texto text) returns jsonb language plpgsql immutable set search_path = '' as $$
declare t text := coalesce(p_texto, ''); r jsonb := '{}'; m text[]; v text;
begin
  -- CNPJ: o primeiro válido do documento
  for m in select regexp_matches(t, '(\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2})', 'g') loop
    if acervo._cnpj_valido(m[1]) then
      r := r || jsonb_build_object('cnpj', jsonb_build_object('valor', acervo._cnpj_formatar(m[1]), 'trecho', m[1])); exit;
    end if;
  end loop;
  m := regexp_match(t, '(?:raz[aã]o social|nome empresarial)\s*[:\-]?\s*([^\n\r]{3,150})', 'i');
  if m is not null then
    v := upper(btrim(regexp_replace(m[1], '\s+', ' ', 'g'), ' .,;:'));
    v := btrim(regexp_replace(v, '\s+(CNPJ|NOME DE FANTASIA|T[IÍ]TULO DO ESTABELECIMENTO|ENDERE[CÇ]O).*$', ''), ' .,;:');
    if length(v) >= 3 then r := r || jsonb_build_object('razao_social', jsonb_build_object('valor', v, 'trecho', left(m[1], 160))); end if;
  end if;
  m := regexp_match(t, '(simples nacional|lucro presumido|lucro real)', 'i');
  if m is not null then r := r || jsonb_build_object('regime_tributario', jsonb_build_object('valor', initcap(lower(m[1])), 'trecho', m[1])); end if;
  m := regexp_match(t, '(?:n[uú]mero|n[ºo°.]|nota fiscal n[ºo°.]?)\s*[:\-]?\s*(\d{1,9})', 'i');
  if m is not null then r := r || jsonb_build_object('numero', jsonb_build_object('valor', ltrim(m[1], '0'), 'trecho', m[1])); end if;
  m := regexp_match(t, '(?:valor total(?: da nota| do servi[cç]o| dos servi[cç]os)?|total a pagar|valor l[ií]quido)\s*[:\-]?\s*(?:R\$)?\s*([\d.]+,\d{2})', 'i');
  if m is not null then r := r || jsonb_build_object('valor_total', jsonb_build_object('valor', replace(replace(m[1], '.', ''), ',', '.'), 'trecho', m[1])); end if;
  return r;
end $$;

-- classificação: o tipo de maior prioridade cuja regra casa; texto vale mais que nome
create or replace function acervo._classificar(p_nome text, p_texto text) returns jsonb language plpgsql stable set search_path = '' as $$
declare t acervo.tipo;
begin
  for t in select * from acervo.tipo order by prioridade loop
    if t.regra_texto is not null and coalesce(p_texto, '') ~* t.regra_texto then return jsonb_build_object('tipo', t.id, 'confianca', 0.9, 'por', 'texto'); end if;
  end loop;
  for t in select * from acervo.tipo order by prioridade loop
    if t.regra_nome is not null and coalesce(p_nome, '') ~* t.regra_nome then return jsonb_build_object('tipo', t.id, 'confianca', 0.6, 'por', 'nome'); end if;
  end loop;
  return jsonb_build_object('tipo', null, 'confianca', 0, 'por', null);
end $$;

-- nome padronizado: tipo · empresa · data[ · nº chave].extensão
create or replace function acervo._nome(p_tipo text, p_empresa uuid, p_chave text, p_original text) returns text language sql stable set search_path = '' as $$
  select coalesce((select nome from acervo.tipo where id = p_tipo), 'Para triagem') || ' · ' ||
         coalesce((select nome from org.empresa where id = p_empresa), 'empresa') || ' · ' || to_char(now() at time zone 'America/Fortaleza', 'YYYY-MM-DD') ||
         coalesce(' · nº ' || p_chave, '') || coalesce('.' || nullif(lower(substring(p_original from '\.([A-Za-z0-9]{1,5})$')), ''), '') $$;

-- antes de subir ao Drive: o arquivo já existe nesta empresa?
create or replace function acervo.verificar(p_empresa uuid, p_hash text, p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare a acervo.arquivo;
begin
  perform acervo._quem(p_como, p_empresa, 'operar');
  select * into a from acervo.arquivo where empresa = p_empresa and hash = lower(p_hash);
  if a.id is null then return jsonb_build_object('duplicado', false); end if;
  return jsonb_build_object('duplicado', true, 'arquivo', a.id, 'nome', a.nome, 'pasta', a.pasta, 'drive_id', a.drive_id, 'situacao', a.situacao);
end $$;

-- núcleo do registro (interno e externo usam este)
create or replace function acervo._registrar(p_empresa uuid, p_nome text, p_hash text, p_mime text, p_tamanho bigint, p_texto text, p_origem text,
  p_drive_id text, p_contraparte uuid, p_por uuid, p_por_externo uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare c jsonb; tp acervo.tipo; x jsonb; v_chave text; v_ant acervo.arquivo; v_id bigint; v_sit text; k text; v_val text; v_campo bigint;
  v_aprov acervo.campo; outros jsonb; divs jsonb := '[]'; props jsonb := '[]'; dup acervo.arquivo;
begin
  if p_hash !~ '^[0-9a-fA-F]{64}$' then raise exception 'hash inválido'; end if;
  select * into dup from acervo.arquivo where empresa = p_empresa and hash = lower(p_hash);
  if dup.id is not null then
    return jsonb_build_object('situacao', 'duplicado', 'arquivo', dup.id, 'nome', dup.nome, 'pasta', dup.pasta, 'drive_id', dup.drive_id,
      'motivo', 'o mesmo arquivo já está no acervo desta empresa');
  end if;
  c := acervo._classificar(p_nome, p_texto);
  select * into tp from acervo.tipo where id = c->>'tipo';
  x := acervo._extrair(p_texto);
  if tp.versao = 'numero' then v_chave := x->'numero'->>'valor'; elsif tp.versao = 'tipo' then v_chave := tp.id; end if;
  v_sit := case when tp.id is null or (c->>'confianca')::numeric < 0.6 then 'triagem' else 'entrada' end;
  if v_chave is not null and tp.id is not null then
    select * into v_ant from acervo.arquivo where empresa = p_empresa and tipo = tp.id and chave = v_chave and situacao = 'organizado'
      and (p_contraparte is null or contraparte is not distinct from p_contraparte) order by id desc limit 1;
  end if;
  insert into acervo.arquivo (empresa, contraparte, tipo, pasta, nome_original, nome, hash, mime, tamanho, origem, drive_id, situacao, confianca, chave, versao_de,
                              enviado_por, enviado_por_externo, motivo)
  values (p_empresa, p_contraparte, tp.id, coalesce(tp.pasta, '99'), p_nome, acervo._nome(tp.id, p_empresa, case when tp.versao = 'numero' then v_chave end, p_nome),
          lower(p_hash), p_mime, p_tamanho, p_origem, p_drive_id, v_sit, (c->>'confianca')::numeric, v_chave, v_ant.id, p_por, p_por_externo,
          case when v_sit = 'triagem' then 'tipo não reconhecido com segurança' when c->>'por' = 'nome' then 'reconhecido só pelo nome: confira' end)
  returning id into v_id;
  -- campos da empresa: só de tipos que informam a identidade da empresa
  if tp.id is not null then
    foreach k in array tp.extrai loop
      v_val := x->k->>'valor';
      continue when v_val is null;
      select * into v_aprov from acervo.campo where empresa = p_empresa and chave = k and situacao = 'aprovado' order by id desc limit 1;
      if v_aprov.id is not null and v_aprov.valor = v_val then continue; end if;   -- confirma o que já vale: nada a decidir
      if exists (select 1 from acervo.campo where empresa = p_empresa and chave = k and valor = v_val and situacao in ('proposto', 'divergente')) then continue; end if;  -- mesmo valor já proposto
      insert into acervo.campo (empresa, chave, valor, arquivo, trecho, situacao)
      values (p_empresa, k, v_val, v_id, x->k->>'trecho', 'proposto') returning id into v_campo;
      props := props || jsonb_build_object('campo', v_campo, 'chave', k, 'valor', v_val);
      -- divergência: valores diferentes propostos ou aprovados para a mesma chave
      select jsonb_agg(jsonb_build_object('valor', f.valor, 'campo', f.id, 'arquivo', f.arquivo, 'nome', a.nome, 'situacao', f.situacao) order by f.id) into outros
        from acervo.campo f join acervo.arquivo a on a.id = f.arquivo
       where f.empresa = p_empresa and f.chave = k and f.situacao in ('proposto', 'aprovado', 'divergente');
      if (select count(distinct e->>'valor') from jsonb_array_elements(outros) e) > 1 then
        update acervo.campo set situacao = 'divergente' where empresa = p_empresa and chave = k and situacao = 'proposto';
        insert into acervo.divergencia (empresa, chave, valores) values (p_empresa, k, outros)
        on conflict (empresa, chave) where situacao = 'aberta' do update set valores = excluded.valores;
        divs := divs || jsonb_build_object('chave', k, 'valores', outros);
      end if;
    end loop;
  end if;
  return jsonb_build_object('situacao', v_sit, 'arquivo', v_id, 'tipo', tp.id, 'tipo_nome', tp.nome, 'pasta', coalesce(tp.pasta, '99'),
    'pasta_nome', (select nome from acervo.pasta where codigo = coalesce(tp.pasta, '99')),
    'nome', (select nome from acervo.arquivo where id = v_id), 'confianca', c->'confianca', 'reconhecido_por', c->'por',
    'versao_de', v_ant.id, 'versao_de_nome', v_ant.nome, 'extraido', x, 'campos_propostos', props, 'divergencias', divs);
end $$;

-- registro feito por quem é de dentro (upload na página, pasta conectada do Drive)
create or replace function acervo.registrar(p_empresa uuid, p_nome text, p_hash text, p_mime text, p_tamanho bigint, p_texto text, p_origem text,
  p_drive_id text default null, p_contraparte uuid default null, p_como uuid default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := acervo._quem(p_como, p_empresa, 'operar');
begin
  if p_origem not in ('upload', 'drive') then raise exception 'origem inválida para registro interno'; end if;
  if p_contraparte is not null and (select empresa from ext.contraparte where id = p_contraparte) is distinct from p_empresa then
    raise exception 'contraparte de outra empresa'; end if;
  return acervo._registrar(p_empresa, p_nome, p_hash, p_mime, p_tamanho, p_texto, p_origem, p_drive_id, p_contraparte, v, null);
end $$;

-- depois que a página moveu o arquivo para a pasta de destino no Drive: confirma o lugar e fecha a versão anterior
create or replace function acervo.confirmar_local(p_arquivo bigint, p_drive_id text, p_como uuid default null) returns void language plpgsql security definer set search_path = '' as $$
declare a acervo.arquivo;
begin
  select * into a from acervo.arquivo where id = p_arquivo for update;
  if a.id is null then raise exception 'arquivo inexistente'; end if;
  perform acervo._quem(p_como, a.empresa, 'operar');
  if a.situacao not in ('entrada') then raise exception 'arquivo em situação % não se organiza', a.situacao; end if;
  update acervo.arquivo set situacao = 'organizado', drive_id = coalesce(p_drive_id, drive_id), atualizado_em = now() where id = a.id;
  if a.versao_de is not null then
    update acervo.arquivo set situacao = 'substituido', atualizado_em = now(), motivo = 'substituído pela versão ' || a.id where id = a.versao_de and situacao = 'organizado';
  end if;
end $$;

-- triagem: uma pessoa escolhe o tipo; devolve pasta e nome novos para a página mover o arquivo
create or replace function acervo.classificar(p_arquivo bigint, p_tipo text, p_chave text default null, p_como uuid default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare a acervo.arquivo; tp acervo.tipo; v uuid; v_ant bigint;
begin
  select * into a from acervo.arquivo where id = p_arquivo for update;
  if a.id is null then raise exception 'arquivo inexistente'; end if;
  v := acervo._quem(p_como, a.empresa, 'operar');
  select * into tp from acervo.tipo where id = p_tipo; if tp.id is null then raise exception 'tipo inexistente'; end if;
  if a.situacao not in ('triagem', 'entrada') then raise exception 'só se classifica arquivo em triagem ou na entrada'; end if;
  if tp.versao = 'numero' and coalesce(p_chave, a.chave) is null then raise exception 'informe o número deste documento'; end if;
  select id into v_ant from acervo.arquivo where empresa = a.empresa and tipo = tp.id and chave = coalesce(p_chave, case when tp.versao = 'tipo' then tp.id else a.chave end)
     and situacao = 'organizado' and id <> a.id order by id desc limit 1;
  update acervo.arquivo set tipo = tp.id, pasta = tp.pasta, situacao = 'entrada', confianca = 1, versao_de = v_ant,
         chave = case when tp.versao = 'tipo' then tp.id when tp.versao = 'numero' then coalesce(p_chave, a.chave) end,
         nome = acervo._nome(tp.id, a.empresa, case when tp.versao = 'numero' then coalesce(p_chave, a.chave) end, a.nome_original),
         motivo = 'classificado por pessoa', atualizado_em = now()
   where id = a.id;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('acervo', 'arquivo ' || a.id, jsonb_build_object('tipo', a.tipo, 'pasta', a.pasta), jsonb_build_object('tipo', tp.id, 'pasta', tp.pasta), v, 'triagem do acervo', 'classificação manual');
  return (select jsonb_build_object('arquivo', id, 'pasta', pasta, 'pasta_nome', (select nome from acervo.pasta where codigo = arquivo.pasta), 'nome', nome, 'versao_de', versao_de)
            from acervo.arquivo arquivo where id = a.id);
end $$;

-- dado da empresa: sensível (CNPJ, razão social) precisa de duas pessoas diferentes; o aprovado vai para org.empresa
create or replace function acervo.decidir_campo(p_campo bigint, p_decisao text, p_motivo text, p_como uuid default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare f acervo.campo; v uuid; n int; precisa int;
begin
  select * into f from acervo.campo where id = p_campo for update;
  if f.id is null then raise exception 'campo inexistente'; end if;
  v := acervo._quem(p_como, f.empresa, 'aprovar');
  if p_decisao not in ('aprovado', 'recusado') then raise exception 'decisão inválida'; end if;
  if f.situacao <> 'proposto' then raise exception 'campo em situação % não recebe decisão', f.situacao; end if;
  if coalesce(length(btrim(p_motivo)), 0) = 0 and p_decisao = 'recusado' then raise exception 'recusa exige motivo'; end if;
  if exists (select 1 from jsonb_array_elements(f.decisoes) d where (d->>'por')::uuid = v) then raise exception 'a mesma pessoa não decide duas vezes'; end if;
  update acervo.campo set decisoes = decisoes || jsonb_build_object('por', v, 'decisao', p_decisao, 'motivo', p_motivo, 'em', now()) where id = f.id;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('acervo', f.chave || ' · campo ' || f.id, jsonb_build_object('valor', (select valor from acervo.campo where empresa = f.empresa and chave = f.chave and situacao = 'aprovado' order by id desc limit 1)),
          jsonb_build_object('valor', f.valor, 'decisao', p_decisao), v, 'acervo: dado da empresa', p_motivo);
  if p_decisao = 'recusado' then
    update acervo.campo set situacao = 'recusado', decidido_em = now() where id = f.id;
    return jsonb_build_object('situacao', 'recusado');
  end if;
  precisa := case when f.chave in ('cnpj', 'razao_social') then 2 else 1 end;
  select count(*) into n from acervo.campo c, jsonb_array_elements(c.decisoes) d where c.id = f.id and d->>'decisao' = 'aprovado';
  if n < precisa then return jsonb_build_object('situacao', 'proposto', 'aprovacoes', n, 'faltam', precisa - n); end if;
  update acervo.campo set situacao = 'substituido' where empresa = f.empresa and chave = f.chave and situacao = 'aprovado';
  update acervo.campo set situacao = 'aprovado', decidido_em = now() where id = f.id;
  execute format('update org.empresa set %I = $1 where id = $2', f.chave) using f.valor, f.empresa;
  return jsonb_build_object('situacao', 'aprovado', 'aplicado_em', 'org.empresa.' || f.chave);
end $$;

-- divergência: quem aprova escolhe o valor (com motivo); o escolhido volta a proposto e segue as duas mãos; os outros saem
create or replace function acervo.resolver_divergencia(p_divergencia bigint, p_campo bigint, p_motivo text, p_como uuid default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare d acervo.divergencia; f acervo.campo; v uuid;
begin
  select * into d from acervo.divergencia where id = p_divergencia for update;
  if d.id is null or d.situacao <> 'aberta' then raise exception 'divergência inexistente ou já resolvida'; end if;
  v := acervo._quem(p_como, d.empresa, 'aprovar');
  if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'informe por que este valor vale'; end if;
  select * into f from acervo.campo where id = p_campo and empresa = d.empresa and chave = d.chave;
  if f.id is null then raise exception 'o valor escolhido não é desta divergência'; end if;
  update acervo.campo set situacao = 'recusado', decidido_em = now() where empresa = d.empresa and chave = d.chave and situacao in ('proposto', 'divergente') and id <> f.id;
  if f.situacao in ('divergente', 'proposto') then update acervo.campo set situacao = 'proposto' where id = f.id; end if;
  update acervo.divergencia set situacao = 'resolvida', valor_escolhido = f.valor, resolvido_por = v, motivo = p_motivo, resolvido_em = now() where id = d.id;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('acervo', d.chave || ' · divergência ' || d.id, d.valores, jsonb_build_object('valor', f.valor), v, 'acervo: divergência', p_motivo);
  return jsonb_build_object('situacao', 'resolvida', 'campo', f.id, 'proximo', case when f.situacao = 'aprovado' then 'já vale' else 'aprovar o campo (duas mãos se sensível)' end);
end $$;

-- pastas do Drive: a página cria a pasta que faltar e registra aqui
create or replace function acervo.pasta_registrar(p_empresa uuid, p_pasta text, p_drive_id text, p_como uuid default null) returns void language plpgsql security definer set search_path = '' as $$
begin
  perform acervo._quem(p_como, p_empresa, 'operar');
  if p_pasta <> 'raiz' and not exists (select 1 from acervo.pasta where codigo = p_pasta) then raise exception 'pasta fora da árvore padrão'; end if;
  insert into acervo.pasta_drive (empresa, pasta, drive_id) values (p_empresa, p_pasta, p_drive_id)
  on conflict (empresa, pasta) do update set drive_id = excluded.drive_id;
end $$;

create or replace function acervo.painel(p_empresa uuid, p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform acervo._quem(p_como, p_empresa, 'ler');
  return jsonb_build_object(
    'empresa', (select jsonb_build_object('id', id, 'nome', nome, 'cnpj', cnpj, 'razao_social', razao_social, 'regime_tributario', regime_tributario, 'simulado', simulado) from org.empresa where id = p_empresa),
    'pastas', (select jsonb_agg(jsonb_build_object('codigo', p.codigo, 'nome', p.nome, 'descricao', p.descricao, 'drive_id', d.drive_id,
                 'arquivos', (select count(*) from acervo.arquivo a where a.empresa = p_empresa and a.pasta = p.codigo and a.situacao = 'organizado')) order by p.ordem)
                 from acervo.pasta p left join acervo.pasta_drive d on d.empresa = p_empresa and d.pasta = p.codigo),
    'raiz', (select drive_id from acervo.pasta_drive where empresa = p_empresa and pasta = 'raiz'),
    'tipos', (select jsonb_agg(jsonb_build_object('id', id, 'nome', nome, 'pasta', pasta, 'versao', versao, 'sensivel', sensivel) order by prioridade) from acervo.tipo),
    'arquivos', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'nome', a.nome, 'original', a.nome_original, 'tipo', t.nome, 'pasta', a.pasta, 'situacao', a.situacao,
                   'origem', a.origem, 'drive_id', a.drive_id, 'versao_de', a.versao_de, 'chave', a.chave, 'confianca', a.confianca, 'motivo', a.motivo, 'em', a.criado_em,
                   'externo', a.enviado_por_externo is not null) order by a.id desc), '[]')
                 from (select * from acervo.arquivo where empresa = p_empresa order by id desc limit 80) a left join acervo.tipo t on t.id = a.tipo),
    'campos', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'chave', f.chave, 'valor', f.valor, 'situacao', f.situacao, 'arquivo', f.arquivo,
                   'arquivo_nome', a.nome, 'trecho', f.trecho, 'aprovacoes', (select count(*) from jsonb_array_elements(f.decisoes) d where d->>'decisao' = 'aprovado'),
                   'precisa', case when f.chave in ('cnpj', 'razao_social') then 2 else 1 end, 'decisoes', f.decisoes) order by f.id desc), '[]')
                 from acervo.campo f join acervo.arquivo a on a.id = f.arquivo where f.empresa = p_empresa and f.situacao in ('proposto', 'divergente', 'aprovado')),
    'divergencias', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'chave', chave, 'valores', valores, 'criado_em', criado_em) order by id), '[]')
                 from acervo.divergencia where empresa = p_empresa and situacao = 'aberta'),
    'resumo', jsonb_build_object(
      'organizados', (select count(*) from acervo.arquivo where empresa = p_empresa and situacao = 'organizado'),
      'triagem', (select count(*) from acervo.arquivo where empresa = p_empresa and situacao = 'triagem'),
      'entrada', (select count(*) from acervo.arquivo where empresa = p_empresa and situacao = 'entrada'),
      'substituidos', (select count(*) from acervo.arquivo where empresa = p_empresa and situacao = 'substituido'),
      'campos_pendentes', (select count(*) from acervo.campo where empresa = p_empresa and situacao = 'proposto'),
      'divergencias', (select count(*) from acervo.divergencia where empresa = p_empresa and situacao = 'aberta')));
end $$;

-- para a página escolher a empresa e quem atua (protótipo)
create or replace function acervo.contexto() returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'empresas', (select jsonb_agg(jsonb_build_object('id', id, 'nome', nome, 'simulado', simulado) order by nome) from org.empresa where ativa),
    'pessoas', (select jsonb_agg(jsonb_build_object('pessoa', a.pessoa, 'papel', p.papel, 'nivel', a.nivel) order by a.nivel desc, p.papel)
                  from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa where a.nivel in ('aprovar', 'administrar') and a.circulo is null)) $$;

revoke all on all functions in schema acervo from public, anon, authenticated;
grant execute on all functions in schema acervo to service_role;
grant execute on function acervo.verificar(uuid, text, uuid), acervo.registrar(uuid, text, text, text, bigint, text, text, text, uuid, uuid),
  acervo.confirmar_local(bigint, text, uuid), acervo.classificar(bigint, text, text, uuid), acervo.decidir_campo(bigint, text, text, uuid),
  acervo.resolver_divergencia(bigint, bigint, text, uuid), acervo.pasta_registrar(uuid, text, text, uuid), acervo.painel(uuid, uuid) to authenticated;
commit;
