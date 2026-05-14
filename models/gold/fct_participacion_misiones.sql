{{ config(materialized='table') }}

select
    p.id_participante,
    p.id_mision,
    p.nombre_mision,
    p.pais,
    p.codigo_iso,
    p.rol_participacion,
    p.tropas_contribuidas,
    p.activos_aereos_contribuidos,
    p.activos_navales_contribuidos,
    p.pct_contribucion,
    m.tipo_mision,
    m.region_operacion,
    m.nivel_amenaza,
    m.anio_inicio_operacion,
    m.anio_fin_operacion,
    m.es_liderada_otan,
    m.tiene_mandato_onu,
    m.estado_mision_es,
    m.resultado_mision_es,
    m.coste_mision_m_usd,
    pa.region                                                       as region_pais,
    pa.generacion_otan,
    pa.es_miembro_fundador,
    r.categoria_rol,
    r.es_rol_liderazgo,
    f.era_otan,
    f.decada,
    case
        when p.tropas_contribuidas > 0 and m.tropas_desplegadas > 0
        then round(p.tropas_contribuidas * 100.0 / m.tropas_desplegadas, 2)
        else null
    end                                                             as pct_tropas_sobre_total_mision
from {{ ref('stg_nato__mission_participants') }} p
left join {{ ref('fct_misiones') }}          m  on p.id_mision       = m.id_mision
left join {{ ref('dim_pais') }}              pa on p.codigo_iso       = pa.codigo_iso
left join {{ ref('dim_rol_participacion') }} r  on p.rol_participacion = r.rol_participacion
left join {{ ref('dim_fecha') }}             f  on m.anio_inicio_operacion = f.anio
where p.id_participante is not null
