# Debezium tuning profiles

## Goal

Provide practical starter profiles for larger datasets and higher write rates.

These settings belong in the connector config (`debezium/register-postgres.json.example`) under `config`.

## Baseline profile (dev/demo)

Use defaults plus explicit `pgoutput` and filtered publication.

```json
{
  "plugin.name": "pgoutput",
  "publication.autocreate.mode": "filtered"
}
```

## Throughput profile (larger datasets)

Use when ingest volume is moderate/high and you want better throughput.

```json
{
  "snapshot.mode": "initial",
  "poll.interval.ms": "1000",
  "max.batch.size": "2048",
  "max.queue.size": "8192",
  "heartbeat.interval.ms": "10000"
}
```

## Low-latency profile (faster event pickup)

Use when lower end-to-end latency matters more than max throughput.

```json
{
  "snapshot.mode": "initial",
  "poll.interval.ms": "250",
  "max.batch.size": "512",
  "max.queue.size": "2048",
  "heartbeat.interval.ms": "5000"
}
```

## Snapshot strategy guidance

- `initial`: take a startup snapshot, then stream changes
- `never`: skip snapshot; stream only new WAL changes (requires existing snapshot strategy elsewhere)
- `initial_only`: snapshot and stop after snapshot

## Recommended starting points

1. Start with throughput profile for bigger tables
2. Monitor slot lag with `./observability.sh slot-lag`
3. If lag grows, increase `max.batch.size` and `max.queue.size`
4. If latency is too high, reduce `poll.interval.ms`

## Validation checklist

After changing connector tuning settings:

1. Re-register connector (or update via Connect API)
2. Run `./health.sh`
3. Run `./observability.sh connector-errors`
4. Run `./observability.sh topic-offsets`
5. Execute `./demo/run.sh` and confirm offsets advance

## Cautions

- Very low `poll.interval.ms` can increase CPU usage
- Very high queue/batch settings can increase memory usage
- Keep `REPLICA IDENTITY FULL` where full `before` images are required
