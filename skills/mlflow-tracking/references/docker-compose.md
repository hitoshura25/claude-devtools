# Local MLflow Server Setup

## docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: mlflow
      POSTGRES_PASSWORD: mlflow
      POSTGRES_DB: mlflow
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "mlflow"]
      interval: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio-data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 5s
      retries: 5

  minio-init:
    image: minio/mc:latest
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
      mc alias set myminio http://minio:9000 minioadmin minioadmin;
      mc mb --ignore-existing myminio/mlflow-artifacts;
      exit 0;
      "

  mlflow:
    image: ghcr.io/mlflow/mlflow:v2.10.0
    depends_on:
      postgres:
        condition: service_healthy
      minio-init:
        condition: service_completed_successfully
    ports:
      - "5000:5000"
    environment:
      MLFLOW_S3_ENDPOINT_URL: http://minio:9000
      AWS_ACCESS_KEY_ID: minioadmin
      AWS_SECRET_ACCESS_KEY: minioadmin
    command: >
      mlflow server
      --backend-store-uri postgresql://mlflow:mlflow@postgres:5432/mlflow
      --default-artifact-root s3://mlflow-artifacts
      --host 0.0.0.0
      --port 5000

volumes:
  postgres-data:
  minio-data:
```

## Directory Structure

```
mlflow/
├── docker-compose.yml
└── .env
```

## Quick Start

```bash
# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f mlflow
```

## Access

- **MLflow UI**: http://localhost:5000
- **MinIO Console**: http://localhost:9001 (minioadmin/minioadmin)

## Client Configuration

Set environment variables for your training scripts:

```bash
export MLFLOW_TRACKING_URI=http://localhost:5000
export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
```

Or in Python:

```python
import os
import mlflow

os.environ['MLFLOW_TRACKING_URI'] = 'http://localhost:5000'
os.environ['MLFLOW_S3_ENDPOINT_URL'] = 'http://localhost:9000'
os.environ['AWS_ACCESS_KEY_ID'] = 'minioadmin'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'minioadmin'

mlflow.set_tracking_uri('http://localhost:5000')
```

## Cleanup

```bash
# Stop services
docker compose down

# Remove volumes (deletes all data!)
docker compose down -v
```

## Production Considerations

For production, consider:
- Use managed PostgreSQL (RDS, Cloud SQL)
- Use managed object storage (S3, GCS)
- Add authentication (MLflow doesn't have built-in auth)
- Use nginx reverse proxy with OAuth2
