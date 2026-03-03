-- ==========================================================
-- Índices optimizados para el proyecto intersemestral DVD Rental (PAgila)
-- ==========================================================

-- 1. Control de Concurrencia: Renta Activa Única
-- Evita que un mismo item del inventario sea rentado por dos personas
-- simultáneamente si el return_date aún es  NULL.

CREATE UNIQUE INDEX IF NOT EXISTS ux_rental_active_inventory
    ON rental (inventory_id)
    WHERE (return_date IS NULL);

-- 2. Optimización de Consultas por Cliente
-- Mejora el rendimiento al buscar el historial de rentas de un usuario.

CREATE INDEX IF NOT EXISTS ix_rental_customer_id_search
    ON rental (customer_id);

-- 3. Índice Compuesto con Cláusula INCLUDE 
-- Se añaden columnas adicionales para que las consultas de pagos
-- sean más rápidas sin cambiar la clave del índice.

CREATE INDEX IF NOT EXISTS ix_payment_perd_customer_date
    ON payment (sutomer_id, payment_date);
