-- Falla si total_medals != gold + silver + bronze en cualquier país.
-- Con datos sucios podrían aparecer tipos de medalla no esperados que rompen la suma.
SELECT
    id_pais,
    nombre,
    total_medallas,
    medallas_oro + medallas_plata + medallas_bronce AS suma_calculada
FROM {{ ref('dim_pais') }}
WHERE total_medallas != medallas_oro + medallas_plata + medallas_bronce
