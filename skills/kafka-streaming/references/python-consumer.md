# Python Kafka Consumer Patterns

## Installation

```bash
pip install confluent-kafka
# Or with Avro support
pip install confluent-kafka[avro]
```

## Basic Consumer

```python
from confluent_kafka import Consumer, KafkaException
import json

config = {
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'glucose-processor',
    'auto.offset.reset': 'earliest',
    'enable.auto.commit': False
}

consumer = Consumer(config)
consumer.subscribe(['healthdata.public.glucose_readings'])

try:
    while True:
        msg = consumer.poll(timeout=1.0)

        if msg is None:
            continue

        if msg.error():
            raise KafkaException(msg.error())

        # Parse Debezium message
        value = json.loads(msg.value().decode('utf-8'))
        payload = value['payload']

        op = payload['op']
        if op == 'c':  # Insert
            record = payload['after']
            process_new_reading(record)
        elif op == 'u':  # Update
            before = payload['before']
            after = payload['after']
            process_update(before, after)
        elif op == 'd':  # Delete
            record = payload['before']
            process_delete(record)

        # Commit after successful processing
        consumer.commit(asynchronous=False)

except KeyboardInterrupt:
    pass
finally:
    consumer.close()
```

## Async Consumer

```python
import asyncio
from confluent_kafka import Consumer
import json

class AsyncKafkaConsumer:
    def __init__(self, config: dict, topics: list[str]):
        self.consumer = Consumer(config)
        self.consumer.subscribe(topics)
        self.running = True

    async def consume(self):
        loop = asyncio.get_event_loop()

        while self.running:
            # Non-blocking poll
            msg = await loop.run_in_executor(
                None, lambda: self.consumer.poll(0.1)
            )

            if msg is None:
                await asyncio.sleep(0.01)
                continue

            if msg.error():
                print(f"Error: {msg.error()}")
                continue

            yield json.loads(msg.value().decode('utf-8'))

    async def commit(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.consumer.commit)

    def close(self):
        self.running = False
        self.consumer.close()


# Usage
async def main():
    config = {
        'bootstrap.servers': 'localhost:9092',
        'group.id': 'async-processor',
        'auto.offset.reset': 'earliest',
        'enable.auto.commit': False
    }

    consumer = AsyncKafkaConsumer(
        config,
        ['healthdata.public.glucose_readings']
    )

    async for message in consumer.consume():
        payload = message['payload']
        await process_message_async(payload)
        await consumer.commit()

asyncio.run(main())
```

## Batch Processing

```python
from confluent_kafka import Consumer
import json
from typing import List

def consume_batch(
    consumer: Consumer,
    batch_size: int = 100,
    timeout: float = 5.0
) -> List[dict]:
    """Consume a batch of messages."""
    messages = []
    start_time = time.time()

    while len(messages) < batch_size:
        remaining = timeout - (time.time() - start_time)
        if remaining <= 0:
            break

        msg = consumer.poll(timeout=min(1.0, remaining))

        if msg is None:
            continue
        if msg.error():
            continue

        messages.append(json.loads(msg.value().decode('utf-8')))

    return messages

# Usage
config = {
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'batch-processor',
    'auto.offset.reset': 'earliest',
    'enable.auto.commit': False
}

consumer = Consumer(config)
consumer.subscribe(['healthdata.public.glucose_readings'])

while True:
    batch = consume_batch(consumer, batch_size=100, timeout=5.0)

    if batch:
        # Process batch
        process_batch(batch)
        consumer.commit()
```

## Anomaly Detection Consumer

```python
from confluent_kafka import Consumer
import json
from collections import deque
import statistics

class GlucoseAnomalyDetector:
    def __init__(self, window_size: int = 10, threshold: float = 2.0):
        self.window = deque(maxlen=window_size)
        self.threshold = threshold

    def detect(self, reading: dict) -> bool:
        """Detect anomaly using z-score."""
        value = reading['value_mg_dl']

        if len(self.window) < 3:
            self.window.append(value)
            return False

        mean = statistics.mean(self.window)
        std = statistics.stdev(self.window)

        if std == 0:
            self.window.append(value)
            return False

        z_score = abs(value - mean) / std
        is_anomaly = z_score > self.threshold

        self.window.append(value)
        return is_anomaly


def run_anomaly_consumer():
    config = {
        'bootstrap.servers': 'localhost:9092',
        'group.id': 'anomaly-detector',
        'auto.offset.reset': 'earliest'
    }

    consumer = Consumer(config)
    consumer.subscribe(['healthdata.public.glucose_readings'])
    detector = GlucoseAnomalyDetector()

    try:
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                continue

            payload = json.loads(msg.value().decode('utf-8'))['payload']

            if payload['op'] == 'c':
                reading = payload['after']
                if detector.detect(reading):
                    alert_anomaly(reading)

    finally:
        consumer.close()


def alert_anomaly(reading: dict):
    """Send alert for anomalous reading."""
    print(f"ANOMALY: {reading['timestamp']} - {reading['value_mg_dl']} mg/dL")
    # Send to alerting system
```

## Error Handling

<Good>
try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                continue  # End of partition, keep polling
            else:
                raise KafkaException(msg.error())

        try:
            process_message(msg)
            consumer.commit()
        except ProcessingError as e:
            # Don't commit, will retry on next poll
            log_error(e)
            send_to_dead_letter_queue(msg)
            consumer.commit()  # Commit after DLQ
</Good>

<Bad>
while True:
    msg = consumer.poll(1.0)
    # No null check
    # No error check
    process_message(msg)
    # No commit
</Bad>
