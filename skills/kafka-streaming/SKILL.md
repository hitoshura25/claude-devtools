---
name: kafka-streaming
description: Use when building real-time data pipelines, CDC (Change Data Capture), or event-driven systems
---

# Kafka Streaming

## Overview

Set up Kafka with CDC for real-time data streaming.

**Announce at start:** "I'm using the kafka-streaming skill to set up the streaming layer."

## When to Use

- Real-time data pipelines
- Database CDC
- Event-driven architecture

## Quick Start

```yaml
# docker-compose excerpt
services:
  kafka:
    image: confluentinc/cp-kafka:7.5.0
    ports: ["9092:9092"]
  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    ports: ["8090:8080"]
```

## CDC with Debezium

Register PostgreSQL connector to capture changes:
- INSERT/UPDATE/DELETE → Kafka topics
- Real-time anomaly detection possible

## References

- @references/docker-compose.md - Full Kafka stack
- @references/debezium-cdc.md - PostgreSQL CDC
- @references/python-consumer.md - Consumer patterns
- @references/flink-integration.md - Stream processing

## Completion Criteria

- [ ] Kafka running (localhost:9092)
- [ ] Kafka UI accessible (localhost:8090)
- [ ] Debezium connector registered
- [ ] CDC events flowing
- [ ] Consumer processing events
