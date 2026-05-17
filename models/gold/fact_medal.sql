{{ config(materialized='table', database=generate_database_name('GOLD_DB')) }}

-- Tabla de hechos Gold: cada medalla con todas las dimensiones resueltas.
-- Lista para consumo analítico directo (BI, dashboards, etc.).

select
    m.id_medalla                        as medal_id,
    m.tipo                              as medal_type,

    -- atleta
    a.athlete_id,
    a.name                              as athlete_name,
    a.date_of_birth,
    a.sex,
    a.birthplace,
    a.birthplace_region,
    a.birthplace_lat,
    a.birthplace_lon,

    -- país acreedor
    c.wikidata_id_pais                  as country_id,
    c.nombre                            as country_name,
    c.codigo_iso2                       as country_code2,
    c.codigo_iso3                       as country_code3,
    c.codigo_coi                        as country_ioc_code,

    -- delegación
    d.wikidata_id_delegacion            as delegation_id,
    d.nombre                            as delegation_name,

    -- evento / disciplina / deporte
    e.event_id,
    e.event_name,
    e.discipline_name,
    e.sport_name,

    -- NUTS (solo atletas europeos; NULL para el resto)
    n.nuts3_id,
    n.nuts3_name,
    n.nuts2_id,
    n.nuts2_name,
    n.nuts1_id,
    n.nuts1_name,
    n.nuts0_id,
    n.nuts0_name                        as nuts_country_name

from {{ ref('silver_medal') }} m
join {{ ref('dim_athlete') }}     a  on m.wikidata_id_atleta     = a.athlete_id
join {{ ref('silver_country') }}  c  on m.wikidata_id_pais        = c.wikidata_id_pais
join {{ ref('silver_delegation') }} d on m.wikidata_id_delegacion = d.wikidata_id_delegacion
join {{ ref('dim_event') }}       e  on m.wikidata_id_evento      = e.event_id
left join {{ ref('dim_nuts') }}   n  on a.birthplace_nuts3_id     = n.nuts3_id
