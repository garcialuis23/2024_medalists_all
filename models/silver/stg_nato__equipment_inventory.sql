{{ config(materialized='table') }}

with source as (
    select * from {{ ref('bronze_equipment_inventory') }}
)

select
    record_id,
    country,
    iso_code,
    try_cast(join_year as integer)                          as join_year,
    try_cast(founding_member as boolean)                    as is_founding_member,
    try_cast(nuclear_sharing as boolean)                    as has_nuclear_sharing,
    region,
    capital,
    equipment_type,
    equipment_category,
    domain,
    notable_models,
    try_cast(units_count as integer)                        as units_count,
    operational_status,
    condition,
    try_cast(year_acquired as integer)                      as year_acquired,
    try_cast(equipment_age_years as integer)                as equipment_age_years,
    try_cast(unit_cost_m_usd as float)                      as unit_cost_m_usd,
    try_cast(total_value_m_usd as float)                    as total_value_m_usd,
    country_of_origin,
    try_cast(nato_standardized as boolean)                  as is_nato_standardized,
    try_cast(interoperable as boolean)                      as is_interoperable,
    try_cast(last_maintenance_year as integer)              as last_maintenance_year,
    try_cast(next_upgrade_due as integer)                   as next_upgrade_due,
    try_cast(combat_ready_pct as float)                     as combat_ready_pct,
    _source_file,
    _loaded_at
from source
