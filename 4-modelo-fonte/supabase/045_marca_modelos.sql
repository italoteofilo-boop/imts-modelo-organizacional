-- E18 Marca e modelos a partir das pastas. O manual de marca que entra no acervo vira proposta de pacote de marca (cores e
-- tipografia lidas do texto; os papéis de cada cor são escolhidos por quem aprova, em duas mãos). O modelo de documento vira
-- minuta em blocos do motor documental; aprovada, a minuta emite documento pelo motor. O banco passa a ser a fonte do pacote de
-- marca: o worker recebe os dados aprovados e o motor usa esses dados no lugar do arquivo de semente.
begin;
create table if not exists doc.marca_proposta (
  id bigint generated always as identity primary key,
  marca text not null references doc.marca(id),
  empresa uuid not null references org.empresa(id),
  arquivo bigint not null references acervo.arquivo(id),
  cores text[] not null default '{}',
  fontes text[] not null default '{}',
  papeis jsonb,                        -- {"primaria": "#...", ...} escolhidos na primeira aprovação
  tipografia jsonb,                    -- {"texto": "...", "display": "..."}
  situacao text not null default 'proposta' check (situacao in ('proposta', 'aprovada', 'recusada')),
  decisoes jsonb not null default '[]',
  criado_em timestamptz not null default now(),
  decidido_em timestamptz
);
create table if not exists doc.minuta (
  id bigint generated always as identity primary key,
  empresa uuid not null references org.empresa(id),
  tipo text references doc.tipo(id),
  arquivo bigint not null references acervo.arquivo(id),
  titulo text not null,
  blocos jsonb not null,
  situacao text not null default 'proposta' check (situacao in ('proposta', 'aprovada', 'recusada', 'substituida')),
  substitui bigint references doc.minuta(id),
  decisoes jsonb not null default '[]',
  criado_em timestamptz not null default now(),
  decidido_em timestamptz
);
create index if not exists minuta_vigente on doc.minuta (empresa, tipo) where situacao = 'aprovada';
alter table doc.marca_proposta enable row level security; alter table doc.minuta enable row level security;
drop policy if exists leitura on doc.marca_proposta; create policy leitura on doc.marca_proposta for select to authenticated using (rt.eu() is not null and rt.pode(rt.eu(), empresa, null, 'ler'));
drop policy if exists leitura on doc.minuta; create policy leitura on doc.minuta for select to authenticated using (rt.eu() is not null and rt.pode(rt.eu(), empresa, null, 'ler'));
grant select on doc.marca_proposta, doc.minuta to authenticated; grant all on doc.marca_proposta, doc.minuta to service_role;

-- mudança no pacote de marca entra no histórico, como as outras regras
drop trigger if exists historico on doc.marca;
create trigger historico after insert or update or delete on doc.marca for each row execute function adm._historico_regra('marca', '{atualizado_em}');

-- texto do modelo em blocos do motor: cláusula vira seção, "1.1" vira item, "a)" vira alínea, o resto vira parágrafo
create or replace function doc._texto_em_blocos(p_texto text) returns jsonb language plpgsql immutable set search_path = '' as $$
declare l text; r jsonb := '[]'; m text[];
begin
  foreach l in array regexp_split_to_array(coalesce(p_texto, ''), E'\\r?\\n') loop
    l := btrim(regexp_replace(l, '\s+', ' ', 'g'));
    continue when l = '';
    if l ~* '^(cl[áa]usula|anexo|cap[íi]tulo|se[çc][ãa]o)\s+\S+' then r := r || jsonb_build_object('t', 'secao', 'titulo', l);
    else
      m := regexp_match(l, '^(\d+(?:\.\d+)+)\.?\s+(.+)$');
      if m is not null then r := r || jsonb_build_object('t', 'item', 'n', m[1], 'texto', m[2]);
      else
        m := regexp_match(l, '^([a-z])\)\s+(.+)$');
        if m is not null then r := r || jsonb_build_object('t', 'alinea', 'm', m[1] || ')', 'texto', m[2]);
        else r := r || jsonb_build_object('t', 'p', 'texto', l); end if;
      end if;
    end if;
  end loop;
  return r;
