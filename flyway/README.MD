# Flyway Database Migrations

Manages schema changes against the local Postgres container using [Flyway](https://flywaydb.org/).

Flyway runs as a one-shot service defined in the root `docker-compose.yml`. It is triggered automatically by `start.sh` after Postgres is healthy — you do not need to run it manually.

## Running migrations

From the **project root**:

```bash
./start.sh
```

Flyway runs as part of startup and exits after applying any pending migrations. To run it manually outside of `start.sh`:

```bash
# From the project root
docker compose run --rm flyway
```

## Adding a new migration

1. Create a new file in `flyway/migrations/` following the naming convention:

   ```
   V{version}__{description}.sql
   ```

   Examples:
   ```
  flyway/migrations/V4__add_product_tags.sql
  flyway/migrations/V5__add_user_roles.sql
   ```

2. Write your SQL (`CREATE TABLE`, `ALTER TABLE`, seed data, etc.)

3. Run `./start.sh` or `docker compose run --rm flyway` — Flyway only runs scripts it hasn't seen before.

4. Add a row to the **Migration history** table below.

> **Never edit an already-applied migration.** Flyway checksums each file; changes will cause a checksum mismatch error. Create a new versioned script instead.

## Useful commands

All commands run from the **project root**:

| Command | Description |
|---|---|
| `docker compose run --rm flyway migrate` | Apply pending migrations (default) |
| `docker compose run --rm flyway info` | Show migration status |
| `docker compose run --rm flyway validate` | Validate applied migrations match scripts |
| `docker compose run --rm flyway repair` | Fix checksum mismatches in the schema history table |
| `docker compose run --rm flyway clean` | **Drop all objects** — dev only, never production |

## Inspect applied migrations (pgAdmin or psql)

```sql
SELECT version, description, script, installed_on, success
FROM flyway_schema_history
ORDER BY installed_rank;
```

## Migration history

| Version | File | Description |
|---|---|---|
| V1 | `V1__init_schema.sql` | Initial `cd` schema — creates `members`, `facilities`, and `bookings` |
| V2 | `V2__seed_data.sql` | Seeds sample data for `cd` tables |
| V3 | `V3__replica_identity.sql` | Sets `REPLICA IDENTITY FULL` on CDC tables so Debezium captures full `before` values on UPDATE/DELETE |

## File structure

```
projects/                        # project root
  docker-compose.yml             # all services including Flyway
  start.sh                       # triggers Flyway as part of startup
  flyway/
    migrations/
      V1__init_schema.sql        # initial cd schema and tables
      V2__seed_data.sql          # sample data for cd schema
      V3__replica_identity.sql   # REPLICA IDENTITY FULL for CDC tables
    README.MD
```
