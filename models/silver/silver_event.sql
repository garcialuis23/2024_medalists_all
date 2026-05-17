{{ config(materialized='table') }}

select distinct
    cast(event_wikidata_id          as varchar)  as wikidata_id_evento,
    cast(event_name                 as varchar)  as nombre,
    cast(event_link                 as varchar)  as enlace,
    cast(event_part_of_wikidata_id  as varchar)  as wikidata_id_disciplina

from {{ ref('bronze_medalists_raw') }}
