# Paris 2024 Olympic Medalists — Data Pipeline

Arquitectura medallón completa (Bronze → Silver → Gold) sobre los medallistas de los Juegos Olímpicos de París 2024, con Dagster como orquestador, Snowflake como data warehouse y modelos dbt listos para consumo en Power BI.

---

## Índice

1. [Arquitectura general](#arquitectura-general)
2. [Stack tecnológico](#stack-tecnológico)
3. [Dataset fuente](#dataset-fuente)
4. [Capas del modelo](#capas-del-modelo)
   - [Bronze](#bronze)
   - [Silver](#silver)
   - [Gold](#gold)
5. [Modelo relacional](#modelo-relacional)
6. [Calidad de datos](#calidad-de-datos)
7. [Orquestación — Dagster](#orquestación--dagster)
8. [Configuración y despliegue](#configuración-y-despliegue)
9. [Decisiones de diseño](#decisiones-de-diseño)

---

## Arquitectura general

```
CSV / Wikidata
      │
      ▼
┌──────────────┐
│    BRONZE    │  Carga raw, cero transformaciones, todo VARCHAR
│  BRONZE_DB   │
└──────┬───────┘
       │  dbt ref()
       ▼
┌──────────────┐
│    SILVER    │  Limpieza, normalización, modelo estrella
│  SILVER_DB   │  9 tablas: 8 dimensiones + 1 tabla de hechos
└──────┬───────┘
       │  dbt ref()
       ▼
┌──────────────┐
│     GOLD     │  Desnormalización para BI, métricas agregadas
│   GOLD_DB    │  5 tablas: 4 dimensiones + 1 fact_medal
└──────┬───────┘
       │
       ▼
   Power BI / SQL
```

Cada capa vive en su propia base de datos Snowflake (`BRONZE_DB`, `SILVER_DB`, `GOLD_DB`) para aislar el acceso y los costes de compute.

---

## Stack tecnológico

| Componente | Tecnología | Versión |
|---|---|---|
| Ingesta y transformación | dbt Core | 1.7.x |
| Data Warehouse | Snowflake | — |
| Orquestación | Dagster | 1.6.x |
| Lenguaje Python | Python | 3.11 |
| Visualización | Power BI | — |
| Control de versiones | Git | — |

---

## Dataset fuente

**Archivo:** `2024_medalists_all.csv` (~1.5 MB)

Dataset de medallistas de los Juegos Olímpicos de París 2024 enriquecido con datos de Wikidata. Cada fila representa a un medallista en un evento específico.

**Columnas principales (52 columnas):**

| Grupo | Campos destacados |
|---|---|
| Atleta | `medalist_wikidata_id`, `medalist_name`, `medalist_link`, `birth_date`, `sex` |
| País / Delegación | `country_wikidata_id`, `country_name`, `iso2`, `iso3`, `ioc_code`, `delegation_id` |
| Deporte | `sport_wikidata_id`, `discipline_wikidata_id`, `event_wikidata_id` |
| Medalla | `medal` (gold / silver / bronze) |
| Lugar de nacimiento | `place_wikidata_id`, `lat`, `lon` |
| Geografía NUTS | `nuts0_id`…`nuts3_id`, `nuts0_name`…`nuts3_name`, `nuts3_population`, `nuts3_gdp` |

> Los valores ausentes vienen codificados como el string `'NA'`. La capa Bronze los preserva; Silver los neutraliza con `NULLIF(campo, 'NA')`.

---

## Capas del modelo

### Bronze

**Base de datos:** `BRONZE_DB_PRO` (prod) / `BRONZE_DB_DEV` (dev)  
**Materialización:** `table`

| Modelo | Descripción |
|---|---|
| `bronze_medalists_raw` | `SELECT *` sin transformaciones. Preserva tipos VARCHAR y los `'NA'` originales. |

La fuente está declarada en `models/bronze/_sources.yml`:

```yaml
source: bronze.MEDALISTS_2024
schema: PUBLIC
```

**Tests definidos en la fuente:**
- `medal`: `accepted_values` → `[gold, silver, bronze]`

---

### Silver

**Base de datos:** `SILVER_DB`  
**Materialización:** `table`  
**Patrón:** modelo estrella normalizado

#### Dimensiones (8 tablas)

| Tabla | Grain | Descripción |
|---|---|---|
| `silver_country` | 1 fila por país | Países únicos con medallistas. Campos: `wikidata_id_pais`, `nombre`, `codigo_iso2`, `codigo_iso3`, `codigo_coi`. |
| `silver_delegation` | 1 fila por delegación | Delegaciones olímpicas. Referencia a `silver_country` mediante `wikidata_id_pais`. |
| `silver_sport` | 1 fila por deporte | Deportes únicos deduplicados. |
| `silver_discipline` | 1 fila por disciplina | Agrupación de deportes. Jerarquía: Disciplina → Deporte. |
| `silver_event` | 1 fila por evento | Eventos individuales con medalla. Jerarquía: Evento → Disciplina → Deporte. |
| `silver_athlete` | 1 fila por atleta | Atletas únicos con deduplicación. `QUALIFY` selecciona la fila con fecha de nacimiento válida cuando hay duplicados. Referencia a `silver_place`. |
| `silver_place` | 1 fila por lugar de nacimiento | Lugares de nacimiento con coordenadas y código NUTS3. `QUALIFY` prioriza filas con latitud no nula. |
| `silver_nuts_region` | 1 fila por región NUTS (niveles 0–3) | Jerarquía geográfica europea autorreferencial. `UNION ALL` de los 4 niveles. Sólo regiones con atletas europeos. Usa `TRY_TO_DOUBLE` para población y PIB. |

**Estructura self-referential de NUTS:**
```
NUTS0 (país) → NUTS1 (región grande) → NUTS2 (región) → NUTS3 (subregión)
     └── id_nuts_padre apunta al nivel superior
```

#### Tabla de hechos

| Tabla | Grain | Descripción |
|---|---|---|
| `silver_medal` | 1 fila por medalla (atleta × evento) | Hecho central del modelo. Clave surrogate `id_medalla` generada con `MD5(atleta \|\| '\|' \|\| evento)`. |

**Columnas de `silver_medal`:**
`id_medalla`, `wikidata_id_atleta`, `wikidata_id_evento`, `wikidata_id_delegacion`, `wikidata_id_pais`, `tipo` (gold/silver/bronze)

**Tests de `silver_medal`:**

| Campo | Test |
|---|---|
| `wikidata_id_atleta` | `not_null`, `relationships` → `silver_athlete` |
| `wikidata_id_evento` | `not_null`, `relationships` → `silver_event` |
| `wikidata_id_delegacion` | `relationships` → `silver_delegation` |
| `wikidata_id_pais` | `relationships` → `silver_country` |
| `tipo` | `accepted_values` → `[gold, silver, bronze]` |

---

### Gold

**Base de datos:** `GOLD_DB`  
**Materialización:** `table`  
**Patrón:** modelo desnormalizado listo para BI (sin JOINs necesarios en Power BI)

#### Dimensiones (4 tablas)

| Tabla | Descripción |
|---|---|
| `dim_country` | Países con recuento de medallas agregado (total, oro, plata, bronce). `LEFT JOIN` a `silver_medal` para que aparezcan países sin medallas. |
| `dim_athlete` | Atletas con datos de lugar de nacimiento desnormalizados: nombre del lugar, región, coordenadas, `nuts3_id`. |
| `dim_event` | Eventos con deporte y disciplina completamente aplanados en una sola fila (Evento ← Disciplina ← Deporte). |
| `dim_nuts` | Jerarquía NUTS completamente desnormalizada. Grain: 1 fila por NUTS3. Columnas de NUTS0 a NUTS3 con nombre, población y PIB. `NULL` para atletas no europeos. |

**Columnas de `dim_country`:**
`country_id`, `name`, `code2`, `code3`, `ioc_code`, `total_medals`, `gold_medals`, `silver_medals`, `bronze_medals`

**Columnas de `dim_nuts` (aplanada):**
`nuts3_id`, `nuts3_name`, `nuts3_population`, `nuts3_gdp`, `nuts2_id`, `nuts2_name`, `nuts2_population`, `nuts2_gdp`, `nuts1_id`, `nuts1_name`, `nuts0_id`, `nuts0_name`

#### Tabla de hechos

| Tabla | Grain | Descripción |
|---|---|
| `fact_medal` | 1 fila por medalla | Todas las dimensiones resueltas en una sola tabla. Permite agregaciones directas sin JOINs. |

**Grupos de columnas de `fact_medal`:**

| Grupo | Columnas |
|---|---|
| Medalla | `medal_id`, `medal_type` |
| Atleta | `athlete_id`, `athlete_name`, `date_of_birth`, `sex`, `birthplace`, `birthplace_region`, `birthplace_lat`, `birthplace_lon` |
| País | `country_id`, `country_name`, `country_code2`, `country_code3`, `country_ioc_code` |
| Delegación | `delegation_id`, `delegation_name` |
| Evento | `event_id`, `event_name`, `discipline_name`, `sport_name` |
| NUTS | `nuts3_id` … `nuts0_name` (NULL para no-europeos) |

> El JOIN a `dim_nuts` se hace con `LEFT JOIN` para preservar medallistas de fuera de Europa.

---

## Modelo relacional

```
silver_country ◄──── silver_delegation ◄──┐
     ▲                                     │
     │                                     │
silver_medal ──────────────────────────────┘
     │
     ├──► silver_athlete ──► silver_place ──► silver_nuts_region (self-ref)
     │
     └──► silver_event ──► silver_discipline ──► silver_sport
```

El diagrama DBML completo está en [`docs/modelo_relacional.dbml`](docs/modelo_relacional.dbml).

---

## Calidad de datos

Los tests dbt se definen en los YAML de cada capa y se ejecutan automáticamente en el pipeline:

| Capa | Test | Tablas afectadas |
|---|---|---|
| Bronze (source) | `accepted_values` en `medal` | `MEDALISTS_2024` |
| Silver | `not_null`, `unique`, `relationships`, `accepted_values` | Todas las dimensiones y `silver_medal` |
| Gold | `not_null`, `relationships` | Dimensiones y `fact_medal` |

**Transformaciones de limpieza en Silver:**
- `NULLIF(campo, 'NA')` en todos los campos de texto para eliminar el placeholder de datos ausentes
- `TRY_TO_DOUBLE()` para conversión segura de coordenadas, población y PIB
- `QUALIFY ROW_NUMBER()` para deduplicación de atletas y lugares (prioridad a filas con datos más completos)

---

## Orquestación — Dagster

El proyecto usa **Dagster Software-Defined Assets (SDA)** para modelar el linaje completo del pipeline.

### Assets

| Asset | Módulo | Descripción |
|---|---|---|
| `raw_logistics_data` | `ingestion_assets.py` | Asset raíz. Particionado por día. Ejecuta el script de ingesta, verifica llegada de ficheros en S3. Timeout: 600 s. |
| `bronze_*` (5 assets) | `snowflake_assets.py` | Un asset por dataset. COPY INTO desde S3 External Stage (formato Parquet) a la capa Bronze. |
| Assets dbt | `dbt_assets.py` | Todos los modelos dbt (Silver + Gold + Snapshots) envueltos automáticamente como assets mediante `dagster-dbt`. |

### Schedule

| Parámetro | Valor |
|---|---|
| Job | `logistics_daily_pipeline` |
| Cron | `0 2 * * *` (02:00 UTC) |
| Orden | Ingestion → Bronze → Silver/Gold |

### Resources

| Recurso | Configuración |
|---|---|
| `S3Resource` | Región `eu-west-1`. IAM Role en ECS; `AWS_ACCESS_KEY_ID` en local. |
| `SnowflakeResource` | `account`, `user`, `password`, `role`, `warehouse` desde variables de entorno. `database=BRONZE_DB`, `schema=PUBLIC`. |
| `DbtCliResource` | `project_dir` y `profiles_dir` apuntando al directorio dbt. |

### Archivos clave de orquestación

```
orchestration/
├── dagster.yaml          # SQLite storage, max 5 runs concurrentes
├── workspace.yaml        # Carga el paquete dagster_project
└── dagster_project/
    ├── __init__.py       # Definitions: assets + resources + schedule
    ├── schedules.py      # Daily schedule 02:00 UTC
    ├── assets/
    │   ├── ingestion_assets.py   # S3 ingestion / validación
    │   ├── snowflake_assets.py   # COPY INTO Bronze (factory pattern)
    │   └── dbt_assets.py         # dbt build Silver + Gold + Snapshots
    └── resources/
        └── resources.py          # S3, Snowflake, dbt resources
```

---

## Configuración y despliegue

### Requisitos previos

- Python 3.11
- Cuenta Snowflake con acceso a `BRONZE_DB`, `SILVER_DB`, `GOLD_DB`
- AWS S3 bucket con stage externo configurado (para orquestación completa)

### Instalación

```bash
pip install dbt-snowflake dagster dagster-dbt dagster-aws
```

### Perfiles dbt

Editar `profiles.yml` con las credenciales de Snowflake:

```yaml
operation_medallion:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <account>
      user: <user>
      password: <password>
      warehouse: COMPUTE_WH
      database: BRONZE_DB_DEV
      schema: PUBLIC
      threads: 4
    pro:
      ...
      database: BRONZE_DB_PRO
```

### Ejecutar dbt

```bash
# Compilar y probar
dbt compile
dbt test

# Ejecutar capa completa
dbt run --select bronze+
dbt run --select silver+
dbt run --select gold+

# Todo el pipeline
dbt build
```

### Ejecutar Dagster

```bash
cd orchestration/
dagster dev
# Interfaz en http://localhost:3000
```

---

## Decisiones de diseño

| Decisión | Justificación |
|---|---|
| **Todo VARCHAR en Bronze** | Preserva integridad del dato crudo. Los errores de tipo se detectan en Silver con `TRY_TO_*`, no en la ingesta. |
| **Claves surrogate MD5 en Silver** | `silver_medal` usa `MD5(atleta_id \|\| '\|' \|\| evento_id)` para claves reproducibles y deterministas sin secuencias. |
| **NUTS autorreferencial** | `silver_nuts_region` usa `UNION ALL` + `id_nuts_padre` para modelar los 4 niveles con una única tabla, evitando 4 tablas separadas. |
| **Gold completamente desnormalizado** | `fact_medal` incluye todos los atributos de dimensiones para que Power BI no necesite JOINs, reduciendo complejidad de modelos semánticos. |
| **LEFT JOIN en `dim_nuts`** | Atletas fuera de Europa no tienen región NUTS; el LEFT JOIN los preserva con NULLs en lugar de eliminarlos del fact. |
| **`QUALIFY` para deduplicación** | En `silver_athlete` y `silver_place` se usa window function para seleccionar la fila más completa sin CTEs intermedias. |
| **Multi-database** | Bronze, Silver y Gold en bases de datos separadas para aislar permisos, costes de compute y ciclos de vida de los datos. |
| **Dagster SDA** | El linaje completo (S3 → Bronze → Silver → Gold) es visible en el grafo de assets, lo que facilita el debugging y la re-ejecución parcial. |
