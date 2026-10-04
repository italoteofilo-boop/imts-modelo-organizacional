-- Correção das regressões da onda 3: M10 (038 trocou a regra de leitura do cartão por uma mais larga) e A9 (redeploy de 025 voltou
-- os limites fixos do motor documental). Idempotente; 038 e 025 já saem corrigidos, este arquivo só acerta a base implantada.
begin;
drop policy if exists leitura_interna on rt.cartao;
drop policy if exists leitura_por_acesso on rt.cartao;
create policy leitura_por_acesso on rt.cartao for select to authenticated
  using ((tipo = 'fluxo' and rt.pode(rt.eu(), empresa, circulo, 'ler')) or dono = rt.eu() or delegado_pessoa = rt.eu());
commit;

-- Rodada única de testes que nunca grava: cada suíte roda numa subtransação desfeita no fim (a exceção leva o resultado para fora).
-- Uso: select adm.testar_tudo();   Chamar as funções _testar_* direto, sem o envelope, grava os efeitos dos testes (incidente de 04/10/2026).
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca'] loop
    begin
      execute format('select %s()', s) into msg;
      raise exception using errcode = 'P0099', message = msg;
    exception when sqlstate 'P0099' then res := res || jsonb_build_object(s, jsonb_build_object('ok', true, 'resultado', sqlerrm));
              when others then res := res || jsonb_build_object(s, jsonb_build_object('ok', false, 'resultado', sqlerrm));
    end;
  end loop;
  return jsonb_build_object('todas_ok', not exists (select 1 from jsonb_each(res) e where not (e.value->>'ok')::boolean), 'suites', res);
end $$;
revoke all on function adm.testar_tudo() from public, anon, authenticated;
grant execute on function adm.testar_tudo() to service_role;
