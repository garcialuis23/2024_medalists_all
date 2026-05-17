{{ config(materialized='table') }}

select distinct
    delegation_wikidata_id      as delegation_id,
    delegation_name             as name,
    delegation_link             as link,
    country_medal_wikidata_id   as country_id

from {{ ref('bronze_medalists_raw') }}
