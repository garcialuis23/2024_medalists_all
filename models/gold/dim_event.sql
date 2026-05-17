{{ config(materialized='table') }}

-- Dimensión eventos con disciplina y deporte flattened en una sola fila.

select
    e.wikidata_id_evento        as event_id,
    e.nombre                    as event_name,
    e.enlace                    as event_link,
    d.wikidata_id_disciplina    as discipline_id,
    d.nombre                    as discipline_name,
    s.wikidata_id_deporte       as sport_id,
    s.nombre                    as sport_name

from {{ ref('silver_event') }} e
left join {{ ref('silver_discipline') }} d
    on e.wikidata_id_disciplina = d.wikidata_id_disciplina
left join {{ ref('silver_sport') }} s
    on d.wikidata_id_deporte = s.wikidata_id_deporte
