"""Monta a página de administração: modelo.html + retrato do adm.painel() embutido (usado quando o conector do Supabase não responde).
Uso: python3 gerar.py [retrato.json] > admin.html"""
import json, os, sys
AQUI = os.path.dirname(os.path.abspath(__file__))
r = open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(AQUI, 'retrato_admin.json')).read().strip()
json.loads(r)
print(open(os.path.join(AQUI, 'modelo.html')).read().replace('/*RETRATO*/null', r.replace('</', '<\\/')))
