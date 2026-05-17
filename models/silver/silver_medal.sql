{{ config(materialized='table') }}

-- Tabla de hechos: una fila por medalla ganada (wikidata_id_atleta × wikidata_id_evento es único).
-- id_medalla: surrogate key reproducible basado en MD5 de las dos claves naturales.

select
    cast(md5(medalist_wikidata_id || '|' || event_wikidata_id)  as varchar)  as id_medalla,
    cast(medalist_wikidata_id                                   as varchar)  as wikidata_id_atleta,
    cast(event_wikidata_id                                      as varchar)  as wikidata_id_evento,
    cast(delegation_wikidata_id                                 as varchar)  as wikidata_id_delegacion,
    cast(country_medal_wikidata_id                              as varchar)  as wikidata_id_pais,
    cast(medal                                                  as varchar)  as tipo

from {{ ref('bronze_medalists_raw') }}
