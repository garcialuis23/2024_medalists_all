# NATO Alliance Data Pipeline — Instrucciones del Proyecto

## Contexto del Proyecto

Pipeline de datos End-to-End sobre la **Alianza NATO (1949–2024)**, aplicando arquitectura Medallion (Bronze → Silver → Gold) sobre datos reales de los 32 países miembros.

- **Dominio**: estadísticas económico-militares, inventario de armamento, operaciones y misiones, participación de países por misión.
- **Fuente Bronze**: 4 CSV con ~80.000 filas en total, datos intencionadamente sucios (duplicados, nulos disfrazados, booleanos inconsistentes, campos calculados erróneos, nombres de país variantes).
- **Objetivo analítico**: gasto en defensa vs. cumplimiento del objetivo 2% PIB, efectividad de misiones NATO, capacidad operativa por región, expansión de la Alianza en el tiempo.

## Stack Tecnológico

| Capa | Tecnología |
|------|-----------|
| Ingesta | Python 3.11, PyArrow, pandas, boto3 |
| Almacenamiento Raw | AWS S3 (Parquet Snappy, particionado por `ingestion_date`) |
| Orquestación | Dagster (Software-Defined Assets) |
| Data Warehouse | Snowflake (Bronze / Silver / Gold) |
| Transformación | dbt Core (modelos incrementales + Snapshots SCD-2) |
| Presentación | Power BI (modelo estrella importado, DAX avanzado, RLS por región) |

## Datasets Bronze (4 CSV → Snowflake)

| Archivo CSV | Tabla Bronze | Filas aprox. | Descripción |
|------------|-------------|-------------|-------------|
| `NATO_1_Country_Stats.csv` | `raw_country_stats` | 1,517 | Serie temporal 1949-2024: GDP, defensa, personal militar |
| `NATO_2_Equipment_Inventory.csv` | `raw_equipment_inventory` | 4,157 | Inventario de armamento por país y tipo |
| `NATO_3_Operations_Missions.csv` | `raw_missions` | 5,330 | Registro de operaciones y misiones NATO |
| `NATO_4_Mission_Participants.csv` | `raw_mission_participants` | 69,818 | Bridge: qué países participaron en cada misión |

## Capas de Datos

```
CSV (Bronze raw) → Parquet → S3 → Snowflake Bronze (COPY INTO) → Silver (dbt) → Gold (dbt) → Power BI
```

- **Bronze**: datos crudos sin casteo. Todas las columnas de negocio son `VARCHAR`. Metadatos `_loaded_at` / `_file_name` / `_file_row_number` / `_ingestion_date` OBLIGATORIOS.

- **Silver (11 tablas)**: casteo estricto, deduplicación con window functions, normalización de nulos/booleanos/strings, claves surrogate SHA-256 (`dbt_utils.generate_surrogate_key`), SCD-2 en `dim_country`, bridge tables para relaciones M:N. Tests de calidad en `schema.yml`.
  - Dimensiones: `dim_country`, `dim_region`, `dim_equipment_type`, `dim_mission_type`, `dim_command_hq`, `dim_year`
  - Hechos: `fact_country_stats`, `fact_equipment_inventory`, `fact_missions`
  - Puentes: `bridge_mission_participants`, `bridge_equipment_models`

- **Gold**: agregados de consumo para Power BI — `agg_defense_spending_trend`, `agg_mission_outcomes`, `agg_equipment_readiness`, `agg_nato_expansion`.

## Convenciones de Código

- **Python**: type hints obligatorios, docstrings en español, variables de entorno para toda configuración, sin secretos en código.
- **SQL / dbt**: modelos en `snake_case`, prefijos `dim_` / `fact_` / `bridge_` (Silver), `agg_` (Gold). Materializaciones explícitas en `dbt_project.yml`.
- **Dagster**: todos los activos son Software-Defined Assets. Recursos (Snowflake, S3, dbt) inyectados, nunca instanciados dentro del asset. Observabilidad mediante `context.log` y metadata outputs.
- **Snowflake**: base de datos `nato_db`, esquemas `bronze` / `silver` / `gold`. File Format `parquet_nato_ff` (Snappy). External Stage `s3_nato_stage`.

## Estructura del Repositorio

```
ingestion/          # Script Python + Dockerfile (CSV → Parquet → S3)
orchestration/      # Dagster project (assets, resources, schedules)
bronze/             # DDL Snowflake Bronze + Stage + COPY INTO
dbt/                # Modelos Silver (11 tablas), Gold (4 agg), Snapshots, Tests
powerbi/            # Medidas DAX + RLS
docs/               # Arquitectura + diagramas
```

## Seguridad

- Sin credenciales hard-coded; usar variables de entorno o IAM Roles en ECS.
- Snowflake External Stage via Storage Integration (no Access Keys).
- Power BI RLS por columna `region` de `dim_country`.

## Agentes Especializados Disponibles

Ver `.github/agents/` para los agentes por capa:
- `ingestion` — lectura CSV, conversión Parquet, upload S3
- `orchestration` — Dagster SDA, recursos, backfilling
- `bronze` — Snowflake DDL, External Stage, COPY INTO, metadatos
- `silver` — dbt staging, incremental, dedup, limpieza, SCD-2, bridge tables
- `gold` — agregados de consumo, Power BI
- `analytics` — Power BI, DAX, KPIs NATO, RLS

## Gestión del Conocimiento — OBLIGATORIO

Cada vez que se descubra algo nuevo, se añada funcionalidad o se resuelva un problema, el agente DEBE:

1. **Actualizar `/memories/repo/`** — guardar el hallazgo en el archivo correspondiente (crear si no existe). Incluir: qué se añadió, en qué archivo/capa, y por qué.
2. **Actualizar `docs/architecture.md`** — si el cambio afecta arquitectura, stack, capas o convenciones.
3. **Actualizar este archivo** — si el cambio introduce una nueva convención, restricción o tecnología.

### Archivos de memoria del repositorio (`/memories/repo/`)

| Archivo | Contenido |
|---------|-----------|
| `project-state.md` | Estado actual: qué capas están implementadas, qué falta |
| `ingestion.md` | Decisiones de la capa de ingesta |
| `orchestration.md` | Decisiones de Dagster |
| `snowflake-bronze.md` | DDL, stage, metadatos Bronze |
| `dbt-silver-gold.md` | Modelos dbt, tests, snapshots, transformaciones de limpieza |
| `powerbi.md` | Medidas DAX, RLS, KPIs NATO |
