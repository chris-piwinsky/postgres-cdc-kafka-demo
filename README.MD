# POC Infrastructure

A local event-driven streaming environment using Postgres, Kafka, Debezium CDC, and Flyway schema migrations — all orchestrated via a single Docker Compose file.

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
docker compose down -v
docker volume rm postgres-data
```

## Configuration

Copy `.env.example` to `.env` and fill in your values before running `./start.sh`:

```bash
cp .env.example .env
```

`.env` is gitignored and must never be committed. The connector password is read from `DB_PASSWORD` at runtime via `envsubst` — it is never written to a committed file.

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

Connect to the running Postgres container:

```bash
docker exec -ti some-postgres psql -U postgres
```

**Verify WAL and replication settings** (required for CDC):

```sql
SELECT name, setting
FROM pg_settings
WHERE name IN ('wal_level', 'max_wal_senders', 'max_replication_slots');
```

**Check active replication slots** (Debezium creates one on first connect):

```sql
SELECT slot_name, plugin, database, active, restart_lsn
FROM pg_replication_slots;
```

**Check publications** (Debezium creates a publication for the tables it tracks):

```sql
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables;
```

**Check replica identity on a table** (must be `f` = FULL for UPDATE/DELETE `before` values):

```sql
SELECT relname, relreplident
FROM pg_class
WHERE relname IN ('members', 'facilities', 'bookings');
```

`relreplident` values: `d` = default (primary key only), `f` = full (all columns), `n` = nothing.

**Inspect Flyway migration history**:

```sql
SELECT version, description, success, installed_on
FROM flyway_schema_history
ORDER BY installed_rank;
```

**Inspect table data**:

```sql
SELECT memid, surname, firstname, address FROM cd.members LIMIT 10;
```

**Insert a test row** (triggers a CDC event on the Kafka topic):

```sql
INSERT INTO cd.members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate)
VALUES (999, 'TestUser', 'Local', '1 Test Street, Boston', 12345, '555-000-0001', NULL, NOW());
```

**Update a row** (triggers a CDC UPDATE event; `before` is populated because of `REPLICA IDENTITY FULL`):

```sql
UPDATE cd.members SET address = '2 New Street, Boston' WHERE memid = 999;
```

## Links

- [Conduktor Learn](https://docs.conduktor.io/learn)
- [Kafka Quickstart](https://kafka.apache.org/quickstart/)
- [Stream Processing](https://blog.devgenius.io/what-is-stream-processing-7fcb561e65d9)
- [Postgres CDC with Debezium: Complete tutorial](https://blog.sequinstream.com/postgres-cdc-with-debezium-complete-step-by-step-tutorial/)
- [Beyond the Basics of Debezium for PostgreSQL — Part 1](https://medium.com/@arijit.mazumdar/beyond-the-basics-of-debezium-for-postgresql-part-1-d1c6952ae110)
- [What is Apache Kafka and how does it work?](https://stanislavkozlovski.medium.com/what-is-apache-kafka-and-how-does-it-work-16023aa2efee)
- [How to start Kafka using Docker](https://docs.conduktor.io/learn/getting-started/docker-setup)
- [Kafka — Building a beginner-friendly Kafka project](https://medium.com/devtechie/kafka-building-a-beginner-friendly-kafka-project-2fb0437efcb6)
