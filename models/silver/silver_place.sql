{{ config(materialized='table') }}

-- Un lugar de nacimiento único por place_id.
-- QUALIFY toma la fila con coordenadas si existen (lat not null primero).

select
    place_of_birth_wikidata_id          as place_id,
    place_of_birth                      as name,
    place_of_birth_located_in_wikidata_id as located_in_id,
    place_of_birth_located_in           as located_in_name,
    lat,
    lon,
    nuts3_id

from {{ ref('bronze_medalists_raw') }}
qualify row_number() over (
    partition by place_of_birth_wikidata_id
    order by lat nulls last
) = 1
