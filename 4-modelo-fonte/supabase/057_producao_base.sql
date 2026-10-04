-- P1 · Banco pronto para produção (plano de produção de 04/10/2026, itens B01 a B07).
-- B01 login liga a conta à pessoa cadastrada; B02 convite de cliente e parceiro; B03 importação do cadastro com prévia;
-- B04 porta única de chamadas do aplicativo; B05 índices e políticas; B06 retenção de eventos; B07 alertas de operação.
begin;

alter table adm.historico drop constraint if exists historico_objeto_check;
alter table adm.historico add constraint historico_objeto_check
  check (objeto in ('parametro', 'conexao', 'agente', 'regra_externa', 'titulo_externo', 'tipo_documento', 'incidente', 'acervo', 'marca',
                    'contrato_parceria', 'comissao', 'prestacao', 'atendimento', 'reuniao', 'simulacao', 'cadastro', 'login', 'alerta'));

insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte) values
 ('login.dominios', 'acesso', 'Domínios de e-mail aceitos no login de quem é de dentro (conta Google do Workspace)', 'lista', '["imts.com.br"]', '["imts.com.br"]', '{}', true, '{}', 'Plano de produção, 04/10/2026'),
 ('runtime.retencao_eventos_dias', 'global', 'Dias que os eventos de instâncias encerradas ficam guardados; 0 = guardar sempre', 'inteiro', '0', '0', '{"min":0,"max":3650}', true, '{}', 'Plano de produção, 04/10/2026 (B06)'),
 ('alerta.chat_ref', 'administração', 'Conversa do Telegram que recebe os alertas de operação (ex.: tg:-100123); vazio = só no painel', 'texto', '""', '""', '{}', false, '{}', 'Plano de produção, 04/10/2026 (B07)'),
 ('alerta.fila_minutos', 'administração', 'Minutos para considerar parada a fila de documentos ou de envio', 'inteiro', '30', '30', '{"min":5,"max":240}', false, '{}', 'Plano de produção, 04/10/2026 (B07)')
on conflict (chave) do nothing;

-- ---------- B01 · login de quem é de dentro ----------
alter table rt_chave.identidade add column if not exists email text;
create unique index if not exists identidade_email on rt_chave.identidade (lower(email)) where email is not null;

-- ---------- B02 · convite de cliente e parceiro ----------
create table if not exists ext.convite (
  id bigint generated always as identity primary key,
  email text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  contraparte uuid not null references ext.contraparte(id),
  nome text not null,
  perfil text not null check (perfil in ('gestor', 'fiscal', 'financeiro', 'operacional')),
  criado_por uuid,
  criado_em timestamptz not null default now(),
  aceito_em timestamptz,
  auth_uid uuid
);
create unique index if not exists convite_email_aberto on ext.convite (lower(email)) where aceito_em is null;
alter table ext.convite enable row level security;
drop policy if exists leitura on ext.convite;
create policy leitura on ext.convite for select to authenticated using (ext._le(contraparte));
grant select on ext.convite to authenticated; grant all on ext.convite to service_role;

-- primeiro acesso: a conta nova liga à pessoa cadastrada (dentro) ou ao convite (fora); sem cadastro, a conta existe mas não vê nada
create or replace function rt_chave._ao_novo_login() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(new.email); v_dom text := split_part(lower(new.email), '@', 2); v_p uuid; c ext.convite;
begin
  if v_email is null then return new; end if;
  select i.pseudonimo into v_p from rt_chave.identidade i join rt.pessoa p on p.pseudonimo = i.pseudonimo
   where lower(i.email) = v_email and not p.simulado;
  if v_p is not null and v_dom = any (array(select jsonb_array_elements_text(adm.valor('login.dominios', '["imts.com.br"]')))) then
    insert into rt_chave.login (auth_uid, pseudonimo) values (new.id, v_p) on conflict do nothing;
    insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
    values ('login', 'pessoa ' || v_p, null, jsonb_build_object('dominio', v_dom), v_p, 'aplicativo', 'primeiro acesso ligado à pessoa cadastrada');
    return new;
  end if;
  select * into c from ext.convite where lower(email) = v_email and aceito_em is null order by id desc limit 1;
  if c.id is not null then
    insert into ext.usuario (auth_uid, contraparte, nome, perfil, simulado, ativo) values (new.id, c.contraparte, c.nome, c.perfil, false, true)
    on conflict (auth_uid) do nothing;
    update ext.convite set aceito_em = now(), auth_uid = new.id where id = c.id;
  end if;
  return new;
exception when others then
  -- o login nunca falha por causa do vínculo: o erro fica registrado para a Integração
  insert into adm.erro (origem, detalhe) values ('rt_chave._ao_novo_login', sqlerrm);
  return new;
end $$;
do $$ begin
  if to_regclass('auth.users') is not null then
    drop trigger if exists imts_novo_login on auth.users;
    create trigger imts_novo_login after insert on auth.users for each row execute function rt_chave._ao_novo_login();
  end if;
