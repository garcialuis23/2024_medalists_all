# Arquitectura Técnica — NATO Alliance Data Pipeline

## Diagrama de Flujo End-to-End

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INGESTA (Python 3.11 / Docker)                      │
│                                                                             │
│   ┌────────────────────────────────────────────────────────────────────┐    │
│   │  ingest.py                                                          │    │
│   │  Lee 4 CSV del repositorio Bronze                                   │    │
│   │  → valida existencia y tamaño mínimo                                │    │
│   │  → convierte cada CSV a Parquet (PyArrow, Snappy)                   │    │
│   │  → sube a S3 particionado por ingestion_date (Hive-style)           │    │
│   └────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Parquet (Snappy)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS S3 — Raw Zone                                   │
│                                                                             │
│   s3://nato-raw-zone/                                                       │
│   ├── country_stats/ingestion_date=YYYY-MM-DD/country_stats.parquet        │
│   ├── equipment_inventory/ingestion_date=YYYY-MM-DD/equipment.parquet      │
│   ├── missions/ingestion_date=YYYY-MM-DD/missions.parquet                  │
│   └── mission_participants/ingestion_date=YYYY-MM-DD/participants.parquet  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ External Stage + COPY INTO
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SNOWFLAKE — nato_db                                  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  BRONZE  (sin transformaciones — todo VARCHAR + metadatos auditoría) │  │
│  │                                                                       │  │
│  │  raw_country_stats        raw_equipment_inventory                    │  │
│  │  raw_missions             raw_mission_participants                   │  │
│  └──────────────────────────────┬───────────────────────────────────────┘  │
│                                 │ dbt (staging + limpieza)                 │
│                                 ▼                                           │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  SILVER  (casteo estricto, dedup, normalización, surrogate keys)     │  │
│  │                                                                       │  │
│  │  DIMENSIONES (6)                  HECHOS (3)                         │  │
│  │  ├── dim_country (SCD-2)          ├── fact_country_stats             │  │
│  │  ├── dim_region                   ├── fact_equipment_inventory       │  │
│  │  ├── dim_equipment_type           └── fact_missions                  │  │
│  │  ├── dim_mission_type                                                 │  │
│  │  ├── dim_command_hq               PUENTES (2)                        │  │
│  │  └── dim_year                     ├── bridge_mission_participants    │  │
│  │                                   └── bridge_equipment_models        │  │
│  └──────────────────────────────┬───────────────────────────────────────┘  │
│                                 │ dbt (Gold — capa de consumo)             │
│                                 ▼                                           │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  GOLD  (agregados y métricas precalculadas para Power BI)            │  │
│  │                                                                       │  │
│  │  agg_defense_spending_trend     agg_mission_outcomes                 │  │
│  │  agg_equipment_readiness        agg_nato_expansion                   │  │
│  └──────────────────────────────┬───────────────────────────────────────┘  │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ Import Mode
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              POWER BI                                        │
│                                                                             │
│   Dashboard Gasto en Defensa     │   Dashboard Operaciones NATO            │
│   Dashboard Inventario Militar   │   RLS por Region / Alliance_Role        │
│   5+ Medidas DAX Avanzadas       │   Modelo importado desde Gold           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Orquestación — Dagster (Software-Defined Assets)

```
DAGSTER ASSET GRAPH — Particiones por Fecha de Ingesta
═══════════════════════════════════════════════════════════════════════════

  [raw_nato_data]                ← Trigger: Schedule diario 02:00 UTC
       │                           compute_kind: python
       │                           Lee CSVs → Parquet → S3
       │                           metadata: n_files, bytes_uploaded, ingestion_date
       │
       ├──▶ [bronze_country_stats]
       ├──▶ [bronze_equipment_inventory]   ← COPY INTO desde External Stage
       ├──▶ [bronze_missions]                partición filtrada por ingestion_date
       └──▶ [bronze_mission_participants]    metadata: rows_loaded, load_errors
                    │
                    └──▶ [nato_dbt_assets]   ← dagster-dbt (Silver + Gold)
                                               Ejecuta todos los modelos dbt
                                               metadata: dbt_run_id, models_run
```

---

## Capas de Datos — Contratos

### Bronze (Aterrizaje)
- **Principio**: datos crudos sin transformaciones. Confianza cero. Espejos exactos del Parquet.
- **Tipos**: todas las columnas de negocio son `VARCHAR`. Sin casteos.
- **Metadatos obligatorios** en todas las tablas:
  ```sql
  _loaded_at       TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  _file_name       VARCHAR(500)  NOT NULL DEFAULT METADATA$FILENAME,
  _file_row_number INTEGER       NOT NULL DEFAULT METADATA$FILE_ROW_NUMBER,
  _ingestion_date  DATE          NOT NULL   -- inyectado por COPY INTO
  ```
