{{ config(materialized='table') }}

-- Disciplina = agrupación de eventos (event_part_of), p.ej. "archery at the 2024 Summer Olympics".
-- sport_wikidata_id es el deporte siempre presente (event_part_of_sport puede ser NULL en equipos).

select distinct
    cast(event_part_of_wikidata_id  as varchar)  as wikidata_id_disciplina,
    cast(event_part_of              as varchar)  as nombre,
    cast(sport_wikidata_id          as varchar)  as wikidata_id_deporte

from {{ ref('bronze_medalists_raw') }}
where event_part_of_wikidata_id is not null
