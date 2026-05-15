{{ config(materialized='table') }}

select
    m.id_mision,
    m.nombre_mision,
    m.tipo_mision,
    m.codigo_iso_lider,
    p.pais                                                      as pais_lider,
    p.region                                                    as region_pais_lider,
    m.region_operacion,
    m.nivel_amenaza,
    m.fecha_inicio_operacion,
    m.fecha_fin_operacion,
    year(m.fecha_inicio_operacion)                              as anio_inicio,
    year(m.fecha_fin_operacion)                                 as anio_fin,
    case
        when m.fecha_fin_operacion is not null
        then round(
            datediff('day', m.fecha_inicio_operacion, m.fecha_fin_operacion) / 365.25,
            2)
        else null
    end                                                         as duracion_anos,
    m.tropas_desplegadas,
    m.activos_aereos_desplegados,
    m.activos_navales_desplegados,
    m.bajas,
    case
        when m.tropas_desplegadas > 0 and m.bajas is not null
        then round(m.bajas * 100.0 / m.tropas_desplegadas, 2)
        else null
    end                                                         as pct_bajas,
    m.coste_mision_m_usd,
    case
        when m.tropas_desplegadas > 0 and m.coste_mision_m_usd > 0
        then round(m.coste_mision_m_usd * 1000000 / m.tropas_desplegadas, 2)
        else null
    end                                                         as coste_por_soldado_usd,
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
        when m.coste_mision_m_usd > 0
         and m.fecha_fin_operacion is not null
         and datediff('day', m.fecha_inicio_operacion, m.fecha_fin_operacion) > 0
        then round(
            m.coste_mision_m_usd
            / (datediff('day', m.fecha_inicio_operacion, m.fecha_fin_operacion) / 365.25),
            2)
        else null
    end                                                         as coste_anual_m_usd
from {{ ref('stg_mision') }} m
left join {{ ref('dim_estado_mision') }} e
    on m.fase_mision       = e.fase_mision
    and m.estado_mision    = e.estado_mision
    and m.resultado_mision = e.resultado_mision
left join {{ ref('dim_pais') }}  p on m.codigo_iso_lider              = p.codigo_iso
left join {{ ref('dim_fecha') }} f on year(m.fecha_inicio_operacion)  = f.anio
where m.id_mision is not null
