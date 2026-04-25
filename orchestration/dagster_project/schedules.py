"""
schedules.py — Schedule diario del pipeline de logística
=========================================================
Lanza el pipeline completo (ingesta → Bronze → Silver → Gold) cada día
a las 02:00 UTC, una vez que los datos operativos del día anterior están listos.
"""

from dagster import (
    AssetSelection,
    DefaultScheduleStatus,
    define_asset_job,
    ScheduleDefinition,
)

# Job que materializa todos los assets del pipeline en orden
logistics_pipeline_job = define_asset_job(
    name           ="logistics_daily_pipeline",
    selection      =AssetSelection.all(),
    description    ="Pipeline completo: Ingesta S3 → Bronze → Silver (dbt) → Gold (dbt)",
    tags           ={"pipeline": "logistics", "env": "production"},
)

# Schedule: todos los días a las 02:00 UTC
daily_logistics_schedule = ScheduleDefinition(
    name            ="daily_logistics_at_0200_utc",
    job             =logistics_pipeline_job,
    cron_schedule   ="0 2 * * *",
    default_status  =DefaultScheduleStatus.RUNNING,
    execution_timezone="UTC",
)
