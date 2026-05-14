{{ config(materialized='table') }}

with source as (
    select * from {{ ref('bronze_mission_participants') }}
)

select
    participant_id,
    mission_record_id,
    mission_name,
    country,
    iso_code,
    participation_role,
    try_cast(troops_contributed as integer)                 as troops_contributed,
    try_cast(air_assets_contributed as integer)             as air_assets_contributed,
    try_cast(naval_assets_contributed as integer)           as naval_assets_contributed,
    try_cast(contribution_pct as float)                     as contribution_pct,
    _source_file,
    _loaded_at
from source
