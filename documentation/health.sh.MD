# health.sh

## What it does

Runs a one-command health validation for the CDC environment.

The script verifies:

1. Docker daemon availability
2. Required containers are running (`some-postgres`, `kafka`, `debezium-connect`)
3. Postgres readiness
4. `wal_level=logical`
5. Connector state is `RUNNING`
6. Connector task state is `RUNNING`
7. Kafka expected topic exists for current scope (`TOPIC_PREFIX + first table from TABLE_INCLUDE_LIST`)
8. Replication slot `example_slot` activity (warn-only)

## How to use

From project root:

```bash
./health.sh
```

## What to look for

Success indicators:

- Green checks for each section
- Final line: `Health check passed`
- No red `[✗]` lines

Warn-only behavior:

- `Replication slot 'example_slot' is not active yet` can appear briefly after startup

## Troubleshooting

### Docker failure

Start Docker Desktop and rerun.

### Connector not RUNNING

Inspect connector details:

```bash
curl -s http://localhost:8083/connectors/example-connector/status | python3 -m json.tool
```

### Expected topic not found

Ensure stack startup completed and connector registered:

```bash
./start.sh
```

Then run `./health.sh` again.

Also verify your `.env` scope values:

```bash
TOPIC_PREFIX=...
TABLE_INCLUDE_LIST=schema.table,...
```
