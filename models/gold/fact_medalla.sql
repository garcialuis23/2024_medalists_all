{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

select
    m.id_medalla                        as id_medalla,
    m.tipo                              as tipo_medalla,

    -- atleta
    a.id_atleta,
    a.nombre                            as nombre_atleta,
    a.fecha_nacimiento,
    a.sexo,
    a.lugar_nacimiento,
    a.region_nacimiento,
    a.lat_nacimiento,
    a.lon_nacimiento,

    -- país acreedor
    c.wikidata_id_pais                  as id_pais,
    c.nombre                            as nombre_pais,
    c.codigo_iso2                       as codigo_iso2_pais,
    c.codigo_iso3                       as codigo_iso3_pais,
    c.codigo_coi                        as codigo_coi_pais,

    -- delegación
    d.wikidata_id_delegacion            as id_delegacion,
    d.nombre                            as nombre_delegacion,

    -- evento / disciplina / deporte
    e.id_evento,
    e.nombre_evento,
    e.nombre_disciplina,
    e.nombre_deporte,

    -- NUTS (solo atletas europeos; NULL para el resto)
    n.id_nuts3,
    n.nombre_nuts3,
    n.id_nuts2,
    n.nombre_nuts2,
    n.id_nuts1,
    n.nombre_nuts1,
    n.id_nuts0,
    n.nombre_nuts0                      as nombre_pais_nuts

from {{ ref('silver_medalla') }} m
join {{ ref('dim_atleta') }}        a on m.wikidata_id_atleta     = a.id_atleta
join {{ ref('silver_pais') }}       c on m.wikidata_id_pais       = c.wikidata_id_pais
join {{ ref('silver_delegacion') }} d on m.wikidata_id_delegacion = d.wikidata_id_delegacion
join {{ ref('dim_evento') }}        e on m.wikidata_id_evento      = e.id_evento
left join {{ ref('dim_nuts') }}     n on a.id_nuts3_nacimiento     = n.id_nuts3
