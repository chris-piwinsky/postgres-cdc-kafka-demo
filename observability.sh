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

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck source=.env
  set -a; source "$SCRIPT_DIR/.env"; set +a
fi

TOPIC_PREFIX="${TOPIC_PREFIX:-example}"
TABLE_INCLUDE_LIST="${TABLE_INCLUDE_LIST:-cd.members,cd.facilities,cd.bookings}"
FIRST_TABLE="${TABLE_INCLUDE_LIST%%,*}"
TOPIC_TABLE="${OBS_TOPIC_TABLE:-$FIRST_TABLE}"
TOPIC_NAME="${TOPIC_PREFIX}.${TOPIC_TABLE}"

usage() {
  cat <<'EOF'
Usage: ./observability.sh [all|slot-lag|connector-errors|topic-offsets]

Commands:
  all               Run all observability checks (default)
  slot-lag          Show replication slot lag/retained WAL metrics
  connector-errors  Show connector/task state and task traces if present
  topic-offsets     Show earliest/latest offsets for the expected topic

Environment:
  OBS_TOPIC_TABLE   Optional topic table override (schema.table)
EOF
}

check_prereqs() {
  docker info > /dev/null 2>&1 || fail "Docker is not running"
  docker inspect -f '{{.State.Status}}' some-postgres 2>/dev/null | grep -qx running || fail "Postgres container is not running"
  docker inspect -f '{{.State.Status}}' debezium-connect 2>/dev/null | grep -qx running || fail "Debezium Connect container is not running"
  docker inspect -f '{{.State.Status}}' kafka 2>/dev/null | grep -qx running || fail "Kafka container is not running"
}

show_slot_lag() {
  echo ""
  warn "Replication slot lag (example_slot)"
  docker exec some-postgres psql -U postgres -c "
    SELECT
      slot_name,
      plugin,
      active,
      restart_lsn,
      confirmed_flush_lsn,
      pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
    FROM pg_replication_slots
    WHERE slot_name = 'example_slot';
  " || fail "Failed to query replication slot lag"
  ok "Replication slot lag query complete"
}

show_connector_errors() {
  echo ""
  warn "Connector status and task errors"
  status_json="$(curl -sf http://localhost:8083/connectors/example-connector/status 2>/dev/null)" \
    || fail "Unable to fetch connector status"

  connector_state="$(printf '%s' "$status_json" | grep -o '"state":"[^"]*"' | head -1 | cut -d '"' -f4 || true)"
  echo "connector.state=$connector_state"

  if command -v jq > /dev/null 2>&1; then
    printf '%s' "$status_json" | jq '.tasks[] | {id, state, worker_id, trace}'
  else
    echo "$status_json"
  fi

  if [[ "$connector_state" == "RUNNING" ]]; then
    ok "Connector is RUNNING"
  else
    warn "Connector is not RUNNING (state=$connector_state)"
  fi
}

show_topic_offsets() {
  echo ""
  warn "Topic offset visibility for $TOPIC_NAME"

  docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka:9092 \
    | grep -qx "$TOPIC_NAME" || fail "Topic '$TOPIC_NAME' not found"

  echo "earliest offsets:"
  docker exec kafka /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list kafka:9092 --topic "$TOPIC_NAME" --time -2 || fail "Failed to fetch earliest offsets"

  echo "latest offsets:"
  docker exec kafka /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list kafka:9092 --topic "$TOPIC_NAME" --time -1 || fail "Failed to fetch latest offsets"

  ok "Topic offsets query complete"
}

main() {
  cmd="${1:-all}"

  case "$cmd" in
    all|slot-lag|connector-errors|topic-offsets)
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "Unknown command: $cmd"
      ;;
  esac

  echo ""
  echo "=== Observability Helper ==="
  echo "scope.topic=$TOPIC_NAME"
  echo ""

  check_prereqs

  case "$cmd" in
    all)
      show_slot_lag
      show_connector_errors
      show_topic_offsets
      ;;
    slot-lag)
      show_slot_lag
      ;;
    connector-errors)
      show_connector_errors
      ;;
    topic-offsets)
      show_topic_offsets
      ;;
  esac

  echo ""
  ok "Observability checks complete"
  echo ""
}

main "$@"
