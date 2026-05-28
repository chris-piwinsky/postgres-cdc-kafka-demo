# POC Infrastructure

A local event-driven streaming environment using Postgres, Kafka, Debezium CDC, and Flyway schema migrations — all orchestrated via a single Docker Compose file.

## Table of contents

- [Architecture](#architecture)
- [Architecture and troubleshooting guide](#architecture-and-troubleshooting-guide)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Stop everything](#stop-everything)
- [Health check](#health-check)
- [Full reset](#full-reset)
- [Observability helper](#observability-helper)
- [Persistent Kafka mode](#persistent-kafka-mode)
- [Debezium tuning profiles](#debezium-tuning-profiles)
- [Configuration](#configuration)
- [Adding a schema migration](#adding-a-schema-migration)
- [Registering a Debezium connector](#registering-a-debezium-connector)
- [Demo quick checklist](#demo-quick-checklist)
- [Demo](#demo)
- [Useful Postgres queries](#useful-postgres-queries)
- [Useful Postgres queries guide](documentation/useful-postgres-queries.MD)
- [Script documentation](#script-documentation)
    - [Architecture and troubleshooting guide](documentation/architecture-troubleshooting.MD)
    - [start.sh guide](documentation/start.sh.MD)
    - [stop.sh guide](documentation/stop.sh.MD)
    - [health.sh guide](documentation/health.sh.MD)
    - [reset.sh guide](documentation/reset.sh.MD)
    - [observability.sh guide](documentation/observability.sh.MD)
    - [demo/run.sh guide](documentation/demo-run.sh.MD)
    - [demo/consume.sh guide](documentation/demo-consume.sh.MD)
    - [Persistent Kafka mode guide](documentation/kafka-persistent-mode.MD)
    - [Debezium tuning profiles](documentation/debezium-tuning-profiles.MD)
- [Links](#links)
- [Future improvements](#future-improvements)
## Architecture

```
┌─────────────────┐        ┌─────────────────┐
│   PostgreSQL    │──CDC──▶│ Debezium Connect│
│   port 5431     │        │   port 8083     │
│ wal_level=logical│       └────────┬────────┘
└────────┬────────┘                 │
         │                          ▼
         │ Flyway            ┌─────────────────┐
         │ migrations        │     Kafka       │
         └──────────────────▶│   port 9092     │
                             └─────────────────┘
```

| Service          | Image                        | Port  | Purpose                           |
|------------------|------------------------------|-------|-----------------------------------|
| `db`             | postgres:17.0                | 5431  | Source database                   |
| `kafka`          | apache/kafka:4.2.0           | 9092  | Event streaming broker            |
| `connect`        | debezium/connect:3.1         | 8083  | CDC connector (Postgres → Kafka)  |
| `flyway`         | flyway/flyway:11             | —     | Schema migration runner (one-shot)|

## Architecture and troubleshooting guide

- [Architecture and troubleshooting guide](documentation/architecture-troubleshooting.MD)

## Prerequisites

- Docker Desktop running
- `postgres-data` volume (created automatically by `start.sh` if missing)
- `.env` file at the project root (see Configuration below)

## Quick start

```bash
cp .env.example .env
# edit .env and set DB_PASSWORD to something secure
./start.sh
```

This will:
1. Fail fast if `.env` is missing
2. Create the `postgres-data` volume if it doesn't exist
3. Clear port 9092 if something is already using it
4. Start Postgres, Kafka, and Debezium Connect
5. Wait for Postgres to be healthy
6. Verify `wal_level = logical` (required for CDC)
7. Run Flyway migrations
8. Wait for the Debezium Connect REST API to be ready
9. Register the Debezium connector (skipped if already registered)
10. Print a status summary

## Stop everything

```bash
./stop.sh
```

Stops all containers. `postgres-data` is preserved.

For full behavior and troubleshooting, see [documentation/stop.sh.MD](documentation/stop.sh.MD).

To fully reset instead of stop:

```bash
./reset.sh --yes
```

## Health check

Run a full infrastructure health check:

```bash
./health.sh
```

Quick success signal:

- Script ends with `Health check passed`

For full checks list, warnings, and troubleshooting, see [documentation/health.sh.MD](documentation/health.sh.MD).

## Full reset

Run a destructive clean reset (recommended before fresh demos):

```bash
./reset.sh
```

Useful options:

```bash
./reset.sh --yes       # skip confirmation prompt
./reset.sh --no-start  # clean reset but keep services stopped
```

To confirm reset worked:

```bash
./health.sh
```

For full reset behavior and troubleshooting, see [documentation/reset.sh.MD](documentation/reset.sh.MD).

## Observability helper

Use `observability.sh` to inspect CDC runtime behavior:

```bash
./observability.sh
```

Useful focused commands:

```bash
./observability.sh slot-lag
./observability.sh connector-errors
./observability.sh topic-offsets
```

For full usage and interpretation guidance, see [documentation/observability.sh.MD](documentation/observability.sh.MD).

## Persistent Kafka mode

Default mode uses tmpfs (ephemeral Kafka data). Optional persistent mode is available with compose override:

```bash
docker compose -f docker-compose.yml -f docker-compose.persist-kafka.yml up -d db kafka connect
```

For full lifecycle commands and caveats, see [documentation/kafka-persistent-mode.MD](documentation/kafka-persistent-mode.MD).

## Debezium tuning profiles

Tuning guidance for larger datasets is documented in:

- [documentation/debezium-tuning-profiles.MD](documentation/debezium-tuning-profiles.MD)

Includes recommended profiles for:

- Snapshot behavior (`snapshot.mode`)
- Poll cadence (`poll.interval.ms`)
- Throughput sizing (`max.batch.size`, `max.queue.size`)
- Liveness (`heartbeat.interval.ms`)

## Configuration

Copy `.env.example` to `.env` and fill in your values before running `./start.sh`:

```bash
cp .env.example .env
```

`.env` is gitignored and must never be committed. The connector password is read from `DB_PASSWORD` at runtime via `envsubst` — it is never written to a committed file.

Connector scope is configurable via `.env`:

```bash
TOPIC_PREFIX=example
TABLE_INCLUDE_LIST=cd.members,cd.facilities,cd.bookings
```

Example topic names produced:

- `example.cd.members`
- `example.cd.facilities`
- `example.cd.bookings`

If you change scope values, rerun:

```bash
./start.sh
./health.sh
```

## Adding a schema migration

Create a new versioned SQL file in `flyway/migrations/`:

```
flyway/migrations/V2__add_my_table.sql
```

Then run:

```bash
docker compose run --rm flyway
```

See [flyway/README.MD](flyway/README.MD) for more details.

## Registering a Debezium connector

Once the stack is running, POST a connector config to:

```
http://localhost:8083/connectors
```

Check connector status:

```bash
curl http://localhost:8083/connectors
```

## Demo quick checklist

Before running the demo, confirm these are true:

1. `./start.sh` completed successfully
2. `./health.sh` reports `Health check passed`
3. `.env` includes the demo table in scope:

```bash
TABLE_INCLUDE_LIST=cd.members,cd.facilities,cd.bookings
```

4. Connector status is `RUNNING`:

```bash
curl -s http://localhost:8083/connectors/example-connector/status | grep state
```

For full demo usage and expected output, see [demo/README.MD](demo/README.MD).

## Demo

Once the stack is running and the Debezium connector is registered, you can watch the full CDC pipeline in action using two terminals.

**Terminal 1 — start the Kafka consumer:**

```bash
./demo/consume.sh
```

Listens on the `example.cd.members` topic from the beginning. CDC events will print here as JSON as they arrive.

**Terminal 2 — run the demo:**

```bash
./demo/run.sh
```

For full run instructions, topic-scope behavior, expected events, and troubleshooting, see [demo/README.MD](demo/README.MD).

## Useful Postgres queries

See [documentation/useful-postgres-queries.MD](documentation/useful-postgres-queries.MD) for full query list and examples.

## Script documentation

- [Architecture and troubleshooting guide](documentation/architecture-troubleshooting.MD)
- [start.sh guide](documentation/start.sh.MD)
- [stop.sh guide](documentation/stop.sh.MD)
- [health.sh guide](documentation/health.sh.MD)
- [reset.sh guide](documentation/reset.sh.MD)
- [observability.sh guide](documentation/observability.sh.MD)
- [demo/run.sh guide](documentation/demo-run.sh.MD)
- [demo/consume.sh guide](documentation/demo-consume.sh.MD)
- [Useful Postgres queries guide](documentation/useful-postgres-queries.MD)
- [Persistent Kafka mode guide](documentation/kafka-persistent-mode.MD)
- [Debezium tuning profiles](documentation/debezium-tuning-profiles.MD)

## Links

- [Conduktor Learn](https://docs.conduktor.io/learn)
- [Kafka Quickstart](https://kafka.apache.org/quickstart/)
- [Stream Processing](https://blog.devgenius.io/what-is-stream-processing-7fcb561e65d9)
- [Postgres CDC with Debezium: Complete tutorial](https://blog.sequinstream.com/postgres-cdc-with-debezium-complete-step-by-step-tutorial/)
- [Beyond the Basics of Debezium for PostgreSQL — Part 1](https://medium.com/@arijit.mazumdar/beyond-the-basics-of-debezium-for-postgresql-part-1-d1c6952ae110)
- [What is Apache Kafka and how does it work?](https://stanislavkozlovski.medium.com/what-is-apache-kafka-and-how-does-it-work-16023aa2efee)
- [How to start Kafka using Docker](https://docs.conduktor.io/learn/getting-started/docker-setup)
- [Kafka — Building a beginner-friendly Kafka project](https://medium.com/devtechie/kafka-building-a-beginner-friendly-kafka-project-2fb0437efcb6)

## Future improvements

Backlog ideas to improve reliability, learning value, and production-readiness over time.

### Operations and observability

- Add consumer group lag visibility and alert thresholds to observability docs.

### Demo extensions

- Add a second consumer example that demonstrates idempotent upsert processing keyed by `memid`.
- Add optional event replay and deduplication walkthrough notes for downstream consumer patterns.

### Suggested implementation order

1. CI smoke test
2. Observability helpers
3. Persistent Kafka mode option
