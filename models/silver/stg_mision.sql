{{ config(materialized='table') }}

select
    trim(record_id)                                             as id_mision,
    trim(mission_name)                                          as nombre_mision,
    trim(mission_type)                                          as tipo_mision,
    trim(lead_iso_code)                                         as codigo_iso_lider,
    trim(operation_location)                                    as ubicacion_operacion,
    trim(operation_region)                                      as region_operacion,
    trim(threat_level)                                          as nivel_amenaza,
    trim(command_hq)                                            as cuartel_general,
    to_date(trim(operation_start_year) || '-01-01')             as fecha_inicio_operacion,
    case
        when trim(operation_end_year) is null
          or trim(operation_end_year) = ''                      then null
        else to_date(trim(operation_end_year) || '-12-31')
    end                                                         as fecha_fin_operacion,
    trim(mission_phase)                                         as fase_mision,
    trim(mission_status)                                        as estado_mision,
    trim(mission_outcome)                                       as resultado_mision,
    trim(classification)                                        as clasificacion,
    trim(media_coverage)                                        as cobertura_mediatica,
    try_cast(upper(trim(nato_led)) as boolean)                  as es_liderada_otan,
    try_cast(upper(trim(un_mandate)) as boolean)                as tiene_mandato_onu,
    trim(after_action_report)                                   as informe_post_accion,
    try_cast(trim(troops_deployed) as integer)                  as tropas_desplegadas,
    try_cast(trim(air_assets_deployed) as integer)              as activos_aereos_desplegados,
    try_cast(trim(naval_assets_deployed) as integer)            as activos_navales_desplegados,
    try_cast(trim(casualties) as integer)                       as bajas,
    try_cast(trim(mission_cost_m_usd) as float)                 as coste_mision_m_usd,
    try_cast(trim(contributing_countries_count) as integer)     as paises_contribuyentes,
    try_cast(trim(public_support_pct) as float)                 as pct_apoyo_publico,
    _loaded_at                                                  as cargado_en
from {{ ref('bronze_operations_missions') }}
where record_id is not null
