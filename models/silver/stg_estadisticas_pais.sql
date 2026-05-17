{{ config(materialized='table') }}

/*
  Serie temporal por (país, año). Sin SCD-2: un registro por año es el modelo natural.
  pais_sk: FK a la versión de stg_pais válida para el año del registro.
  Campos calculados (pib_per_capita_usd, defensa_pct_pib, cumple_objetivo_2pct,
  personal_total) REMOVIDOS → se recalculan en Gold sobre datos atómicos de Silver.
  codigo_iso conservado desnormalizado (patrón dual key).
*/

with stats as (
    select
        trim(iso_code)                                          as codigo_iso,
        to_date(trim(year) || '-01-01')                         as fecha,
        try_cast(trim(population_m) as float)                   as poblacion_millones,
        try_cast(trim(gdp_billion_usd) as float)                as pib_bn_usd,
        try_cast(trim(inflation_rate_pct) as float)             as tasa_inflacion_pct,
        try_cast(trim(unemployment_rate_pct) as float)          as tasa_desempleo_pct,
        try_cast(trim(defense_budget_billion_usd) as float)     as presupuesto_defensa_bn_usd,
        try_cast(trim(active_military_personnel) as integer)    as personal_activo,
        try_cast(trim(reserve_personnel) as integer)            as personal_reserva,
        try_cast(trim(nato_contribution_rank) as integer)       as rango_contribucion_otan,
        try_cast(trim(interoperability_score) as float)         as score_interoperabilidad,
        try_cast(trim(training_exercises_per_year) as integer)  as ejercicios_entrenamiento_anio,
        _loaded_at                                              as cargado_en
    from {{ ref('bronze_country_stats') }}
    where iso_code is not null
      and year is not null
)

select
    p.pais_sk,
    s.codigo_iso,
    s.fecha,
    s.poblacion_millones,
    s.pib_bn_usd,
    s.tasa_inflacion_pct,
    s.tasa_desempleo_pct,
    s.presupuesto_defensa_bn_usd,
    s.personal_activo,
    s.personal_reserva,
    s.rango_contribucion_otan,
    s.score_interoperabilidad,
    s.ejercicios_entrenamiento_anio,
    s.cargado_en
from stats s
left join {{ ref('stg_pais') }} p
    on  p.codigo_iso = s.codigo_iso
    and s.fecha between p.fecha_inicio_validez and p.fecha_fin_validez
