# start.sh

## What it does

Starts the full local CDC stack and prepares it for demos.

The script:

1. Loads `.env`
2. Verifies Docker is running
3. Ensures `postgres-data` volume exists
4. Frees Kafka port 9092 when needed
5. Starts `db`, `kafka`, and `connect`
6. Waits for Postgres readiness
7. Verifies `wal_level=logical`
8. Runs Flyway migrations
9. Waits for Debezium Connect API
10. Registers connector if missing
11. Prints service status summary

## How to use

From project root:

```bash
./start.sh
```

Optional connector scope in `.env`:

```bash
TOPIC_PREFIX=example
TABLE_INCLUDE_LIST=cd.members,cd.facilities,cd.bookings
```

## What to look for

Success indicators:

- `Postgres is ready`
- `wal_level = logical (streaming ready)`
- `Debezium Connect is ready`
- `Debezium connector is RUNNING`
- `Connector scope: topic.prefix=...`
- `Connector scope: table.include.list=...`
- Status section shows Postgres, Kafka, and Debezium as running

## Troubleshooting

### `.env not found`

Create env file first:

```bash
cp .env.example .env
```

### Docker not running

Start Docker Desktop, then re-run `./start.sh`.

### Connector not RUNNING

Check connector status and logs:

```bash
curl -s http://localhost:8083/connectors/example-connector/status | python3 -m json.tool
docker logs debezium-connect
```

### Startup completes but topic missing

Run health validation:

```bash
./health.sh
```
