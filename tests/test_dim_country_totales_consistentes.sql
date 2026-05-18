-- Falla si total_medals != gold + silver + bronze en cualquier país.
-- Con datos sucios podrían aparecer tipos de medalla no esperados que rompen la suma.
SELECT
    country_id,
    name,
    total_medals,
    gold_medals + silver_medals + bronze_medals AS suma_calculada
FROM {{ ref('dim_country') }}
WHERE total_medals != gold_medals + silver_medals + bronze_medals
