#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[~]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Load optional connector scope from .env so topic checks match current configuration.
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck source=.env
  set -a; source "$SCRIPT_DIR/.env"; set +a
fi

TOPIC_PREFIX="${TOPIC_PREFIX:-example}"
TABLE_INCLUDE_LIST="${TABLE_INCLUDE_LIST:-cd.members,cd.facilities,cd.bookings}"
FIRST_TABLE="${TABLE_INCLUDE_LIST%%,*}"

[[ -n "$FIRST_TABLE" ]] || fail "TABLE_INCLUDE_LIST is empty. Set it in .env."
expected_topic="${TOPIC_PREFIX}.${FIRST_TABLE}"

get_container_status() {
  docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null || echo "not found"
}

echo ""
echo "=== POC Health Check ==="
echo ""

# 1. Docker
warn "Checking Docker daemon..."
docker info > /dev/null 2>&1 || fail "Docker is not running. Start Docker Desktop and retry."
ok "Docker is running"

# 2. Containers
warn "Checking required containers..."
for pair in "some-postgres:Postgres" "kafka:Kafka" "debezium-connect:Debezium Connect"; do
  container_name="${pair%%:*}"
  pretty_name="${pair##*:}"
  status="$(get_container_status "$container_name")"
  if [[ "$status" == "running" ]]; then
    ok "$pretty_name container is running"
  else
    fail "$pretty_name container is '$status'. Run ./start.sh first."
  fi
done

# 3. Postgres readiness + WAL setting
warn "Checking Postgres readiness..."
docker exec some-postgres pg_isready -U postgres > /dev/null 2>&1 || fail "Postgres is not ready."
ok "Postgres is ready"

wal_level="$(docker exec some-postgres psql -U postgres -tAc "SHOW wal_level;" 2>/dev/null | tr -d '[:space:]')"
[[ "$wal_level" == "logical" ]] || fail "wal_level is '$wal_level' (expected logical)."
ok "wal_level is logical"

# 4. Debezium connector status
warn "Checking Debezium connector status..."
connector_status_json="$(curl -sf http://localhost:8083/connectors/example-connector/status 2>/dev/null)" \
  || fail "Cannot read connector status from http://localhost:8083"

connector_state="$(printf '%s' "$connector_status_json" | grep -o '"state":"[^"]*"' | head -1 | cut -d '"' -f4 || true)"
[[ "$connector_state" == "RUNNING" ]] || fail "Connector state is '$connector_state' (expected RUNNING)."
ok "Connector state is RUNNING"

task_state="$(printf '%s' "$connector_status_json" | grep -o '"tasks":\[[^]]*\]' | grep -o '"state":"[^"]*"' | head -1 | cut -d '"' -f4 || true)"
if [[ "$task_state" == "RUNNING" ]]; then
  ok "Connector task state is RUNNING"
else
  fail "Connector task state is '$task_state' (expected RUNNING)."
fi

# 5. Topic availability
warn "Checking Kafka topic availability..."
topics="$(docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka:9092 2>/dev/null)" \
  || fail "Unable to list Kafka topics from broker."

printf '%s\n' "$topics" | grep -qx "$expected_topic" \
  || fail "Expected topic '$expected_topic' not found."
ok "Topic '$expected_topic' exists"

# Optional but useful: replication slot health
slot_active="$(docker exec some-postgres psql -U postgres -tAc "SELECT active FROM pg_replication_slots WHERE slot_name='example_slot' LIMIT 1;" 2>/dev/null | tr -d '[:space:]')"
if [[ "$slot_active" == "true" ]]; then
  ok "Replication slot 'example_slot' is active"
else
  warn "Replication slot 'example_slot' is not active yet (this can happen briefly after startup)."
fi

echo ""
ok "Health check passed"
echo ""
echo "Next checks you can run manually:"
echo "  ./demo/run.sh"
echo "  ./demo/consume.sh"
echo ""
