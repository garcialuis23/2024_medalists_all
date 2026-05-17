{{ config(materialized='table') }}

select distinct
    sport_wikidata_id   as sport_id,
    sport               as name

from {{ ref('bronze_medalists_raw') }}
where sport_wikidata_id is not null
