-- scriptB_deadlock_fixed.sql
-- Versión corregida del patrón anterior para evitar deadlocks.
-- La idea clave es tomar locks siempre en el mismo orden lógico,
-- independientemente de los valores aleatorios, usando LEAST/GREATEST.

\set aid random(1, 300)
\set bid random(301, 600)

-- Normalizamos el orden de los IDs.
\set first_id least(:aid, :bid)
\set second_id greatest(:aid, :bid)

BEGIN;
SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Siempre se bloquea primero el menor ID y luego el mayor,
-- lo que elimina el ciclo de espera circular entre transacciones.
UPDATE customer
SET last_update = NOW()
WHERE customer_id = :first_id;

SELECT pg_sleep(0.05);

UPDATE customer
SET last_update = NOW()
WHERE customer_id = :second_id;

COMMIT;

