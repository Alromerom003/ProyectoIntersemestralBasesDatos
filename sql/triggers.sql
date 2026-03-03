-- ==========================================================
-- Esquema de optimización y performance DVD Rental
-- ==========================================================

-- 1. Regla de negocio: Integridad en renta de inventario.
-- Garantiza que un inventory_id no tenga duplicidad de rentas activas.
-- Implementación mediante índice parcial único.

CREATE UNIQUE INDEX IF NOT EXISTS idx_active_rental_prevention
    ON rental (inventory_id)
    WHERE return_date IS NULL;

-- 2. Performance: Optimización de búsqueda de clientes.
-- Indexación de customer_id para acelerar joins y filtrados en la tabla rental.

CREATE INDEX IF NOT EXISTS idx_rental_customer_lookup
    ON rental (sutomer_id);

-- 3. Performance: Historial de pagos
-- Índice compuesto optimizado para reportes de facturación por cliente y fecha.

CREATE INDEX IF NOT EXISTS idx_payment_customer_date_composite
    ON payment (customer_id, payment_date);
