{{ config(materialized='table') }}

select
    trim(participant_id)                                as participant_id,
    trim(mission_record_id)                             as mission_record_id,
    trim(mission_name)                                  as mission_name,
    trim(country)                                       as country,
    trim(iso_code)                                      as iso_code,
    trim(participation_role)                            as participation_role,
    trim(troops_contributed)                            as troops_contributed,
    trim(air_assets_contributed)                        as air_assets_contributed,
    trim(naval_assets_contributed)                      as naval_assets_contributed,
    trim(contribution_pct)                              as contribution_pct,
    _source_file,
    _loaded_at
from {{ source('bronze_raw', 'nato_mission_participants') }}
