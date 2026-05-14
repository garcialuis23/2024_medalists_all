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
    -- Atributos de misión desde la dimensión (descriptivos)
    dm.tipo_mision,
    dm.region_operacion,
    dm.nivel_amenaza,
    dm.anio_inicio_operacion,
    dm.anio_fin_operacion,
    dm.es_liderada_otan,
    dm.tiene_mandato_onu,
    -- Estado de misión desde la dimensión
    em.estado_mision_es,
    em.resultado_mision_es,
    -- Métricas de contexto de la misión desde Silver (no desde otro fact)
    m.coste_mision_m_usd,
    m.tropas_desplegadas,
    -- Atributos del país desde dimensión
    pa.region                                                       as region_pais,
    pa.generacion_otan,
    pa.es_miembro_fundador,
    -- Rol desde dimensión
    r.categoria_rol,
    r.es_rol_liderazgo,
    -- Fecha desde dimensión
    f.era_otan,
    f.decada,
    -- Métrica calculada
    case
        when p.tropas_contribuidas > 0 and m.tropas_desplegadas > 0
        then round(p.tropas_contribuidas * 100.0 / m.tropas_desplegadas, 2)
        else null
    end                                                             as pct_tropas_sobre_total_mision
from {{ ref('stg_nato__mission_participants') }}     p
left join {{ ref('dim_mision') }}                   dm on p.id_mision          = dm.id_mision
left join {{ ref('stg_nato__operations_missions') }} m  on p.id_mision          = m.record_id
left join {{ ref('dim_estado_mision') }}            em on m.fase_mision         = em.fase_mision
                                                       and m.estado_mision      = em.estado_mision
                                                       and m.resultado_mision   = em.resultado_mision
left join {{ ref('dim_pais') }}                     pa on p.codigo_iso          = pa.codigo_iso
left join {{ ref('dim_rol_participacion') }}        r  on p.rol_participacion   = r.rol_participacion
left join {{ ref('dim_fecha') }}                    f  on dm.anio_inicio_operacion = f.anio
where p.id_participante is not null
