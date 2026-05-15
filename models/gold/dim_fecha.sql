{{ config(materialized='table') }}

with anos as (
    select distinct year(fecha)                    as anio
    from {{ ref('stg_estadisticas_pais') }}        where fecha is not null
    union
    select distinct year(fecha_inicio_operacion)   as anio
    from {{ ref('stg_mision') }}                   where fecha_inicio_operacion is not null
    union
    select distinct year(fecha_fin_operacion)      as anio
    from {{ ref('stg_mision') }}                   where fecha_fin_operacion is not null
    union
    select distinct year(fecha_adquisicion)        as anio
    from {{ ref('stg_inventario_equipamiento') }}  where fecha_adquisicion is not null
)

select
    anio,
    floor(anio / 10) * 10                                      as decada,
    case
        when anio < 1950                  then 'Pre-OTAN'
        when anio between 1950 and 1991   then 'Guerra Fría'
        when anio between 1992 and 2003   then 'Post-Guerra Fría'
        when anio between 2004 and 2014   then 'Expansión Este'
        else                                   'Era Actual'
    end                                                         as era_otan,
    case when anio <= 1991 then true else false end              as es_era_guerra_fria,
    case when anio >= floor(year(current_date()) / 10) * 10
         then true else false end                               as es_decada_actual,
    case when anio >= year(current_date()) - 5
         then true else false end                               as es_anio_reciente,
    floor(anio / 100) + 1                                      as siglo
from anos
order by anio
