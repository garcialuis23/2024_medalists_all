{{ config(materialized='table') }}

-- Tabla de hechos: una fila por medalla ganada (athlete_id × event_id es único).
-- medal_id: surrogate key reproducible basado en MD5 de las dos claves naturales.

select
    md5(medalist_wikidata_id || '|' || event_wikidata_id)   as medal_id,
    medalist_wikidata_id                                    as athlete_id,
    event_wikidata_id                                       as event_id,
    delegation_wikidata_id                                  as delegation_id,
    country_medal_wikidata_id                               as country_id,
    medal                                                   as type

from {{ ref('bronze_medalists_raw') }}