end $$;

-- quem sou eu (o aplicativo monta o menu a partir daqui)
create or replace function rt.quem_sou() returns jsonb language plpgsql stable security definer set search_path = '' as $$
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
      'pessoas', (select coalesce(jsonb_agg(jsonb_build_object('pessoa', p.pseudonimo, 'papel', p.papel, 'circulo', p.circulo) order by p.circulo nulls first, p.papel), '[]')
                   from rt.pessoa p where p.circulo is not null and (not p.simulado or not exists (select 1 from rt.pessoa x where not x.simulado))),
      'governanca', rt.pode(v, null, 9::smallint, 'ler'));
  end if;
  u := ext.eu();
  if u.auth_uid is not null then
    return jsonb_build_object('tipo', 'externo', 'nome', u.nome, 'perfil', u.perfil,
      'contraparte', (select jsonb_build_object('nome', nome, 'tipo', tipo) from ext.contraparte where id = u.contraparte));
  end if;
  return jsonb_build_object('tipo', 'sem_cadastro', 'email', (select email from auth.users where id = auth.uid()));
end $$;

-- convidar cliente ou parceiro (o link de acesso vai pelo e-mail de login do Supabase)
create or replace function ext.convidar(p_contraparte uuid, p_email text, p_nome text, p_perfil text, p_como uuid default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v uuid := ext._interno(p_como); c ext.contraparte; v_id bigint;
begin
  select * into c from ext.contraparte where id = p_contraparte and ativa;
  if c.id is null then raise exception 'cliente ou parceiro inexistente'; end if;
  if not rt.pode(v, c.empresa, null, 'operar') then raise exception 'sem acesso a esta empresa'; end if;
  if exists (select 1 from ext.usuario u join auth.users a on a.id = u.auth_uid where lower(a.email) = lower(btrim(p_email)) and u.ativo) then raise exception 'este e-mail já tem acesso ao portal'; end if;
  insert into ext.convite (email, contraparte, nome, perfil, criado_por) values (lower(btrim(p_email)), c.id, btrim(p_nome), p_perfil, v) returning id into v_id;
  return v_id;
end $$;

-- ---------- B03 · importação do cadastro com prévia ----------
create or replace function adm.importar_cadastro(p_dados jsonb, p_confirmar boolean default false, p_como uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v uuid := adm._admin(p_como); erros jsonb := '[]'; avisos jsonb := '[]'; r jsonb; i int; v_emp uuid; v_cp uuid; v_p uuid; n_emp int := 0; n_pes int := 0; n_cp int := 0; n_conv int := 0; n_ct int := 0;
  -- papéis válidos: as raias do modelo (não depende de haver pessoa simulada) e os papéis já em uso
  papeis text[] := array(select distinct raia from org.tarefa union select distinct papel from rt.pessoa union select distinct papel from rt.acesso);
  dominios text[] := array(select jsonb_array_elements_text(adm.valor('login.dominios', '["imts.com.br"]')));
  d text; nomes_emp text[] := '{}';
begin
  -- empresas
  i := 0;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'empresas', '[]')) loop
    i := i + 1; d := regexp_replace(coalesce(r->>'cnpj', ''), '\D', '', 'g');
    if coalesce(btrim(r->>'nome'), '') = '' then erros := erros || jsonb_build_object('aba', 'empresas', 'linha', i, 'campo', 'nome', 'motivo', 'obrigatório'); end if;
    if d <> '' and not acervo._cnpj_valido(d) then erros := erros || jsonb_build_object('aba', 'empresas', 'linha', i, 'campo', 'cnpj', 'motivo', 'CNPJ inválido'); end if;
    if coalesce(r->>'marca', 'neutra') not in (select id from doc.marca) then erros := erros || jsonb_build_object('aba', 'empresas', 'linha', i, 'campo', 'marca', 'motivo', 'marca desconhecida (use: ' || (select string_agg(id, ', ') from doc.marca) || ')'); end if;
    if exists (select 1 from org.empresa where lower(nome) = lower(btrim(r->>'nome')) and not simulado) then avisos := avisos || jsonb_build_object('aba', 'empresas', 'linha', i, 'motivo', 'empresa já cadastrada: fica como está'); end if;
    nomes_emp := nomes_emp || lower(btrim(r->>'nome'));
  end loop;
  -- pessoas
  i := 0;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'pessoas', '[]')) loop
    i := i + 1;
    if coalesce(btrim(r->>'nome'), '') = '' then erros := erros || jsonb_build_object('aba', 'pessoas', 'linha', i, 'campo', 'nome', 'motivo', 'obrigatório'); end if;
    if coalesce(r->>'email', '') !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then erros := erros || jsonb_build_object('aba', 'pessoas', 'linha', i, 'campo', 'email', 'motivo', 'e-mail inválido');
    elsif not (split_part(lower(r->>'email'), '@', 2) = any (dominios)) then erros := erros || jsonb_build_object('aba', 'pessoas', 'linha', i, 'campo', 'email', 'motivo', 'domínio fora de ' || array_to_string(dominios, ', '));
    elsif exists (select 1 from rt_chave.identidade where lower(email) = lower(r->>'email')) then avisos := avisos || jsonb_build_object('aba', 'pessoas', 'linha', i, 'motivo', 'pessoa já cadastrada: fica como está'); end if;
    if not (r->>'papel' = any (papeis)) then erros := erros || jsonb_build_object('aba', 'pessoas', 'linha', i, 'campo', 'papel', 'motivo', 'papel desconhecido'); end if;
    if (r->>'circulo') is not null and (r->>'circulo') !~ '^[1-9]$' then erros := erros || jsonb_build_object('aba', 'pessoas', 'linha', i, 'campo', 'circulo', 'motivo', 'círculo de 1 a 9 ou vazio'); end if;
    if coalesce(r->>'nivel', '') not in ('ler', 'operar', 'aprovar', 'administrar') then erros := erros || jsonb_build_object('aba', 'pessoas', 'linha', i, 'campo', 'nivel', 'motivo', 'nível: ler, operar, aprovar ou administrar'); end if;
    if coalesce(r->>'empresa', '') <> '' and not (lower(r->>'empresa') = any (nomes_emp)) and not exists (select 1 from org.empresa where lower(nome) = lower(r->>'empresa') and not simulado) then
      erros := erros || jsonb_build_object('aba', 'pessoas', 'linha', i, 'campo', 'empresa', 'motivo', 'empresa não está na planilha nem cadastrada (vazio = todas)'); end if;
  end loop;
  -- clientes e parceiros
  i := 0;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'contrapartes', '[]')) loop
    i := i + 1; d := regexp_replace(coalesce(r->>'cnpj', ''), '\D', '', 'g');
    if coalesce(r->>'tipo', '') not in ('cliente', 'parceiro') then erros := erros || jsonb_build_object('aba', 'contrapartes', 'linha', i, 'campo', 'tipo', 'motivo', 'cliente ou parceiro'); end if;
    if coalesce(btrim(r->>'nome'), '') = '' then erros := erros || jsonb_build_object('aba', 'contrapartes', 'linha', i, 'campo', 'nome', 'motivo', 'obrigatório'); end if;
    if d <> '' and not acervo._cnpj_valido(d) then erros := erros || jsonb_build_object('aba', 'contrapartes', 'linha', i, 'campo', 'cnpj', 'motivo', 'CNPJ inválido'); end if;
    if not (lower(coalesce(r->>'empresa', '')) = any (nomes_emp)) and not exists (select 1 from org.empresa where lower(nome) = lower(r->>'empresa') and not simulado) then
      erros := erros || jsonb_build_object('aba', 'contrapartes', 'linha', i, 'campo', 'empresa', 'motivo', 'empresa da IMTS desconhecida'); end if;
  end loop;
  -- usuários de fora (viram convites) e contratos de parceria
  i := 0;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'usuarios_externos', '[]')) loop
    i := i + 1;
    if coalesce(r->>'email', '') !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then erros := erros || jsonb_build_object('aba', 'usuarios_externos', 'linha', i, 'campo', 'email', 'motivo', 'e-mail inválido'); end if;
    if coalesce(r->>'perfil', '') not in ('gestor', 'fiscal', 'financeiro', 'operacional') then erros := erros || jsonb_build_object('aba', 'usuarios_externos', 'linha', i, 'campo', 'perfil', 'motivo', 'gestor, fiscal, financeiro ou operacional'); end if;
    if not exists (select 1 from jsonb_array_elements(coalesce(p_dados->'contrapartes', '[]')) x where lower(x->>'nome') = lower(r->>'contraparte'))
       and not exists (select 1 from ext.contraparte where lower(nome) = lower(r->>'contraparte') and not simulado) then
      erros := erros || jsonb_build_object('aba', 'usuarios_externos', 'linha', i, 'campo', 'contraparte', 'motivo', 'cliente ou parceiro desconhecido'); end if;
  end loop;
  i := 0;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'contratos_parceria', '[]')) loop
    i := i + 1;
    if coalesce((r->>'percentual')::numeric, 0) <= 0 or (r->>'percentual')::numeric > 50 then erros := erros || jsonb_build_object('aba', 'contratos_parceria', 'linha', i, 'campo', 'percentual', 'motivo', 'entre 0 e 50'); end if;
    if coalesce(btrim(r->>'fonte'), '') = '' then erros := erros || jsonb_build_object('aba', 'contratos_parceria', 'linha', i, 'campo', 'fonte', 'motivo', 'diga o contrato de onde vem a regra'); end if;
    if not exists (select 1 from jsonb_array_elements(coalesce(p_dados->'contrapartes', '[]')) x where lower(x->>'nome') = lower(r->>'parceiro') and x->>'tipo' = 'parceiro')
       and not exists (select 1 from ext.contraparte where lower(nome) = lower(r->>'parceiro') and tipo = 'parceiro' and not simulado) then
      erros := erros || jsonb_build_object('aba', 'contratos_parceria', 'linha', i, 'campo', 'parceiro', 'motivo', 'parceiro desconhecido'); end if;
  end loop;

  if not p_confirmar or jsonb_array_length(erros) > 0 then
    return jsonb_build_object('confirmado', false, 'pode_confirmar', jsonb_array_length(erros) = 0, 'erros', erros, 'avisos', avisos,
      'resumo', jsonb_build_object('empresas', jsonb_array_length(coalesce(p_dados->'empresas', '[]')), 'pessoas', jsonb_array_length(coalesce(p_dados->'pessoas', '[]')),
        'contrapartes', jsonb_array_length(coalesce(p_dados->'contrapartes', '[]')), 'usuarios_externos', jsonb_array_length(coalesce(p_dados->'usuarios_externos', '[]')),
        'contratos_parceria', jsonb_array_length(coalesce(p_dados->'contratos_parceria', '[]'))));
  end if;

  -- grava (tudo ou nada: é uma transação só)
  for r in select * from jsonb_array_elements(coalesce(p_dados->'empresas', '[]')) loop
    continue when exists (select 1 from org.empresa where lower(nome) = lower(btrim(r->>'nome')) and not simulado);
    d := regexp_replace(coalesce(r->>'cnpj', ''), '\D', '', 'g');
    insert into org.empresa (nome, regime_tributario, porte, simulado, ativa, cnpj, razao_social)
    values (btrim(r->>'nome'), nullif(r->>'regime_tributario', ''), nullif(r->>'porte', ''), false, true,
            case when d <> '' then acervo._cnpj_formatar(d) end, nullif(btrim(r->>'razao_social'), '')) returning id into v_emp;
    insert into ext.empresa_marca (empresa, marca) values (v_emp, coalesce(nullif(r->>'marca', ''), 'neutra')) on conflict (empresa) do update set marca = excluded.marca;
    n_emp := n_emp + 1;
  end loop;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'pessoas', '[]')) loop
    continue when exists (select 1 from rt_chave.identidade where lower(email) = lower(r->>'email'));
    v_p := gen_random_uuid();
    insert into rt_chave.identidade (pseudonimo, nome, email, simulado) values (v_p, btrim(r->>'nome'), lower(btrim(r->>'email')), false);
    insert into rt.pessoa (pseudonimo, papel, circulo, simulado) values (v_p, r->>'papel', (r->>'circulo')::smallint, false);
    insert into rt.acesso (pessoa, empresa, circulo, papel, nivel, concedido_por, motivo)
    values (v_p, (select id from org.empresa where lower(nome) = lower(r->>'empresa') and not simulado), (r->>'circulo')::smallint, r->>'papel', r->>'nivel', v, 'carga inicial do cadastro');
    n_pes := n_pes + 1;
  end loop;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'contrapartes', '[]')) loop
    continue when exists (select 1 from ext.contraparte where lower(nome) = lower(btrim(r->>'nome')) and not simulado);
    d := regexp_replace(coalesce(r->>'cnpj', ''), '\D', '', 'g');
    insert into ext.contraparte (empresa, tipo, nome, documento, setor_publico, simulado, ativa)
    values ((select id from org.empresa where lower(nome) = lower(r->>'empresa') and not simulado), r->>'tipo', btrim(r->>'nome'),
            case when d <> '' then acervo._cnpj_formatar(d) end, coalesce((r->>'setor_publico')::boolean, false), false, true);
    n_cp := n_cp + 1;
  end loop;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'usuarios_externos', '[]')) loop
    continue when exists (select 1 from ext.convite where lower(email) = lower(r->>'email') and aceito_em is null);
    insert into ext.convite (email, contraparte, nome, perfil, criado_por)
    values (lower(btrim(r->>'email')), (select id from ext.contraparte where lower(nome) = lower(r->>'contraparte') and not simulado), btrim(r->>'nome'), r->>'perfil', v);
    n_conv := n_conv + 1;
  end loop;
  for r in select * from jsonb_array_elements(coalesce(p_dados->'contratos_parceria', '[]')) loop
    select id into v_cp from ext.contraparte where lower(nome) = lower(r->>'parceiro') and tipo = 'parceiro' and not simulado;
    update ext.contrato_parceria set vigente_ate = coalesce((r->>'vigente_de')::date, current_date) - 1 where contraparte = v_cp and vigente_ate is null;
    insert into ext.contrato_parceria (contraparte, percentual, parcelas_max, vigente_de, simulado, fonte)
    values (v_cp, (r->>'percentual')::numeric, coalesce((r->>'parcelas_max')::int, 12), coalesce((r->>'vigente_de')::date, current_date), false, btrim(r->>'fonte'));
    n_ct := n_ct + 1;
  end loop;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('cadastro', 'carga ' || to_char(now() at time zone 'America/Fortaleza', 'DD/MM/YYYY HH24:MI'), null,
          jsonb_build_object('empresas', n_emp, 'pessoas', n_pes, 'contrapartes', n_cp, 'convites', n_conv, 'contratos_parceria', n_ct), v,
          case when rt.eu() is null then 'serviço (implantação ou rotina)' else 'aplicativo' end, 'carga do cadastro real pela importação');
  return jsonb_build_object('confirmado', true, 'avisos', avisos, 'gravados', jsonb_build_object('empresas', n_emp, 'pessoas', n_pes, 'contrapartes', n_cp, 'convites', n_conv, 'contratos_parceria', n_ct));
