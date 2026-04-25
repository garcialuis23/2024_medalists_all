-- =============================================================================
-- 02_landing_tables_ddl.sql — DDL de Tablas de Aterrizaje Bronze
-- Proyecto: Logística Última Milla España
-- Capa: Bronze
-- Principio: TODAS las columnas de negocio son VARCHAR.
--            Los metadatos de auditoría son los ÚNICOS campos tipados.
-- Tablas (10):
--   Dimensiones : raw_couriers, raw_vehicles, raw_depots, raw_customers
--   Hechos      : raw_packages, raw_deliveries, raw_routes, raw_route_stops
--   Eventos     : raw_incidents
--   Referencia  : raw_weather
-- =============================================================================

USE ROLE     SYSADMIN;
USE DATABASE logistics_db;
USE SCHEMA   bronze;


-- =============================================================================
-- 1. RAW_COURIERS — Dimensión de conductores
-- Fuente: s3://logistics-raw-zone/couriers/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_couriers (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    courier_id        VARCHAR(36),
    full_name         VARCHAR(200),
    email             VARCHAR(200),
    phone             VARCHAR(30),
    hire_date         VARCHAR(20),
    employment_type   VARCHAR(20),   -- autónomo / plantilla
    zone_ccaa         VARCHAR(100),
    license_type      VARCHAR(20),
    status            VARCHAR(20),   -- activo / baja / vacaciones

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Conductores. Dimensión de la flota humana.'
DATA_RETENTION_TIME_IN_DAYS = 30;


-- =============================================================================
-- 2. RAW_VEHICLES — Flota de vehículos
-- Fuente: s3://logistics-raw-zone/vehicles/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_vehicles (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    vehicle_id       VARCHAR(36),
    courier_id       VARCHAR(36),
    plate_number     VARCHAR(15),
    vehicle_type     VARCHAR(20),   -- moto / furgoneta / bici-cargo / cargocycle
    fuel_type        VARCHAR(20),   -- gasolina / diésel / eléctrico
    brand            VARCHAR(50),
    model            VARCHAR(100),
    year             VARCHAR(4),
    max_payload_kg   VARCHAR(20),
    status           VARCHAR(20),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Flota de vehículos. Clave para análisis de costes, consumo e incidencias.'
DATA_RETENTION_TIME_IN_DAYS = 30;


-- =============================================================================
-- 3. RAW_DEPOTS — Centros de distribución / almacenes
-- Fuente: s3://logistics-raw-zone/depots/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_depots (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    depot_id                VARCHAR(36),
    depot_name              VARCHAR(200),
    city                    VARCHAR(100),
    ccaa                    VARCHAR(100),
    postal_code             VARCHAR(10),
    latitude                VARCHAR(20),
    longitude               VARCHAR(20),
    capacity_packages       VARCHAR(10),
    operating_hours_start   VARCHAR(8),   -- HH:MM
    operating_hours_end     VARCHAR(8),   -- HH:MM

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Centros de distribución. Base para análisis geoespacial y de capacidad.'
DATA_RETENTION_TIME_IN_DAYS = 30;


-- =============================================================================
-- 4. RAW_CUSTOMERS — Destinatarios
-- Fuente: s3://logistics-raw-zone/customers/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_customers (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    customer_id           VARCHAR(36),
    customer_type         VARCHAR(20),   -- particular / empresa
    postal_code           VARCHAR(10),
    city                  VARCHAR(100),
    ccaa                  VARCHAR(100),
    preferred_time_slot   VARCHAR(30),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Destinatarios. Base para RLS por zona y análisis de entrega fallida por tipo de cliente.'
DATA_RETENTION_TIME_IN_DAYS = 30;


-- =============================================================================
-- 5. RAW_PACKAGES — Objeto físico a entregar
-- Fuente: s3://logistics-raw-zone/packages/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_packages (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    package_id                VARCHAR(36),
    delivery_id               VARCHAR(36),
    weight_kg                 VARCHAR(20),
    volume_cm3                VARCHAR(20),
    category                  VARCHAR(20),   -- estándar / frágil / cadena_frío
    declared_value_eur        VARCHAR(20),
    origin_postal_code        VARCHAR(10),
    destination_postal_code   VARCHAR(10),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Paquetes físicos. Permite análisis de coste por peso/volumen y categorías especiales.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- 6. RAW_DELIVERIES — Hechos de entregas (tabla central)
