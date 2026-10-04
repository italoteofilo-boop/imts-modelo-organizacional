-- Homologação do banco de produção, de ponta a ponta, sem deixar rastro (tudo é desfeito no fim).
-- Roda depois do aplicar.sh:  psql "$DB_URL" -v ON_ERROR_STOP=1 -f homologar_banco.sql
-- Faz o que o aplicativo faz, pela porta única (public.imts) e com o papel authenticated, como o PostgREST:
--   H1 o administrador entra com o Google; H2 importa um cadastro; H3 a pessoa de Operações entra e inicia uma jornada
--   na empresa escolhida; H4 a tarefa vai para uma pessoa de verdade; H5 o cliente convidado entra e abre um pedido;
--   H6 a equipe vê o pedido; H7 quem não tem cadastro não usa nada.
-- Resultado: uma linha "homologação do banco: 7 de 7 ok" ou o primeiro passo que falhou.
begin;
do $$
declare adm_p uuid; u_adm uuid := gen_random_uuid(); u_op uuid := gen_random_uuid(); u_cli uuid := gen_random_uuid(); u_x uuid := gen_random_uuid();
  r jsonb; emp uuid; inst bigint; ped bigint; ok boolean; v_cnpj text; base text := '445556660001';
  dominio text := (adm.valor('login.dominios', '["imts.com.br"]') ->> 0);
