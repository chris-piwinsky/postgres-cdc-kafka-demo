# CDC Demo

Demonstrates the full Postgres -> Debezium -> Kafka CDC pipeline by running INSERT, UPDATE, and DELETE operations against the `cd.members` table and streaming the resulting change events in real time.

## Prerequisites

The full stack must be running and the Debezium connector must be registered before starting the demo.

1. **Start the stack** (from the project root):

   ```bash
   ./start.sh
   ```

2. **Register the Debezium connector** (first time only):

   ```bash
   source .env
   envsubst < debezium/register-postgres.json.example \
     | curl -X POST -H "Content-Type: application/json" --data @- http://localhost:8083/connectors
   ```

3. **Verify the connector is RUNNING:**

   ```bash
   curl -s http://localhost:8083/connectors/example-connector/status | grep state
   ```

   Expected: `"state":"RUNNING"`

4. **Confirm demo table is in connector scope (`cd.members`):**

  In `.env`, ensure:

  ```bash
  TABLE_INCLUDE_LIST=cd.members,cd.facilities,cd.bookings
  ```

  If you changed scope values, rerun:

  ```bash
  ./start.sh
  ./health.sh
  ```

## Running the demo

You need two terminals open at the same time — one to watch events, one to produce them.

### Terminal 1 — start the consumer

```bash
./demo/consume.sh
```

By default, the consumer reads topic scope from `.env`:

- `TOPIC_PREFIX`
- `TABLE_INCLUDE_LIST`

It will follow `cd.members` when that table is included (recommended for this demo), otherwise it uses the first table in `TABLE_INCLUDE_LIST`.

You can force a specific table for a run:

```bash
DEMO_TABLE=cd.members ./demo/consume.sh
```

Debezium CDC events will appear here as JSON as each database operation is committed.

Leave this terminal open and running.

### Terminal 2 — run the demo script

```bash
./demo/run.sh
```

`./demo/run.sh` now performs a scope guard and exits early with a clear message if `cd.members` is not included in `TABLE_INCLUDE_LIST`.

The script will:

1. Check the Debezium connector is `RUNNING` — exits with an error and the register command if not
2. Delete any previous demo rows with `memid >= 100` (fully repeatable)
3. Prompt you to confirm Terminal 1 is ready
4. Run **3 iterations** of `INSERT → UPDATE → DELETE` with a 3-second pause between each step
5. Print the final table state when done

## What to expect

Each database operation produces a distinct Debezium event on the Kafka topic:

| Operation | `"op"` | `before`     | `after`      |
|-----------|--------|--------------|--------------|
| INSERT    | `"c"`  | `null`       | new row data |
| UPDATE    | `"u"`  | old row data | new row data |
| DELETE    | `"d"`  | old row data | `null`       |

> `before` is populated on UPDATE and DELETE because the `members` table has `REPLICA IDENTITY FULL` set (applied by Flyway migration `V3__replica_identity.sql`). Without it, `before` would always be `null`.

Example INSERT event (truncated):

```json
{
  "before": null,
  "after": {
    "memid": 101,
    "surname": "Demo1",
    "firstname": "User1",
    "address": "1 Demo Lane, Boston",
    "zipcode": 12345,
    "telephone": "555-000-0001",
    "recommendedby": null,
    "joindate": 1748217600000000
  },
  "op": "c",
  "source": { "db": "postgres", "schema": "cd", "table": "members" }
}
```

See [kafka/create.json](../kafka/create.json) and [kafka/update.json](../kafka/update.json) for full event envelope examples.

## Re-running the demo

The demo is fully repeatable. Just run `./demo/run.sh` again — it clears prior demo rows (`memid >= 100`) at the start of each run.

The consumer (`./demo/consume.sh`) uses `--from-beginning`, so it will also replay all previous events from the topic on each restart.

If you changed connector scope in `.env`, rerun `./start.sh` and then `./health.sh` before running the demo.
