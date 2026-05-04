# NATO Alliance Data Pipeline — Medallion Architecture

End-to-end data engineering pipeline sobre los **32 países miembros de la OTAN (1949–2024)**, aplicando arquitectura Medallion (Bronze → Silver → Gold) sobre ~80.000 filas de datos históricos reales con calidad de datos intencionadamente degradada.

---

## Arquitectura

```
┌────────────────────────────────────────────────────────────────────────────┐
│  INGESTA  Python 3.11 + Docker                                             │
│  Lee 4 CSV Bronze → PyArrow Parquet (Snappy) → AWS S3 particionado         │
└───────────────────────────────┬────────────────────────────────────────────┘
                                │
          s3://nato-raw-zone/{dataset}/ingestion_date=YYYY-MM-DD/
                                │
┌───────────────────────────────▼────────────────────────────────────────────┐
│  DAGSTER  Software-Defined Assets + Schedule diario 02:00 UTC              │
│                                                                            │
│  raw_nato_data                                                             │
│    ├── bronze_country_stats          COPY INTO (Snowflake External Stage)  │
│    ├── bronze_equipment_inventory                                          │
│    ├── bronze_missions                                                     │
│    └── bronze_mission_participants                                         │
│               └── nato_dbt_assets   dbt build (Silver + Gold)             │
└───────────────────────────────┬────────────────────────────────────────────┘
                                │
┌───────────────────────────────▼────────────────────────────────────────────┐
│  SNOWFLAKE  nato_db                                                        │
│                                                                            │
│  BRONZE (4 tablas — todo VARCHAR + auditoria)                              │
│  raw_country_stats  raw_equipment_inventory  raw_missions  raw_participants│
│                                │                                           │
│  SILVER (11 tablas — limpieza, tipado, normalización, SCD-2)               │
│  dim_country(SCD2)  dim_region  dim_equipment_type  dim_mission_type       │
│  dim_command_hq     dim_year                                               │
│  fact_country_stats  fact_equipment_inventory  fact_missions               │
│  bridge_mission_participants   bridge_equipment_models                     │
│                                │                                           │
│  GOLD (4 agregados — consumo Power BI)                                     │
│  agg_defense_spending_trend    agg_mission_outcomes                        │
│  agg_equipment_readiness       agg_nato_expansion                          │
└───────────────────────────────┬────────────────────────────────────────────┘
                                │ Import Mode
┌───────────────────────────────▼────────────────────────────────────────────┐
│  POWER BI  4 dashboards + 8 medidas DAX + RLS por Region                   │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Stack Tecnologico

| Capa | Tecnologia | Version |
|------|-----------|---------|
| Ingesta | Python, PyArrow, pandas, boto3 | 3.11 / 14.x / 2.x / 1.34.x |
| Raw Zone | AWS S3 (Parquet Snappy, Hive partitioning) | — |
| Orquestacion | Dagster + dagster-snowflake + dagster-dbt | 1.6.x |
| Data Warehouse | Snowflake (Bronze / Silver / Gold) | — |
| Transformacion | dbt Core + dbt-snowflake + dbt-utils | 1.7.x |
| Presentacion | Power BI (Import, DAX, RLS) | — |

---

## Datasets Bronze

| Archivo | Tabla Snowflake | Filas | Descripcion |
|---------|----------------|-------|-------------|
| `NATO_1_Country_Stats.csv` | `raw_country_stats` | ~1,500 | Serie temporal 1949-2024: PIB, presupuesto defensa, personal militar, interoperabilidad |
| `NATO_2_Equipment_Inventory.csv` | `raw_equipment_inventory` | ~4,200 | Inventario armamento: tipo, categoria, dominio, modelos, estado operativo, valor |
| `NATO_3_Operations_Missions.csv` | `raw_missions` | ~5,300 | Operaciones NATO: tipo, pais lider, region, duracion, coste, bajas, resultado |
| `NATO_4_Mission_Participants.csv` | `raw_mission_participants` | ~70,000 | Bridge: que paises participaron en cada mision, con rol y activos aportados |

> Los CSV contienen datos sinteticos estadisticamente realistas (no son cifras oficiales OTAN).

---

## Datos Sucios Bronze — Por que existe el Pipeline

Los 4 CSV tienen calidad de datos degradada intencionadamente para justificar cada transformacion en Silver:

| Problema | Ejemplo | Transformacion Silver |
|----------|---------|----------------------|
| Duplicados (~2.5%) | Misma fila con distinto `_loaded_at` | `ROW_NUMBER() OVER (PARTITION BY Record_ID)` |
| Nulos disfrazados (~4%) | `"NULL"`, `"N/A"`, `"-"`, `""` | `NULLIF(TRIM(col), '')` |
| Booleanos inconsistentes (~6%) | `Yes/YES/yes/Y/True/1` | `CASE WHEN UPPER(...) IN ('YES','Y','TRUE','1')` |
| Nombres de pais variantes (~7%) | `"Turkey"` vs `"Turkiye"` | Join canonico por `ISO_Code` |
| Alliance_Role aleatorio por anyo | Cambia cada anyo sin logica | dbt Snapshot SCD Tipo 2 |
| Campos calculados erroneos (~7%) | `Duration_Years != End - Start` | Recalculo desde fuentes primarias |
| Valores imposibles (~2%) | `Combat_Ready_Pct = 112%` | `LEAST(col, 100)` + flag |
| Fechas imposibles (~4 filas) | `End_Year < Start_Year` | Flag `is_date_anomaly`, excluir de hechos |
| Whitespace (~5%) | `"  Operation Eagle Eye  "` | `TRIM()` en todas las CTEs |
| Casing mixto (~6%) | `"OPERATIONAL"` vs `"Operational"` | `INITCAP()` / `UPPER()` |
| Campo multi-valor | `"M113 / Boxer / BTR-80"` | `SPLIT_TO_TABLE` → `bridge_equipment_models` |

---

## Capa Silver — 11 Tablas

### Dimensiones (6)

| Tabla | Grano | SCD | Descripcion |
|-------|-------|-----|-------------|
| `dim_country` | 1 pais | Tipo 2 | Atributos estaticos + historial Government_Type y Alliance_Role |
| `dim_region` | 1 region geografica | No | Regiones normalizadas de paises y operaciones |
| `dim_equipment_type` | 1 tipo de equipo | No | Jerarquia: Equipment_Type > Category > Domain |
| `dim_mission_type` | 1 tipo de mision | No | Mission_Type + Classification + Threat_Level |
| `dim_command_hq` | 1 cuartel general | No | Cuarteles NATO normalizados |
| `dim_year` | 1 anyo (1949-2030) | No | Date spine generado con `dbt_utils.date_spine` |

### Hechos (3)

| Tabla | Grano | Filas aprox. | Metricas clave |
|-------|-------|-------------|---------------|
| `fact_country_stats` | 1 pais x 1 anyo | ~1,480 | PIB, presupuesto defensa, personal militar, interoperabilidad |
| `fact_equipment_inventory` | 1 registro inventario | ~4,060 | Unidades, valor total, combat readiness, estado operativo |
| `fact_missions` | 1 mision | ~5,200 | Tropas, coste, bajas, duracion, resultado |

### Puentes (2)

| Tabla | Grano | Filas aprox. | Relacion M:N |
|-------|-------|-------------|-------------|
| `bridge_mission_participants` | 1 pais x 1 mision | ~68,800 | Pais contribuyente, rol, activos aportados |
| `bridge_equipment_models` | 1 equipo x 1 modelo | ~12,000 | Split de `Notable_Models` (delimitador `/`) |

---

## Capa Gold — 4 Agregados para Power BI

| Tabla | Descripcion |
|-------|-------------|
| `agg_defense_spending_trend` | Gasto en defensa por pais/anyo con YoY y cumplimiento objetivo 2% PIB |
| `agg_mission_outcomes` | Resultados de misiones con participantes reales y metricas de coste/bajas |
| `agg_equipment_readiness` | Capacidad operativa por pais/categoria/dominio |
| `agg_nato_expansion` | Evolucion de la Alianza: miembros, PIB colectivo, interoperabilidad (1949-2024) |

---

## Power BI — KPIs Principales

| KPI | Formula |
|-----|---------|
| Cumplimiento 2% PIB | Paises con `defense_gdp_percent >= 2` / total miembros |
| Tasa de Exito Misiones | Misiones "Mission Accomplished" / total misiones |
| Combat Readiness Media | Promedio ponderado por unidades de `avg_combat_ready_pct` |
| Crecimiento Alianza | Miembros NATO por anyo (1949: 12 → 2024: 32) |
| Coste por Soldado | `SUM(mission_cost_m_usd) * 1M / SUM(troops_deployed)` |

**RLS**: filtro por `region` en `dim_country` → rol "Analista Regional" solo ve datos de su region.

---

## Estructura del Repositorio

```
nato-alliance-data-pipeline/
├── NATO_1_Country_Stats.csv          # Bronze raw: estadisticas anuales por pais
├── NATO_2_Equipment_Inventory.csv    # Bronze raw: inventario de armamento
├── NATO_3_Operations_Missions.csv    # Bronze raw: operaciones y misiones
├── NATO_4_Mission_Participants.csv   # Bronze raw: bridge paises participantes
├── bronze_data_generator.py          # Script que genero los CSV con dirty data
│
├── last-mile-data-pipeline/
│   ├── .github/
│   │   ├── copilot-instructions.md   # Instrucciones del proyecto para agentes IA
│   │   └── agents/                   # Agentes especializados por capa
│   │       ├── ingestion.agent.md
│   │       ├── orchestration.agent.md
│   │       ├── bronze.agent.md
│   │       ├── silver.agent.md
│   │       ├── gold.agent.md
│   │       └── analytics.agent.md
│   ├── docs/
│   │   └── architecture.md           # Arquitectura tecnica detallada
│   ├── ingestion/                    # Script Python + Dockerfile
│   │   ├── src/ingest.py             # CSV → Parquet → S3
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── bronze/                       # DDL Snowflake
│   │   ├── 01_external_stage.sql
│   │   ├── 02_landing_tables_ddl.sql
│   │   └── 03_copy_into.sql
│   ├── orchestration/                # Dagster project
│   │   ├── dagster_project/
│   │   │   ├── assets/
│   │   │   └── resources/
│   │   └── dagster.yaml
│   └── dbt/                          # Modelos Silver + Gold + Tests
│       ├── models/silver/
│       ├── models/gold/
│       └── snapshots/
```

---

## Como Ejecutar

### Variables de entorno requeridas

```bash
export S3_BUCKET="nato-raw-zone"
export SNOWFLAKE_ACCOUNT="xxxxx.eu-west-1"
export SNOWFLAKE_USER="nato_pipeline_user"
export SNOWFLAKE_PASSWORD="..."
export SNOWFLAKE_ROLE="nato_pipeline_role"
export SNOWFLAKE_WAREHOUSE="compute_wh"
```

### Ingesta manual (una vez)

```bash
cd last-mile-data-pipeline/ingestion
pip install -r requirements.txt
INGESTION_DATE=2026-05-04 python -m src.ingest
```

### Pipeline completo via Dagster

```bash
cd last-mile-data-pipeline/orchestration
pip install -e ".[dev]"
dagster dev
# Abrir http://localhost:3000 → materializar todos los assets
```

### Solo transformaciones dbt

```bash
cd last-mile-data-pipeline/dbt
dbt deps
dbt build --target prod
```

---

## Decisiones de Diseno

**Por que Bronze es todo VARCHAR?**
Confianza cero en los datos de origen. Los errores de casteo en Bronze destruirian datos; mejor detectarlos en Silver con `TRY_TO_NUMERIC` y registrar los fallos.

**Por que SCD Tipo 2 en dim_country?**
`Government_Type` y `Alliance_Role` varian por anyo en los datos. Un SCD-2 permite rastrear con que estructura politica contaba un pais durante cada mision o anyo fiscal.

**Por que bridge_mission_participants es la tabla mas grande (70k filas)?**
El dataset original solo tenia el conteo de paises por mision. Esta tabla resuelve la relacion M:N real entre misiones y paises, permitiendo analizar contribuciones individuales por rol.

**Por que Notable_Models se desanida en Silver y no en Bronze?**
Bronze preserva los datos exactamente como vienen del CSV. La logica de negocio (separar `"M113 / Boxer"` en dos modelos distintos) es una transformacion que pertenece a Silver.

---

## Disclaimer

Los datos son sinteticos/simulados generados para fines educativos. No representan cifras oficiales de la OTAN. Para datos oficiales: [NATO Statistics](https://www.nato.int/cps/en/natohq/topics_49198.htm).

---

*Dataset base: NATO Alliance Complete Dataset 2024 — CC0 1.0 Universal (Public Domain)*
