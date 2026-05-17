{{ config(materialized='table') }}

select distinct
    nullif(sport_wikidata_id, 'NA')  as wikidata_id_deporte,
    nullif(sport, 'NA')              as nombre

from {{ ref('bronze_medalists_raw') }}
where nullif(sport_wikidata_id, 'NA') is not null
