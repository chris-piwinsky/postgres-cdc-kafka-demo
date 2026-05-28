# Persistent Kafka mode

## Purpose

By default, Kafka runs in tmpfs mode in `docker-compose.yml` for fast local demos. This mode is ephemeral.

Use `docker-compose.persist-kafka.yml` when you want Kafka topic data to survive container restarts and `docker compose down` (without `-v`).

## Files

- Base config: `docker-compose.yml` (tmpfs mode)
- Override config: `docker-compose.persist-kafka.yml` (persistent volumes)

## Start in persistent mode

```bash
docker compose -f docker-compose.yml -f docker-compose.persist-kafka.yml up -d db kafka connect
```

Run migrations and connector registration (if needed):

```bash
docker compose -f docker-compose.yml -f docker-compose.persist-kafka.yml run --rm flyway
source .env
envsubst < debezium/register-postgres.json.example \
  | curl -X POST -H "Content-Type: application/json" --data @- http://localhost:8083/connectors
```

## Stop in persistent mode

```bash
docker compose -f docker-compose.yml -f docker-compose.persist-kafka.yml down
```

## Fully remove persistent Kafka data

```bash
docker compose -f docker-compose.yml -f docker-compose.persist-kafka.yml down -v
```

This removes `kafka-data` and `kafka-meta` volumes.

## What to look for

1. Topic data persists across stop/start without `-v`
2. `docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka:9092` still shows your topics after restart
3. Offsets continue from previous values

## Troubleshooting

### `Topic not found` after restart

Ensure you did not run `down -v`, which removes persistent volumes.

### Compose override not taking effect

Always include both `-f docker-compose.yml -f docker-compose.persist-kafka.yml` in the same command.
