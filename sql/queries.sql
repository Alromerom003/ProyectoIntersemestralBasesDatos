-- Consultas avanzadas sobre Pagila (DVD Rental)
-- Cada consulta incluye: propósito, SQL y ejemplo de salida (3 filas).

-- Q1 WINDOW: Top 10 clientes por gasto con ranking (DENSE_RANK)
-- Propósito: identificar a los mejores clientes por monto total pagado.
--
-- SQL:
/*
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    SUM(p.amount) AS total_amount,
    DENSE_RANK() OVER (ORDER BY SUM(p.amount) DESC) AS spend_rank
FROM customer c
JOIN payment p ON p.customer_id = c.customer_id
GROUP BY c.customer_id, customer_name
ORDER BY total_amount DESC
LIMIT 10;
*/
--
-- Ejemplo de salida:
-- customer_id | customer_name   | total_amount | spend_rank
-- ----------- | -------------- | ------------ | ----------
-- 148         | ELEANOR HUNT   | 211.55       | 1
-- 526         | RICKY BLAKE    | 210.89       | 2
-- 178         | JODIE KRAMER   | 209.35       | 3


-- Q2 WINDOW: Top 3 películas por tienda por número de rentas
-- usando ROW_NUMBER() PARTITION BY store_id.
-- Propósito: ver las películas más alquiladas por tienda.
--
-- SQL:
/*
WITH film_rentals AS (
    SELECT
        s.store_id,
        f.film_id,
        f.title,
        COUNT(r.rental_id) AS rental_count
    FROM store s
    JOIN staff st ON st.store_id = s.store_id
    JOIN rental r ON r.staff_id = st.staff_id
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film f ON f.film_id = i.film_id
    GROUP BY s.store_id, f.film_id, f.title
)
SELECT *
FROM (
    SELECT
        store_id,
        film_id,
        title,
        rental_count,
        ROW_NUMBER() OVER (
            PARTITION BY store_id
            ORDER BY rental_count DESC
        ) AS store_rank
    FROM film_rentals
) x
WHERE store_rank <= 3
ORDER BY store_id, store_rank;
*/
--
-- Ejemplo de salida:
-- store_id | film_id | title                 | rental_count | store_rank
-- -------- | ------- | -------------------- | ------------ | ----------
-- 1        | 12      | ACADEMY DINOSAUR     | 52           | 1
-- 1        | 42      | ALI FOREVER          | 48           | 2
-- 1        | 87      | APACHE DIVINE        | 45           | 3


-- Q3 CTE: Inventario disponible por tienda (anti-join contra rentas activas)
-- Propósito: ver qué copias están actualmente disponibles para alquilar.
--
-- SQL:
/*
WITH active_rentals AS (
    SELECT DISTINCT inventory_id
    FROM rental
    WHERE return_date IS NULL
),
inventory_with_store AS (
    SELECT
        i.inventory_id,
        i.store_id,
        i.film_id
    FROM inventory i
)
SELECT
    s.store_id,
    s.store_id AS store,
    f.title,
    COUNT(*) AS available_copies
FROM inventory_with_store iw
JOIN store s ON s.store_id = iw.store_id
JOIN film f ON f.film_id = iw.film_id
LEFT JOIN active_rentals ar ON ar.inventory_id = iw.inventory_id
WHERE ar.inventory_id IS NULL
GROUP BY s.store_id, f.title
ORDER BY s.store_id, available_copies DESC, f.title;
*/
--
-- Ejemplo de salida:
-- store_id | store | title               | available_copies
-- -------- | ----- | ------------------ | ----------------
-- 1        | 1     | ACADEMY DINOSAUR   | 3
-- 1        | 1     | ALI FOREVER        | 2
-- 1        | 1     | APACHE DIVINE      | 2


-- Q4 CTE: Retrasos por categoría (rentas tardías y promedio de días tarde)
-- Propósito: medir comportamiento de retrasos por categoría de película.
--
-- SQL:
/*
WITH rental_with_due AS (
    SELECT
        r.rental_id,
        r.rental_date,
        r.return_date,
        f.film_id,
        f.title,
        c.name AS category_name,
        (r.rental_date + (f.rental_duration || ' days')::INTERVAL) AS due_date
    FROM rental r
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film f ON f.film_id = i.film_id
    JOIN film_category fc ON fc.film_id = f.film_id
    JOIN category c ON c.category_id = fc.category_id
),
late_rentals AS (
    SELECT
        category_name,
        rental_id,
        GREATEST(
            EXTRACT(DAY FROM (COALESCE(return_date, NOW()) - due_date)),
            0
        ) AS late_days
    FROM rental_with_due
    WHERE return_date IS NOT NULL
      AND return_date > due_date
)
SELECT
    category_name,
    COUNT(*) AS late_rentals_count,
    ROUND(AVG(late_days)::NUMERIC, 2) AS avg_late_days
FROM late_rentals
GROUP BY category_name
ORDER BY avg_late_days DESC;
*/
--
-- Ejemplo de salida:
-- category_name | late_rentals_count | avg_late_days
-- ------------- | ------------------ | -------------
-- Horror        | 120                | 3.45
-- Drama         | 210                | 3.12
-- Family        |  90                | 2.78


