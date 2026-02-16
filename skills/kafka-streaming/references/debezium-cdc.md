# Debezium CDC for PostgreSQL

## PostgreSQL Configuration

Enable logical replication in PostgreSQL:

```sql
-- postgresql.conf or via ALTER SYSTEM
ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM SET max_replication_slots = 4;
ALTER SYSTEM SET max_wal_senders = 4;

-- Restart PostgreSQL after changes
```

Or in docker-compose:

```yaml
services:
  postgres:
    image: postgres:16
    command: >
      postgres
      -c wal_level=logical
      -c max_replication_slots=4
      -c max_wal_senders=4
    environment:
      POSTGRES_USER: healthdata
      POSTGRES_PASSWORD: healthdata
      POSTGRES_DB: healthdata
```

## Create Publication

```sql
-- Create publication for specific tables
CREATE PUBLICATION glucose_pub FOR TABLE glucose_readings, heart_rate_readings;

-- Or for all tables
CREATE PUBLICATION healthdata_pub FOR ALL TABLES;
```

## Register Debezium Connector

```bash
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "healthdata-postgres-connector",
    "config": {
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
      "database.hostname": "postgres",
      "database.port": "5432",
      "database.user": "healthdata",
      "database.password": "healthdata",
      "database.dbname": "healthdata",
      "database.server.name": "healthdata",
      "topic.prefix": "healthdata",
      "table.include.list": "public.glucose_readings,public.heart_rate_readings",
      "plugin.name": "pgoutput",
      "publication.name": "healthdata_pub",
      "slot.name": "healthdata_slot",
      "snapshot.mode": "initial",
      "key.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "key.converter.schemas.enable": "false",
      "value.converter.schemas.enable": "true"
    }
  }'
```

## Connector Management

```bash
# List connectors
curl http://localhost:8083/connectors

# Get connector status
curl http://localhost:8083/connectors/healthdata-postgres-connector/status

# Pause connector
curl -X PUT http://localhost:8083/connectors/healthdata-postgres-connector/pause

# Resume connector
curl -X PUT http://localhost:8083/connectors/healthdata-postgres-connector/resume

# Delete connector
curl -X DELETE http://localhost:8083/connectors/healthdata-postgres-connector
```

## Topic Naming

Debezium creates topics with this pattern:
```
{topic.prefix}.{schema}.{table}
```

Example topics:
- `healthdata.public.glucose_readings`
- `healthdata.public.heart_rate_readings`

## Message Format

### Insert Event

```json
{
  "schema": { ... },
  "payload": {
    "before": null,
    "after": {
      "id": 1,
      "timestamp": "2025-01-28T10:00:00Z",
      "value_mg_dl": 120.5,
      "source": "stelo"
    },
    "source": {
      "version": "2.4.0",
      "connector": "postgresql",
      "name": "healthdata",
      "ts_ms": 1706436000000,
      "db": "healthdata",
      "schema": "public",
      "table": "glucose_readings"
    },
    "op": "c",
    "ts_ms": 1706436000123
  }
}
```

### Update Event

```json
{
  "payload": {
    "before": {
      "id": 1,
      "value_mg_dl": 120.5
    },
    "after": {
      "id": 1,
      "value_mg_dl": 125.0
    },
    "op": "u"
  }
}
```

### Delete Event

```json
{
  "payload": {
    "before": {
      "id": 1,
      "value_mg_dl": 125.0
    },
    "after": null,
    "op": "d"
  }
}
```

## Operation Types

| Code | Operation |
|------|-----------|
| `c` | Create (INSERT) |
| `u` | Update (UPDATE) |
| `d` | Delete (DELETE) |
| `r` | Read (snapshot) |

## Troubleshooting

### Check Replication Slot

```sql
SELECT * FROM pg_replication_slots;
```

### Check WAL Position

```sql
SELECT pg_current_wal_lsn();
```

### Connector Errors

```bash
# Check connector task errors
curl http://localhost:8083/connectors/healthdata-postgres-connector/tasks/0/status
```

### Reset Offset

```bash
# Delete and recreate connector to reset
curl -X DELETE http://localhost:8083/connectors/healthdata-postgres-connector
# Re-register with snapshot.mode: initial
```
