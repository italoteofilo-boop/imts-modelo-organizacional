"""Gera supabase/025_motor_documental.sql: esquema doc, catálogo, marcas, modelos, fila e funções do worker."""
import json, os, re
AQUI = os.path.dirname(os.path.abspath(__file__))
q = lambda s: 'null' if s is None else "'" + str(s).replace("'", "''") + "'"
cat = json.load(open(os.path.join(AQUI, 'tipos', 'catalogo.json')))
MODELOS = [('institucional', 'Institucional', False, 'capa, sumário e seções; estratégia, identidade, mandato'),
 ('contratual', 'Contratual', True, 'Legal.OS: quadro de controle, sumário, cláusulas em barras, assinaturas com testemunhas, anexos e parte informativa'),
 ('proposta', 'Proposta comercial', False, 'capa, proposta em uma página, indicadores, investimento, próximos passos'),
 ('licitacao', 'Licitação (B2G)', True, 'dados do certame, sumário, preços e condições, declaração da proponente'),
 ('relatorio', 'Relatório técnico', False, 'capa, sumário, indicadores, análise, recomendações'),
 ('ata', 'Ata e pauta', True, 'campos da reunião, deliberações numeradas, assinaturas de quem preside e secretaria'),
 ('oficio', 'Ofício e correspondência', True, 'referência, local e data, destinatário, assunto, corpo e assinatura única'),
 ('demonstrativo', 'Demonstrativo financeiro', False, 'capa, quadros numéricos com total, nota e assinaturas do contador e do administrador'),
 ('politica', 'Política e manual', True, 'campos de aprovação e vigência, sumário, regras numeradas, papéis'),
 ('certificado', 'Certificado', False, 'A4 paisagem, uma página, moldura da marca')]
def papel(nome):
    n = nome.lower()
    if re.match(r'(redigir|elaborar|escrever|preparar)', n): return 'redige'
    if re.match(r'(assinar)', n): return 'assina'
    if re.match(r'(revisar|consolidar|fechar o texto|conferir)', n): return 'revisa'
    if re.match(r'(emitir|gerar|montar|publicar|expedir|enviar|divulgar|comunicar|lavrar|formalizar|apresentar|documentar|registrar a ata|responder)', n): return 'emite'
    return 'outro'
L = []
A = L.append
A("""-- E12 · Motor documental (aprovado por Ítalo em 04/10/2026). Esquema doc: catálogo de tipos tirado do modelo, marcas, modelos de design,
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
""")
for m in MODELOS: A(f"insert into doc.modelo values ({q(m[0])}, {q(m[1])}, {str(m[2]).lower()}, {q(m[3])}) on conflict (id) do update set nome = excluded.nome, formal = excluded.formal, descricao = excluded.descricao;")
for mid in ('imts', 'onni', 'tron', 'neutra'):
    mj = json.load(open(os.path.join(AQUI, 'marcas', mid, 'marca.json')))
    A(f"insert into doc.marca (id, nome, situacao, dados) values ({q(mid)}, {q(mj['nome'])}, {q(mj['situacao'])}, {q(json.dumps(mj, ensure_ascii=False))}::jsonb) on conflict (id) do update set nome = excluded.nome, situacao = excluded.situacao, dados = excluded.dados, atualizado_em = now();")
for t in cat['tipos']:
    orig = [{k: o[k] for k in ('jornada', 'etapa', 'saida')} for o in t['origens']]
    A(f"insert into doc.tipo values ({q(t['id'])}, {q(t['nome'])}, {q(t['familia'])}, {q(t['modelo'])}, {q(t['alcance'])}, {q(t['regra'])}, 'heuristica', {q(json.dumps(orig, ensure_ascii=False))}::jsonb) on conflict (id) do update set nome = excluded.nome, familia = excluded.familia, modelo = excluded.modelo, alcance = excluded.alcance, regra = excluded.regra, origens = excluded.origens;")
vals = []
for t in cat['tipos']:
    for x in t['tarefas']: vals.append(f"({q(t['id'])}, {q(x['jornada'])}, {x['etapa']}, {q(x['nome'])}, {q(papel(x['nome']))})")
A("-- ligação tipo → tarefa pelo nome da tarefa dentro da etapa (o nome é estável entre versões; a ordem pode mudar)")
A("insert into doc.tipo_tarefa (tipo, tarefa, papel)\n  select v.tipo, t.id, v.papel from (values\n  " + ',\n  '.join(vals) +
  "\n  ) v(tipo, jornada, etapa, nome, papel) join org.etapa e on e.jornada = v.jornada and e.numero = v.etapa join org.tarefa t on t.etapa = e.id and t.nome = v.nome\non conflict do nothing;")
A(open(os.path.join(AQUI, 'doc_funcoes.sql')).read())
A('commit;')
open(os.path.join(AQUI, '..', 'supabase', '025_motor_documental.sql'), 'w').write('\n'.join(L) + '\n')
print(len(vals), 'ligações;', len(cat['tipos']), 'tipos')
