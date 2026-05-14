{{ config(materialized='table') }}

select
    e.codigo_iso,
    e.pais,
    e.region,
    e.tipo_equipamiento,
    e.categoria_equipamiento,
    e.dominio,
    e.anio_adquisicion,
    e.cantidad_unidades,
    e.coste_unitario_m_usd,
    e.valor_total_m_usd,
    e.antiguedad_anos,
    e.estado_operacional,
    e.condicion,
    e.pct_combat_ready,
    e.es_estandar_otan,
    e.es_interoperable,
    e.anio_ultimo_mantenimiento,
    e.anio_proximo_upgrade,
    e.pais_origen,
    case
        when e.pct_combat_ready >= 90 then 'Óptimo'
        when e.pct_combat_ready >= 70 then 'Bueno'
        when e.pct_combat_ready >= 50 then 'Aceptable'
        else 'Crítico'
    end                                                             as estado_readiness,
    case
        when e.antiguedad_anos <= 10 then 'Nuevo'
        when e.antiguedad_anos <= 25 then 'Moderno'
        when e.antiguedad_anos <= 40 then 'Veterano'
        else 'Obsoleto'
    end                                                             as generacion_equipo,
    d.dominio_es,
    d.nivel_integracion_otan,
    f.era_otan,
    f.decada
from {{ ref('stg_nato__equipment_inventory') }} e
left join {{ ref('dim_equipamiento') }} d
    on e.tipo_equipamiento = d.tipo_equipamiento
    and e.categoria_equipamiento = d.categoria_equipamiento
left join {{ ref('dim_fecha') }} f on e.anio_adquisicion = f.anio
where e.tipo_equipamiento is not null