end $$;

-- o que o arquivo do acervo gera além do registro: proposta de marca ou minuta
create or replace function acervo._derivar(p_arquivo bigint, p_texto text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare a acervo.arquivo; v_marca text; v_cores text[]; v_fontes text[]; v_tipo text; v_tit text; v_id bigint; t record;
begin
  select * into a from acervo.arquivo where id = p_arquivo;
  if a.tipo = 'manual-marca' then
    select marca into v_marca from ext.empresa_marca where empresa = a.empresa;
    if v_marca is null or v_marca = 'neutra' then return jsonb_build_object('marca', 'sem pacote próprio para esta empresa'); end if;
    select coalesce(array_agg(distinct upper('#' || m[1])), '{}') into v_cores from regexp_matches(coalesce(p_texto, ''), '#([0-9A-Fa-f]{6})\M', 'g') m;
    select coalesce(array_agg(distinct btrim(m[1])), '{}') into v_fontes
      from regexp_matches(coalesce(p_texto, ''), '(?:tipografia|fonte|fam[íi]lia tipogr[áa]fica)(?:\s+(?:principal|secund[áa]ria|de apoio|de texto|de t[íi]tulos|institucional))?\s*[:\-]\s*([A-Z][A-Za-z0-9 ]{1,30}?)(?=[\n\r,.;(]|$)', 'gi') m;
    insert into doc.marca_proposta (marca, empresa, arquivo, cores, fontes) values (v_marca, a.empresa, a.id, v_cores, v_fontes) returning id into v_id;
    return jsonb_build_object('proposta_marca', v_id, 'cores', v_cores, 'fontes', v_fontes);
  elsif a.tipo = 'modelo-documento' then
    v_tit := coalesce(nullif(btrim((regexp_match(coalesce(p_texto, ''), '^\s*([^\n\r]{3,120})'))[1]), ''), a.nome_original);
    -- tipo de documento sugerido pelo título (as regras do catálogo são escritas sem acento); quem aprova confirma ou troca
    for t in select id, regra from doc.tipo where regra is not null order by length(regra) desc loop
      begin
        if translate(lower(v_tit), 'áàâãéêíóôõúüç', 'aaaaeeiooouuc') ~ t.regra then v_tipo := t.id; exit; end if;
      exception when others then null;
      end;
    end loop;
    insert into doc.minuta (empresa, tipo, arquivo, titulo, blocos) values (a.empresa, v_tipo, a.id, v_tit, doc._texto_em_blocos(p_texto)) returning id into v_id;
    return jsonb_build_object('minuta', v_id, 'tipo_documento', v_tipo, 'blocos', (select jsonb_array_length(blocos) from doc.minuta where id = v_id));
  end if;
  return '{}';
end $$;

-- o registro do acervo chama a derivação ao final
create or replace function acervo._registrar_e_derivar(p_r jsonb, p_texto text) returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_r->>'situacao' in ('entrada', 'triagem') and p_r->>'tipo' in ('manual-marca', 'modelo-documento') then
    return p_r || jsonb_build_object('derivado', acervo._derivar((p_r->>'arquivo')::bigint, p_texto));
  end if;
  return p_r;
end $$;
create or replace function acervo.registrar(p_empresa uuid, p_nome text, p_hash text, p_mime text, p_tamanho bigint, p_texto text, p_origem text,
  p_drive_id text default null, p_contraparte uuid default null, p_como uuid default null) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := acervo._quem(p_como, p_empresa, 'operar');
begin
  if p_origem not in ('upload', 'drive') then raise exception 'origem inválida para registro interno'; end if;
  if p_contraparte is not null and (select empresa from ext.contraparte where id = p_contraparte) is distinct from p_empresa then
    raise exception 'contraparte de outra empresa'; end if;
  return acervo._registrar_e_derivar(acervo._registrar(p_empresa, p_nome, p_hash, p_mime, p_tamanho, p_texto, p_origem, p_drive_id, p_contraparte, v, null), p_texto);
end $$;

-- marca em duas mãos: a primeira pessoa escolhe os papéis das cores e a tipografia; a segunda confere e aprova o mesmo
create or replace function doc.decidir_marca(p_proposta bigint, p_decisao text, p_papeis jsonb, p_tipografia jsonb, p_motivo text, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare pr doc.marca_proposta; v uuid; k text; n int; antes jsonb;
begin
  select * into pr from doc.marca_proposta where id = p_proposta for update;
  if pr.id is null then raise exception 'proposta inexistente'; end if;
  v := acervo._quem(p_como, pr.empresa, 'aprovar');
  if pr.situacao <> 'proposta' then raise exception 'proposta em situação % não recebe decisão', pr.situacao; end if;
  if p_decisao not in ('aprovado', 'recusado') then raise exception 'decisão inválida'; end if;
  if exists (select 1 from jsonb_array_elements(pr.decisoes) d where (d->>'por')::uuid = v) then raise exception 'a mesma pessoa não decide duas vezes'; end if;
  if p_decisao = 'recusado' then
    if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'recusa exige motivo'; end if;
    update doc.marca_proposta set situacao = 'recusada', decidido_em = now(), decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'recusado', 'motivo', p_motivo, 'em', now()) where id = pr.id;
    return jsonb_build_object('situacao', 'recusada');
  end if;
  for k in select jsonb_object_keys(coalesce(p_papeis, '{}')) loop
    if k not in ('primaria', 'texto', 'fundo', 'destaque', 'apoio', 'apoio2', 'claro', 'barra', 'linha') then raise exception 'papel de cor desconhecido: %', k; end if;
    if (p_papeis->>k) !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'cor inválida em %', k; end if;
  end loop;
  if jsonb_array_length(pr.decisoes) = 0 then
    if coalesce(p_papeis, '{}') = '{}' and coalesce(p_tipografia, '{}') = '{}' then raise exception 'escolha ao menos um papel de cor ou a tipografia'; end if;
    update doc.marca_proposta set papeis = p_papeis, tipografia = p_tipografia,
           decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'aprovado', 'motivo', p_motivo, 'em', now()) where id = pr.id;
    return jsonb_build_object('situacao', 'proposta', 'aprovacoes', 1, 'faltam', 1);
  end if;
  if coalesce(p_papeis, pr.papeis) is distinct from pr.papeis or coalesce(p_tipografia, pr.tipografia) is distinct from pr.tipografia then
    raise exception 'a segunda aprovação confere o que a primeira escolheu; para mudar, recuse com motivo';
  end if;
  select dados into antes from doc.marca where id = pr.marca;
  update doc.marca set dados = dados
      || jsonb_build_object('cores', coalesce(dados->'cores', '{}') || coalesce(pr.papeis, '{}'))
      || jsonb_build_object('tipografia', coalesce(dados->'tipografia', '{}') || coalesce(pr.tipografia, '{}'))
      || jsonb_build_object('fonte', 'manual de marca do acervo (arquivo ' || pr.arquivo || '), aprovado em ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM/YYYY'))
     , atualizado_em = now()
   where id = pr.marca;
  update doc.marca_proposta set situacao = 'aprovada', decidido_em = now(), decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'aprovado', 'motivo', p_motivo, 'em', now()) where id = pr.id;
  return jsonb_build_object('situacao', 'aprovada', 'marca', pr.marca);