-- Q5 Auditoría pagos sospechosos
-- Propósito: detectar pagos mayores a un umbral o repetidos el mismo día
--            por el mismo cliente y mismo monto.
--
-- SQL:
/*
WITH payments_norm AS (
    SELECT
        payment_id,
        customer_id,
        amount,
        DATE(payment_date) AS payment_day
    FROM payment
),
repeated_same_day AS (
    SELECT
        customer_id,
        amount,
        payment_day,
        COUNT(*) AS times
    FROM payments_norm
    GROUP BY customer_id, amount, payment_day
    HAVING COUNT(*) >= 2
)
SELECT
    p.payment_id,
    p.customer_id,
    p.amount,
    p.payment_date,
    CASE
        WHEN p.amount > 50 THEN 'HIGH_AMOUNT'
        WHEN r.times IS NOT NULL THEN 'REPEATED_SAME_DAY'
        ELSE 'OK'
    END AS risk_flag
FROM payment p
LEFT JOIN repeated_same_day r
  ON r.customer_id = p.customer_id
 AND r.amount = p.amount
 AND r.payment_day = DATE(p.payment_date)
WHERE p.amount > 50
   OR r.times IS NOT NULL
ORDER BY p.payment_date DESC;
*/
--
-- Ejemplo de salida:
-- payment_id | customer_id | amount | payment_date          | risk_flag
-- ---------- | ----------- | ------ | --------------------- | ---------
-- 16005      | 148         | 75.99  | 2020-06-18 10:01:23   | HIGH_AMOUNT
-- 16006      | 148         | 15.00  | 2020-06-18 10:05:10   | REPEATED_SAME_DAY
-- 16007      | 148         | 15.00  | 2020-06-18 10:07:45   | REPEATED_SAME_DAY


-- Q6 Clientes con riesgo (mora): clientes con N o más rentas tardías
-- (return_date > rental_date + film.rental_duration).
-- Propósito: identificar clientes en riesgo de morosidad.
--
-- SQL (usar N = 3 como ejemplo):
/*
WITH rental_with_due AS (
    SELECT
        r.rental_id,
        r.customer_id,
        r.rental_date,
        r.return_date,
        (r.rental_date + (f.rental_duration || ' days')::INTERVAL) AS due_date
    FROM rental r
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film f ON f.film_id = i.film_id
),
late_rentals AS (
    SELECT
        customer_id,
        rental_id
    FROM rental_with_due
    WHERE return_date IS NOT NULL
      AND return_date > due_date
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(lr.rental_id) AS late_rentals
FROM customer c
JOIN late_rentals lr ON lr.customer_id = c.customer_id
GROUP BY c.customer_id, customer_name
HAVING COUNT(lr.rental_id) >= 3
ORDER BY late_rentals DESC;
*/
--
-- Ejemplo de salida:
-- customer_id | customer_name   | late_rentals
-- ----------- | -------------- | ------------
-- 148         | ELEANOR HUNT   | 7
-- 178         | JODIE KRAMER   | 5
-- 526         | RICKY BLAKE    | 3


-- Q7 Consistencia: inventory con >1 renta activa (return_date IS NULL)
-- Propósito: verificar que la invariante de "a lo sumo una renta activa
-- por inventory_id" se cumple. Esta consulta se debería usar después
-- de pruebas de concurrencia (pgbench y la API /rentals).
--
-- SQL:
/*
SELECT
    inventory_id,
    COUNT(*) AS active_rentals,
    ARRAY_AGG(rental_id ORDER BY rental_id) AS rental_ids
FROM rental
WHERE return_date IS NULL
GROUP BY inventory_id
HAVING COUNT(*) > 1
ORDER BY active_rentals DESC, inventory_id;
*/
--
-- Ejemplo de salida (idealmente, 0 filas; se muestra un ejemplo hipotético):
-- inventory_id | active_rentals | rental_ids
-- ------------ | -------------- | ---------------------
-- 42           | 2              | {10234,10235}
-- 99           | 3              | {11001,11005,11007}
-- 150          | 2              | {11100,11101}

