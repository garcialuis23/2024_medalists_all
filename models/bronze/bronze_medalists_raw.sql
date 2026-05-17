{{ config(materialized='table') }}

-- Capa Bronze: ingesta cruda del seed 2024_medalists_all.
-- Convierte 'NA' a NULL y castea campos numéricos/fecha.
-- No aplica ninguna lógica de negocio ni normalización.

select
    medalist_wikidata_id,
    medalist_link,
    medalist_name,
    medal,

    delegation_wikidata_id,
    delegation_link,
    delegation_name,

    country_medal_wikidata_id,
    country_medal,
    country_medal_code2,
    country_medal_code3,
    country_medal_ioc_country_code,
    nullif(country_medal_nuts_code, 'NA')                           as country_medal_nuts_code,

    try_to_date(nullif(date_of_birth, 'NA'))                        as date_of_birth,
    place_of_birth_wikidata_id,
    place_of_birth,
    nullif(place_of_birth_located_in_wikidata_id, 'NA')             as place_of_birth_located_in_wikidata_id,
    nullif(place_of_birth_located_in, 'NA')                         as place_of_birth_located_in,
    nullif(place_of_birth_coordinates, 'NA')                        as place_of_birth_coordinates,
    try_to_double(nullif(lat, 'NA'))                                 as lat,
    try_to_double(nullif(lon, 'NA'))                                 as lon,

    sex_or_gender_wikidata_id,
    sex_or_gender,

    event_wikidata_id,
    event_link,
    event_name,
    nullif(event_part_of_wikidata_id, 'NA')                         as event_part_of_wikidata_id,
    nullif(event_part_of, 'NA')                                     as event_part_of,
    nullif(event_sport_wikidata_id, 'NA')                           as event_sport_wikidata_id,
    nullif(event_sport, 'NA')                                       as event_sport,
    nullif(event_part_of_sport_wikidata_id, 'NA')                   as event_part_of_sport_wikidata_id,
    nullif(event_part_of_sport, 'NA')                               as event_part_of_sport,
    sport_wikidata_id,
    sport,

    nullif(nuts1_id, 'NA')                                          as nuts1_id,
    nullif(nuts1_name, 'NA')                                        as nuts1_name,
    nullif(nuts2_id, 'NA')                                          as nuts2_id,
    nullif(nuts2_name, 'NA')                                        as nuts2_name,
    nullif(nuts3_id, 'NA')                                          as nuts3_id,
    nullif(nuts3_name, 'NA')                                        as nuts3_name,
    try_to_double(nullif(nuts2_population, 'NA'))                    as nuts2_population,
    try_to_double(nullif(nuts3_population, 'NA'))                    as nuts3_population,
    try_to_double(nullif(nuts2_gdp, 'NA'))                          as nuts2_gdp,
    try_to_double(nullif(nuts3_gdp, 'NA'))                          as nuts3_gdp,
    nullif(nuts0_id, 'NA')                                          as nuts0_id,
    nullif(nuts0_name, 'NA')                                        as nuts0_name

from {{ ref('2024_medalists_all') }}
