{{ config(materialized='table', database=("SILVER_DB_PRO" if target.name == "pro" else "SILVER_DB_DEV")) }}

-- Un atleta único por wikidata_id_atleta.
-- QUALIFY prefiere la fila con fecha de nacimiento conocida.

select
    nullif(medalist_wikidata_id, 'NA')                          as wikidata_id_atleta,
    nullif(medalist_name, 'NA')                                 as nombre,
    nullif(medalist_link, 'NA')                                 as enlace,
    try_to_date(nullif(date_of_birth, 'NA'))                    as fecha_nacimiento,
    nullif(sex_or_gender, 'NA')                                 as sexo,
    nullif(place_of_birth_wikidata_id, 'NA')                    as wikidata_id_lugar

from {{ ref('bronze_medalists_raw') }}
qualify row_number() over (
    partition by nullif(medalist_wikidata_id, 'NA')
    order by try_to_date(nullif(date_of_birth, 'NA')) nulls last
) = 1
