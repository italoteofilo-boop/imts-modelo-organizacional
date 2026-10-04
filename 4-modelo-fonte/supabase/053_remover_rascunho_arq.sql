-- Remove o esquema "arq", sobra de um rascunho da E17 aplicado por engano e substituído pelo "acervo" (043).
-- Conferido em 04/10/2026: 0 arquivos, 0 dados, 0 raízes; só sementes de pastas e tipos; nenhum gatilho, rotina ou função fora dele dependia dele.
-- Aprovado por Ítalo em 04/10/2026, 14:01 ("resolva todas as travas").
begin;
drop schema if exists arq cascade;
commit;
