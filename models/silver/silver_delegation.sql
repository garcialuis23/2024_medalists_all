{{ config(materialized='table') }}

select distinct
    cast(delegation_wikidata_id     as varchar)  as wikidata_id_delegacion,
    cast(delegation_name            as varchar)  as nombre,
    cast(delegation_link            as varchar)  as enlace,
    cast(country_medal_wikidata_id  as varchar)  as wikidata_id_pais

from {{ ref('bronze_medalists_raw') }}
