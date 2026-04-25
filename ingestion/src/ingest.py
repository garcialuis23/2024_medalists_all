#!/usr/bin/env python3
"""
ingest.py — Ingesta de Datos de Logística de Última Milla en España
====================================================================
Genera datos sintéticos complejos con Faker y consume la API Open-Meteo.
Exporta todos los datasets en formato Parquet comprimido con Snappy
y los sube a AWS S3 particionados por extraction_date.

Diseñado para ejecutarse como un job en un contenedor Docker/ECS.

Variables de entorno REQUERIDAS:
    S3_BUCKET             — Nombre del bucket S3 destino (ej. "logistics-raw-zone")

Variables de entorno OPCIONALES:
    AWS_REGION            — Región AWS (default: eu-west-1)
    EXTRACTION_DATE       — Fecha ISO YYYY-MM-DD (default: hoy UTC)
    N_COURIERS            — Mensajeros a generar (default: 200)
    N_DELIVERIES          — Entregas a generar (default: 5000)
    N_ROUTES              — Rutas a generar (default: 1500)
    INCIDENTS_RATE        — Fracción de entregas con incidencia (default: 0.12)
    OPEN_METEO_DAYS       — Días de forecast a solicitar a Open-Meteo (default: 1)
    LOG_LEVEL             — Nivel de log (default: INFO)
"""

from __future__ import annotations

import io
import logging
import os
import random
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import boto3
import httpx
import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from botocore.exceptions import BotoCoreError, ClientError
from faker import Faker
from tenacity import (
    RetryError,
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

# ──────────────────────────────────────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────────────────────────────────────
_log_level = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=_log_level,
    format="%(asctime)s [%(levelname)-8s] %(name)s — %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%SZ",
)
logger = logging.getLogger("logistics.ingest")


# ──────────────────────────────────────────────────────────────────────────────
# Faker + semillas de reproducibilidad
# ──────────────────────────────────────────────────────────────────────────────
fake = Faker("es_ES")
Faker.seed(42)
random.seed(42)
np.random.seed(42)


# ──────────────────────────────────────────────────────────────────────────────
# Configuración desde variables de entorno
# ──────────────────────────────────────────────────────────────────────────────
S3_BUCKET: str = os.environ["S3_BUCKET"]
AWS_REGION: str = os.getenv("AWS_REGION", "eu-west-1")
EXTRACTION_DATE: str = os.getenv(
    "EXTRACTION_DATE", datetime.now(timezone.utc).strftime("%Y-%m-%d")
)
N_COURIERS: int = int(os.getenv("N_COURIERS", "200"))
N_DELIVERIES: int = int(os.getenv("N_DELIVERIES", "5000"))
N_ROUTES: int = int(os.getenv("N_ROUTES", "1500"))
INCIDENTS_RATE: float = float(os.getenv("INCIDENTS_RATE", "0.12"))
OPEN_METEO_DAYS: int = int(os.getenv("OPEN_METEO_DAYS", "1"))

# ──────────────────────────────────────────────────────────────────────────────
# Open-Meteo
# ──────────────────────────────────────────────────────────────────────────────
_OPEN_METEO_BASE_URL = "https://api.open-meteo.com/v1/forecast"
_OPEN_METEO_TIMEOUT = 30.0

