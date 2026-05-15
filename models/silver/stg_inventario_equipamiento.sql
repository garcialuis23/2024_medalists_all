{{ config(materialized='table') }}

with source as (
    select
        trim(record_id)                                         as record_id,
        trim(iso_code)                                          as codigo_iso,
        trim(equipment_type)                                    as tipo_equipamiento,
        trim(country_of_origin)                                 as pais_origen,
        try_cast(trim(units_count) as integer)                  as cantidad_unidades,
        upper(trim(operational_status))                         as estado_operacional,
        trim(condition)                                         as condicion,
        to_date(trim(year_acquired) || '-01-01')                as fecha_adquisicion,
        try_cast(trim(unit_cost_m_usd) as float)                as coste_unitario_m_usd,
        try_cast(upper(trim(nato_standardized)) as boolean)     as es_estandar_otan,
        try_cast(upper(trim(interoperable)) as boolean)         as es_interoperable,
        try_cast(trim(last_maintenance_year) as integer)        as anio_ultimo_mantenimiento,
        try_cast(trim(next_upgrade_due) as integer)             as anio_proximo_upgrade,
        try_cast(trim(combat_ready_pct) as float)               as pct_combat_ready,
        _loaded_at
    from {{ ref('bronze_equipment_inventory') }}
    where record_id is not null
),

-- Hash over all mutable operational attributes
with_hash as (
    select *,
        md5(
            coalesce(estado_operacional, '')               || '|' ||
            coalesce(condicion, '')                        || '|' ||
            coalesce(cast(cantidad_unidades as varchar), '') || '|' ||
            coalesce(cast(pct_combat_ready as varchar), '') || '|' ||
            coalesce(cast(es_estandar_otan as varchar), '') || '|' ||
            coalesce(cast(es_interoperable as varchar), '')
        )                                                       as hash_diff
    from source
),

-- One row per (record_id, hash_diff): deduplicate identical reloads
deduped as (
    select *
    from with_hash
    qualify row_number() over (
        partition by record_id, hash_diff
        order by _loaded_at
    ) = 1
),

-- Assign validity windows: each version is valid until the next change is loaded
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
        max(_loaded_at) over (partition by record_id)          as ultimo_loaded_at
    from deduped
)

select
    record_id,
    codigo_iso,
    tipo_equipamiento,
    pais_origen,
    cantidad_unidades,
    estado_operacional,
    condicion,
    fecha_adquisicion,
    coste_unitario_m_usd,
    es_estandar_otan,
    es_interoperable,
    anio_ultimo_mantenimiento,
    anio_proximo_upgrade,
    pct_combat_ready,
    hash_diff,
    fecha_inicio_validez,
    fecha_fin_validez,
    (_loaded_at = ultimo_loaded_at)                             as es_registro_actual,
    _loaded_at                                                  as cargado_en
from with_validity
