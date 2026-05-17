{{ config(materialized='table') }}

-- Rompe la transitiva tipo_equipamiento → dominio (3NF).
-- Una categoría pertenece a un único dominio: Air Force → Air, Armored → Land, etc.
-- QUALIFY resuelve casos donde la misma categoría aparece con dominios distintos
-- por error de datos: se toma el dominio más frecuente.
with base as (
    select
        trim(equipment_category)                            as categoria_equipamiento,
        trim(domain)                                        as dominio,
        count(*)                                            as frecuencia
    from {{ ref('bronze_equipment_inventory') }}
    where equipment_category is not null
      and trim(equipment_category) != ''
    group by 1, 2
)

select
    categoria_equipamiento,
    dominio,
    null::varchar                                           as descripcion,
    current_timestamp()                                     as cargado_en
from base
qualify row_number() over (
    partition by categoria_equipamiento
    order by frecuencia desc
) = 1
