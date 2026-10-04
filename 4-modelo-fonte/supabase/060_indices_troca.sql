-- Índices das chaves estrangeiras de org.troca: existiam no protótipo (correção do diagnóstico do Supabase) e faltavam no repositório.
-- Achado do ensaio em banco vazio (comparação de estrutura com o protótipo).
create index if not exists troca_de_circulo_idx on org.troca (de_circulo);
create index if not exists troca_para_circulo_idx on org.troca (para_circulo);
