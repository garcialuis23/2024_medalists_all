{{ config(materialized='table') }}

select distinct
    event_wikidata_id           as event_id,
    event_name                  as name,
    event_link                  as link,
    event_part_of_wikidata_id   as discipline_id

from {{ ref('bronze_medalists_raw') }}
