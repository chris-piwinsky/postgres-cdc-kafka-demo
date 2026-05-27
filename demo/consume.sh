#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${YELLOW}[~]${NC} $1"; }

# Load connector scope from .env if present.
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck source=.env
  set -a; source "$ROOT_DIR/.env"; set +a
fi

TOPIC_PREFIX="${TOPIC_PREFIX:-example}"
TABLE_INCLUDE_LIST="${TABLE_INCLUDE_LIST:-cd.members,cd.facilities,cd.bookings}"

# Topic selection strategy:
# 1) DEMO_TABLE override if provided
# 2) cd.members when included (matches demo/run.sh producer)
# 3) first table from TABLE_INCLUDE_LIST
if [[ -n "${DEMO_TABLE:-}" ]]; then
  TOPIC_TABLE="$DEMO_TABLE"
elif [[ ",${TABLE_INCLUDE_LIST}," == *",cd.members,"* ]]; then
  TOPIC_TABLE="cd.members"
else
  TOPIC_TABLE="${TABLE_INCLUDE_LIST%%,*}"
fi

TOPIC_NAME="${TOPIC_PREFIX}.${TOPIC_TABLE}"

# jq filter: handles both schema-enabled envelope {"schema":...,"payload":...}
# and schema-disabled flat payload (connector default in this project).
# Maps op codes to human-readable labels and prints a clean summary per event.
JQ_FILTER='
  (if has("payload") then .payload else . end) as $p |
  ($p.op | if   . == "c" then "INSERT"
           elif . == "u" then "UPDATE"
           elif . == "d" then "DELETE"
           elif . == "r" then "READ  "
           else               .
           end) as $label |
  "\n────────────────────────────────────────────",
  " \($label)  (op: \"\($p.op)\")",
  " table:   \($p.source.table // "unknown")",
  " before:  \($p.before | if . == null then "null" else tojson end)",
  " after:   \($p.after  | if . == null then "null" else tojson end)",
  "────────────────────────────────────────────"
'

echo ""
echo "=== Kafka CDC Consumer ==="
echo ""
info "Listening on topic: $TOPIC_NAME"
if [[ "$TOPIC_TABLE" != "cd.members" ]]; then
  info "Note: ./demo/run.sh writes to cd.members; set DEMO_TABLE=cd.members to follow demo writes"
fi
info "Press Ctrl+C to stop"
echo ""

if command -v jq &>/dev/null; then
  info "jq found — formatting output"
  echo ""
  docker exec -i kafka /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --topic "$TOPIC_NAME" \
    --from-beginning \
  | jq --unbuffered -r "$JQ_FILTER"
else
  echo -e "${YELLOW}[~]${NC} jq not found — showing raw JSON (install with: brew install jq)"
  echo ""
  docker exec -it kafka /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --topic "$TOPIC_NAME" \
    --from-beginning
fi
