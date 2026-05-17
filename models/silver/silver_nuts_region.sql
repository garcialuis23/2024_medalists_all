{{ config(materialized='table') }}

-- Tabla auto-jerárquica: nivel 0 (país) → 1 (NUTS1) → 2 (NUTS2) → 3 (NUTS3).
-- Solo atletas europeos tienen datos NUTS; el resto tiene NULL en estos campos.

-- Nivel 0: país
select
    nuts0_id                    as nuts_id,
    0                           as level,
    nuts0_name                  as name,
    null                        as parent_nuts_id,
    null::double                as population,
    null::double                as gdp
from {{ ref('bronze_medalists_raw') }}
where nuts0_id is not null
group by 1, 2, 3, 4

union all

-- Nivel 1: región NUTS1
select
    nuts1_id,
    1,
    nuts1_name,
    nuts0_id,
    null::double,
    null::double
from {{ ref('bronze_medalists_raw') }}
where nuts1_id is not null
group by 1, 2, 3, 4

union all

-- Nivel 2: subregión NUTS2 (con población y PIB)
select
    nuts2_id,
    2,
    nuts2_name,
    nuts1_id,
    max(nuts2_population),
    max(nuts2_gdp)
from {{ ref('bronze_medalists_raw') }}
where nuts2_id is not null
group by 1, 2, 3, 4

union all

-- Nivel 3: subsubregión NUTS3 (con población y PIB)
select
    nuts3_id,
    3,
    nuts3_name,
    nuts2_id,
    max(nuts3_population),
    max(nuts3_gdp)
from {{ ref('bronze_medalists_raw') }}
where nuts3_id is not null
group by 1, 2, 3, 4
