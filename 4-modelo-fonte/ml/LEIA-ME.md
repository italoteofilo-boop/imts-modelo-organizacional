# Machine learning do motor (E8)

`treinar.py` lê os eventos do motor (`rt.evento`, `rt.instancia`), treina os modelos e escreve `supabase/006_modelos.sql`, que registra cada modelo em `rt.modelo` com versão, dado de treino, métricas e SHA-256 do arquivo.

    python3 ml/treinar.py --psql "psql -h <host> -p <porta> -U <usuário> -d <base>"

## Modelos de 03/10/2026 (versão 2026-10-03.1)

Treinados com 2.000 instâncias simuladas da Identidade (400 por jornada), no Postgres 16 local, com o mesmo motor que está no Supabase.

| Modelo | Tipo | Amostras | Resultado | Em uso |
| --- | --- | --- | --- | --- |
| `risco-atraso-etapa` | Classificação (gradient boosting): a etapa vai passar do p75 de duração dela? | 7.797 etapas (5.856 de treino, 1.941 de teste, separadas por instância) | AUC 0,447; Brier 0,2006 contra 0,1991 da taxa média | Não |
| `anomalia-instancia` | Isolation Forest sobre duração, passos, tarefas, decisões e voltas | 2.000 instâncias | 40 marcadas (2%, a contaminação assumida) | Não |

**Como ler o resultado.** No simulador, o tempo de cada tarefa é sorteado de forma independente (`rt.parametro_simulacao`). Por isso não há nada para prever no atraso, e o modelo de atraso fica no acaso (AUC perto de 0,5), um pouco pior que a taxa média. É o resultado certo: mostra que o treino não vaza informação do alvo. O encanamento está provado: extração, treino, avaliação separada por instância, registro, versão e hash. O sinal só vem com dado real; quando houver, o mesmo `treinar.py` treina a versão seguinte com `dado = 'real'`.

**Promoção de modo** (Copiloto → Autopiloto) não foi treinada. Ela depende de sinais de qualidade (retrabalho apontado por pessoa, correção de agente) que o simulador não produz.

Nenhum modelo está em uso (`em_uso = false`). Um modelo treinado só com dado simulado não decide nada real.
