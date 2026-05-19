{{ config(materialized='table', database=("BRONZE_DB_PRO" if target.name == "pro" else "BRONZE_DB_DEV")) }}

select
    *,
    CURRENT_TIMESTAMP() AS _loaded_at,
    ARRAY_TO_STRING(
        ARRAY_CONSTRUCT_COMPACT(
            CASE WHEN medalist_name IS NULL
                 THEN 'medalist_name es NULL' END,
            CASE WHEN medal NOT IN ('gold', 'silver', 'bronze')
                 THEN 'medal inválido: ' || COALESCE(medal, 'NULL') END
        ),
        ' | '
    ) AS rejection_reason

from {{ source('bronze', 'MEDALISTS_2024') }}
where
    medalist_name is null
    or medal not in ('gold', 'silver', 'bronze')
