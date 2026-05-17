{{ config(materialized='table') }}

-- Un lugar de nacimiento único por wikidata_id_lugar.
-- QUALIFY toma la fila con coordenadas si existen (latitud not null primero).

select
    cast(place_of_birth_wikidata_id                 as varchar)  as wikidata_id_lugar,
    cast(place_of_birth                             as varchar)  as nombre,
    cast(place_of_birth_located_in_wikidata_id      as varchar)  as wikidata_id_ubicado_en,
    cast(place_of_birth_located_in                  as varchar)  as nombre_ubicado_en,
    cast(lat                                        as float)    as latitud,
    cast(lon                                        as float)    as longitud,
    cast(nuts3_id                                   as varchar)  as id_nuts3

from {{ ref('bronze_medalists_raw') }}
qualify row_number() over (
    partition by place_of_birth_wikidata_id
    order by lat nulls last
) = 1
