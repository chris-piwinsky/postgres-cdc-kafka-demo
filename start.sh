#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${YELLOW}[~]${NC} $1"; }

echo ""
echo "=== Starting POC Infrastructure ==="
echo ""

# Load .env so DB_PASSWORD is available for envsubst when registering the connector.
# docker compose reads .env automatically, but the shell script needs it explicitly.
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck source=.env
  set -a; source "$SCRIPT_DIR/.env"; set +a
else
  fail ".env not found — copy .env.example to .env and fill in values"
fi

# 1. Check Docker is running
info "Checking Docker..."
docker info > /dev/null 2>&1 || fail "Docker is not running. Start Docker Desktop and try again."
ok "Docker is running"

# 2. Ensure postgres-data volume exists
info "Checking postgres-data volume..."
if ! docker volume inspect postgres-data > /dev/null 2>&1; then
  info "Volume not found — creating postgres-data..."
  docker volume create postgres-data
  ok "Created postgres-data volume"
else
  ok "postgres-data volume exists"
fi

# 3. Clear port 9092 if something is squatting on it
KAFKA_STATUS=$(docker inspect -f '{{.State.Status}}' kafka 2>/dev/null || echo "not found")
if [[ "$KAFKA_STATUS" != "running" ]]; then
  info "Cleaning up any existing Kafka container..."
  docker compose down 2>/dev/null || true

  info "Checking port 9092..."
  if lsof -ti :9092 > /dev/null 2>&1; then
    info "Port 9092 in use — killing processes..."
    lsof -ti :9092 | xargs kill -9
    sleep 1
    ok "Port 9092 cleared"
  else
    ok "Port 9092 is free"
  fi
fi

# 4. Start all long-running services (db, kafka, connect)
info "Starting services..."
docker compose up -d db kafka connect
ok "Services started"

# 5. Wait for Postgres to be healthy
info "Waiting for Postgres to be ready..."
RETRIES=15
until docker exec some-postgres pg_isready -U postgres > /dev/null 2>&1; do
  RETRIES=$((RETRIES - 1))
  if [[ $RETRIES -eq 0 ]]; then
    fail "Postgres did not become ready in time. Check: docker logs some-postgres"
  fi
  sleep 2
done
ok "Postgres is ready"

# Verify wal_level is logical (required for data streaming)
WAL_LEVEL=$(docker exec some-postgres psql -U postgres -tAc "SHOW wal_level;" 2>/dev/null | tr -d '[:space:]')
if [[ "$WAL_LEVEL" == "logical" ]]; then
  ok "wal_level = logical (streaming ready)"
else
  fail "wal_level is '$WAL_LEVEL' — expected 'logical'. Check docker-compose.yml db command flag."
fi

# 6. Run Flyway migrations
info "Running Flyway migrations..."
docker compose run --rm flyway
ok "Flyway migrations applied"

# 7. Wait for Debezium Connect REST API to be ready
info "Waiting for Debezium Connect to be ready..."
RETRIES=30
until curl -sf http://localhost:8083/connectors > /dev/null 2>&1; do
  RETRIES=$((RETRIES - 1))
  if [[ $RETRIES -eq 0 ]]; then
    fail "Debezium Connect did not become ready in time. Check: docker logs debezium-connect"
  fi
  sleep 2
done
ok "Debezium Connect is ready"

# 8. Register Debezium connector (skip if already registered)
CONNECTOR_EXISTS=$(curl -sf http://localhost:8083/connectors/example-connector 2>/dev/null && echo "yes" || echo "no")
if [[ "$CONNECTOR_EXISTS" == "yes" ]]; then
  ok "Debezium connector already registered — skipping"
else
  info "Registering Debezium connector..."
  # envsubst substitutes ${DB_PASSWORD} in the template at runtime.
  # The secret comes from .env and is never written to a committed file.
  RESPONSE=$(envsubst < "$SCRIPT_DIR/debezium/register-postgres.json.example" \
    | curl -sf -X POST \
      -H "Content-Type: application/json" \
      -d @- \
      http://localhost:8083/connectors 2>&1) || fail "Failed to register connector. Check: docker logs debezium-connect"
  ok "Debezium connector registered"
fi

# Verify connector is RUNNING
CONNECTOR_STATE=$(curl -sf http://localhost:8083/connectors/example-connector/status 2>/dev/null \
  | grep -o '"state":"[^"]*"' | head -1 | grep -o '[^"]*"$' | tr -d '"' || echo "UNKNOWN")
if [[ "$CONNECTOR_STATE" == "RUNNING" ]]; then
  ok "Debezium connector is RUNNING"
else
  echo -e "${RED}[✗]${NC} Connector state: $CONNECTOR_STATE — check: curl http://localhost:8083/connectors/example-connector/status"
fi

# 9. Status summary
echo ""
echo "=== Infrastructure Status ==="
echo ""

POSTGRES_STATUS=$(docker inspect -f '{{.State.Status}}' some-postgres 2>/dev/null || echo "not found")
KAFKA_STATUS=$(docker inspect -f '{{.State.Status}}' kafka 2>/dev/null || echo "not found")
CONNECT_STATUS=$(docker inspect -f '{{.State.Status}}' debezium-connect 2>/dev/null || echo "not found")

[[ "$POSTGRES_STATUS" == "running" ]] && ok "Postgres         (some-postgres)    — localhost:5431" || echo -e "${RED}[✗]${NC} Postgres  — $POSTGRES_STATUS"
[[ "$KAFKA_STATUS"    == "running" ]] && ok "Kafka            (kafka)            — localhost:9092" || echo -e "${RED}[✗]${NC} Kafka     — $KAFKA_STATUS"
[[ "$CONNECT_STATUS" == "running" ]] && ok "Debezium Connect (debezium-connect) — localhost:8083" || echo -e "${RED}[✗]${NC} Connect  — $CONNECT_STATUS"
ok "Flyway           migrations applied"
[[ "$CONNECTOR_STATE" == "RUNNING" ]] && ok "Connector        (example-connector) — RUNNING" || echo -e "${RED}[✗]${NC} Connector — $CONNECTOR_STATE"

echo ""
