-- Falla si Gold pierde o duplica filas respecto a Silver.
SELECT ABS(cnt_silver - cnt_gold) AS diferencia
FROM (
    SELECT COUNT(*) AS cnt_silver FROM {{ ref('silver_medalla') }}
) s
CROSS JOIN (
    SELECT COUNT(*) AS cnt_gold FROM {{ ref('fact_medalla') }}
) g
WHERE s.cnt_silver != g.cnt_gold
