#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${YELLOW}[~]${NC} $1"; }

echo ""
echo "=== Stopping POC Infrastructure ==="
echo ""

info "Stopping all services..."
docker compose down

# Confirm port 9092 is free
RETRIES=10
while lsof -ti :9092 > /dev/null 2>&1; do
  RETRIES=$((RETRIES - 1))
  if [[ $RETRIES -eq 0 ]]; then
    echo -e "${YELLOW}[~]${NC} Port 9092 still in use — forcing kill..."
    lsof -ti :9092 | xargs kill -9
    break
  fi
  sleep 1
done
ok "All services stopped — port 9092 is free"

echo ""
echo "=== All services stopped ==="
echo ""
echo "Note: postgres-data volume is preserved. To delete it:"
echo "  docker volume rm postgres-data"
echo ""
