{% docs __overview__ %}

# 🏅 París 2024 — Medallistas Olímpicos

Proyecto dbt de modelado medallístico de los **Juegos Olímpicos de París 2024**.
Transforma datos crudos de Wikidata en un modelo dimensional listo para análisis y visualización.

---

## Arquitectura Medallion

```
BRONZE_DB  →  SILVER_DB  →  GOLD_DB
   ↓               ↓             ↓
Datos crudos   Normalizado   Dimensional
(VARCHAR)      (tipado)      (BI-ready)
```

### Bronze
Ingesta cruda desde el stage de Snowflake. Sin transformaciones: todos los valores como VARCHAR,
campos vacíos representados con la cadena `'NA'`.

- **`bronze_medalists_raw`** — 1 fila por atleta × evento × medalla. Fuente única para Silver y Gold.

### Silver
Capa de limpieza, tipado y normalización. 9 tablas relacionadas con integridad referencial completa.
Los registros comodín (`'N/A'`) garantizan que no existan huérfanos en ninguna FK.

| Tabla | Descripción |
|---|---|
| `silver_medal` | Tabla de hechos (2,202 medallas) |
| `silver_athlete` | 1,949 atletas únicos |
| `silver_country` | 90 países + registro "País Desconocido" |
| `silver_delegation` | Delegaciones olímpicas |
| `silver_event` | 325 eventos |
| `silver_discipline` | Disciplinas por deporte |
| `silver_sport` | Deportes olímpicos |
| `silver_place` | Lugares de nacimiento con coordenadas |
| `silver_nuts_region` | Jerarquía NUTS europea (niveles 0–3) |

### Gold
Modelo dimensional desnormalizado para consumo directo en BI. Wide fact table con todas
las dimensiones resueltas, sin necesidad de JOINs adicionales.

| Tabla | Filas | Descripción |
|---|---|---|
| `fact_medal` | 2,202 | Fact table principal con 29 columnas |
| `dim_athlete` | 1,949 | Atletas con lugar de nacimiento y coordenadas |
| `dim_country` | 90 | Países con métricas de medallas pre-agregadas |
| `dim_event` | 325 | Eventos con disciplina y deporte aplanados |
| `dim_nuts` | 445 | Jerarquía NUTS3 → NUTS0 desnormalizada |

---

## Notas de calidad

- **Atletas neutrales / refugiados** (Equipo Olímpico de Refugiados, AIN): acreditados al país `'N/A'` → "País Desconocido". Usar `is_known_country = TRUE` en `dim_country` para excluirlos de rankings.
- **Cobertura NUTS**: solo atletas europeos tienen datos geográficos NUTS (~44% del dataset).
- **Artistic swimming Team event** (Q128645552): disciplina asignada manualmente a Q109317225 por dato vacío en la fuente.

{% enddocs %}
