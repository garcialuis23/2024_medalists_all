{{ config(materialized='table') }}

/*
  DATO INFERIDO / APROXIMADO — No existe fuente directa en los CSV.
  Lógica de inferencia:
    · CSV4 provee Air_Assets_Contributed y Naval_Assets_Contributed por (misión, país).
    · CSV2 provee el inventario real por (país, tipo_equipamiento).
    · Para cada (misión, país) con activos aéreos se asigna el tipo de equipamiento
      del dominio 'Air' más numeroso en inventario de ese país.
    · Ídem para activos navales con dominio 'Sea'.
    · Un país puede generar máximo dos filas por misión (una aérea + una naval).
    · UNIQUE garantizada por (mision_sk, pais_sk, tipo_equipamiento).
*/

with participantes_activos as (
    select
        p.id_mision,
        p.mision_sk,
        p.codigo_iso,
        p.pais_sk,
        p.activos_aereos_contribuidos,
        p.activos_navales_contribuidos
    from {{ ref('stg_participacion_mision') }} p
    where p.es_registro_actual = true
),

-- Activos aéreos → tipo de equipamiento Air más numeroso del país
despliegue_aereo as (
    select
        pa.id_mision,
        pa.mision_sk,
        pa.codigo_iso,
        pa.pais_sk,
        i.tipo_equipamiento,
        pa.activos_aereos_contribuidos                      as cantidad_desplegada
    from participantes_activos pa
    join {{ ref('stg_inventario_equipamiento') }} i
        on  i.codigo_iso = pa.codigo_iso
        and i.es_registro_actual = true
    join {{ ref('stg_tipo_equipamiento') }} t
        on  t.tipo_equipamiento = i.tipo_equipamiento
    join {{ ref('stg_cat_categoria_equipamiento') }} c
        on  c.categoria_equipamiento = t.categoria_equipamiento
        and c.dominio = 'Air'
    where pa.activos_aereos_contribuidos > 0
      and i.cantidad_unidades > 0
    qualify row_number() over (
        partition by pa.id_mision, pa.codigo_iso
        order by i.cantidad_unidades desc nulls last
    ) = 1
),

-- Activos navales → tipo de equipamiento Sea más numeroso del país
despliegue_naval as (
    select
        pa.id_mision,
        pa.mision_sk,
        pa.codigo_iso,
        pa.pais_sk,
        i.tipo_equipamiento,
        pa.activos_navales_contribuidos                     as cantidad_desplegada
    from participantes_activos pa
    join {{ ref('stg_inventario_equipamiento') }} i
        on  i.codigo_iso = pa.codigo_iso
        and i.es_registro_actual = true
    join {{ ref('stg_tipo_equipamiento') }} t
        on  t.tipo_equipamiento = i.tipo_equipamiento
    join {{ ref('stg_cat_categoria_equipamiento') }} c
        on  c.categoria_equipamiento = t.categoria_equipamiento
        and c.dominio = 'Sea'
    where pa.activos_navales_contribuidos > 0
      and i.cantidad_unidades > 0
    qualify row_number() over (
        partition by pa.id_mision, pa.codigo_iso
        order by i.cantidad_unidades desc nulls last
    ) = 1
),

combined as (
    select * from despliegue_aereo
    union all
    select * from despliegue_naval
)

select
    row_number() over (
        order by id_mision, codigo_iso, tipo_equipamiento
    )                                                       as id_despliegue,
    mision_sk,
    pais_sk,
    id_mision,
    codigo_iso,
    tipo_equipamiento,
    cantidad_desplegada,
    null::date                                              as fecha_inicio,
    null::date                                              as fecha_fin,
    current_timestamp()                                     as cargado_en
from combined
