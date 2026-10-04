-- Perfil de produção (B08). SÓ NO PROJETO DE PRODUÇÃO, nunca no protótipo.
-- Ordem: migrações 001 a 072 num projeto novo -> select adm.primeiro_administrador('Nome', 'email@imts.com.br') -> este arquivo
--        -> select adm.conferir_implantacao().
-- O que faz: desliga a simulação, tira as rotinas de simulação da agenda, apaga o cadastro simulado que as migrações criam
-- (empresas, pessoas, identidades, acessos, clientes, parceiros, usuários e contratos), passa os agentes residentes para o
-- primeiro administrador, gera a chave do worker de documentos no cofre e remove as funções de simulação, de atuação
-- simulada ("_como") e de teste. Roda uma vez: se já rodou, não faz nada.
begin;

do $$
declare v_adm uuid; emp_sim uuid[]; pes_sim uuid[]; cp_sim uuid[]; usu_sim uuid[];
begin
  if exists (select 1 from adm.parametro where chave = 'implantacao.perfil' and valor = '"producao"') then
    raise notice 'perfil de produção já aplicado: nada a fazer'; return;
  end if;
  if exists (select 1 from rt.instancia) or exists (select 1 from rt.cartao) or exists (select 1 from ext.pedido) then
    raise exception 'o perfil de produção roda num projeto novo, logo depois das migrações (há movimento no banco)';
  end if;
  select p.pseudonimo into v_adm from rt.acesso a join rt.pessoa p on p.pseudonimo = a.pessoa
   where not p.simulado and a.nivel = 'administrar' and a.empresa is null and a.circulo is null order by a.id limit 1;
  if v_adm is null then raise exception 'cadastre antes o primeiro administrador: select adm.primeiro_administrador(''Nome'', ''email@imts.com.br'');'; end if;

  -- 1. simulação desligada e fora da agenda
  update adm.parametro set valor = 'false', atualizado_em = now(), atualizado_por = v_adm where chave = 'simulacao.ativa';
  -- tarefas de automação e de agente viram cartão de pessoa até existir o adaptador real (062)
  update adm.parametro set valor = 'true', atualizado_em = now(), atualizado_por = v_adm where chave = 'motor.maquina_assistida';
  perform cron.unschedule(jobid) from cron.job where jobname in ('imts-simulacao-continua', 'imts-externo-simulado');

  -- 2. cadastro simulado das migrações
  select coalesce(array_agg(id), '{}') into emp_sim from org.empresa where simulado;
  select coalesce(array_agg(pseudonimo), '{}') into pes_sim from rt.pessoa where simulado;
  select coalesce(array_agg(id), '{}') into cp_sim from ext.contraparte where simulado;
  select coalesce(array_agg(auth_uid), '{}') into usu_sim from ext.usuario where simulado;
  update rt.agente_residente set dono = v_adm where dono = any (pes_sim);
  update rt.acesso set concedido_por = null where concedido_por = any (pes_sim);
  delete from ext.telegram where simulado or auth_uid = any (usu_sim);
  delete from ext.convite where contraparte = any (cp_sim);
  delete from ext.usuario where auth_uid = any (usu_sim);
  delete from ext.contrato_parceria where contraparte = any (cp_sim);
  delete from acervo.pasta_drive where empresa = any (emp_sim);
  delete from ext.contraparte where id = any (cp_sim);
  delete from ext.empresa_marca where empresa = any (emp_sim);
  delete from rt.conversa where pessoa = any (pes_sim);
  delete from rt.fila_envio where pessoa = any (pes_sim);
  delete from rt.mensagem where pessoa = any (pes_sim);
  delete from rt_chave.login where pseudonimo = any (pes_sim);
  delete from rt.acesso where pessoa = any (pes_sim) or empresa = any (emp_sim);
  delete from rt.pessoa where pseudonimo = any (pes_sim);
  delete from rt_chave.identidade where simulado;
  delete from org.atribuicao where empresa = any (emp_sim);
  delete from org.empresa where id = any (emp_sim);

  -- conexões: o que apontava para o protótipo fica pendente até o time preencher o endereço de produção (Administração > Conexões)
  update adm.conexao set nome = replace(nome, ' (projeto rzkfolkqdgtounqjjzss)', ''), ambiente = 'produção', estado = 'pendente', endpoint = null, alvo = null, saude = 'desconhecida', saude_detalhe = null,
         pendencia = 'preencher com o endereço do projeto de produção', atualizado_em = now()
   where coalesce(endpoint, '') || coalesce(alvo, '') || nome like '%rzkfolkqdgtounqjjzss%';

  -- catálogo de sistemas: nada simulado em produção; sem integração, a pessoa faz (motor assistido)
  update rt.sistema set adaptador = 'assistido' where adaptador = 'simulado';
  update adm.conexao set estado = 'pendente', pendencia = coalesce(pendencia, 'escolher o fornecedor e cadastrar em Administração > Integrações')
   where estado = 'simulada';

  -- 3. chave do worker de documentos (o time a lê no cofre e a põe no ambiente do worker)
  if rt._segredo('doc_worker_chave') is null then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'doc_worker_chave', 'chave do worker de documentos (cabeçalho do worker)');
  end if;

  -- 4. marca do perfil
  insert into adm.parametro (chave, escopo, descricao, tipo, valor, padrao, validacao, sensivel, destinos, fonte)
  values ('implantacao.perfil', 'global', 'Perfil do banco: produção não tem simulação nem funções de teste', 'texto', '"producao"', '"producao"', '{}', true, '{}', 'Perfil de produção (B08)')
  on conflict (chave) do update set valor = excluded.valor;
  insert into adm.historico (objeto, chave, antes, depois, por, como, motivo)
  values ('simulacao', 'perfil de produção', jsonb_build_object('empresas', cardinality(emp_sim), 'pessoas', cardinality(pes_sim), 'contrapartes', cardinality(cp_sim), 'usuarios', cardinality(usu_sim)),
          jsonb_build_object('simulacao', false), v_adm, 'serviço (implantação)', 'perfil de produção aplicado: cadastro simulado removido');
