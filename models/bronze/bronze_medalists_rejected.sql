{{ config(materialized='table', database=("BRONZE_DB_PRO" if target.name == "pro" else "BRONZE_DB_DEV")) }}

select
    *,
    CURRENT_TIMESTAMP() AS _loaded_at,
    CASE
        WHEN medalist_name IS NULL AND (medal IS NULL OR medal NOT IN ('gold', 'silver', 'bronze'))
            THEN 'medalist_name es NULL | medal inválido: ' || COALESCE(medal, 'NULL')
        WHEN medalist_name IS NULL
            THEN 'medalist_name es NULL'
        ELSE
            'medal inválido: ' || COALESCE(medal, 'NULL')
    END AS rejection_reason

from {{ source('bronze', 'MEDALISTS_2024') }}
where
    medalist_name is null
    or medal is null
    or medal not in ('gold', 'silver', 'bronze')
