# CDC Demo

Demonstrates the full Postgres → Debezium → Kafka CDC pipeline by running INSERT, UPDATE, and DELETE operations against the `customers` table and streaming the resulting change events in real time.

## Prerequisites

The full stack must be running and the Debezium connector must be registered before starting the demo.

1. **Start the stack** (from the project root):

   ```bash
   ./start.sh
   ```

2. **Register the Debezium connector** (first time only):

   ```bash
   cd debezium
   curl -X POST -H "Content-Type: application/json" \
     -d @register-postgres.json \
     http://localhost:8083/connectors
   ```

3. **Verify the connector is RUNNING:**

   ```bash
   curl -s http://localhost:8083/connectors/example-connector/status | grep state
   ```

   Expected: `"state":"RUNNING"`

## Running the demo

You need two terminals open at the same time — one to watch events, one to produce them.

### Terminal 1 — start the consumer

```bash
./demo/consume.sh
```

This listens on the `example.public.customers` Kafka topic from the beginning. Debezium CDC events will appear here as JSON as each database operation is committed.

Leave this terminal open and running.

### Terminal 2 — run the demo script

```bash
./demo/run.sh
```

The script will:

1. Check the Debezium connector is `RUNNING` — exits with an error and the register command if not
2. Truncate the `customers` table and reset the id sequence (fully repeatable)
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

> `before` is populated on UPDATE and DELETE because the `customers` table has `REPLICA IDENTITY FULL` set (applied by Flyway migration `V2__replica_identity.sql`). Without it, `before` would always be `null`.

Example INSERT event (truncated):

```json
{
  "payload": {
    "before": null,
    "after": { "id": 1, "name": "User1", "email": "user1@example.com" },
    "op": "c",
    "source": { "db": "postgres", "table": "customers" }
  }
}
```

See [kafka/create.json](../kafka/create.json) and [kafka/update.json](../kafka/update.json) for full event envelope examples.

## Re-running the demo

The demo is fully repeatable. Just run `./demo/run.sh` again — it truncates the table and resets the id sequence at the start of each run.

The consumer (`./demo/consume.sh`) uses `--from-beginning`, so it will also replay all previous events from the topic on each restart.
