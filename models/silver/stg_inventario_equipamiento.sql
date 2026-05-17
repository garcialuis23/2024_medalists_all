{{ config(materialized='table') }}

/*
  SCD-2 Pattern 2: ventanas de validez por tiempo de carga.
  es_estandar_otan + es_interoperable REMOVIDOS → movidos a stg_tipo_equipamiento.
  pais_sk: FK a stg_pais (versión actual) para simplificar joins en Gold.
  codigo_iso_origen: normalizado vía stg_cat_pais_origen.
  anio_ultimo_mantenimiento + anio_proximo_upgrade: integer → date (01-01 del año).
  codigo_iso natural key conservado desnormalizado junto al FK (patrón dual key).
*/

with source as (
    select
        trim(record_id)                                         as record_id,
        trim(iso_code)                                          as codigo_iso,
        trim(equipment_type)                                    as tipo_equipamiento,
        case upper(trim(country_of_origin))
            when 'MULTI-NATIONAL' then 'MNA'
            when 'UK'             then 'GBR'
            else trim(country_of_origin)
        end                                                     as codigo_iso_origen,
        try_cast(trim(units_count) as integer)                  as cantidad_unidades,
        upper(trim(operational_status))                         as estado_operacional,
        trim(condition)                                         as condicion,
        to_date(trim(year_acquired) || '-01-01')                as fecha_adquisicion,
        try_cast(trim(unit_cost_m_usd) as float)                as coste_unitario_m_usd,
        case
            when trim(last_maintenance_year) is not null
             and trim(last_maintenance_year) != ''
            then to_date(trim(last_maintenance_year) || '-01-01')
            else null
        end                                                     as fecha_ultimo_mantenimiento,
        case
            when trim(next_upgrade_due) is not null
             and trim(next_upgrade_due) != ''
            then to_date(trim(next_upgrade_due) || '-01-01')
            else null
        end                                                     as fecha_proximo_upgrade,
        try_cast(trim(combat_ready_pct) as float)               as pct_combat_ready,
        _loaded_at
    from {{ ref('bronze_equipment_inventory') }}
    where record_id is not null
),

with_hash as (
    select *,
        md5(
            coalesce(estado_operacional, '')                    || '|' ||
            coalesce(condicion, '')                             || '|' ||
            coalesce(cast(cantidad_unidades as varchar), '')    || '|' ||
            coalesce(cast(pct_combat_ready as varchar), '')     || '|' ||
            coalesce(cast(fecha_ultimo_mantenimiento as varchar), '')
        )                                                       as hash_diff
    from source
),

deduped as (
    select *
    from with_hash
    qualify row_number() over (
        partition by record_id, hash_diff
        order by _loaded_at
    ) = 1
),

with_validity as (
    select *,
        _loaded_at                                              as fecha_inicio_validez,
        coalesce(
            lead(_loaded_at) over (
                partition by record_id
                order by _loaded_at
            ),
            '9999-12-31'::timestamp
        )                                                       as fecha_fin_validez,
        max(_loaded_at) over (partition by record_id)           as ultimo_loaded_at
    from deduped
)

select
    v.record_id,
    p.pais_sk,
    v.codigo_iso,
    v.tipo_equipamiento,
    v.codigo_iso_origen,
    v.cantidad_unidades,
    v.estado_operacional,
    v.condicion,
    v.fecha_adquisicion,
    v.coste_unitario_m_usd,
    v.fecha_ultimo_mantenimiento,
    v.fecha_proximo_upgrade,
    v.pct_combat_ready,
    v.hash_diff,
    v.fecha_inicio_validez,
    v.fecha_fin_validez,
    (v._loaded_at = v.ultimo_loaded_at)                         as es_registro_actual,
    current_timestamp()                                         as cargado_en
from with_validity v
left join {{ ref('stg_pais') }} p
    on  p.codigo_iso = v.codigo_iso
    and p.es_registro_actual = true
