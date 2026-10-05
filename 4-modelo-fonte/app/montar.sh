#!/usr/bin/env bash
# Monta a pasta publicável do aplicativo (dist/) para a hospedagem de www.imts.global.
# Uso: SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<chave publicável> [DESTINO=dist-homologacao] ./montar.sh
# Sai em dist/ (ou DESTINO): páginas, comum/, vendor/, biblioteca/ e um config.js de produção. Testes e documentação de desenvolvimento ficam fora.
set -euo pipefail
cd "$(dirname "$0")"
: "${SUPABASE_URL:?defina SUPABASE_URL}"; : "${SUPABASE_ANON_KEY:?defina SUPABASE_ANON_KEY}"
case "$SUPABASE_ANON_KEY" in *service_role*|sb_secret_*) echo "isso é chave secreta: use a publicável (anon)"; exit 1;; esac
OUT="${DESTINO:-dist}"; case "$OUT" in dist*) ;; *) echo "DESTINO precisa começar com dist"; exit 1;; esac
rm -rf "$OUT" && mkdir "$OUT"
cp ./*.html "$OUT"/ && cp -r comum vendor biblioteca "$OUT"/
cat > "$OUT"/config.js <<CFG
window.IMTS_CONFIG = { supabaseUrl: '${SUPABASE_URL%/}', anonKey: '${SUPABASE_ANON_KEY}', dominio: '${IMTS_DOMINIO:-imts.email}' };
CFG
grep -q "ensaio" "$OUT"/config.js && { echo "config.js de ensaio não pode ir para produção"; exit 1; }
echo "pronto: $(find "$OUT" -type f | wc -l) arquivos em $OUT/"
