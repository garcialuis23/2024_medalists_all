{{ config(materialized='table') }}

with source as (
    select * from {{ ref('bronze_operations_missions') }}
)

select
    record_id,
    mission_name,
    mission_type,
    lead_country,
    lead_iso_code,
    lead_country_region,
    operation_location,
    operation_region,
    threat_level,
    command_hq,
    try_cast(operation_start_year as integer)               as operation_start_year,
    try_cast(operation_end_year as integer)                 as operation_end_year,
    try_cast(duration_years as float)                       as duration_years,
    mission_phase,
    try_cast(troops_deployed as integer)                    as troops_deployed,
    try_cast(air_assets_deployed as integer)                as air_assets_deployed,
    try_cast(naval_assets_deployed as integer)              as naval_assets_deployed,
    try_cast(casualties as integer)                         as casualties,
    try_cast(casualties_rate_pct as float)                  as casualties_rate_pct,
    try_cast(mission_cost_m_usd as float)                   as mission_cost_m_usd,
    try_cast(cost_per_soldier_usd as float)                 as cost_per_soldier_usd,
    try_cast(contributing_countries_count as integer)       as contributing_countries_count,
    try_cast(nato_led as boolean)                           as is_nato_led,
    try_cast(un_mandate as boolean)                         as has_un_mandate,
    mission_outcome,
    mission_status,
    classification,
    media_coverage,
    try_cast(public_support_pct as float)                   as public_support_pct,
    after_action_report,
    _source_file,
    _loaded_at
from source
