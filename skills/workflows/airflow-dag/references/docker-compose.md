# Local Airflow Setup

## docker-compose.yml

```yaml
version: '3.8'

x-airflow-common: &airflow-common
  image: apache/airflow:2.8.1-python3.11
  environment:
    &airflow-common-env
    AIRFLOW__CORE__EXECUTOR: LocalExecutor
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
    AIRFLOW__CORE__FERNET_KEY: ''
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
    AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
    AIRFLOW__API__AUTH_BACKENDS: 'airflow.api.auth.backend.basic_auth'
  volumes:
    - ./dags:/opt/airflow/dags
    - ./logs:/opt/airflow/logs
    - ./plugins:/opt/airflow/plugins
    - ./tests:/opt/airflow/tests
  user: "${AIRFLOW_UID:-50000}:0"
  depends_on:
    postgres:
      condition: service_healthy

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres-db-volume:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
      interval: 5s
      retries: 5
    restart: always

  airflow-webserver:
    <<: *airflow-common
    command: webserver
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
      interval: 10s
      timeout: 10s
      retries: 5
    restart: always

  airflow-scheduler:
    <<: *airflow-common
    command: scheduler
    healthcheck:
      test: ["CMD-SHELL", 'airflow jobs check --job-type SchedulerJob --hostname "$${HOSTNAME}"']
      interval: 10s
      timeout: 10s
      retries: 5
    restart: always

  airflow-init:
    <<: *airflow-common
    entrypoint: /bin/bash
    command:
      - -c
      - |
        airflow db migrate
        airflow users create \
          --username admin \
          --firstname Admin \
          --lastname User \
          --role Admin \
          --email admin@example.com \
          --password admin
    restart: on-failure

volumes:
  postgres-db-volume:
```

## Directory Structure

```
project/
├── docker-compose.yml
├── dags/
│   ├── __init__.py
│   └── health_connect_etl.py
├── plugins/
│   └── __init__.py
├── tests/
│   ├── __init__.py
│   └── test_dags.py
└── logs/
```

## Quick Start

```bash
# Set UID for volume permissions
echo -e "AIRFLOW_UID=$(id -u)" > .env

# Create directories
mkdir -p dags logs plugins tests

# Initialize
docker compose up airflow-init

# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f airflow-scheduler
```

## Access

- **Web UI**: http://localhost:8080
- **Username**: admin
- **Password**: admin

## Adding Python Dependencies

Create `requirements.txt`:

```
pandas>=2.0.0
google-api-python-client>=2.0.0
sqlalchemy>=2.0.0
```

Update docker-compose:

```yaml
x-airflow-common: &airflow-common
  build:
    context: .
    dockerfile: Dockerfile
```

Create `Dockerfile`:

```dockerfile
FROM apache/airflow:2.8.1-python3.11
COPY requirements.txt /
RUN pip install --no-cache-dir -r /requirements.txt
```

## Common Commands

```bash
# Trigger DAG manually
docker compose exec airflow-scheduler airflow dags trigger my_dag

# List DAGs
docker compose exec airflow-scheduler airflow dags list

# Check task status
docker compose exec airflow-scheduler airflow tasks states-for-dag-run my_dag 2025-01-01

# Clear task
docker compose exec airflow-scheduler airflow tasks clear my_dag -t my_task -s 2025-01-01 -e 2025-01-02
```

## Cleanup

```bash
# Stop and remove containers
docker compose down

# Remove volumes (deletes data!)
docker compose down -v
```
