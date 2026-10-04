-- Onda 3 do plano mestre: toda regra que muda o comportamento do runtime deixa rastro no histórico da administração (append-only).
-- Cobertas: o que o cliente e o parceiro veem (ext.regra, ext.jornada_externa), o catálogo de documentos (doc.tipo) e a
-- configuração dos agentes residentes (rt.agente_residente; ligar e liberar já são registrados pelas próprias funções).
begin;
alter table adm.historico drop constraint if exists historico_objeto_check;
alter table adm.historico add constraint historico_objeto_check
  check (objeto in ('parametro', 'conexao', 'agente', 'regra_externa', 'titulo_externo', 'tipo_documento', 'incidente'));

create or replace function adm._historico_regra() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_obj text := tg_argv[0]; v_antes jsonb; v_depois jsonb; v_chave text; v_ign text[] := coalesce(tg_argv[1], '{}')::text[];
begin
  v_antes := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) - v_ign end;
  v_depois := case when tg_op in ('UPDATE', 'INSERT') then to_jsonb(new) - v_ign end;
  if tg_op = 'UPDATE' and v_antes = v_depois then return new; end if;
  v_chave := coalesce(v_depois, v_antes) ->> (case v_obj when 'titulo_externo' then 'jornada' when 'agente' then 'codigo' else 'id' end);
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values (v_obj, v_chave, v_antes, v_depois, rt.eu(),
          case when rt.eu() is null then 'serviço (implantação ou rotina)' else 'aplicativo' end,
          lower(tg_op) || ' em ' || tg_table_schema || '.' || tg_table_name);
  return coalesce(new, old);
end $$;
revoke all on function adm._historico_regra() from public, anon, authenticated;

drop trigger if exists historico on ext.regra;
create trigger historico after insert or update or delete on ext.regra for each row execute function adm._historico_regra('regra_externa');
drop trigger if exists historico on ext.jornada_externa;
create trigger historico after insert or update or delete on ext.jornada_externa for each row execute function adm._historico_regra('titulo_externo');
drop trigger if exists historico on doc.tipo;
create trigger historico after insert or update or delete on doc.tipo for each row execute function adm._historico_regra('tipo_documento');
drop trigger if exists historico on rt.agente_residente;
create trigger historico after update on rt.agente_residente for each row
  execute function adm._historico_regra('agente', '{ultima_execucao,ligado,liberado,liberado_por}');
commit;
