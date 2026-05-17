{{ config(materialized='table') }}

select distinct
    nullif(country_medal_wikidata_id, 'NA')       as wikidata_id_pais,
    nullif(country_medal, 'NA')                   as nombre,
    nullif(country_medal_code2, 'NA')             as codigo_iso2,
    nullif(country_medal_code3, 'NA')             as codigo_iso3,
    nullif(country_medal_ioc_country_code, 'NA')  as codigo_coi

from {{ ref('bronze_medalists_raw') }}
where nullif(country_medal_wikidata_id, 'NA') is not null