# ──────────────────────────────────────────────────────────────────────────────
# Datos de referencia: ciudades españolas con coordenadas y CCAA
# ──────────────────────────────────────────────────────────────────────────────
SPANISH_CITIES: dict[str, dict[str, Any]] = {
    "Madrid":     {"lat": 40.4168, "lon": -3.7038, "ccaa": "Comunidad de Madrid",    "province": "Madrid"},
    "Barcelona":  {"lat": 41.3851, "lon":  2.1734, "ccaa": "Cataluña",               "province": "Barcelona"},
    "Valencia":   {"lat": 39.4699, "lon": -0.3763, "ccaa": "Comunidad Valenciana",   "province": "Valencia"},
    "Sevilla":    {"lat": 37.3891, "lon": -5.9845, "ccaa": "Andalucía",              "province": "Sevilla"},
    "Zaragoza":   {"lat": 41.6488, "lon": -0.8891, "ccaa": "Aragón",                 "province": "Zaragoza"},
    "Málaga":     {"lat": 36.7213, "lon": -4.4214, "ccaa": "Andalucía",              "province": "Málaga"},
    "Bilbao":     {"lat": 43.2630, "lon": -2.9350, "ccaa": "País Vasco",             "province": "Vizcaya"},
    "Murcia":     {"lat": 37.9922, "lon": -1.1307, "ccaa": "Región de Murcia",       "province": "Murcia"},
    "Palma":      {"lat": 39.5696, "lon":  2.6502, "ccaa": "Islas Baleares",         "province": "Palma"},
    "Las Palmas": {"lat": 28.1235, "lon": -15.4366, "ccaa": "Canarias",              "province": "Las Palmas"},
}

_CITY_NAMES = list(SPANISH_CITIES.keys())

# Distribuciones de dominio
_VEHICLE_TYPES   = ["Furgoneta", "Moto", "Bicicleta", "Coche", "Camion_Pequeno"]
_VEHICLE_WEIGHTS = [0.30, 0.25, 0.10, 0.25, 0.10]

_DELIVERY_STATUSES = ["entregado", "fallido", "en_transito", "devuelto", "pendiente"]
_STATUS_WEIGHTS    = [0.72, 0.10, 0.08, 0.05, 0.05]

_INCIDENT_TYPES   = [
    "accidente_trafico", "averia_vehiculo", "condiciones_climaticas",
    "no_encontrado", "direccion_erronea", "cliente_ausente",
    "robo", "paquete_danado",
]
_INCIDENT_WEIGHTS = [0.08, 0.15, 0.20, 0.10, 0.15, 0.22, 0.05, 0.05]

_FAILURE_REASONS = [
    "cliente_ausente", "direccion_incorrecta", "paquete_danado",
    "acceso_denegado", "fuerza_mayor_climatologica", None,
]

_PRIORITY_LEVELS  = ["estandar", "express", "urgente"]
_PRIORITY_WEIGHTS = [0.60, 0.30, 0.10]

_TIME_WINDOWS = ["08:00-12:00", "12:00-16:00", "16:00-20:00", "08:00-20:00"]

_SEVERITY_LEVELS  = ["baja", "media", "alta", "critica"]
_SEVERITY_WEIGHTS = [0.40, 0.35, 0.18, 0.07]


# ──────────────────────────────────────────────────────────────────────────────
# Helpers internos
# ──────────────────────────────────────────────────────────────────────────────

