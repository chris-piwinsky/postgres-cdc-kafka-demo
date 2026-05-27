# reset.sh

## What it does

Performs a destructive local reset to return the demo to a known-clean state.

The script:

1. Confirms Docker is running
2. Prompts before destructive changes (unless `--yes`)
3. Runs `docker compose down -v --remove-orphans`
4. Frees ports 9092, 5431, 8083
5. Removes `postgres-data` volume
6. Recreates clean `postgres-data` volume
7. Restarts stack with `./start.sh` (default)

## How to use

Interactive reset with restart:

```bash
./reset.sh
```

Non-interactive reset with restart:

```bash
./reset.sh --yes
```

Reset only, keep services stopped:

```bash
./reset.sh --yes --no-start
```

## What to look for

Success indicators:

- `Compose resources removed`
- `Ports 9092, 5431, and 8083 are free`
- `Removed postgres-data volume` (or warning that it did not exist)
- `Created clean postgres-data volume`
- `Reset complete and environment restarted` (default mode)

Post-reset verification:

```bash
./health.sh
```

## Troubleshooting

### Reset cancelled unexpectedly

If you skipped confirmation by mistake, use explicit flags:

```bash
./reset.sh --yes
```

### Docker errors during down/volume operations

Check Docker daemon status and rerun.

### Want reset without auto-start

Use:

```bash
./reset.sh --no-start
```
