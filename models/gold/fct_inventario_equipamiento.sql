{{ config(materialized='table') }}

select
    i.record_id,
    i.codigo_iso,
    p.pais,
    p.region,
    i.tipo_equipamiento,
    d.categoria_equipamiento,
    d.dominio,
    d.dominio_es,
    year(i.fecha_adquisicion)                                   as anio_adquisicion,
    i.fecha_adquisicion,
    i.cantidad_unidades,
    i.coste_unitario_m_usd,
    round(i.cantidad_unidades * i.coste_unitario_m_usd, 4)      as valor_total_m_usd,
    year(current_date()) - year(i.fecha_adquisicion)            as antiguedad_anos,
    i.estado_operacional,
    i.condicion,
    i.pct_combat_ready,
    i.es_estandar_otan,
    i.es_interoperable,
    i.anio_ultimo_mantenimiento,
    i.anio_proximo_upgrade,
    i.pais_origen,
    case
        when i.pct_combat_ready >= 90 then 'Óptimo'
        when i.pct_combat_ready >= 70 then 'Bueno'
        when i.pct_combat_ready >= 50 then 'Aceptable'
        else 'Crítico'
    end                                                         as estado_readiness,
    case
        when year(current_date()) - year(i.fecha_adquisicion) <= 10 then 'Nuevo'
        when year(current_date()) - year(i.fecha_adquisicion) <= 25 then 'Moderno'
        when year(current_date()) - year(i.fecha_adquisicion) <= 40 then 'Veterano'
        else 'Obsoleto'
    end                                                         as generacion_equipo,
    f.era_otan,
    f.decada
from {{ ref('stg_inventario_equipamiento') }}   i
left join {{ ref('dim_pais') }}         p on i.codigo_iso       = p.codigo_iso
left join {{ ref('dim_equipamiento') }} d on i.tipo_equipamiento = d.tipo_equipamiento
left join {{ ref('dim_fecha') }}        f on year(i.fecha_adquisicion) = f.anio
where i.tipo_equipamiento is not null
  and i.es_registro_actual = true
