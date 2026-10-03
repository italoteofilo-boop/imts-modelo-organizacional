# -*- coding: utf-8 -*-
"""Contingência das fontes legais. Guarda e confere o texto literal dos dispositivos citados no modelo.

Uso:
  python3 conferir_fontes.py            confere o retrato local: hash de cada trecho e as afirmações do modelo
  python3 conferir_fontes.py --online   também baixa cada URL e confere se o trecho continua igual (precisa de rede)

O retrato (trechos.json) foi tirado em 03/10/2026 no navegador, com a página inteira carregada. Se uma fonte oficial
sair do ar, o modelo continua com o texto literal e a data; a reconferência mensal agendada refaz o retrato."""
import hashlib, json, os, re, sys, unicodedata, urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))

# afirmação do modelo -> (fonte, dispositivo, trecho que precisa estar no texto literal)
AFIRMACOES = [
    ('Impugnação até 3 dias úteis antes da abertura (NE-05)', 'l14133', 'art. 164, caput', 'até 3 (três) dias úteis antes da data de abertura'),
    ('Resposta à impugnação em até 3 dias úteis (NE-05)', 'l14133', 'art. 164, parágrafo único', 'no prazo de até 3 (três) dias úteis'),
    ('Ata de registro de preços de 1 ano, prorrogável (NE-06)', 'l14133', 'art. 84, caput', 'prorrogado, por igual período'),
    ('Garantia: defeito denunciado em 30 dias (OP-07, contratos)', 'cc2002', 'art. 446', 'nos trinta dias seguintes ao seu descobrimento'),
    ('IPCA quando o índice não foi convencionado (contratos)', 'cc2002', 'art. 389, parágrafo único', 'IPCA'),
    ('Alocação de riscos respeitada (contratos)', 'cc2002', 'art. 421-A, inciso II', 'a alocação de riscos definida pelas partes deve ser respeitada e observada'),
    ('Salário até o quinto dia útil (GE-13)', 'clt', 'art. 459, § 1º', 'até o quinto dia útil do mês subsequente ao vencido'),
    ('FGTS até o dia 20 (GE-13)', 'fgts', 'art. 15, caput', 'até o vigésimo dia de cada mês'),
    ('Incidente à ANPD em 3 dias úteis (GO-09)', 'anpd15', 'art. 6º, caput', 'no prazo de três dias úteis'),
    ('Prazo em dobro para agente de pequeno porte (GO-09)', 'anpd15', 'art. 6º, § 8º', 'contados em dobro para os agentes de pequeno porte'),
    ('Registro do incidente por 5 anos (GO-09)', 'anpd15', 'art. 10, caput', 'cinco anos'),
]


def norm(s):
    s = unicodedata.normalize('NFKC', s).replace('\xa0', ' ')
    return re.sub(r'\s+', ' ', s).strip().lower()


def main():
    online = '--online' in sys.argv
    d = json.load(open(os.path.join(BASE, 'trechos.json'), encoding='utf-8'))
    reg_path = os.path.join(BASE, 'hashes.json')
    hashes = {f"{t['fonte']}|{t['dispositivo']}": hashlib.sha256(t['texto'].encode('utf-8')).hexdigest() for t in d['trechos'] if t.get('obtido')}
    if os.path.exists(reg_path):
        antes = json.load(open(reg_path, encoding='utf-8'))
        mudou = [k for k in hashes if k in antes and antes[k] != hashes[k]]
    else:
        json.dump(hashes, open(reg_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        mudou = []
    falhas = 0
    idx = {(t['fonte'], t['dispositivo']): t for t in d['trechos']}
    for nome, fonte, disp, frag in AFIRMACOES:
        t = next((v for (f, dd), v in idx.items() if f == fonte and dd.replace(' ', '') .startswith(disp.replace(' ', ''))), None)
        ok = bool(t) and norm(frag) in norm(t['texto'])
        if not ok:
            falhas += 1
            print('SEM APOIO NO TEXTO LITERAL:', nome, '|', fonte, disp)
    for k in mudou:
        falhas += 1
        print('TRECHO ALTERADO DESDE O RETRATO:', k)
    fora = 0
    if online:
        for t in d['trechos']:
            try:
                req = urllib.request.Request(t['url'], headers={'User-Agent': 'Mozilla/5.0'})
                pagina = urllib.request.urlopen(req, timeout=60).read().decode('utf-8', 'ignore')
                txt = norm(re.sub(r'<[^>]+>', ' ', pagina))
                if norm(t['texto'])[:120] not in txt:
                    fora += 1
                    print('NÃO ACHADO NA PÁGINA (pode ter mudado):', t['fonte'], t['dispositivo'])
            except Exception as e:
                fora += 1
                print('FONTE FORA DO AR OU BLOQUEADA:', t['fonte'], t['dispositivo'], type(e).__name__)
    print(f'TRECHOS: {len(d["trechos"])} | AFIRMAÇÕES CONFERIDAS: {len(AFIRMACOES)} | FALHAS: {falhas}' + (f' | ONLINE COM PROBLEMA: {fora}' if online else ''))
    sys.exit(1 if falhas else 0)


if __name__ == '__main__':
    main()
