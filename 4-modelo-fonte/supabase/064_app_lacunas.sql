-- Lacunas achadas no porte das telas para o aplicativo de produção (P3).
--  * rt.painel falhava para todo usuário com login: faltava leitura da visão rt.v_cobertura;
--  * catálogo de círculos e jornadas para a Mesa e o Painel (iniciar jornada sem decorar código);
--  * sugestão de jornada pelo texto da captura na Mesa (já existia; faltava na porta única);
--  * lista de clientes e parceiros com id e usuários, para convidar e marcar reunião;
--  * cartão de pedido de fora sem pessoa na raia: mesmo destino do rt._responsavel (líder ou quem opera no círculo).
begin;
grant select on rt.v_cobertura to authenticated;

create or replace function rt.app_catalogo() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu();
begin
  return jsonb_build_object(
    'circulos', (select coalesce(jsonb_agg(jsonb_build_object('numero', c.numero, 'nome', c.nome) order by c.numero), '[]') from org.circulo c),
    'jornadas', (select coalesce(jsonb_agg(jsonb_build_object('codigo', j.codigo, 'nome', j.nome, 'circulo', j.circulo,
                        'pode_iniciar', rt.pode(v, null, j.circulo, 'operar')) order by j.codigo), '[]') from org.jornada j));
end $$;
revoke all on function rt.app_catalogo() from public, anon;
grant execute on function rt.app_catalogo() to authenticated, service_role;

create or replace function ext.contrapartes(p_empresa uuid) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt._exigir_eu();
begin
  if not rt.pode(v, p_empresa, null, 'ler') then raise exception 'sem acesso de leitura nesta empresa'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'tipo', c.tipo, 'nome', c.nome, 'documento', c.documento, 'setor_publico', c.setor_publico, 'ativa', c.ativa,
            'usuarios', (select coalesce(jsonb_agg(jsonb_build_object('nome', u.nome, 'perfil', u.perfil, 'email', a.email, 'ativo', u.ativo) order by u.nome), '[]')
                           from ext.usuario u left join auth.users a on a.id = u.auth_uid where u.contraparte = c.id),
            'convites_abertos', (select coalesce(jsonb_agg(jsonb_build_object('nome', k.nome, 'email', k.email, 'perfil', k.perfil) order by k.id), '[]')
                           from ext.convite k where k.contraparte = c.id and k.aceito_em is null)) order by c.tipo, c.nome), '[]')
          from ext.contraparte c where c.empresa = p_empresa);
end $$;
revoke all on function ext.contrapartes(uuid) from public, anon;
grant execute on function ext.contrapartes(uuid) to authenticated, service_role;

create or replace function ext._cartao(p_raia text, p_motor smallint, p_titulo text, p_prazo timestamp with time zone, p_empresa uuid) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v bigint;
begin
  v := rt.criar_avulsa(rt._responsavel(p_raia, p_motor), left(p_titulo, 200), p_prazo, null, 'externo', null);
  update rt.cartao set empresa = p_empresa where id = v;
  return v;
end $$;

grant execute on function rt.sugerir_jornada(text) to authenticated;

insert into adm.api_funcao (nome, quem, descricao) values
  ('rt.app_catalogo', 'interno', 'Círculos e jornadas do modelo, com o que a pessoa pode iniciar'),
  ('rt.sugerir_jornada', 'interno', 'Jornada que já cobre o texto da captura'),
  ('ext.contrapartes', 'interno', 'Clientes e parceiros da empresa, com usuários e convites')
on conflict (nome) do nothing;
commit;
