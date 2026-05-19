-- Valida que todos los identificadores Wikidata empiecen por 'Q'.
-- Con datos sucios del CSV pueden colarse IDs vacíos o con formato incorrecto.
SELECT 'silver_country'  AS tabla, wikidata_id_pais      AS id FROM {{ ref('silver_pais')  }} WHERE wikidata_id_pais      != 'N/A' AND wikidata_id_pais      NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_athlete',            wikidata_id_atleta           FROM {{ ref('silver_atleta')  }} WHERE wikidata_id_atleta     NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_event',              wikidata_id_evento           FROM {{ ref('silver_evento')    }} WHERE wikidata_id_evento     NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_sport',              wikidata_id_deporte          FROM {{ ref('silver_deporte')    }} WHERE wikidata_id_deporte    != 'N/A' AND wikidata_id_deporte    NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_discipline',         wikidata_id_disciplina       FROM {{ ref('silver_disciplina') }} WHERE wikidata_id_disciplina != 'N/A' AND wikidata_id_disciplina NOT LIKE 'Q%'
