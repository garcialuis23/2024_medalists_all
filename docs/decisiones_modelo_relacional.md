# Decisiones de Diseño — Modelo Relacional Silver Layer

> **Versión del modelo**: v10  
> **Capa**: Silver (Snowflake / dbt)  
> **Tablas**: 13 (5 catálogos + 2 dimensiones SCD-2 + 2 dimensiones estables + 4 hechos/series temporales)

---

## Índice

1. [Filosofía general](#1-filosofía-general)
2. [Normalización: 3NF y ruptura de transitivas](#2-normalización-3nf-y-ruptura-de-transitivas)
3. [Patrón SCD-2: cuándo sí y cuándo no](#3-patrón-scd-2-cuándo-sí-y-cuándo-no)
4. [Surrogate keys en tablas SCD-2](#4-surrogate-keys-en-tablas-scd-2)
5. [FK a clave natural vs FK a surrogate key](#5-fk-a-clave-natural-vs-fk-a-surrogate-key)
6. [Catálogos: qué se modeló y qué se dejó como varchar](#6-catálogos-qué-se-modeló-y-qué-se-dejó-como-varchar)
7. [Correcciones de tipo originadas en los datos fuente](#7-correcciones-de-tipo-originadas-en-los-datos-fuente)
8. [PK compuesta de 5 columnas en participacion_mision](#8-pk-compuesta-de-5-columnas-en-participacion_mision)
9. [Campos calculados excluidos de Silver](#9-campos-calculados-excluidos-de-silver)
10. [Nueva tabla despliegue_equipamiento](#10-nueva-tabla-despliegue_equipamiento)
11. [Tabla cat_pais_origen: estados extintos y origen multinacional](#11-tabla-cat_pais_origen-estados-extintos-y-origen-multinacional)
12. [Resumen de decisiones en una tabla](#12-resumen-de-decisiones-en-una-tabla)

---

## 1. Filosofía general

Silver es la **capa de confianza**: datos tipados, limpios, deduplicados y normalizados. Tres principios guían todas las decisiones del modelo:

- **Representar fielmente la realidad**, incluyendo su complejidad temporal (cambios de gobierno, traslados de mando, renombres geopolíticos).
- **No precalcular nada** que pueda derivarse en Gold. Silver almacena hechos; Gold los interpreta.
- **Trazabilidad completa**: cada fila conserva su clave natural de negocio junto a la surrogate key, para auditoría y debugging del ETL.

---

## 2. Normalización: 3NF y ruptura de transitivas

El modelo está en **Tercera Forma Normal (3NF)**. Se identificaron dos dependencias transitivas que se materializaron como catálogos propios:

### 2.1 `ubicacion_operacion → region`

Sin el catálogo `cat_ubicacion_operacion`, la tabla `mision` contendría la región derivada de la ubicación. Eso crea redundancia y obliga a actualizar muchas filas si la región cambia.

```
mision.ubicacion_operacion
    └──▶ cat_ubicacion_operacion.region
              └──▶ cat_region.zona_geografica
```

### 2.2 `tipo_equipamiento.categoria → dominio`

Un tipo de equipamiento (ej. *Fighter Aircraft*) pertenece a una categoría (*Air Force*) que a su vez pertenece a un dominio (*Air*). Sin ruptura de esta transitiva, el dominio quedaría duplicado en cada fila de `tipo_equipamiento`.

```
tipo_equipamiento.categoria_equipamiento
    └──▶ cat_categoria_equipamiento.dominio
              └──▶ cat_dominio_equipamiento.descripcion
```

**Beneficio**: cambiar el dominio de una categoría requiere actualizar una sola fila del catálogo, no miles de registros de inventario.

---

## 3. Patrón SCD-2: cuándo sí y cuándo no

Se aplicó **SCD Tipo 2** de forma selectiva, solo donde la historia temporal tiene valor analítico real.

### 3.1 Tablas con SCD-2

| Tabla | Atributos que cambian | Justificación |
|---|---|---|
| `pais` | `pais`, `capital`, `tipo_gobierno`, `rol_alianza`, `tiene_comparticion_nuclear` | Cambios geopolíticos reales: Türkiye (2022), traslados de capital, rotación de roles en la alianza |
| `mision` | `codigo_iso_lider`, `fase_mision`, `estado_mision`, `bajas`, `coste_mision_m_usd`, `pct_apoyo_publico` | Una misión puede cambiar de líder (ISAF: ONU → OTAN), de fase y acumular bajas/costes a lo largo del tiempo |
| `inventario_equipamiento` | `estado_operacional`, `condicion`, `pct_combat_ready` | Un lote de equipamiento pasa de *Operational* a *Maintenance*, se actualiza su condición y disponibilidad |
| `participacion_mision` | `tropas_contribuidas`, `activos_aereos_contribuidos`, `activos_navales_contribuidos` | Los países ajustan su contribución durante el curso de una operación |

### 3.2 Tablas sin SCD-2 (sobrescritura directa)

| Tabla | Justificación |
|---|---|
| `tipo_equipamiento` | Dimensión estable. Los atributos `es_estandar_otan` y `es_interoperable` cambian tan raramente que no justifican overhead de versionado |
| `cat_*` (catálogos) | Son listas de referencia inmutables o casi inmutables. La historia de un cambio en un catálogo no aporta valor analítico |

### 3.3 Serie temporal pura: `estadisticas_pais`

`estadisticas_pais` **no necesita SCD-2** porque cada fila ya es una versión: el grano es `(codigo_iso, fecha)` — un año por país. Cada año ES una snapshot distinta por diseño.

---

## 4. Surrogate keys en tablas SCD-2

### El problema con las claves naturales como PK

En la versión anterior (v9), las tablas `pais` y `mision` usaban una PK compuesta por la clave natural + `fecha_inicio_validez`:

```sql
PRIMARY KEY (codigo_iso, fecha_inicio_validez)
```

Esto es correcto para identificar filas de forma única, pero crea un **problema en las FKs**: las tablas de hechos que referencian a `pais` o `mision` necesitarían incluir `fecha_inicio_validez` en la FK para apuntar a una versión concreta — o bien no apuntar a ninguna versión específica y resolver el join temporalmente en Gold.

### La solución: surrogate key por versión

Se añadió una surrogate key autoincremental como PK en cada tabla SCD-2:

```sql
-- pais
pais_sk    INTEGER  [pk, increment]  -- identifica cada versión histórica

-- mision
mision_sk  INTEGER  [pk, increment]  -- ídem
```

La clave natural pasa a tener un **índice UNIQUE** (no PK):

```sql
UNIQUE (codigo_iso, fecha_inicio_validez)  -- garantiza integridad sin ser PK
```

### Ventaja operativa

Las tablas de hechos referencian directamente la `pais_sk` activa en el momento de carga:

```sql
-- Inventario: FK a la versión del país activa cuando se cargó el dato
pais_sk  INTEGER  [ref: > pais.pais_sk]
```

Esto elimina los joins temporales complejos en las consultas de Gold. El ETL Silver resuelve el cruce temporal **una sola vez** al cargar, no en cada consulta.

---

## 5. FK a clave natural vs FK a surrogate key

Se adoptó un patrón **dual** en todas las tablas que referencian dimensiones SCD-2:

| Columna | Tipo | Propósito |
|---|---|---|
| `codigo_iso` | Clave natural (varchar) | Auditoría, debugging ETL, lectura humana |
| `pais_sk` | Surrogate key (integer, FK) | Join eficiente a la versión específica del país |

```sql
-- Ejemplo en inventario_equipamiento
codigo_iso  VARCHAR   -- "DEU" — legible, para auditoría
pais_sk     INTEGER   -- 42   — FK a la versión de Alemania activa en 2023
```

**Por qué conservar la clave natural**: si la surrogate key se recalcula o la dimensión se recarga, el `codigo_iso` permite reidentificar el registro sin depender de un número autogenerado.

La misma lógica aplica a `mision_sk` / `id_mision` en `participacion_mision` y `despliegue_equipamiento`.

---

## 6. Catálogos: qué se modeló y qué se dejó como varchar

### Se modelaron como tabla propia

Aquellos valores que tienen **jerarquía** (requieren join para navegar niveles) o **atributos adicionales** con valor analítico:

| Catálogo | Razón |
|---|---|
| `cat_region` | Contiene `zona_geografica` — agrupa regiones en áreas geopolíticas más amplias |
| `cat_ubicacion_operacion` | Rompe la transitiva con `cat_region` |
| `cat_dominio_equipamiento` | Nivel padre de la jerarquía Air/Land/Sea/Support |
| `cat_categoria_equipamiento` | Rompe la transitiva con `cat_dominio_equipamiento` |
| `cat_pais_origen` | Requiere `fecha_inicio_estado` / `fecha_fin_estado` para validar anomalías de equipamiento de estados extintos |

### Se dejaron como varchar

Atributos con valores enumerados simples, sin jerarquía ni atributos extra:

- `tipo_mision` (Collective Defence, Crisis Management…)
- `fase_mision`, `estado_mision`, `resultado_mision`
- `nivel_amenaza`, `clasificacion`, `cobertura_mediatica`
- `rol_participacion`, `estado_operacional`, `condicion`

Estas listas se documentan en el modelo mediante `note:` y se validan en dbt con tests `accepted_values`.

---

## 7. Correcciones de tipo originadas en los datos fuente

Al revisar los CSVs antes de finalizar el modelo se detectaron tres columnas cuyo tipo estaba mal definido:

### 7.1 `mision.tipo_liderazgo` (antes: `es_liderada_otan boolean`)

El CSV fuente (`NATO_3_Operations_Missions.csv`) contiene los valores:

```
"Yes" | "No" | "Joint UN-NATO"
```

`"Joint UN-NATO"` no cabe en un booleano. La columna se renombró a `tipo_liderazgo varchar` con valores normalizados: `NATO`, `Joint UN-NATO`, `Non-NATO`.

### 7.2 `tipo_equipamiento.es_estandar_otan` (antes: boolean)

El CSV fuente (`NATO_2_Equipment_Inventory.csv`) contiene:

```
"Yes" | "No" | "Partial"
```

`"Partial"` representa equipamiento que cumple parcialmente los estándares OTAN. Se cambió a `varchar`. El ETL normaliza a: `Yes`, `No`, `Partial`.

### 7.3 `cat_pais_origen` — valores no-ISO en `Country_of_Origin`

El CSV fuente contiene `"Multi-National"` y `"UK"` (en lugar de `"GBR"`). La tabla catálogo lo contempla:

- `"UK"` → se normaliza a `"GBR"` en el ETL (transformación en Bronze → Silver)
- `"Multi-National"` → se registra con código convencional `"MNA"` en el catálogo

---

## 8. PK compuesta de 5 columnas en `participacion_mision`

La clave única de `participacion_mision` tiene cinco componentes:

```
(id_mision, codigo_iso, rol_participacion, fecha_inicio_participacion, fecha_inicio_validez)
```

Cada componente es necesario:

| Componente | Por qué no puede eliminarse |
|---|---|
| `id_mision` | Un país puede participar en múltiples misiones |
| `codigo_iso` | Una misión tiene múltiples países participantes |
| `rol_participacion` | Un mismo país puede tener **roles simultáneos** en una misión (ej. Lead Nation + Naval) |
| `fecha_inicio_participacion` | Soporta **despliegues intermitentes**: un país puede retirarse y reincorporarse |
| `fecha_inicio_validez` | Componente SCD-2: distingue versiones del mismo período de despliegue |

La PK es compleja, pero refleja la complejidad real del dominio. Alternativa rechazada: usar una surrogate key y relajar la unicidad — se descartó porque enmascaría duplicados en el ETL y complicaría los tests de calidad de datos.

---

## 9. Campos calculados excluidos de Silver

Silver almacena **únicamente hechos fuente o datos transformados directamente**. Los campos derivados que aparecían en los CSVs se excluyen o marcan para recálculo, ya que contienen errores (~6-8%):

| Campo CSV | Motivo de exclusión | Cálculo correcto en Gold |
|---|---|---|
| `Duration_Years` | ~8% de filas con valor incorrecto | `DATEDIFF(year, fecha_inicio, fecha_fin)` |
| `Equipment_Age_Years` | ~6% incorrecto | `YEAR(CURRENT_DATE) - YEAR(fecha_adquisicion)` |
| `Total_Value_M_USD` | ~7% incorrecto | `cantidad_unidades * coste_unitario_m_usd` |
| `Cost_Per_Soldier_USD` | ~8% incorrecto | `coste_mision_m_usd * 1_000_000 / tropas_contribuidas` |
| `GDP_Per_Capita_USD` | Derivado | `pib_bn_usd * 1_000_000_000 / (poblacion_millones * 1_000_000)` |

Estos campos se recalculan en la capa Gold desde sus fuentes atómicas, garantizando consistencia.

Los campos acumulativos que **sí viven en Silver** porque son datos fuente y no derivados:

- `bajas` (acumulativo de reportes)
- `pct_combat_ready` (dato fuente de inventario, no derivado)
- `rango_contribucion_otan` (ranking oficial publicado por OTAN)

---

## 10. Nueva tabla `despliegue_equipamiento`

### El gap analítico

Sin esta tabla no es posible responder directamente:

> *"¿Qué tipo de equipamiento desplegó Alemania en la operación X?"*

La ruta indirecta era: `participacion_mision.codigo_iso` → `inventario_equipamiento.codigo_iso` (cruce temporal). Funciona para estimaciones, pero no hay trazabilidad directa misión ↔ equipo.

### Limitación de los datos fuente

El CSV `NATO_4_Mission_Participants.csv` solo contiene conteos agregados:

```
Air_Assets_Contributed   = 34
Naval_Assets_Contributed = 8
```

No hay detalle del tipo concreto de equipamiento desplegado. Por eso `despliegue_equipamiento` es un dato **inferido/aproximado** en el ETL: se cruza el conteo de activos aéreos/navales de CSV4 con el inventario de CSV2 filtrado por `pais_sk + dominio` para asignar el tipo más probable.

### Diseño de la tabla

```
despliegue_equipamiento
├── mision_sk       → mision.mision_sk
├── pais_sk         → pais.pais_sk
├── tipo_equipamiento → tipo_equipamiento.tipo_equipamiento
├── cantidad_desplegada
├── fecha_inicio / fecha_fin
└── UNIQUE (mision_sk, pais_sk, tipo_equipamiento)
```

La unicidad se garantiza a nivel `(misión, país, tipo)`: un país no puede desplegar dos registros distintos del mismo tipo de equipo en la misma misión en el mismo periodo.

---

## 11. Tabla `cat_pais_origen`: estados extintos y origen multinacional

Esta tabla resuelve un problema de integridad referencial que ningún estándar ISO cubre completamente: el inventario militar incluye equipamiento fabricado en **países que ya no existen**.

### Casos contemplados

| Escenario | Ejemplo | Tratamiento |
|---|---|---|
| Estado extinto | Equipo soviético (`SUN`) | `fecha_fin_estado` != NULL; ETL puede detectar anomalías cruzando con `fecha_adquisicion` |
| País renombrado | Yugoslavia (`YUG`) | Mismo tratamiento que estados extintos |
| Origen multinacional | Consorcio europeo | Código convencional `MNA` en el catálogo |
| Alias no-ISO | `"UK"` en lugar de `"GBR"` | Normalizado a ISO-3166 en ETL Bronze → Silver |

### Validación en ETL, no como constraint

La detección de anomalías (ej. equipamiento "fabricado en la URSS" con `fecha_adquisicion` = 2019) **no se implementa como FK constraint** porque requiere lógica de rango de fechas que los motores SQL no soportan de forma nativa como restricción declarativa. Se implementa como test dbt en la capa Silver.

---

## 12. Resumen de decisiones en una tabla

| Decisión | Alternativa considerada | Por qué se eligió esta |
|---|---|---|
| SCD-2 en `pais` y `mision` | SCD-1 (sobrescritura) | La historia geopolítica y operacional tiene valor analítico directo |
| SCD-2 **no** en `tipo_equipamiento` | SCD-2 completo | Cambios rarísimos; el overhead no justifica la complejidad |
| Surrogate key (`pais_sk`, `mision_sk`) | PK compuesta con clave natural | Joins sin resolución temporal en Gold; FK simple y eficiente |
| Conservar clave natural desnormalizada | Solo surrogate key | Trazabilidad ETL; independencia ante recargas de dimensión |
| `tipo_liderazgo varchar` | `es_liderada_otan boolean` | CSV fuente contiene `"Joint UN-NATO"` — no es binario |
| `es_estandar_otan varchar` | boolean | CSV fuente contiene `"Partial"` — no es binario |
| 3NF con catálogos de jerarquía | Desnormalizar en tabla principal | Reduce redundancia; cambio en un catálogo propaga sin UPDATE masivo |
| Campos calculados solo en Gold | Almacenar en Silver | Silver mantiene hechos puros; ~6-8% de errores en columnas derivadas del CSV |
| `despliegue_equipamiento` inferido | No modelar el link | Habilita consultas misión ↔ equipo; la nota documenta la aproximación |
| `cat_pais_origen` con `fecha_fin_estado` | Solo código y nombre | Permite detectar anomalías históricas en auditorías de inventario |
