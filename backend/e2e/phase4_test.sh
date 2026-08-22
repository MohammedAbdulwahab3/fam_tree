#!/usr/bin/env bash
# Phase 4: sessions last, and a lost password is recoverable.
API=${API:-http://localhost:5099}
pass=0; fail=0
ok() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  \033[31mFAIL\033[0m  %s\n     %s\n' "$1" "$2"; fail=$((fail+1)); }
same() { [ "$2" = "$3" ] && ok "$1 ($3)" || no "$1" "got '$2' want '$3'"; }

reg() { curl -s -X POST $API/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\",\"password\":\"$3\",\"name\":\"$2\"}"; }
req() {
  local out
  if [ -n "$4" ]; then out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "$4")
  else out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3"); fi
  STATUS=$(echo "$out" | tail -1); BODY=$(echo "$out" | sed '$d')
}
pub() {
  local out; out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" -H 'Content-Type: application/json' -d "$3")
  STATUS=$(echo "$out" | tail -1); BODY=$(echo "$out" | sed '$d')
}
jv() { echo "$BODY" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('$1',''))" 2>/dev/null; }

echo "── A-05  a session that lasts ────────────────────────────────────"
ADMIN=$(reg boss@t.local "Tigist Admin" secret123 | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
curl -s -X POST $API/init-admin -H 'Content-Type: application/json' \
  -d '{"email":"boss@t.local","secret_key":"FamilyTree2026AdminSecret"}' > /dev/null

EXP=$(python3 -c "
import base64,json,sys,datetime
t='$ADMIN'.split('.')[1]
t+='='*(-len(t)%4)
c=json.loads(base64.urlsafe_b64decode(t))
days=(c['exp']-c['iat'])/86400
print(round(days))")
same "an issued token is good for 30 days, not 1" "$EXP" "30"

echo
echo "── locked out, then let back in ──────────────────────────────────"
SARA_JSON=$(reg sara@t.local "Sara Tesfaye" oldpassword)
SARA_ID=$(echo "$SARA_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin)['user']['id'])")

pub POST /login '{"email":"sara@t.local","password":"forgotten"}'
same "signing in with the wrong password fails" "$STATUS" "401"

req POST "/api/admin/users/$SARA_ID/reset-code" "$ADMIN" '{}'
same "admin issues a reset code" "$STATUS" "201"
CODE=$(jv code)
[ -n "$CODE" ] && ok "the code is returned for the admin to pass on ($CODE)" || no "reset code" "empty"
case "$CODE" in *-*) ok "it is grouped so it can be read down a phone" ;; *) no "code format" "$CODE" ;; esac

SARA_TOK=$(reg other@t.local "Other" secret123 > /dev/null; echo)
req POST "/api/admin/users/$SARA_ID/reset-code" "$(reg m2@t.local 'Member Two' secret123 | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")" '{}'
same "an ordinary member cannot issue reset codes" "$STATUS" "403"

pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"WRONGCOD\",\"newPassword\":\"newpassword\"}"
same "a wrong code is refused" "$STATUS" "400"

pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"$CODE\",\"newPassword\":\"short\"}"
same "a too-short new password is refused" "$STATUS" "400"

LOWER=$(echo "$CODE" | tr 'A-Z' 'a-z' | tr -d '-')
pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"$LOWER\",\"newPassword\":\"newpassword\"}"
same "the code works lowercase and without the dash" "$STATUS" "200"
[ -n "$(jv token)" ] && ok "she is signed straight in, not sent back to the login form" || no "no token returned" "$BODY"

pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"$CODE\",\"newPassword\":\"another1\"}"
same "the code cannot be used twice" "$STATUS" "400"
echo "     -> $(jv error)"

pub POST /login '{"email":"sara@t.local","password":"newpassword"}'
same "she can sign in with the new password" "$STATUS" "200"
SARA=$(jv token)
pub POST /login '{"email":"sara@t.local","password":"oldpassword"}'
same "the old password no longer works" "$STATUS" "401"

echo
echo "── changing a password you still remember ────────────────────────"
req PUT /api/me/password "$SARA" '{"currentPassword":"wrong","newPassword":"betterpass"}'
same "the current password must be right" "$STATUS" "401"
req PUT /api/me/password "$SARA" '{"currentPassword":"newpassword","newPassword":"newpassword"}'
same "reusing the same password is refused" "$STATUS" "400"
req PUT /api/me/password "$SARA" '{"currentPassword":"newpassword","newPassword":"betterpass"}'
same "she changes it herself" "$STATUS" "200"
pub POST /login '{"email":"sara@t.local","password":"betterpass"}'
same "and signs in with it" "$STATUS" "200"
SARA=$(jv token)

echo
echo "── deleting your own account ─────────────────────────────────────"
req POST /api/admin/persons "$ADMIN" '{"firstName":"Sara","lastName":"Tesfaye","familyTreeId":"main-family-tree"}'
PERSON=$(jv id)
req POST /api/link-requests "$SARA" "{\"personId\":\"$PERSON\"}"
LR=$(jv id)
req PUT "/api/admin/link-requests/$LR" "$ADMIN" '{"status":"approved"}'
same "Sara is linked to her record first" "$STATUS" "200"

req DELETE /api/me "$SARA" '{"password":"wrong"}'
same "deleting needs the right password" "$STATUS" "401"
req DELETE /api/me "$SARA" '{"password":"betterpass"}'
same "she deletes her own account" "$STATUS" "200"

pub POST /login '{"email":"sara@t.local","password":"betterpass"}'
same "the account is gone" "$STATUS" "401"

req GET "/api/persons/$PERSON" "$ADMIN" ''
OWNER=$(jv authUserId)
[ -z "$OWNER" ] && ok "her person record stays in the tree, unclaimed" || no "person owner" "still '$OWNER'"

pub POST /register '{"email":"sara@t.local","password":"secret123","name":"Sara Again"}'
same "the email can be registered again" "$STATUS" "201"

req DELETE /api/me "$ADMIN" '{"password":"secret123"}'
same "the last admin cannot delete themselves" "$STATUS" "409"
echo "     -> $(jv error)"

echo
echo "──────────────────────────────────────────────────────────────────"
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
