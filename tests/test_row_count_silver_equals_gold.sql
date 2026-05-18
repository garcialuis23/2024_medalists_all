-- Falla si Gold pierde o duplica filas respecto a Silver.
SELECT ABS(cnt_silver - cnt_gold) AS diferencia
FROM (
    SELECT COUNT(*) AS cnt_silver FROM {{ ref('silver_medal') }}
) s
CROSS JOIN (
    SELECT COUNT(*) AS cnt_gold FROM {{ ref('fact_medal') }}
) g
WHERE s.cnt_silver != g.cnt_gold
