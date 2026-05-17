{{ config(materialized='table') }}

select distinct
    cast(sport_wikidata_id  as varchar)  as wikidata_id_deporte,
    cast(sport              as varchar)  as nombre

from {{ ref('bronze_medalists_raw') }}
where sport_wikidata_id is not null
