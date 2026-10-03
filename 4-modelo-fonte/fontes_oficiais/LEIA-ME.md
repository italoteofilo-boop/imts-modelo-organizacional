# Fontes oficiais: retrato e contingência

O modelo cita prazos de lei. Esta pasta guarda o texto literal de cada dispositivo citado, tirado em 03/10/2026 da fonte oficial, para o modelo não depender de o site estar no ar.

## Arquivos

- `trechos.json`: 35 trechos literais (Lei 14.133, Código Civil, CLT, Lei 8.036, Resolução CD/ANPD nº 15/2024 e a página da ANPD). Cada um tem a URL aberta, o dispositivo e o texto copiado da página inteira no navegador. O SHA-256 de cada trecho foi conferido duas vezes: no navegador e no arquivo.
- `hashes.json`: o hash de cada trecho no retrato. Se alguém editar um trecho, o conferidor acusa.
- `conferir_fontes.py`: confere se cada prazo citado no modelo tem apoio no texto literal. Com `--online`, baixa de novo cada URL e acusa a fonte que saiu do ar ou mudou.

## Fontes e espelhos

| Fonte | Oficial | Espelho de contingência |
|---|---|---|
| Lei 14.133/2021, Código Civil, CLT, Lei 8.036 | Planalto (planalto.gov.br) | Este retrato; transcrições por artigo (LegJur, Petições Online), marcadas como secundárias |
| Resolução CD/ANPD nº 15/2024 | DOU (in.gov.br); página da ANPD (gov.br/anpd) | Reprodução do DOU pelo Governo de MS (lgpd.ms.gov.br); LegisWeb |

**O que se sabe dos acessos em 03/10/2026:**
- **Planalto:** abre inteiro no navegador. A leitura automática corta a Lei 14.133 no art. 36, e o contêiner de nuvem tem a conexão recusada.
- **DOU (in.gov.br):** recusa leitura automática (robots.txt) e falhou também no navegador. Por isso a Resolução foi conferida na página da ANPD e na reprodução do DOU pelo Governo de MS.

## Como manter

- Uma reconferência mensal está agendada. Ela abre cada URL, compara com o retrato e avisa o que mudou ou saiu do ar.
- Lei alterada: refazer o trecho, rodar `python3 conferir_fontes.py`, apagar `hashes.json` para gravar o novo retrato e registrar a mudança em `fontes.py`.
