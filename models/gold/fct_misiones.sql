{{ config(materialized='table') }}

select
    m.record_id                                                     as id_mision,
    m.nombre_mision,
    m.tipo_mision,
    m.pais_lider,
    m.codigo_iso_lider,
    m.region_operacion,
    m.nivel_amenaza,
    m.anio_inicio_operacion,
    m.anio_fin_operacion,
    m.duracion_anos,
    m.tropas_desplegadas,
    m.activos_aereos_desplegados,
    m.activos_navales_desplegados,
    m.bajas,
    m.pct_bajas,
    m.coste_mision_m_usd,
    m.coste_por_soldado_usd,
    m.paises_contribuyentes,
    m.es_liderada_otan,
    m.tiene_mandato_onu,
    m.pct_apoyo_publico,
    e.fase_mision,
    e.estado_mision_es,
    e.resultado_mision_es,
    f.era_otan,
    f.decada,
    case
        when m.coste_mision_m_usd > 0 and m.duracion_anos > 0
        then round(m.coste_mision_m_usd / m.duracion_anos, 2)
        else null
    end                                                             as coste_anual_m_usd,
    case
        when m.tropas_desplegadas > 0
        then round(m.bajas * 100.0 / m.tropas_desplegadas, 4)
        else null
    end                                                             as ratio_bajas_calc
from {{ ref('stg_nato__operations_missions') }} m
left join {{ ref('dim_estado_mision') }} e
    on m.fase_mision      = e.fase_mision
    and m.estado_mision   = e.estado_mision
    and m.resultado_mision = e.resultado_mision
left join {{ ref('dim_fecha') }} f on m.anio_inicio_operacion = f.anio
where m.record_id is not null
