# Documento do projeto, exportado em PDF

O documento vivo está no endereço de `1-situacao-do-projeto/enderecos.txt` e continua sendo a versão de referência.
Aqui vai a exportação das sete abas em PDF, feita em 03/10/2026, depois do G5 cumprido.

- `documento-do-projeto-2026-10-03.zip`: as sete abas. Os PDFs foram compactados sem perda (qpdf: fluxos recompactados
  e objetos agrupados; texto e imagens iguais), de 2,8 MB para 1,0 MB.
- `MANIFESTO.csv`: um arquivo por linha, com aba, data e hora da exportação, páginas, tamanho e SHA-256 do PDF compacto
  e do PDF como saiu do documento. A mesma tabela vai dentro do zip.
- `zip_rastreavel.py`: confere e descompacta.

## Como conferir e descompactar

    python3 zip_rastreavel.py conferir documento-do-projeto-2026-10-03.zip MANIFESTO.csv
    python3 zip_rastreavel.py extrair documento-do-projeto-2026-10-03.zip pasta-destino

Sem Python: `unzip documento-do-projeto-2026-10-03.zip` (macOS e Linux) ou "Extrair tudo" no Windows; para conferir um
arquivo, `shasum -a 256 arquivo.pdf` (macOS) ou `certutil -hashfile arquivo.pdf SHA256` (Windows) e compare com o MANIFESTO.

O texto atual de cada aba, em Markdown, está em `5-leitura-por-circulo/`.
