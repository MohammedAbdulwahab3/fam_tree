#!/usr/bin/env bash
# End-to-end checks, each against a throwaway database so your real data is
# never touched.
#
#   ./e2e/run.sh                  # every suite
#   ./e2e/run.sh permissions      # one suite
#   PORT=5199 ./e2e/run.sh        # if 5099 is busy
#
# Locally this expects the Postgres container from docker-compose.yml. In CI it
# talks to a service container over TCP; set PG_HOST/PG_PORT and it uses a plain
# psql client instead of docker exec.
set -u
cd "$(dirname "$0")/.."

PG_HOST=${PG_HOST:-127.0.0.1}
PG_PORT=${PG_PORT:-5433}
PG_CONTAINER=${PG_CONTAINER:-family-tree-postgres}
PORT=${PORT:-5099}
TEST_DB=${TEST_DB:-ft_e2e}
BIN=$(mktemp -u "${TMPDIR:-/tmp}/ftserver-e2e-XXXXXX")
SERVER_PID=""

SUITES=${*:-permissions notifications linking sessions tree}

# Prefer a real psql client; fall back to the local docker container. The old
# script only knew how to shell into a container, which is why this suite could
# never run in CI.
if command -v psql >/dev/null 2>&1; then
  admin_sql() { PGPASSWORD=postgres psql -h "$PG_HOST" -p "$PG_PORT" -U postgres -d postgres -c "$1" >/dev/null 2>&1; }
elif command -v docker >/dev/null 2>&1; then
  admin_sql() { docker exec "$PG_CONTAINER" psql -U postgres -c "$1" >/dev/null 2>&1; }
else
  echo "Need either psql or docker to create the test database." >&2
  exit 1
fi

cleanup() {
  # Only ever kill the server this script started. Matching on a name pattern
  # is how an earlier version managed to kill the shell running it.
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  rm -f "$BIN"
  admin_sql "DROP DATABASE IF EXISTS $TEST_DB;"
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

export PG_URL="postgresql://postgres:postgres@$PG_HOST:$PG_PORT/$TEST_DB?sslmode=disable"
export DATABASE_URL="host=$PG_HOST port=$PG_PORT user=postgres password=postgres dbname=$TEST_DB sslmode=disable"

failed=0
for suite in $SUITES; do
  script="e2e/${suite}_test.sh"
  if [ ! -f "$script" ]; then
    echo "No such suite: $suite" >&2
    failed=1
    continue
  fi

  [ -n "$SERVER_PID" ] && { kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; }

  admin_sql "DROP DATABASE IF EXISTS $TEST_DB;"
  admin_sql "CREATE DATABASE $TEST_DB;"

  JWT_SECRET=e2e-test PORT="$PORT" GIN_MODE=release \
    "$BIN" > "${TMPDIR:-/tmp}/ftserver-e2e.log" 2>&1 &
  SERVER_PID=$!

  # Wait for it rather than guessing at a sleep.
  ready=0
  for _ in $(seq 1 40); do
    curl -sf -m 1 "http://localhost:$PORT/ping" >/dev/null 2>&1 && { ready=1; break; }
    sleep 0.25
  done
  if [ "$ready" -ne 1 ]; then
    echo "Server did not start. Log:"
    tail -20 "${TMPDIR:-/tmp}/ftserver-e2e.log"
    failed=1
    continue
  fi

  echo
  echo "════ ${suite^^} ════"
  API="http://localhost:$PORT" bash "$script" || failed=1
done

exit $failed
