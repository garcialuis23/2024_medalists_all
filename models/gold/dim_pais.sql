{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

select
    c.wikidata_id_pais                                          as id_pais,
    c.nombre                                                    as nombre,
    c.codigo_iso2                                               as codigo_iso2,
    c.codigo_iso3                                               as codigo_iso3,
    c.codigo_coi                                                as codigo_coi,
    c.es_pais_conocido                                          as es_pais_conocido,
    count(m.id_medalla)                                         as total_medallas,
    count(case when m.tipo = 'gold'   then 1 end)               as medallas_oro,
    count(case when m.tipo = 'silver' then 1 end)               as medallas_plata,
    count(case when m.tipo = 'bronze' then 1 end)               as medallas_bronce

from {{ ref('silver_pais') }} c
left join {{ ref('silver_medalla') }} m
    on c.wikidata_id_pais = m.wikidata_id_pais

group by 1, 2, 3, 4, 5, 6
