#!/usr/bin/env bash
# Phase 5: the tree stops re-downloading itself, and uploads have limits.
API=${API:-http://localhost:5099}
pass=0; fail=0
ok() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  \033[31mFAIL\033[0m  %s\n     %s\n' "$1" "$2"; fail=$((fail+1)); }
same() { [ "$2" = "$3" ] && ok "$1 ($3)" || no "$1" "got '$2' want '$3'"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

TOK=$(curl -s -X POST $API/register -H 'Content-Type: application/json' \
  -d '{"email":"p5@t.local","password":"secret123","name":"Poller"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
curl -s -X POST $API/init-admin -H 'Content-Type: application/json' \
  -d '{"email":"p5@t.local","secret_key":"FamilyTree2026AdminSecret"}' >/dev/null
for i in 1 2 3 4 5; do
  curl -s -X POST $API/api/admin/persons -H "Authorization: Bearer $TOK" \
    -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"Person$i\",\"lastName\":\"Test\",\"familyTreeId\":\"main-family-tree\"}" >/dev/null
done

echo "── A-07  the tree only re-sends when it changed ──────────────────"
curl -s -D "$TMP/h1" -o "$TMP/b1" $API/api/persons -H "Authorization: Bearer $TOK"
ETAG=$(grep -i '^etag:' "$TMP/h1" | tr -d '\r' | cut -d' ' -f2)
FULL=$(wc -c < "$TMP/b1")
[ -n "$ETAG" ] && ok "the response carries an ETag" || no "ETag" "missing"
[ "$FULL" -gt 100 ] && ok "first fetch returns the full tree ($FULL bytes)" || no "body" "$FULL bytes"

: > "$TMP/b2"
CODE=$(curl -s -o "$TMP/b2" -w '%{http_code}' $API/api/persons \
  -H "Authorization: Bearer $TOK" -H "If-None-Match: $ETAG")
same "an unchanged poll answers 304" "$CODE" "304"
# curl does not always create the output file for a bodyless response.
UNCH=$( [ -f "$TMP/b2" ] && wc -c < "$TMP/b2" || echo 0 )
same "and sends no body at all" "$UNCH" "0"
printf '         \033[2msaves %s bytes on every unchanged poll\033[0m\n' "$FULL"

for form in "W/$ETAG" "\"other\", $ETAG" "*"; do
  C=$(curl -s -o /dev/null -w '%{http_code}' $API/api/persons \
    -H "Authorization: Bearer $TOK" -H "If-None-Match: $form")
  [ "$C" = "304" ] && ok "If-None-Match form accepted: ${form:0:22}" \
                   || no "If-None-Match: $form" "got $C"
done

C=$(curl -s -o /dev/null -w '%{http_code}' $API/api/persons \
  -H "Authorization: Bearer $TOK" -H 'If-None-Match: "stale"')
same "a stale ETag gets the full tree" "$C" "200"

curl -s -X POST $API/api/admin/persons -H "Authorization: Bearer $TOK" \
  -H 'Content-Type: application/json' \
  -d '{"firstName":"Newborn","lastName":"Test","familyTreeId":"main-family-tree"}' >/dev/null
curl -s -D "$TMP/h3" -o "$TMP/b3" $API/api/persons \
  -H "Authorization: Bearer $TOK" -H "If-None-Match: $ETAG" > /dev/null
NEW=$(grep -i '^etag:' "$TMP/h3" | tr -d '\r' | cut -d' ' -f2)
CODE3=$(head -1 "$TMP/h3" | awk '{print $2}')
same "adding someone makes the next poll a 200" "$CODE3" "200"
[ "$NEW" != "$ETAG" ] && ok "and the ETag changed with the data" || no "ETag" "unchanged"

echo
echo "── A-10  uploads have a ceiling and a whitelist ──────────────────"
head -c 1024 /dev/urandom > "$TMP/small.jpg"
CODE=$(curl -s -o "$TMP/up" -w '%{http_code}' -X POST $API/api/upload \
  -H "Authorization: Bearer $TOK" -F "file=@$TMP/small.jpg")
same "a small jpg uploads" "$CODE" "200"
KIND=$(python3 -c "import json;print(json.load(open('$TMP/up')).get('kind',''))")
same "the response says what kind of file it is" "$KIND" "image"

head -c 2048 /dev/urandom > "$TMP/thing.exe"
CODE=$(curl -s -o "$TMP/up2" -w '%{http_code}' -X POST $API/api/upload \
  -H "Authorization: Bearer $TOK" -F "file=@$TMP/thing.exe")
same "an executable is refused" "$CODE" "415"
echo "     -> $(python3 -c "import json;print(json.load(open('$TMP/up2'))['error'])")"

# 26 MB, just past the 25 MB ceiling.
head -c 27262976 /dev/zero > "$TMP/huge.mp4"
CODE=$(curl -s -o "$TMP/up3" -w '%{http_code}' -X POST $API/api/upload \
  -H "Authorization: Bearer $TOK" -F "file=@$TMP/huge.mp4")
same "an oversized file is refused with a reason" "$CODE" "413"
echo "     -> $(python3 -c "import json;print(json.load(open('$TMP/up3'))['error'])")"

STORED=$(python3 -c "import json;print(json.load(open('$TMP/up'))['url'])")
case "$STORED" in
  /uploads/[0-9]*.jpg) ok "the stored name is generated, not the client's" ;;
  *) no "stored name" "$STORED" ;;
esac

echo
echo "──────────────────────────────────────────────────────────────────"
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
