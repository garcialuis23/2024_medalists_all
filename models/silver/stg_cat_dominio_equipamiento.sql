{{ config(materialized='table') }}

-- Dominios de equipamiento OTAN.
-- Nivel raíz de la jerarquía: dominio → categoría → tipo.
select distinct
    trim(domain)                                            as dominio,
    null::varchar                                           as descripcion,
    current_timestamp()                                     as cargado_en
from {{ ref('bronze_equipment_inventory') }}
where domain is not null
  and trim(domain) != ''
