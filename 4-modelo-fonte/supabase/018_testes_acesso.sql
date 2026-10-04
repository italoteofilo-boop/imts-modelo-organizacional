-- Os testes de acesso (testar_acesso.sql) como função, para rodar no Supabase sem gravar nada:
-- do $$ begin raise exception '%', rt._testar_acesso(); end $$;   (a exceção desfaz tudo)
begin;
create or replace function rt._testar_acesso() returns text language plpgsql set search_path = '' as $$
declare
  p1 uuid; lider uuid; ges uuid; lider8 uuid; outro uuid; u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
  c bigint; q jsonb; ok boolean; n int; x jsonb; a bigint;
begin
  select pseudonimo into p1 from rt.pessoa where papel = 'Identidade · pessoa' order by pseudonimo limit 1;
  select pseudonimo into lider from rt.pessoa where papel = 'Líder do círculo' and circulo = 1;
  select pseudonimo into ges from rt.pessoa where papel = 'Gestão · pessoa' limit 1;
  select pseudonimo into outro from rt.pessoa where papel = 'Identidade · pessoa' and pseudonimo <> p1 limit 1;
  insert into rt_chave.login (auth_uid, pseudonimo) values (u1, p1), (u2, lider);

  -- A1. Sem login não há pessoa; com login, a pessoa é a do vínculo
  perform set_config('request.jwt.claim.sub', '', true);
  if rt.eu() is not null then raise exception 'FALHA A1: pessoa sem login'; end if;
  ok := false; begin perform rt.app_quadro(); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A1: app sem login respondeu'; end if;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  if rt.eu() is distinct from p1 then raise exception 'FALHA A1: login não chegou à pessoa'; end if;

  -- A2. Permissão por círculo e nível
  if not rt.pode(p1, null, 1::smallint, 'operar') then raise exception 'FALHA A2: pessoa não opera no seu círculo'; end if;
  if rt.pode(p1, null, 2::smallint, 'ler') then raise exception 'FALHA A2: pessoa lê outro círculo'; end if;
  if rt.pode(p1, null, 1::smallint, 'aprovar') then raise exception 'FALHA A2: pessoa aprova sem ser líder'; end if;

  -- A3. Quadro do círculo: a pessoa vê o fluxo, não a carga; o líder vê a carga; outro círculo, recusa
  q := rt.app_quadro_circulo(1::smallint);
  if q ? 'carga' then raise exception 'FALHA A3: pessoa viu a carga'; end if;
  ok := false; begin perform rt.app_quadro_circulo(2::smallint); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A3: viu quadro de outro círculo'; end if;
  perform set_config('request.jwt.claim.sub', u2::text, true);
  if not (rt.app_quadro_circulo(1::smallint) ? 'carga') then raise exception 'FALHA A3: líder não viu a carga'; end if;

  -- A4. O app usa a pessoa do login: quem não é dono não conclui o cartão de outro
  perform set_config('request.jwt.claim.sub', u1::text, true);
  c := rt.app_criar_avulsa('Separar recibos do mês', now() + interval '1 day');
  if (select dono from rt.cartao where id = c) <> p1 then raise exception 'FALHA A4: avulsa com dono errado'; end if;
  perform set_config('request.jwt.claim.sub', u2::text, true);
  ok := false; begin perform rt.app_concluir(c); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A4: outro concluiu a avulsa'; end if;

  -- A5. Leitura direta (RLS): a avulsa só aparece para quem é dono
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', u2::text, true);
  select count(*) into n from rt.cartao where id = c;
  if n <> 0 then execute 'reset role'; raise exception 'FALHA A5: o líder leu a avulsa da pessoa'; end if;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  select count(*) into n from rt.cartao where id = c;
  execute 'reset role';
  if n <> 1 then raise exception 'FALHA A5: a dona não leu a própria avulsa'; end if;

  -- A6. Segregação: a mesma pessoa não prepara e aprova na Gestão
  ok := false;
  begin insert into rt.acesso (pessoa, circulo, papel, nivel, motivo) values (ges, 8, 'Líder do círculo', 'aprovar', 'teste'); exception when others then ok := true; end;
  if not ok then raise exception 'FALHA A6: acumulou preparar e aprovar na Gestão'; end if;

  -- A7. Multiempresa: as empresas simuladas existem; o acesso por empresa restringe
  if (select count(*) from org.empresa where simulado) < 4 then raise exception 'FALHA A7: empresas simuladas'; end if;
  insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, motivo)
       values (outro, (select id from org.empresa where nome = 'Empresa de saúde (simulada)'), 1, 'Identidade · pessoa', 'aprovar', 'teste por empresa');
  if not rt.pode(outro, (select id from org.empresa where nome = 'Empresa de saúde (simulada)'), 1::smallint, 'aprovar') then raise exception 'FALHA A7: acesso da empresa'; end if;
  if rt.pode(outro, (select id from org.empresa where nome = 'Empresa de educação (simulada)'), 1::smallint, 'aprovar') then raise exception 'FALHA A7: acesso vazou para outra empresa'; end if;

  -- A8. Exportação do titular (LGPD, art. 18, II e V): traz identidade, acessos e cartões
  x := rt.atender_exportacao(p1);
  if x->'identidade'->>'nome' is null or jsonb_array_length(x->'acessos') < 1 or not exists (select 1 from jsonb_array_elements(x->'cartoes') e where (e->>'id')::bigint = c) then
    raise exception 'FALHA A8: exportação incompleta';
  end if;

  -- A9. Eliminação (art. 18, IV e VI): identidade apagada, login desfeito, acessos encerrados; o pseudônimo fica anônimo
  x := rt.eliminar_pessoa(p1, 'pedido do titular (teste)');
  if (select nome from rt_chave.identidade where pseudonimo = p1) not like 'eliminado em %' then raise exception 'FALHA A9: identidade ficou'; end if;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  if rt.eu() is not null then raise exception 'FALHA A9: login continuou ligado'; end if;
  if rt.pode(p1, null, 1::smallint, 'ler') then raise exception 'FALHA A9: acesso continuou'; end if;
  if (select count(*) from rt.pedido_titular where pessoa = p1) <> 2 then raise exception 'FALHA A9: pedidos do titular sem registro'; end if;

  -- A10. Defeitos plantados: cada teste acha o seu
  n := 0;
  alter table rt.acesso disable trigger acesso_confere;
  begin insert into rt.acesso (pessoa, circulo, papel, nivel, motivo) values (ges, 8, 'Líder do círculo', 'aprovar', 'defeito'); n := n + 1; exception when others then null; end;
  alter table rt.acesso enable trigger acesso_confere;
  delete from rt.acesso where motivo = 'defeito';
  drop policy leitura_por_acesso on rt.cartao;
  create policy leitura_por_acesso on rt.cartao for select to authenticated using (true);
  execute 'set local role authenticated'; perform set_config('request.jwt.claim.sub', u2::text, true);
  if (select count(*) from rt.cartao where id = c) = 1 then n := n + 1; end if;
  execute 'reset role';
  if n <> 2 then raise exception 'FALHA A10: defeito plantado não detectado (% de 2)', n; end if;

  return 'ACESSO: 10 testes, 0 falhas; 2 defeitos plantados detectados';
end $$;
revoke all on function rt._testar_acesso() from public;
commit;
