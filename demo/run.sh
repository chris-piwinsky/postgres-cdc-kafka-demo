#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${YELLOW}[~]${NC} $1"; }
step() { echo -e "${CYAN}${BOLD}--- $1 ---${NC}"; }

# Load connector scope from .env if present.
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck source=.env
  set -a; source "$ROOT_DIR/.env"; set +a
fi

TOPIC_PREFIX="${TOPIC_PREFIX:-example}"
TABLE_INCLUDE_LIST="${TABLE_INCLUDE_LIST:-cd.members,cd.facilities,cd.bookings}"

psql() {
  docker exec -i some-postgres psql -U postgres -c "$1"
}

pause() {
  echo ""
  sleep "${1:-2}"
}

echo ""
echo "=== CDC Demo: INSERT / UPDATE / DELETE ==="
echo ""

# Ensure demo writes are in connector scope.
if [[ ",${TABLE_INCLUDE_LIST}," != *",cd.members,"* ]]; then
  fail "cd.members is not in TABLE_INCLUDE_LIST ('$TABLE_INCLUDE_LIST').
  This demo writes to cd.members, so include it in .env and restart:
  TABLE_INCLUDE_LIST=cd.members,cd.facilities,cd.bookings
  ./start.sh
  ./health.sh"
fi

ok "Demo scope check passed: cd.members is included"
info "Current connector scope: topic.prefix=$TOPIC_PREFIX"
info "Current connector scope: table.include.list=$TABLE_INCLUDE_LIST"

# 1. Check connector is RUNNING
info "Checking Debezium connector status..."
CONNECTOR_STATE=$(curl -sf http://localhost:8083/connectors/example-connector/status 2>/dev/null \
  | grep -o '"state":"[^"]*"' | head -1 | grep -o '[^"]*"$' | tr -d '"' || echo "UNKNOWN")

if [[ "$CONNECTOR_STATE" != "RUNNING" ]]; then
  fail "Connector is not RUNNING (state: $CONNECTOR_STATE). Register it first:
  source .env
  envsubst < debezium/register-postgres.json.example \\
    | curl -X POST -H 'Content-Type: application/json' --data @- http://localhost:8083/connectors"
fi
ok "Connector is RUNNING"

# 2. Clean up any leftover demo members from a previous run
info "Removing any leftover demo members (memid >= 100)..."
psql "DELETE FROM cd.members WHERE memid >= 100;"
ok "Demo members cleared"

pause

echo ""
echo "Open a second terminal and run:  ./demo/consume.sh"
echo "Then press Enter here to start the demo..."
read -r

echo ""
echo "Starting 3 iterations of INSERT → UPDATE → DELETE against cd.members"
echo "Each event will appear in the consumer terminal as a Debezium CDC message."
echo ""

for i in 1 2 3; do
  echo ""
  step "Iteration $i / 3"
  MEMID=$((100 + i))

  # INSERT
  SURNAME="Demo${i}"
  FIRSTNAME="User${i}"
  info "INSERT: memid=$MEMID, surname='$SURNAME', firstname='$FIRSTNAME'"
  psql "INSERT INTO cd.members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate) VALUES ($MEMID, '$SURNAME', '$FIRSTNAME', '1 Demo Lane, Boston', 12345, '555-000-000$i', NULL, NOW());"
  ok "Inserted"
  pause 3

  # UPDATE
  NEW_ADDR="$((i * 100)) Updated Blvd, Boston"
  info "UPDATE: memid=$MEMID → address='$NEW_ADDR'"
  psql "UPDATE cd.members SET address = '$NEW_ADDR' WHERE memid = $MEMID;"
  ok "Updated"
  pause 3

  # DELETE
  info "DELETE: memid=$MEMID"
  psql "DELETE FROM cd.members WHERE memid = $MEMID;"
  ok "Deleted"
  pause 3

done

echo ""
step "Final demo member state (should be empty)"
psql "SELECT memid, surname, firstname FROM cd.members WHERE memid >= 100;"

echo ""
ok "Demo complete — check your consumer terminal for all CDC events"
echo ""
