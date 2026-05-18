{{ config(materialized='table', database=("SILVER_DB_PRO" if target.name == "pro" else "SILVER_DB_DEV")) }}

select distinct
    nullif(event_wikidata_id, 'NA')                                as wikidata_id_evento,
    nullif(event_name, 'NA')                                       as nombre,
    nullif(event_link, 'NA')                                       as enlace,
    case
        when nullif(event_wikidata_id, 'NA') = 'Q128645552' then 'Q109317225'
        else coalesce(nullif(nullif(event_part_of_wikidata_id, 'NA'), ''), 'N/A')
    end                                                            as wikidata_id_disciplina

from {{ ref('bronze_medalists_raw') }}
where nullif(event_wikidata_id, 'NA') is not null
