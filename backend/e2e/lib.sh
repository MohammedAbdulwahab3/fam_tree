#!/usr/bin/env bash
# Shared helpers for the end-to-end suites.
#
# Every suite used to carry its own copy of check/req/jval, in four slightly
# different dialects, so a fix to one of them reached one file.

API=${API:-http://localhost:5099}
pass=0
fail=0

# ok <label> [detail]
ok() {
  printf '  \033[32mPASS\033[0m  %-54s %s\n' "$1" "${2:-}"
  pass=$((pass + 1))
}

# no <label> <why>
no() {
  printf '  \033[31mFAIL\033[0m  %-54s\n        %s\n' "$1" "$2"
  fail=$((fail + 1))
}

# check <label> <expected-status>
# Reads STATUS and BODY set by the last req/pub call.
check() {
  if [ "$2" = "$STATUS" ]; then
    ok "$1" "$STATUS"
  else
    no "$1" "got $STATUS, want $2 — $BODY"
  fi
}

# same <label> <actual> <expected>
same() {
  if [ "$2" = "$3" ]; then
    ok "$1" "$2"
  else
    no "$1" "got '$2', want '$3'"
  fi
}

# req <method> <path> <token> [json] -> sets STATUS and BODY
req() {
  local out
  if [ -n "${4:-}" ]; then
    out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" \
      -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "$4")
  else
    out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" \
      -H "Authorization: Bearer $3")
  fi
  STATUS=$(echo "$out" | tail -1)
  BODY=$(echo "$out" | sed '$d')
}

# pub <method> <path> [json] -> sets STATUS and BODY, no credentials
pub() {
  local out
  out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" \
    -H 'Content-Type: application/json' -d "${3:-}")
  STATUS=$(echo "$out" | tail -1)
  BODY=$(echo "$out" | sed '$d')
}

# jval <json> <key> — one top-level key, empty if absent
jval() {
  echo "$1" | python3 -c \
    "import sys,json;print(json.load(sys.stdin).get('$2',''))" 2>/dev/null
}

# jq_path <json> <python-expression on d> — for anything nested
jpath() {
  echo "$1" | python3 -c "import sys,json;d=json.load(sys.stdin);print($2)" 2>/dev/null
}

# register <email> <name> <password> — echoes the token
register() {
  curl -s -X POST "$API/register" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"name\":\"$2\",\"password\":\"$3\"}" |
    python3 -c "import sys,json;print(json.load(sys.stdin)['token'])"
}

# register_full <email> <name> <password> — echoes "<token> <id>"
register_full() {
  curl -s -X POST "$API/register" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"name\":\"$2\",\"password\":\"$3\"}" |
    python3 -c "import sys,json;d=json.load(sys.stdin);print(d['token'],d['user']['id'])"
}

# promote <email> — make an account an admin.
#
# There is no HTTP route for this by design: the one that used to exist was
# public and gated on a secret string committed to this repository. Promotion
# goes through the database, exactly as it does in production.
promote() {
  (cd "$(dirname "${BASH_SOURCE[0]}")/.." && go run ./cmd/make_admin "$1" >/dev/null)
}

# psql_query <sql> — echoes the single value it selects
psql_query() {
  psql "$PG_URL" -tAc "$1" 2>/dev/null | tr -d '[:space:]'
}

summary() {
  echo
  echo "──────────────────────────────────────────────────────────────────"
  printf '  %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
