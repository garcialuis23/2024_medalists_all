-- Falla si Silver pierde o duplica filas respecto a Bronze.
-- Con datos sucios la carga puede crear duplicados o rechazar filas — este test lo detecta.
SELECT ABS(cnt_bronze - cnt_silver) AS diferencia
FROM (
    SELECT COUNT(*) AS cnt_bronze FROM {{ ref('bronze_medalists_raw') }}
) b
CROSS JOIN (
    SELECT COUNT(*) AS cnt_silver FROM {{ ref('silver_medal') }}
) s
WHERE b.cnt_bronze != s.cnt_silver
