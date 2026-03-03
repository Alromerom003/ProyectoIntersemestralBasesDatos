SELECT
    inventory_id,
    COUNT(*) AS active_rentals
FROM rental
WHERE return_date IS NULL
GROUP BY inventory_id
HAVING COUNT(*) > 1;

SELECT
    COUNT(*) AS total_active_rentals
FROM rental
WHERE return_date IS NULL;