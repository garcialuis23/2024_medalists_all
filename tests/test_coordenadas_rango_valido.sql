-- Detecta coordenadas fuera de rango físicamente imposible.
-- Con datos sucios del CSV es el primer sitio donde aparecen valores como 999 o -999.
SELECT wikidata_id_lugar, latitud, longitud
FROM {{ ref('silver_lugar') }}
WHERE
    (latitud  IS NOT NULL AND (latitud  < -90  OR latitud  > 90))
    OR (longitud IS NOT NULL AND (longitud < -180 OR longitud > 180))
