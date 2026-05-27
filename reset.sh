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

usage() {
  cat <<'EOF'
Usage: ./reset.sh [--yes|-y] [--no-start]

Options:
  --yes, -y     Skip confirmation prompt
  --no-start    Reset and stop. Do not restart services automatically.
  --help, -h    Show help
EOF
}

ASSUME_YES=false
AUTO_START=true

for arg in "$@"; do
  case "$arg" in
    --yes|-y)
      ASSUME_YES=true
      ;;
    --no-start)
      AUTO_START=false
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $arg"
      ;;
  esac
done

echo ""
echo "=== Resetting POC Infrastructure ==="
echo ""

warn "Checking Docker daemon..."
docker info > /dev/null 2>&1 || fail "Docker is not running. Start Docker Desktop and retry."
ok "Docker is running"

if [[ "$ASSUME_YES" != "true" ]]; then
  echo "This will delete local state:"
  echo "  - postgres-data volume"
  echo "  - any compose-managed volumes/networks for this project"
  echo ""
  read -r -p "Continue? [y/N]: " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      warn "Reset cancelled"
      exit 0
      ;;
  esac
fi

warn "Stopping and removing compose resources..."
docker compose down -v --remove-orphans || true
ok "Compose resources removed"

warn "Ensuring service ports are free..."
for port in 9092 5431 8083; do
  if lsof -ti ":$port" > /dev/null 2>&1; then
    lsof -ti ":$port" | xargs kill -9 || true
  fi
done
ok "Ports 9092, 5431, and 8083 are free"

warn "Removing postgres-data volume..."
if docker volume inspect postgres-data > /dev/null 2>&1; then
  docker volume rm postgres-data > /dev/null
  ok "Removed postgres-data volume"
else
  warn "postgres-data volume was not present"
fi

warn "Recreating empty postgres-data volume..."
docker volume create postgres-data > /dev/null
ok "Created clean postgres-data volume"

if [[ "$AUTO_START" == "true" ]]; then
  warn "Starting clean environment..."
  "$SCRIPT_DIR/start.sh"
  ok "Reset complete and environment restarted"
else
  ok "Reset complete"
  echo ""
  echo "Environment is clean and stopped. Start when ready:"
  echo "  ./start.sh"
fi
