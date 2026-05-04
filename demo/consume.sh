#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${YELLOW}[~]${NC} $1"; }

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
info "Listening on topic: example.cd.members"
info "Press Ctrl+C to stop"
echo ""

if command -v jq &>/dev/null; then
  info "jq found — formatting output"
  echo ""
  docker exec -i kafka /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --topic example.cd.members \
    --from-beginning \
  | jq --unbuffered -r "$JQ_FILTER"
else
  echo -e "${YELLOW}[~]${NC} jq not found — showing raw JSON (install with: brew install jq)"
  echo ""
  docker exec -it kafka /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --topic example.cd.members \
    --from-beginning
fi
