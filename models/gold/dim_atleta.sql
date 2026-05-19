{{ config(materialized='table', database=("GOLD_DB_PRO" if target.name == "pro" else "GOLD_DB_DEV")) }}

select
    a.wikidata_id_atleta        as id_atleta,
    a.nombre                    as nombre,
    a.enlace                    as enlace,
    a.fecha_nacimiento          as fecha_nacimiento,
    a.sexo                      as sexo,
    p.nombre                    as lugar_nacimiento,
    p.nombre_ubicado_en         as region_nacimiento,
    p.latitud                   as lat_nacimiento,
    p.longitud                  as lon_nacimiento,
    p.id_nuts3                  as id_nuts3_nacimiento

from {{ ref('silver_atleta') }} a
left join {{ ref('silver_lugar') }} p
    on a.wikidata_id_lugar = p.wikidata_id_lugar
