# demo/run.sh

## What it does

Executes a guided CDC demo against `cd.members`.

The script:

1. Verifies connector is `RUNNING`
2. Verifies `cd.members` is included in `TABLE_INCLUDE_LIST`
3. Clears previous demo rows (`memid >= 100`)
4. Waits for user confirmation after consumer is open
5. Runs 3 iterations of INSERT -> UPDATE -> DELETE
6. Shows final table state (expected empty for demo rows)

## How to use

Terminal 1:

```bash
./demo/consume.sh
```

Terminal 2:

```bash
./demo/run.sh
```

Required `.env` scope for this demo script:

```bash
TABLE_INCLUDE_LIST=cd.members,cd.facilities,cd.bookings
```

## What to look for

Success indicators in run script:

- `Demo scope check passed: cd.members is included`
- `Connector is RUNNING`
- `Demo members cleared`
- Iteration logs show inserted, updated, deleted
- Final query prints no rows for `memid >= 100`

Success indicators in consumer terminal:

- INSERT events with `op: "c"`
- UPDATE events with `op: "u"`
- DELETE events with `op: "d"` and deleted row in `before`

## Troubleshooting

### Connector not RUNNING

Start stack and verify status:

```bash
./start.sh
curl -s http://localhost:8083/connectors/example-connector/status | grep state
```

### No events appear in consumer terminal

Confirm consumer is running and following the same scope as your demo writes. The simplest option is:

```bash
DEMO_TABLE=cd.members ./demo/consume.sh
```

### `cd.members is not in TABLE_INCLUDE_LIST` error

Update `.env` to include `cd.members`, then restart and recheck:

```bash
./start.sh
./health.sh
./demo/run.sh
```

### SQL command failures in script

Ensure Postgres container is running and healthy:

```bash
docker ps | grep some-postgres
./health.sh
```
