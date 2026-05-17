{{ config(materialized='table') }}

-- Rompe la transitiva mision.ubicacion_operacion → region (3NF).
-- FK a stg_cat_region.region, que agrupa ubicaciones en zonas geopolíticas.
-- QUALIFY: si la misma ubicación aparece con distintas regiones (dato ruidoso)
-- se toma la región más frecuente.
with base as (
    select
        trim(operation_location)                            as ubicacion_operacion,
        trim(operation_region)                              as region,
        count(*)                                            as frecuencia
    from {{ ref('bronze_operations_missions') }}
    where operation_location is not null
      and trim(operation_location) != ''
    group by 1, 2
)

select
    ubicacion_operacion,
    region,
    null::varchar                                           as descripcion,
    current_timestamp()                                     as cargado_en
from base
qualify row_number() over (
    partition by ubicacion_operacion
    order by frecuencia desc
) = 1
