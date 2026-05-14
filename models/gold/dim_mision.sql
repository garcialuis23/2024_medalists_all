{{ config(materialized='table') }}

select distinct
    record_id                                                       as id_mision,
    nombre_mision,
    tipo_mision,
    pais_lider,
    codigo_iso_lider,
    region_pais_lider,
    ubicacion_operacion,
    region_operacion,
    nivel_amenaza,
    cuartel_general,
    clasificacion,
    cobertura_mediatica,
    paises_contribuyentes,
    duracion_anos,
    anio_inicio_operacion,
    anio_fin_operacion
from {{ ref('stg_nato__operations_missions') }}
where record_id is not null
