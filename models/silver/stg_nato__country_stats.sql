{{ config(materialized='table') }}

with fuente as (
    select * from {{ ref('bronze_country_stats') }}
)

select
    record_id,
    country                                                         as pais,
    iso_code                                                        as codigo_iso,
    try_cast(join_year as integer)                                  as anio_ingreso_otan,
    try_cast(years_in_nato as integer)                              as anos_en_otan,
    try_cast(founding_member as boolean)                            as es_miembro_fundador,
    try_cast(nuclear_sharing as boolean)                            as tiene_comparticion_nuclear,
    region                                                          as region,
    capital                                                         as capital,
    try_cast(area_km2 as integer)                                   as area_km2,
    government_type                                                 as tipo_gobierno,
    alliance_role                                                   as rol_alianza,
    try_cast(year as integer)                                       as anio,
    try_cast(population_m as float)                                 as poblacion_millones,
    try_cast(gdp_billion_usd as float)                              as pib_bn_usd,
    try_cast(gdp_per_capita_usd as float)                           as pib_per_capita_usd,
    try_cast(inflation_rate_pct as float)                           as tasa_inflacion_pct,
    try_cast(unemployment_rate_pct as float)                        as tasa_desempleo_pct,
    try_cast(defense_budget_billion_usd as float)                   as presupuesto_defensa_bn_usd,
    try_cast(defense_gdp_percent as float)                          as defensa_pct_pib,
    try_cast(meets_2_percent_target as boolean)                     as cumple_objetivo_2pct,
    try_cast(active_military_personnel as integer)                  as personal_militar_activo,
    try_cast(reserve_personnel as integer)                          as personal_reserva,
    try_cast(total_military_personnel as integer)                   as personal_militar_total,
    try_cast(nato_contribution_rank as integer)                     as rango_contribucion_otan,
    try_cast(interoperability_score as float)                       as score_interoperabilidad,
    try_cast(training_exercises_per_year as integer)                as ejercicios_entrenamiento_anio,
    _source_file                                                    as archivo_fuente,
    _loaded_at                                                      as cargado_en
from fuente
