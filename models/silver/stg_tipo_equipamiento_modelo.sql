{{ config(materialized='table') }}

select
    trim(equipment_type)                        as tipo_equipamiento,
    trim(f.value)                               as modelo_destacado,
    row_number() over (
        partition by trim(equipment_type)
        order by f.index
    )                                           as orden_modelo
from {{ ref('bronze_equipment_inventory') }},
lateral split_to_table(notable_models, '/') f
where equipment_type is not null
  and trim(f.value) <> ''
qualify row_number() over (
    partition by trim(equipment_type), trim(f.value)
    order by f.index
) = 1
