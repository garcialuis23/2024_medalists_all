# Arquitectura Conceptual — Pipeline Logística Última Milla España

## Diagrama de Flujo End-to-End

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INGESTA (Python 3.11 / Docker)                      │
│                                                                             │
│   ┌─────────────┐     ┌──────────────────┐     ┌───────────────────────┐   │
│   │   Faker     │     │  Open-Meteo API  │     │   ingest.py           │   │
│   │  (es_ES)    │────▶│  (httpx + retry) │────▶│  PyArrow → Parquet   │   │
│   │  Sintético  │     │  10 ciudades ES  │     │  boto3 → S3          │   │
│   └─────────────┘     └──────────────────┘     └───────────────────────┘   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Parquet (Snappy)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS S3 — Raw Zone                                   │
│                                                                             │
│   s3://logistics-raw-zone/                                                  │
│   ├── couriers/extraction_date=YYYY-MM-DD/couriers.parquet                 │
│   ├── deliveries/extraction_date=YYYY-MM-DD/deliveries.parquet             │
│   ├── routes/extraction_date=YYYY-MM-DD/routes.parquet                     │
│   ├── incidents/extraction_date=YYYY-MM-DD/incidents.parquet               │
│   └── weather/extraction_date=YYYY-MM-DD/weather.parquet                   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ External Stage + COPY INTO
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              SNOWFLAKE — logistics_db                                        │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  BRONZE (sin transformaciones — todo VARCHAR + metadatos auditoría)  │   │
│  │  raw_couriers │ raw_deliveries │ raw_routes │ raw_incidents │ raw_weather│
│  └───────────────────────────────┬─────────────────────────────────────┘   │
│                                  │ dbt (incremental models)                │
│                                  ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SILVER (casteo estricto, dedup, surrogate keys, tests de calidad)   │   │
│  │  stg_couriers │ stg_deliveries │ stg_routes │ stg_incidents │ stg_weather│
│  └───────────────────────────────┬─────────────────────────────────────┘   │
│                                  │ dbt (dimensional model Kimball)         │
│                                  ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GOLD — Modelo Estrella Kimball                                       │   │
│  │                                                                       │   │
│  │  fact_deliveries ◀── dim_courier (SCD-2 via Snapshot)               │   │
│  │  fact_incidents  ◀── dim_vehicle                                     │   │
│  │                  ◀── dim_location                                    │   │
│  │                  ◀── dim_date                                        │   │
│  └───────────────────────────────┬─────────────────────────────────────┘   │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ DirectQuery / Import
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       POWER BI                                               │
│                                                                             │
│   Dashboard Costes Operativos    │   RLS por CCAA (Jefes de Zona)          │
│   5 Medidas DAX Avanzadas        │   Modelo Estrella importado              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Orquestación — Dagster (Software-Defined Assets)

```
DAGSTER ASSET GRAPH — Particiones Diarias
═══════════════════════════════════════════════════════════════

  [raw_logistics_data]        ← Trigger: Schedule diario 02:00 UTC
         │                      compute_kind: python
         │                      Ejecuta contenedor Docker de ingesta
         │                      metadata: n_files, bytes_uploaded, partition_date
         │
         ├──▶ [bronze_couriers]
         ├──▶ [bronze_deliveries]       ← COPY INTO desde External Stage
         ├──▶ [bronze_routes]             partición filtrada por extraction_date
         ├──▶ [bronze_incidents]          metadata: rows_loaded, load_errors
         └──▶ [bronze_weather]
                    │
                    └──▶ [silver_dbt_assets]    ← dagster-dbt integration
                                │                  Ejecuta stg_* modelos
                                │                  metadata: dbt_run_id, models_run
                                │
                                └──▶ [gold_dbt_assets]    ← fact_* + dim_*
                                                            Ejecuta snapshots SCD-2
```

## Capas de Datos — Contratos

### Bronze (Aterrizaje)
- **Principio**: datos crudos, sin transformaciones, confianza cero.
- **Tipos**: todas las columnas de negocio son `VARCHAR`.
- **Metadatos obligatorios**: `_loaded_at`, `_file_name`, `_file_row_number`, `_extraction_date`.
- **Retención**: 90 días tablas transaccionales, 30 días dimensiones.

### Silver (Confianza)
- **Principio**: datos limpios, tipados, deduplicados, con tests.
- **Deduplicación**: `ROW_NUMBER() OVER (PARTITION BY {id} ORDER BY _loaded_at DESC) = 1`.
- **Claves surrogate**: `dbt_utils.generate_surrogate_key(['{id}'])` → SHA-256.
- **Materialización**: `incremental` para hechos, `table` para dimensiones.

### Gold (Consumo)
- **Principio**: modelo Kimball estrella, optimizado para BI.
- **SCD-2**: `dim_courier` via dbt Snapshots — rastrea cambios en `vehicle_type`, `zone_ccaa`.
- **Grano**:
  - `fact_deliveries`: 1 fila = 1 entrega.
  - `fact_incidents`: 1 fila = 1 incidencia.

## Seguridad

| Componente | Mecanismo |
|-----------|-----------|
| S3 → Snowflake | Storage Integration (IAM Role, sin Access Keys) |
| Python → S3 | IAM Role en ECS Task (no credenciales en código) |
| Dagster → Snowflake | `SnowflakeResource` via variables de entorno |
| Dagster → dbt | `DbtCliResource` con profiles.yml desde env vars |
| Power BI → Snowflake | Service Principal con certificado |
| Power BI RLS | Filtro `[zone_ccaa]` sobre `dim_courier` |

## Particionado S3

```
Estrategia de particionado: por extraction_date (Hive-style)

s3://logistics-raw-zone/
├── couriers/
│   └── extraction_date=2026-04-25/
│       └── couriers.parquet          ← ~200 filas, ~50KB
├── deliveries/
│   └── extraction_date=2026-04-25/
│       └── deliveries.parquet        ← ~5.000 filas, ~2MB
├── routes/
│   └── extraction_date=2026-04-25/
│       └── routes.parquet            ← ~1.500 filas, ~600KB
├── incidents/
│   └── extraction_date=2026-04-25/
│       └── incidents.parquet         ← ~600 filas, ~250KB
└── weather/
    └── extraction_date=2026-04-25/
        └── weather.parquet           ← ~240 filas (10 ciudades × 24h), ~100KB
```

## Stack de Versiones

| Tecnología | Versión |
|-----------|---------|
| Python | 3.11 |
| Faker | 20.x |
| PyArrow | 14.x |
| boto3 | 1.34.x |
| httpx | 0.25.x |
| tenacity | 8.x |
| Dagster | 1.6.x |
| dagster-dbt | 0.22.x |
| dagster-snowflake | 0.22.x |
| dbt Core | 1.7.x |
| dbt-snowflake | 1.7.x |
| dbt-utils | 1.1.x |
