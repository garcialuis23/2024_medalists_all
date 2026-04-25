"""
resources.py — Recursos inyectables del pipeline de logística
=============================================================
Todos los recursos se configuran desde variables de entorno.
NUNCA se instancian recursos dentro del cuerpo de un asset.
"""

import os
from typing import Any

from dagster import EnvVar
from dagster_aws.s3 import S3Resource
from dagster_dbt import DbtCliResource
from dagster_snowflake import SnowflakeResource


def build_resources() -> dict[str, Any]:
    """Construye el diccionario de recursos para el objeto Definitions.

    Todos los valores sensibles se leen desde variables de entorno
    para garantizar que no haya credenciales en el código fuente.
    """
    return {
        # ── AWS S3 ───────────────────────────────────────────────────────────
        # En ECS: usa IAM Role — no es necesario proporcionar access keys.
        # En local: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY desde .env
        "s3_resource": S3Resource(
            region_name=os.getenv("AWS_REGION", "eu-west-1"),
        ),

        # ── Snowflake ────────────────────────────────────────────────────────
        "snowflake_resource": SnowflakeResource(
            account   =EnvVar("SNOWFLAKE_ACCOUNT"),
            user      =EnvVar("SNOWFLAKE_USER"),
            password  =EnvVar("SNOWFLAKE_PASSWORD"),
            role      =EnvVar("SNOWFLAKE_ROLE"),
            warehouse =EnvVar("SNOWFLAKE_WAREHOUSE"),
            database  ="logistics_db",
            schema    ="bronze",
        ),

        # ── dbt CLI ──────────────────────────────────────────────────────────
        "dbt_resource": DbtCliResource(
            project_dir  =os.path.abspath("../dbt"),
            profiles_dir =os.path.abspath("../dbt"),
        ),
    }
