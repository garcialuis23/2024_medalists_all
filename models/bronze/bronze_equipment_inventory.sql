{{ config(materialized='table') }}

/*
  Bronze layer — NATO_EQUIPMENT_INVENTORY
  Source  : BRONZE_DB.PUBLIC.NATO_EQUIPMENT_INVENTORY
  Strategy: Raw pass-through. All columns kept as VARCHAR.
            Only TRIM applied to string fields to remove leading/trailing whitespace.
            No business logic. No type casting.
*/

SELECT
    -- Identifiers
    TRIM(record_id)                 AS record_id,

    -- Country attributes
    TRIM(country)                   AS country,
    TRIM(iso_code)                  AS iso_code,
    TRIM(join_year)                 AS join_year,
    TRIM(founding_member)           AS founding_member,
    TRIM(nuclear_sharing)           AS nuclear_sharing,
    TRIM(region)                    AS region,
    TRIM(capital)                   AS capital,

    -- Equipment classification
    TRIM(equipment_type)            AS equipment_type,
    TRIM(equipment_category)        AS equipment_category,
    TRIM(domain)                    AS domain,
    TRIM(notable_models)            AS notable_models,

    -- Inventory & status
    TRIM(units_count)               AS units_count,
    UPPER(TRIM(operational_status)) AS operational_status,
    TRIM(condition)                 AS condition,
    TRIM(year_acquired)             AS year_acquired,
    TRIM(equipment_age_years)       AS equipment_age_years,

    -- Financial
    TRIM(unit_cost_m_usd)           AS unit_cost_m_usd,
    TRIM(total_value_m_usd)         AS total_value_m_usd,

    -- Origin & interoperability
    TRIM(country_of_origin)         AS country_of_origin,
    UPPER(TRIM(nato_standardized))  AS nato_standardized,
    UPPER(TRIM(interoperable))      AS interoperable,

    -- Maintenance & readiness
    TRIM(last_maintenance_year)     AS last_maintenance_year,
    TRIM(next_upgrade_due)          AS next_upgrade_due,
    TRIM(combat_ready_pct)          AS combat_ready_pct,

    -- Metadata
    _source_file,
    _loaded_at

FROM {{ source('bronze_raw', 'nato_equipment_inventory') }}
