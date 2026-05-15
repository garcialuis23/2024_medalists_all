{% snapshot snap_pais %}

{{
    config(
        target_schema='snapshots',
        unique_key='codigo_iso',
        strategy='check',
        check_cols=['pais', 'region', 'capital', 'area_km2', 'tipo_gobierno', 'rol_alianza',
                    'es_miembro_fundador', 'tiene_comparticion_nuclear']
    )
}}

select
    trim(iso_code)                                          as codigo_iso,
    trim(country)                                           as pais,
    trim(region)                                            as region,
    trim(capital)                                           as capital,
    try_cast(trim(area_km2) as integer)                     as area_km2,
    trim(government_type)                                   as tipo_gobierno,
    trim(alliance_role)                                     as rol_alianza,
    try_cast(trim(join_year) as integer)                    as anio_ingreso_otan,
    try_cast(upper(trim(founding_member)) as boolean)       as es_miembro_fundador,
    try_cast(upper(trim(nuclear_sharing)) as boolean)       as tiene_comparticion_nuclear
from {{ ref('bronze_country_stats') }}
where iso_code is not null
qualify row_number() over (
    partition by trim(iso_code)
    order by _loaded_at desc
) = 1

{% endsnapshot %}
