# Logística Última Milla España — Instrucciones del Proyecto

## Contexto del Proyecto
Pipeline de datos End-to-End sobre **logística de última milla en España**, cruzando operativa interna con impacto climático.
- Dominio: flota de reparto, rutas, incidencias, datos meteorológicos Open-Meteo.
- Objetivo analítico: costes operativos, SLA de entrega, correlación clima-incidencias.

## Stack Tecnológico
| Capa | Tecnología |
|------|-----------|
| Ingesta | Python 3.11, Faker, httpx + tenacity, PyArrow, boto3 |
| Almacenamiento Raw | AWS S3 (Parquet, particionado por `extraction_date`) |
| Orquestación | Dagster (Software-Defined Assets, particiones diarias) |
| Data Warehouse | Snowflake (Bronze / Silver / Gold) |
| Transformación | dbt Core (modelos incrementales + Snapshots SCD-2) |
| Presentación | Power BI (modelo estrella, DAX, RLS por CCAA) |

## Capas de Datos
```
S3 (raw) → Snowflake Bronze (COPY INTO) → Silver (dbt, incremental) → Gold (Kimball)
```
- **Bronze**: datos crudos sin casteo, todas las columnas VARCHAR, metadatos `_loaded_at` / `_file_name` / `_file_row_number` / `_extraction_date` OBLIGATORIOS.
- **Silver**: casteo estricto, deduplicación con window functions, claves surrogate hash (`dbt_utils.generate_surrogate_key`), tests de calidad en `schema.yml`.
- **Gold**: modelo dimensional Kimball, SCD-2 en `dim_courier` via dbt Snapshots.

## Convenciones de Código
- **Python**: type hints obligatorios, docstrings en español, variables de entorno para toda configuración, sin secretos en código.
- **SQL / dbt**: nombres de modelo en `snake_case`, prefijos `stg_` (Silver staging), `dim_` / `fact_` (Gold). Materializaciones explícitas en `dbt_project.yml`.
- **Dagster**: todos los activos son Software-Defined Assets. Los recursos (Snowflake, S3, dbt) se inyectan, nunca se instancian dentro del asset. Observabilidad mediante `context.log` y metadata outputs.
- **Snowflake**: base de datos `logistics_db`, esquemas `bronze` / `silver` / `gold`. File Format `parquet_logistics_ff` (Snappy). External Stage `s3_raw_stage`.

## Estructura del Repositorio
```
ingestion/          # Script Python + Dockerfile
orchestration/      # Dagster project
snowflake/          # DDL Bronze + Stage + COPY INTO
dbt/                # Modelos Silver, Gold, Snapshots, Tests
powerbi/            # Medidas DAX + RLS
docs/               # Arquitectura + diagramas
```

## Seguridad
- Sin credenciales hard-coded; usar variables de entorno o IAM Roles en ECS.
- Snowflake External Stage via Storage Integration (no Access Keys).
- Power BI RLS por columna `zone_ccaa` de la dimensión de conductor.

## Agentes Especializados Disponibles
Ver `.github/agents/` para los agentes por capa:
- `ingestion` — generación sintética, Open-Meteo, Parquet, S3
- `orchestration` — Dagster SDA, recursos, particiones, backfilling
- `bronze` — Snowflake DDL, External Stage, COPY INTO, metadatos
- `silver` — dbt staging, incremental, deduplicación, tests
- `gold` — modelo Kimball, dbt Snapshots SCD-2, dimensiones, hechos
- `analytics` — Power BI, DAX, medidas de negocio, RLS

## Gestión del Conocimiento — OBLIGATORIO

Cada vez que se descubra algo nuevo, se añada funcionalidad o se resuelva un problema relevante, el agente DEBE:

1. **Actualizar `/memories/repo/`** — guardar el hallazgo en el archivo de memoria de repositorio correspondiente (crear si no existe). Incluir: qué se añadió, en qué archivo/capa, y por qué.

2. **Actualizar `docs/architecture.md`** — si el cambio afecta a la arquitectura, al stack, a las capas de datos o a las convenciones, reflejar el cambio en la documentación.

3. **Actualizar este archivo (`copilot-instructions.md`)** — si el cambio introduce una nueva convención, restricción de seguridad, tecnología o patrón que deba aplicarse en el futuro.

### Archivos de memoria del repositorio (`/memories/repo/`)
| Archivo | Contenido |
|---------|-----------|
| `project-state.md` | Estado actual del proyecto: qué capas están implementadas, qué falta |
| `ingestion.md` | Decisiones y hallazgos de la capa de ingesta |
| `orchestration.md` | Decisiones y hallazgos de Dagster |
| `snowflake-bronze.md` | DDL, stage, metadatos Bronze |
| `dbt-silver-gold.md` | Modelos dbt, tests, snapshots |
| `powerbi.md` | Medidas DAX, RLS, modelo estrella |

### Cuándo actualizar cada archivo
- **Nuevo asset Dagster** → `orchestration.md` + `project-state.md`
- **Nueva tabla Bronze** → `snowflake-bronze.md` + `docs/architecture.md`
- **Nuevo modelo dbt** → `dbt-silver-gold.md` + `docs/architecture.md`
- **Nueva medida DAX o RLS** → `powerbi.md`
- **Cambio de convención o patrón** → este archivo (`copilot-instructions.md`)
