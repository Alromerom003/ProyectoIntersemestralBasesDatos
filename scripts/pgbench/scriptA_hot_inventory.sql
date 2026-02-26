-- scriptA_hot_inventory.sql
-- Simula múltiples clientes intentando rentar simultáneamente
-- el MISMO inventory_id, como hace el endpoint POST /rentals.
-- La defensa central es el índice único parcial:
--   ux_rental_active_inventory ON rental(inventory_id) WHERE return_date IS NULL
-- que garantiza que sólo una transacción logrará insertar una renta
-- activa por inventory_id; las demás fallarán con unique_violation.

\set customer_id random(1, 599)
\set staff_id random(1, 2)

-- Ajustar manualmente este inventory_id a uno existente en la base Pagila.
\set inventory_id 1

BEGIN;
SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), :inventory_id, :customer_id, NULL, :staff_id);

COMMIT;

