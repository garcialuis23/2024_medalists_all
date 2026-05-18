{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

-- Dimensión países con recuento de medallas por tipo.

select
    c.wikidata_id_pais                                          as country_id,
    c.nombre                                                    as name,
    c.codigo_iso2                                               as code2,
    c.codigo_iso3                                               as code3,
    c.codigo_coi                                                as ioc_code,
    c.es_pais_conocido                                          as is_known_country,
    count(m.id_medalla)                                         as total_medals,
    count(case when m.tipo = 'gold'   then 1 end)               as gold_medals,
    count(case when m.tipo = 'silver' then 1 end)               as silver_medals,
    count(case when m.tipo = 'bronze' then 1 end)               as bronze_medals

from {{ ref('silver_country') }} c
left join {{ ref('silver_medal') }} m
    on c.wikidata_id_pais = m.wikidata_id_pais

group by 1, 2, 3, 4, 5, 6
