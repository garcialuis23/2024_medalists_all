{{ config(materialized='table') }}

with fuente as (
    select * from {{ ref('bronze_mission_participants') }}
)

select
    participant_id                                                  as id_participante,
    mission_record_id                                               as id_mision,
    mission_name                                                    as nombre_mision,
    country                                                         as pais,
    iso_code                                                        as codigo_iso,
    participation_role                                              as rol_participacion,
    try_cast(troops_contributed as integer)                         as tropas_contribuidas,
    try_cast(air_assets_contributed as integer)                     as activos_aereos_contribuidos,
    try_cast(naval_assets_contributed as integer)                   as activos_navales_contribuidos,
    try_cast(contribution_pct as float)                             as pct_contribucion,
    _source_file                                                    as archivo_fuente,
    _loaded_at                                                      as cargado_en
from fuente
