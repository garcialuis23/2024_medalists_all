# ─────────────────────────────────────────────────────────────────────────────
# Dockerfile — Script de Ingesta de Logística Última Milla
# Imagen base: python:3.11-slim (sin extras de sistema innecesarios)
# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim

# Evitar prompts interactivos en apt
ENV DEBIAN_FRONTEND=noninteractive

# Directorio de trabajo
WORKDIR /app

# Copiar solo requirements primero para aprovechar la caché de capas Docker
COPY requirements.txt .

# Instalar dependencias sin caché pip (reduce tamaño de imagen)
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copiar el código fuente
COPY src/ ./src/

# Variables de entorno con defaults seguros (no secretos)
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    LOG_LEVEL=INFO \
    N_COURIERS=200 \
    N_DELIVERIES=5000 \
    N_ROUTES=1500 \
    INCIDENTS_RATE=0.12 \
    OPEN_METEO_DAYS=1 \
    AWS_REGION=eu-west-1

# Las variables secretas/sensibles se inyectan en tiempo de ejecución:
#   S3_BUCKET, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#   (o via IAM Role en ECS — recomendado en producción)

# Punto de entrada: ejecutar el script de ingesta
ENTRYPOINT ["python", "-m", "src.ingest"]
