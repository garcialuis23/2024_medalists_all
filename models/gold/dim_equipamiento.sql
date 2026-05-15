{{ config(materialized='table') }}

select
    tipo_equipamiento,
    categoria_equipamiento,
    dominio,
    case
        when dominio = 'Air'     then 'Aéreo'
        when dominio = 'Land'    then 'Terrestre'
        when dominio = 'Sea'     then 'Naval'
        when dominio = 'Support' then 'Apoyo'
        else dominio
    end                                                         as dominio_es
from {{ ref('stg_tipo_equipamiento') }}
where tipo_equipamiento is not null
