"""
snowflake_assets.py — Assets de Carga Bronze (COPY INTO desde S3)
=================================================================
Un asset por tabla Bronze. Cada uno ejecuta el COPY INTO correspondiente
usando la fecha de partición para filtrar el prefijo S3 exacto.
"""

import os
from typing import Any

from dagster import (
    AssetExecutionContext,
    DailyPartitionsDefinition,
    MetadataValue,
    Output,
    asset,
)
from dagster_snowflake import SnowflakeResource

from .ingestion_assets import raw_logistics_data  # establece dependencia upstream

_daily_partitions = DailyPartitionsDefinition(start_date="2025-01-01")

# Plantilla COPY INTO parametrizada por dataset y fecha
_COPY_INTO_SQL = """
COPY INTO logistics_db.bronze.raw_{dataset} ({columns}, _extraction_date)
FROM (
    SELECT {select_cols}, '{extraction_date}'::DATE
    FROM @logistics_db.bronze.s3_raw_stage/{dataset}/extraction_date={extraction_date}/
)
FILE_FORMAT = (FORMAT_NAME = 'logistics_db.bronze.parquet_logistics_ff')
ON_ERROR    = CONTINUE
PURGE       = FALSE
"""

# Mapeo dataset → columnas y sus expresiones de selección Parquet
_DATASET_SCHEMA: dict[str, dict[str, list[str]]] = {
    "couriers": {
        "columns": [
            "courier_id", "first_name", "last_name", "email", "phone",
            "national_id", "license_number", "vehicle_type", "vehicle_plate",
            "zone_ccaa", "zone_province", "hire_date", "is_active", "salary_eur",
        ],
        "select": [
            "$1:courier_id::VARCHAR(36)", "$1:first_name::VARCHAR(100)",
            "$1:last_name::VARCHAR(200)", "$1:email::VARCHAR(200)",
            "$1:phone::VARCHAR(30)", "$1:national_id::VARCHAR(20)",
            "$1:license_number::VARCHAR(30)", "$1:vehicle_type::VARCHAR(50)",
            "$1:vehicle_plate::VARCHAR(15)", "$1:zone_ccaa::VARCHAR(100)",
            "$1:zone_province::VARCHAR(100)", "$1:hire_date::VARCHAR(20)",
            "$1:is_active::VARCHAR(10)", "$1:salary_eur::VARCHAR(20)",
        ],
    },
    "deliveries": {
        "columns": [
            "delivery_id", "courier_id", "package_id",
            "origin_city", "destination_city",
            "origin_lat", "origin_lon", "destination_lat", "destination_lon",
            "origin_ccaa", "destination_ccaa",
            "scheduled_date", "time_window",
            "actual_pickup_ts", "actual_delivery_ts",
            "status", "failure_reason",
            "weight_kg", "volume_cm3", "delivery_cost_eur", "distance_km",
            "priority", "vehicle_type",
        ],
        "select": [
            "$1:delivery_id::VARCHAR(36)", "$1:courier_id::VARCHAR(36)",
            "$1:package_id::VARCHAR(36)", "$1:origin_city::VARCHAR(100)",
            "$1:destination_city::VARCHAR(100)", "$1:origin_lat::VARCHAR(30)",
            "$1:origin_lon::VARCHAR(30)", "$1:destination_lat::VARCHAR(30)",
            "$1:destination_lon::VARCHAR(30)", "$1:origin_ccaa::VARCHAR(100)",
            "$1:destination_ccaa::VARCHAR(100)", "$1:scheduled_date::VARCHAR(20)",
            "$1:time_window::VARCHAR(30)", "$1:actual_pickup_ts::VARCHAR(40)",
            "$1:actual_delivery_ts::VARCHAR(40)", "$1:status::VARCHAR(50)",
            "$1:failure_reason::VARCHAR(200)", "$1:weight_kg::VARCHAR(20)",
            "$1:volume_cm3::VARCHAR(20)", "$1:delivery_cost_eur::VARCHAR(20)",
            "$1:distance_km::VARCHAR(20)", "$1:priority::VARCHAR(30)",
            "$1:vehicle_type::VARCHAR(50)",
        ],
    },
    "routes": {
        "columns": [
            "route_id", "courier_id", "route_date", "origin_city", "total_stops",
            "planned_distance_km", "actual_distance_km",
            "planned_duration_min", "actual_duration_min",
            "fuel_consumption_liters", "co2_emissions_kg",
            "start_ts", "end_ts",
        ],
        "select": [
            "$1:route_id::VARCHAR(36)", "$1:courier_id::VARCHAR(36)",
            "$1:route_date::VARCHAR(20)", "$1:origin_city::VARCHAR(100)",
            "$1:total_stops::VARCHAR(10)", "$1:planned_distance_km::VARCHAR(20)",
            "$1:actual_distance_km::VARCHAR(20)", "$1:planned_duration_min::VARCHAR(20)",
            "$1:actual_duration_min::VARCHAR(20)", "$1:fuel_consumption_liters::VARCHAR(20)",
            "$1:co2_emissions_kg::VARCHAR(20)", "$1:start_ts::VARCHAR(40)",
            "$1:end_ts::VARCHAR(40)",
        ],
    },
    "incidents": {
        "columns": [
            "incident_id", "delivery_id", "courier_id",
            "incident_ts", "incident_type", "description", "severity",
            "resolution_ts", "resolution_notes", "cost_impact_eur", "is_weather_related",
        ],
        "select": [
            "$1:incident_id::VARCHAR(36)", "$1:delivery_id::VARCHAR(36)",
            "$1:courier_id::VARCHAR(36)", "$1:incident_ts::VARCHAR(40)",
            "$1:incident_type::VARCHAR(100)", "$1:description::VARCHAR(2000)",
            "$1:severity::VARCHAR(20)", "$1:resolution_ts::VARCHAR(40)",
            "$1:resolution_notes::VARCHAR(2000)", "$1:cost_impact_eur::VARCHAR(20)",
            "$1:is_weather_related::VARCHAR(10)",
        ],
    },
    "weather": {
        "columns": [
            "city", "lat", "lon", "ccaa", "province", "forecast_ts",
            "temperature_2m_celsius", "precipitation_mm",
            "wind_speed_10m_kmh", "wind_gusts_10m_kmh",
            "cloud_cover_pct", "visibility_m", "weather_code",
        ],
        "select": [
            "$1:city::VARCHAR(100)", "$1:lat::VARCHAR(20)", "$1:lon::VARCHAR(20)",
            "$1:ccaa::VARCHAR(100)", "$1:province::VARCHAR(100)",
            "$1:forecast_ts::VARCHAR(40)", "$1:temperature_2m_celsius::VARCHAR(20)",
            "$1:precipitation_mm::VARCHAR(20)", "$1:wind_speed_10m_kmh::VARCHAR(20)",
            "$1:wind_gusts_10m_kmh::VARCHAR(20)", "$1:cloud_cover_pct::VARCHAR(20)",
            "$1:visibility_m::VARCHAR(20)", "$1:weather_code::VARCHAR(10)",
        ],
    },
}


