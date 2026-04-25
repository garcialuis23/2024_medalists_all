-- =============================================================================
-- 02_landing_tables_ddl.sql — DDL de Tablas de Aterrizaje Bronze
-- Proyecto: Logística Última Milla España
-- Capa: Bronze
-- Principio: TODAS las columnas de negocio son VARCHAR.
--            Los metadatos de auditoría son los ÚNICOS campos tipados.
-- =============================================================================

USE ROLE    SYSADMIN;
USE DATABASE logistics_db;
USE SCHEMA   bronze;


-- =============================================================================
-- Tabla: RAW_COURIERS — Dimensión de mensajeros
-- Fuente: s3://bucket/couriers/extraction_date=*/couriers.parquet
-- =============================================================================
CREATE OR REPLACE TABLE raw_couriers (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    courier_id        VARCHAR(36),
    first_name        VARCHAR(100),
    last_name         VARCHAR(200),
    email             VARCHAR(200),
    phone             VARCHAR(30),
    national_id       VARCHAR(20),
    license_number    VARCHAR(30),
    vehicle_type      VARCHAR(50),
    vehicle_plate     VARCHAR(15),
    zone_ccaa         VARCHAR(100),
    zone_province     VARCHAR(100),
    hire_date         VARCHAR(20),
    is_active         VARCHAR(10),
    salary_eur        VARCHAR(20),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name        VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number  INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date  DATE          NOT NULL

)
COMMENT             = 'Bronze — Mensajeros. Datos crudos sin transformación.'
DATA_RETENTION_TIME_IN_DAYS = 30;


-- =============================================================================
-- Tabla: RAW_DELIVERIES — Hechos de entregas
-- Fuente: s3://bucket/deliveries/extraction_date=*/deliveries.parquet
-- =============================================================================
CREATE OR REPLACE TABLE raw_deliveries (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    delivery_id           VARCHAR(36),
    courier_id            VARCHAR(36),
    package_id            VARCHAR(36),
    origin_city           VARCHAR(100),
    destination_city      VARCHAR(100),
    origin_lat            VARCHAR(30),
    origin_lon            VARCHAR(30),
    destination_lat       VARCHAR(30),
    destination_lon       VARCHAR(30),
    origin_ccaa           VARCHAR(100),
    destination_ccaa      VARCHAR(100),
    scheduled_date        VARCHAR(20),
    time_window           VARCHAR(30),
    actual_pickup_ts      VARCHAR(40),
    actual_delivery_ts    VARCHAR(40),
    status                VARCHAR(50),
    failure_reason        VARCHAR(200),
    weight_kg             VARCHAR(20),
    volume_cm3            VARCHAR(20),
    delivery_cost_eur     VARCHAR(20),
    distance_km           VARCHAR(20),
    priority              VARCHAR(30),
    vehicle_type          VARCHAR(50),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at            TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name            VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number      INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date      DATE          NOT NULL

)
COMMENT             = 'Bronze — Entregas diarias. Datos crudos sin transformación.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- Tabla: RAW_ROUTES — Rutas operativas de la flota
-- Fuente: s3://bucket/routes/extraction_date=*/routes.parquet
-- =============================================================================
CREATE OR REPLACE TABLE raw_routes (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    route_id                  VARCHAR(36),
    courier_id                VARCHAR(36),
    route_date                VARCHAR(20),
    origin_city               VARCHAR(100),
    total_stops               VARCHAR(10),
    planned_distance_km       VARCHAR(20),
    actual_distance_km        VARCHAR(20),
    planned_duration_min      VARCHAR(20),
    actual_duration_min       VARCHAR(20),
    fuel_consumption_liters   VARCHAR(20),
    co2_emissions_kg          VARCHAR(20),
    start_ts                  VARCHAR(40),
    end_ts                    VARCHAR(40),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at                TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name                VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number          INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date          DATE          NOT NULL

)
COMMENT             = 'Bronze — Rutas operativas de la flota. Datos crudos sin transformación.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- Tabla: RAW_INCIDENTS — Incidencias de la operativa
-- Fuente: s3://bucket/incidents/extraction_date=*/incidents.parquet
-- =============================================================================
CREATE OR REPLACE TABLE raw_incidents (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    incident_id          VARCHAR(36),
    delivery_id          VARCHAR(36),
    courier_id           VARCHAR(36),
    incident_ts          VARCHAR(40),
    incident_type        VARCHAR(100),
    description          VARCHAR(2000),
    severity             VARCHAR(20),
    resolution_ts        VARCHAR(40),
    resolution_notes     VARCHAR(2000),
    cost_impact_eur      VARCHAR(20),
    is_weather_related   VARCHAR(10),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at           TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name           VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number     INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date     DATE          NOT NULL

)
COMMENT             = 'Bronze — Incidencias operativas. Datos crudos sin transformación.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- Tabla: RAW_WEATHER — Datos meteorológicos Open-Meteo
-- Fuente: s3://bucket/weather/extraction_date=*/weather.parquet
-- =============================================================================
CREATE OR REPLACE TABLE raw_weather (

    -- ── Columnas de negocio (VARCHAR — sin casteo) ────────────────────────
    city                    VARCHAR(100),
    lat                     VARCHAR(20),
    lon                     VARCHAR(20),
    ccaa                    VARCHAR(100),
    province                VARCHAR(100),
    forecast_ts             VARCHAR(40),
    temperature_2m_celsius  VARCHAR(20),
    precipitation_mm        VARCHAR(20),
    wind_speed_10m_kmh      VARCHAR(20),
    wind_gusts_10m_kmh      VARCHAR(20),
    cloud_cover_pct         VARCHAR(20),
    visibility_m            VARCHAR(20),
    weather_code            VARCHAR(10),

    -- ── Metadatos de auditoría OBLIGATORIOS ──────────────────────────────
    _loaded_at              TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    _file_name              VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
    _file_row_number        INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
    _extraction_date        DATE          NOT NULL

)
COMMENT             = 'Bronze — Meteorología Open-Meteo por hora y ciudad. Datos crudos sin transformación.'
DATA_RETENTION_TIME_IN_DAYS = 90;


-- =============================================================================
-- Verificación: listar tablas creadas
-- =============================================================================
SHOW TABLES IN SCHEMA logistics_db.bronze;
