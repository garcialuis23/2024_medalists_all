{{ config(materialized='table') }}

select distinct
    country_medal_wikidata_id   as country_id,
    country_medal               as name,
    country_medal_code2         as code2,
    country_medal_code3         as code3,
    country_medal_ioc_country_code as ioc_code

from {{ ref('bronze_medalists_raw') }}
