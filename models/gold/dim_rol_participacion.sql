{{ config(materialized='table') }}

select distinct
    rol_participacion,
    case
        when lower(rol_participacion) like '%lead%'        then 'Liderazgo'
        when lower(rol_participacion) like '%support%'     then 'Apoyo'
        when lower(rol_participacion) like '%observer%'    then 'Observador'
        when lower(rol_participacion) like '%logistics%'   then 'Logística'
        when lower(rol_participacion) like '%intel%'       then 'Inteligencia'
        when lower(rol_participacion) like '%air%'         then 'Componente Aéreo'
        when lower(rol_participacion) like '%naval%'       then 'Componente Naval'
        else 'Otro'
    end                                                             as categoria_rol,
    case
        when lower(rol_participacion) like '%lead%' then 1 else 0
    end                                                             as es_rol_liderazgo
from {{ ref('stg_nato__mission_participants') }}
where rol_participacion is not null