end $$;

-- o cartão vai para a pessoa de verdade antes da simulada, e entre pessoas do mesmo papel, para a que tem menos tarefas abertas
create or replace function rt._pessoa(p_raia text, p_motor smallint) returns uuid language sql stable set search_path = '' as $$
  select p.pseudonimo from rt.pessoa p where p.papel = p_raia
   order by (p.circulo is not distinct from p_motor) desc, p.simulado,
            (select count(*) from rt.cartao k where k.dono = p.pseudonimo and k.coluna <> 'feito'), p.circulo nulls first, p.pseudonimo
   limit 1 $$;

-- ---------- B04 · porta única do aplicativo ----------
create table if not exists adm.api_funcao (
  nome text primary key check (nome ~ '^(rt|ext|doc|adm|acervo)\.[a-z_]+$'),
  quem text not null check (quem in ('interno', 'externo', 'todos')),
  descricao text not null
);
alter table adm.api_funcao enable row level security;
drop policy if exists leitura on adm.api_funcao;
create policy leitura on adm.api_funcao for select to authenticated using (true);
grant select on adm.api_funcao to authenticated; grant all on adm.api_funcao to service_role;

insert into adm.api_funcao (nome, quem, descricao) values
 ('rt.quem_sou', 'todos', 'quem está usando e o que pode ver'),
 ('rt.app_quadro', 'interno', 'Mesa: tarefas da pessoa'), ('rt.app_quadro_circulo', 'interno', 'Mesa: tarefas do círculo'),
 ('rt.app_concluir', 'interno', 'concluir tarefa'), ('rt.app_criar_avulsa', 'interno', 'criar tarefa avulsa'), ('rt.app_decidir', 'interno', 'decidir caminho'),
 ('rt.app_delegar', 'interno', 'delegar tarefa'), ('rt.app_iniciar', 'interno', 'iniciar processo'), ('rt.app_mover', 'interno', 'mover tarefa'), ('rt.app_responder', 'interno', 'aceitar ou recusar delegação'),
 ('rt.painel', 'interno', 'painel dos processos'), ('rt.painel_detalhe', 'interno', 'painel: detalhe da jornada'), ('rt.painel_execucao', 'interno', 'painel: uma execução'),
 ('rt.agente_aprovar_rascunho', 'interno', 'aprovar resposta de agente'), ('rt.agente_memoria_editar', 'interno', 'editar memória de agente'),
 ('rt.agente_ligar', 'interno', 'ligar ou desligar agente'), ('rt.agente_liberar', 'interno', 'liberar ou suspender agente'),
 ('adm.painel_completo', 'interno', 'administração'), ('adm.alterar_conexao', 'interno', 'alterar conexão'), ('adm.alterar_parametro', 'interno', 'alterar parâmetro'),
 ('adm.decidir_mudanca', 'interno', 'aprovar ou recusar mudança'), ('adm.verificar_saude', 'interno', 'verificar saúde'),
 ('adm.importar_cadastro', 'interno', 'importar o cadastro'), ('adm.alertas', 'interno', 'alertas de operação'), ('adm.alerta_resolver', 'interno', 'encerrar alerta'),
 ('acervo.painel', 'interno', 'acervo'), ('acervo.verificar', 'interno', 'acervo: duplicado?'),
 ('acervo.registrar', 'interno', 'acervo: registrar arquivo'), ('acervo.confirmar_local', 'interno', 'acervo: confirmar pasta'), ('acervo.classificar', 'interno', 'acervo: triagem'),
 ('acervo.decidir_campo', 'interno', 'acervo: aprovar dado'), ('acervo.resolver_divergencia', 'interno', 'acervo: divergência'), ('acervo.pasta_registrar', 'interno', 'acervo: pasta do Drive'),
 ('doc.painel_marca_modelos', 'interno', 'marca e minutas'), ('doc.decidir_marca', 'interno', 'decidir marca'), ('doc.decidir_minuta', 'interno', 'decidir minuta'), ('doc.pedir_minuta', 'interno', 'emitir pela minuta'),
 ('ext.painel_atendimento', 'interno', 'Central: atendimento'), ('ext.painel_parceiros', 'interno', 'Central: parceiros'), ('ext.painel_reunioes', 'interno', 'Central: reuniões'),
 ('ext.responder', 'interno', 'responder pedido'), ('ext.encaminhar', 'interno', 'encaminhar'), ('ext.encaminhamento_concluir', 'interno', 'concluir encaminhamento'),
 ('ext.sala_responder', 'interno', 'responder na sala'), ('ext.oportunidade_decidir', 'interno', 'decidir oportunidade'), ('ext.comissao_adquirir', 'interno', 'parcela recebida'),
 ('ext.prestacao_decidir', 'interno', 'decidir nota'), ('ext.prestacao_pagar', 'interno', 'registrar pagamento'), ('ext.contraparte_documento', 'interno', 'CNPJ do parceiro'),
 ('ext.reuniao_agendar', 'interno', 'marcar reunião'), ('ext.reuniao_registrar_externa', 'interno', 'link da reunião'), ('ext.reuniao_consentir', 'interno', 'consentimento'),
 ('ext.reuniao_transcricao', 'interno', 'transcrição'), ('ext.reuniao_ata_rascunho', 'interno', 'rascunho da ata'), ('ext.reuniao_ata_aprovar', 'interno', 'aprovar ata'),
 ('ext.reuniao_cancelar', 'interno', 'cancelar reunião'), ('ext.reuniao_gravacao_apagada', 'interno', 'retenção da gravação'), ('ext.publicar_documento', 'interno', 'publicar documento no portal'),
 ('ext.convidar', 'interno', 'convidar cliente ou parceiro'),
 ('ext.portal', 'externo', 'portal'), ('ext.pedir', 'externo', 'novo pedido'), ('ext.ouvidoria', 'externo', 'ouvidoria'), ('ext.documento_pdf', 'externo', 'baixar documento'),
 ('ext.portal_parceiro', 'externo', 'portal do parceiro'), ('ext.sala_enviar', 'externo', 'sala de negócio'), ('ext.telegram_codigo', 'externo', 'código do Telegram'), ('ext.telegram_desligar', 'externo', 'desligar Telegram'),
 ('ext.portal_reunioes', 'externo', 'reuniões'), ('ext.reuniao_consentir_externo', 'externo', 'consentir gravação'),
 ('ext.atendimento_confirmar', 'externo', 'confirmar encerramento'), ('ext.atendimento_reabrir', 'externo', 'reabrir')
