{{ config(materialized='table') }}

select distinct
    upper(trim(operational_status)) as estado_operacional
from {{ ref('bronze_equipment_inventory') }}
where operational_status is not null
