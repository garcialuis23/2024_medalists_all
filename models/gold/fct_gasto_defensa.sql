{{ config(materialized='table') }}

select
    e.codigo_iso,
    p.pais,
    p.region,
    year(e.fecha)                                               as anio,
    e.fecha,
    e.pib_bn_usd,
    e.presupuesto_defensa_bn_usd,
    e.defensa_pct_pib,
    e.cumple_objetivo_2pct,
    case when e.cumple_objetivo_2pct then 'Cumple Objetivo'
         else 'Bajo Objetivo' end                               as estado_objetivo_2pct,
    e.pib_per_capita_usd,
    e.poblacion_millones,
    e.tasa_inflacion_pct,
    e.tasa_desempleo_pct,
    case
        when e.poblacion_millones > 0
        then round((e.presupuesto_defensa_bn_usd * 1000) / e.poblacion_millones, 2)
        else null
    end                                                         as gasto_defensa_per_capita_usd,
    p.generacion_otan,
    p.es_miembro_fundador,
    p.tiene_comparticion_nuclear,
    p.rol_alianza,
    f.era_otan,
    f.es_era_guerra_fria,
    f.decada
from {{ ref('stg_estadisticas_pais') }}  e
left join {{ ref('dim_pais') }}  p on e.codigo_iso         = p.codigo_iso
left join {{ ref('dim_fecha') }} f on year(e.fecha)        = f.anio
where e.pib_bn_usd is not null