end $$;

-- 5. funções que não existem em produção: atuação simulada ("_como"), simulação e testes
do $$ declare f record; begin
  for f in select p.oid::regprocedure as assinatura from pg_proc p join pg_namespace s on s.oid = p.pronamespace
            where (s.nspname = 'ext' and (p.proname like '%\_como' or p.proname in ('_como', 'usuarios_simulados', 'vincular_simulados', 'contexto_central')))
               or (s.nspname = 'acervo' and p.proname = 'contexto')
               or (s.nspname = 'adm' and p.proname in ('simular_ecossistema', 'religar_simulacao', 'zerar_simulacoes', 'simulacao_painel', 'testar_tudo'))
               or (s.nspname = 'rt' and p.proname in ('simular_continuo', 'executar_simulada'))
               or (s.nspname in ('rt', 'doc', 'adm', 'ext', 'acervo') and p.proname like '\_testar%')
  loop execute format('drop function %s', f.assinatura); end loop;
  delete from adm.api_funcao a where not exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname || '.' || p.proname = a.nome);
end $$;

-- 6. nenhuma função que fica pode chamar uma que saiu
do $$ declare achou text; begin
  select string_agg(distinct s.nspname || '.' || p.proname, ', ') into achou from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname in ('rt', 'rt_chave', 'doc', 'adm', 'ext', 'org', 'sim', 'acervo')
     and p.prosrc ~ '(_como\(|simular_continuo|executar_simulada|simular_ecossistema|vincular_simulados|usuarios_simulados|zerar_simulacoes|simulacao_painel|_testar_|testar_tudo|contexto_central|acervo\.contexto\()'
     and p.proname not in ('conferir_implantacao');
  if achou is not null then raise exception 'funções que ainda chamam o que saiu: %', achou; end if;
end $$;

select adm.endurecer_permissoes();
commit;
