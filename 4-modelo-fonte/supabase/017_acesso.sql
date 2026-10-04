-- Acesso, permissões, multiempresa e direitos do titular (aprovado em 03/10/2026, às 21:05). Depende de 003 a 016.
-- 1. Empresas: estrutura multiempresa, com quatro empresas simuladas até o gate G1 trazer as reais.
-- 2. Login: a conta do Supabase Auth liga-se ao pseudônimo por uma tabela separada (rt_chave), como a identidade (LGPD, art. 13, § 4º).
-- 3. Permissões: pessoa × empresa × círculo × papel × nível (ler, operar, aprovar, administrar), com papéis incompatíveis barrados (D3: quem prepara não aprova).
-- 4. Aplicação: funções para quem está logado (rt.app_*), que usam a pessoa do login e não a que a tela manda.
-- 5. Direitos do titular (LGPD, art. 18): exportar tudo de uma pessoa (II e V) e eliminar o vínculo com a identidade, anonimizando o que fica (IV e VI).
begin;

-- 0. No Postgres local não há Supabase Auth: cria-se só o necessário para testar (no Supabase, auth.uid() já existe)
do $$ begin
  if to_regprocedure('auth.uid()') is null then
    create schema if not exists auth;
    execute $f$create function auth.uid() returns uuid language sql stable as
      $b$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $b$ $f$;
  end if;
end $$;

-- 1. Empresas -----------------------------------------------------------------------------------------
alter table org.empresa add column if not exists simulado boolean not null default false;
alter table org.empresa add column if not exists ativa boolean not null default true;
insert into org.empresa (nome, simulado) values
  ('Holding (simulada)', true), ('Empresa de educação (simulada)', true), ('Empresa de saúde (simulada)', true), ('Empresa de crédito (simulada)', true)
on conflict (nome) do nothing;

-- 2. Login --------------------------------------------------------------------------------------------
create table if not exists rt_chave.login (
  auth_uid   uuid primary key,
  pseudonimo uuid not null unique references rt.pessoa(pseudonimo),
  criado_em  timestamptz not null default now()
);
alter table rt_chave.login enable row level security;
revoke all on rt_chave.login from anon, authenticated;

-- A pessoa de quem está logado (nula se o login não estiver ligado a ninguém)
create or replace function rt.eu() returns uuid language sql stable security definer set search_path = '' as $$
  select pseudonimo from rt_chave.login where auth_uid = auth.uid() $$;

-- 3. Permissões ---------------------------------------------------------------------------------------
create table if not exists rt.acesso (
  id            bigint generated always as identity primary key,
  pessoa        uuid not null references rt.pessoa(pseudonimo),
  empresa       uuid references org.empresa(id),            -- nula: todas as empresas
  circulo       smallint references org.circulo(numero),     -- nulo: todos os círculos
  papel         text not null,
  nivel         text not null check (nivel in ('ler', 'operar', 'aprovar', 'administrar')),
  inicio        date not null default current_date,
  fim           date,
  concedido_por uuid references rt.pessoa(pseudonimo),
  motivo        text not null,
  check (fim is null or fim >= inicio)
);
create index if not exists acesso_pessoa on rt.acesso (pessoa);

create table if not exists rt.papel_incompativel (
  papel_a text not null, papel_b text not null, circulo smallint references org.circulo(numero), regra text not null,
  primary key (papel_a, papel_b)
);
insert into rt.papel_incompativel values
  ('Gestão · pessoa', 'Líder do círculo', 8, 'D3 da auditoria geral (aprovada em 03/10/2026): na Gestão, quem prepara não aprova')
on conflict do nothing;

create or replace function rt._nivel(p text) returns int language sql immutable set search_path = '' as $$
  select case p when 'ler' then 1 when 'operar' then 2 when 'aprovar' then 3 when 'administrar' then 4 end $$;

-- A pessoa pode agir com este nível nesta empresa e neste círculo hoje?
create or replace function rt.pode(p_pessoa uuid, p_empresa uuid, p_circulo smallint, p_nivel text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from rt.acesso a
                  where a.pessoa = p_pessoa and current_date >= a.inicio and (a.fim is null or current_date <= a.fim)
                    and (a.empresa is null or a.empresa = p_empresa or p_empresa is null)
                    and (a.circulo is null or a.circulo = p_circulo or p_circulo is null)
                    and rt._nivel(a.nivel) >= rt._nivel(p_nivel)) $$;

-- Barra o acúmulo de papéis que se fiscalizam
create or replace function rt._acesso_confere() returns trigger language plpgsql set search_path = '' as $$
begin
  if exists (select 1 from rt.acesso a join rt.papel_incompativel i
               on (i.papel_a = new.papel and i.papel_b = a.papel) or (i.papel_b = new.papel and i.papel_a = a.papel)
              where a.pessoa = new.pessoa and a.id is distinct from new.id and (a.fim is null or a.fim >= current_date)
                and (i.circulo is null or (coalesce(a.circulo, i.circulo) = i.circulo and coalesce(new.circulo, i.circulo) = i.circulo))) then
    raise exception 'papéis incompatíveis para a mesma pessoa: % e outro papel que o fiscaliza (regra de segregação)', new.papel;
  end if;
  return new;
