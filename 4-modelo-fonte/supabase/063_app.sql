-- Aplicativo de produção (P3): o que as telas precisam e ainda não havia pela porta única.
--  * quem_sou: nome das pessoas (delegar na Mesa, encaminhar na Central);
--  * ext.pasta_externa(): a pasta do acervo que recebe os arquivos de quem é de fora (antes só existia a versão simulada "_como");
--  * lista da porta única: painel dos agentes (Administração), prestação de contas e pasta externa (Portal).
begin;
CREATE OR REPLACE FUNCTION rt.quem_sou()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v uuid := rt.eu(); u ext.usuario;
begin
  if v is not null then
    return jsonb_build_object('tipo', 'interno', 'pessoa', v,
      'nome', (select nome from rt_chave.identidade where pseudonimo = v),
      'papel', (select papel from rt.pessoa where pseudonimo = v), 'circulo', (select circulo from rt.pessoa where pseudonimo = v),
      'acessos', (select coalesce(jsonb_agg(jsonb_build_object('empresa', a.empresa, 'empresa_nome', e.nome, 'circulo', a.circulo, 'papel', a.papel, 'nivel', a.nivel) order by a.id), '[]')
                   from rt.acesso a left join org.empresa e on e.id = a.empresa where a.pessoa = v and (a.fim is null or a.fim >= current_date)),
      'administra', rt.pode_estrito(v, null, null, 'administrar'),
      'empresas', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'nome', e.nome) order by e.nome), '[]') from org.empresa e
                    where e.ativa and rt.pode(v, e.id, null, 'ler') and (not e.simulado or not exists (select 1 from org.empresa x where not x.simulado))),
      'pessoas', (select coalesce(jsonb_agg(jsonb_build_object('pessoa', p.pseudonimo, 'nome', i.nome, 'papel', p.papel, 'circulo', p.circulo) order by p.circulo nulls first, p.papel, i.nome), '[]')
                   from rt.pessoa p join rt_chave.identidade i on i.pseudonimo = p.pseudonimo where p.circulo is not null and (not p.simulado or not exists (select 1 from rt.pessoa x where not x.simulado))),
      'governanca', rt.pode(v, null, 9::smallint, 'ler'));
  end if;
  u := ext.eu();
  if u.auth_uid is not null then
    return jsonb_build_object('tipo', 'externo', 'nome', u.nome, 'perfil', u.perfil,
      'contraparte', (select jsonb_build_object('nome', nome, 'tipo', tipo) from ext.contraparte where id = u.contraparte));
  end if;
  return jsonb_build_object('tipo', 'sem_cadastro', 'email', (select email from auth.users where id = auth.uid()));
end $function$;

create or replace function ext.pasta_externa() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u ext.usuario; c ext.contraparte; v_cod text;
begin
  u := ext._exigir_eu();
  select * into c from ext.contraparte where id = u.contraparte;
  v_cod := case c.tipo when 'parceiro' then '07' else '08' end;
  return jsonb_build_object('empresa', (select nome from org.empresa where id = c.empresa), 'codigo', v_cod, 'nome_pasta', (select nome from acervo.pasta where codigo = v_cod),
    'pronta', exists (select 1 from acervo.pasta_drive where empresa = c.empresa and pasta = v_cod));
end $$;
revoke all on function ext.pasta_externa() from public, anon;
grant execute on function ext.pasta_externa() to authenticated, service_role;

insert into adm.api_funcao (nome, quem, descricao) values
  ('rt.agentes_painel', 'interno', 'Painel dos agentes residentes (só administração)'),
  ('ext.prestacao_enviar', 'externo', 'Parceiro envia nota ou relatório da prestação de contas'),
  ('ext.pasta_externa', 'externo', 'Pasta do acervo que recebe os arquivos de quem é de fora')
on conflict (nome) do nothing;
commit;
