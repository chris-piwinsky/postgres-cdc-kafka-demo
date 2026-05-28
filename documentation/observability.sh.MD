# observability.sh

## What it does

Runs operator-focused checks for CDC visibility and troubleshooting.

Supported checks:

1. Replication slot lag (`example_slot`) and retained WAL
2. Connector/task status and task error traces
3. Topic offset visibility (earliest/latest)

## How to use

Run all checks:

```bash
./observability.sh
```

Run a single check:

```bash
./observability.sh slot-lag
./observability.sh connector-errors
./observability.sh topic-offsets
```

Optional topic table override:

```bash
OBS_TOPIC_TABLE=cd.members ./observability.sh topic-offsets
```

## What to look for

### Replication slot lag

- `active=true` is typical while connector is actively streaming
- `retained_wal` should not grow unbounded over time

### Connector errors

- `connector.state=RUNNING`
- Task objects show `state: RUNNING`
- `trace` field should be empty or absent

### Topic offsets

- Earliest/latest offsets should be visible for your scoped topic
- Latest offsets should increase after running `./demo/run.sh`

## Troubleshooting

### `Docker is not running`

Start Docker Desktop and retry.

### Topic not found

Verify connector scope and startup:

```bash
./start.sh
./health.sh
```

### Connector not RUNNING

Inspect status and logs:

```bash
curl -s http://localhost:8083/connectors/example-connector/status | python3 -m json.tool
docker logs debezium-connect
```
