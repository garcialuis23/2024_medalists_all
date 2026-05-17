{{ config(materialized='table') }}

-- Un atleta único por athlete_id.
-- QUALIFY prefiere la fila con fecha de nacimiento conocida.

select
    medalist_wikidata_id    as athlete_id,
    medalist_name           as name,
    medalist_link           as link,
    date_of_birth,
    sex_or_gender           as sex,
    place_of_birth_wikidata_id as place_id

from {{ ref('bronze_medalists_raw') }}
qualify row_number() over (
    partition by medalist_wikidata_id
    order by date_of_birth nulls last
) = 1
