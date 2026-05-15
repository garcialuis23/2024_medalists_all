{{ config(materialized='table') }}

select
    e.codigo_iso,
    p.pais,
    p.region,
    year(e.fecha)                                               as anio,
    e.fecha,
    e.personal_activo,
    e.personal_reserva,
    e.personal_total,
    e.score_interoperabilidad,
    e.ejercicios_entrenamiento_anio,
    e.rango_contribucion_otan,
    case
        when e.personal_total > 0
        then round(e.personal_activo * 100.0 / e.personal_total, 2)
        else null
    end                                                         as pct_fuerzas_activas,
    case
        when e.poblacion_millones > 0
        then round(e.personal_total / (e.poblacion_millones * 1000000) * 1000, 2)
        else null
    end                                                         as militares_por_1000_hab,
    case
        when e.score_interoperabilidad >= 8 then 'Alto'
        when e.score_interoperabilidad >= 5 then 'Medio'
        else 'Bajo'
    end                                                         as nivel_interoperabilidad,
    p.generacion_otan,
    p.es_miembro_fundador,
    p.rol_alianza,
    f.era_otan,
    f.decada
from {{ ref('stg_estadisticas_pais') }}  e
left join {{ ref('dim_pais') }}  p on e.codigo_iso         = p.codigo_iso
left join {{ ref('dim_fecha') }} f on year(e.fecha)        = f.anio
where e.personal_total is not null
