#!/usr/bin/env bash
# End-to-end checks for the repair phases, each against a throwaway database so
# your real data is never touched.
#
#   ./e2e/run.sh          # all phases
#   ./e2e/run.sh 3        # just phase 3
#   PORT=5199 ./e2e/run.sh
#
# Needs the Postgres container from docker-compose.yml to be up.
set -u
cd "$(dirname "$0")/.."

PG_CONTAINER=${PG_CONTAINER:-family-tree-postgres}
PG_PORT=${PG_PORT:-5433}
PORT=${PORT:-5099}
TEST_DB=${TEST_DB:-ft_e2e}
BIN=$(mktemp -u "${TMPDIR:-/tmp}/ftserver-e2e-XXXXXX")
SERVER_PID=""

phases=${*:-1 2 3 4 5}

cleanup() {
  # Only ever kill the server this script started. Matching on a name pattern
  # is how an earlier version managed to kill the shell running it.
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  rm -f "$BIN"
  docker exec "$PG_CONTAINER" psql -U postgres \
    -c "DROP DATABASE IF EXISTS $TEST_DB;" >/dev/null 2>&1
}
trap cleanup EXIT

# A server left over from something else would quietly serve these tests a
# stale build, and every assertion would be about the wrong binary.
if curl -sf -m 2 "http://localhost:$PORT/ping" >/dev/null 2>&1; then
  echo "Something is already listening on port $PORT."
  echo "Stop it, or run: PORT=5199 ./e2e/run.sh"
  exit 1
fi

echo "Building..."
go build -o "$BIN" . || exit 1

failed=0
for phase in $phases; do
  [ -n "$SERVER_PID" ] && { kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; }

  docker exec "$PG_CONTAINER" psql -U postgres \
    -c "DROP DATABASE IF EXISTS $TEST_DB;" -c "CREATE DATABASE $TEST_DB;" >/dev/null 2>&1

  DATABASE_URL="host=127.0.0.1 port=$PG_PORT user=postgres password=postgres dbname=$TEST_DB sslmode=disable" \
    JWT_SECRET=e2e-test PORT="$PORT" GIN_MODE=release TEST_DB="$TEST_DB" \
    "$BIN" > "${TMPDIR:-/tmp}/ftserver-e2e.log" 2>&1 &
  SERVER_PID=$!

  # Wait for it rather than guessing at a sleep.
  for _ in $(seq 1 40); do
    curl -sf -m 1 "http://localhost:$PORT/ping" >/dev/null 2>&1 && break
    sleep 0.25
  done

  echo
  echo "════ PHASE $phase ════"
  TEST_DB="$TEST_DB" API="http://localhost:$PORT" bash "e2e/phase${phase}_test.sh" || failed=1
done

exit $failed
