{{ config(materialized='table') }}

-- Tabla de hechos Gold: cada medalla con todas las dimensiones resueltas.
-- Lista para consumo analítico directo (BI, dashboards, etc.).

select
    m.medal_id,
    m.type                          as medal_type,

    -- atleta
    a.athlete_id,
    a.name                          as athlete_name,
    a.date_of_birth,
    a.sex,
    a.birthplace,
    a.birthplace_region,
    a.birthplace_lat,
    a.birthplace_lon,

    -- país acreedor
    c.country_id,
    c.name                          as country_name,
    c.code2                         as country_code2,
    c.code3                         as country_code3,
    c.ioc_code                      as country_ioc_code,

    -- delegación
    d.delegation_id,
    d.name                          as delegation_name,

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
    n.nuts0_name                    as nuts_country_name

from {{ ref('silver_medal') }} m
join {{ ref('dim_athlete') }}     a  on m.athlete_id    = a.athlete_id
join {{ ref('silver_country') }}  c  on m.country_id    = c.country_id
join {{ ref('silver_delegation') }} d on m.delegation_id = d.delegation_id
join {{ ref('dim_event') }}       e  on m.event_id      = e.event_id
left join {{ ref('dim_nuts') }}   n  on a.birthplace_nuts3_id = n.nuts3_id
