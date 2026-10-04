-- Versão 2026-10-03.2 do modelo-base (aprovada por Ítalo em 03/10/2026, às 21:05). Rode depois de 012 (org.sincronizar_modelo) e 013 (grafos).
-- 1. Sistemas contábil, fiscal e bancário, com adaptador simulado, e o vínculo das tarefas novas.
-- 2. Publicação da versão pelo runtime dos runtimes e aplicação nos nove motores (os testes do modelo passaram: testar.py).
-- 3. E10: os oito motores que estavam em desenho passam a piloto, cada um com a sua configuração.
begin;

-- 1. Sistemas e contrato de interface dos adaptadores ------------------------------------------------
insert into rt.sistema (codigo, nome, atende, descricao) values
  ('erp-contabil',   'Sistema contábil e financeiro (ERP)', 'R', 'Plano de contas, centros de custo, lançamentos, a pagar e a receber, fechamento e demonstrações. Integração a escolher na stack de produção'),
  ('emissor-fiscal', 'Emissor de documentos fiscais',       'R', 'Emite, cancela e consulta notas e documentos fiscais junto aos órgãos fiscais. Integração a escolher na stack de produção'),
  ('banco',          'Bancos',                              'R', 'Extrato, pagamentos, cobranças e conciliação. Integração a escolher na stack de produção')
on conflict (codigo) do nothing;

create table if not exists rt.adaptador_operacao (
  sistema   text not null references rt.sistema(codigo),
  operacao  text not null,
  entrada   jsonb not null,
  saida     jsonb not null,
  descricao text not null,
  primary key (sistema, operacao)
);
insert into rt.adaptador_operacao (sistema, operacao, entrada, saida, descricao) values
  ('erp-contabil', 'manter_plano_contas', '{"empresa":"uuid","contas":"[{codigo,nome,natureza,pai}]"}', '{"versao":"text"}', 'Cria ou muda contas do plano comum e das empresas (GE-15)'),
  ('erp-contabil', 'manter_centro_custo', '{"empresa":"uuid","circulo":"int","projeto":"text","acao":"abrir|encerrar"}', '{"centro":"text"}', 'Abre e encerra centros de custo por empresa, círculo e projeto (GE-15)'),
  ('erp-contabil', 'lancar', '{"empresa":"uuid","data":"date","debito":"text","credito":"text","valor":"numeric","centro":"text","historico":"text"}', '{"lancamento":"text"}', 'Lança no razão (GE-03, GE-04, GE-05, GE-06, GE-13, GE-14)'),
  ('erp-contabil', 'titulo', '{"empresa":"uuid","tipo":"pagar|receber","contraparte":"text","valor":"numeric","vencimento":"date","contrato":"text"}', '{"titulo":"text"}', 'Registra título a pagar ou a receber (GE-03, GE-04, GE-14)'),
  ('erp-contabil', 'fechar_periodo', '{"empresa":"uuid|null","periodo":"yyyy-mm"}', '{"situacao":"text"}', 'Fecha o período por empresa ou consolidado (GE-05)'),
  ('erp-contabil', 'demonstracoes', '{"empresa":"uuid|null","periodo":"yyyy-mm","tipo":"balancete|dre|balanco"}', '{"arquivo":"url","dados":"jsonb"}', 'Emite balancete, DRE e balanço (GE-05)'),
  ('erp-contabil', 'realizado_contrato', '{"contrato":"text","periodo":"yyyy-mm"}', '{"receita":"numeric","custo":"numeric","margem":"numeric","caixa":"numeric"}', 'Realizado de um contrato para comparar com o racional (GE-02)'),
  ('emissor-fiscal', 'emitir', '{"empresa":"uuid","cliente":"text","itens":"jsonb","fatura":"text"}', '{"documento":"text","chave":"text","situacao":"text"}', 'Emite o documento fiscal da fatura (GE-03)'),
  ('emissor-fiscal', 'cancelar', '{"documento":"text","motivo":"text"}', '{"situacao":"text"}', 'Cancela o documento dentro do prazo do órgão'),
  ('emissor-fiscal', 'consultar', '{"documento":"text"}', '{"situacao":"text"}', 'Consulta a situação do documento'),
  ('banco', 'extrato', '{"conta":"text","de":"date","ate":"date"}', '{"movimentos":"[{data,valor,historico,id}]"}', 'Lê o extrato para conciliar (GE-03, GE-05)'),
  ('banco', 'pagar', '{"conta":"text","favorecido":"text","valor":"numeric","data":"date","titulo":"text"}', '{"comprovante":"text"}', 'Agenda o pagamento já aprovado na alçada, com a confirmação fora do Telegram (GE-04, GE-05, GE-13, GE-14)'),
  ('banco', 'cobrar', '{"conta":"text","pagador":"text","valor":"numeric","vencimento":"date","titulo":"text"}', '{"cobranca":"text","linha":"text"}', 'Emite a cobrança da fatura (GE-03)')
