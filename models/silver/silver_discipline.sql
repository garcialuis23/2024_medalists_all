{{ config(materialized='table') }}

-- Disciplina = agrupación de eventos (event_part_of), p.ej. "archery at the 2024 Summer Olympics".
-- sport_wikidata_id es el deporte siempre presente (event_part_of_sport puede ser NULL en equipos).

select distinct
    nullif(event_part_of_wikidata_id, 'NA')  as wikidata_id_disciplina,
    nullif(event_part_of, 'NA')              as nombre,
    nullif(sport_wikidata_id, 'NA')          as wikidata_id_deporte

from {{ ref('bronze_medalists_raw') }}
where nullif(event_part_of_wikidata_id, 'NA') is not null
