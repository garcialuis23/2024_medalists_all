-- =============================================================================
-- 01_external_stage.sql — Configuración del External Stage S3 en Snowflake
-- Proyecto: Logística Última Milla España
-- Capa: Bronze
-- =============================================================================
-- INSTRUCCIONES DE EJECUCIÓN:
--   1. Sustituir ${AWS_ACCOUNT_ID} y ${S3_BUCKET} con los valores reales.
--   2. Ejecutar el PASO 1 con rol ACCOUNTADMIN (una sola vez por cuenta).
--   3. Anotar STORAGE_AWS_IAM_USER_ARN y STORAGE_AWS_EXTERNAL_ID del DESC.
--   4. Configurar el trust policy en la IAM Role de AWS con esos valores.
--   5. Ejecutar pasos 2-5 con un rol con privilegios suficientes (SYSADMIN).
-- =============================================================================


-- =============================================================================
-- PASO 1: Crear Storage Integration (solo ACCOUNTADMIN — ejecutar UNA VEZ)
-- =============================================================================
USE ROLE ACCOUNTADMIN;

CREATE STORAGE INTEGRATION IF NOT EXISTS s3_logistics_integration
    TYPE                      = EXTERNAL_STAGE
    STORAGE_PROVIDER          = 'S3'
    ENABLED                   = TRUE
    STORAGE_AWS_ROLE_ARN      = 'arn:aws:iam::${AWS_ACCOUNT_ID}:role/snowflake-logistics-s3-role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://${S3_BUCKET}/')
    COMMENT                   = 'Integración S3 para el pipeline de logística última milla';

-- Obtener los valores para configurar el trust policy en AWS IAM:
--   STORAGE_AWS_IAM_USER_ARN  → Principal en el trust policy
--   STORAGE_AWS_EXTERNAL_ID   → Condition ExternalId en el trust policy
DESC INTEGRATION s3_logistics_integration;

-- Conceder uso de la integración al rol de trabajo
GRANT USAGE ON INTEGRATION s3_logistics_integration TO ROLE SYSADMIN;


-- =============================================================================
-- PASO 2: Crear base de datos y esquemas
-- =============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS logistics_db
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Base de datos del proyecto de logística de última milla en España';

CREATE SCHEMA IF NOT EXISTS logistics_db.bronze
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Capa de aterrizaje de datos crudos desde S3. Sin transformaciones.';

CREATE SCHEMA IF NOT EXISTS logistics_db.silver
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Datos limpios, tipados y deduplicados. Gestionado por dbt.';

CREATE SCHEMA IF NOT EXISTS logistics_db.gold
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Modelo dimensional Kimball para consumo analítico. Gestionado por dbt.';


-- =============================================================================
-- PASO 3: Crear File Format Parquet con Snappy
-- =============================================================================
USE SCHEMA logistics_db.bronze;

CREATE FILE FORMAT IF NOT EXISTS logistics_db.bronze.parquet_logistics_ff
    TYPE                = PARQUET
    SNAPPY_COMPRESSION  = TRUE
    BINARY_AS_TEXT      = FALSE
    COMMENT             = 'Formato Parquet Snappy para datasets de logística generados por PyArrow';


-- =============================================================================
-- PASO 4: Crear External Stage apuntando a S3
-- =============================================================================
CREATE STAGE IF NOT EXISTS logistics_db.bronze.s3_raw_stage
    URL                 = 's3://${S3_BUCKET}/'
    STORAGE_INTEGRATION = s3_logistics_integration
    FILE_FORMAT         = logistics_db.bronze.parquet_logistics_ff
    COMMENT             = 'Stage externo S3 — Raw Zone del pipeline de logística última milla';


-- =============================================================================
-- PASO 5: Verificar el Stage
-- =============================================================================

-- Listar todos los archivos en el stage
LIST @logistics_db.bronze.s3_raw_stage;

-- Verificar una partición concreta de entregas
LIST @logistics_db.bronze.s3_raw_stage/deliveries/;

-- Inspeccionar estructura de un Parquet (inferir schema)
SELECT *
FROM TABLE(
    INFER_SCHEMA(
        LOCATION     => '@logistics_db.bronze.s3_raw_stage/deliveries/extraction_date=2026-04-25/',
        FILE_FORMAT  => 'logistics_db.bronze.parquet_logistics_ff'
    )
);
