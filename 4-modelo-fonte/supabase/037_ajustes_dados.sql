-- Correção de dados da auditoria (R11): publicações simuladas datadas pelo relógio da simulação (à frente do real) passam à data real.
update ext.publicacao set em = least(em, now()) where simulado and em > now();
