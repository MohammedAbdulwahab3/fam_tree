#!/usr/bin/env bash
# Phase 3: the link flow can no longer dead-end.
API=${API:-http://localhost:5099}
pass=0; fail=0
ok() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  \033[31mFAIL\033[0m  %s\n     %s\n' "$1" "$2"; fail=$((fail+1)); }
same() { [ "$2" = "$3" ] && ok "$1 ($3)" || no "$1" "got '$2' want '$3'"; }

tok() { curl -s -X POST $API/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\",\"password\":\"secret123\",\"name\":\"$2\"}" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])"; }
req() {
  local out
  if [ -n "$4" ]; then out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "$4")
  else out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3"); fi
  STATUS=$(echo "$out" | tail -1); BODY=$(echo "$out" | sed '$d')
}
jv() { echo "$BODY" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('$1',''))" 2>/dev/null; }

echo "── setup ─────────────────────────────────────────────────────────"
ADMIN=$(tok boss@t.local "Tigist Admin")
curl -s -X POST $API/init-admin -H 'Content-Type: application/json' \
  -d '{"email":"boss@t.local","secret_key":"FamilyTree2026AdminSecret"}' > /dev/null
SARA=$(tok sara@t.local "Sara Tesfaye")
DAWIT=$(tok dawit@t.local "Dawit Kebede")

req POST /api/admin/persons "$ADMIN" '{"firstName":"Aster","lastName":"Bekele","familyTreeId":"main-family-tree","gender":"female"}'
ASTER=$(jv id)
req POST /api/admin/persons "$ADMIN" '{"firstName":"Yonas","lastName":"Bekele","familyTreeId":"main-family-tree","gender":"male"}'
YONAS=$(jv id)
echo "  admin, two members, two people in the tree"

echo
echo "── A-04  a claim, and what the member can see about it ───────────"
req GET /api/link-requests/my-status "$SARA" ''
same "before claiming, status is not_linked" "$(jv status)" "not_linked"

req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
same "Sara claims Aster" "$STATUS" "201"

req GET /api/link-requests/my-status "$SARA" ''
same "her status now reads pending" "$(jv status)" "pending"
same "and names who she claimed" "$(jv personName)" "Aster Bekele"

req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
same "claiming the same person twice is refused" "$STATUS" "409"
echo "     -> $(jv error)"

req POST /api/link-requests "$SARA" "{\"personId\":\"$YONAS\"}"
same "stacking a second claim is refused" "$STATUS" "409"
echo "     -> $(jv error)"

echo
echo "── the admin is told there is something to review ────────────────"
req GET /api/notifications "$ADMIN" ''
HAS=$(echo "$BODY" | python3 -c "import sys,json;print(any('Sara' in n['body'] for n in json.load(sys.stdin)))")
[ "$HAS" = "True" ] && ok "admin was notified about the new claim" || no "admin notification" "not found"

echo
echo "── a member can withdraw their own claim ─────────────────────────"
req DELETE /api/link-requests/mine "$SARA" ''
same "Sara withdraws it" "$STATUS" "200"
req GET /api/link-requests/my-status "$SARA" ''
same "she is back to not_linked and free to try again" "$(jv status)" "not_linked"
req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
same "and can claim again straight away" "$STATUS" "201"
SARA_REQ=$(jv id)

echo
echo "── A-04  a rejection says why, and stays visible ─────────────────"
req PUT "/api/admin/link-requests/$SARA_REQ" "$ADMIN" '{"status":"rejected","reason":"That is your aunt, not you — try Meron"}'
same "admin rejects with a reason" "$STATUS" "200"

req GET /api/link-requests/my-status "$SARA" ''
same "her status is rejected, not not_linked" "$(jv status)" "rejected"
same "and carries the admin's words" "$(jv reason)" "That is your aunt, not you — try Meron"
same "and still names the person" "$(jv personName)" "Aster Bekele"

req GET /api/notifications "$SARA" ''
TOLD=$(echo "$BODY" | python3 -c "import sys,json;print(any('not approved' in n['title'] for n in json.load(sys.stdin)))")
[ "$TOLD" = "True" ] && ok "Sara was notified of the decision" || no "rejection notification" "not found"
echo "     -> $(echo "$BODY" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['body'])")"

echo
echo "── approval, and what it locks down ──────────────────────────────"
req POST /api/link-requests "$SARA" "{\"personId\":\"$YONAS\"}"
SARA_REQ2=$(jv id)
req PUT "/api/admin/link-requests/$SARA_REQ2" "$ADMIN" '{"status":"approved"}'
same "admin approves the second claim" "$STATUS" "200"

req GET /api/link-requests/my-status "$SARA" ''
same "she is verified" "$(jv status)" "verified"
same "and the status names her record" "$(jv personName)" "Yonas Bekele"

req GET /api/notifications "$SARA" ''
TOLD=$(echo "$BODY" | python3 -c "import sys,json;print(any('You are linked' in n['title'] for n in json.load(sys.stdin)))")
[ "$TOLD" = "True" ] && ok "Sara was told she is linked" || no "approval notification" "not found"

req POST /api/link-requests "$DAWIT" "{\"personId\":\"$YONAS\"}"
same "someone else cannot claim a taken record" "$STATUS" "409"
echo "     -> $(jv error)"

req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
same "an already-linked member cannot claim again" "$STATUS" "409"

req POST /api/link-requests "$DAWIT" '{"personId":"does-not-exist"}'
same "claiming a person who is not in the tree is refused" "$STATUS" "404"

req DELETE /api/link-requests/mine "$DAWIT" ''
same "withdrawing with nothing pending says so" "$STATUS" "404"

echo
echo "──────────────────────────────────────────────────────────────────"
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
