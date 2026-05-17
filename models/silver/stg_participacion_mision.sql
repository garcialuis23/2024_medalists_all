{{ config(materialized='table') }}

/*
  SCD-2 Pattern 2: ventanas de validez por tiempo de carga.
  Natural key: (id_mision, codigo_iso, rol_participacion) — un país puede
  participar con varios roles simultáneos en la misma misión (e.g. "Lead" + "Support").
  BUG del modelo anterior: deduplicaba sobre (mission_record_id, iso_code) únicamente,
  perdiendo filas de multi-rol.
  participacion_sk: surrogate PK determinista dentro del run.
  mision_sk + pais_sk: FKs a versión actual de sus dimensiones (patrón dual key).
  fecha_inicio_participacion: derivada de mision.fecha_inicio_operacion (CSV4 sin fechas).
*/

with source as (
    select
        trim(participant_id)                                    as id_participante,
        trim(mission_record_id)                                 as id_mision,
        trim(iso_code)                                          as codigo_iso,
        trim(participation_role)                                as rol_participacion,
        try_cast(trim(troops_contributed) as integer)           as tropas_contribuidas,
        try_cast(trim(air_assets_contributed) as integer)       as activos_aereos_contribuidos,
        try_cast(trim(naval_assets_contributed) as integer)     as activos_navales_contribuidos,
        _loaded_at
    from {{ ref('bronze_mission_participants') }}
    where participant_id is not null
),

with_hash as (
    select *,
        md5(
            coalesce(cast(tropas_contribuidas as varchar),          '') || '|' ||
            coalesce(cast(activos_aereos_contribuidos as varchar),  '') || '|' ||
            coalesce(cast(activos_navales_contribuidos as varchar), '')
        )                                                       as hash_diff
    from source
),

-- Dedup: una fila por (natural_key + hash_diff), la más antigua de cada versión
deduped as (
    select *
    from with_hash
    qualify row_number() over (
        partition by id_mision, codigo_iso, rol_participacion, hash_diff
        order by _loaded_at
    ) = 1
),

with_validity as (
    select *,
        _loaded_at                                              as fecha_inicio_validez,
        coalesce(
            lead(_loaded_at) over (
                partition by id_mision, codigo_iso, rol_participacion
                order by _loaded_at
            ),
            '9999-12-31'::timestamp
        )                                                       as fecha_fin_validez,
        max(_loaded_at) over (
            partition by id_mision, codigo_iso, rol_participacion
        )                                                       as ultimo_loaded_at
    from deduped
)

select
    row_number() over (
        order by v.id_mision, v.codigo_iso, v.rol_participacion, v.fecha_inicio_validez
    )                                                           as participacion_sk,
    m.mision_sk,
    p.pais_sk,
    v.id_participante,
    v.id_mision,
    v.codigo_iso,
    v.rol_participacion,
    v.tropas_contribuidas,
    v.activos_aereos_contribuidos,
    v.activos_navales_contribuidos,
    m.fecha_inicio_operacion                                    as fecha_inicio_participacion,
    v.hash_diff,
    v.fecha_inicio_validez,
    v.fecha_fin_validez,
    (v._loaded_at = v.ultimo_loaded_at)                         as es_registro_actual,
    current_timestamp()                                         as cargado_en
from with_validity v
left join {{ ref('stg_mision') }} m
    on  m.id_mision = v.id_mision
    and m.es_registro_actual = true
left join {{ ref('stg_pais') }} p
    on  p.codigo_iso = v.codigo_iso
    and p.es_registro_actual = true
