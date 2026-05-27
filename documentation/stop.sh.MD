# stop.sh

## What it does

Stops running project services and frees Kafka port 9092.

The script:

1. Runs `docker compose down`
2. Waits for port 9092 to be released
3. Force-kills any remaining process using 9092 if needed
4. Leaves `postgres-data` volume intact

## How to use

From project root:

```bash
./stop.sh
```

## What to look for

Success indicators:

- `Stopping all services...`
- `All services stopped — port 9092 is free`
- Final note about preserved `postgres-data` volume

## Troubleshooting

### Port 9092 still in use

Script will force-kill processes after retries. If still blocked, identify process manually:

```bash
lsof -i :9092
```

### Need a full clean reset, not just stop

Use the reset workflow:

```bash
./reset.sh --yes
```
