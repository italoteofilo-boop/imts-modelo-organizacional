#!/bin/bash
# Roda todos os testes de navegador do aplicativo (ensaio local já de pé). Sai com erro se algum falhar.
cd "$(dirname "$0")"; r=0
for t in t_entrada t_mesa t_painel t_biblioteca t_acervo t_central t_admin t_portal t_assinatura; do node $t.mjs 2>&1 | tail -1; [ ${PIPESTATUS[0]} -eq 0 ] || r=1; done
exit $r
