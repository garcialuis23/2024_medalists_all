{{ config(materialized='table') }}

with fuente as (
    select * from {{ ref('bronze_operations_missions') }}
)

select
    record_id,
    mission_name                                                    as nombre_mision,
    mission_type                                                    as tipo_mision,
    lead_country                                                    as pais_lider,
    lead_iso_code                                                   as codigo_iso_lider,
    lead_country_region                                             as region_pais_lider,
    operation_location                                              as ubicacion_operacion,
    operation_region                                                as region_operacion,
    threat_level                                                    as nivel_amenaza,
    command_hq                                                      as cuartel_general,
    try_cast(operation_start_year as integer)                       as anio_inicio_operacion,
    try_cast(operation_end_year as integer)                         as anio_fin_operacion,
    try_cast(duration_years as float)                               as duracion_anos,
    mission_phase                                                   as fase_mision,
    try_cast(troops_deployed as integer)                            as tropas_desplegadas,
    try_cast(air_assets_deployed as integer)                        as activos_aereos_desplegados,
    try_cast(naval_assets_deployed as integer)                      as activos_navales_desplegados,
    try_cast(casualties as integer)                                 as bajas,
    try_cast(casualties_rate_pct as float)                          as pct_bajas,
    try_cast(mission_cost_m_usd as float)                           as coste_mision_m_usd,
    try_cast(cost_per_soldier_usd as float)                         as coste_por_soldado_usd,
    try_cast(contributing_countries_count as integer)               as paises_contribuyentes,
    try_cast(nato_led as boolean)                                   as es_liderada_otan,
    try_cast(un_mandate as boolean)                                 as tiene_mandato_onu,
    mission_outcome                                                 as resultado_mision,
    mission_status                                                  as estado_mision,
    classification                                                  as clasificacion,
    media_coverage                                                  as cobertura_mediatica,
    try_cast(public_support_pct as float)                           as pct_apoyo_publico,
    after_action_report                                             as informe_post_accion,
    _source_file                                                    as archivo_fuente,
    _loaded_at                                                      as cargado_en
from fuente
