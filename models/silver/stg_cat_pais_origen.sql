{{ config(materialized='table') }}

/*
  Fuente: country_of_origin de CSV2 (nombres de país, no códigos ISO).
  Normalizaciones aplicadas:
    · "UK"            → "GBR"  (alias no-ISO muy frecuente en fuente)
    · "Multi-National"→ "MNA"  (consorcio multinacional, código convencional)
  Resto de valores se conservan tal cual hasta que el ETL añada un lookup completo.
  fecha_inicio_estado / fecha_fin_estado: NULL en Silver (no hay fuente).
  El cruce con fecha_adquisicion del inventario para detectar equipamiento de
  estados extintos se implementa como test dbt en Gold, no como FK constraint.
*/

select distinct
    case upper(trim(country_of_origin))
        when 'MULTI-NATIONAL' then 'MNA'
        when 'UK'             then 'GBR'
        else trim(country_of_origin)
    end                                                     as codigo_iso_origen,
    trim(country_of_origin)                                 as pais_origen,
    null::date                                              as fecha_inicio_estado,
    null::date                                              as fecha_fin_estado,
    null::varchar                                           as descripcion,
    current_timestamp()                                     as cargado_en
from {{ ref('bronze_equipment_inventory') }}
where country_of_origin is not null
  and trim(country_of_origin) != ''