on conflict (sistema, operacao) do nothing;

-- tarefas novas ganham o vínculo pela regra do executor
insert into rt.vinculo (tarefa, sistema, motor)
  select t.id,
         case t.executor when 'P' then 'canal-pessoa' when 'H' then 'canal-pessoa' when 'A' then 'agente-ia'
                         when 'R' then 'automacao' when 'C' then 'troca-circulo' when 'X' then 'canal-externo' end,
         j.circulo
    from org.tarefa t join org.etapa e on e.id = t.etapa join org.jornada j on j.codigo = e.jornada
   where not exists (select 1 from rt.vinculo v where v.tarefa = t.id);

-- automações das finanças: banco e documento fiscal pelo que fazem; o resto vai ao ERP
update rt.vinculo v set sistema = 'banco' from org.tarefa t join org.etapa e on e.id = t.etapa
 where v.tarefa = t.id and t.executor = 'R' and e.jornada like 'GE-%'
   and t.nome ~* '(conciliar|programar e fazer o pagamento|pagar o reembolso|recolher os impostos|executar e registrar a movimentação|pagar a quitação|pagar a folha|depositar)';
update rt.vinculo v set sistema = 'emissor-fiscal' from org.tarefa t join org.etapa e on e.id = t.etapa
 where v.tarefa = t.id and t.executor = 'R' and t.nome ~* '(documentos? fisca|nota fiscal)';
update rt.vinculo v set sistema = 'erp-contabil' from org.tarefa t join org.etapa e on e.id = t.etapa
 where v.tarefa = t.id and t.executor = 'R' and v.sistema = 'automacao'
   and e.jornada in ('GE-02', 'GE-03', 'GE-04', 'GE-05', 'GE-06', 'GE-12', 'GE-13', 'GE-14', 'GE-15');

alter table rt.adaptador_operacao enable row level security;
drop policy if exists leitura_autenticada on rt.adaptador_operacao;
create policy leitura_autenticada on rt.adaptador_operacao for select to authenticated using (true);
grant select on rt.adaptador_operacao to authenticated; grant all on rt.adaptador_operacao to service_role;

-- 2. Versão nova pelo runtime dos runtimes -------------------------------------------------------------
select rt.publicar_versao('2026-10-03.2',
  'Modelo com 9 círculos, 75 jornadas, 299 etapas, 1.586 tarefas e 411 trocas: GE-14 (dívidas tributárias), GE-15 (estrutura contábil e plano tributário), '
  'racional financeiro na NE-04, planejado x realizado por contrato na GE-02, balancete, DRE e balanço na GE-05. Aprovado em 03/10/2026, às 21:05.')
 where not exists (select 1 from rt.versao_base where versao = '2026-10-03.2');
select rt.concluir_atualizacao(m.circulo, '2026-10-03.2', true,
  'testar.py: integridade, bpmnlint, desenho, rótulos e mutação do círculo verdes; cruzamento 411 trocas sem problema; alçadas 20 sem falta')
  from rt.motor m join rt.atualizacao a on a.motor = m.circulo and a.versao = '2026-10-03.2' and a.estado = 'pendente';

-- 3. E10: os nove motores em piloto, cada um com a sua configuração ------------------------------------
update rt.motor set estado = 'piloto' where estado = 'desenho';
insert into rt.config (motor, chave, valor, origem)
  select c.numero, 'jornadas', (select jsonb_agg(codigo order by codigo) from org.jornada where circulo = c.numero), 'org.jornada' from org.circulo c
on conflict (motor, chave) do update set valor = excluded.valor, atualizado_em = now();
insert into rt.config (motor, chave, valor, origem)
  select m.circulo, x.chave, x.valor, x.origem from rt.motor m cross join (values
    ('canal_padrao', '"telegram"'::jsonb, 'decisão de 17:42 de 03/10/2026: Telegram em 99% das interações'),
    ('autodestruicao_horas', '47'::jsonb, 'o bot só apaga mensagens com menos de 48 horas (Telegram, deleteMessage)'),
    ('fora_do_telegram', '["senhas, chaves e códigos", "relatos da GO-09", "confirmação de pagamento"]'::jsonb, 'plano da fase 2, seção 4'),
    ('simulacao_continua_minutos', '5'::jsonb, 'escolha de 03/10/2026, 21:05: uma execução simulada a cada 5 minutos')) as x(chave, valor, origem)
on conflict (motor, chave) do update set valor = excluded.valor, origem = excluded.origem, atualizado_em = now();

commit;