- **Retención**: 90 días tablas transaccionales, 30 días dimensiones.

### Silver (Confianza)
- **Principio**: datos tipados, limpios, deduplicados, normalizados, con tests.
- **Deduplicación**: `ROW_NUMBER() OVER (PARTITION BY {natural_key} ORDER BY _loaded_at DESC) = 1`
- **Limpieza obligatoria**:
  - Nulos: unificar `""`, `"NULL"`, `"N/A"`, `"-"` → `NULL`
  - Booleanos: normalizar `Yes/YES/yes/Y/True/1` → `TRUE` / `FALSE`
  - Strings: `TRIM()` en todos los campos de texto
  - Nombres de país: lookup via `ISO_Code` como clave canónica
  - Campos calculados: recomputar `Duration_Years`, `Equipment_Age_Years`, `Cost_Per_Soldier` desde sus fuentes
  - Valores imposibles: filtrar o marcar `Combat_Ready_Pct > 100`, `End_Year < Start_Year`
- **Claves surrogate**: `dbt_utils.generate_surrogate_key(['{natural_key}'])` → SHA-256
- **SCD Tipo 2**: `dim_country` vía dbt Snapshot, rastreando cambios en `Government_Type` y `Alliance_Role`
- **Bridge tables**: `bridge_mission_participants` y `bridge_equipment_models` como tablas de unión M:N

### Gold (Consumo)
- **Principio**: métricas de negocio precalculadas, optimizadas para Power BI.
- **Materialización**: vistas materializadas o tablas con refresh diario.
- Nunca referenciar Bronze directamente; siempre vía modelos Silver.

---

## Modelo Silver — Detalle de Tablas (11)

### Dimensiones

| Tabla | Grano | Filas aprox. | Notas |
|-------|-------|-------------|-------|
| `dim_country` | 1 fila = 1 país (versión activa SCD-2) | 32 | SCD-2: Government_Type, Alliance_Role |
| `dim_region` | 1 fila = 1 región geográfica | ~10 | Normalizada desde Country y Operation_Region |
| `dim_equipment_type` | 1 fila = 1 tipo de equipo | ~30 | Jerarquía: Equipment_Type → Category → Domain |
| `dim_mission_type` | 1 fila = 1 tipo de misión | ~15 | Mission_Type + Classification + Threat_Level |
| `dim_command_hq` | 1 fila = 1 cuartel general | ~10 | Normalizado desde Command_HQ |
| `dim_year` | 1 fila = 1 año (1949–2024) | 76 | Date spine generado con dbt_utils |

### Hechos

| Tabla | Grano | Filas aprox. | Métricas clave |
|-------|-------|-------------|---------------|
| `fact_country_stats` | 1 fila = 1 país × 1 año | ~1,480 | GDP, Defense_Budget, Military_Personnel |
| `fact_equipment_inventory` | 1 fila = 1 registro de inventario | ~4,060 | Units_Count, Total_Value, Combat_Ready_Pct |
| `fact_missions` | 1 fila = 1 misión | ~5,200 | Troops_Deployed, Mission_Cost, Casualties |

### Puentes

| Tabla | Grano | Filas aprox. | Relación |
|-------|-------|-------------|---------|
| `bridge_mission_participants` | 1 fila = 1 país × 1 misión | ~68,800 | Desanidado desde raw_mission_participants |
| `bridge_equipment_models` | 1 fila = 1 equipo × 1 modelo | ~12,000 | Split de Notable_Models (delimitador `/`) |

---

## Transformaciones Clave Bronze → Silver

| Problema (Bronze) | Transformación (Silver) | Tabla afectada |
|---|---|---|
| Duplicados ~2.5% (reingesta) | `ROW_NUMBER() OVER (PARTITION BY Record_ID)` | Todas |
| Nulos como `""`, `"NULL"`, `"N/A"` | `NULLIF(TRIM(col), '') → COALESCE` | Todas |
| Boolean `YES/yes/Y/True/1` | `CASE WHEN UPPER(TRIM(col)) IN ('YES','Y','TRUE','1') THEN TRUE` | 8+ columnas |
| `Country = "Turkey"` vs `"Türkiye"` | Join con tabla ISO_Code como clave canónica | dim_country |
| `Alliance_Role` cambia cada año | dbt Snapshot → SCD-2 con `dbt_valid_from` / `dbt_valid_to` | dim_country |
| `Duration_Years` no coincide con `End - Start` | `DATEDIFF(year, Start, End)` recalculado | fact_missions |
| `Cost_Per_Soldier` incorrecto | `Mission_Cost_M_USD * 1_000_000 / Troops_Deployed` | fact_missions |
| `Equipment_Age_Years` incorrecto | `YEAR(CURRENT_DATE) - Year_Acquired` | fact_equipment |
| `Total_Value_M_USD` incorrecto | `Units_Count * Unit_Cost_M_USD` | fact_equipment |
| `Combat_Ready_Pct > 100` | `LEAST(col, 100)` + flag `is_value_corrected` | fact_equipment |
| `End_Year < Start_Year` | Marcar como `is_date_anomaly = TRUE`, excluir de facts | fact_missions |
| `Notable_Models = "M113 / Boxer"` | `SPLIT_TO_TABLE` → bridge | bridge_equipment_models |
| Whitespace en strings | `TRIM(col)` en todas las CTEs `cleaned` | Todas |

