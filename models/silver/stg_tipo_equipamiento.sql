{{ config(materialized='table') }}

/*
  3NF: Catálogo de tipos de equipamiento. Dimensión estable sin SCD-2.
  es_estandar_otan y es_interoperable son atributos del TIPO de equipo,
  no del inventario por país → movidos desde stg_inventario_equipamiento.
  dominio eliminado: accesible via categoria_equipamiento → stg_cat_categoria_equipamiento.

  es_estandar_otan puede ser "Yes"/"No"/"Partial" (CSV fuente no es booleano).
  Cuando el mismo tipo aparece con valores distintos entre países (ruido de datos)
  se toma el valor de mayor estandarización: Yes > Partial > No.
*/

with base as (
    select
        trim(equipment_type)                                as tipo_equipamiento,
        trim(equipment_category)                            as categoria_equipamiento,
        case upper(trim(nato_standardized))
            when 'YES'     then 'Yes'
            when 'NO'      then 'No'
            when 'PARTIAL' then 'Partial'
            else trim(nato_standardized)
        end                                                 as es_estandar_otan,
        case
            when upper(trim(interoperable)) in ('YES','Y','TRUE','1')   then true
            when upper(trim(interoperable)) in ('NO','N','FALSE','0')   then false
            else null
        end                                                 as es_interoperable
    from {{ ref('bronze_equipment_inventory') }}
    where equipment_type is not null
      and trim(equipment_type) != ''
)

select
    tipo_equipamiento,
    categoria_equipamiento,
    es_estandar_otan,
    es_interoperable,
    current_timestamp()                                     as cargado_en
from base
qualify row_number() over (
    partition by tipo_equipamiento
    order by
        case es_estandar_otan when 'Yes' then 1 when 'Partial' then 2 when 'No' then 3 else 4 end asc,
        case when es_interoperable then 1 else 2 end asc
) = 1
