-- E12 · Motor documental (aprovado por Ítalo em 04/10/2026). Esquema doc: catálogo de tipos tirado do modelo, marcas, modelos de design,
-- fila de pedidos para o worker (Chromium), emissões com hash, gates e alertas, aprovação em duas mãos e trilha de eventos.
-- Gerado por documentos/gerar_sql.py a partir de documentos/tipos/catalogo.json e documentos/marcas/*/marca.json.
begin;
create schema if not exists doc;
revoke all on schema doc from anon;
grant usage on schema doc to authenticated, service_role;

create table if not exists doc.marca (id text primary key, nome text not null, situacao text not null check (situacao in ('oficial','provisoria','neutra')),
  dados jsonb not null, atualizado_em timestamptz not null default now());
create table if not exists doc.modelo (id text primary key, nome text not null, formal boolean not null, descricao text not null);
create table if not exists doc.tipo (id text primary key, nome text not null, familia text not null, modelo text not null references doc.modelo(id),
  alcance text not null check (alcance in ('interno','externo')), regra text not null, ligacao text not null default 'heuristica',
  origens jsonb not null default '[]');
create table if not exists doc.tipo_tarefa (tipo text not null references doc.tipo(id), tarefa bigint not null references org.tarefa(id),
  papel text not null check (papel in ('redige','revisa','emite','assina','outro')), primary key (tipo, tarefa));

create table if not exists doc.pedido (
  id bigint generated always as identity primary key,
  tipo text not null references doc.tipo(id), marca text not null references doc.marca(id), modelo text references doc.modelo(id),
  empresa uuid references org.empresa(id), tarefa bigint references org.tarefa(id), instancia bigint,
  conteudo jsonb not null, pedido_por uuid, criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
  situacao text not null default 'na_fila' check (situacao in ('na_fila','em_emissao','emitido','emitido_com_alertas','bloqueado','recusado','erro','aprovado','reprovado')),
  tentativas smallint not null default 0, worker text, erro text);
create index if not exists pedido_fila on doc.pedido (criado_em) where situacao = 'na_fila';

create table if not exists doc.emissao (
  id bigint generated always as identity primary key, pedido bigint not null references doc.pedido(id),
  situacao text not null check (situacao in ('emitido','emitido_com_alertas','bloqueado','recusado')),
  paginas int, hash_pedido text, hash_pdf text, hash_html text, gates jsonb not null default '[]', alertas jsonb not null default '[]',
  registro jsonb not null, worker text, emitido_em timestamptz not null default now());
create table if not exists doc.arquivo (emissao bigint not null references doc.emissao(id), formato text not null check (formato in ('pdf','html')),
  conteudo bytea not null, sha256 text not null, bytes int not null, primary key (emissao, formato));
create table if not exists doc.aprovacao (
  id bigint generated always as identity primary key, emissao bigint not null references doc.emissao(id),
  etapa text not null check (etapa in ('analise','aprovacao')), pessoa uuid not null, decisao text not null check (decisao in ('aprovado','reprovado')),
  motivo text, decidido_em timestamptz not null default now(),
  check (decisao = 'aprovado' or coalesce(length(trim(motivo)), 0) > 0));
create table if not exists doc.evento (id bigint generated always as identity primary key, pedido bigint references doc.pedido(id),
  tipo text not null, dados jsonb not null default '{}', em timestamptz not null default now());

insert into doc.modelo values ('institucional', 'Institucional', false, 'capa, sumário e seções; estratégia, identidade, mandato') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('contratual', 'Contratual', true, 'Legal.OS: quadro de controle, sumário, cláusulas em barras, assinaturas com testemunhas, anexos e parte informativa') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('proposta', 'Proposta comercial', false, 'capa, proposta em uma página, indicadores, investimento, próximos passos') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('licitacao', 'Licitação (B2G)', true, 'dados do certame, sumário, preços e condições, declaração da proponente') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('relatorio', 'Relatório técnico', false, 'capa, sumário, indicadores, análise, recomendações') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('ata', 'Ata e pauta', true, 'campos da reunião, deliberações numeradas, assinaturas de quem preside e secretaria') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('oficio', 'Ofício e correspondência', true, 'referência, local e data, destinatário, assunto, corpo e assinatura única') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('demonstrativo', 'Demonstrativo financeiro', false, 'capa, quadros numéricos com total, nota e assinaturas do contador e do administrador') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('politica', 'Política e manual', true, 'campos de aprovação e vigência, sumário, regras numeradas, papéis') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.modelo values ('certificado', 'Certificado', false, 'A4 paisagem, uma página, moldura da marca') on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;
insert into doc.marca (id, nome, situacao, dados) values ('imts', 'IMTS', 'oficial', '{"id": "imts", "nome": "IMTS", "razao_social": null, "cnpj": null, "situacao": "oficial", "fonte": "Manual da Marca IMTS 2025, transcrito na skill imts-editorial (references/marca.md); logos de assets/logos", "cores": {"primaria": "#023ED8", "texto": "#272829", "fundo": "#FFFFFF", "destaque": "#ED8A15", "apoio": "#3F64FA", "apoio2": "#2D4FFA", "barra": "#D9D9D9", "linha": "#7F7F7F"}, "tipografia": {"texto": "Open Sans", "display": "Michroma", "fallback": "system-ui, sans-serif"}, "logos": {"horizontal": "logos/Logo_Horizontal_IMTS_Blue.png", "horizontal_negativo": "logos/Logo_Horizontal_IMTS_White.png", "horizontal_positivo": "logos/Logo_Horizontal_IMTS_Black.png", "simbolo": "logos/Simbolo_IMTS_Black.png", "simbolo_negativo": "logos/Simbolo_IMTS_White.png"}, "logo_regras": {"arejamento": 0.15, "largura_minima_cm": 3.0}, "autor_institucional": "IMTS", "rodape_aprovacao": {"etapas": ["Preenchimento", "Análise Crítica e Validação", "Aprovação"], "areas": ["Área de Compliance", "Assessoria Jurídica", "Liderança Corporativa"]}, "marca_dagua": null, "regras": ["Laranja Disruptivo: no máximo um elemento por página", "Michroma só em títulos de modelos não formais; modelos formais usam uma família (Open Sans)", "corpo em Grafite Digital, nunca azul em corpo pequeno"], "inferencias": ["rodapé de aprovação: padrão Legal.OS aplicado à IMTS, a confirmar", "razão social e CNPJ ausentes: a informar"]}'::jsonb) on conflict (id) do update set nome = excluded.nome, situacao = excluded.situacao, dados = excluded.dados, atualizado_em = now();
insert into doc.marca (id, nome, situacao, dados) values ('onni', 'Onni.ai', 'oficial', '{"id": "onni", "nome": "Onni.ai", "razao_social": "ONNI.AI INTELIGÊNCIA, GOVERNANÇA E TECNOLOGIA S.A.", "cnpj": null, "situacao": "oficial", "fonte": "Manual de Identidade Visual Onni.ai V2.0 (maio/2026), cores e tipografia conforme informado por Ítalo; rodapé \"Liderança Corporativa\" conforme regra editorial de 25/09/2026", "cores": {"primaria": "#23405B", "texto": "#00141C", "fundo": "#FFFFFF", "destaque": "#13574B", "apoio": "#6D7B86", "apoio2": "#8E6141", "claro": "#E8F0F7", "barra": "#E8F0F7", "linha": "#6D7B86"}, "tipografia": {"texto": "Poppins", "display": "Poppins", "fallback": "system-ui, sans-serif", "oficial": "Nexa (Black em títulos, Regular em texto)", "substituicao": "Nexa indisponível aqui: Poppins no lugar, declarado em cada emissão"}, "logos": null, "logo_regras": null, "autor_institucional": "Onni.ai", "rodape_aprovacao": {"etapas": ["Preenchimento", "Análise Crítica e Validação", "Aprovação"], "areas": ["Área de Compliance", "Assessoria Jurídica", "Liderança Corporativa"]}, "marca_dagua": null, "regras": ["sem logotipo até receber os arquivos oficiais: o nome entra em texto, nunca redesenhado"], "inferencias": ["papéis das cores no documento (títulos em Slate Blue, texto em Onni Dark, barra em Off-White) são escolha do motor, não do manual", "CNPJ ausente: a informar"]}'::jsonb) on conflict (id) do update set nome = excluded.nome, situacao = excluded.situacao, dados = excluded.dados, atualizado_em = now();
insert into doc.marca (id, nome, situacao, dados) values ('tron', 'TRON', 'provisoria', '{"id": "tron", "nome": "TRON", "razao_social": null, "cnpj": null, "situacao": "provisoria", "fonte": "sem manual de marca disponível; pacote provisório com tokens neutros", "cores": {"primaria": "#3A3A3A", "texto": "#1F1F1F", "fundo": "#FFFFFF", "destaque": "#3A3A3A", "apoio": "#6B6B6B", "apoio2": "#6B6B6B", "barra": "#E6E6E6", "linha": "#7F7F7F"}, "tipografia": {"texto": "Open Sans", "display": "Open Sans", "fallback": "system-ui, sans-serif"}, "logos": null, "logo_regras": null, "autor_institucional": "TRON", "rodape_aprovacao": {"etapas": ["Preenchimento", "Análise Crítica e Validação", "Aprovação"], "areas": ["Área de Compliance", "Assessoria Jurídica", "Liderança Corporativa"]}, "marca_dagua": "MARCA PROVISÓRIA", "regras": ["não emitir documento externo com esta marca até o manual oficial"], "inferencias": ["todas as cores e a fonte são neutras e provisórias, nenhuma é da marca TRON"]}'::jsonb) on conflict (id) do update set nome = excluded.nome, situacao = excluded.situacao, dados = excluded.dados, atualizado_em = now();
insert into doc.marca (id, nome, situacao, dados) values ('neutra', 'Ecossistema', 'neutra', '{"id": "neutra", "nome": "Ecossistema", "razao_social": null, "cnpj": null, "situacao": "neutra", "fonte": "skill editorial-legal-os, references/tipografia.md (padrão Legal.OS)", "cores": {"primaria": "#000000", "texto": "#000000", "fundo": "#FFFFFF", "destaque": "#000000", "apoio": "#404040", "apoio2": "#404040", "barra": "#D9D9D9", "linha": "#7F7F7F"}, "tipografia": {"texto": "Open Sans", "display": "Open Sans", "fallback": "system-ui, sans-serif"}, "logos": null, "logo_regras": null, "autor_institucional": "Ecossistema IMTS", "rodape_aprovacao": {"etapas": ["Preenchimento", "Análise Crítica e Validação", "Aprovação"], "areas": ["Área de Compliance", "Assessoria Jurídica", "Liderança Corporativa"]}, "marca_dagua": null, "regras": ["marca do motor (white label) quando o documento não tem empresa"], "inferencias": []}'::jsonb) on conflict (id) do update set nome = excluded.nome, situacao = excluded.situacao, dados = excluded.dados, atualizado_em = now();
insert into doc.tipo values ('contrato-cliente', 'Contrato de prestação de serviços a cliente', 'contratual', 'contratual', 'externo', 'contrato de cliente|contrato assinado|contratos? (encerrad|vencimento|com vencimento)|vencimento do contrato', 'heuristica', '[{"jornada": "NE-04", "etapa": 3, "saida": "Contrato assinado e guardado"}, {"jornada": "NE-04", "etapa": 4, "saida": "Contrato de cliente assinado, com o escopo vendido"}, {"jornada": "NE-05", "etapa": 4, "saida": "Contrato de cliente assinado, com o escopo vendido"}, {"jornada": "NE-06", "etapa": 1, "saida": "Vencimento do contrato e resultado da renovação"}, {"jornada": "NE-06", "etapa": 3, "saida": "Contratos encerrados ou transferidos na saída"}, {"jornada": "NE-06", "etapa": 5, "saida": "Contrato de cliente assinado, com o escopo vendido"}, {"jornada": "NE-06", "etapa": 5, "saida": "Contrato encerrado, com a data de fim"}, {"jornada": "NE-06", "etapa": 5, "saida": "Vencimento do contrato e resultado da renovação"}, {"jornada": "GO-05", "etapa": 2, "saida": "Contratos com vencimento e obrigações"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('contrato-fornecedor', 'Contrato com fornecedor', 'contratual', 'contratual', 'externo', 'contrato de fornecedor|contrato de tecnologia', 'heuristica', '[{"jornada": "IT-07", "etapa": 3, "saida": "Contrato de tecnologia para guardar"}, {"jornada": "GE-04", "etapa": 2, "saida": "Contrato de fornecedor para revisar e guardar"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('aditivo', 'Termo aditivo, renovação ou distrato', 'contratual', 'contratual', 'externo', 'aditivo|renovacao, aditivo|encerramento assinado|distrato', 'heuristica', '[{"jornada": "NE-06", "etapa": 4, "saida": "Renovação, aditivo, contratação ou encerramento assinado"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('acordo-parceria', 'Acordo de parceria ou de oferta conjunta', 'contratual', 'contratual', 'externo', 'acordo de oferta conjunta|termos da parceria|encerramento de parceria', 'heuristica', '[{"jornada": "NE-07", "etapa": 2, "saida": "Acordo de oferta conjunta entre as empresas"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('contrato-societario', 'Contrato de compra e venda de participação', 'contratual', 'contratual', 'externo', 'contrato de compra ou venda', 'heuristica', '[{"jornada": "ES-05", "etapa": 5, "saida": "Contrato de compra ou venda assinado"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('licenca-marca', 'Autorização de uso de marca', 'contratual', 'contratual', 'externo', 'autorizac\w* de uso da marca|uso da marca por terceiros', 'heuristica', '[{"jornada": "ID-02", "etapa": 4, "saida": "Regra de uso da marca por terceiros"}, {"jornada": "RE-06", "etapa": 5, "saida": "Autorizações de uso da marca por terceiros, com prazo"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('acordo-servico', 'Acordo de serviço entre círculos ou empresas', 'contratual', 'contratual', 'interno', 'acordo de servico', 'heuristica', '[{"jornada": "IT-05", "etapa": 2, "saida": "Ficha da capacidade: método, conhecimento, executor, ferramentas, acordo de serviço e indicador"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('termo-negociacao', 'Termo de pagamento, parcelamento ou transação', 'contratual', 'contratual', 'externo', 'parcelamento|transacao formalizad|termos negociados', 'heuristica', '[{"jornada": "ES-05", "etapa": 3, "saida": "Resultado da apuração e termos negociados"}, {"jornada": "GE-14", "etapa": 2, "saida": "Pagamento, parcelamento ou transação formalizado, com as condições"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('proposta-comercial', 'Proposta comercial', 'proposta', 'proposta', 'externo', 'proposta (aprovada para envio|aceita|de renovacao)|modelos de proposta|proposta comercial', 'heuristica', '[{"jornada": "NE-03", "etapa": 3, "saida": "Proposta aprovada para envio"}, {"jornada": "NE-03", "etapa": 4, "saida": "Proposta aceita ou em negociação"}, {"jornada": "NE-06", "etapa": 1, "saida": "Proposta de renovação, expansão ou retenção"}, {"jornada": "GO-01", "etapa": 3, "saida": "Modelos de proposta e de contrato"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('proposta-interna', 'Proposta para decisão (memorando)', 'relatorio', 'institucional', 'interno', '^proposta', 'heuristica', '[{"jornada": "ID-01", "etapa": 2, "saida": "Proposta de declaração"}, {"jornada": "ID-01", "etapa": 3, "saida": "Proposta validada"}, {"jornada": "ID-04", "etapa": 2, "saida": "Proposta de posicionamento"}, {"jornada": "ES-01", "etapa": 3, "saida": "Proposta de estratégia, com as hipóteses, o método e as divergências"}, {"jornada": "ES-02", "etapa": 2, "saida": "Proposta de alocação e de destino do resultado"}, {"jornada": "ES-03", "etapa": 3, "saida": "Proposta de alvos e iniciativas, com o orçamento da Gestão e as alternativas"}, {"jornada": "ES-05", "etapa": 4, "saida": "Proposta de estrutura"}, {"jornada": "RE-01", "etapa": 2, "saida": "Proposta de plano de demanda"}, {"jornada": "RE-04", "etapa": 2, "saida": "Proposta de estratégia de experiência"}, {"jornada": "NE-05", "etapa": 2, "saida": "Proposta e habilitação prontas para a disputa"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('racional-financeiro', 'Racional financeiro de contrato', 'demonstrativo', 'demonstrativo', 'interno', 'racional financeiro|condicoes acordadas', 'heuristica', '[{"jornada": "NE-04", "etapa": 1, "saida": "Condições acordadas com o cliente"}, {"jornada": "NE-04", "etapa": 2, "saida": "Condições acordadas e racional financeiro do contrato"}, {"jornada": "NE-04", "etapa": 4, "saida": "Racional financeiro do contrato aprovado"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('proposta-b2g', 'Proposta de preço e habilitação em licitação', 'licitacao', 'licitacao', 'externo', 'habilitac|edital|licitac|pregao|proposta de preco', 'heuristica', '[{"jornada": "NE-03", "etapa": 1, "saida": "Edital ou pedido de cotação de órgão público"}, {"jornada": "NE-05", "etapa": 1, "saida": "Edital analisado, com a decisão de participar"}, {"jornada": "GO-04", "etapa": 2, "saida": "Certidões e documentos de habilitação em dia"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('arp', 'Ata de registro de preços', 'licitacao', 'licitacao', 'externo', 'ata de registro de precos', 'heuristica', '[{"jornada": "NE-05", "etapa": 4, "saida": "Ata de registro de preços vigente, com saldo e órgãos participantes"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('ata', 'Ata de reunião ou de deliberação', 'ata', 'ata', 'interno', '^ata\b|deliberac|decisao dos socios|decididos? pelo comite|acoes do ritual', 'heuristica', '[{"jornada": "ID-01", "etapa": 4, "saida": "Decisão dos sócios registrada"}, {"jornada": "ID-02", "etapa": 3, "saida": "Decisão dos sócios sobre critérios e limites"}, {"jornada": "ES-01", "etapa": 4, "saida": "Decisão dos sócios sobre a estratégia"}, {"jornada": "ES-03", "etapa": 4, "saida": "Decisão dos sócios sobre alvos e orçamento"}, {"jornada": "ES-05", "etapa": 5, "saida": "Decisão dos sócios sobre a empresa"}, {"jornada": "ES-06", "etapa": 3, "saida": "Revisão aberta para decisão dos sócios: alvos, portfólio ou estratégia"}, {"jornada": "GE-02", "etapa": 3, "saida": "Ações do ritual, com dono e prazo"}, {"jornada": "GE-02", "etapa": 4, "saida": "Situação das ações do ritual"}, {"jornada": "GO-08", "etapa": 2, "saida": "Declaração, posição e encerramento da crise decididos pelo comitê"}, {"jornada": "GO-08", "etapa": 3, "saida": "Declaração, posição e encerramento da crise decididos pelo comitê"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('pauta', 'Pauta e convocação', 'ata', 'ata', 'interno', 'pauta|convocac', 'heuristica', '[{"jornada": "RE-07", "etapa": 1, "saida": "Pauta decidida, com o alvo de cada tema"}, {"jornada": "GE-02", "etapa": 1, "saida": "Pauta do ritual com os desvios e os donos"}, {"jornada": "GE-11", "etapa": 1, "saida": "Pauta e calendário aprovados"}, {"jornada": "GO-02", "etapa": 1, "saida": "Pauta e matérias preparadas"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('politica', 'Política', 'politica', 'politica', 'interno', 'politica', 'heuristica', '[{"jornada": "NE-01", "etapa": 2, "saida": "Tabela e política decididas"}, {"jornada": "NE-01", "etapa": 3, "saida": "Tabela de preços e política comercial vigentes"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('regra-alcadas', 'Regras e alçadas', 'politica', 'politica', 'interno', 'alcadas|regra de uso|^regras? (vigente|aprovad)', 'heuristica', '[{"jornada": "GO-01", "etapa": 3, "saida": "Regras e alçadas vigentes"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('manual-metodo', 'Manual, método ou padrão', 'politica', 'politica', 'interno', 'manual|metodo|padroes|^padrao|kit\b|guia\b|protocolo de crise', 'heuristica', '[{"jornada": "ID-02", "etapa": 2, "saida": "Padrões redigidos"}, {"jornada": "ID-02", "etapa": 3, "saida": "Padrões testados e casos de teste"}, {"jornada": "ID-02", "etapa": 4, "saida": "Padrões de identidade vigentes"}, {"jornada": "ID-02", "etapa": 4, "saida": "Kit de cultura e pessoas"}, {"jornada": "ID-02", "etapa": 4, "saida": "Protocolo de crise"}, {"jornada": "ID-05", "etapa": 4, "saida": "Resumo da avaliação dos padrões"}, {"jornada": "ES-01", "etapa": 2, "saida": "Escolhas estratégicas, portfólio-alvo, hipóteses e método do Ecossistema"}, {"jornada": "ES-01", "etapa": 5, "saida": "Método de estratégia vigente: critérios dos portões, regras de realocação e calendário"}, {"jornada": "IN-06", "etapa": 2, "saida": "Método descrito, com critério de sucesso e casos de teste"}, {"jornada": "IN-06", "etapa": 3, "saida": "Método testado, com o resultado medido"}, {"jornada": "IN-06", "etapa": 4, "saida": "Método publicado, com versão e data de revisão"}, {"jornada": "IN-06", "etapa": 4, "saida": "Kit do método para agentes: passos, conhecimento, casos de teste e critério de sucesso"}, {"jornada": "IN-06", "etapa": 5, "saida": "Decisão de rever o método"}, {"jornada": "IN-06", "etapa": 5, "saida": "Resultado da avaliação do método"}, {"jornada": "IN-07", "etapa": 4, "saida": "Solução, método de entrega e entregáveis"}, {"jornada": "IN-07", "etapa": 9, "saida": "Oferta no catálogo de ofertas: escopo, método, conteúdo-base, preço-base e indicadores"}, {"jornada": "RE-04", "etapa": 4, "saida": "Estratégia de experiência do cliente: personas, mapa da jornada e padrões de experiência"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('mandato', 'Mandato da empresa', 'politica', 'politica', 'interno', '^mandato', 'heuristica', '[{"jornada": "ES-05", "etapa": 6, "saida": "Mandato da empresa"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('declaracao-identidade', 'Declaração de identidade', 'politica', 'institucional', 'externo', 'declaracao de identidade|essencia da marca', 'heuristica', '[{"jornada": "ID-01", "etapa": 5, "saida": "Declaração de identidade vigente"}, {"jornada": "ID-03", "etapa": 3, "saida": "Essência da marca e nome aprovado"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('estrategia', 'Documento de estratégia', 'relatorio', 'institucional', 'interno', '^estrategia vigente|hipoteses da estrategia', 'heuristica', '[{"jornada": "ES-01", "etapa": 5, "saida": "Estratégia vigente do Ecossistema e das empresas"}, {"jornada": "ES-01", "etapa": 5, "saida": "Hipóteses da estratégia e sinais a vigiar"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('plano-contas', 'Plano de contas e plano tributário', 'demonstrativo', 'demonstrativo', 'interno', 'plano de contas|plano tributario', 'heuristica', '[{"jornada": "GE-15", "etapa": 1, "saida": "Plano de contas e centros de custo vigentes"}, {"jornada": "GE-15", "etapa": 2, "saida": "Plano tributário do grupo e regras das operações entre empresas"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('plano', 'Plano (estratégico, de ação, de saída, de correção)', 'relatorio', 'relatorio', 'interno', '^plano (de|da|do)|^planejamento', 'heuristica', '[{"jornada": "IN-01", "etapa": 1, "saida": "Plano de leitura: perguntas, sinais, fontes e critério de aviso"}, {"jornada": "RE-01", "etapa": 3, "saida": "Plano de demanda aprovado"}, {"jornada": "RE-01", "etapa": 4, "saida": "Plano de demanda do ciclo: públicos, ofertas, canais, ações, alvos e orçamento"}, {"jornada": "RE-05", "etapa": 1, "saida": "Plano de sucesso do cliente: resultados esperados, marcos e contatos"}, {"jornada": "RE-05", "etapa": 3, "saida": "Plano de recuperação do cliente"}, {"jornada": "NE-02", "etapa": 3, "saida": "Plano de vendas do ciclo: alvos por empresa, oferta e canal"}, {"jornada": "NE-02", "etapa": 3, "saida": "Plano de conta dos clientes-chave"}, {"jornada": "IT-02", "etapa": 1, "saida": "Plano de implantação do cliente"}, {"jornada": "IT-03", "etapa": 1, "saida": "Plano de lançamento da oferta"}, {"jornada": "IT-04", "etapa": 1, "saida": "Plano de saída da oferta: clientes e contratos"}, {"jornada": "IT-04", "etapa": 1, "saida": "Plano de saída: clientes, contratos e pessoas"}, {"jornada": "IT-04", "etapa": 1, "saida": "Plano de saída de clientes e contratos"}, {"jornada": "OP-01", "etapa": 2, "saida": "Plano de capacidade decidido"}, {"jornada": "OP-01", "etapa": 3, "saida": "Plano de capacidade de entrega: pessoas, parceiros, materiais e ativos"}, {"jornada": "OP-02", "etapa": 1, "saida": "Plano de entrega do cliente"}, {"jornada": "OP-08", "etapa": 1, "saida": "Plano de fim das entregas"}, {"jornada": "OP-06", "etapa": 1, "saida": "Plano de produção e de materiais"}, {"jornada": "GE-09", "etapa": 2, "saida": "Plano de desenvolvimento ligado ao propósito"}, {"jornada": "GO-03", "etapa": 2, "saida": "Plano de remediação, com dono e prazo"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('diagnostico', 'Diagnóstico, estudo ou análise', 'relatorio', 'relatorio', 'interno', '^diagnostico|^estudo|^analise|^sintese', 'heuristica', '[{"jornada": "ID-04", "etapa": 1, "saida": "Síntese de insumos"}, {"jornada": "ES-01", "etapa": 1, "saida": "Diagnóstico estratégico"}, {"jornada": "ES-01", "etapa": 4, "saida": "Diagnóstico e decisão de manter a estratégia"}, {"jornada": "ES-02", "etapa": 4, "saida": "Estudo de saída pedido para empresa, oferta ou aposta"}, {"jornada": "IN-01", "etapa": 3, "saida": "Análise de mercado por pergunta e hipótese"}, {"jornada": "RE-01", "etapa": 1, "saida": "Diagnóstico de demanda do ciclo"}, {"jornada": "NE-01", "etapa": 1, "saida": "Diagnóstico de preço das ofertas"}, {"jornada": "GO-10", "etapa": 2, "saida": "Análise do impacto"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('relatorio', 'Relatório de resultado ou de situação', 'relatorio', 'relatorio', 'interno', '^relatorio|^resultado|^situacao da|^avaliacao', 'heuristica', '[{"jornada": "ID-05", "etapa": 2, "saida": "Relatório de alinhamento"}, {"jornada": "ES-04", "etapa": 2, "saida": "Avaliação da aposta com recomendação"}, {"jornada": "ES-04", "etapa": 3, "saida": "Situação da carteira de apostas"}, {"jornada": "ES-04", "etapa": 4, "saida": "Situação da carteira de apostas"}, {"jornada": "ES-04", "etapa": 5, "saida": "Situação da carteira de apostas"}, {"jornada": "ES-05", "etapa": 7, "saida": "Situação da execução do mandato"}, {"jornada": "ES-06", "etapa": 4, "saida": "Resultado da revisão da estratégia"}, {"jornada": "IN-01", "etapa": 5, "saida": "Avaliação de uso da leitura"}, {"jornada": "IN-04", "etapa": 4, "saida": "Resultado da revisão dos indicadores, com as contestações de indicador de alvo vigente"}, {"jornada": "IN-06", "etapa": 3, "saida": "Resultado do teste em caso real"}, {"jornada": "IN-07", "etapa": 6, "saida": "Resultado do piloto com clientes"}, {"jornada": "IN-08", "etapa": 4, "saida": "Resultado das melhorias conferidas"}, {"jornada": "RE-02", "etapa": 3, "saida": "Resultado das ações de demanda por canal e oferta"}, {"jornada": "RE-04", "etapa": 1, "saida": "Avaliação da experiência, com lacunas e causas"}, {"jornada": "RE-05", "etapa": 3, "saida": "Resultado apresentado e avaliação do cliente"}, {"jornada": "RE-06", "etapa": 4, "saida": "Resultado da parceria"}, {"jornada": "RE-07", "etapa": 4, "saida": "Resultado da comunicação externa"}, {"jornada": "NE-05", "etapa": 3, "saida": "Resultado favorável da disputa"}, {"jornada": "NE-07", "etapa": 3, "saida": "Resultado da venda com parceiros e conjunta"}, {"jornada": "IT-01", "etapa": 3, "saida": "Situação das iniciativas na carteira de projetos"}, {"jornada": "IT-06", "etapa": 2, "saida": "Resultado dos testes e do monitoramento dos agentes"}, {"jornada": "IT-06", "etapa": 4, "saida": "Resultado dos testes e do monitoramento dos agentes"}, {"jornada": "OP-07", "etapa": 4, "saida": "Relatórios do recall para a autoridade"}, {"jornada": "GE-05", "etapa": 2, "saida": "Resultado por empresa e consolidado"}, {"jornada": "GE-09", "etapa": 3, "saida": "Resultado da pesquisa de cultura e dados de pessoas"}, {"jornada": "GO-03", "etapa": 2, "saida": "Resultado dos testes de controle"}, {"jornada": "GO-03", "etapa": 3, "saida": "Relatório de riscos e conformidade"}, {"jornada": "GO-06", "etapa": 4, "saida": "Resultado da auditoria externa da Governança, com as correções decididas"}, {"jornada": "GO-06", "etapa": 5, "saida": "Resultado da auditoria das entregas"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('parecer', 'Parecer', 'parecer', 'relatorio', 'interno', 'parecer|conformidade|^revisao', 'heuristica', '[{"jornada": "ID-01", "etapa": 1, "saida": "Parecer de revisão"}, {"jornada": "ES-06", "etapa": 2, "saida": "Revisão sem correção registrada"}, {"jornada": "ES-06", "etapa": 3, "saida": "Revisão aberta dos alvos"}, {"jornada": "ES-06", "etapa": 3, "saida": "Revisão aberta do portfólio"}, {"jornada": "ES-06", "etapa": 3, "saida": "Revisão aberta da estratégia"}, {"jornada": "OP-05", "etapa": 2, "saida": "Não conformidades e tendências, com a evidência"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('auditoria', 'Relatório de auditoria ou de apuração', 'parecer', 'relatorio', 'interno', 'auditoria|apuracao', 'heuristica', '[{"jornada": "ID-02", "etapa": 4, "saida": "Critérios de auditoria e casos de teste"}, {"jornada": "GO-06", "etapa": 3, "saida": "Desvio de agente apontado pela auditoria"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('demonstracoes', 'Demonstrações contábeis (DRE, balancete, balanço)', 'demonstrativo', 'demonstrativo', 'externo', 'demonstrac|balancete|balanco|\bdre\b', 'heuristica', '[{"jornada": "GE-05", "etapa": 2, "saida": "Demonstrações e obrigações fiscais do período"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('orcamento', 'Orçamento e previsão financeira', 'demonstrativo', 'demonstrativo', 'interno', 'orcamento|previsao (financeira|de caixa)|planejado|rateio', 'heuristica', '[{"jornada": "GE-01", "etapa": 1, "saida": "Orçamento desdobrado, com dono por linha"}, {"jornada": "GE-01", "etapa": 1, "saida": "Orçamento de demanda do ciclo"}, {"jornada": "GE-01", "etapa": 2, "saida": "Orçamento ajustado"}, {"jornada": "GE-01", "etapa": 3, "saida": "Orçamento vigente por empresa, círculo, oferta e aposta"}, {"jornada": "GE-05", "etapa": 2, "saida": "Execução do orçamento e da alocação por empresa, oferta e aposta"}, {"jornada": "GE-06", "etapa": 1, "saida": "Rateio calculado"}, {"jornada": "GE-06", "etapa": 2, "saida": "Rateio do custo dos círculos por empresa"}, {"jornada": "GO-01", "etapa": 3, "saida": "Critério de rateio do custo dos círculos"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('fatura', 'Fatura e cobrança', 'demonstrativo', 'demonstrativo', 'externo', 'fatura emitida|pedido de cobranca do fornecedor', 'heuristica', '[{"jornada": "GE-03", "etapa": 2, "saida": "Fatura emitida"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('folha', 'Folha e demonstrativo de pagamento', 'demonstrativo', 'demonstrativo', 'interno', 'folha', 'heuristica', '[{"jornada": "GE-13", "etapa": 1, "saida": "Folha apurada"}, {"jornada": "GE-13", "etapa": 2, "saida": "Folha e encargos pagos"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('ordem-compra', 'Ordem de compra a fornecedor', 'oficio', 'oficio', 'externo', 'pedido emitido ao fornecedor|ordem de compra', 'heuristica', '[]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('resposta-titular', 'Resposta a titular de dados (LGPD)', 'oficio', 'oficio', 'externo', 'resposta ao titular|pedido do titular cumprido', 'heuristica', '[{"jornada": "GO-07", "etapa": 3, "saida": "Resposta ao titular"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('resposta-externa', 'Resposta a cliente, parceiro ou público', 'oficio', 'oficio', 'externo', 'resposta ao (parceiro|relato|pedido de uso)|comunicacao da posicao|solucao aplicada ao cliente', 'heuristica', '[{"jornada": "RE-06", "etapa": 5, "saida": "Resposta ao pedido de uso da marca"}, {"jornada": "RE-08", "etapa": 3, "saida": "Comunicação da posição sobre a crise"}, {"jornada": "NE-07", "etapa": 1, "saida": "Resposta ao parceiro sobre a oportunidade"}, {"jornada": "OP-07", "etapa": 2, "saida": "Solução aplicada ao cliente"}, {"jornada": "GO-09", "etapa": 5, "saida": "Resposta ao relato"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('comunicado', 'Comunicado interno', 'oficio', 'oficio', 'interno', '^comunicado|a comunicar$|^aviso de mudanca', 'heuristica', '[{"jornada": "IN-01", "etapa": 3, "saida": "Aviso de mudança relevante de cenário"}, {"jornada": "OP-07", "etapa": 3, "saida": "Fato a comunicar"}, {"jornada": "GE-10", "etapa": 4, "saida": "Histórias e reconhecimentos a comunicar"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('notificacao', 'Notificação formal', 'oficio', 'oficio', 'externo', 'notificac|retirada de marca|suspensao de novas entregas', 'heuristica', '[{"jornada": "GE-03", "etapa": 3, "saida": "Suspensão de novas entregas por atraso, decidida pelo executivo"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('certificado', 'Certificado de reconhecimento', 'certificado', 'certificado', 'interno', 'reconhecimento', 'heuristica', '[{"jornada": "GE-10", "etapa": 2, "saida": "Reconhecimentos aprovados"}, {"jornada": "GE-10", "etapa": 4, "saida": "Reconhecimentos concedidos"}]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
insert into doc.tipo values ('declaracao', 'Declaração', 'certificado', 'certificado', 'externo', '^declaracao(?! de identidade)', 'heuristica', '[]'::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;
-- ligação tipo → tarefa pelo nome da tarefa dentro da etapa (o nome é estável entre versões; a ordem pode mudar)
insert into doc.tipo_tarefa (tipo, tarefa, papel)
  select v.tipo, t.id, v.papel from (values
  ('contrato-cliente', 'NE-04', 3, 'Redigir o contrato no modelo, com o escopo vendido e as condições acordadas', 'redige'),
  ('contrato-cliente', 'NE-04', 3, 'Assinar o contrato em nome da empresa', 'assina'),
  ('contrato-cliente', 'NE-04', 3, 'Assinar o contrato', 'assina'),
  ('contrato-cliente', 'NE-05', 4, 'Assinar o contrato com o órgão em nome da empresa', 'assina'),
  ('contrato-cliente', 'NE-05', 4, 'Assinar a ata de registro de preços em nome da empresa', 'assina'),
  ('contrato-cliente', 'NE-05', 4, 'Assinar o contrato da adesão em nome da empresa', 'assina'),
  ('contrato-cliente', 'NE-05', 4, 'Responder ao órgão não participante que a empresa não adere, com o motivo', 'emite'),
  ('contrato-cliente', 'NE-06', 1, 'Preparar a proposta de renovação, aditivo ou retenção com o histórico, o plano de conta e a tabela', 'redige'),
  ('contrato-cliente', 'NE-06', 1, 'Responder à consulta sobre a proposta de renovação não coberta pelos padrões', 'emite'),
  ('contrato-fornecedor', 'GE-04', 2, 'Emitir o pedido ao fornecedor e informar a data de entrega a quem pediu', 'emite'),
  ('aditivo', 'NE-06', 4, 'Redigir a renovação, o aditivo, o contrato pela ata ou o termo de encerramento, no modelo', 'redige'),
  ('aditivo', 'NE-06', 4, 'Assinar o documento em nome da empresa', 'assina'),
  ('aditivo', 'NE-06', 4, 'Assinar o documento pelo cliente, quando a forma pede', 'assina'),
  ('acordo-parceria', 'NE-07', 2, 'Formalizar o acordo entre as empresas: divisão de receita, responsabilidade e rateio', 'emite'),
  ('contrato-societario', 'ES-05', 5, 'Redigir a lição do caso que os sócios decidiram arquivar, sem dado sigiloso', 'redige'),
  ('contrato-societario', 'ES-05', 5, 'Redigir a lição do caso que os sócios decidiram não seguir, sem dado sigiloso', 'redige'),
  ('contrato-societario', 'ES-05', 5, 'Preparar o contrato de compra ou venda dentro do que os sócios decidiram', 'redige'),
  ('contrato-societario', 'ES-05', 5, 'Assinar o contrato de compra ou venda', 'assina'),
  ('contrato-societario', 'ES-05', 5, 'Redigir a lição do caso em que o contrato não foi assinado, sem o que é confidencial', 'redige'),
  ('licenca-marca', 'ID-02', 4, 'Montar o conjunto de padrões de cada círculo que executa', 'emite'),
  ('licenca-marca', 'RE-06', 5, 'Responder à consulta sobre o uso fora da regra', 'emite'),
  ('termo-negociacao', 'ES-05', 3, 'Consolidar o resultado da apuração para decidir se o caso segue', 'revisa'),
  ('termo-negociacao', 'ES-05', 3, 'Redigir a lição do caso arquivado depois da apuração, sem o que é confidencial', 'redige'),
  ('termo-negociacao', 'GE-14', 2, 'Formalizar o pagamento, o parcelamento ou a transação e registrar as condições', 'emite'),
  ('proposta-comercial', 'NE-03', 3, 'Redigir a proposta no modelo, com o escopo, o preço, as condições e a validade', 'redige'),
  ('proposta-comercial', 'NE-03', 3, 'Responder à consulta sobre a proposta não coberta pelos padrões', 'emite'),
  ('proposta-comercial', 'NE-03', 4, 'Enviar a proposta ao cliente e registrar o envio', 'emite'),
  ('proposta-comercial', 'NE-06', 1, 'Preparar a proposta de renovação, aditivo ou retenção com o histórico, o plano de conta e a tabela', 'redige'),
  ('proposta-comercial', 'NE-06', 1, 'Responder à consulta sobre a proposta de renovação não coberta pelos padrões', 'emite'),
  ('proposta-interna', 'ID-01', 3, 'Consolidar objeções e ajustes', 'revisa'),
  ('proposta-interna', 'ES-01', 3, 'Montar o rascunho da estratégia de cada empresa a partir das escolhas do Ecossistema', 'emite'),
  ('proposta-interna', 'ES-02', 2, 'Montar a proposta de alocação e de destino do resultado, mesmo quando é manter a atual', 'emite'),
  ('proposta-interna', 'ES-03', 3, 'Montar o orçamento do ciclo a partir dos alvos e da alocação', 'emite'),
  ('proposta-interna', 'ES-03', 3, 'Montar as alternativas de alvos e de recursos para decisão dos sócios', 'emite'),
  ('proposta-interna', 'RE-04', 2, 'Responder à consulta sobre a experiência não coberta pelos padrões', 'emite'),
  ('proposta-interna', 'NE-05', 2, 'Montar a proposta e a parte técnica, quando houver, nas regras do edital', 'emite'),
  ('proposta-interna', 'NE-05', 2, 'Responder à consulta sobre a proposta de licitação não coberta pelos padrões', 'emite'),
  ('proposta-interna', 'NE-05', 2, 'Assinar a proposta e os documentos pedidos no edital em nome da empresa', 'assina'),
  ('racional-financeiro', 'NE-04', 2, 'Montar o racional financeiro do contrato: receita, custos, margem, impostos e caixa por período', 'emite'),
  ('proposta-b2g', 'NE-05', 1, 'Preparar a resposta à cotação com o preço pela tabela e pela política, sem disputa', 'redige'),
  ('proposta-b2g', 'GO-04', 2, 'Preparar o pedido, a renovação, a transferência ou a baixa', 'redige'),
  ('arp', 'NE-05', 4, 'Assinar o contrato com o órgão em nome da empresa', 'assina'),
  ('arp', 'NE-05', 4, 'Assinar a ata de registro de preços em nome da empresa', 'assina'),
  ('arp', 'NE-05', 4, 'Assinar o contrato da adesão em nome da empresa', 'assina'),
  ('arp', 'NE-05', 4, 'Responder ao órgão não participante que a empresa não adere, com o motivo', 'emite'),
  ('ata', 'ES-05', 5, 'Redigir a lição do caso que os sócios decidiram arquivar, sem dado sigiloso', 'redige'),
  ('ata', 'ES-05', 5, 'Redigir a lição do caso que os sócios decidiram não seguir, sem dado sigiloso', 'redige'),
  ('ata', 'ES-05', 5, 'Preparar o contrato de compra ou venda dentro do que os sócios decidiram', 'redige'),
  ('ata', 'ES-05', 5, 'Assinar o contrato de compra ou venda', 'assina'),
  ('ata', 'ES-05', 5, 'Redigir a lição do caso em que o contrato não foi assinado, sem o que é confidencial', 'redige'),
  ('ata', 'GE-02', 3, 'Apresentar os desvios e propor as ações', 'emite'),
  ('ata', 'GO-08', 3, 'Consolidar as lições e as causas', 'revisa'),
  ('politica', 'NE-01', 3, 'Preparar o material de venda das ofertas novas ou mudadas com o pacote de marca', 'redige'),
  ('politica', 'NE-01', 3, 'Responder à consulta sobre o material de venda não coberto pelos padrões', 'emite'),
  ('politica', 'NE-01', 3, 'Publicar a tabela, a política comercial e o material de venda com versão e vigência', 'emite'),
  ('manual-metodo', 'ID-02', 4, 'Montar o conjunto de padrões de cada círculo que executa', 'emite'),
  ('manual-metodo', 'ID-05', 4, 'Publicar o resumo e avisar quem forneceu dados', 'emite'),
  ('manual-metodo', 'ES-01', 2, 'Montar opções estratégicas e simular as consequências de cada uma', 'emite'),
  ('manual-metodo', 'ES-01', 2, 'Escrever as hipóteses de cada escolha e os sinais que as confirmam ou refutam', 'redige'),
  ('manual-metodo', 'ES-01', 5, 'Publicar a estratégia, o portfólio-alvo, as hipóteses e o método', 'emite'),
  ('manual-metodo', 'IN-06', 2, 'Escrever o critério de sucesso e os casos de teste do método', 'redige'),
  ('manual-metodo', 'IN-06', 2, 'Responder à consulta sobre o método não coberto', 'emite'),
  ('manual-metodo', 'IN-06', 4, 'Montar o kit para agentes: passos, conhecimento, casos de teste e critério de sucesso', 'emite'),
  ('manual-metodo', 'IN-06', 4, 'Publicar o método com versão, classificação e data de revisão', 'emite'),
  ('manual-metodo', 'IN-07', 4, 'Montar alternativas de solução e comparar com as ofertas existentes', 'emite'),
  ('manual-metodo', 'RE-04', 4, 'Publicar a estratégia de experiência com versão e data de revisão', 'emite'),
  ('mandato', 'ES-05', 6, 'Redigir o mandato: objetivo, estrutura, recursos, prazos e donos', 'redige'),
  ('mandato', 'ES-05', 6, 'Enviar o mandato a cada círculo que executa', 'emite'),
  ('declaracao-identidade', 'ID-03', 3, 'Gerar a essência da marca e nomes candidatos', 'emite'),
  ('estrategia', 'ES-01', 5, 'Publicar a estratégia, o portfólio-alvo, as hipóteses e o método', 'emite'),
  ('plano-contas', 'GE-15', 2, 'Preparar a proposta de plano tributário para quem decide', 'redige'),
  ('plano', 'RE-05', 1, 'Preparar com Operações e Integração a transição, sem avisar os clientes ainda', 'redige'),
  ('plano', 'RE-05', 3, 'Montar o relatório de resultado do cliente contra o plano de sucesso', 'emite'),
  ('plano', 'RE-05', 3, 'Responder à consulta sobre o relatório não coberto pelos padrões', 'emite'),
  ('plano', 'RE-05', 3, 'Apresentar ao cliente o resultado e ouvir a avaliação dele', 'emite'),
  ('plano', 'NE-02', 3, 'Publicar o plano de vendas do ciclo, os planos de conta e a previsão com versão e data', 'emite'),
  ('plano', 'IT-02', 1, 'Montar o cronograma, os riscos e a lista de requisitos a partir do escopo vendido', 'emite'),
  ('plano', 'OP-01', 3, 'Publicar o plano e o mapa de capacidade usados para confirmar propostas e implantações', 'emite'),
  ('plano', 'OP-02', 1, 'Montar ou ajustar o plano de entrega: entregas, nível de serviço, equipe, agentes e contatos', 'emite'),
  ('plano', 'OP-08', 1, 'Preparar o fim das entregas pelo plano e aguardar a data de saída', 'redige'),
  ('plano', 'OP-06', 1, 'Montar a previsão de demanda por produto e conferir com a previsão de vendas e os contratos', 'emite'),
  ('plano', 'GE-09', 2, 'Escrever a declaração de propósito e escolher o que compartilha', 'redige'),
  ('plano', 'GO-03', 2, 'Montar o plano de remediação com o dono, o prazo e a causa', 'emite'),
  ('diagnostico', 'ES-01', 1, 'Enviar as perguntas do diagnóstico à Inteligência', 'emite'),
  ('diagnostico', 'ES-02', 4, 'Enviar a alocação decidida ao desdobramento dos alvos', 'emite'),
  ('diagnostico', 'ES-02', 4, 'Comunicar o estudo de saída ao executivo afetado', 'emite'),
  ('diagnostico', 'IN-01', 3, 'Emitir o aviso de mudança relevante a quem decide', 'emite'),
  ('relatorio', 'ES-04', 2, 'Enviar à Inteligência a pergunta de decisão do portão, com o risco e o prazo', 'emite'),
  ('relatorio', 'ES-04', 3, 'Apresentar a avaliação e a recomendação a quem decide', 'emite'),
  ('relatorio', 'ES-04', 3, 'Enviar a decisão de encerrar a quem desenha, vende e entrega, para parar novas vendas', 'emite'),
  ('relatorio', 'ES-04', 4, 'Enviar a data de saída a quem desenha, vende, entrega e coordena o plano de saída', 'emite'),
  ('relatorio', 'IN-01', 5, 'Publicar a leitura conforme a classificação e avisar quem depende dela', 'emite'),
  ('relatorio', 'IN-07', 6, 'Montar a versão mínima da oferta para o piloto, com a solução e o método descrito', 'emite'),
  ('relatorio', 'IN-07', 6, 'Responder à consulta sobre a versão mínima não coberta pelos padrões', 'emite'),
  ('relatorio', 'IN-07', 6, 'Enviar à Estratégia a evidência de que o piloto não é viável e a recomendação', 'emite'),
  ('relatorio', 'IN-07', 6, 'Preparar a proposta e o termo de piloto no modelo de contrato', 'redige'),
  ('relatorio', 'IN-07', 6, 'Enviar à Estratégia a evidência do piloto e a recomendação de encerrar', 'emite'),
  ('relatorio', 'IN-08', 4, 'Publicar o resultado das melhorias conferidas', 'emite'),
  ('relatorio', 'RE-05', 3, 'Montar o relatório de resultado do cliente contra o plano de sucesso', 'emite'),
  ('relatorio', 'RE-05', 3, 'Responder à consulta sobre o relatório não coberto pelos padrões', 'emite'),
  ('relatorio', 'RE-05', 3, 'Apresentar ao cliente o resultado e ouvir a avaliação dele', 'emite'),
  ('relatorio', 'RE-07', 4, 'Publicar o conteúdo aprovado nos canais da empresa e enviar à imprensa, no calendário', 'emite'),
  ('relatorio', 'NE-05', 3, 'Enviar a proposta e os documentos pelo meio e no prazo do edital', 'emite'),
  ('relatorio', 'NE-05', 3, 'Apresentar contrarrazões ao recurso do concorrente', 'emite'),
  ('relatorio', 'NE-05', 3, 'Apresentar o recurso da empresa', 'emite'),
  ('relatorio', 'OP-07', 4, 'Enviar à autoridade os relatórios do recall', 'emite'),
  ('relatorio', 'GE-05', 2, 'Emitir o balancete, a DRE e o balanço de cada empresa e o consolidado', 'emite'),
  ('relatorio', 'GO-03', 2, 'Montar o plano de remediação com o dono, o prazo e a causa', 'emite'),
  ('relatorio', 'GO-03', 3, 'Consolidar o relatório de riscos, conformidade e remediações', 'revisa'),
  ('relatorio', 'GO-03', 3, 'Publicar o relatório aos sócios e à Estratégia', 'emite'),
  ('relatorio', 'GO-06', 5, 'Publicar o resultado da auditoria', 'emite'),
  ('parecer', 'ID-01', 1, 'Consolidar evidências e apontar lacunas', 'revisa'),
  ('parecer', 'ES-06', 2, 'Enviar à Inteligência a pergunta sobre as causas propostas, com o risco e o prazo', 'emite'),
  ('auditoria', 'ID-02', 4, 'Montar o conjunto de padrões de cada círculo que executa', 'emite'),
  ('demonstracoes', 'GE-05', 2, 'Emitir o balancete, a DRE e o balanço de cada empresa e o consolidado', 'emite'),
  ('orcamento', 'GE-01', 2, 'Responder a quem pediu, com o motivo', 'emite'),
  ('orcamento', 'GE-01', 3, 'Publicar o orçamento vigente a cada dono e aos registros de compra e de pagamento', 'emite'),
  ('orcamento', 'GE-05', 2, 'Emitir o balancete, a DRE e o balanço de cada empresa e o consolidado', 'emite'),
  ('orcamento', 'GE-06', 2, 'Publicar e lançar o rateio nas contas de cada empresa', 'emite'),
  ('fatura', 'GE-03', 2, 'Emitir a fatura e os documentos fiscais e enviá-los ao cliente', 'emite'),
  ('resposta-titular', 'GO-07', 3, 'Responder ao titular, com os motivos do que não procede', 'emite'),
  ('resposta-externa', 'RE-06', 5, 'Responder à consulta sobre o uso fora da regra', 'emite'),
  ('resposta-externa', 'RE-08', 3, 'Redigir a comunicação da posição decidida, no protocolo de crise e nos padrões', 'redige'),
  ('resposta-externa', 'RE-08', 3, 'Publicar a comunicação e acompanhar a reação dos públicos', 'emite'),
  ('resposta-externa', 'NE-07', 1, 'Responder ao parceiro com o motivo', 'emite'),
  ('resposta-externa', 'GO-09', 5, 'Responder a quem relatou', 'emite'),
  ('comunicado', 'IN-01', 3, 'Emitir o aviso de mudança relevante a quem decide', 'emite'),
  ('comunicado', 'OP-07', 3, 'Comunicar o risco à autoridade competente', 'emite')
  ) v(tipo, jornada, etapa, nome, papel) join org.etapa e on e.jornada = v.jornada and e.numero = v.etapa join org.tarefa t on t.etapa = e.id and t.nome = v.nome
on conflict do nothing;

-- Sistema do motor documental, contrato da interface e vínculo das automações que emitem documento ---------------------
insert into rt.sistema (codigo, nome, atende, descricao) values
  ('motor-documental', 'Motor documental (PDF e HTML)', 'R', 'Emite os documentos formais internos e externos das empresas: catálogo de tipos, marca por empresa, modelos de design, gates editoriais, registro com hash e aprovação em duas mãos')
on conflict (codigo) do nothing;
insert into rt.adaptador_operacao (sistema, operacao, entrada, saida, descricao) values
  ('motor-documental', 'emitir', '{"tipo":"text","marca":"text","empresa":"uuid|null","conteudo":"jsonb (titulo, data, local, blocos, anexos, assinaturas)"}', '{"pedido":"bigint"}', 'Põe o pedido na fila do worker (doc.pedir)'),
  ('motor-documental', 'situacao', '{"pedido":"bigint"}', '{"situacao":"text","emissao":"bigint","gates":"jsonb","alertas":"jsonb"}', 'Lê a situação do pedido e da última emissão'),
  ('motor-documental', 'decidir', '{"emissao":"bigint","etapa":"analise|aprovacao","decisao":"aprovado|reprovado","motivo":"text"}', '{"aprovacao":"bigint"}', 'Análise crítica e aprovação, por pessoas diferentes de quem pediu (doc.decidir)')
on conflict (sistema, operacao) do nothing;
-- automações que hoje emitem documento passam ao motor documental; agentes continuam redigindo, pessoas continuam assinando
update rt.vinculo v set sistema = 'motor-documental'
  from doc.tipo_tarefa tt join org.tarefa t on t.id = tt.tarefa
 where v.tarefa = tt.tarefa and tt.papel = 'emite' and t.executor = 'R' and v.sistema = 'automacao'
   and t.nome ~* '^(publicar|emitir|gerar|lavrar|expedir|responder|enviar a proposta)';

-- Funções ------------------------------------------------------------------------------------------------------------
create or replace function doc._evento(p_pedido bigint, p_tipo text, p_dados jsonb default '{}') returns void
language sql security definer set search_path = '' as $$ insert into doc.evento (pedido, tipo, dados) values (p_pedido, p_tipo, p_dados) $$;

-- quem chama pelo app precisa de acesso "operar" na empresa; sem identidade, só o service_role (motor, testes)
create or replace function doc.pedir(p_tipo text, p_marca text, p_conteudo jsonb, p_empresa uuid default null, p_tarefa bigint default null,
  p_instancia bigint default null, p_modelo text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_eu uuid := rt.eu(); v_tipo doc.tipo; v_marca doc.marca; v_id bigint;
begin
  if v_eu is null and coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'service_role') <> 'service_role' then raise exception 'pedido sem identidade'; end if;
  if v_eu is not null and not rt.pode(v_eu, p_empresa, null, 'operar') then raise exception 'sem acesso para pedir documento nesta empresa'; end if;
  select * into v_tipo from doc.tipo where id = p_tipo; if not found then raise exception 'tipo fora do catálogo: %', p_tipo; end if;
  select * into v_marca from doc.marca where id = p_marca; if not found then raise exception 'marca sem pacote: %', p_marca; end if;
  if v_marca.situacao = 'provisoria' and v_tipo.alcance = 'externo' then raise exception 'marca provisória não emite documento externo (%)', p_tipo; end if;
  if p_modelo is not null and not exists (select 1 from doc.modelo where id = p_modelo) then raise exception 'modelo desconhecido: %', p_modelo; end if;
  if coalesce(p_conteudo->>'titulo', '') = '' or coalesce(p_conteudo->>'data', '') = '' or coalesce(p_conteudo->>'local', '') = '' then
    raise exception 'conteúdo sem título, data ou local'; end if;
  insert into doc.pedido (tipo, marca, modelo, empresa, tarefa, instancia, conteudo, pedido_por)
  values (p_tipo, p_marca, p_modelo, p_empresa, p_tarefa, p_instancia, p_conteudo, v_eu) returning id into v_id;
  perform doc._evento(v_id, 'pedido', jsonb_build_object('tipo', p_tipo, 'marca', p_marca, 'por', v_eu));
  return v_id;
end $$;

create or replace function doc._chave_ok(p_chave text) returns boolean language sql stable security definer set search_path = '' as $$
  select p_chave is not null and length(p_chave) >= 32 and p_chave = rt._segredo('doc_worker_chave') $$;

-- worker: pega o próximo pedido (um por vez, sem disputa entre workers)
create or replace function doc.worker_proximo(p_chave text, p_worker text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v doc.pedido;
begin
  if not doc._chave_ok(p_chave) then raise exception 'não autorizado'; end if;
  update doc.pedido set situacao = 'em_emissao', worker = p_worker, atualizado_em = now()
   where id = (select id from doc.pedido where situacao = 'na_fila' order by criado_em for update skip locked limit 1)
  returning * into v;
  if v.id is null then return null; end if;
  perform doc._evento(v.id, 'em_emissao', jsonb_build_object('worker', p_worker));
  return v.conteudo || jsonb_build_object('id', 'pedido-' || v.id, 'tipo', v.tipo, 'marca', v.marca, 'pedido', v.id)
                    || case when v.modelo is not null then jsonb_build_object('modelo', v.modelo) else '{}'::jsonb end;
end $$;

create or replace function doc.worker_registrar(p_chave text, p_pedido bigint, p_registro jsonb, p_pdf text, p_html text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_em bigint; v_sit text := p_registro->>'situacao'; v_pdf bytea; v_html bytea;
begin
  if not doc._chave_ok(p_chave) then raise exception 'não autorizado'; end if;
  if not exists (select 1 from doc.pedido where id = p_pedido and situacao = 'em_emissao') then raise exception 'pedido % não está em emissão', p_pedido; end if;
  if v_sit = 'recusado' then
    update doc.pedido set situacao = 'recusado', erro = p_registro->>'erros', atualizado_em = now() where id = p_pedido;
    perform doc._evento(p_pedido, 'recusado', p_registro); return null;
  end if;
  v_pdf := decode(p_pdf, 'base64'); v_html := decode(p_html, 'base64');
  if encode(extensions.digest(v_pdf, 'sha256'), 'hex') <> p_registro->>'hash_pdf' then raise exception 'hash do PDF não confere'; end if;
  insert into doc.emissao (pedido, situacao, paginas, hash_pedido, hash_pdf, hash_html, gates, alertas, registro, worker)
  values (p_pedido, v_sit, (p_registro->>'paginas')::int, p_registro->>'hash_pedido', p_registro->>'hash_pdf', p_registro->>'hash_html',
          coalesce(p_registro->'gates', '[]'), coalesce(p_registro->'alertas', '[]'), p_registro, (select worker from doc.pedido where id = p_pedido))
  returning id into v_em;
  insert into doc.arquivo values (v_em, 'pdf', v_pdf, p_registro->>'hash_pdf', length(v_pdf)),
                                 (v_em, 'html', v_html, encode(extensions.digest(v_html, 'sha256'), 'hex'), length(v_html));
  update doc.pedido set situacao = v_sit, erro = null, atualizado_em = now() where id = p_pedido;
  perform doc._evento(p_pedido, v_sit, jsonb_build_object('emissao', v_em, 'gates', jsonb_array_length(coalesce(p_registro->'gates', '[]')),
                                                          'alertas', jsonb_array_length(coalesce(p_registro->'alertas', '[]'))));
  return v_em;
end $$;

create or replace function doc.worker_falhar(p_chave text, p_pedido bigint, p_erro text) returns text
language plpgsql security definer set search_path = '' as $$
declare v_sit text;
begin
  if not doc._chave_ok(p_chave) then raise exception 'não autorizado'; end if;
  update doc.pedido set tentativas = tentativas + 1, erro = left(p_erro, 2000), atualizado_em = now(),
         situacao = case when tentativas + 1 >= 3 then 'erro' else 'na_fila' end
   where id = p_pedido and situacao = 'em_emissao' returning situacao into v_sit;
  perform doc._evento(p_pedido, 'falha', jsonb_build_object('erro', left(p_erro, 500), 'situacao', v_sit));
  return v_sit;
end $$;

-- pedido preso em emissão (worker caiu) volta para a fila depois de 15 minutos
create or replace function doc.destravar() returns int language sql security definer set search_path = '' as $$
  with x as (update doc.pedido set situacao = 'na_fila', worker = null, atualizado_em = now()
              where situacao = 'em_emissao' and atualizado_em < now() - interval '15 minutes' returning id)
  select count(*)::int from x $$;

-- análise crítica e aprovação: duas mãos, nunca quem pediu; bloqueado não se submete; alerta mantido exige justificativa
create or replace function doc.decidir(p_emissao bigint, p_etapa text, p_decisao text, p_motivo text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_eu uuid := rt.eu(); e doc.emissao; p doc.pedido; v_id bigint;
begin
  if v_eu is null then raise exception 'decisão sem identidade'; end if;
  select * into e from doc.emissao where id = p_emissao; if not found then raise exception 'emissão inexistente'; end if;
  select * into p from doc.pedido where id = e.pedido;
  if not rt.pode(v_eu, p.empresa, null, 'aprovar') then raise exception 'sem alçada para decidir documento nesta empresa'; end if;
  if e.id <> (select max(id) from doc.emissao where pedido = p.id) then raise exception 'há emissão mais nova deste pedido'; end if;
  if e.situacao in ('bloqueado', 'recusado') then raise exception 'emissão % não pode ser submetida', e.situacao; end if;
  if p.pedido_por = v_eu then raise exception 'quem pediu não decide o próprio documento'; end if;
  if p_decisao = 'aprovado' and jsonb_array_length(e.alertas) > 0 and coalesce(length(trim(p_motivo)), 0) = 0 then
    raise exception 'há alertas tipográficos: justifique a manutenção no motivo'; end if;
  if p_etapa = 'aprovacao' then
    if not exists (select 1 from doc.aprovacao where emissao = e.id and etapa = 'analise' and decisao = 'aprovado') then raise exception 'falta a análise crítica'; end if;
    if exists (select 1 from doc.aprovacao where emissao = e.id and etapa = 'analise' and pessoa = v_eu) then raise exception 'quem analisou não aprova'; end if;
  end if;
  insert into doc.aprovacao (emissao, etapa, pessoa, decisao, motivo) values (e.id, p_etapa, v_eu, p_decisao, p_motivo) returning id into v_id;
  if p_decisao = 'reprovado' then update doc.pedido set situacao = 'reprovado', atualizado_em = now() where id = p.id;
  elsif p_etapa = 'aprovacao' then update doc.pedido set situacao = 'aprovado', atualizado_em = now() where id = p.id; end if;
  perform doc._evento(p.id, p_etapa || ':' || p_decisao, jsonb_build_object('emissao', e.id, 'por', v_eu));
  return v_id;
end $$;

create or replace view doc.v_fila with (security_invoker = true) as
  select situacao, count(*) as pedidos, min(criado_em) as mais_antigo from doc.pedido group by situacao;

-- Entrada pública do worker (PostgREST só expõe public): protegida pela chave do Vault doc_worker_chave -----------------
create or replace function public.doc_worker_proximo(p_chave text, p_worker text) returns jsonb language sql security definer set search_path = '' as $$ select doc.worker_proximo(p_chave, p_worker) $$;
create or replace function public.doc_worker_registrar(p_chave text, p_pedido bigint, p_registro jsonb, p_pdf text, p_html text) returns bigint language sql security definer set search_path = '' as $$ select doc.worker_registrar(p_chave, p_pedido, p_registro, p_pdf, p_html) $$;
create or replace function public.doc_worker_falhar(p_chave text, p_pedido bigint, p_erro text) returns text language sql security definer set search_path = '' as $$ select doc.worker_falhar(p_chave, p_pedido, p_erro) $$;

-- Segurança ------------------------------------------------------------------------------------------------------------
do $$ declare t text; begin
  foreach t in array array['marca','modelo','tipo','tipo_tarefa','pedido','emissao','arquivo','aprovacao','evento'] loop
    execute format('alter table doc.%I enable row level security', t);
    execute format('drop policy if exists leitura on doc.%I', t);
  end loop;
end $$;
create policy leitura on doc.marca for select to authenticated using (true);
create policy leitura on doc.modelo for select to authenticated using (true);
create policy leitura on doc.tipo for select to authenticated using (true);
create policy leitura on doc.tipo_tarefa for select to authenticated using (true);
create policy leitura on doc.pedido for select to authenticated using (rt.pode(rt.eu(), empresa, null, 'ler'));
create policy leitura on doc.emissao for select to authenticated using (exists (select 1 from doc.pedido p where p.id = pedido and rt.pode(rt.eu(), p.empresa, null, 'ler')));
create policy leitura on doc.arquivo for select to authenticated using (exists (select 1 from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = emissao and rt.pode(rt.eu(), p.empresa, null, 'ler')));
create policy leitura on doc.aprovacao for select to authenticated using (exists (select 1 from doc.emissao e join doc.pedido p on p.id = e.pedido where e.id = emissao and rt.pode(rt.eu(), p.empresa, null, 'ler')));
create policy leitura on doc.evento for select to authenticated using (exists (select 1 from doc.pedido p where p.id = pedido and rt.pode(rt.eu(), p.empresa, null, 'ler')));
grant select on all tables in schema doc to authenticated;
grant all on all tables in schema doc to service_role;
revoke all on all functions in schema doc from public;
grant execute on function doc.pedir(text, text, jsonb, uuid, bigint, bigint, text), doc.decidir(bigint, text, text, text) to authenticated, service_role;
grant execute on function doc.destravar(), doc.worker_proximo(text, text), doc.worker_registrar(text, bigint, jsonb, text, text), doc.worker_falhar(text, bigint, text) to service_role;
revoke all on function public.doc_worker_proximo(text, text), public.doc_worker_registrar(text, bigint, jsonb, text, text), public.doc_worker_falhar(text, bigint, text) from public;
grant execute on function public.doc_worker_proximo(text, text), public.doc_worker_registrar(text, bigint, jsonb, text, text), public.doc_worker_falhar(text, bigint, text) to anon, authenticated, service_role;

commit;
