{{ config(materialized='table') }}

select
    s.codigo_iso,
    s.pais,
    s.anio,
    s.region,
    s.personal_militar_activo,
    s.personal_reserva,
    s.personal_militar_total,
    s.score_interoperabilidad,
    s.ejercicios_entrenamiento_anio,
    s.rango_contribucion_otan,
    case
        when s.personal_militar_total > 0
        then round(s.personal_militar_activo * 100.0 / s.personal_militar_total, 2)
        else null
    end                                                             as pct_fuerzas_activas,
    case
        when s.poblacion_millones > 0
        then round(s.personal_militar_total / (s.poblacion_millones * 1000000) * 1000, 2)
        else null
    end                                                             as militares_por_1000_hab,
    case
        when s.score_interoperabilidad >= 8 then 'Alto'
        when s.score_interoperabilidad >= 5 then 'Medio'
        else 'Bajo'
    end                                                             as nivel_interoperabilidad,
    p.generacion_otan,
    p.es_miembro_fundador,
    p.rol_alianza,
    f.era_otan,
    f.decada
from {{ ref('stg_nato__country_stats') }} s
left join {{ ref('dim_pais') }}  p on s.codigo_iso = p.codigo_iso
left join {{ ref('dim_fecha') }} f on s.anio = f.anio
where s.anio is not null
  and s.personal_militar_total is not null
