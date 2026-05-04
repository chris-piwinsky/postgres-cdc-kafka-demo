
# Kafka with DOCKER

Kafka runs as part of the root `docker-compose.yml` in KRaft mode (no Zookeeper). Start it with `./start.sh` from the project root.

Kill anything listening on port 9092:
```bash
lsof -ti :9092 | xargs kill -9
```

Start Kafka (version 4.2.0):
```bash
docker compose up -d
```

Confirm it is up and running:
```bash
docker exec -ti kafka /opt/kafka/bin/kafka-cluster.sh cluster-id --bootstrap-server :9092
```

Create a sample topic:
```bash
docker exec -ti kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server :9092 --topic demo
```

Stop Kafka:
```bash
docker compose down
```

## KRaft listener configuration

Kafka requires explicit listener config so other containers (e.g. Debezium Connect) can reach it via `kafka:9092` on the Docker internal network:

| Environment variable | Value | Purpose |
|---|---|---|
| `KAFKA_PROCESS_ROLES` | `broker,controller` | Single-node KRaft mode (no Zookeeper) |
| `KAFKA_LISTENERS` | `PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093` | Bind to all interfaces |
| `KAFKA_ADVERTISED_LISTENERS` | `PLAINTEXT://kafka:9092` | Advertise Docker hostname to clients |
| `KAFKA_CONTROLLER_QUORUM_VOTERS` | `1@kafka:9093` | Single-node controller quorum |
| `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR` | `1` | Required for single-node cluster |

Without `KAFKA_ADVERTISED_LISTENERS`, Kafka defaults to `localhost` and other containers cannot connect.

## Example CDC event payloads

`create.json` and `update.json` are reference examples of the Debezium CDC event structure published to the `example.public.customers` Kafka topic.

Each event has two top-level fields:

| Field | Description |
|---|---|
| `schema` | Describes the structure of the payload (field names, types, optional flags) |
| `payload` | The actual change data |

### payload fields

| Field | Description |
|---|---|
| `before` | Row state before the change. `null` for INSERTs |
| `after` | Row state after the change. `null` for DELETEs |
| `op` | Operation type: `c` = INSERT, `u` = UPDATE, `d` = DELETE, `r` = snapshot READ |
| `source` | Metadata: connector name, table, transaction ID (`txId`), log sequence number (`lsn`), timestamp |

### create.json

Represents an INSERT (`"op": "c"`). `before` is `null`; `after` contains the new row.

```json
"payload": {
  "before": null,
  "after": { "id": 1, "name": "Test User", "email": "test@example.com" },
  "op": "c"
}
```

### update.json

Represents an UPDATE (`"op": "u"`). Both `before` and `after` are populated because `REPLICA IDENTITY FULL` is set on the `customers` table (see [flyway/migrations/V2__replica_identity.sql](../flyway/migrations/V2__replica_identity.sql)).

```json
"payload": {
  "before": { "id": 1, "name": "Test User", "email": "test@example.com" },
  "after":  { "id": 1, "name": "Updated Name", "email": "new@example.com" },
  "op": "u"
}
```

> These files are reference examples only. They are not registered with a schema registry (schemas are disabled in the connector config).

## Links

- [Developing event-driven applications with Kafka and Docker](https://docs.docker.com/guides/kafka/)
- [Docker files]()