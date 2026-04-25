"""
Dagster Project — Pipeline de Logística Última Milla España
============================================================
Punto de entrada principal del proyecto Dagster.
Define el objeto `Definitions` con todos los assets, recursos y schedules.
"""

from dagster import Definitions, load_assets_from_modules

from .assets import dbt_assets, ingestion_assets, snowflake_assets
from .resources.resources import build_resources
from .schedules import daily_logistics_schedule

# Cargar todos los Software-Defined Assets por módulo
_ingestion_assets  = load_assets_from_modules([ingestion_assets])
_snowflake_assets  = load_assets_from_modules([snowflake_assets])
_dbt_assets_list   = load_assets_from_modules([dbt_assets])

defs = Definitions(
    assets   = [*_ingestion_assets, *_snowflake_assets, *_dbt_assets_list],
    resources= build_resources(),
    schedules= [daily_logistics_schedule],
)
