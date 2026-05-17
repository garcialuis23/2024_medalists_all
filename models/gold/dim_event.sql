{{ config(materialized='table') }}

-- Dimensión eventos con disciplina y deporte flattened en una sola fila.

select
    e.event_id,
    e.name          as event_name,
    e.link          as event_link,
    d.discipline_id,
    d.name          as discipline_name,
    s.sport_id,
    s.name          as sport_name

from {{ ref('silver_event') }} e
left join {{ ref('silver_discipline') }} d
    on e.discipline_id = d.discipline_id
left join {{ ref('silver_sport') }} s
    on d.sport_id = s.sport_id
