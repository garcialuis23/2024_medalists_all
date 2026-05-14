{{ config(materialized='table') }}

select
    codigo_iso,
    pais,
    region,
    capital,
    area_km2,
    tipo_gobierno,
    rol_alianza,
    anio_ingreso_otan,
    anos_en_otan,
    es_miembro_fundador,
    tiene_comparticion_nuclear,
    case
        when anio_ingreso_otan <= 1949 then 'Miembro Fundador'
        when anio_ingreso_otan between 1950 and 1982 then 'Primera Expansión'
        when anio_ingreso_otan between 1990 and 2003 then 'Expansión Post-GF'
        when anio_ingreso_otan >= 2004 then 'Expansión Este'
        else 'Desconocido'
    end                                                             as generacion_otan
from (
    select distinct
        codigo_iso,
        pais,
        region,
        capital,
        area_km2,
        tipo_gobierno,
        rol_alianza,
        anio_ingreso_otan,
        anos_en_otan,
        es_miembro_fundador,
        tiene_comparticion_nuclear
    from {{ ref('stg_nato__country_stats') }}
    where codigo_iso is not null
)