def _make_bronze_asset(dataset_name: str):
    """Factory que genera un asset Bronze para un dataset concreto."""

    @asset(
        name         =f"bronze_{dataset_name}",
        group_name   ="bronze",
        compute_kind ="snowflake",
        partitions_def=_daily_partitions,
        deps         =[raw_logistics_data],
        description  =f"Carga Bronze: COPY INTO raw_{dataset_name} desde S3.",
    )
    def _bronze_asset(
        context: AssetExecutionContext,
        snowflake_resource: SnowflakeResource,
    ) -> Output[dict[str, Any]]:
        """Ejecuta el COPY INTO para la tabla Bronze correspondiente."""
        partition_date = context.partition_key
        schema         = _DATASET_SCHEMA[dataset_name]

        sql = _COPY_INTO_SQL.format(
            dataset        =dataset_name,
            columns        =", ".join(schema["columns"]),
            select_cols    =", ".join(schema["select"]),
            extraction_date=partition_date,
        )

        context.log.info("Ejecutando COPY INTO para %s (partición %s)...", dataset_name, partition_date)

        with snowflake_resource.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql)
            results = cursor.fetchall()
            # COPY INTO retorna: file, status, rows_parsed, rows_loaded, error_limit, errors_seen, ...
            rows_loaded = sum(int(r[3]) for r in results if r[3] is not None)
            errors_seen = sum(int(r[5]) for r in results if r[5] is not None)
            context.log.info(
                "COPY INTO %s: %d filas cargadas, %d errores",
                dataset_name, rows_loaded, errors_seen,
            )
            if errors_seen > 0:
                context.log.warning("Hay %d errores en la carga. Revisar COPY_HISTORY.", errors_seen)

        return Output(
            value={"dataset": dataset_name, "rows_loaded": rows_loaded},
            metadata={
                "partition_date": MetadataValue.text(partition_date),
                "rows_loaded":    MetadataValue.int(rows_loaded),
                "errors_seen":    MetadataValue.int(errors_seen),
                "table":          MetadataValue.text(f"logistics_db.bronze.raw_{dataset_name}"),
            },
        )

    return _bronze_asset


# Instanciar un asset Bronze por cada dataset
bronze_couriers   = _make_bronze_asset("couriers")
bronze_deliveries = _make_bronze_asset("deliveries")
bronze_routes     = _make_bronze_asset("routes")
bronze_incidents  = _make_bronze_asset("incidents")
bronze_weather    = _make_bronze_asset("weather")
