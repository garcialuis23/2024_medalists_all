{{ config(materialized='table') }}

select
    region,
    zona_geografica,
    es_flanco_este,
    es_norte_america
from {{ ref('stg_cat_region') }}
