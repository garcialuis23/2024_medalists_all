{{ config(materialized='table') }}

select distinct
    trim(mission_phase)   as fase_mision,
    trim(mission_status)  as estado_mision,
    trim(mission_outcome) as resultado_mision
from {{ ref('bronze_operations_missions') }}
where mission_phase is not null
