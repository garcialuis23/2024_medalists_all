{{ config(materialized='table') }}

-- Un atleta único por wikidata_id_atleta.
-- QUALIFY prefiere la fila con fecha de nacimiento conocida.

select
    cast(medalist_wikidata_id           as varchar)  as wikidata_id_atleta,
    cast(medalist_name                  as varchar)  as nombre,
    cast(medalist_link                  as varchar)  as enlace,
    cast(date_of_birth                  as date)     as fecha_nacimiento,
    cast(sex_or_gender                  as varchar)  as sexo,
    cast(place_of_birth_wikidata_id     as varchar)  as wikidata_id_lugar

from {{ ref('bronze_medalists_raw') }}
qualify row_number() over (
    partition by medalist_wikidata_id
    order by date_of_birth nulls last
) = 1
