{{ config(materialized='table') }}

select
    s.codigo_iso,
    s.pais,
    s.anio,
    s.region,
    s.pib_bn_usd,
    s.presupuesto_defensa_bn_usd,
    s.defensa_pct_pib,
    s.cumple_objetivo_2pct,
    case
        when s.cumple_objetivo_2pct then 'Cumple Objetivo'
        else 'Bajo Objetivo'
    end                                                             as estado_objetivo_2pct,
    s.pib_per_capita_usd,
    s.poblacion_millones,
    s.tasa_inflacion_pct,
    s.tasa_desempleo_pct,
    case
        when s.poblacion_millones > 0
        then round((s.presupuesto_defensa_bn_usd * 1000) / s.poblacion_millones, 2)
        else null
    end                                                             as gasto_defensa_per_capita_usd,
    case
        when s.pib_bn_usd > 0
        then round(s.presupuesto_defensa_bn_usd / s.pib_bn_usd * 100, 4)
        else null
    end                                                             as defensa_pct_pib_calc,
    p.generacion_otan,
    p.es_miembro_fundador,
    p.tiene_comparticion_nuclear,
    p.rol_alianza,
    f.era_otan,
    f.es_era_guerra_fria,
    f.decada
from {{ ref('stg_nato__country_stats') }} s
left join {{ ref('dim_pais') }}  p on s.codigo_iso = p.codigo_iso
left join {{ ref('dim_fecha') }} f on s.anio = f.anio
where s.anio is not null
  and s.pib_bn_usd is not null