on conflict (nome) do update set quem = excluded.quem, descricao = excluded.descricao;
delete from adm.api_funcao where nome in ('acervo.contexto', 'ext.contexto_central', 'adm.verificar_conexoes');   -- a escolha de quem atua é do protótipo

-- verificar a saúde pelo aplicativo: só quem administra
create or replace function adm.verificar_saude() returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not rt.pode_estrito(rt.eu(), null, null, 'administrar') then raise exception 'só a administração verifica a saúde'; end if;
  return adm.verificar_conexoes();
end $$;
revoke all on function adm.verificar_saude() from public, anon;
grant execute on function adm.verificar_saude() to authenticated, service_role;

-- as leituras do painel dos processos passam a ser liberadas a quem tem login (o acesso por linha continua valendo)
grant execute on function rt.painel(), rt.painel_detalhe(text, integer), rt.painel_execucao(bigint) to authenticated;

-- chama, com o login de quem está usando, uma função da lista; argumentos por nome, em JSON
create or replace function public.imts(p_fn text, p_args jsonb default '{}') returns jsonb language plpgsql security invoker set search_path = '' as $$
declare f record; q text; parts text[] := '{}'; k text; t text; res jsonb; ok_args text[];
begin
  if p_fn is null or not exists (select 1 from adm.api_funcao where nome = p_fn) then raise exception 'função não disponível no aplicativo: %', p_fn; end if;
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
end $$;
revoke all on function public.imts(text, jsonb) from public, anon;
grant execute on function public.imts(text, jsonb) to authenticated, service_role;
grant execute on function rt.quem_sou(), ext.convidar(uuid, text, text, text, uuid), adm.importar_cadastro(jsonb, boolean, uuid) to authenticated, service_role;
revoke all on function rt_chave._ao_novo_login() from public, anon, authenticated;

