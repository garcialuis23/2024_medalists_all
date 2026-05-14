{{ config(materialized='table') }}

select distinct
    fase_mision,
    estado_mision,
    resultado_mision,
    es_liderada_otan,
    tiene_mandato_onu,
    informe_post_accion,
    case
        when estado_mision = 'Completed' then 'Finalizada'
        when estado_mision = 'Active'    then 'Activa'
        when estado_mision = 'Planned'   then 'Planificada'
        when estado_mision = 'Suspended' then 'Suspendida'
        else estado_mision
    end                                                             as estado_mision_es,
    case
        when resultado_mision = 'Success'        then 'Éxito'
        when resultado_mision = 'Partial Success' then 'Éxito Parcial'
        when resultado_mision = 'Failure'        then 'Fracaso'
        when resultado_mision = 'Ongoing'        then 'En Curso'
        else resultado_mision
    end                                                             as resultado_mision_es
from {{ ref('stg_nato__operations_missions') }}
where fase_mision is not null
