-- Rodada de testes da P6 (21/10/2026): acrescenta as suítes da automação R, avisos de assinatura, Mini App do Telegram,
-- Google Docs e agentes de IA. Só onde os testes ficam (homologação); a 090 tira a rodada no perfil de produção.
begin;
create or replace function adm.testar_tudo() returns jsonb language plpgsql set search_path = '' as $f$
declare s text; res jsonb := '{}'; msg text;
begin
  foreach s in array array['rt._testar_runtime', 'rt._testar_motor', 'rt._testar_mesa', 'rt._testar_acesso', 'rt._testar_telegram',
                           'doc._testar_documental', 'adm._testar_administracao', 'ext._testar_externo', 'rt._testar_agentes', 'rt._testar_seguranca',
                           'acervo._testar_acervo', 'doc._testar_marca_modelos', 'ext._testar_parceiro', 'ext._testar_atendimento', 'ext._testar_reunioes',
                           'adm._testar_simulacao', 'adm._testar_producao', 'rt._testar_assistido', 'adm._testar_servidor', 'doc._testar_nota_debito', 'adm._testar_integracoes',
                           'rt._testar_papeis_acumulados', 'doc._testar_assinatura',
                           'rt._testar_automacao_r', 'doc._testar_assinatura_avisos', 'rt._testar_telegram_miniapp', 'doc._testar_docs_google', 'rt._testar_agentes_ia'] loop
    begin
      execute format('select %s()', s) into msg;
      raise exception using errcode = 'P0099', message = msg;
    exception when sqlstate 'P0099' then res := res || jsonb_build_object(s, jsonb_build_object('ok', true, 'resultado', sqlerrm));
              when others then res := res || jsonb_build_object(s, jsonb_build_object('ok', false, 'resultado', sqlerrm));
    end;
  end loop;
  return jsonb_build_object('todas_ok', not exists (select 1 from jsonb_each(res) e where not (e.value->>'ok')::boolean), 'suites', res);
end $f$;
revoke all on function adm.testar_tudo() from public, anon, authenticated;
commit;