def _random_spanish_plate() -> str:
    """Genera una matrícula española válida (formato post-2000: 4 dígitos + 3 letras)."""
    digits = "".join(str(random.randint(0, 9)) for _ in range(4))
    # Letras permitidas en matrícula española (excluye A, B, N, O, Q)
    allowed = "BCDFGHJKLMPRSTVWXYZ"
    letters = "".join(random.choices(allowed, k=3))
    return f"{digits}{letters}"


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calcula la distancia en km entre dos coordenadas geográficas."""
    r = 6_371.0
    phi1, phi2 = map(lambda d: d * 3.14159265 / 180, [lat1, lat2])
    dphi = (lat2 - lat1) * 3.14159265 / 180
    dlam = (lon2 - lon1) * 3.14159265 / 180
    a = (
        np.sin(dphi / 2) ** 2
        + np.cos(phi1) * np.cos(phi2) * np.sin(dlam / 2) ** 2
    )
    return round(r * 2 * np.arctan2(np.sqrt(a), np.sqrt(1 - a)) * random.uniform(1.15, 1.55), 2)


# ──────────────────────────────────────────────────────────────────────────────
# Generadores de datos sintéticos
# ──────────────────────────────────────────────────────────────────────────────

def _generate_couriers(n: int) -> pd.DataFrame:
    """Genera un DataFrame de mensajeros con datos realistas para España."""
    logger.info("Generando %d mensajeros...", n)
    rows: list[dict[str, Any]] = []
    for _ in range(n):
        city      = random.choice(_CITY_NAMES)
        city_info = SPANISH_CITIES[city]
        vehicle   = random.choices(_VEHICLE_TYPES, weights=_VEHICLE_WEIGHTS, k=1)[0]
        hire_date = fake.date_between(start_date="-5y", end_date="-1m")
        rows.append({
            "courier_id":     str(uuid.uuid4()),
            "first_name":     fake.first_name(),
            "last_name":      f"{fake.last_name()} {fake.last_name()}",
            "email":          fake.email(),
            "phone":          fake.phone_number(),
            "national_id":    fake.bothify(text="########?", letters="TRWAGMYFPDXBNJZSQVHLCKE"),
            "license_number": fake.bothify(text="??-###-####"),
            "vehicle_type":   vehicle,
            "vehicle_plate":  _random_spanish_plate(),
            "zone_ccaa":      city_info["ccaa"],
            "zone_province":  city_info["province"],
            "hire_date":      hire_date.isoformat(),
            "is_active":      str(random.choices([True, False], weights=[0.92, 0.08])[0]),
            "salary_eur":     str(round(random.gauss(1_800, 250), 2)),
        })
    df = pd.DataFrame(rows)
    logger.info("Mensajeros generados: %d filas", len(df))
    return df


def _generate_deliveries(n: int, courier_ids: list[str]) -> pd.DataFrame:
    """Genera un DataFrame de entregas con referencias a mensajeros y ciudades españolas."""
    logger.info("Generando %d entregas...", n)
    extraction_dt = datetime.fromisoformat(EXTRACTION_DATE)
    rows: list[dict[str, Any]] = []

    for _ in range(n):
        origin_city   = random.choice(_CITY_NAMES)
        dest_city     = random.choice(_CITY_NAMES)
        origin_info   = SPANISH_CITIES[origin_city]
        dest_info     = SPANISH_CITIES[dest_city]
        status        = random.choices(_DELIVERY_STATUSES, weights=_STATUS_WEIGHTS, k=1)[0]
        priority      = random.choices(_PRIORITY_LEVELS, weights=_PRIORITY_WEIGHTS, k=1)[0]
        vehicle       = random.choices(_VEHICLE_TYPES, weights=_VEHICLE_WEIGHTS, k=1)[0]

        pickup_hour = random.randint(7, 12)
        pickup_dt   = datetime(
            extraction_dt.year, extraction_dt.month, extraction_dt.day,
            pickup_hour, random.randint(0, 59),
            tzinfo=timezone.utc,
        )
        duration_min  = random.randint(25, 300)
        delivery_dt   = pickup_dt + timedelta(minutes=duration_min) if status == "entregado" else None

        distance_km   = _haversine_km(
            origin_info["lat"], origin_info["lon"],
            dest_info["lat"], dest_info["lon"],
        )
        weight_kg     = round(random.uniform(0.1, 30.0), 3)
        volume_cm3    = round(random.uniform(500, 80_000), 0)
        multiplier    = {"urgente": 1.50, "express": 1.20, "estandar": 1.00}[priority]
        cost_eur      = round((3.5 + distance_km * 0.08 + weight_kg * 0.15) * multiplier, 2)

        rows.append({
            "delivery_id":         str(uuid.uuid4()),
            "courier_id":          random.choice(courier_ids),
            "package_id":          str(uuid.uuid4()),
            "origin_city":         origin_city,
            "destination_city":    dest_city,
            "origin_lat":          str(origin_info["lat"]),
            "origin_lon":          str(origin_info["lon"]),
            "destination_lat":     str(dest_info["lat"]),
            "destination_lon":     str(dest_info["lon"]),
            "origin_ccaa":         origin_info["ccaa"],
            "destination_ccaa":    dest_info["ccaa"],
            "scheduled_date":      extraction_dt.date().isoformat(),
            "time_window":         random.choice(_TIME_WINDOWS),
            "actual_pickup_ts":    pickup_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "actual_delivery_ts":  delivery_dt.strftime("%Y-%m-%dT%H:%M:%SZ") if delivery_dt else None,
            "status":              status,
            "failure_reason":      random.choice(_FAILURE_REASONS) if status == "fallido" else None,
            "weight_kg":           str(weight_kg),
            "volume_cm3":          str(volume_cm3),
            "delivery_cost_eur":   str(cost_eur),
            "distance_km":         str(distance_km),
            "priority":            priority,
            "vehicle_type":        vehicle,
        })

    df = pd.DataFrame(rows)
    logger.info("Entregas generadas: %d filas", len(df))
    return df


def _generate_routes(n: int, courier_ids: list[str]) -> pd.DataFrame:
    """Genera un DataFrame de rutas operativas con métricas de combustible y CO₂."""
    logger.info("Generando %d rutas...", n)
    extraction_dt = datetime.fromisoformat(EXTRACTION_DATE)
    rows: list[dict[str, Any]] = []

    for _ in range(n):
        city         = random.choice(_CITY_NAMES)
        start_hour   = random.randint(6, 9)
        start_dt     = datetime(
            extraction_dt.year, extraction_dt.month, extraction_dt.day,
            start_hour, random.randint(0, 59),
            tzinfo=timezone.utc,
        )
        planned_dur  = random.randint(240, 600)
        actual_dur   = int(planned_dur * random.uniform(0.85, 1.45))
        end_dt       = start_dt + timedelta(minutes=actual_dur)

        planned_dist = round(random.uniform(50, 250), 2)
        actual_dist  = round(planned_dist * random.uniform(0.90, 1.25), 2)
        fuel_l       = round(actual_dist * random.uniform(0.06, 0.14), 3)
        co2_kg       = round(fuel_l * 2.392, 3)  # factor estándar gasolina

        rows.append({
            "route_id":                str(uuid.uuid4()),
            "courier_id":              random.choice(courier_ids),
            "route_date":              extraction_dt.date().isoformat(),
            "origin_city":             city,
            "total_stops":             str(random.randint(5, 45)),
            "planned_distance_km":     str(planned_dist),
            "actual_distance_km":      str(actual_dist),
            "planned_duration_min":    str(planned_dur),
            "actual_duration_min":     str(actual_dur),
            "fuel_consumption_liters": str(fuel_l),
            "co2_emissions_kg":        str(co2_kg),
            "start_ts":                start_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "end_ts":                  end_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
        })

    df = pd.DataFrame(rows)
    logger.info("Rutas generadas: %d filas", len(df))
    return df


def _generate_incidents(deliveries_df: pd.DataFrame, rate: float) -> pd.DataFrame:
    """Genera incidencias como subconjunto aleatorio del DataFrame de entregas."""
    n_incidents = int(len(deliveries_df) * rate)
    logger.info("Generando %d incidencias (%.0f%% de entregas)...", n_incidents, rate * 100)

    sample        = deliveries_df.sample(n=min(n_incidents, len(deliveries_df)), replace=False)
    extraction_dt = datetime.fromisoformat(EXTRACTION_DATE)
    rows: list[dict[str, Any]] = []

    for _, row in sample.iterrows():
        inc_type       = random.choices(_INCIDENT_TYPES, weights=_INCIDENT_WEIGHTS, k=1)[0]
        is_weather     = inc_type == "condiciones_climaticas"
        severity       = random.choices(_SEVERITY_LEVELS, weights=_SEVERITY_WEIGHTS, k=1)[0]
        incident_dt    = datetime(
            extraction_dt.year, extraction_dt.month, extraction_dt.day,
            random.randint(7, 20), random.randint(0, 59),
            tzinfo=timezone.utc,
        )
        resolution_min = random.randint(15, 600)
        resolution_dt  = incident_dt + timedelta(minutes=resolution_min)
        cost_mult      = 2.0 if severity in ("alta", "critica") else 1.0
        cost_impact    = round(random.uniform(10, 800) * cost_mult, 2)

        rows.append({
            "incident_id":       str(uuid.uuid4()),
            "delivery_id":       str(row["delivery_id"]),
            "courier_id":        str(row["courier_id"]),
            "incident_ts":       incident_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "incident_type":     inc_type,
            "description":       fake.sentence(nb_words=12),
            "severity":          severity,
            "resolution_ts":     resolution_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "resolution_notes":  fake.sentence(nb_words=8),
            "cost_impact_eur":   str(cost_impact),
            "is_weather_related": str(is_weather),
        })

    df = pd.DataFrame(rows)
    logger.info("Incidencias generadas: %d filas", len(df))
    return df


# ──────────────────────────────────────────────────────────────────────────────
# Open-Meteo API con reintentos mediante tenacity
# ──────────────────────────────────────────────────────────────────────────────

@retry(
    retry=retry_if_exception_type(
        (httpx.TimeoutException, httpx.HTTPStatusError, httpx.ConnectError)
    ),
    wait=wait_exponential(multiplier=1, min=2, max=60),
    stop=stop_after_attempt(5),
    before_sleep=before_sleep_log(logger, logging.WARNING),
)
def _fetch_city_weather(city: str, city_info: dict[str, Any], days: int) -> list[dict[str, Any]]:
    """Consulta Open-Meteo para una ciudad y retorna registros por hora.

    Lanza httpx.HTTPStatusError si el servidor responde con 4xx/5xx,
    lo que activa el mecanismo de reintento de tenacity.
    """
    params: dict[str, Any] = {
        "latitude":      city_info["lat"],
        "longitude":     city_info["lon"],
        "hourly":        ",".join([
            "temperature_2m", "precipitation", "wind_speed_10m",
            "wind_gusts_10m", "cloud_cover", "visibility", "weather_code",
        ]),
        "timezone":      "Europe/Madrid",
        "forecast_days": days,
    }

    with httpx.Client(timeout=_OPEN_METEO_TIMEOUT) as client:
        response = client.get(_OPEN_METEO_BASE_URL, params=params)
        response.raise_for_status()

    data   = response.json()
    hourly = data.get("hourly", {})
    times  = hourly.get("time", [])

    if not times:
        logger.warning("Open-Meteo: respuesta vacía para %s", city)
        return []

    def _val(key: str, idx: int) -> str:
        """Extrae un valor de la lista hourly con manejo de índice fuera de rango."""
        vals = hourly.get(key, [])
        return str(vals[idx]) if idx < len(vals) else "None"

    return [
        {
            "city":                   city,
            "lat":                    str(city_info["lat"]),
            "lon":                    str(city_info["lon"]),
            "ccaa":                   city_info["ccaa"],
            "province":               city_info["province"],
            "forecast_ts":            ts,
            "temperature_2m_celsius": _val("temperature_2m", i),
            "precipitation_mm":       _val("precipitation", i),
            "wind_speed_10m_kmh":     _val("wind_speed_10m", i),
            "wind_gusts_10m_kmh":     _val("wind_gusts_10m", i),
            "cloud_cover_pct":        _val("cloud_cover", i),
            "visibility_m":           _val("visibility", i),
            "weather_code":           _val("weather_code", i),
        }
        for i, ts in enumerate(times)
    ]


def _fetch_all_weather(days: int = 1) -> pd.DataFrame:
    """Itera sobre todas las ciudades de referencia y agrega los datos meteorológicos."""
    all_records: list[dict[str, Any]] = []

    for city, city_info in SPANISH_CITIES.items():
        logger.info("Consultando Open-Meteo para %s...", city)
        try:
            records = _fetch_city_weather(city, city_info, days)
            all_records.extend(records)
            logger.debug("  → %d registros para %s", len(records), city)
        except RetryError:
            logger.error("Reintentos agotados para %s. Ciudad omitida.", city)
        except Exception:
            logger.error("Error inesperado al consultar %s.", city, exc_info=True)

    df = pd.DataFrame(all_records)
    logger.info(
        "Datos meteorológicos: %d filas para %d ciudades",
        len(df), len(SPANISH_CITIES),
    )
    return df


# ──────────────────────────────────────────────────────────────────────────────
# Serialización Parquet y upload a S3
# ──────────────────────────────────────────────────────────────────────────────

def _df_to_parquet_bytes(df: pd.DataFrame) -> bytes:
    """Serializa un DataFrame a bytes Parquet con compresión Snappy."""
    table = pa.Table.from_pandas(df, preserve_index=False)
    buf   = io.BytesIO()
    pq.write_table(table, buf, compression="snappy")
    buf.seek(0)
    return buf.read()


def _upload_to_s3(
    s3_client: Any,
    data: bytes,
    dataset_name: str,
    extraction_date: str,
    bucket: str,
) -> str:
    """Sube bytes Parquet a S3 usando la convención de particionado Hive-style.

    Retorna el S3 key del archivo subido.
    Lanza BotoCoreError o ClientError si la subida falla.
    """
    s3_key = f"{dataset_name}/extraction_date={extraction_date}/{dataset_name}.parquet"
    logger.info("Subiendo s3://%s/%s (%d bytes)...", bucket, s3_key, len(data))

    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=s3_key,
            Body=data,
            ContentType="application/octet-stream",
            ServerSideEncryption="AES256",
        )
    except (BotoCoreError, ClientError) as exc:
        logger.error("Error al subir %s: %s", s3_key, exc)
        raise

    logger.info("Upload OK → s3://%s/%s", bucket, s3_key)
    return s3_key


# ──────────────────────────────────────────────────────────────────────────────
# Punto de entrada principal
# ──────────────────────────────────────────────────────────────────────────────

def main() -> None:
    """Orquesta la generación de datos, la obtención meteorológica y el upload a S3."""
    logger.info("=" * 70)
    logger.info(
        "Iniciando ingesta | fecha=%s | bucket=s3://%s",
        EXTRACTION_DATE, S3_BUCKET,
    )
    logger.info(
        "Parámetros: couriers=%d, deliveries=%d, routes=%d, incidents_rate=%.2f",
        N_COURIERS, N_DELIVERIES, N_ROUTES, INCIDENTS_RATE,
    )
    logger.info("=" * 70)

    # 1. Generar datos sintéticos
    couriers_df   = _generate_couriers(N_COURIERS)
    courier_ids   = couriers_df["courier_id"].tolist()
    deliveries_df = _generate_deliveries(N_DELIVERIES, courier_ids)
    routes_df     = _generate_routes(N_ROUTES, courier_ids)
    incidents_df  = _generate_incidents(deliveries_df, INCIDENTS_RATE)

    # 2. Obtener datos meteorológicos de Open-Meteo
    weather_df = _fetch_all_weather(days=OPEN_METEO_DAYS)

    # 3. Inicializar cliente S3 (usa IAM Role si corre en ECS, o env vars localmente)
    s3_client = boto3.client("s3", region_name=AWS_REGION)

    # 4. Serializar cada dataset a Parquet y subir a S3
    datasets: dict[str, pd.DataFrame] = {
        "couriers":   couriers_df,
        "deliveries": deliveries_df,
        "routes":     routes_df,
        "incidents":  incidents_df,
        "weather":    weather_df,
    }

    uploaded_keys: list[str] = []
    for name, df in datasets.items():
        if df.empty:
            logger.warning("Dataset '%s' está vacío — se omite.", name)
            continue
        parquet_bytes = _df_to_parquet_bytes(df)
        key = _upload_to_s3(s3_client, parquet_bytes, name, EXTRACTION_DATE, S3_BUCKET)
        uploaded_keys.append(key)

    # 5. Resumen final
    logger.info("=" * 70)
    logger.info("Ingesta completada. %d archivos subidos:", len(uploaded_keys))
    for key in uploaded_keys:
        logger.info("  → s3://%s/%s", S3_BUCKET, key)
    logger.info("=" * 70)


if __name__ == "__main__":
    main()
