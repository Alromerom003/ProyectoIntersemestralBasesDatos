-- Particiones adicionales para la tabla payment (Pagila)
-- Las particiones originales cubren hasta 2022-07.
--
-- Además: permite rental_id NULL para pagos sin renta asociada (nuestra API).

-- Hacer rental_id opcional (propaga a todas las particiones)
ALTER TABLE public.payment ALTER COLUMN rental_id DROP NOT NULL;
-- Este script añade particiones para 2023-2030 para permitir
-- inserciones con payment_date = NOW() en años recientes.

DO $$
DECLARE
    year_val INT;
    month_val INT;
    part_name TEXT;
    start_ts TEXT;
    end_ts TEXT;
BEGIN
    FOR year_val IN 2023..2030 LOOP
        FOR month_val IN 1..12 LOOP
            part_name := 'payment_p' || year_val || '_' || LPAD(month_val::TEXT, 2, '0');
            start_ts := year_val || '-' || LPAD(month_val::TEXT, 2, '0') || '-01 00:00:00+00';
            end_ts := CASE WHEN month_val = 12
                THEN (year_val + 1)::TEXT || '-01-01 00:00:00+00'
                ELSE year_val::TEXT || '-' || LPAD((month_val + 1)::TEXT, 2, '0') || '-01 00:00:00+00'
            END;
            
            IF NOT EXISTS (
                SELECT 1 FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relname = part_name AND n.nspname = 'public'
            ) THEN
                EXECUTE format(
                    'CREATE TABLE public.%I PARTITION OF public.payment
                     FOR VALUES FROM (%L::timestamptz) TO (%L::timestamptz)',
                    part_name, start_ts, end_ts);
                RAISE NOTICE 'Creada partición %', part_name;
            END IF;
        END LOOP;
    END LOOP;
END $$;
