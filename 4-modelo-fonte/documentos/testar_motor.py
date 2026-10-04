"""Testes do motor documental (E12). Cada teste emite de verdade (Chromium) e confere o registro e o PDF."""
import copy, json, os, sys, tempfile, io
from playwright.sync_api import sync_playwright
import motor
A = lambda n: json.load(open(os.path.join(motor.AQUI, 'amostras', n)))
ok = []; falhas = []
def t(nome, cond, extra=''):
    (ok if cond else falhas).append(nome); print(('ok   ' if cond else 'FALHA'), nome, extra if not cond else '')

with sync_playwright() as pw, tempfile.TemporaryDirectory() as tmp:
    nav = pw.chromium.launch()
    E = lambda p: motor.emitir(p, tmp, nav)
    # T1 todas as amostras saem sem gate bloqueante
    rs = [E(A(n)) for n in sorted(os.listdir(os.path.join(motor.AQUI, 'amostras')))]
    t('T1 amostras sem bloqueio (10 modelos, 4 marcas)', all(r['situacao'] != 'bloqueado' for r in rs) and len({r['modelo'] for r in rs}) == 10 and len({r['marca'] for r in rs}) == 4, [r['situacao'] for r in rs])
    # T10 metadados institucionais
    from pypdf import PdfReader
    m = PdfReader(os.path.join(tmp, 'amostra-contrato-imts.pdf')).metadata
    t('T10 autor institucional, título e assunto', m['/Author'] == 'IMTS' and m['/Subject'] == 'Contrato de prestação de serviços a cliente')
    c = A('contrato-imts.json')
    # T2 pedido inválido é recusado antes de renderizar
    r = E({**c, 'tipo': 'nao-existe'}); t('T2 tipo fora do catálogo recusado', r['situacao'] == 'recusado')
    r = E({**c, 'data': '04/10/2026'}); t('T3 data fora do formato recusada', r['situacao'] == 'recusado')
    # T4 travessão longo, campo pendente e sinal de modelo bloqueiam
    p = copy.deepcopy(c); p['blocos'][0]['texto'] += ' — com travessão'; r = E(p)
    t('T4 travessão longo bloqueia', r['situacao'] == 'bloqueado' and any('travessão' in g['gate'] for g in r['gates']))
    p = copy.deepcopy(c); p['blocos'][0]['texto'] = 'Valor de [● a definir].'; r = E(p)
    t('T5 campo pendente bloqueia', any('pendente' in g['gate'] for g in r['gates']))
    p = copy.deepcopy(c); p['blocos'][0]['texto'] = 'Olá {{ nome }}'; r = E(p)
    t('T6 sinal de modelo bloqueia', any('modelo' in g['gate'] for g in r['gates']))
    p = copy.deepcopy(c); p['titulo'] = 'Contrato v2.1'; r = E(p)
    t('T7 número de versão bloqueia', any('versão' in g['gate'] for g in r['gates']))
    # T8 marca provisória não sai em documento externo
    p = copy.deepcopy(c); p['marca'] = 'tron'; r = E(p)
    t('T8 marca provisória em documento externo bloqueia', any('provisória' in g['gate'] for g in r['gates']))
    # T9 sumário com páginas reais, crescentes, lidas dos marcadores
    r = rs[[x['id'] for x in rs].index('amostra-contrato-imts')]
    pg = list(r['sumario'].values())
    t('T9 sumário paginado e crescente', len(pg) == 8 and pg == sorted(pg) and pg[-1] == r['paginas'], r['sumario'])
    # T11 regra do terço: parágrafo que não se resolve vira alerta, não some
    t('T11a amostra do contrato sem alerta do terço', r['situacao'] == 'emitido' and not r['alertas'], r['alertas'])
    p = copy.deepcopy(c); p['blocos'].append({'t': 'p', 'texto': 'Código: ' + 'X_' * 60 + ' e.'}); r11 = E(p)
    t('T11b parágrafo sem solução vira alerta do terço', r11['situacao'] == 'emitido_com_alertas' and any(a['alerta'] == 'regra do terço' for a in r11['alertas']), r11['alertas'])
    # T12 texto escondido: palavra cortada do PDF é pega (simula conteúdo cortado por CSS)
    p = copy.deepcopy(c); p['blocos'].append({'t': 'p', 'texto': 'PALAVRAESCONDIDA ao fim.'})
    doc_orig = motor.montar
    def montar_cortado(*a, **k):
        d, cp, it = doc_orig(*a, **k); return d.replace('PALAVRAESCONDIDA', '<span style="display:none">PALAVRAESCONDIDA</span>'), cp, it
    motor.montar = montar_cortado; r = E(p); motor.montar = doc_orig
    t('T12 texto do PDF diferente dos blocos bloqueia', any('diferente' in g['gate'] for g in r['gates']))
    # T13 fontes embutidas e só a família da marca
    import subprocess
    f = subprocess.run(['pdffonts', os.path.join(tmp, 'amostra-contrato-imts.pdf')], capture_output=True, text=True).stdout
    t('T13 uma família tipográfica, embutida', all('OpenSans' in l and ' yes ' in l for l in f.splitlines()[2:]))
    # T14 mesmo pedido, mesmo HTML (reprodutível)
    r1 = E(c); r2 = E(c); t('T14 emissão reprodutível (hash do HTML)', r1['hash_html'] == r2['hash_html'])
    nav.close()
print(f'\n{len(ok)} ok, {len(falhas)} falhas'); sys.exit(1 if falhas else 0)