-- ---------- B05 · índices das chaves estrangeiras usadas e políticas sem recálculo por linha ----------
create index if not exists cartao_pai on rt.cartao (pai) where pai is not null;
create index if not exists cartao_tarefa on rt.cartao (tarefa);
create index if not exists cartao_jornada on rt.cartao (jornada);
create index if not exists cartao_criado_por on rt.cartao (criado_por);
create index if not exists cartao_circulo on rt.cartao (circulo);
create index if not exists instancia_jornada on rt.instancia (jornada);
create index if not exists instancia_motor on rt.instancia (motor);
create index if not exists acesso_empresa on rt.acesso (empresa);
create index if not exists acesso_circulo on rt.acesso (circulo);
create index if not exists pessoa_circulo on rt.pessoa (circulo);
create index if not exists mensagem_pessoa on rt.mensagem (pessoa);
create index if not exists fila_envio_pessoa on rt.fila_envio (pessoa);
create index if not exists arquivo_contraparte on acervo.arquivo (contraparte);
create index if not exists arquivo_versao_de on acervo.arquivo (versao_de);
create index if not exists campo_arquivo on acervo.campo (arquivo);
create index if not exists marca_proposta_empresa on doc.marca_proposta (empresa);
create index if not exists marca_proposta_arquivo on doc.marca_proposta (arquivo);
create index if not exists minuta_arquivo on doc.minuta (arquivo);
create index if not exists minuta_empresa_tipo on doc.minuta (empresa, tipo);
create index if not exists pedido_empresa on doc.pedido (empresa);
create index if not exists pedido_tarefa on doc.pedido (tarefa);
create index if not exists comissao_prestacao on ext.comissao (prestacao);
create index if not exists comissao_oportunidade on ext.comissao (oportunidade);
create index if not exists contraparte_empresa on ext.contraparte (empresa);
create index if not exists documento_emissao on ext.documento (emissao);
create index if not exists encaminhamento_reuniao on ext.encaminhamento (reuniao);
create index if not exists oportunidade_pedido on ext.oportunidade (pedido);
create index if not exists oportunidade_contraparte on ext.oportunidade (contraparte);
create index if not exists pedido_usuario on ext.pedido (usuario);
create index if not exists pedido_contraparte on ext.pedido (contraparte);
create index if not exists prestacao_arquivo on ext.prestacao (arquivo);
create index if not exists prestacao_contraparte on ext.prestacao (contraparte);
create index if not exists reuniao_contraparte on ext.reuniao (contraparte);
create index if not exists reuniao_pedido on ext.reuniao (pedido);
create index if not exists usuario_contraparte on ext.usuario (contraparte);
create index if not exists vinculo_contraparte on ext.vinculo (contraparte);
create index if not exists convite_contraparte on ext.convite (contraparte);

