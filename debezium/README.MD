# Debezium Postgres CDC Connector

Registers a Debezium PostgreSQL source connector with Kafka Connect to stream change events from Postgres into Kafka topics.

Debezium Connect runs as part of the root `docker-compose.yml`. Start it with `./start.sh` from the project root before registering connectors.

## Register the connector

The connector is registered automatically by `./start.sh` (idempotent — safe to run multiple times).

To register manually (e.g. after deleting and re-creating it), run from the project root:

```bash
source .env
envsubst < debezium/register-postgres.json.example \
  | curl -X POST -H "Content-Type: application/json" \
         --data @- \
         http://localhost:8083/connectors
```

`envsubst` substitutes `${DB_PASSWORD}` from your `.env` at runtime. The resolved JSON is piped directly to curl and never written to disk.

Expected response:

```json
{
  "name": "example-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "db",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "<your-password>",
    "database.dbname": "postgres",
    "topic.prefix": "example",
    "slot.name": "example_slot",
    "publication.autocreate.mode": "filtered",
    "table.include.list": "cd.members,cd.facilities,cd.bookings",
    "name": "example-connector"
  },
  "tasks": [],
  "type": "source"
}
```

## Useful commands

Check connector status:
```bash
curl -s http://localhost:8083/connectors/example-connector/status | jq
```

List all registered connectors:
```bash
curl -s http://localhost:8083/connectors | python3 -m json.tool
```

Delete the connector:
```bash
curl -X DELETE http://localhost:8083/connectors/example-connector
```

Check Kafka Connect is running:
```bash
curl -s http://localhost:8083/ | python3 -m json.tool
```

## Configuration notes

| Field | Value | Notes |
|---|---|---|
| `database.hostname` | `db` | Docker Compose service name — not `localhost` or `some-postgres` |
| `database.port` | `5432` | Internal Docker port (not the host-mapped 5431) |
| `plugin.name` | `pgoutput` | Must be set explicitly — Debezium may default to `decoderbufs` which is not installed on `postgres:17` |
| `publication.autocreate.mode` | `filtered` | Auto-creates a publication for tables in `table.include.list` |
| `table.include.list` | `cd.members,cd.facilities,cd.bookings` | Add more tables as `schema.table` comma-separated |

## Troubleshooting

### `could not access file "decoderbufs": No such file or directory`

Debezium tried to use the `decoderbufs` logical decoding plugin which is not installed on the official `postgres:17` image. Fix: ensure `plugin.name: pgoutput` is set in `register-postgres.json`. `pgoutput` is built into PostgreSQL 10+ and requires no extra installation.

If you hit this after already registering the connector, delete it and re-register:
```bash
curl -X DELETE http://localhost:8083/connectors/example-connector

curl -X POST -H "Content-Type: application/json" \
     --data @register-postgres.json \
     http://localhost:8083/connectors
```

### Connector is FAILED

Check the task error:
```bash
curl -s http://localhost:8083/connectors/example-connector/status | python3 -m json.tool
```

### `no such file or directory: /kafka/bin/kafka-console-consumer.sh`

The `apache/kafka` image installs Kafka at `/opt/kafka/bin/`, not `/kafka/bin/`. Always use `/opt/kafka/bin/` for all Kafka CLI commands.

### `database.hostname` connection refused

Use the Docker Compose service name `db` — not `localhost`, `127.0.0.1`, or `some-postgres`. Debezium Connect resolves hostnames via the Docker internal network.

## Change events

Once registered, Debezium streams change events to Kafka topics named `{topic.prefix}.{schema}.{table}`:

- `example.cd.members` — INSERT / UPDATE / DELETE on the `members` table
- `example.cd.facilities` — INSERT / UPDATE / DELETE on the `facilities` table
- `example.cd.bookings` — INSERT / UPDATE / DELETE on the `bookings` table

Consume events to verify:
```bash
docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka:9092 \
  --topic example.cd.members \
  --from-beginning
```
