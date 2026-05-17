{{ config(materialized='table') }}

-- Jerarquía NUTS completa desnormalizada: una fila por región NUTS3.
-- Útil para análisis geoespacial de atletas europeos.

select
    n3.nuts_id          as nuts3_id,
    n3.name             as nuts3_name,
    n3.population       as nuts3_population,
    n3.gdp              as nuts3_gdp,

    n2.nuts_id          as nuts2_id,
    n2.name             as nuts2_name,
    n2.population       as nuts2_population,
    n2.gdp              as nuts2_gdp,

    n1.nuts_id          as nuts1_id,
    n1.name             as nuts1_name,

    n0.nuts_id          as nuts0_id,
    n0.name             as nuts0_name

from {{ ref('silver_nuts_region') }} n3
left join {{ ref('silver_nuts_region') }} n2
    on n3.parent_nuts_id = n2.nuts_id
left join {{ ref('silver_nuts_region') }} n1
    on n2.parent_nuts_id = n1.nuts_id
left join {{ ref('silver_nuts_region') }} n0
    on n1.parent_nuts_id = n0.nuts_id
where n3.level = 3
