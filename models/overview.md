{% docs __overview__ %}

# París 2024 — Medallistas Olímpicos

Proyecto dbt que transforma datos crudos de Wikidata sobre los **Juegos Olímpicos de París 2024**
en un modelo dimensional listo para análisis y visualización. Arquitectura Medallion de tres capas.

---

## Arquitectura Medallion

```
Fuente externa (Snowflake Stage)
        │
        ▼
  ┌─────────────┐        ┌────────────────────────────┐        ┌─────────────────┐
  │   BRONZE    │──────▶ │          SILVER             │──────▶ │      GOLD       │
  │             │        │                            │        │                 │
  │ _raw        │        │ silver_medalla (hechos)     │        │ fact_medalla    │
  │ _rejected   │        │ silver_atleta               │        │ dim_pais        │
  └─────────────┘        │ silver_pais                 │        │ dim_atleta      │
  VARCHAR puro           │ silver_delegacion           │        │ dim_evento      │
  sin transformar        │ silver_lugar                │        │ dim_nuts        │
                         │ silver_region_nuts          │        └─────────────────┘
                         │ silver_evento               │        Dimensional BI-ready
                         │ silver_disciplina           │        sin JOINs adicionales
                         │ silver_deporte              │
                         └────────────────────────────┘
                         Normalizado, tipado, FK-safe
```

---

## Bronze

**Base de datos:** `BRONZE_DB_DEV` / `BRONZE_DB_PRO`

Ingesta cruda desde el stage de Snowflake (`MEDALISTS_STAGE`). Sin transformaciones: todos
los valores llegan como `VARCHAR` y los campos vacíos de la fuente se representan con la
cadena literal `'NA'`. El único filtrado aplicado es eliminar filas sin medallista o con
tipo de medalla inválido, que van a la tabla de cuarentena.

| Modelo | Descripción |
|---|---|
| `bronze_medalists_raw` | Fuente única para Silver y Gold. 1 fila por atleta × evento × medalla. Filtrada: `medalist_name` no nulo y `medal` ∈ {gold, silver, bronze}. |
| `bronze_medalists_rejected` | Cuarentena de filas rechazadas: `medalist_name` nulo o `medal` con valor inválido. El dataset de origen está limpio, por lo que actualmente contiene 0 filas. |

---

## Silver

**Base de datos:** `SILVER_DB_DEV` / `SILVER_DB_PRO`

Capa de normalización, tipado y limpieza. 9 tablas relacionadas mediante FKs con integridad
referencial completa. Los registros comodín (`'N/A'`) garantizan que no existan huérfanos
en ninguna FK, permitiendo JOINs seguros sin pérdida de filas.

| Modelo | Filas aprox. | Descripción |
|---|---|---|
| `silver_medalla` | 2 202 | **Tabla de hechos.** 1 fila por medalla. Surrogate key MD5. FK a atleta, delegación, país y evento. `wikidata_id_pais` usa COALESCE a `'N/A'` para refugiados y neutrales AIN. |
| `silver_atleta` | 1 949 | Atletas únicos deduplicados por `wikidata_id_atleta` (QUALIFY: prefiere la fila con fecha de nacimiento conocida). |
| `silver_pais` | 91 | Países únicos + 1 registro comodín `'N/A'` / "País Desconocido". Usar `es_pais_conocido = TRUE` para excluirlo en rankings. |
| `silver_delegacion` | ~91 | Delegaciones olímpicas. `wikidata_id_pais` puede ser NULL para delegaciones sin país en la fuente (ver warns). |
| `silver_lugar` | ~1 520 | Lugares de nacimiento únicos. Incluye coordenadas y NUTS3. `nombre` puede ser NULL cuando Wikidata carece del topónimo (ver warns). |
| `silver_region_nuts` | ~640 | Jerarquía NUTS europea auto-referencial (niveles 0=país, 1=gran región, 2=subregión, 3=unidad local). Solo cubre atletas con nacimiento en Europa. |
| `silver_evento` | 325 | Eventos olímpicos únicos. Evento Q128645552 con disciplina asignada manualmente. |
| `silver_disciplina` | ~47 | Disciplinas (agrupación de eventos). Incluye registro comodín `'N/A'`. |
| `silver_deporte` | ~32 | Deportes olímpicos únicos. Incluye registro comodín `'N/A'`. |

### Advertencias de calidad conocidas (severity: warn)

Estos dos tests fallan en cada build pero **no interrumpen el pipeline**. Los datos aguas
abajo (Gold) absorben los NULLs resultantes sin pérdida de filas.

| Test | Modelo | Columna | Causa raíz | Filas afectadas |
|---|---|---|---|---|
| `not_null_silver_lugar_nombre` | `silver_lugar` | `nombre` | Lugares con `wikidata_id` válido pero sin topónimo registrado en Wikidata. | Pocas (<10 lugares únicos) |
| `not_null_silver_delegacion_wikidata_id_pais` | `silver_delegacion` | `wikidata_id_pais` | Delegaciones del Equipo Olímpico de Refugiados y neutrales AIN sin país asignado. | 1–2 delegaciones |

---

## Gold

**Base de datos:** `GOLD_DB_DEV` / `GOLD_DB_PRO`

Modelo dimensional desnormalizado para consumo directo en herramientas BI. Todas las
dimensiones están resueltas en los modelos: no se necesitan JOINs adicionales para
construir un dashboard.

| Modelo | Filas | Descripción |
|---|---|---|
| `fact_medalla` | 2 202 | **Fact table principal.** 1 fila por medalla con IDs de todas las dimensiones + nombre de evento, disciplina y deporte desnormalizados. NUTS completo (niveles 0–3) para atletas europeos. |
| `dim_pais` | 91 | Países con métricas de medallas pre-agregadas (total, oro, plata, bronce). |
| `dim_atleta` | 1 949 | Atletas con lugar de nacimiento, coordenadas y NUTS3 desnormalizados. |
| `dim_evento` | 325 | Eventos con disciplina y deporte aplanados en una sola fila. |
| `dim_nuts` | ~445 | Jerarquía NUTS3 → NUTS0 desnormalizada. Solo regiones con atletas europeos. |

---

## Notas de calidad de datos

- **Atletas neutrales / refugiados**: acreditados al país `'N/A'` ("País Desconocido"). Filtrar con `es_pais_conocido = TRUE` en `dim_pais` para excluirlos de rankings nacionales.
- **Cobertura NUTS**: solo atletas con lugar de nacimiento en Europa tienen datos NUTS (~44% del dataset). El resto tiene `id_nuts3 = NULL` en `fact_medalla` y `dim_atleta`.
- **17 atletas sin fecha de nacimiento**: `fecha_nacimiento = NULL` en `silver_atleta` y `dim_atleta`.
- **93 atletas sin lugar de nacimiento**: `wikidata_id_lugar = NULL` en `silver_atleta` → `lugar_nacimiento = NULL` en `dim_atleta` y `fact_medalla`.
- **Artistic swimming Team** (Q128645552): disciplina asignada manualmente a Q109317225 por campo vacío en la fuente Wikidata.

{% enddocs %}