end $$;
drop trigger if exists acesso_confere on rt.acesso;
create trigger acesso_confere before insert or update on rt.acesso for each row execute function rt._acesso_confere();

-- Acessos das pessoas simuladas: cada uma no seu círculo e no seu papel; líderes aprovam no círculo; sócios, executivos e Administrador em tudo
insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, motivo)
  select p.pseudonimo, null, p.circulo, p.papel,
         case when p.papel in ('Sócios', 'Administrador do IMTS.OS') then 'administrar'
              when p.papel in ('Líder do círculo', 'Executivo da empresa') then 'aprovar'
              when p.papel in ('Cliente', 'Parceiro', 'Assessoria externa', 'Solicitante') then 'ler'
              else 'operar' end,
         'usuário simulado (E2): acesso pelo papel'
    from rt.pessoa p
   where p.simulado and not exists (select 1 from rt.acesso a where a.pessoa = p.pseudonimo);

-- 4. Aplicação: o que o app chama com o login da pessoa ---------------------------------------------------
create or replace function rt._exigir_eu() returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then raise exception 'login sem pessoa ligada'; end if;
  return v;
end $$;

create or replace function rt.app_quadro() returns jsonb language sql security definer set search_path = '' as $$ select rt.quadro(rt._exigir_eu()) $$;
create or replace function rt.app_concluir(p_cartao bigint) returns text language sql security definer set search_path = '' as $$ select rt.concluir_cartao(p_cartao, rt._exigir_eu()) $$;
create or replace function rt.app_decidir(p_cartao bigint, p_para text) returns text language sql security definer set search_path = '' as $$ select rt.decidir_cartao(p_cartao, rt._exigir_eu(), p_para) $$;
create or replace function rt.app_mover(p_cartao bigint, p_coluna text) returns void language sql security definer set search_path = '' as $$ select rt.mover_cartao(p_cartao, rt._exigir_eu(), p_coluna) $$;
create or replace function rt.app_criar_avulsa(p_titulo text, p_prazo timestamptz, p_pai bigint default null) returns bigint
  language sql security definer set search_path = '' as $$ select rt.criar_avulsa(rt._exigir_eu(), p_titulo, p_prazo, p_pai, 'mesa') $$;
create or replace function rt.app_delegar(p_cartao bigint, p_para uuid default null, p_agente boolean default false, p_modo smallint default null) returns void
  language sql security definer set search_path = '' as $$ select rt.delegar_cartao(p_cartao, rt._exigir_eu(), p_para, p_agente, p_modo) $$;
create or replace function rt.app_responder(p_cartao bigint, p_aceita boolean, p_novo_prazo timestamptz default null) returns void
  language sql security definer set search_path = '' as $$ select rt.responder_delegacao(p_cartao, rt._exigir_eu(), p_aceita, p_novo_prazo) $$;
create or replace function rt.app_iniciar(p_jornada text) returns bigint language plpgsql security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu();
begin
  if not rt.pode(v, null, (select circulo from org.jornada where codigo = p_jornada), 'operar') then raise exception 'sem acesso para iniciar jornada deste círculo'; end if;
  return rt.iniciar_jornada(p_jornada, v, false);
end $$;
-- Quadro do círculo: os cartões de fluxo para quem lê o círculo; a carga em números só para quem aprova nele (o líder)
create or replace function rt.app_quadro_circulo(p_circulo smallint) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu(); q jsonb;
begin
  if not rt.pode(v, null, p_circulo, 'ler') then raise exception 'sem acesso a este círculo'; end if;
  q := rt.quadro_circulo(p_circulo);
  if not rt.pode(v, null, p_circulo, 'aprovar') then q := q - 'carga' - 'pedidos_de_fora'; end if;
  return q;
end $$;

-- leitura direta das tabelas pelo login: cartão de fluxo do círculo que a pessoa lê; avulsa e ajuda só de quem é dono ou recebeu
drop policy if exists leitura_autenticada_fluxo on rt.cartao;
drop policy if exists leitura_por_acesso on rt.cartao;
create policy leitura_por_acesso on rt.cartao for select to authenticated
  using ((tipo = 'fluxo' and rt.pode(rt.eu(), null, circulo, 'ler')) or dono = rt.eu() or delegado_pessoa = rt.eu());
alter table rt.acesso enable row level security;
drop policy if exists leitura_propria on rt.acesso;
create policy leitura_propria on rt.acesso for select to authenticated using (pessoa = rt.eu() or rt.pode(rt.eu(), empresa, circulo, 'administrar'));
alter table rt.papel_incompativel enable row level security;
drop policy if exists leitura_autenticada on rt.papel_incompativel;
create policy leitura_autenticada on rt.papel_incompativel for select to authenticated using (true);
grant select on rt.acesso, rt.papel_incompativel to authenticated; grant all on rt.acesso, rt.papel_incompativel to service_role;

