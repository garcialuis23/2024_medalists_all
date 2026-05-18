{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

-- Jerarquía NUTS completa desnormalizada: una fila por región NUTS3.
-- Útil para análisis geoespacial de atletas europeos.

select
    n3.id_nuts          as nuts3_id,
    n3.nombre           as nuts3_name,
    n3.poblacion        as nuts3_population,
    n3.pib              as nuts3_gdp,

    n2.id_nuts          as nuts2_id,
    n2.nombre           as nuts2_name,
    n2.poblacion        as nuts2_population,
    n2.pib              as nuts2_gdp,

    n1.id_nuts          as nuts1_id,
    n1.nombre           as nuts1_name,

    n0.id_nuts          as nuts0_id,
    n0.nombre           as nuts0_name

from {{ ref('silver_nuts_region') }} n3
left join {{ ref('silver_nuts_region') }} n2
    on n3.id_nuts_padre = n2.id_nuts
left join {{ ref('silver_nuts_region') }} n1
    on n2.id_nuts_padre = n1.id_nuts
left join {{ ref('silver_nuts_region') }} n0
    on n1.id_nuts_padre = n0.id_nuts
where n3.nivel = 3
