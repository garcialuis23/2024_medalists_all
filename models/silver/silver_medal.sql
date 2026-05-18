{{ config(materialized='table', database=("SILVER_DB_PRO" if target.name == "pro" else "SILVER_DB_DEV")) }}

-- Tabla de hechos: una fila por medalla ganada (wikidata_id_atleta × wikidata_id_evento es único).
-- id_medalla: surrogate key reproducible basado en MD5 de las dos claves naturales.
-- wikidata_id_pais: COALESCE a 'N/A' para medallas sin país identificado.

select
    md5(nullif(medalist_wikidata_id, 'NA') || '|' || nullif(event_wikidata_id, 'NA'))  as id_medalla,
    nullif(medalist_wikidata_id, 'NA')                                                 as wikidata_id_atleta,
    nullif(event_wikidata_id, 'NA')                                                    as wikidata_id_evento,
    nullif(delegation_wikidata_id, 'NA')                                               as wikidata_id_delegacion,
    coalesce(nullif(country_medal_wikidata_id, 'NA'), 'N/A')                           as wikidata_id_pais,
    nullif(medal, 'NA')                                                                as tipo

from {{ ref('bronze_medalists_raw') }}
where nullif(medalist_wikidata_id, 'NA') is not null
  and nullif(event_wikidata_id, 'NA') is not null
  and coalesce(nullif(country_medal_wikidata_id, 'NA'), 'N/A') in (
      select wikidata_id_pais from {{ ref('silver_country') }}
  )