-- 5. Direitos do titular (LGPD, art. 18) -----------------------------------------------------------------
-- Exporta, num JSON só, tudo o que a base guarda de uma pessoa: acesso aos dados (II) e portabilidade (V)
create or replace function rt.exportar_pessoa(p_pessoa uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'gerado_em', now(), 'base_legal', 'LGPD, art. 18, II e V',
    'pessoa', (select to_jsonb(p) from rt.pessoa p where p.pseudonimo = p_pessoa),
    'identidade', (select to_jsonb(i) - 'pseudonimo' from rt_chave.identidade i where i.pseudonimo = p_pessoa),
    'acessos', (select coalesce(jsonb_agg(to_jsonb(a) order by a.id), '[]') from rt.acesso a where a.pessoa = p_pessoa),
    'cartoes', (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]') from rt.cartao c where c.dono = p_pessoa or c.delegado_pessoa = p_pessoa or c.criado_por = p_pessoa),
    'eventos', (select coalesce(jsonb_agg(jsonb_build_object('quando', coalesce(e.fim, e.inicio), 'tipo', e.tipo, 'jornada', e.jornada, 'resultado', e.resultado) order by e.id), '[]')
                  from rt.evento e where e.pessoa = p_pessoa),
    'mensagens', (select coalesce(jsonb_agg(to_jsonb(m) order by m.id), '[]') from rt.mensagem m where m.pessoa = p_pessoa)) $$;

-- Registro dos pedidos do titular atendidos (sem dado pessoal: só o pseudônimo, o pedido e quando)
create table if not exists rt.pedido_titular (
  id bigint generated always as identity primary key, pessoa uuid not null, pedido text not null check (pedido in ('exportar', 'eliminar')),
  motivo text, feito_em timestamptz not null default now());
alter table rt.pedido_titular enable row level security;
grant all on rt.pedido_titular to service_role;

-- Exportação com registro
create or replace function rt.atender_exportacao(p_pessoa uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  insert into rt.pedido_titular (pessoa, pedido) values (p_pessoa, 'exportar');
  return rt.exportar_pessoa(p_pessoa);
end $$;

-- Elimina o vínculo da pessoa com a identidade real, apaga o conteúdo das mensagens e encerra os acessos:
-- o pseudônimo fica sem dono conhecido, e o que resta (eventos, cartões) passa a ser anônimo (IV e VI)
create or replace function rt.eliminar_pessoa(p_pessoa uuid, p_motivo text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare a int; b int; c int;
begin
  if p_motivo is null or length(trim(p_motivo)) < 5 then raise exception 'diga o motivo da eliminação'; end if;
  delete from rt_chave.login where pseudonimo = p_pessoa;
  update rt_chave.identidade set nome = 'eliminado em ' || to_char(now(), 'DD/MM/YYYY'), telegram_id = null, consentimento_art33_em = null
   where pseudonimo = p_pessoa and nome not like 'eliminado em %';
  get diagnostics a = row_count;
  update rt.mensagem set conteudo = '(eliminado)' where pessoa = p_pessoa and conteudo <> '(eliminado)'; get diagnostics c = row_count;
  update rt.acesso set inicio = least(inicio, current_date - 1), fim = current_date - 1, motivo = motivo || ' · encerrado: ' || p_motivo where pessoa = p_pessoa and (fim is null or fim >= current_date);
  get diagnostics b = row_count;
  insert into rt.pedido_titular (pessoa, pedido, motivo) values (p_pessoa, 'eliminar', p_motivo);
  return jsonb_build_object('identidade_apagada', a > 0, 'mensagens_apagadas', c, 'acessos_encerrados', b);
end $$;

revoke all on function rt.eu(), rt.pode(uuid, uuid, smallint, text), rt._exigir_eu(), rt.exportar_pessoa(uuid), rt.atender_exportacao(uuid), rt.eliminar_pessoa(uuid, text) from public;
grant execute on function rt.eu(), rt.pode(uuid, uuid, smallint, text) to authenticated, service_role;
grant execute on function rt.exportar_pessoa(uuid), rt.atender_exportacao(uuid), rt.eliminar_pessoa(uuid, text), rt._exigir_eu() to service_role;
revoke all on function rt.app_quadro(), rt.app_concluir(bigint), rt.app_decidir(bigint, text), rt.app_mover(bigint, text), rt.app_criar_avulsa(text, timestamptz, bigint),
  rt.app_delegar(bigint, uuid, boolean, smallint), rt.app_responder(bigint, boolean, timestamptz), rt.app_iniciar(text), rt.app_quadro_circulo(smallint) from public;
grant execute on function rt.app_quadro(), rt.app_concluir(bigint), rt.app_decidir(bigint, text), rt.app_mover(bigint, text), rt.app_criar_avulsa(text, timestamptz, bigint),
  rt.app_delegar(bigint, uuid, boolean, smallint), rt.app_responder(bigint, boolean, timestamptz), rt.app_iniciar(text), rt.app_quadro_circulo(smallint) to authenticated, service_role;

commit;
