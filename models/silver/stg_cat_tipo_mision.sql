{{ config(materialized='table') }}

select distinct
    trim(mission_type) as tipo_mision
from {{ ref('bronze_operations_missions') }}
where mission_type is not null
