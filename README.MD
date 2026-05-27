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
    - [demo/run.sh guide](documentation/demo-run.sh.MD)
    - [demo/consume.sh guide](documentation/demo-consume.sh.MD)
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

Stops all containers. The `postgres-data` volume is preserved. To fully reset:

```bash
./reset.sh --yes
```

## Health check

Run a full infrastructure health check:

```bash
./health.sh
```

What it verifies:

1. Docker daemon is running
2. Required containers are running (`some-postgres`, `kafka`, `debezium-connect`)
3. Postgres is ready and `wal_level=logical`
4. Debezium connector and task are both `RUNNING`
5. Expected Kafka topic exists for the current scope (derived from `TOPIC_PREFIX` + first entry in `TABLE_INCLUDE_LIST`)
6. Replication slot (`example_slot`) is active (warn-only if temporarily inactive)

What success looks like:

- Script ends with `Health check passed`
- No red `[✗]` lines

What failure looks like:

- Script exits non-zero
- First failing check is printed with a red `[✗]` line

## Full reset

Run a destructive clean reset (recommended before fresh demos):

```bash
./reset.sh
```

What it does:

1. Stops and removes compose resources (`down -v --remove-orphans`)
2. Frees ports 9092, 5431, and 8083
3. Deletes `postgres-data` volume
4. Recreates an empty `postgres-data` volume
5. Starts the stack again by calling `./start.sh` (default)

Useful options:

```bash
./reset.sh --yes       # skip confirmation prompt
./reset.sh --no-start  # clean reset but keep services stopped
```

How to confirm reset worked:

```bash
./health.sh
```

Expected result: all checks pass and connector status is `RUNNING`.

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

This script:
1. Verifies the Debezium connector is `RUNNING` (exits with a clear error if not)
2. Removes any leftover demo members from a previous run (makes the demo fully repeatable)
3. Pauses and prompts you to confirm the consumer terminal is open
4. Runs 3 iterations of `INSERT → UPDATE → DELETE`, with a 3-second pause between each so you can watch events appear in Terminal 1 in real time
5. Prints the final table state

Each operation produces a distinct Debezium event:

| Operation | `"op"` | `before` | `after` |
|-----------|--------|----------|---------|
| INSERT    | `"c"`  | `null`   | new row |
| UPDATE    | `"u"`  | old row  | new row |
| DELETE    | `"d"`  | old row  | `null`  |

See [kafka/README.MD](kafka/README.MD) for full CDC event payload documentation.

## Useful Postgres queries

See [documentation/useful-postgres-queries.MD](documentation/useful-postgres-queries.MD) for full query list and examples.

## Script documentation

- [Architecture and troubleshooting guide](documentation/architecture-troubleshooting.MD)
- [start.sh guide](documentation/start.sh.MD)
- [stop.sh guide](documentation/stop.sh.MD)
- [health.sh guide](documentation/health.sh.MD)
- [reset.sh guide](documentation/reset.sh.MD)
- [demo/run.sh guide](documentation/demo-run.sh.MD)
- [demo/consume.sh guide](documentation/demo-consume.sh.MD)
- [Useful Postgres queries guide](documentation/useful-postgres-queries.MD)

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

### Developer experience

- Add startup flow and CDC flow diagrams to speed up onboarding in additional docs and presentations.

### Operations and observability

- Add helper commands/scripts for replication slot lag, connector task errors, and topic offset visibility.
- Add an optional persistent Kafka storage mode (compose override) alongside current tmpfs mode.
- Add Debezium tuning profile documentation (snapshot mode, polling, batch size, heartbeat) for larger datasets.

### Demo extensions

- Add a second consumer example that demonstrates idempotent upsert processing keyed by `memid`.
- Add optional event replay and deduplication walkthrough notes for downstream consumer patterns.

### Suggested implementation order

1. CI smoke test
2. Observability helpers
3. Persistent Kafka mode option
