{{ config(materialized='table', database=("SILVER_DB_PRO" if target.name == "pro" else "SILVER_DB_DEV")) }}

select distinct
    nullif(event_wikidata_id, 'NA')          as wikidata_id_evento,
    nullif(event_name, 'NA')                 as nombre,
    nullif(event_link, 'NA')                 as enlace,
    nullif(event_part_of_wikidata_id, 'NA')  as wikidata_id_disciplina

from {{ ref('bronze_medalists_raw') }}
where nullif(event_wikidata_id, 'NA') is not null
