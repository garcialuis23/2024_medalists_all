{{ config(materialized='table') }}

-- 3NF: Catálogo de tipos de equipamiento.
-- En la tabla original, tipo+categoria+dominio se repiten en cada fila del inventario.
-- Atributos del tipo de equipo dependen del tipo, no del país que lo posee.
select distinct
    trim(equipment_type)                                    as tipo_equipamiento,
    trim(equipment_category)                                as categoria_equipamiento,
    trim(domain)                                            as dominio
from {{ ref('bronze_equipment_inventory') }}
where equipment_type is not null
