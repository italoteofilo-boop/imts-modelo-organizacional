-- O teste T1 do motor passa a aceitar o motor documental como sistema de automação (E12, 04/10/2026)
do $$ declare d text := pg_get_functiondef('rt._testar_motor()'::regprocedure);
begin
  if position('motor-documental' in d) = 0 then
    execute replace(d, '''banco'', ''emissor-fiscal'')', '''banco'', ''emissor-fiscal'', ''motor-documental'')');
  end if;
end $$;
