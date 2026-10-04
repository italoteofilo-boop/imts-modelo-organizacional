-- A porta única passa a conferir o público de cada função (adm.api_funcao.quem), além da lista.
-- Achado do porte das telas: rt.painel e afins respondiam (vazios) a quem é de fora; a recusa ficava só na tela.
begin;
CREATE OR REPLACE FUNCTION public.imts(p_fn text, p_args jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_quem text; f record; q text; parts text[] := '{}'; k text; t text; res jsonb; ok_args text[];
begin
  if p_fn is null or not exists (select 1 from adm.api_funcao where nome = p_fn) then raise exception 'função não disponível no aplicativo: %', p_fn; end if;
  -- quem pode: função da equipe só com login de dentro; função do portal só com login de cliente ou parceiro
  select quem into v_quem from adm.api_funcao where nome = p_fn;
  if v_quem = 'interno' and rt.eu() is null then raise exception 'função só para a equipe do IMTS'; end if;
  if v_quem = 'externo' and (ext.eu()).auth_uid is null then raise exception 'função só para clientes e parceiros'; end if;
  select p.oid, p.prorettype, p.proargnames, p.pronargs, p.proargtypes, p.pronargdefaults into f
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname || '.' || p.proname = p_fn
   order by p.pronargs desc limit 1;
  if f.oid is null then raise exception 'função inexistente: %', p_fn; end if;
  ok_args := coalesce(f.proargnames[1:f.pronargs], '{}');
  for k in select jsonb_object_keys(coalesce(p_args, '{}')) loop
    if not (k = any (ok_args)) then raise exception 'argumento desconhecido para %: %', p_fn, k; end if;
    if k = 'p_como' then raise exception 'o aplicativo não atua como outra pessoa'; end if;
    t := format_type(f.proargtypes[array_position(ok_args, k) - 1], null);
    parts := parts || case
      when jsonb_typeof(p_args->k) = 'null' then format('%I => null::%s', k, t)
      when t in ('jsonb', 'json') then format('%I => ($1->%L)::%s', k, k, t)
      when t like '%[]' then format('%I => (select array_agg(x)::%s from jsonb_array_elements_text($1->%L) x)', k, t, k)
      else format('%I => ($1->>%L)::%s', k, k, t) end;
  end loop;
  q := format('%s(%s)', p_fn, array_to_string(parts, ', '));
  if f.prorettype = 'void'::regtype then
    execute 'select ' || q || ' is null' using p_args;
    return null;
  end if;
  execute 'select to_jsonb(' || q || ')' into res using p_args;
  return res;
end $function$;
commit;
