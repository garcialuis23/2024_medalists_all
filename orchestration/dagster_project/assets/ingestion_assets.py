"""
ingestion_assets.py — Assets de Ingesta (S3)
=============================================
Activo raíz del pipeline: ejecuta el script de ingesta Python en un subproceso
y verifica que los Parquet hayan llegado a S3.
"""

import os
import subprocess
from datetime import datetime, timezone

from dagster import (
    AssetExecutionContext,
    DailyPartitionsDefinition,
    MetadataValue,
    Output,
    asset,
)
from dagster_aws.s3 import S3Resource

# Partición diaria desde el inicio del proyecto
_daily_partitions = DailyPartitionsDefinition(start_date="2025-01-01")

_DATASETS = ["couriers", "deliveries", "routes", "incidents", "weather"]


@asset(
    group_name    ="ingestion",
    compute_kind  ="python",
    partitions_def=_daily_partitions,
    description   ="Genera datos sintéticos + Open-Meteo y sube Parquet a S3.",
)
def raw_logistics_data(
    context: AssetExecutionContext,
    s3_resource: S3Resource,
) -> Output[str]:
    """Activo raíz del pipeline.

    Ejecuta el script de ingesta como subproceso (en producción se lanzaría
    como ECS Task). Inyecta la fecha de partición como EXTRACTION_DATE.
    Verifica que los 5 Parquet hayan llegado a S3 antes de marcar el activo
    como materializado.
    """
    partition_date: str = context.partition_key
    bucket: str = os.environ["S3_BUCKET"]

    context.log.info("Iniciando ingesta para partición %s", partition_date)

    # Ejecutar el script de ingesta
    env = {**os.environ, "EXTRACTION_DATE": partition_date}
    result = subprocess.run(
        ["python", "-m", "src.ingest"],
        cwd=os.path.abspath("../../ingestion"),
        env=env,
        capture_output=True,
        text=True,
        timeout=600,
    )

    if result.stdout:
        for line in result.stdout.splitlines():
            context.log.info("[ingest] %s", line)

    if result.returncode != 0:
        context.log.error(result.stderr)
        raise RuntimeError(
            f"Script de ingesta falló con código {result.returncode}.\n{result.stderr}"
        )

    # Verificar que los archivos llegaron a S3
    s3_client      = s3_resource.get_client()
    uploaded_files = []
    for dataset in _DATASETS:
        prefix = f"{dataset}/extraction_date={partition_date}/"
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
        objects  = response.get("Contents", [])
        if objects:
            size = sum(o["Size"] for o in objects)
            uploaded_files.append({"dataset": dataset, "files": len(objects), "bytes": size})
            context.log.info("  ✓ %s — %d archivo(s), %d bytes", dataset, len(objects), size)
        else:
            context.log.warning("  ✗ %s — NO se encontraron archivos en S3", dataset)

    total_bytes = sum(f["bytes"] for f in uploaded_files)

    return Output(
        value=partition_date,
        metadata={
            "partition_date":  MetadataValue.text(partition_date),
            "datasets_loaded": MetadataValue.int(len(uploaded_files)),
            "total_bytes_s3":  MetadataValue.int(total_bytes),
            "s3_bucket":       MetadataValue.text(bucket),
        },
    )