end $$;

-- minuta: quem subiu o modelo não aprova; aprovada, substitui a anterior do mesmo tipo na empresa
create or replace function doc.decidir_minuta(p_minuta bigint, p_decisao text, p_tipo text, p_motivo text, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare mi doc.minuta; v uuid; v_tipo text; v_ant bigint;
begin
  select * into mi from doc.minuta where id = p_minuta for update;
  if mi.id is null then raise exception 'minuta inexistente'; end if;
  v := acervo._quem(p_como, mi.empresa, 'aprovar');
  if mi.situacao <> 'proposta' then raise exception 'minuta em situação % não recebe decisão', mi.situacao; end if;
  if (select enviado_por from acervo.arquivo where id = mi.arquivo) = v then raise exception 'quem subiu o modelo não aprova a minuta'; end if;
  if p_decisao = 'recusado' then
    if coalesce(length(btrim(p_motivo)), 0) = 0 then raise exception 'recusa exige motivo'; end if;
    update doc.minuta set situacao = 'recusada', decidido_em = now(), decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'recusado', 'motivo', p_motivo, 'em', now()) where id = mi.id;
    return jsonb_build_object('situacao', 'recusada');
  end if;
  if p_decisao <> 'aprovado' then raise exception 'decisão inválida'; end if;
  v_tipo := coalesce(p_tipo, mi.tipo);
  if v_tipo is null or not exists (select 1 from doc.tipo where id = v_tipo) then raise exception 'escolha o tipo de documento da minuta'; end if;
  select id into v_ant from doc.minuta where empresa = mi.empresa and tipo = v_tipo and situacao = 'aprovada' and id <> mi.id order by id desc limit 1;
  update doc.minuta set situacao = 'substituida' where id = v_ant;
  update doc.minuta set situacao = 'aprovada', tipo = v_tipo, substitui = v_ant, decidido_em = now(),
         decisoes = decisoes || jsonb_build_object('por', v, 'decisao', 'aprovado', 'motivo', p_motivo, 'em', now()) where id = mi.id;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('acervo', 'minuta ' || mi.id, case when v_ant is not null then jsonb_build_object('minuta', v_ant) end, jsonb_build_object('minuta', mi.id, 'tipo', v_tipo), v, 'modelos de documento', p_motivo);
  return jsonb_build_object('situacao', 'aprovada', 'substitui', v_ant);
