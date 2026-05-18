{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

-- Dimensión atletas con lugar de nacimiento desnormalizado.

select
    a.wikidata_id_atleta        as athlete_id,
    a.nombre                    as name,
    a.enlace                    as link,
    a.fecha_nacimiento          as date_of_birth,
    a.sexo                      as sex,
    p.nombre                    as birthplace,
    p.nombre_ubicado_en         as birthplace_region,
    p.latitud                   as birthplace_lat,
    p.longitud                  as birthplace_lon,
    p.id_nuts3                  as birthplace_nuts3_id

from {{ ref('silver_athlete') }} a
left join {{ ref('silver_place') }} p
    on a.wikidata_id_lugar = p.wikidata_id_lugar
