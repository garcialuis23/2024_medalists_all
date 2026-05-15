{{ config(materialized='table') }}

with origen_equipo as (
    select distinct trim(country_of_origin) as pais_origen
    from {{ ref('bronze_equipment_inventory') }}
    where country_of_origin is not null
),

paises_otan as (
    select distinct trim(iso_code) as pais_origen
    from {{ ref('bronze_country_stats') }}
    where iso_code is not null
)

select pais_origen
from origen_equipo
union
select pais_origen
from paises_otan
