#!/usr/bin/env bash
#
# Dumps the local Docker Postgres (docker-compose.yml maps it to 5433) into a
# file you can replay against Render.
#
#   ./scripts/dump-local-db.sh                 # -> family_tree_dump.sql
#   ./scripts/dump-local-db.sh /tmp/out.sql
set -euo pipefail

OUT="${1:-family_tree_dump.sql}"
CONTAINER="${PG_CONTAINER:-family-tree-postgres}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5433}"
PGUSER="${PGUSER:-postgres}"
PGPASS="${PGPASSWORD:-postgres}"

# --no-owner/--no-acl: the local objects belong to "postgres", a role that does
# not exist on Render, and the ownership lines would fail on every statement.
# --clean/--if-exists makes the dump safe to replay over a non-empty database.
DUMP_ARGS=(--no-owner --no-acl --clean --if-exists -U "$PGUSER" -d family_tree)

if command -v pg_dump >/dev/null 2>&1; then
  # A client on PATH. Must be >= the server's major version (15 here).
  PGPASSWORD="$PGPASS" pg_dump -h "$PGHOST" -p "$PGPORT" "${DUMP_ARGS[@]}" -f "$OUT"
elif docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  # No client installed — borrow the one inside the container, which is
  # guaranteed to match the server version.
  echo "pg_dump not on PATH; using the client inside '$CONTAINER'"
  # Written inside the container and copied out, rather than piped: streaming
  # docker exec's stdout into a redirect fails with "bad file descriptor" when
  # the docker CLI is confined (the snap package, among others).
  docker exec -e PGPASSWORD="$PGPASS" "$CONTAINER" \
    pg_dump "${DUMP_ARGS[@]}" -f /tmp/family_tree_dump.sql
  docker cp "$CONTAINER:/tmp/family_tree_dump.sql" "$OUT"
  docker exec "$CONTAINER" rm -f /tmp/family_tree_dump.sql
else
  echo "Need either pg_dump on PATH or a running '$CONTAINER' container." >&2
  exit 1
fi

echo "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
