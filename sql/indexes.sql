-- ==========================================================
-- Índices optimizados para el proyecto intersemestral DVD Rental (PAgila)
-- ==========================================================

-- 1. Control de Concurrencia: Renta Activa Única
-- Este índice es el que arroja el error de "llave duplicada" 
CREATE UNIQUE INDEX IF NOT EXISTS ux_rental_active_inventory
    ON rental (inventory_id)
    WHERE (return_date IS NULL);

-- 2. Optimización de Consultas por Cliente
-- Mejora el rendimiento para los endpoints que buscan el historial de un usuario.
CREATE INDEX IF NOT EXISTS ix_rental_customer_id_search
    ON rental (customer_id);

-- 3. Índice Compuesto con Cláusula INCLUDE 
-- Optimiza las consultas de auditoría de pagos permitiendo que 
-- Postgres obtenga el 'amount' sin leer la tabla completa (Index Only Scan).
CREATE INDEX IF NOT EXISTS ix_payment_perf_customer_date
    ON payment (customer_id, payment_date)
    INCLUDE (amount);
