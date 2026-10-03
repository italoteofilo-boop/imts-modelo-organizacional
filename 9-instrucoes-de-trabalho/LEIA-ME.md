# Instruções de trabalho

Uma instrução por jornada (73), gerada da fonte do modelo em 03/10/2026 pelo 4-modelo-fonte/instrucoes.py. Cada uma traz:
quando a jornada começa e como termina, quem participa, e, etapa a etapa, o que recebe, as tarefas com quem faz cada uma,
as decisões com seus caminhos e o que entrega. Nada foi escrito à mão: o que o modelo não diz, a instrução não diz.

- `instrucoes-de-trabalho-2026-10-03.zip`: os 73 PDFs A4, para imprimir. Conferido: as 1.555 tarefas aparecem nos PDFs.
- `MANIFESTO.csv`: jornada, círculo, páginas, tamanho e SHA-256 de cada PDF (também dentro do zip).
- `instrucoes.html`: a versão digital, com as 73 navegáveis. Abra no navegador.
- `zip_rastreavel.py`: confere e descompacta.

    python3 zip_rastreavel.py conferir instrucoes-de-trabalho-2026-10-03.zip MANIFESTO.csv
    python3 zip_rastreavel.py extrair instrucoes-de-trabalho-2026-10-03.zip pasta-destino

Para refazer depois de mudar o modelo: python3 instrucoes.py && node instrucoes_pdf.mjs (precisa do Playwright).