-- Fuente: s3://logistics-raw-zone/deliveries/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_deliveries (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    delivery_id           VARCHAR(36),
    package_id            VARCHAR(36),
    courier_id            VARCHAR(36),
    vehicle_id            VARCHAR(36),
    route_id              VARCHAR(36),
    customer_id           VARCHAR(36),
    depot_id              VARCHAR(36),
    scheduled_date        VARCHAR(20),
    scheduled_time_slot   VARCHAR(30),
    actual_delivery_ts    VARCHAR(40),
    status                VARCHAR(20),   -- entregado / fallido / devuelto / en_tránsito
    failure_reason        VARCHAR(200),
    delivery_cost_eur     VARCHAR(20),
    distance_km           VARCHAR(20),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Entregas diarias. Tabla de hechos central del modelo.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- 7. RAW_ROUTES — Rutas operativas (conductor + vehículo + almacén + día)
-- Fuente: s3://logistics-raw-zone/routes/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_routes (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    route_id               VARCHAR(36),
    courier_id             VARCHAR(36),
    vehicle_id             VARCHAR(36),
    depot_id               VARCHAR(36),
    route_date             VARCHAR(20),
    total_stops            VARCHAR(10),
    completed_stops        VARCHAR(10),
    route_status           VARCHAR(20),
    planned_distance_km    VARCHAR(20),
    actual_distance_km     VARCHAR(20),
    planned_duration_min   VARCHAR(20),
    actual_duration_min    VARCHAR(20),
    fuel_consumed_liters   VARCHAR(20),
    co2_emissions_kg       VARCHAR(20),
    start_ts               VARCHAR(40),
    end_ts                 VARCHAR(40),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Rutas operativas. Une conductor + vehículo + almacén + día.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- 8. RAW_ROUTE_STOPS — Paradas individuales dentro de una ruta
-- Fuente: s3://logistics-raw-zone/route_stops/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_route_stops (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    stop_id                VARCHAR(36),
    route_id               VARCHAR(36),
    delivery_id            VARCHAR(36),
    stop_sequence          VARCHAR(10),
    planned_arrival_ts     VARCHAR(40),
    actual_arrival_ts      VARCHAR(40),
    stop_duration_minutes  VARCHAR(10),
    stop_status            VARCHAR(20),
    latitude               VARCHAR(20),
    longitude              VARCHAR(20),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Paradas individuales por ruta. Granularidad máxima para análisis de tiempo por parada y cuellos de botella.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- 9. RAW_INCIDENTS — Incidencias de la operativa
-- Fuente: s3://logistics-raw-zone/incidents/extraction_date=*/
-- Nota: weather_condition_at_time almacena el código WMO en Bronze.
--       En Silver se cruza con raw_weather por ciudad + timestamp.
-- =============================================================================
CREATE OR REPLACE TABLE raw_incidents (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    incident_id               VARCHAR(36),
    delivery_id               VARCHAR(36),
    route_id                  VARCHAR(36),
    courier_id                VARCHAR(36),
    vehicle_id                VARCHAR(36),
    incident_type             VARCHAR(30),   -- accidente / avería / robo / cliente_ausente / paquete_dañado
    severity                  VARCHAR(20),
    reported_ts               VARCHAR(40),
    resolved_ts               VARCHAR(40),
    cost_eur                  VARCHAR(20),
    weather_condition_at_time VARCHAR(20),   -- código WMO Open-Meteo

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Incidencias operativas. weather_condition_at_time (WMO) se enriquece en Silver cruzando con raw_weather.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- 10. RAW_WEATHER — Observaciones meteorológicas Open-Meteo
-- Fuente: s3://logistics-raw-zone/weather/extraction_date=*/
-- =============================================================================
CREATE OR REPLACE TABLE raw_weather (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    weather_id        VARCHAR(36),
    city              VARCHAR(100),
    ccaa              VARCHAR(100),
    latitude          VARCHAR(20),
    longitude         VARCHAR(20),
    observation_ts    VARCHAR(40),
    temperature_c     VARCHAR(20),
    precipitation_mm  VARCHAR(20),
    wind_speed_kmh    VARCHAR(20),
    humidity_pct      VARCHAR(10),
    weather_code      VARCHAR(10),   -- código WMO
    visibility_km     VARCHAR(20),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Meteorología Open-Meteo por hora y ciudad.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- Verificación: listar tablas creadas
-- =============================================================================
SHOW TABLES IN SCHEMA logistics_db.bronze;