drop policy if exists leitura on ext.usuario;
create policy leitura on ext.usuario for select to authenticated using (auth_uid = (select auth.uid()) or rt.pode_estrito(rt.eu(), null, null, 'administrar'));
drop policy if exists leitura on ext.telegram;
create policy leitura on ext.telegram for select to authenticated using (auth_uid = (select auth.uid()));
drop policy if exists leitura on ext.pedido;
create policy leitura on ext.pedido for select to authenticated using (
  (contraparte = (ext.eu()).contraparte and (usuario = (select auth.uid()) or ((ext.eu()).perfil = 'gestor' and tipo <> 'ouvidoria')))
  or (ext._le(contraparte) and (tipo <> 'ouvidoria' or ext._le_ouvidoria(contraparte))));

-- ---------- B06 · retenção dos eventos (desligada por padrão) ----------
create or replace function rt.reter_eventos(p_lote int default 20000) returns int language plpgsql security definer set search_path = '' as $$
declare v_dias int := coalesce((adm.valor('runtime.retencao_eventos_dias', '0') #>> '{}')::int, 0); n int;
begin
  if v_dias <= 0 then return 0; end if;
  delete from rt.evento where ctid = any (array(
    select e.ctid from rt.evento e join rt.instancia i on i.id = e.instancia
     where i.estado <> 'rodando' and coalesce(i.fim, i.inicio) < now() - make_interval(days => v_dias)
       and not exists (select 1 from rt.cartao k where k.instancia = i.id and k.coluna <> 'feito')
     limit p_lote));
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function rt.reter_eventos(int) from public, anon, authenticated;
select cron.schedule('imts-retencao-eventos', '37 4 * * *', 'select rt.reter_eventos()');

-- ---------- B07 · alertas de operação ----------
create table if not exists adm.alerta (
  id bigint generated always as identity primary key,
  chave text not null,
  tipo text not null check (tipo in ('erro', 'conexao', 'rotina', 'fila_documentos', 'fila_envio')),
  detalhe text not null,
  primeiro_em timestamptz not null default now(),
  ultimo_em timestamptz not null default now(),
  vezes int not null default 1,
  avisado_em timestamptz,
  resolvido_em timestamptz,
  resolvido_por uuid
);
create unique index if not exists alerta_aberto on adm.alerta (chave) where resolvido_em is null;
alter table adm.alerta enable row level security;
drop policy if exists leitura on adm.alerta;
create policy leitura on adm.alerta for select to authenticated using (rt.pode_estrito(rt.eu(), null, null, 'ler'));
grant select on adm.alerta to authenticated; grant all on adm.alerta to service_role;

create or replace function adm._alertar(p_chave text, p_tipo text, p_detalhe text) returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into adm.alerta (chave, tipo, detalhe) values (p_chave, p_tipo, left(p_detalhe, 1000))
  on conflict (chave) where resolvido_em is null do update set ultimo_em = now(), vezes = adm.alerta.vezes + 1, detalhe = excluded.detalhe;
end $$;

-- vigia: abre, renova e fecha alertas; avisa no Telegram de Integração uma vez por alerta
create or replace function adm.vigiar() returns jsonb language plpgsql security definer set search_path = '' as $$
declare r record; v_min int := coalesce((adm.valor('alerta.fila_minutos', '30') #>> '{}')::int, 30); chat text := nullif(adm.valor('alerta.chat_ref', '""') #>> '{}', ''); n_novos int := 0; vistos text[] := '{}';
begin
  for r in select 'erro:' || origem as chave, count(*) n, max(detalhe) d from adm.erro where em > now() - interval '15 minutes' group by origem loop
    perform adm._alertar(r.chave, 'erro', r.n || ' erro(s) em ' || substr(r.chave, 6) || ': ' || coalesce(r.d, '')); vistos := vistos || r.chave;
  end loop;
  for r in select 'conexao:' || codigo as chave, nome, saude_detalhe from adm.conexao where estado = 'ativa' and saude = 'falha' loop
    perform adm._alertar(r.chave, 'conexao', r.nome || ' com falha: ' || coalesce(r.saude_detalhe, '')); vistos := vistos || r.chave;
  end loop;
  if to_regclass('cron.job_run_details') is not null then
    for r in execute $q$select 'rotina:' || j.jobname as chave, count(*) n from cron.job_run_details d join cron.job j on j.jobid = d.jobid
                         where d.status = 'failed' and d.start_time > now() - interval '1 hour' group by j.jobname$q$ loop
      perform adm._alertar(r.chave, 'rotina', 'rotina ' || substr(r.chave, 8) || ' falhou ' || r.n || ' vez(es) na última hora'); vistos := vistos || r.chave;
    end loop;
  end if;
  if exists (select 1 from doc.pedido where situacao = 'na_fila' and criado_em < now() - make_interval(mins => v_min)) then
    perform adm._alertar('fila:documentos', 'fila_documentos', (select count(*) from doc.pedido where situacao = 'na_fila' and criado_em < now() - make_interval(mins => v_min)) || ' documento(s) na fila há mais de ' || v_min || ' minutos: o worker parou?');
    vistos := vistos || 'fila:documentos'::text;
  end if;
  if exists (select 1 from rt.fila_envio where not simulado and estado in ('pendente', 'erro') and criado_em < now() - make_interval(mins => v_min)) then
    perform adm._alertar('fila:envio', 'fila_envio', (select count(*) from rt.fila_envio where not simulado and estado in ('pendente', 'erro') and criado_em < now() - make_interval(mins => v_min)) || ' mensagem(ns) do Telegram presas há mais de ' || v_min || ' minutos');
    vistos := vistos || 'fila:envio'::text;
  end if;
  -- fecha o que sumiu (erros fecham sozinhos depois de 1 hora sem repetir)
  update adm.alerta set resolvido_em = now() where resolvido_em is null and not (chave = any (vistos))
     and (tipo <> 'erro' or ultimo_em < now() - interval '1 hour');
  -- avisa uma vez
  for r in select id, detalhe from adm.alerta where resolvido_em is null and avisado_em is null loop
    if chat is not null then insert into rt.fila_envio (chat_ref, texto, simulado) values (chat, 'Alerta IMTS.OS: ' || r.detalhe, false); end if;
    update adm.alerta set avisado_em = now() where id = r.id; n_novos := n_novos + 1;
  end loop;
  return jsonb_build_object('abertos', (select count(*) from adm.alerta where resolvido_em is null), 'novos', n_novos);
end $$;
create or replace function adm.alertas(p_como uuid default null) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then if not rt.chamada_servico() then raise exception 'sem identidade'; end if; v := p_como; end if;
  if v is null or not rt.pode_estrito(v, null, null, 'ler') then raise exception 'sem acesso'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'tipo', tipo, 'detalhe', detalhe, 'primeiro_em', primeiro_em, 'ultimo_em', ultimo_em, 'vezes', vezes, 'resolvido_em', resolvido_em) order by resolvido_em nulls first, ultimo_em desc), '[]')
            from (select * from adm.alerta order by resolvido_em nulls first, ultimo_em desc limit 100) a);
end $$;
create or replace function adm.alerta_resolver(p_id bigint, p_como uuid default null) returns void language plpgsql security definer set search_path = '' as $$
declare v uuid := rt.eu();
begin
  if v is null then if not rt.chamada_servico() then raise exception 'sem identidade'; end if; v := p_como; end if;
  if v is null or not rt.pode_estrito(v, null, null, 'operar') then raise exception 'sem acesso'; end if;
  update adm.alerta set resolvido_em = now(), resolvido_por = v where id = p_id and resolvido_em is null;
end $$;
revoke all on function adm._alertar(text, text, text), adm.vigiar(), adm.alertas(uuid), adm.alerta_resolver(bigint, uuid) from public, anon, authenticated;
grant execute on function adm.alertas(uuid), adm.alerta_resolver(bigint, uuid) to authenticated, service_role;
select cron.schedule('imts-vigia', '*/10 * * * *', 'select adm.vigiar()');
commit;
