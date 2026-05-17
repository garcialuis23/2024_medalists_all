{{ config(materialized='table', database=generate_database_name('SILVER_DB')) }}

select distinct
    nullif(delegation_wikidata_id, 'NA')     as wikidata_id_delegacion,
    nullif(delegation_name, 'NA')            as nombre,
    nullif(delegation_link, 'NA')            as enlace,
    nullif(country_medal_wikidata_id, 'NA')  as wikidata_id_pais

from {{ ref('bronze_medalists_raw') }}
where nullif(delegation_wikidata_id, 'NA') is not null