begin
  select p.pseudonimo into adm_p from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
   where not p.simulado and a.nivel = 'administrar' and a.empresa is null and a.circulo is null order by a.id limit 1;
  if adm_p is null then raise exception 'FALHA H0: sem administrador de verdade (rode o aplicar.sh)'; end if;
  v_cnpj := acervo._cnpj_formatar(base || acervo._cnpj_dv(base));

  -- H1. login do administrador (o Supabase Auth grava em auth.users; o gatilho liga à pessoa pelo e-mail)
  insert into auth.users (id, email, aud, role) values (u_adm, (select email from rt_chave.identidade where pseudonimo = adm_p), 'authenticated', 'authenticated');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_adm, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u_adm::text, true); perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  r := public.imts('rt.quem_sou', '{}');
  if r->>'tipo' <> 'interno' or not coalesce((r->>'administra')::boolean, false) then reset role; raise exception 'FALHA H1: administrador não reconhecido (%)', r; end if;

  -- H2. importação do cadastro pela porta única (prévia e confirmação)
  r := public.imts('adm.importar_cadastro', jsonb_build_object('p_confirmar', true, 'p_dados', jsonb_build_object(
    'empresas', jsonb_build_array(jsonb_build_object('nome', 'Empresa de homologação', 'cnpj', v_cnpj, 'regime_tributario', 'Lucro Presumido', 'marca', 'imts')),
    'pessoas', jsonb_build_array(
       jsonb_build_object('nome', 'Pessoa de Operações', 'email', 'homolog.op@' || dominio, 'papel', 'Operações · pessoa', 'circulo', 7, 'nivel', 'operar', 'empresa', 'Empresa de homologação'),
       jsonb_build_object('nome', 'Pessoa de Relações', 'email', 'homolog.rel@' || dominio, 'papel', 'Relações · pessoa', 'circulo', 4, 'nivel', 'operar', 'empresa', 'Empresa de homologação'),
       jsonb_build_object('nome', 'Líder de Operações', 'email', 'homolog.lider@' || dominio, 'papel', 'Líder do círculo', 'circulo', 7, 'nivel', 'aprovar', 'empresa', 'Empresa de homologação')),
    'contrapartes', jsonb_build_array(jsonb_build_object('empresa', 'Empresa de homologação', 'tipo', 'cliente', 'nome', 'Cliente de homologação', 'setor_publico', true)),
    'usuarios_externos', jsonb_build_array(jsonb_build_object('contraparte', 'Cliente de homologação', 'nome', 'Gestor do cliente', 'email', 'gestor@cliente-homologacao.gov.br', 'perfil', 'gestor')))));
  if not coalesce((r->>'confirmado')::boolean, false) then reset role; raise exception 'FALHA H2: importação (%)', r; end if;
  reset role;
  select id into emp from org.empresa where nome = 'Empresa de homologação';

  -- H3. a pessoa de Operações entra e inicia uma jornada na empresa escolhida (cabeçalho x-empresa)
  insert into auth.users (id, email, aud, role) values (u_op, 'homolog.op@' || dominio, 'authenticated', 'authenticated');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_op, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u_op::text, true);
  perform set_config('request.headers', jsonb_build_object('x-empresa', emp)::text, true);
  set local role authenticated;
  r := public.imts('rt.quem_sou', '{}');
  if r->>'tipo' <> 'interno' then reset role; raise exception 'FALHA H3: pessoa de Operações não reconhecida (%)', r; end if;
  r := public.imts('rt.app_iniciar', '{"p_jornada": "OP-03"}');
  reset role;
  select id into inst from rt.instancia where not simulado and jornada = 'OP-03' order by id desc limit 1;
  if inst is null or (select empresa from rt.instancia where id = inst) is distinct from emp then raise exception 'FALHA H3: instância fora da empresa escolhida'; end if;

  -- H4. as tarefas de pessoa vão para pessoas de verdade, nunca para simuladas
  if exists (select 1 from rt.cartao k join rt.pessoa p on p.pseudonimo = k.dono where k.instancia = inst and p.simulado) then raise exception 'FALHA H4: tarefa para pessoa simulada'; end if;
  if not exists (select 1 from rt.cartao k where k.instancia = inst) then raise exception 'FALHA H4: a jornada não gerou tarefa'; end if;

  -- H5. o cliente convidado entra, vê o portal da sua organização e abre um pedido
  insert into auth.users (id, email, aud, role) values (u_cli, 'gestor@cliente-homologacao.gov.br', 'authenticated', 'authenticated');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_cli, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u_cli::text, true); perform set_config('request.headers', '', true);
  set local role authenticated;
  r := public.imts('ext.portal', '{}');
  if r->'contraparte'->>'nome' <> 'Cliente de homologação' then reset role; raise exception 'FALHA H5: portal do cliente (%)', r->'contraparte'; end if;
  r := public.imts('ext.pedir', '{"p_tipo": "duvida", "p_assunto": "Homologação", "p_texto": "Pedido de teste da homologação"}');
  ok := false; begin perform public.imts('adm.painel_completo', '{}'); exception when others then ok := true; end;
  reset role;
  if not ok then raise exception 'FALHA H5: cliente leu a administração'; end if;
  select p.id into ped from ext.pedido p join ext.contraparte c on c.id = p.contraparte where c.nome = 'Cliente de homologação' order by p.id desc limit 1;
  if ped is null then raise exception 'FALHA H5: pedido não gravado'; end if;

  -- H6. a equipe vê o pedido no painel de atendimento
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_adm, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u_adm::text, true);
  set local role authenticated;
  r := public.imts('ext.painel_atendimento', jsonb_build_object('p_empresa', emp));
  reset role;
  if position(('"' || ped || '"') in r::text) = 0 and position((': ' || ped || ',') in r::text) = 0 and position((': ' || ped || '}') in r::text) = 0 then
    raise exception 'FALHA H6: pedido fora do painel de atendimento'; end if;

  -- H7. quem entra sem cadastro não usa nada
  insert into auth.users (id, email, aud, role) values (u_x, 'desconhecido@gmail.com', 'authenticated', 'authenticated');
  perform set_config('request.jwt.claims', jsonb_build_object('sub', u_x, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u_x::text, true);
  set local role authenticated;
  r := public.imts('rt.quem_sou', '{}');
  ok := false; begin perform public.imts('rt.app_quadro', '{}'); exception when others then ok := true; end;
  reset role;
  if r->>'tipo' <> 'sem_cadastro' or not ok then raise exception 'FALHA H7: desconhecido entrou (%)', r->>'tipo'; end if;

  raise notice 'homologação do banco: 7 de 7 ok';
end $$;
rollback;
