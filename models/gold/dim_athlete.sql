{{ config(materialized='table') }}

-- Dimensión atletas con lugar de nacimiento desnormalizado.

select
    a.athlete_id,
    a.name,
    a.link,
    a.date_of_birth,
    a.sex,
    p.name                  as birthplace,
    p.located_in_name       as birthplace_region,
    p.lat                   as birthplace_lat,
    p.lon                   as birthplace_lon,
    p.nuts3_id              as birthplace_nuts3_id

from {{ ref('silver_athlete') }} a
left join {{ ref('silver_place') }} p
    on a.place_id = p.place_id
