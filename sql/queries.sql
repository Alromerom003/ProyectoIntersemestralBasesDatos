-- ==========================================================
-- Consultas para proyecto Pagila
-- ==========================================================

-- Query 1. Analysis: Ranking de clientes (top 10)
-- Objetivo: Identificar los clientes con mayor volumen de facturación.

SELECT 
    c.customer_id,
    c.first_name || '' || c.last_name AS customer_full_name,
    SUM(P.amount) AS total_revenue,
    DENSE_RANK() OVER (ORDER BY SUM(p.amount) DESC) AS rank_pos
FROM customer c
INNER JOIN payment p ON p.customer_id = c.customer_id
GROUP BY c.customer_id, customer_full_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 2. Ranking: Preferencias por sucursal (top 3)
-- Uso de ROW_NUMBER() para segmentación por store_id.

WITH film_stats AS (
    SELECT
        s.store_id,
        f.film_id,
        f.title,
        COUNT(r.rental_id) AS total_rentals
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
        total_rentals,
        ROW_NUMBER() OVER (
            PARTITION BY store_id
            ORDER BY total_rentals DESC
        ) AS rank_in_store
    FROM film_stats
) AS sub 
WHERE rank_in_store <= 3
ORDER BY store_id, rank_in_store;

-- Query 3. Inventory: Disponibilidad real en tienda
-- Anti-join optimizado para filtrar rentas que no han sido devueltas.

WITH current_rentals AS (
    SELECT inventory_id
    FROM rental
    WHERE return_date IS NULL
)
SELECT
    s.store_id,
    f.title,
    COUNT(i.inventory_id) AS stock_available
FROM inventory i
JOIN store s ON s.store_id = i.store_id
JOIN film f ON f.film_id = i.film_id
LEFT JOIN current_rentals cr ON cr.inventory_id = i.inventory_id
WHERE cr.inventory_id IS NULL
GROUP BY s.store_id, f.title
ORDER BY s.store_id, stock_available DESC;

-- Query 4. Metrics: Análisis de retrasos por categoría
-- Mide el promedio de días de demora comparando return_date vd due_date.
WITH rental_deadlines AS (
    SELECT
        r.rental_id,
        c.name AS category,
        (r.rental_date + (f.rental_duration * INTERVAL '1 day')) AS limit_date,
        r.return_date
    FROM rental r
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film f ON f.film_id = i.film_id
    JOIN film_category fc ON fc.film_id = f.film_id
    JOIN category c ON c.category_id = fc.category_id
),
delay_calc AS (
    SELECT category,
        EXTRACT(DAY FROM (COALESCE(retun_date, NOW()) - limit_date)) AS days_overdue
    FROM rental_deadlines
    WHERE return_date > limit_date OR return_date IS NULL
)
SELECT
    category,
COUNT (*) AS total_late_cases,
ROUND(AVG(GREATEST(days_overdue, 0)):: NUMERIC, 2) AS avg_delay_days
FROM delay_calc
GROUP BY category
ORDER BY avg_delay_days DESC;


-- Query 5. Risk: Detección de pagos atípicos
-- Identifica transacciones de alto monto o duplicidad en el mismo día.

WITH daily_payment_check AS (
    SELECT
        customer_id,
        amount,
        payment_date:: DATE AS p_date,
        COUNT(*) OVER(PARTITION BY customer_id, amount, payment_date:: DATE) as occurrence_count
    FROM payment
)
SELECT
    p.payment_id,
    p.customer_id,
    p.aoumt,
    p.payment_date,
    CASE
        WHEN p.amount > 50 THEN 'CRITICAL_AMOUNT'
        WHEN d.occurrence_count > 1 THEN 'POTENTIAL_DUPLICATE'
        ELSE 'VERIFIED'
    END AS status_flag
FROM payment p
JOIN daily_payment_check d ON p.customer_id = d.customer_id AND p.payment_date = p.payment_date
WHERE p.amount > 50 OR d.occurrence_count >1
ORDER BY p.payment_date DESC;
    
-- Query 6. Risk Analysis: Clientes con Morosidad Crítica
-- Identifica usuarios con 3 o más rentas devueltas después de la fecha límite.

WITH rental_status AS (
    SELECT 
        r.rental_id,
        r.customer_id,
        (r.rental_date + (f.rental_duration * INTERVAL '1 day')) AS expected_return,
        r.return_date
    FROM rental r
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film f ON f.film_id = i.film_id
),
late_list AS (
    SELECT 
        customer_id,
        rental_id
    FROM rental_status
    WHERE return_date > expected_return
)
SELECT
    c.customer_id
    c.first_name || '' || c.last_name AS full_name,
    COUNT(ll.rental_id) AS total_late_returns
FROM customer c
INNER JOIN late_list ll ON ll.customer_id = c.customer_id
GROUP BY c.customer_id, full_name
HAVIMG COUNT(ll.rental_id) >= 3
ORDER BY total_late_returns DESC;
    

-- Query 7. Integrity: Verificación de variante inventario
-- Detecta si un ítem de inventario tiene múltiples rentas activas (sería un error de concurrencia).
-- Valida pruebas de estrés.

SELECT 
    inventory_id,
    COUNT(*) AS active_count,
    STRING_AGG(rental_id:: TEXT, ', ' ORDER BY rental_id) AS active_rental_ids
FROM rental
WHERE return_date IS NULL
GROUP BY inventory_id
HAVING COUNT(*) > 1
ORDER BY active_count DESC;