---

## Datos Sucios Bronze — Catálogo Completo

| Tipo | Columnas afectadas | % aprox. | Cómo detectarlo |
|------|-------------------|----------|----------------|
| Duplicados exactos | Record_ID (todas las tablas) | 2.5% | COUNT vs COUNT DISTINCT |
| Nulos disfrazados | Inflation_Rate_Pct, Training_Exercises, Troops_Contributed | 4-5% | `col IN ('','NULL','N/A','-')` |
| Boolean inconsistente | Founding_Member, NATO_Led, UN_Mandate, Interoperable | 6-7% | `col NOT IN ('Yes','No')` |
| Nombres de país variantes | Country (todas) | 7% | Anti-join con tabla maestra ISO |
| Alliance_Role / Gov_Type aleatorio | Country_Stats por año | 100% | Requiere SCD-2 |
| Duration_Years incorrecto | NATO_3 | 8% | `Duration_Years != End - Start` |
| Cost_Per_Soldier incorrecto | NATO_3 | 8% | `abs(CPT - Cost/Troops) > 0.01` |
| Equipment_Age_Years incorrecto | NATO_2 | 6% | `Age != 2024 - Year_Acquired` |
| Total_Value incorrecto | NATO_2 | 7% | `abs(Total - Units * Cost) > 1` |
| Combat_Ready_Pct > 100 | NATO_2 | 1.5% | `Combat_Ready_Pct > 100` |
| End_Year < Start_Year | NATO_3 | ~4 filas | `End_Year < Start_Year` |
| Whitespace en strings | Mission_Name, Notable_Models, Capital | 4-5% | `col != TRIM(col)` |
| Casing mixto | Operational_Status, Classification, Participation_Role | 6-7% | `col != INITCAP(col)` |

---

## Particionado S3

```
Estrategia: por ingestion_date (Hive-style) — snapshot completo por ejecución

s3://nato-raw-zone/
├── country_stats/
│   └── ingestion_date=2026-05-04/
│       └── country_stats.parquet      (~1,500 filas, ~280 KB)
├── equipment_inventory/
│   └── ingestion_date=2026-05-04/
│       └── equipment_inventory.parquet (~4,200 filas, ~800 KB)
├── missions/
│   └── ingestion_date=2026-05-04/
│       └── missions.parquet            (~5,400 filas, ~1.3 MB)
└── mission_participants/
    └── ingestion_date=2026-05-04/
        └── mission_participants.parquet (~70,000 filas, ~5.5 MB)
```

> **Nota**: Los CSV son snapshots completos (no hay datos nuevos diariamente). La partición por `ingestion_date` permite detectar y deduplicar reingestas en Bronze y Silver.

---

## Stack de Versiones

| Tecnología | Versión | Rol |
|-----------|---------|-----|
| Python | 3.11 | Ingesta CSV → Parquet → S3 |
| PyArrow | 14.x | Serialización Parquet (Snappy) |
| pandas | 2.x | Transformaciones en ingesta |
| boto3 | 1.34.x | Upload S3 con SSE-S3 |
| Dagster | 1.6.x | Orquestación SDAs |
| dagster-dbt | 0.22.x | Integración dbt en Dagster |
| dagster-snowflake | 0.22.x | Recurso Snowflake inyectable |
| dbt Core | 1.7.x | Transformaciones Silver + Gold |
| dbt-snowflake | 1.7.x | Adapter Snowflake |
| dbt-utils | 1.1.x | `generate_surrogate_key`, `date_spine` |
| Snowflake | — | Data Warehouse (Bronze/Silver/Gold) |
| Power BI | — | Dashboards + DAX + RLS |

---

## Seguridad

| Componente | Mecanismo |
|-----------|-----------|
| S3 → Snowflake | Storage Integration (IAM Role, sin Access Keys) |
| Python → S3 | IAM Role en ECS Task (no credenciales en código) |
| Dagster → Snowflake | `SnowflakeResource` via variables de entorno |
| Dagster → dbt | `DbtCliResource` con profiles.yml desde env vars |
| Power BI → Snowflake | Service Principal con certificado |
| Power BI RLS | Filtro por `region` sobre `dim_country` |
