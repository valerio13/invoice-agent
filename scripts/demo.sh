#!/usr/bin/env bash
# Start the whole demo with one command: the database, its tables, the API in demo mode and the
# desktop app. Closing the app stops the API this script started.
#
#   scripts/demo.sh              # API on 127.0.0.1:8000
#   DEMO_PORT=8100 scripts/demo.sh
#
# Needs Docker, uv, Flutter and a filled-in .env (see .env.example). Values of .env are never
# printed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
port="${DEMO_PORT:-8000}"
api="http://127.0.0.1:${port}"
tmp="${TMPDIR:-/tmp}"
log="${tmp%/}/invoice-agent-demo-api.log"

step() { printf '\n==> %s\n' "$1"; }
fail() { printf 'Error: %s\n' "$1" >&2; exit 1; }

for tool in docker uv flutter curl; do
  command -v "$tool" >/dev/null || fail "$tool is not installed."
done
[[ -f "$root/.env" ]] || fail "no .env. Run: cp .env.example .env, then fill in the values."
docker info >/dev/null 2>&1 || fail "Docker is not running. Start Docker Desktop and try again."

step "Database"
(cd "$root" && docker compose up -d --wait db)

step "Tables (alembic upgrade head, does nothing when they are up to date)"
uv run --directory "$root/backend" alembic upgrade head

# Demo mode and the stand-in model, whatever .env says: the demo needs no key.
export DEMO_MODE=true LLM_PROVIDER=fake

started=""
stop_api() {
  if [[ -n "$started" ]] && kill -0 "$started" 2>/dev/null; then
    kill "$started"
    printf '\nAPI stopped.\n'
  fi
}
trap stop_api EXIT

if curl -sf "$api/health" >/dev/null; then
  step "API already running at $api"
  curl -sf "$api/health" | grep -q '"demo_mode":true' ||
    fail "the API at $api is not in demo mode. Stop it or use another DEMO_PORT."
else
  step "API at $api (log: $log)"
  uv run --directory "$root/backend" fastapi run --host 127.0.0.1 --port "$port" >"$log" 2>&1 &
  started=$!
  for _ in $(seq 60); do
    curl -sf "$api/health" >/dev/null && break
    kill -0 "$started" 2>/dev/null || fail "the API did not start. See $log"
    sleep 1
  done
  curl -sf "$api/health" >/dev/null || fail "the API did not answer in 60 seconds. See $log"
fi

# The demo set replaces every invoice, so it is only loaded into an empty database. Otherwise
# "Load demo" on the Overview screen does it.
if curl -sf "$api/metrics" | grep -q '"invoices":0,'; then
  step "Loading the demo invoices"
  curl -sf -X POST "$api/ingest/demo" >/dev/null
else
  step "The database already has invoices: kept as they are"
fi

step "Desktop app (close it or press q to end the demo)"
cd "$root/desktop"
flutter run -d macos --dart-define=API_URL="$api"
