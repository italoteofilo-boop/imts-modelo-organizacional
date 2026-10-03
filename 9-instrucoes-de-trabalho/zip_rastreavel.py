# -*- coding: utf-8 -*-
"""Zip rastreável: cada arquivo entra com caminho, tamanho e SHA-256 num MANIFESTO.csv (dentro do zip e ao lado dele).

Montar (usado pelo montar_zip.py):
    from zip_rastreavel import montar
    montar('saida.zip', [(origem, caminho_no_zip, {'campo extra': 'valor'}), ...], leia_me='texto')

Conferir e descompactar (só Python 3, sem instalar nada):
    python3 zip_rastreavel.py conferir arquivo.zip            confere cada arquivo contra o MANIFESTO interno
    python3 zip_rastreavel.py conferir arquivo.zip MANIFESTO.csv   e também contra o manifesto de fora
    python3 zip_rastreavel.py extrair  arquivo.zip pasta       confere e descompacta
Descompactar sem conferir: unzip arquivo.zip   ou   python3 -m zipfile -e arquivo.zip pasta
"""
import csv, hashlib, io, os, sys, zipfile

CAMPOS = ['caminho', 'bytes', 'sha256']


def _sha(b):
    return hashlib.sha256(b).hexdigest()


def montar(destino, itens, leia_me=None, data_fixa=(2026, 10, 3, 0, 0, 0)):
    """itens: (origem em disco ou bytes, caminho no zip, dict de campos extras). Devolve as linhas do manifesto."""
    extras = []
    linhas = []
    for _, arc, ext in itens:
        for k in (ext or {}):
            if k not in extras:
                extras.append(k)
    with zipfile.ZipFile(destino, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        def pos(arc, dados):
            zi = zipfile.ZipInfo(arc, date_time=data_fixa)  # data fixa: o mesmo conteúdo gera o mesmo zip
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            z.writestr(zi, dados, compresslevel=9)
        for src, arc, ext in sorted(itens, key=lambda x: x[1]):
            dados = src if isinstance(src, bytes) else open(src, 'rb').read()
            pos(arc, dados)
            linhas.append(dict({'caminho': arc, 'bytes': len(dados), 'sha256': _sha(dados)}, **(ext or {})))
        buf = io.StringIO()
        w = csv.DictWriter(buf, fieldnames=CAMPOS + extras, lineterminator='\n')
        w.writeheader()
        w.writerows(linhas)
        man = buf.getvalue().encode('utf-8')
        pos('MANIFESTO.csv', man)
        if leia_me:
            pos('LEIA-ME.md', leia_me.encode('utf-8'))
    open(os.path.join(os.path.dirname(destino), 'MANIFESTO.csv'), 'wb').write(man)
    return linhas


def conferir(zip_path, manifesto_fora=None, mostrar=True):
    falhas = 0
    with zipfile.ZipFile(zip_path) as z:
        if z.testzip() is not None:
            print('ZIP CORROMPIDO:', z.testzip())
            return 1
        man = list(csv.DictReader(io.StringIO(z.read('MANIFESTO.csv').decode('utf-8'))))
        nomes = set(z.namelist()) - {'MANIFESTO.csv', 'LEIA-ME.md'}
        for l in man:
            if l['caminho'] not in nomes:
                falhas += 1; print('FALTA NO ZIP:', l['caminho']); continue
            d = z.read(l['caminho'])
            if len(d) != int(l['bytes']) or _sha(d) != l['sha256']:
                falhas += 1; print('DIFERE DO MANIFESTO:', l['caminho'])
        for n in nomes - {l['caminho'] for l in man}:
            falhas += 1; print('FORA DO MANIFESTO:', n)
        if manifesto_fora:
            fora = list(csv.DictReader(open(manifesto_fora, encoding='utf-8')))
            if [(l['caminho'], l['sha256']) for l in fora] != [(l['caminho'], l['sha256']) for l in man]:
                falhas += 1; print('MANIFESTO DE FORA DIFERE DO DE DENTRO')
    if mostrar:
        print(f'{os.path.basename(zip_path)}: {len(man)} arquivos conferidos, {falhas} falhas')
    return falhas


if __name__ == '__main__':
    if len(sys.argv) < 3 or sys.argv[1] not in ('conferir', 'extrair'):
        print(__doc__); sys.exit(2)
    if sys.argv[1] == 'conferir':
        sys.exit(1 if conferir(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None) else 0)
    if conferir(sys.argv[2]):
        sys.exit(1)
    zipfile.ZipFile(sys.argv[2]).extractall(sys.argv[3])
    print('descompactado em', sys.argv[3])
