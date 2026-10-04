-- Aprovado por Ítalo em 04/10/2026, às 10:13: apagar a chave antiga 'telegram' de rt.config (autodestruição 24, não lida por nada).
-- A autodestruição vale pela chave 'autodestruicao_horas', administrada em adm.parametro (telegram.autodestruicao_horas).
delete from rt.config where chave = 'telegram';
