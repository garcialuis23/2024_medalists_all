{{ config(materialized='table') }}

with source as (
    select * from {{ ref('bronze_country_stats') }}
)

select
    record_id,
    country,
    iso_code,
    try_cast(join_year as integer)                          as join_year,
    try_cast(years_in_nato as integer)                      as years_in_nato,
    try_cast(founding_member as boolean)                    as is_founding_member,
    try_cast(nuclear_sharing as boolean)                    as has_nuclear_sharing,
    region,
    capital,
    try_cast(area_km2 as integer)                           as area_km2,
    government_type,
    alliance_role,
    try_cast(year as integer)                               as year,
    try_cast(population_m as float)                         as population_m,
    try_cast(gdp_billion_usd as float)                      as gdp_billion_usd,
    try_cast(gdp_per_capita_usd as float)                   as gdp_per_capita_usd,
    try_cast(inflation_rate_pct as float)                   as inflation_rate_pct,
    try_cast(unemployment_rate_pct as float)                as unemployment_rate_pct,
    try_cast(defense_budget_billion_usd as float)           as defense_budget_billion_usd,
    try_cast(defense_gdp_percent as float)                  as defense_gdp_percent,
    try_cast(meets_2_percent_target as boolean)             as meets_2_percent_target,
    try_cast(active_military_personnel as integer)          as active_military_personnel,
    try_cast(reserve_personnel as integer)                  as reserve_personnel,
    try_cast(total_military_personnel as integer)           as total_military_personnel,
    try_cast(nato_contribution_rank as integer)             as nato_contribution_rank,
    try_cast(interoperability_score as float)               as interoperability_score,
    try_cast(training_exercises_per_year as integer)        as training_exercises_per_year,
    _source_file,
    _loaded_at
from source
