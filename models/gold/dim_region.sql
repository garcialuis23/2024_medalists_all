{{ config(materialized='table') }}

select
    region,
    case
        when region in ('Northern Europe', 'Western Europe') then 'Europa Occidental/Norte'
        when region in ('Southern Europe')                   then 'Europa Meridional'
        when region in ('Eastern Europe', 'Central Europe')  then 'Europa Oriental/Central'
        when region = 'North America'                        then 'América del Norte'
        else 'Otra'
    end                                                             as zona_geografica,
    case
        when region in ('Eastern Europe', 'Central Europe')
        then true else false
    end                                                             as es_flanco_este,
    case
        when region = 'North America'
        then true else false
    end                                                             as es_norte_america,
    count(distinct codigo_iso)                                      as total_paises
from (
    select distinct region, codigo_iso
    from {{ ref('stg_nato__country_stats') }}
    where region is not null
)
group by 1, 2, 3, 4
