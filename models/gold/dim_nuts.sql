{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

select
    n3.id_nuts          as id_nuts3,
    n3.nombre           as nombre_nuts3,
    n3.poblacion        as poblacion_nuts3,
    n3.pib              as pib_nuts3,

    n2.id_nuts          as id_nuts2,
    n2.nombre           as nombre_nuts2,
    n2.poblacion        as poblacion_nuts2,
    n2.pib              as pib_nuts2,

    n1.id_nuts          as id_nuts1,
    n1.nombre           as nombre_nuts1,

    n0.id_nuts          as id_nuts0,
    n0.nombre           as nombre_nuts0

from {{ ref('silver_region_nuts') }} n3
left join {{ ref('silver_region_nuts') }} n2
    on n3.id_nuts_padre = n2.id_nuts
left join {{ ref('silver_region_nuts') }} n1
    on n2.id_nuts_padre = n1.id_nuts
left join {{ ref('silver_region_nuts') }} n0
    on n1.id_nuts_padre = n0.id_nuts
where n3.nivel = 3
