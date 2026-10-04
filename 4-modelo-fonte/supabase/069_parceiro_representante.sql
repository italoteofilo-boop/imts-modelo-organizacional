-- Parceiro simulado: "escritório regional de advocacia" vira "representante comercial regional" (aprovado em 04/10/2026).
-- Motivo: escritório de advocacia não recebe comissão (decisão de set/2026; é remunerado pela OS-Cliente),
-- e o parceiro simulado existe justamente para testar comissão. Só afeta dado simulado.
update ext.contraparte set nome = 'Representante comercial regional (simulado)'
 where simulado and tipo = 'parceiro' and nome = 'Escritório regional de advocacia (simulado)';
