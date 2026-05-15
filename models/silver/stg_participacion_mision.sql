{{ config(materialized='table') }}

select
    trim(participant_id)                                        as id_participante,
    trim(mission_record_id)                                     as id_mision,
    trim(iso_code)                                              as codigo_iso,
    trim(participation_role)                                    as rol_participacion,
    try_cast(trim(troops_contributed) as integer)               as tropas_contribuidas,
    try_cast(trim(air_assets_contributed) as integer)           as activos_aereos_contribuidos,
    try_cast(trim(naval_assets_contributed) as integer)         as activos_navales_contribuidos,
    _loaded_at                                                  as cargado_en
from {{ ref('bronze_mission_participants') }}
where participant_id is not null
qualify row_number() over (
    partition by trim(mission_record_id), trim(iso_code)
    order by _loaded_at desc
) = 1
