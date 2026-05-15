{{ config(materialized='table') }}

select distinct
    trim(command_hq) as cuartel_general
from {{ ref('bronze_operations_missions') }}
where command_hq is not null
