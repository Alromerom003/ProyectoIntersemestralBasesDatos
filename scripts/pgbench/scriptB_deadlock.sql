-- scriptB_deadlock.sql
-- Script diseñado para provocar deadlocks reales bajo alta concurrencia.
-- Usa dos recursos (dos customers) actualizados en orden inverso entre
-- ejecuciones concurrentes, generando el clásico patrón de deadlock.

\set aid random(1, 300)
\set bid random(301, 600)

BEGIN;
SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Primera actualización toma lock sobre aid.
UPDATE customer
SET last_update = NOW()
WHERE customer_id = :aid;

-- Pequeña pausa para aumentar probabilidad de interleaving.
SELECT pg_sleep(0.05);

-- Segunda actualización toma lock sobre bid.
UPDATE customer
SET last_update = NOW()
WHERE customer_id = :bid;

COMMIT;

-- Para maximizar el deadlock, ejecutar este script con pgbench en dos
-- terminales, uno con (aid,bid) como arriba (1-300 / 301-600) y otro
-- usando un rango invertido (ver scriptB_deadlock.sql llamado desde
-- distintas instancias con rangos superpuestos).

