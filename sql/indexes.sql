-- Índices adicionales para el proyecto DVD Rental (Pagila)

-- Índice único parcial para garantizar que no haya más de una renta
-- activa (return_date IS NULL) por inventory_id.
--
-- Esta es la defensa principal a nivel de base de datos frente a la
-- concurrencia: incluso si múltiples transacciones intentan insertar
-- una renta activa para el mismo inventory_id al mismo tiempo, sólo
-- una podrá comprometerse; las demás recibirán un unique_violation
-- (SQLSTATE 23505) y la API lo traducirá en HTTP 409.
CREATE UNIQUE INDEX IF NOT EXISTS ux_rental_active_inventory
    ON rental (inventory_id)
    WHERE return_date IS NULL;


-- Índice de apoyo para consultas frecuentes sobre rental por customer.
CREATE INDEX IF NOT EXISTS ix_rental_customer_id
    ON rental (customer_id);


-- Índice de apoyo para pagos por customer y fecha.
CREATE INDEX IF NOT EXISTS ix_payment_customer_id_payment_date
    ON payment (customer_id, payment_date);

