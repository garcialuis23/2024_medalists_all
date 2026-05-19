{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

select
    m.id_medalla                        as id_medalla,
    m.tipo                              as tipo_medalla,

    -- atleta
    a.id_atleta,
    a.nombre                            as nombre_atleta,
    a.fecha_nacimiento,

    -- país acreedor (join a dim Gold, no a Silver directamente)
    p.id_pais,

    -- delegación (ID ya disponible en silver_medalla, sin saltar a capa Silver)
    m.wikidata_id_delegacion            as id_delegacion,

    -- evento / disciplina / deporte
    e.id_evento,
    e.nombre_evento,
    e.nombre_disciplina,
    e.nombre_deporte,

    -- NUTS (solo atletas europeos; NULL para el resto)
    n.id_nuts3,
    n.id_nuts2,
    n.id_nuts1,
    n.id_nuts0,

from {{ ref('silver_medalla') }}  m
join      {{ ref('dim_atleta') }} a on m.wikidata_id_atleta  = a.id_atleta
join      {{ ref('dim_pais') }}   p on m.wikidata_id_pais    = p.id_pais
join      {{ ref('dim_evento') }} e on m.wikidata_id_evento  = e.id_evento
left join {{ ref('dim_nuts') }}   n on a.id_nuts3_nacimiento = n.id_nuts3
