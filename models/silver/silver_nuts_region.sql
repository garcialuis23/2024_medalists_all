{{ config(materialized='table') }}

-- Tabla auto-jerárquica: nivel 0 (país) → 1 (NUTS1) → 2 (NUTS2) → 3 (NUTS3).
-- Solo atletas europeos tienen datos NUTS; el resto tiene NULL en estos campos.

-- Nivel 0: país
select
    cast(nuts0_id   as varchar)     as id_nuts,
    cast(0          as integer)     as nivel,
    cast(nuts0_name as varchar)     as nombre,
    null::varchar                   as id_nuts_padre,
    null::float                     as poblacion,
    null::float                     as pib
from {{ ref('bronze_medalists_raw') }}
where nuts0_id is not null
group by 1, 2, 3, 4

union all

-- Nivel 1: región NUTS1
select
    cast(nuts1_id   as varchar),
    cast(1          as integer),
    cast(nuts1_name as varchar),
    cast(nuts0_id   as varchar),
    null::float,
    null::float
from {{ ref('bronze_medalists_raw') }}
where nuts1_id is not null
group by 1, 2, 3, 4

union all

-- Nivel 2: subregión NUTS2 (con población y PIB)
select
    cast(nuts2_id   as varchar),
    cast(2          as integer),
    cast(nuts2_name as varchar),
    cast(nuts1_id   as varchar),
    max(cast(nuts2_population as float)),
    max(cast(nuts2_gdp        as float))
from {{ ref('bronze_medalists_raw') }}
where nuts2_id is not null
group by 1, 2, 3, 4

union all

-- Nivel 3: subsubregión NUTS3 (con población y PIB)
select
    cast(nuts3_id   as varchar),
    cast(3          as integer),
    cast(nuts3_name as varchar),
    cast(nuts2_id   as varchar),
    max(cast(nuts3_population as float)),
    max(cast(nuts3_gdp        as float))
from {{ ref('bronze_medalists_raw') }}
where nuts3_id is not null
group by 1, 2, 3, 4

