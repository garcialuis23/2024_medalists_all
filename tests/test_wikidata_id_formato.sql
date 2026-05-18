-- Valida que todos los identificadores Wikidata empiecen por 'Q'.
-- Con datos sucios del CSV pueden colarse IDs vacíos o con formato incorrecto.
SELECT 'silver_country'  AS tabla, wikidata_id_pais      AS id FROM {{ ref('silver_country')  }} WHERE wikidata_id_pais      != 'N/A' AND wikidata_id_pais      NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_athlete',            wikidata_id_atleta           FROM {{ ref('silver_athlete')  }} WHERE wikidata_id_atleta     NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_event',              wikidata_id_evento           FROM {{ ref('silver_event')    }} WHERE wikidata_id_evento     NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_sport',              wikidata_id_deporte          FROM {{ ref('silver_sport')    }} WHERE wikidata_id_deporte    != 'N/A' AND wikidata_id_deporte    NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_discipline',         wikidata_id_disciplina       FROM {{ ref('silver_discipline') }} WHERE wikidata_id_disciplina != 'N/A' AND wikidata_id_disciplina NOT LIKE 'Q%'
