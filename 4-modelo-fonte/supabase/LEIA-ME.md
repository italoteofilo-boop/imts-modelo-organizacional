# Base de dados do modelo organizacional (Supabase)

Esquema `org`, em Postgres. Guarda o modelo como foi aprovado em 03/10/2026, com as correções da auditoria geral (16:05): os 9 círculos, as 73 jornadas com etapas, tarefas, decisões, entradas e saídas, as trocas entre círculos, as cadeias, as fontes, as decisões registradas, os parâmetros e os gates de implantação.

## Onde está

Projeto Supabase **imts-modelo-organizacional** (código rzkfolkqdgtounqjjzss), na organização IMTS.OS, região São Paulo. Carregado em 03/10/2026 e recarregado às 17h, depois das correções da auditoria geral; as contagens no banco batem com o modelo, e o verificador de segurança do Supabase não aponta nada.

## Arquivos

- `001_esquema.sql`: tipos, tabelas, índices, visões e segurança.
- `002_carga.sql`: a carga, gerada dos arquivos do modelo.
- `carga_compacta.py` e `lotes/`: a mesma carga em 26 lotes, a forma usada para carregar o Supabase.
- `gerar_tipos.py` e `tipos.ts`: os tipos TypeScript do esquema `org`.
- `gerar_sql.py`: refaz os dois arquivos a partir de `saida/`, a pasta que os scripts do modelo criam ao rodar (no repositório, a cópia publicada dos dados está em `dados-gerados/`). Rode depois de qualquer mudança no modelo: `python3 supabase/gerar_sql.py`.

## Tabelas

| Tabela | O que guarda | Linhas na carga |
|---|---|---|
| circulo | Os 9 círculos | 9 |
| dominio | Domínios de cada círculo | por círculo |
| jornada | As 73 jornadas, com objetivo, cadência e nível de automação | 73 |
| evento | Eventos de início e de fim de cada jornada | por jornada |
| etapa | As 292 etapas, com dono, modo, risco e o tipo que as tarefas dão à etapa | 292 |
| tarefa | As 1.544 tarefas, com executor (P, A, R, H, C, X), raia e condição | 1.544 |
| decisao_caminho | As perguntas que decidem o caminho em cada etapa | por etapa |
| entrada, saida | O que cada etapa recebe e entrega, e de quem ou para quem | por etapa |
| troca | As 409 trocas entre círculos | 409 |
| cadeia, cadeia_elo | As 26 cadeias que substituem as jornadas cross, com 47 elos | 26 e 47 |
| fonte, fonte_uso, jornada_fonte | As fontes, o uso de cada uma em cada círculo e em cada jornada | 65 fontes |
| decisao_registrada | As decisões registradas por círculo | 120 |
| limite | Os limites declarados por círculo | por círculo |
| parametro | Alçadas, cadências, conteúdos e fontes, com o valor aprovado | 72 |
| gate | Os 9 gates de implantação, com a situação | 9 |
| achado_auditoria | Os apontamentos que ficaram da auditoria de execução | 51 |
| empresa, pessoa, atribuicao | Implantação: nascem vazias e são preenchidas nos gates G1 e G2 | 0 |

Visões: `v_etapa` (tarefas de pessoa e de máquina em cada etapa) e `v_jornada` (etapas, tarefas e percentual de máquina em cada jornada).

## Segurança

- A segurança por linha (RLS) está ligada em todas as tabelas.
- Usuário autenticado só lê.
- Só o papel de serviço escreve.
- O papel anônimo não tem acesso.

Uma aplicação que precise escrever, como o cadastro de empresas e pessoas, ganha uma política própria quando for criada.

## Conferência

Testado em 03/10/2026 em Postgres 16 local, antes de cada carga no Supabase. As contagens da carga batem com o modelo:

| Item | Contagem |
|---|---|
| Círculos | 9 |
| Jornadas | 73 |
| Etapas | 292 (Copiloto 139, Autopiloto 62, Assistido 57, Autômato 34) |
| Tarefas | 1.544 |
| Trocas entre círculos | 409 |
| Cadeias e elos | 26 e 47 |
| Parâmetros | 72 (14 alçadas, 39 cadências, 15 conteúdos, 4 fontes) |
| Gates | 9 |

## Para as aplicações lerem

O esquema `org` está liberado na API do projeto desde 03/10/2026. O acesso anônimo é recusado (conferido: "permission denied for schema org"); usuário autenticado lê.

Tipos TypeScript: `tipos.ts`, gerado por `gerar_tipos.py` a partir do `001_esquema.sql` (o gerador do Supabase só cobre o esquema `public`). Uso: `createClient<Database>(url, chave, { db: { schema: 'org' } })`. Os tipos passaram no `tsc --strict`.
