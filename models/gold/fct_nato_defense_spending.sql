{{ config(materialized='table') }}

select
    country,
    iso_code,
    region,
    year,
    gdp_billion_usd,
    defense_budget_billion_usd,
    defense_gdp_percent,
    meets_2_percent_target,
    case
        when meets_2_percent_target then 'Meets Target'
        else 'Below Target'
    end                                                         as target_status,
    population_m,
    gdp_per_capita_usd,
    case
        when population_m > 0
        then round((defense_budget_billion_usd * 1000) / population_m, 2)
        else null
    end                                                         as defense_spend_per_capita_usd,
    is_founding_member,
    has_nuclear_sharing,
    alliance_role,
    nato_contribution_rank
from {{ ref('stg_nato__country_stats') }}
where year is not null
  and gdp_billion_usd is not null
