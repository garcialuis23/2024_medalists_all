{{ config(materialized='table') }}

-- Tabla auto-jerárquica: nivel 0 (país) → 1 (NUTS1) → 2 (NUTS2) → 3 (NUTS3).
-- Solo atletas europeos tienen datos NUTS; el resto tiene NULL en estos campos.

-- Nivel 0: país
select
    nullif(nuts0_id, 'NA')     as id_nuts,
    0::integer                 as nivel,
    nullif(nuts0_name, 'NA')   as nombre,
    null::varchar              as id_nuts_padre,
    null::float                as poblacion,
    null::float                as pib
from {{ ref('bronze_medalists_raw') }}
where nullif(nuts0_id, 'NA') is not null
group by 1, 2, 3, 4

union all

-- Nivel 1: región NUTS1
select
    nullif(nuts1_id, 'NA'),
    1::integer,
    nullif(nuts1_name, 'NA'),
    nullif(nuts0_id, 'NA'),
    null::float,
    null::float
from {{ ref('bronze_medalists_raw') }}
where nullif(nuts1_id, 'NA') is not null
group by 1, 2, 3, 4

union all

-- Nivel 2: subregión NUTS2 (con población y PIB)
select
    nullif(nuts2_id, 'NA'),
    2::integer,
    nullif(nuts2_name, 'NA'),
    nullif(nuts1_id, 'NA'),
    max(try_to_double(nullif(nuts2_population, 'NA'))),
    max(try_to_double(nullif(nuts2_gdp, 'NA')))
from {{ ref('bronze_medalists_raw') }}
where nullif(nuts2_id, 'NA') is not null
group by 1, 2, 3, 4

union all

-- Nivel 3: subsubregión NUTS3 (con población y PIB)
select
    nullif(nuts3_id, 'NA'),
    3::integer,
    nullif(nuts3_name, 'NA'),
    nullif(nuts2_id, 'NA'),
    max(try_to_double(nullif(nuts3_population, 'NA'))),
    max(try_to_double(nullif(nuts3_gdp, 'NA')))
from {{ ref('bronze_medalists_raw') }}
where nullif(nuts3_id, 'NA') is not null
group by 1, 2, 3, 4
