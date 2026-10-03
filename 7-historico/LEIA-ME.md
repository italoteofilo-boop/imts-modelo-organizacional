# Histórico compactado

Versões superadas, guardadas para rastrear de onde veio cada decisão. Nada aqui está em uso.

- `versoes-anteriores-ate-2026-10-03.zip`:
  - `base-rodada-2/`: o catálogo da rodada 2 (49 jornadas e 216 workflows) em dados, o texto do documento-base daquela
    rodada e os testes de integridade de então.
  - `catalogo-rodada-2-pdf/`: as cinco abas do Catálogo de jornadas da rodada 2, como exportadas em 02/10/2026. As abas
    foram retiradas do documento vivo em 03/10/2026; o Mapa de jornadas as substitui.
  - `circulo1-treze-jornadas/`: a versão de treze jornadas do círculo 1.
  - `modulos/`: as versões anteriores dos módulos do modelo.
  - `c2p-fragmentos-superados/`: os fragmentos antigos do círculo 2.
- `MANIFESTO.csv`: caminho, tamanho e SHA-256 de cada arquivo (também dentro do zip).
- `zip_rastreavel.py`: confere e descompacta.

## Como conferir e descompactar

    python3 zip_rastreavel.py conferir versoes-anteriores-ate-2026-10-03.zip MANIFESTO.csv
    python3 zip_rastreavel.py extrair versoes-anteriores-ate-2026-10-03.zip pasta-destino

Sem Python: `unzip versoes-anteriores-ate-2026-10-03.zip`. O histórico do git também guarda cada versão no caminho antigo
(pastas `7-base-rodada-2/` e `8-versoes-anteriores/`, até o commit 21af232).
