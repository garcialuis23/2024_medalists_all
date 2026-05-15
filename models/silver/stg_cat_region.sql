{{ config(materialized='table') }}

with regions_pais as (
    select distinct trim(region) as region
    from {{ ref('bronze_country_stats') }}
    where region is not null
),

regions_mision as (
    select distinct trim(operation_region) as region
    from {{ ref('bronze_operations_missions') }}
    where operation_region is not null
),

todas as (
    select region from regions_pais
    union
    select region from regions_mision
)

select
    region,
    case
        when region in ('Northern Europe', 'Western Europe') then 'Europa Occidental/Norte'
        when region = 'Southern Europe'                      then 'Europa Meridional'
        when region in ('Eastern Europe', 'Central Europe')  then 'Europa Oriental/Central'
        when region = 'North America'                        then 'América del Norte'
        when region in ('Middle East', 'Central Asia',
                        'South Asia', 'East Africa',
                        'North Africa', 'West Africa',
                        'Southeast Asia', 'Caribbean',
                        'Eastern Mediterranean')             then 'Zona Operacional'
        else 'Otra'
    end                                                      as zona_geografica,
    case when region in ('Eastern Europe', 'Central Europe')
         then true else false end                            as es_flanco_este,
    case when region = 'North America'
         then true else false end                            as es_norte_america
from todas
where region is not null
