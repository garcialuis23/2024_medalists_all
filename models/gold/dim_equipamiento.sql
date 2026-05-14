{{ config(materialized='table') }}

select distinct
    tipo_equipamiento,
    categoria_equipamiento,
    dominio,
    modelos_destacados,
    pais_origen,
    es_estandar_otan,
    case
        when dominio = 'Air'     then 'Aéreo'
        when dominio = 'Land'    then 'Terrestre'
        when dominio = 'Sea'     then 'Naval'
        when dominio = 'Support' then 'Apoyo'
        else dominio
    end                                                             as dominio_es,
    case
        when es_estandar_otan and es_interoperable then 'Total'
        when es_estandar_otan or es_interoperable  then 'Parcial'
        else 'No'
    end                                                             as nivel_integracion_otan
from {{ ref('stg_nato__equipment_inventory') }}
where tipo_equipamiento is not null
