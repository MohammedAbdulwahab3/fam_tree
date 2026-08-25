#!/usr/bin/env bash
#
# Deletes every feed post (with its comments, reactions and the notifications
# that point at them) and every announcement notification, from the deployed
# Render database.
#
# Render's managed Postgres only accepts external connections from an IP on its
# allow list, so this opens the list, does the work, and closes it again --
# including on failure, via the trap.
#
# Usage:
#   export RENDER_API_KEY=rnd_xxx          # dashboard.render.com -> API Keys
#   ./scripts/clear-feed-and-announcements.sh
#
set -euo pipefail

DB_ID="${DB_ID:-dpg-da6mmjc9v7es73ed8tug-a}"
CONTAINER="${PG_CONTAINER:-family-tree-postgres}"
API="https://api.render.com/v1"

: "${RENDER_API_KEY:?Set RENDER_API_KEY first (dashboard.render.com -> Account Settings -> API Keys)}"
auth=(-H "Authorization: Bearer $RENDER_API_KEY")

# psql lives inside the local postgres container; nothing is installed on the host.
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" \
  || { echo "The '$CONTAINER' container is not running (docker compose up -d)." >&2; exit 1; }

close_list() {
  echo "==> Closing external database access"
  curl -s -m 30 -X PATCH "${auth[@]}" -H 'Content-Type: application/json' \
    -d '{"ipAllowList":[]}' "$API/postgres/$DB_ID" -o /dev/null
}
trap close_list EXIT

EXT=$(curl -sf -m 20 "${auth[@]}" "$API/postgres/$DB_ID/connection-info" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin)["externalConnectionString"])')

IP=$(curl -s -m 15 https://api.ipify.org)
echo "==> Allowing $IP"
curl -s -m 30 -X PATCH "${auth[@]}" -H 'Content-Type: application/json' \
  -d "{\"ipAllowList\":[{\"cidrBlock\":\"$IP/32\",\"description\":\"feed cleanup\"}]}" \
  "$API/postgres/$DB_ID" -o /dev/null

echo "==> Waiting for the allow list to take effect"
for _ in $(seq 1 12); do
  docker exec "$CONTAINER" psql "$EXT" -c 'select 1' >/dev/null 2>&1 && break
  sleep 10
done
docker exec "$CONTAINER" psql "$EXT" -c 'select 1' >/dev/null 2>&1 \
  || { echo "Could not connect. Your public IP may have changed mid-run; just run it again." >&2; exit 1; }

echo "==> Before"
docker exec "$CONTAINER" psql "$EXT" -tAc \
  "select 'posts='||(select count(*) from posts)
        ||' comments='||(select count(*) from comments)
        ||' reactions='||(select count(*) from reactions)
        ||' announcements='||(select count(*) from notifications where entity_type='announcement')"

# Children before parents: comments and reactions hang off post_id, and a
# 'somebody commented on your post' notification would otherwise open a post
# that no longer exists. One transaction, so a failure leaves nothing half-done.
echo "==> Deleting"
docker exec "$CONTAINER" psql "$EXT" -v ON_ERROR_STOP=1 -c "
BEGIN;
DELETE FROM notifications WHERE entity_type IN ('post','announcement');
DELETE FROM reactions;
DELETE FROM comments;
DELETE FROM posts;
COMMIT;"

echo "==> After"
docker exec "$CONTAINER" psql "$EXT" -tAc \
  "select 'posts='||(select count(*) from posts)
        ||' comments='||(select count(*) from comments)
        ||' reactions='||(select count(*) from reactions)
        ||' announcements='||(select count(*) from notifications where entity_type='announcement')
        ||' people='||(select count(*) from people where deleted_at is null)"

echo "==> Done. People are untouched; the count above is your check."
