{{ config(materialized='table') }}

select distinct
    cast(country_medal_wikidata_id       as varchar)  as wikidata_id_pais,
    cast(country_medal                   as varchar)  as nombre,
    cast(country_medal_code2             as varchar)  as codigo_iso2,
    cast(country_medal_code3             as varchar)  as codigo_iso3,
    cast(country_medal_ioc_country_code  as varchar)  as codigo_coi

from {{ ref('bronze_medalists_raw') }}
