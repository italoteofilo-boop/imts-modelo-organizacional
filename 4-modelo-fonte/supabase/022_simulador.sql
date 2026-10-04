-- E7: o simulador de cenários escreve só no esquema sim, nunca no motor
create schema if not exists sim;
create table if not exists sim.proposta (
  id bigint generated always as identity primary key, gerado_em timestamptz not null default now(), origem text not null,
  alvo text not null, texto text not null, situacao text not null default 'para a ID-04' check (situacao in ('para a ID-04', 'aceita', 'recusada')));
alter table sim.proposta enable row level security;
revoke all on schema sim from anon, authenticated;

-- propostas da rodada de 03/10/2026 (geradas pelo simulador)
insert into sim.proposta (origem, alvo, texto) values
('simulador/simular.py, cenários base, dobro e reforco', 'Estratégia · pessoa', 'no volume dobrado, a ocupação chega a 106% e a espera p90 a 1544.8 h. Com uma segunda pessoa no papel, a ocupação cai para 53% e a espera p90 para 1327.5 h. Proposta à ID-04: prever a segunda pessoa no G2 ou levar tarefas do papel para Copiloto ou Autopiloto onde a etapa permitir.'),
('simulador/simular.py, cenários base, dobro e reforco', 'ES-03 · Desdobrar a estratégia em alvos e iniciativas de cada empresa e de cada círculo', 'no cenário base, o p90 de duração é 719.6 h (mediana 719.6 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.'),
('simulador/simular.py, cenários base, dobro e reforco', 'ES-02 · Rever o portfólio e realocar recursos entre empresas, ofertas e apostas', 'no cenário base, o p90 de duração é 603.7 h (mediana 553.1 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.'),
('simulador/simular.py, cenários base, dobro e reforco', 'ES-05 · Decidir e estruturar a criação, a aquisição, a venda ou o encerramento de uma empresa', 'no cenário base, o p90 de duração é 529.1 h (mediana 529.1 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.'),
('simulador/simular.py, cenários base, dobro e reforco', 'ES-01 · Formular e revisar a estratégia do Ecossistema e de cada empresa', 'no cenário base, o p90 de duração é 398.2 h (mediana 398.2 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.'),
('simulador/simular.py, cenários base, dobro e reforco', 'ES-06 · Acompanhar a execução da estratégia e corrigir o rumo', 'no cenário base, o p90 de duração é 360.3 h (mediana 349.8 h). Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.');
