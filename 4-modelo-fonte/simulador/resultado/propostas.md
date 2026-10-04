# Propostas do simulador de cenários (E7)

Gerado por simulador/simular.py. O simulador lê uma cópia do modelo e não escreve no motor. As propostas seguem a ID-04, que decide.
Os tempos são hipóteses do protótipo (rt.parametro_simulacao, a calibrar no G9); o volume vem da frequência escrita em cada jornada (a cadência mais frequente citada, mais 1 por mês quando a jornada também roda "por evento"), e também é hipótese até haver dado real.

## Cenário base: Uma pessoa por papel; o volume de cada jornada pela frequência do modelo

| Papel | Pessoas | Ocupação | Espera média (h) | Espera p90 (h) |
|---|---|---|---|---|
| Estratégia · pessoa | 1 | 47% | 63.0 | 312.6 |
| Gestão · pessoa | 1 | 36% | 33.6 | 94.3 |
| Relações · pessoa | 1 | 33% | 21.5 | 72.6 |
| Operações · pessoa | 1 | 32% | 15.5 | 43.3 |
| Governança · pessoa | 1 | 31% | 5.4 | 15.0 |
| Identidade · pessoa | 1 | 28% | 20.6 | 15.9 |
| Inteligência · pessoa | 1 | 18% | 10.0 | 25.4 |
| Integração · pessoa | 1 | 18% | 7.0 | 14.5 |
| Negócios · pessoa | 1 | 14% | 5.9 | 12.8 |

## Cenário dobro: O dobro do volume, com a mesma equipe

| Papel | Pessoas | Ocupação | Espera média (h) | Espera p90 (h) |
|---|---|---|---|---|
| Estratégia · pessoa | 1 | 106% | 322.8 | 1544.8 |
| Relações · pessoa | 1 | 72% | 122.7 | 643.9 |
| Gestão · pessoa | 1 | 69% | 106.2 | 264.5 |
| Identidade · pessoa | 1 | 57% | 13.7 | 41.3 |
| Operações · pessoa | 1 | 55% | 19.8 | 69.2 |
| Governança · pessoa | 1 | 54% | 16.6 | 42.0 |
| Integração · pessoa | 1 | 40% | 29.7 | 110.2 |
| Negócios · pessoa | 1 | 39% | 21.1 | 74.1 |
| Inteligência · pessoa | 1 | 38% | 28.7 | 114.5 |

## Cenário reforco: O dobro do volume, com duas pessoas em cada papel que passou de 85% de ocupação no cenário dobro

| Papel | Pessoas | Ocupação | Espera média (h) | Espera p90 (h) |
|---|---|---|---|---|
| Relações · pessoa | 1 | 72% | 122.7 | 643.9 |
| Gestão · pessoa | 1 | 69% | 106.2 | 264.5 |
| Identidade · pessoa | 1 | 57% | 13.7 | 41.3 |
| Operações · pessoa | 1 | 55% | 19.8 | 69.2 |
| Governança · pessoa | 1 | 54% | 16.6 | 42.0 |
| Estratégia · pessoa | 2 | 53% | 246.3 | 1327.5 |
| Integração · pessoa | 1 | 40% | 29.7 | 110.2 |
| Negócios · pessoa | 1 | 39% | 21.1 | 74.1 |
| Inteligência · pessoa | 1 | 38% | 28.7 | 114.5 |

## Propostas

1. **Estratégia · pessoa**: no volume dobrado, a ocupação chega a 106% e a espera p90 a 1544.8 h. Com uma segunda pessoa no papel, a ocupação cai para 53% e a espera p90 para 1327.5 h. Proposta à ID-04: prever a segunda pessoa no G2 ou levar tarefas do papel para Copiloto ou Autopiloto onde a etapa permitir.
2. **ES-03 · Desdobrar a estratégia em alvos e iniciativas de cada empresa e de cada círculo**: no cenário base, o p90 de duração é 719.6 h (mediana 719.6 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.
3. **ES-02 · Rever o portfólio e realocar recursos entre empresas, ofertas e apostas**: no cenário base, o p90 de duração é 603.7 h (mediana 553.1 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.
4. **ES-05 · Decidir e estruturar a criação, a aquisição, a venda ou o encerramento de uma empresa**: no cenário base, o p90 de duração é 529.1 h (mediana 529.1 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.
5. **ES-01 · Formular e revisar a estratégia do Ecossistema e de cada empresa**: no cenário base, o p90 de duração é 398.2 h (mediana 398.2 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.
6. **ES-06 · Acompanhar a execução da estratégia e corrigir o rumo**: no cenário base, o p90 de duração é 360.3 h (mediana 349.8 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.
