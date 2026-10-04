# Simulador de cenários (E7)

Separado do motor: lê uma cópia do modelo (`saida/cN/circulo.json` e os fluxos BPMN), roda carga sintética e devolve propostas para a ID-04. Nunca escreve no motor; as propostas vão ao esquema `sim` do Supabase (`supabase/022_simulador.sql`).

- `simular.py`: três cenários (base, dobro do volume, dobro com reforço onde a ocupação passou de 85%). Pessoas do círculo (P) têm capacidade e fila por papel, em horário de trabalho (8 horas por dia); agentes e automações não esperam; pessoa de fora, outro círculo e assessoria contam só o tempo de resposta. Laços com a mesma regra do motor.
- `testar_simulador.py`: 6 testes (mesma semente, mesmo resultado; todas as jornadas rodam; mais volume, mais ocupação; mais gente, menos ocupação; o trabalho total se conserva; o simulador não fala com a base).
- `resultado/`: um JSON por cenário e `propostas.md`.

Hipóteses, até haver dado real: os tempos de cada executor (`rt.parametro_simulacao`, a calibrar no G9) e o volume, tirado da frequência escrita em cada jornada (a cadência mais frequente citada, mais 1 por mês quando a jornada também roda "por evento").

Uso: `python3 simulador/simular.py` e `python3 simulador/testar_simulador.py`.
