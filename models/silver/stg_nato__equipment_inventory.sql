{{ config(materialized='table') }}

with fuente as (
    select * from {{ ref('bronze_equipment_inventory') }}
)

select
    record_id,
    country                                                         as pais,
    iso_code                                                        as codigo_iso,
    try_cast(join_year as integer)                                  as anio_ingreso_otan,
    try_cast(founding_member as boolean)                            as es_miembro_fundador,
    try_cast(nuclear_sharing as boolean)                            as tiene_comparticion_nuclear,
    region                                                          as region,
    capital                                                         as capital,
    equipment_type                                                  as tipo_equipamiento,
    equipment_category                                              as categoria_equipamiento,
    domain                                                          as dominio,
    notable_models                                                  as modelos_destacados,
    try_cast(units_count as integer)                                as cantidad_unidades,
    operational_status                                              as estado_operacional,
    condition                                                       as condicion,
    try_cast(year_acquired as integer)                              as anio_adquisicion,
    try_cast(equipment_age_years as integer)                        as antiguedad_anos,
    try_cast(unit_cost_m_usd as float)                              as coste_unitario_m_usd,
    try_cast(total_value_m_usd as float)                            as valor_total_m_usd,
    country_of_origin                                               as pais_origen,
    try_cast(nato_standardized as boolean)                          as es_estandar_otan,
    try_cast(interoperable as boolean)                              as es_interoperable,
    try_cast(last_maintenance_year as integer)                      as anio_ultimo_mantenimiento,
    try_cast(next_upgrade_due as integer)                           as anio_proximo_upgrade,
    try_cast(combat_ready_pct as float)                             as pct_combat_ready,
    _source_file                                                    as archivo_fuente,
    _loaded_at                                                      as cargado_en
from fuente
