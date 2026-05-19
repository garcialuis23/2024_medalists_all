{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

select
    e.wikidata_id_evento        as id_evento,
    e.nombre                    as nombre_evento,
    e.enlace                    as enlace_evento,
    d.wikidata_id_disciplina    as id_disciplina,
    d.nombre                    as nombre_disciplina,
    s.wikidata_id_deporte       as id_deporte,
    s.nombre                    as nombre_deporte

from {{ ref('silver_evento') }} e
left join {{ ref('silver_disciplina') }} d
    on e.wikidata_id_disciplina = d.wikidata_id_disciplina
left join {{ ref('silver_deporte') }} s
    on d.wikidata_id_deporte = s.wikidata_id_deporte
