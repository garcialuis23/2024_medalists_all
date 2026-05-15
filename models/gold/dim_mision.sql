{{ config(materialized='table') }}

select
    id_mision,
    nombre_mision,
    tipo_mision,
    codigo_iso_lider,
    ubicacion_operacion,
    region_operacion,
    nivel_amenaza,
    cuartel_general,
    clasificacion,
    cobertura_mediatica,
    paises_contribuyentes,
    fecha_inicio_operacion,
    fecha_fin_operacion,
    year(fecha_inicio_operacion)                                as anio_inicio,
    year(fecha_fin_operacion)                                   as anio_fin,
    es_liderada_otan,
    tiene_mandato_onu
from {{ ref('stg_mision') }}
where id_mision is not null
