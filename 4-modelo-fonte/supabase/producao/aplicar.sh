#!/usr/bin/env bash
# Implantação do banco do IMTS.OS num projeto Supabase NOVO (B11).
# Uso:
#   export DB_URL='postgresql://postgres:<senha>@db.<ref>.supabase.co:5432/postgres'   # Dashboard > Connect > Direct (ou Session pooler)
#   export ADMIN_NOME='Nome Sobrenome' ADMIN_EMAIL='nome@imts.email'
#   export LOGIN_DOMINIOS='imts.email'   # opcional; padrão imts.email
#   ./aplicar.sh            # aplica tudo, cadastra o primeiro administrador, aplica o perfil de produção e confere
#   ./aplicar.sh --conferir # só a conferência
# Para o primeiro erro. Nada aqui imprime ou grava segredo.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"; MIG="$(dirname "$AQUI")"
: "${DB_URL:?defina DB_URL}"
PSQL=(psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q)
conferir() {
  "${PSQL[@]}" -At -c "select i->>'item' || ' | ' || case when (i->>'ok')::boolean then 'ok' else 'FALTA' end || case when coalesce((i->>'externo')::boolean, false) then ' (externo)' else '' end || coalesce(' | ' || nullif(i->>'detalhe', 'null'), '') from jsonb_array_elements(adm.conferir_implantacao()->'itens') i" \
    -c "select 'internos_ok=' || (r->>'internos_ok') || ' pronto=' || (r->>'pronto') from (select adm.conferir_implantacao() r) x"
}
if [ "${1:-}" = "--conferir" ]; then conferir; exit 0; fi
: "${ADMIN_NOME:?defina ADMIN_NOME}"; : "${ADMIN_EMAIL:?defina ADMIN_EMAIL}"

ja=$("${PSQL[@]}" -At -c "select count(*) from pg_namespace where nspname = 'rt'")
if [ "$ja" != "0" ]; then echo "este banco já tem o esquema rt: a implantação é só para projeto novo"; exit 1; fi

echo "== extensões"; "${PSQL[@]}" -f "$AQUI/000_extensoes.sql"
echo "== migrações"
# 012a_org_novo.sql é ferramenta de troca de versão do modelo (carrega org_novo), não faz parte da implantação
for f in $(ls "$MIG"/[0-9][0-9][0-9]_*.sql | sort -V); do
  "${PSQL[@]}" -f "$f" > /dev/null; echo "ok $(basename "$f")"
done
echo "== domínios aceitos no login"
# LOGIN_DOMINIOS: lista separada por vírgula; padrão imts.email (Workspace do IMTS)
"${PSQL[@]}" -At -v doms="${LOGIN_DOMINIOS:-imts.email}" <<< "update adm.parametro set valor = to_jsonb(string_to_array(replace(:'doms', ' ', ''), ',')) where chave = 'login.dominios' returning 'login.dominios = ' || valor::text;"
echo "== primeiro administrador"
"${PSQL[@]}" -At -v nome="$ADMIN_NOME" -v email="$ADMIN_EMAIL" <<< "select 'pessoa ' || adm.primeiro_administrador(:'nome', :'email');"
echo "== perfil de produção"; "${PSQL[@]}" -f "$AQUI/090_perfil_producao.sql" > /dev/null; echo "ok 090_perfil_producao.sql"
echo "== conferência"; conferir
