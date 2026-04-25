-- =============================================================================
-- 03_copy_into.sql — Comandos COPY INTO para carga Bronze desde S3
-- Proyecto: Logística Última Milla España
-- Capa: Bronze
-- =============================================================================
-- INSTRUCCIONES:
--   Sustituir ${EXTRACTION_DATE} con la fecha real en formato YYYY-MM-DD
--   antes de ejecutar. En Dagster esto se inyecta via context.partition_key.
--   Ejemplo: SET EXTRACTION_DATE = '2026-04-25';
-- =============================================================================

USE ROLE     SYSADMIN;
USE DATABASE logistics_db;
USE SCHEMA   bronze;

-- Variable de sesión para la fecha (adaptar según el orquestador)
SET EXTRACTION_DATE = '2026-04-25';


-- =============================================================================
-- 1. COPY INTO: raw_couriers
-- Dimensión — se carga el snapshot diario completo.
-- =============================================================================
COPY INTO logistics_db.bronze.raw_couriers (
    courier_id, full_name, email, phone, hire_date,
    employment_type, zone_ccaa, license_type, status,
    _extraction_date
)
FROM (
    SELECT
        $1:courier_id::VARCHAR(36),
        $1:full_name::VARCHAR(200),
        $1:email::VARCHAR(200),
        $1:phone::VARCHAR(30),
        $1:hire_date::VARCHAR(20),
        $1:employment_type::VARCHAR(20),
        $1:zone_ccaa::VARCHAR(100),
        $1:license_type::VARCHAR(20),
        $1:status::VARCHAR(20),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/couriers/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 2. COPY INTO: raw_vehicles
-- Dimensión — snapshot diario de la flota.
-- =============================================================================
COPY INTO logistics_db.bronze.raw_vehicles (
    vehicle_id, courier_id, plate_number, vehicle_type, fuel_type,
    brand, model, year, max_payload_kg, status,
    _extraction_date
)
FROM (
    SELECT
        $1:vehicle_id::VARCHAR(36),
        $1:courier_id::VARCHAR(36),
        $1:plate_number::VARCHAR(15),
        $1:vehicle_type::VARCHAR(20),
        $1:fuel_type::VARCHAR(20),
        $1:brand::VARCHAR(50),
        $1:model::VARCHAR(100),
        $1:year::VARCHAR(4),
        $1:max_payload_kg::VARCHAR(20),
        $1:status::VARCHAR(20),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/vehicles/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 3. COPY INTO: raw_depots
-- Dimensión — catálogo de almacenes (carga incremental por fecha).
-- =============================================================================
COPY INTO logistics_db.bronze.raw_depots (
    depot_id, depot_name, city, ccaa, postal_code,
    latitude, longitude, capacity_packages,
    operating_hours_start, operating_hours_end,
    _extraction_date
)
FROM (
    SELECT
        $1:depot_id::VARCHAR(36),
        $1:depot_name::VARCHAR(200),
        $1:city::VARCHAR(100),
        $1:ccaa::VARCHAR(100),
        $1:postal_code::VARCHAR(10),
        $1:latitude::VARCHAR(20),
        $1:longitude::VARCHAR(20),
        $1:capacity_packages::VARCHAR(10),
        $1:operating_hours_start::VARCHAR(8),
        $1:operating_hours_end::VARCHAR(8),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/depots/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 4. COPY INTO: raw_customers
-- Dimensión — snapshot diario de destinatarios activos.
-- =============================================================================
COPY INTO logistics_db.bronze.raw_customers (
    customer_id, customer_type, postal_code, city, ccaa,
    preferred_time_slot,
    _extraction_date
)
FROM (
    SELECT
        $1:customer_id::VARCHAR(36),
        $1:customer_type::VARCHAR(20),
        $1:postal_code::VARCHAR(10),
        $1:city::VARCHAR(100),
        $1:ccaa::VARCHAR(100),
        $1:preferred_time_slot::VARCHAR(30),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/customers/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 5. COPY INTO: raw_packages
-- =============================================================================
COPY INTO logistics_db.bronze.raw_packages (
    package_id, delivery_id, weight_kg, volume_cm3, category,
    declared_value_eur, origin_postal_code, destination_postal_code,
    _extraction_date
)
FROM (
    SELECT
        $1:package_id::VARCHAR(36),
        $1:delivery_id::VARCHAR(36),
        $1:weight_kg::VARCHAR(20),
        $1:volume_cm3::VARCHAR(20),
        $1:category::VARCHAR(20),
        $1:declared_value_eur::VARCHAR(20),
        $1:origin_postal_code::VARCHAR(10),
        $1:destination_postal_code::VARCHAR(10),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/packages/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 6. COPY INTO: raw_deliveries
-- =============================================================================
COPY INTO logistics_db.bronze.raw_deliveries (
    delivery_id, package_id, courier_id, vehicle_id, route_id,
    customer_id, depot_id, scheduled_date, scheduled_time_slot,
    actual_delivery_ts, status, failure_reason,
    delivery_cost_eur, distance_km,
    _extraction_date
)
FROM (
    SELECT
        $1:delivery_id::VARCHAR(36),
        $1:package_id::VARCHAR(36),
        $1:courier_id::VARCHAR(36),
        $1:vehicle_id::VARCHAR(36),
        $1:route_id::VARCHAR(36),
        $1:customer_id::VARCHAR(36),
        $1:depot_id::VARCHAR(36),
        $1:scheduled_date::VARCHAR(20),
        $1:scheduled_time_slot::VARCHAR(30),
        $1:actual_delivery_ts::VARCHAR(40),
        $1:status::VARCHAR(20),
        $1:failure_reason::VARCHAR(200),
        $1:delivery_cost_eur::VARCHAR(20),
        $1:distance_km::VARCHAR(20),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/deliveries/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 7. COPY INTO: raw_routes
-- =============================================================================
COPY INTO logistics_db.bronze.raw_routes (
    route_id, courier_id, vehicle_id, depot_id, route_date,
    total_stops, completed_stops, route_status,
    planned_distance_km, actual_distance_km,
    planned_duration_min, actual_duration_min,
    fuel_consumed_liters, co2_emissions_kg,
    start_ts, end_ts,
    _extraction_date
)
FROM (
    SELECT
        $1:route_id::VARCHAR(36),
        $1:courier_id::VARCHAR(36),
        $1:vehicle_id::VARCHAR(36),
        $1:depot_id::VARCHAR(36),
        $1:route_date::VARCHAR(20),
        $1:total_stops::VARCHAR(10),
        $1:completed_stops::VARCHAR(10),
        $1:route_status::VARCHAR(20),
        $1:planned_distance_km::VARCHAR(20),
        $1:actual_distance_km::VARCHAR(20),
        $1:planned_duration_min::VARCHAR(20),
        $1:actual_duration_min::VARCHAR(20),
        $1:fuel_consumed_liters::VARCHAR(20),
        $1:co2_emissions_kg::VARCHAR(20),
        $1:start_ts::VARCHAR(40),
        $1:end_ts::VARCHAR(40),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/routes/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 8. COPY INTO: raw_route_stops
-- Tabla de mayor volumen — granularidad a nivel parada.
-- =============================================================================
COPY INTO logistics_db.bronze.raw_route_stops (
    stop_id, route_id, delivery_id, stop_sequence,
    planned_arrival_ts, actual_arrival_ts,
    stop_duration_minutes, stop_status,
    latitude, longitude,
    _extraction_date
)
FROM (
    SELECT
        $1:stop_id::VARCHAR(36),
        $1:route_id::VARCHAR(36),
        $1:delivery_id::VARCHAR(36),
        $1:stop_sequence::VARCHAR(10),
        $1:planned_arrival_ts::VARCHAR(40),
        $1:actual_arrival_ts::VARCHAR(40),
        $1:stop_duration_minutes::VARCHAR(10),
        $1:stop_status::VARCHAR(20),
        $1:latitude::VARCHAR(20),
        $1:longitude::VARCHAR(20),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/route_stops/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 9. COPY INTO: raw_incidents
-- =============================================================================
COPY INTO logistics_db.bronze.raw_incidents (
    incident_id, delivery_id, route_id, courier_id, vehicle_id,
    incident_type, severity, reported_ts, resolved_ts,
    cost_eur, weather_condition_at_time,
    _extraction_date
)
FROM (
    SELECT
        $1:incident_id::VARCHAR(36),
        $1:delivery_id::VARCHAR(36),
        $1:route_id::VARCHAR(36),
        $1:courier_id::VARCHAR(36),
        $1:vehicle_id::VARCHAR(36),
        $1:incident_type::VARCHAR(30),
        $1:severity::VARCHAR(20),
        $1:reported_ts::VARCHAR(40),
        $1:resolved_ts::VARCHAR(40),
        $1:cost_eur::VARCHAR(20),
        $1:weather_condition_at_time::VARCHAR(20),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/incidents/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- 10. COPY INTO: raw_weather
-- =============================================================================
COPY INTO logistics_db.bronze.raw_weather (
    weather_id, city, ccaa, latitude, longitude,
    observation_ts, temperature_c, precipitation_mm,
    wind_speed_kmh, humidity_pct, weather_code, visibility_km,
    _extraction_date
)
FROM (
    SELECT
        $1:weather_id::VARCHAR(36),
        $1:city::VARCHAR(100),
        $1:ccaa::VARCHAR(100),
        $1:latitude::VARCHAR(20),
        $1:longitude::VARCHAR(20),
        $1:observation_ts::VARCHAR(40),
        $1:temperature_c::VARCHAR(20),
        $1:precipitation_mm::VARCHAR(20),
        $1:wind_speed_kmh::VARCHAR(20),
        $1:humidity_pct::VARCHAR(10),
        $1:weather_code::VARCHAR(10),
        $1:visibility_km::VARCHAR(20),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/weather/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;



-- =============================================================================
-- COPY INTO: raw_couriers
-- Nota: couriers es una dimensión completa — se carga el snapshot diario entero.
-- =============================================================================
COPY INTO logistics_db.bronze.raw_couriers (
    courier_id, first_name, last_name, email, phone, national_id,
    license_number, vehicle_type, vehicle_plate, zone_ccaa, zone_province,
    hire_date, is_active, salary_eur,
    _extraction_date
)
FROM (
    SELECT
        $1:courier_id::VARCHAR(36),
        $1:first_name::VARCHAR(100),
        $1:last_name::VARCHAR(200),
        $1:email::VARCHAR(200),
        $1:phone::VARCHAR(30),
        $1:national_id::VARCHAR(20),
        $1:license_number::VARCHAR(30),
        $1:vehicle_type::VARCHAR(50),
        $1:vehicle_plate::VARCHAR(15),
        $1:zone_ccaa::VARCHAR(100),
        $1:zone_province::VARCHAR(100),
        $1:hire_date::VARCHAR(20),
        $1:is_active::VARCHAR(10),
        $1:salary_eur::VARCHAR(20),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/couriers/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- COPY INTO: raw_deliveries
-- =============================================================================
COPY INTO logistics_db.bronze.raw_deliveries (
    delivery_id, courier_id, package_id,
    origin_city, destination_city,
    origin_lat, origin_lon, destination_lat, destination_lon,
    origin_ccaa, destination_ccaa,
    scheduled_date, time_window,
    actual_pickup_ts, actual_delivery_ts,
    status, failure_reason,
    weight_kg, volume_cm3, delivery_cost_eur, distance_km,
    priority, vehicle_type,
    _extraction_date
)
FROM (
    SELECT
        $1:delivery_id::VARCHAR(36),
        $1:courier_id::VARCHAR(36),
        $1:package_id::VARCHAR(36),
        $1:origin_city::VARCHAR(100),
        $1:destination_city::VARCHAR(100),
        $1:origin_lat::VARCHAR(30),
        $1:origin_lon::VARCHAR(30),
        $1:destination_lat::VARCHAR(30),
        $1:destination_lon::VARCHAR(30),
        $1:origin_ccaa::VARCHAR(100),
        $1:destination_ccaa::VARCHAR(100),
        $1:scheduled_date::VARCHAR(20),
        $1:time_window::VARCHAR(30),
        $1:actual_pickup_ts::VARCHAR(40),
        $1:actual_delivery_ts::VARCHAR(40),
        $1:status::VARCHAR(50),
        $1:failure_reason::VARCHAR(200),
        $1:weight_kg::VARCHAR(20),
        $1:volume_cm3::VARCHAR(20),
        $1:delivery_cost_eur::VARCHAR(20),
        $1:distance_km::VARCHAR(20),
        $1:priority::VARCHAR(30),
        $1:vehicle_type::VARCHAR(50),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/deliveries/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- COPY INTO: raw_routes
-- =============================================================================
COPY INTO logistics_db.bronze.raw_routes (
    route_id, courier_id, route_date, origin_city, total_stops,
    planned_distance_km, actual_distance_km,
    planned_duration_min, actual_duration_min,
    fuel_consumption_liters, co2_emissions_kg,
    start_ts, end_ts,
    _extraction_date
)
FROM (
    SELECT
        $1:route_id::VARCHAR(36),
        $1:courier_id::VARCHAR(36),
        $1:route_date::VARCHAR(20),
        $1:origin_city::VARCHAR(100),
        $1:total_stops::VARCHAR(10),
        $1:planned_distance_km::VARCHAR(20),
        $1:actual_distance_km::VARCHAR(20),
        $1:planned_duration_min::VARCHAR(20),
        $1:actual_duration_min::VARCHAR(20),
        $1:fuel_consumption_liters::VARCHAR(20),
        $1:co2_emissions_kg::VARCHAR(20),
        $1:start_ts::VARCHAR(40),
        $1:end_ts::VARCHAR(40),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/routes/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- COPY INTO: raw_incidents
-- =============================================================================
COPY INTO logistics_db.bronze.raw_incidents (
    incident_id, delivery_id, courier_id,
    incident_ts, incident_type, description, severity,
    resolution_ts, resolution_notes,
    cost_impact_eur, is_weather_related,
    _extraction_date
)
FROM (
    SELECT
        $1:incident_id::VARCHAR(36),
        $1:delivery_id::VARCHAR(36),
        $1:courier_id::VARCHAR(36),
        $1:incident_ts::VARCHAR(40),
        $1:incident_type::VARCHAR(100),
        $1:description::VARCHAR(2000),
        $1:severity::VARCHAR(20),
        $1:resolution_ts::VARCHAR(40),
        $1:resolution_notes::VARCHAR(2000),
        $1:cost_impact_eur::VARCHAR(20),
        $1:is_weather_related::VARCHAR(10),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/incidents/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- COPY INTO: raw_weather
-- =============================================================================
COPY INTO logistics_db.bronze.raw_weather (
    city, lat, lon, ccaa, province,
    forecast_ts,
    temperature_2m_celsius, precipitation_mm,
    wind_speed_10m_kmh, wind_gusts_10m_kmh,
    cloud_cover_pct, visibility_m, weather_code,
    _extraction_date
)
FROM (
    SELECT
        $1:city::VARCHAR(100),
        $1:lat::VARCHAR(20),
        $1:lon::VARCHAR(20),
        $1:ccaa::VARCHAR(100),
        $1:province::VARCHAR(100),
        $1:forecast_ts::VARCHAR(40),
        $1:temperature_2m_celsius::VARCHAR(20),
        $1:precipitation_mm::VARCHAR(20),
        $1:wind_speed_10m_kmh::VARCHAR(20),
        $1:wind_gusts_10m_kmh::VARCHAR(20),
        $1:cloud_cover_pct::VARCHAR(20),
        $1:visibility_m::VARCHAR(20),
        $1:weather_code::VARCHAR(10),
        $EXTRACTION_DATE::DATE
    FROM @logistics_db.bronze.s3_raw_stage/weather/extraction_date=$EXTRACTION_DATE/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE;


-- =============================================================================
-- Verificar resultados de la última carga
-- =============================================================================
SELECT
    table_name,
    row_count,
    last_altered
FROM   information_schema.tables
WHERE  table_schema = 'BRONZE'
ORDER BY table_name;

-- Auditoría de errores en la carga
SELECT *
FROM   TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME    => 'RAW_DELIVERIES',
    START_TIME    => DATEADD('hour', -2, CURRENT_TIMESTAMP())
))
ORDER BY last_load_time DESC;
