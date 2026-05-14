{{ config(materialized='table') }}

with personnel as (
    select
        country,
        iso_code,
        region,
        year,
        active_military_personnel,
        reserve_personnel,
        total_military_personnel,
        interoperability_score,
        training_exercises_per_year,
        nato_contribution_rank
    from {{ ref('stg_nato__country_stats') }}
    where year is not null
),

equipment_summary as (
    select
        country,
        iso_code,
        domain,
        count(*)                                                as equipment_types_count,
        sum(units_count)                                        as total_units,
        sum(total_value_m_usd)                                  as total_equipment_value_m_usd,
        avg(combat_ready_pct)                                   as avg_combat_readiness_pct
    from {{ ref('stg_nato__equipment_inventory') }}
    group by 1, 2, 3
)

select
    p.country,
    p.iso_code,
    p.region,
    p.year,
    p.active_military_personnel,
    p.reserve_personnel,
    p.total_military_personnel,
    p.interoperability_score,
    p.training_exercises_per_year,
    p.nato_contribution_rank,
    sum(e.total_units)                                          as total_equipment_units,
    sum(e.total_equipment_value_m_usd)                         as total_equipment_value_m_usd,
    round(avg(e.avg_combat_readiness_pct), 2)                  as avg_combat_readiness_pct
from personnel p
left join equipment_summary e
    on p.country = e.country
    and p.iso_code = e.iso_code
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
