{{ config(materialized='table') }}

/*
  SCD-2 Pattern 2: ventanas de validez basadas en tiempo de carga (_loaded_at).
  Cada recarga que altere atributos mutables genera una nueva versión.
  mision_sk: surrogate key determinista dentro del run (ROW_NUMBER).
  tipo_liderazgo: varchar porque la fuente contiene "Yes", "No" y "Joint UN-NATO".
  region_operacion eliminada: 3NF, accesible vía ubicacion_operacion → stg_cat_ubicacion_operacion.
  Campos calculados (paises_contribuyentes, totales de tropa) movidos a Gold.
*/

with source as (
    select
        trim(record_id)                                         as id_mision,
        trim(mission_name)                                      as nombre_mision,
        trim(mission_type)                                      as tipo_mision,
        trim(lead_iso_code)                                     as codigo_iso_lider,
        trim(operation_location)                                as ubicacion_operacion,
        trim(threat_level)                                      as nivel_amenaza,
        trim(command_hq)                                        as cuartel_general,
        to_date(trim(operation_start_year) || '-01-01')         as fecha_inicio_operacion,
        case
            when trim(operation_end_year) is null
              or trim(operation_end_year) = ''                  then null
            else to_date(trim(operation_end_year) || '-12-31')
        end                                                     as fecha_fin_operacion,
        trim(mission_phase)                                     as fase_mision,
        trim(mission_status)                                    as estado_mision,
        trim(mission_outcome)                                   as resultado_mision,
        trim(classification)                                    as clasificacion,
        trim(media_coverage)                                    as cobertura_mediatica,
        case upper(trim(nato_led))
            when 'YES' then 'NATO'
            when 'NO'  then 'Non-NATO'
            else trim(nato_led)
        end                                                     as tipo_liderazgo,
        case
            when upper(trim(un_mandate)) in ('YES','Y','TRUE','1') then true
            when upper(trim(un_mandate)) in ('NO','N','FALSE','0') then false
            else null
        end                                                     as tiene_mandato_onu,
        trim(after_action_report)                               as informe_post_accion,
        try_cast(trim(public_support_pct) as float)             as pct_apoyo_publico,
        _loaded_at
    from {{ ref('bronze_operations_missions') }}
    where record_id is not null
),

with_hash as (
    select *,
        md5(
            coalesce(nombre_mision,          '') || '|' ||
            coalesce(tipo_mision,            '') || '|' ||
            coalesce(codigo_iso_lider,       '') || '|' ||
            coalesce(ubicacion_operacion,    '') || '|' ||
            coalesce(nivel_amenaza,          '') || '|' ||
            coalesce(fase_mision,            '') || '|' ||
            coalesce(estado_mision,          '') || '|' ||
            coalesce(resultado_mision,       '') || '|' ||
            coalesce(tipo_liderazgo,         '') || '|' ||
            coalesce(cast(tiene_mandato_onu as varchar), '') || '|' ||
            coalesce(cast(pct_apoyo_publico as varchar), '')
        )                                                       as hash_diff
    from source
),

deduped as (
    select *
    from with_hash
    qualify row_number() over (
        partition by id_mision, hash_diff
        order by _loaded_at
    ) = 1
),

with_validity as (
    select *,
        _loaded_at                                              as fecha_inicio_validez,
        coalesce(
            lead(_loaded_at) over (
                partition by id_mision
                order by _loaded_at
            ),
            '9999-12-31'::timestamp
        )                                                       as fecha_fin_validez,
        max(_loaded_at) over (partition by id_mision)           as ultimo_loaded_at
    from deduped
)

select
    row_number() over (
        order by id_mision, fecha_inicio_validez
    )                                                           as mision_sk,
    id_mision,
    nombre_mision,
    tipo_mision,
    codigo_iso_lider,
    ubicacion_operacion,
    nivel_amenaza,
    cuartel_general,
    fecha_inicio_operacion,
    fecha_fin_operacion,
    fase_mision,
    estado_mision,
    resultado_mision,
    clasificacion,
    cobertura_mediatica,
    tipo_liderazgo,
    tiene_mandato_onu,
    informe_post_accion,
    pct_apoyo_publico,
    hash_diff,
    fecha_inicio_validez,
    fecha_fin_validez,
    (_loaded_at = ultimo_loaded_at)                             as es_registro_actual,
    current_timestamp()                                         as cargado_en
from with_validity
