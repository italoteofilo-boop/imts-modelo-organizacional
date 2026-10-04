#!/usr/bin/env bash
# Monta a pasta publicável do aplicativo (dist/) para a hospedagem de www.imts.global.
# Uso: SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<chave publicável> ./montar.sh
# Sai em dist/: páginas, comum/, vendor/, biblioteca/ e um config.js de produção. Testes e documentação de desenvolvimento ficam fora.
set -euo pipefail
cd "$(dirname "$0")"
: "${SUPABASE_URL:?defina SUPABASE_URL}"; : "${SUPABASE_ANON_KEY:?defina SUPABASE_ANON_KEY}"
case "$SUPABASE_ANON_KEY" in *service_role*|sb_secret_*) echo "isso é chave secreta: use a publicável (anon)"; exit 1;; esac
rm -rf dist && mkdir dist
cp ./*.html dist/ && cp -r comum vendor biblioteca dist/
cat > dist/config.js <<CFG
window.IMTS_CONFIG = { supabaseUrl: '${SUPABASE_URL%/}', anonKey: '${SUPABASE_ANON_KEY}', dominio: '${IMTS_DOMINIO:-imts.com.br}' };
CFG
grep -q "ensaio" dist/config.js && { echo "config.js de ensaio não pode ir para produção"; exit 1; }
echo "pronto: $(find dist -type f | wc -l) arquivos em dist/"
