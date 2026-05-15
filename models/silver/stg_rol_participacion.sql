{{ config(materialized='table') }}

-- Catálogo de roles de participación en misiones.
-- Extrae los valores únicos para eliminar la dependencia transitiva
-- de rol_participacion en stg_participacion_mision.
select distinct
    trim(participation_role)                                as rol_participacion
from {{ ref('bronze_mission_participants') }}
where participation_role is not null
