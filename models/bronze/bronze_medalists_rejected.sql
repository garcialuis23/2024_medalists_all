{{ config(materialized='table', database=("BRONZE_DB_PRO" if target.name == "pro" else "BRONZE_DB_DEV")) }}

-- Hard errors: medalist_name NULL o medal inválido
select
    *,
    'error'                                                               as severity,
    CASE
        WHEN medalist_name IS NULL AND (medal IS NULL OR medal NOT IN ('gold', 'silver', 'bronze'))
            THEN 'medalist_name es NULL | medal inválido: ' || COALESCE(medal, 'NULL')
        WHEN medalist_name IS NULL
            THEN 'medalist_name es NULL'
        ELSE
            'medal inválido: ' || COALESCE(medal, 'NULL')
    END                                                                   as rejection_reason

from {{ source('bronze', 'MEDALISTS_2024') }}
where
    medalist_name is null
    or medal is null
    or medal not in ('gold', 'silver', 'bronze')

union all

-- Warnings: registros válidos con problemas de calidad que generan warn en Silver
select
    *,
    'warn'                                                                as severity,
    ARRAY_TO_STRING(
        ARRAY_CONSTRUCT_COMPACT(
            IFF(
                place_of_birth_wikidata_id IS NOT NULL
                AND place_of_birth_wikidata_id != 'NA'
                AND (place_of_birth IS NULL OR place_of_birth = 'NA'),
                'lugar sin nombre → not_null_silver_lugar_nombre',
                NULL
            ),
            IFF(
                delegation_wikidata_id IS NOT NULL
                AND delegation_wikidata_id != 'NA'
                AND (country_medal_wikidata_id IS NULL OR country_medal_wikidata_id = 'NA'),
                'delegación sin país → not_null_silver_delegacion_wikidata_id_pais',
                NULL
            )
        ),
        ' | '
    )                                                                     as rejection_reason

from {{ ref('bronze_medalists_raw') }}
where
    (
        place_of_birth_wikidata_id IS NOT NULL
        AND place_of_birth_wikidata_id != 'NA'
        AND (place_of_birth IS NULL OR place_of_birth = 'NA')
    )
    or (
        delegation_wikidata_id IS NOT NULL
        AND delegation_wikidata_id != 'NA'
        AND (country_medal_wikidata_id IS NULL OR country_medal_wikidata_id = 'NA')
    )
