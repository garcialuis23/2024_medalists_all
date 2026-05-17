{{ config(materialized='table') }}

-- Disciplina = agrupación de eventos (event_part_of), p.ej. "archery at the 2024 Summer Olympics".
-- sport_wikidata_id es el deporte siempre presente (event_part_of_sport puede ser NULL en equipos).

select distinct
    event_part_of_wikidata_id   as discipline_id,
    event_part_of               as name,
    sport_wikidata_id           as sport_id

from {{ ref('bronze_medalists_raw') }}
where event_part_of_wikidata_id is not null
