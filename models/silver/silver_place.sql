{{ config(materialized='table') }}

-- Un lugar de nacimiento único por wikidata_id_lugar.
-- QUALIFY toma la fila con coordenadas si existen (latitud not null primero).

select
    nullif(place_of_birth_wikidata_id, 'NA')             as wikidata_id_lugar,
    nullif(place_of_birth, 'NA')                         as nombre,
    nullif(place_of_birth_located_in_wikidata_id, 'NA')  as wikidata_id_ubicado_en,
    nullif(place_of_birth_located_in, 'NA')              as nombre_ubicado_en,
    try_to_double(nullif(lat, 'NA'))                     as latitud,
    try_to_double(nullif(lon, 'NA'))                     as longitud,
    nullif(nuts3_id, 'NA')                               as id_nuts3

from {{ ref('bronze_medalists_raw') }}
where nullif(place_of_birth_wikidata_id, 'NA') is not null
qualify row_number() over (
    partition by nullif(place_of_birth_wikidata_id, 'NA')
    order by try_to_double(nullif(lat, 'NA')) nulls last
) = 1
