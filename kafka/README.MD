# Kafka

Kafka runs as part of the root `docker-compose.yml` in single-node KRaft mode (no Zookeeper).

Start the full stack from the project root:
```bash
./start.sh
```

Start only Kafka (if needed):
```bash
docker compose up -d kafka
```

Confirm Kafka is up:
```bash
docker exec -ti kafka /opt/kafka/bin/kafka-cluster.sh cluster-id --bootstrap-server kafka:9092
```

Stop services:
```bash
./stop.sh
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

## Topics in this demo

Debezium produces table CDC events to:

- `example.cd.members`
- `example.cd.facilities`
- `example.cd.bookings`

Kafka Connect internal topics:

- `connect_configs`
- `connect_offsets`
- `connect_statuses`

List topics:
```bash
docker exec -ti kafka /opt/kafka/bin/kafka-topics.sh \
  --list --bootstrap-server kafka:9092
```

Consume members CDC events:
```bash
docker exec -ti kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka:9092 \
  --topic example.cd.members \
  --from-beginning
```

## Example CDC event payloads

`create.json` and `update.json` are reference examples of Debezium CDC events published to the `example.cd.members` topic.

In this project, connector schemas are disabled (`KEY_CONVERTER_SCHEMAS_ENABLE=false`, `VALUE_CONVERTER_SCHEMAS_ENABLE=false`), so events are flat JSON payloads.

Each event includes:

| Field | Description |
|---|---|
| `before` | Row state before the change. `null` for INSERTs |
| `after` | Row state after the change. `null` for DELETEs |
| `op` | Operation type: `c` = INSERT, `u` = UPDATE, `d` = DELETE, `r` = snapshot READ |
| `source` | Metadata: connector, schema, table, transaction ID (`txId`), LSN, timestamps |

### create.json

Represents an INSERT (`"op": "c"`). `before` is `null`; `after` contains the new row.

```json
{
  "before": null,
  "after": { "memid": 101, "surname": "Demo1", "firstname": "User1" },
  "op": "c"
}
```

### update.json

Represents an UPDATE (`"op": "u"`). Both `before` and `after` are populated because `REPLICA IDENTITY FULL` is set on `cd.members` (see [flyway/migrations/V3__replica_identity.sql](../flyway/migrations/V3__replica_identity.sql)).

```json
{
  "before": { "memid": 101, "surname": "Demo1", "firstname": "User1", "address": "1 Demo Lane, Boston" },
  "after":  { "memid": 101, "surname": "Demo1", "firstname": "User1", "address": "100 Updated Blvd, Boston" },
  "op": "u"
}
```

These files are reference examples only.

## Links

- [Developing event-driven applications with Kafka and Docker](https://docs.docker.com/guides/kafka/)