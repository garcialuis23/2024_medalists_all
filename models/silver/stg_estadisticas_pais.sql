{{ config(materialized='table') }}

select
    trim(iso_code)                                              as codigo_iso,
    to_date(trim(year) || '-01-01')                             as fecha,
    try_cast(trim(population_m) as float)                       as poblacion_millones,
    try_cast(trim(gdp_billion_usd) as float)                    as pib_bn_usd,
    try_cast(trim(gdp_per_capita_usd) as float)                 as pib_per_capita_usd,
    try_cast(trim(inflation_rate_pct) as float)                 as tasa_inflacion_pct,
    try_cast(trim(unemployment_rate_pct) as float)              as tasa_desempleo_pct,
    try_cast(trim(defense_budget_billion_usd) as float)         as presupuesto_defensa_bn_usd,
    try_cast(trim(defense_gdp_percent) as float)                as defensa_pct_pib,
    try_cast(upper(trim(meets_2_percent_target)) as boolean)    as cumple_objetivo_2pct,
    try_cast(trim(active_military_personnel) as integer)        as personal_activo,
    try_cast(trim(reserve_personnel) as integer)                as personal_reserva,
    try_cast(trim(total_military_personnel) as integer)         as personal_total,
    try_cast(trim(nato_contribution_rank) as integer)           as rango_contribucion_otan,
    try_cast(trim(interoperability_score) as float)             as score_interoperabilidad,
    try_cast(trim(training_exercises_per_year) as integer)      as ejercicios_entrenamiento_anio,
    _loaded_at                                                  as cargado_en
from {{ ref('bronze_country_stats') }}
where iso_code is not null
  and year is not null
