{{ config(materialized='table') }}

with missions as (
    select
        record_id                                               as mission_record_id,
        mission_name,
        mission_type,
        lead_country,
        lead_iso_code,
        operation_region,
        threat_level,
        operation_start_year,
        operation_end_year,
        mission_phase,
        mission_outcome,
        mission_status,
        is_nato_led,
        has_un_mandate,
        mission_cost_m_usd,
        public_support_pct
    from {{ ref('stg_nato__operations_missions') }}
),

participants as (
    select
        mission_record_id,
        country,
        iso_code,
        participation_role,
        troops_contributed,
        air_assets_contributed,
        naval_assets_contributed,
        contribution_pct
    from {{ ref('stg_nato__mission_participants') }}
)

select
    p.country,
    p.iso_code,
    p.participation_role,
    m.mission_name,
    m.mission_type,
    m.operation_region,
    m.threat_level,
    m.operation_start_year,
    m.operation_end_year,
    m.mission_phase,
    m.mission_outcome,
    m.mission_status,
    m.is_nato_led,
    m.has_un_mandate,
    p.troops_contributed,
    p.air_assets_contributed,
    p.naval_assets_contributed,
    p.contribution_pct,
    m.mission_cost_m_usd,
    m.public_support_pct
from participants p
inner join missions m
    on p.mission_record_id = m.mission_record_id
