"""Emite todas as amostras com um navegador só e imprime a situação de cada uma."""
import glob, json, os, sys
from playwright.sync_api import sync_playwright
import motor
saida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(motor.AQUI, 'saida', 'amostras')
with sync_playwright() as pw:
    nav = pw.chromium.launch()
    res = []
    for arq in sorted(glob.glob(os.path.join(motor.AQUI, 'amostras', '*.json'))):
        r = motor.emitir(json.load(open(arq)), saida, nav)
        res.append(r)
        print(f"{r.get('id', arq):34} {r['situacao']:20} {r.get('paginas', '-'):>2} p  ajustes {r.get('ajustes_terco', '-')}  gates {[g['gate'] for g in r.get('gates', [])]}  alertas {[a['onde'][:50] for a in r.get('alertas', [])]} {r.get('erros', '')}")
    nav.close()
