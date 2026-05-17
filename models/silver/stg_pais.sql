{{ config(materialized='table') }}

with source as (
    select
        trim(iso_code)                                          as codigo_iso,
        try_cast(trim(year) as integer)                         as anio_fuente,
        trim(country)                                           as pais,
        trim(region)                                            as region,
        trim(capital)                                           as capital,
        try_cast(trim(area_km2) as integer)                     as area_km2,
        trim(government_type)                                   as tipo_gobierno,
        trim(alliance_role)                                     as rol_alianza,
        try_cast(trim(join_year) as integer)                    as anio_ingreso_otan,
        case upper(trim(founding_member))
            when 'YES' then true  when 'Y' then true
            when 'NO'  then false when 'N' then false
            else null
        end                                                     as es_miembro_fundador,
        try_cast(upper(trim(nuclear_sharing)) as boolean)       as tiene_comparticion_nuclear,
        _loaded_at
    from {{ ref('bronze_country_stats') }}
    where iso_code is not null
        and year is not null
),

-- Hash over all mutable attributes to detect real mutations (not just reloads)
with_hash as (
    select *,
        md5(
            coalesce(pais,           '') || '|' ||
            coalesce(region,         '') || '|' ||
            coalesce(capital,        '') || '|' ||
            coalesce(cast(area_km2 as varchar), '') || '|' ||
            coalesce(tipo_gobierno,  '') || '|' ||
            coalesce(rol_alianza,    '')
        )                                                       as hash_diff
    from source
),

with_lag as (
    select *,
        lag(hash_diff) over (
            partition by codigo_iso
            order by anio_fuente
        )                                                       as prev_hash
    from with_hash
),

version_starts as (
    select *,
        case
            when prev_hash is null or hash_diff <> prev_hash then 1
            else 0
        end                                                     as es_inicio_version
    from with_lag
),

grouped as (
    select *,
        sum(es_inicio_version) over (
            partition by codigo_iso
            order by anio_fuente
            rows between unbounded preceding and current row
        )                                                       as version_grupo
    from version_starts
),

versiones as (
    select
        codigo_iso,
        pais,
        region,
        capital,
        area_km2,
        tipo_gobierno,
        rol_alianza,
        anio_ingreso_otan,
        es_miembro_fundador,
        tiene_comparticion_nuclear,
        hash_diff,
        version_grupo,
        min(anio_fuente)                                        as valid_from_anio,
        max(anio_fuente)                                        as valid_to_anio,
        max(anio_fuente) over (partition by codigo_iso)         as ultimo_anio
    from grouped
    group by
        codigo_iso, pais, region, capital, area_km2,
        tipo_gobierno, rol_alianza, anio_ingreso_otan,
        es_miembro_fundador, tiene_comparticion_nuclear,
        hash_diff, version_grupo
)

select
    row_number() over (
        order by codigo_iso, fecha_inicio_validez
    )                                                       as pais_sk,
    codigo_iso,
    pais,
    region,
    capital,
    area_km2,
    tipo_gobierno,
    rol_alianza,
    anio_ingreso_otan,
    case
        when anio_ingreso_otan is not null
        then to_date(anio_ingreso_otan || '-01-01')
        else null
    end                                                     as fecha_ingreso_otan,
    es_miembro_fundador,
    tiene_comparticion_nuclear,
    hash_diff,
    to_date(valid_from_anio || '-01-01')                        as fecha_inicio_validez,
    case
        when valid_to_anio = ultimo_anio then '9999-12-31'::date
        else to_date(valid_to_anio || '-12-31')
    end                                                         as fecha_fin_validez,
    (valid_to_anio = ultimo_anio)                               as es_registro_actual,
    current_timestamp()                                         as cargado_en
from versiones
