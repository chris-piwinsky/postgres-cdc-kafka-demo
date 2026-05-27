# demo/consume.sh

## What it does

Consumes CDC events from a scope-aware Kafka topic and formats output for human-readable demo viewing.

The script:

1. Starts Kafka console consumer from beginning of topic
2. Uses `jq` formatting if available
3. Prints operation label, source table, before/after payloads per event
4. Falls back to raw JSON output if `jq` is not installed
5. Selects topic from `.env` connector scope:
	- `TOPIC_PREFIX`
	- `TABLE_INCLUDE_LIST`

## How to use

From project root:

```bash
./demo/consume.sh
```

Optional table override for one run:

```bash
DEMO_TABLE=cd.members ./demo/consume.sh
```

Stop with `Ctrl+C`.

## What to look for

Success indicators:

- Startup banner `Kafka CDC Consumer`
- `Listening on topic: <topic-prefix>.<schema>.<table>`
- Formatted event blocks for each message

Expected operation codes:

- `c` -> INSERT
- `u` -> UPDATE
- `d` -> DELETE
- `r` -> READ (snapshot event)

Delete behavior:

- DELETE event shows `before` populated and `after` as `null`
- You may also see tombstone/null-style messages depending on topic/log compaction behavior

## Troubleshooting

### `jq not found`

Install jq for formatted output:

```bash
brew install jq
```

### No events displayed

Run producer/demo operations in another terminal:

```bash
./demo/run.sh
```

If your scope points to a different table topic, force the demo table topic:

```bash
DEMO_TABLE=cd.members ./demo/consume.sh
```

### Kafka command errors

Verify Kafka container is running:

```bash
docker ps | grep kafka
./health.sh
```
