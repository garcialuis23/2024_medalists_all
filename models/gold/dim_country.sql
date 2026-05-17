{{ config(materialized='table') }}

-- Dimensión países con recuento de medallas por tipo.

select
    c.country_id,
    c.name,
    c.code2,
    c.code3,
    c.ioc_code,
    count(m.medal_id)                               as total_medals,
    count(case when m.type = 'gold'   then 1 end)   as gold_medals,
    count(case when m.type = 'silver' then 1 end)   as silver_medals,
    count(case when m.type = 'bronze' then 1 end)   as bronze_medals

from {{ ref('silver_country') }} c
left join {{ ref('silver_medal') }} m
    on c.country_id = m.country_id

group by 1, 2, 3, 4, 5
