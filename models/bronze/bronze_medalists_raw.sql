{{ config(materialized='table') }}

-- Capa Bronze: ingesta cruda del seed 2024_medalists_all.
-- Sin transformaciones: todos los valores llegan como varchar, incluidos los 'NA'.

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
    country_medal_nuts_code,

    date_of_birth,
    place_of_birth_wikidata_id,
    place_of_birth,
    place_of_birth_located_in_wikidata_id,
    place_of_birth_located_in,
    place_of_birth_coordinates,
    lat,
    lon,

    sex_or_gender_wikidata_id,
    sex_or_gender,

    event_wikidata_id,
    event_link,
    event_name,
    event_part_of_wikidata_id,
    event_part_of,
    event_sport_wikidata_id,
    event_sport,
    event_part_of_sport_wikidata_id,
    event_part_of_sport,
    sport_wikidata_id,
    sport,

    nuts1_id,
    nuts1_name,
    nuts2_id,
    nuts2_name,
    nuts3_id,
    nuts3_name,
    nuts2_population,
    nuts3_population,
    nuts2_gdp,
    nuts3_gdp,
    nuts0_id,
    nuts0_name

from {{ source('bronze', 'MEDALISTS_2024') }}
