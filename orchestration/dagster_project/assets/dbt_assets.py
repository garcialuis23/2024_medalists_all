"""
dbt_assets.py — Assets dbt para capas Silver y Gold
====================================================
Usa la integración dagster-dbt para envolver todos los modelos dbt
como Software-Defined Assets nativos de Dagster.
"""

import os

from dagster import AssetExecutionContext
from dagster_dbt import DbtCliResource, dbt_assets

# Ruta al manifest.json generado por `dbt compile` o `dbt parse`
_DBT_MANIFEST_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../../dbt/target/manifest.json")
)


@dbt_assets(manifest=_DBT_MANIFEST_PATH)
def logistics_dbt_assets(context: AssetExecutionContext, dbt_resource: DbtCliResource):
    """Ejecuta todos los modelos dbt del proyecto (Silver + Gold + Snapshots).

    dagster-dbt convierte automáticamente cada modelo dbt en un SDA nativo,
    respetando el linaje y las dependencias definidas en ref() y source().
    """
    yield from dbt_resource.cli(["build"], context=context).stream()