end $$;

-- emitir pelo motor a partir de uma minuta aprovada (vai para a fila do worker, com as duas mãos de sempre depois da emissão)
create or replace function doc.pedir_minuta(p_minuta bigint, p_titulo text, p_data date, p_local text, p_como uuid default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare mi doc.minuta; v uuid; v_marca text; v_ped bigint;
begin
  select * into mi from doc.minuta where id = p_minuta;
  if mi.id is null then raise exception 'minuta inexistente'; end if;
  v := acervo._quem(p_como, mi.empresa, 'operar');
  if mi.situacao <> 'aprovada' then raise exception 'só minuta aprovada emite documento'; end if;
  select marca into v_marca from ext.empresa_marca where empresa = mi.empresa;
  v_ped := doc.pedir(mi.tipo, coalesce(v_marca, 'neutra'), jsonb_build_object('titulo', coalesce(nullif(btrim(p_titulo), ''), mi.titulo), 'data', to_char(p_data, 'YYYY-MM-DD'),
             'local', p_local, 'blocos', mi.blocos), mi.empresa);
  perform doc._evento(v_ped, 'pedido_pela_minuta', jsonb_build_object('minuta', mi.id, 'por', v));
  return v_ped;
end $$;

-- o worker recebe o pacote de marca aprovado no banco
create or replace function doc.worker_proximo(p_chave text, p_worker text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v doc.pedido;
begin
  if not doc._chave_ok(p_chave) then raise exception 'não autorizado'; end if;
  update doc.pedido set situacao = 'em_emissao', worker = p_worker, atualizado_em = now()
   where id = (select id from doc.pedido where situacao = 'na_fila' order by criado_em for update skip locked limit 1)
  returning * into v;
  if v.id is null then return null; end if;
  perform doc._evento(v.id, 'em_emissao', jsonb_build_object('worker', p_worker));
  return (v.conteudo - 'modelo' - 'id' - 'tipo' - 'marca' - '_marca_dados') || jsonb_build_object('id', 'pedido-' || v.id, 'tipo', v.tipo, 'marca', v.marca, 'pedido', v.id,
         'modelo', coalesce(v.modelo, (select modelo from doc.tipo where id = v.tipo)), '_marca_dados', (select dados from doc.marca where id = v.marca));
end $$;

-- dado da empresa aprovado no acervo também vale no pacote de marca próprio da empresa
create or replace function acervo._marca_da_empresa() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_marca text;
begin
  select marca into v_marca from ext.empresa_marca where empresa = new.id;
  if v_marca is null or v_marca = 'neutra' then return new; end if;
  if new.cnpj is distinct from old.cnpj then
    update doc.marca set dados = jsonb_set(dados, '{cnpj}', to_jsonb(new.cnpj))
      || jsonb_build_object('inferencias', coalesce((select jsonb_agg(e) from jsonb_array_elements(dados->'inferencias') e where e::text !~* 'cnpj'), '[]')), atualizado_em = now()
     where id = v_marca;
  end if;
  if new.razao_social is distinct from old.razao_social then
    update doc.marca set dados = jsonb_set(dados, '{razao_social}', to_jsonb(new.razao_social))
      || jsonb_build_object('inferencias', coalesce((select jsonb_agg(e) from jsonb_array_elements(dados->'inferencias') e where e::text !~* 'raz[ãa]o social'), '[]')), atualizado_em = now()
     where id = v_marca;
  end if;
  return new;
end $$;
drop trigger if exists marca_da_empresa on org.empresa;
create trigger marca_da_empresa after update of cnpj, razao_social on org.empresa for each row execute function acervo._marca_da_empresa();

-- painel: o que a página de marca e modelos precisa
create or replace function doc.painel_marca_modelos(p_empresa uuid, p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_marca text;
begin
  perform acervo._quem(p_como, p_empresa, 'ler');
  select marca into v_marca from ext.empresa_marca where empresa = p_empresa;
  return jsonb_build_object(
    'marca', (select jsonb_build_object('id', id, 'nome', nome, 'situacao', situacao, 'cores', dados->'cores', 'tipografia', dados->'tipografia', 'fonte', dados->'fonte',
               'razao_social', dados->'razao_social', 'cnpj', dados->'cnpj', 'inferencias', dados->'inferencias') from doc.marca where id = v_marca),
    'propostas', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'cores', p.cores, 'fontes', p.fontes, 'papeis', p.papeis, 'tipografia', p.tipografia, 'situacao', p.situacao,
                   'decisoes', p.decisoes, 'arquivo', a.nome, 'drive_id', a.drive_id, 'em', p.criado_em) order by p.id desc), '[]')
                   from doc.marca_proposta p join acervo.arquivo a on a.id = p.arquivo where p.empresa = p_empresa and p.situacao = 'proposta'),
    'minutas', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'tipo', m.tipo, 'tipo_nome', t.nome, 'titulo', m.titulo, 'situacao', m.situacao, 'blocos', m.blocos,
                   'anterior', (select blocos from doc.minuta x where x.empresa = m.empresa and x.tipo = m.tipo and x.situacao = 'aprovada' and x.id <> m.id order by x.id desc limit 1),
                   'arquivo', a.nome, 'drive_id', a.drive_id, 'decisoes', m.decisoes, 'em', m.criado_em) order by m.id desc), '[]')
                   from doc.minuta m join acervo.arquivo a on a.id = m.arquivo left join doc.tipo t on t.id = m.tipo where m.empresa = p_empresa and m.situacao in ('proposta', 'aprovada')),
    'tipos_documento', (select jsonb_agg(jsonb_build_object('id', id, 'nome', nome) order by nome) from doc.tipo));
end $$;

revoke all on function doc._texto_em_blocos(text), acervo._derivar(bigint, text), acervo._registrar_e_derivar(jsonb, text), doc.decidir_marca(bigint, text, jsonb, jsonb, text, uuid),
  doc.decidir_minuta(bigint, text, text, text, uuid), doc.pedir_minuta(bigint, text, date, text, uuid), doc.painel_marca_modelos(uuid, uuid), acervo._marca_da_empresa() from public, anon;
grant execute on function doc.decidir_marca(bigint, text, jsonb, jsonb, text, uuid), doc.decidir_minuta(bigint, text, text, text, uuid), doc.pedir_minuta(bigint, text, date, text, uuid),
  doc.painel_marca_modelos(uuid, uuid) to authenticated, service_role;
grant execute on function doc._texto_em_blocos(text), acervo._derivar(bigint, text), acervo._registrar_e_derivar(jsonb, text) to service_role;
commit;
