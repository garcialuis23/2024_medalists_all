-- Valida que todos los identificadores Wikidata empiecen por 'Q'.
-- Con datos sucios del CSV pueden colarse IDs vacíos o con formato incorrecto.
SELECT 'silver_pais'        AS tabla, wikidata_id_pais        AS id FROM {{ ref('silver_pais')        }} WHERE wikidata_id_pais        != 'N/A' AND wikidata_id_pais        NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_atleta',              wikidata_id_atleta              FROM {{ ref('silver_atleta')       }} WHERE wikidata_id_atleta        NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_evento',              wikidata_id_evento              FROM {{ ref('silver_evento')        }} WHERE wikidata_id_evento         NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_deporte',             wikidata_id_deporte             FROM {{ ref('silver_deporte')       }} WHERE wikidata_id_deporte    != 'N/A' AND wikidata_id_deporte    NOT LIKE 'Q%'
UNION ALL
SELECT 'silver_disciplina',          wikidata_id_disciplina          FROM {{ ref('silver_disciplina')    }} WHERE wikidata_id_disciplina != 'N/A' AND wikidata_id_disciplina NOT LIKE 'Q%'
