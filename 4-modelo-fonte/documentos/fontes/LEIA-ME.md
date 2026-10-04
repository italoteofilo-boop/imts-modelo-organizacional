# Fontes do motor documental

| Arquivo | Família | Origem | Licença |
|---|---|---|---|
| OpenSans-*.ttf | Open Sans | pacote npm @fontsource/open-sans (subconjunto latino), convertido de woff2 para ttf com fontTools | SIL Open Font License 1.1 |
| Michroma-Regular.ttf | Michroma | pacote npm @fontsource/michroma (subconjunto latino), convertido da mesma forma | SIL Open Font License 1.1 |

O cabeçalho e o rodapé do PDF são desenhados pelo Chromium fora da página e só enxergam fontes instaladas no sistema. Por isso o worker instala estas fontes (`motor.py --instalar-fontes`) antes da primeira emissão.

| Poppins-*.ttf | Poppins | fontes do sistema (Google Fonts), copiadas para o HTML de saída ser autocontido | SIL Open Font License 1.1 |

Poppins é a substituta declarada da Nexa na marca Onni. Nexa é fonte comercial: os arquivos ainda não foram entregues.
