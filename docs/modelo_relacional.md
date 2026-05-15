# Modelo Relacional — NATO Data

```mermaid
erDiagram
    PAIS_ESTADISTICAS {
        varchar record_id PK
        varchar codigo_iso "Clave natural"
        varchar pais
        varchar anio "Año del registro"
        varchar region
        varchar pib_bn_usd
        varchar presupuesto_defensa_bn
        varchar personal_activo
        varchar personal_total
        timestamp _loaded_at
    }

    INVENTARIO_EQUIPAMIENTO {
        varchar record_id PK
        varchar codigo_iso FK
        varchar pais FK
        varchar tipo_equipamiento
        varchar categoria_equipo
        varchar dominio "Air/Land/Sea/Support"
        varchar cantidad_unidades
        varchar valor_total_m_usd
        varchar pct_combat_ready
        timestamp _loaded_at
    }

    OPERACIONES_MISIONES {
        varchar record_id PK
        varchar pais_lider FK
        varchar codigo_iso_lider FK
        varchar nombre_mision
        varchar tipo_mision
        varchar region_operacion
        varchar nivel_amenaza
        varchar anio_inicio
        varchar tropas_desplegadas
        varchar coste_mision_m_usd
        timestamp _loaded_at
    }

    PARTICIPANTES_MISIONES {
        varchar participant_id PK
        varchar mission_record_id FK
        varchar codigo_iso FK
        varchar pais FK
        varchar rol_participacion
        varchar tropas_contribuidas
        varchar pct_contribucion
        timestamp _loaded_at
    }

    PAIS_ESTADISTICAS         ||--o{ INVENTARIO_EQUIPAMIENTO  : "tiene equipamiento"
    PAIS_ESTADISTICAS         ||--o{ OPERACIONES_MISIONES     : "lidera misiones"
    PAIS_ESTADISTICAS         ||--o{ PARTICIPANTES_MISIONES   : "participa en misiones"
    OPERACIONES_MISIONES      ||--o{ PARTICIPANTES_MISIONES   : "tiene participantes"
```

## Relaciones

| Relación | Tipo | Descripción |
|---|---|---|
| `PAIS_ESTADISTICAS` → `INVENTARIO_EQUIPAMIENTO` | 1:N | Un país tiene múltiples registros de equipamiento |
| `PAIS_ESTADISTICAS` → `OPERACIONES_MISIONES` | 1:N | Un país puede liderar múltiples misiones |
| `PAIS_ESTADISTICAS` → `PARTICIPANTES_MISIONES` | 1:N | Un país puede participar en múltiples misiones |
| `OPERACIONES_MISIONES` → `PARTICIPANTES_MISIONES` | 1:N | Una misión tiene múltiples países participantes |

## Notas
- Todos los campos son `VARCHAR` en Bronze (capa de aterrizaje sin casteo)
- Los tipos se castean en Silver (`stg_nato__*`)
- La clave natural de país es `codigo_iso` — `record_id` no garantiza unicidad en todos los casos
