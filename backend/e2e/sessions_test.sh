#!/usr/bin/env bash
# Sessions last, a lost password is recoverable, and an account can be closed.
set -u
source "$(dirname "$0")/lib.sh"

echo "── a session that lasts ──────────────────────────────────────────"
ADMIN=$(register boss@t.local "Tigist Admin" secret123)
promote boss@t.local

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
read -r SARA_TOKEN SARA_ID <<<"$(register_full sara@t.local "Sara Tesfaye" oldpassword)"

pub POST /login '{"email":"sara@t.local","password":"forgotten"}'
check "signing in with the wrong password fails" 401

req POST "/api/admin/users/$SARA_ID/reset-code" "$ADMIN" '{}'
check "admin issues a reset code" 201
CODE=$(jval "$BODY" code)
[ -n "$CODE" ] && ok "the code is returned for the admin to pass on ($CODE)" || no "reset code" "empty"
case "$CODE" in *-*) ok "it is grouped so it can be read down a phone" ;; *) no "code format" "$CODE" ;; esac

MEMBER=$(register m2@t.local "Member Two" secret123)
req POST "/api/admin/users/$SARA_ID/reset-code" "$MEMBER" '{}'
check "an ordinary member cannot issue reset codes" 403

# A reset code is a credential; handing one to a peer is a lateral takeover.
ADMIN2=$(register boss2@t.local "Second Admin" secret123)
promote boss2@t.local
req GET /api/me "$ADMIN2" ''
ADMIN2_ID=$(jval "$BODY" id)
req POST "/api/admin/users/$ADMIN2_ID/reset-code" "$ADMIN" '{}'
check "an admin cannot issue a reset code for another admin" 409

pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"WRONGCOD\",\"newPassword\":\"newpassword\"}"
check "a wrong code is refused" 400

pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"$CODE\",\"newPassword\":\"short\"}"
check "a too-short new password is refused" 400

LOWER=$(echo "$CODE" | tr 'A-Z' 'a-z' | tr -d '-')
pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"$LOWER\",\"newPassword\":\"newpassword\"}"
check "the code works lowercase and without the dash" 200
[ -n "$(jval "$BODY" token)" ] && ok "she is signed straight in, not sent back to the login form" || no "no token returned" "$BODY"

pub POST /reset-password "{\"email\":\"sara@t.local\",\"code\":\"$CODE\",\"newPassword\":\"another1\"}"
check "the code cannot be used twice" 400
echo "     -> $(jval "$BODY" error)"

pub POST /login '{"email":"sara@t.local","password":"newpassword"}'
check "she can sign in with the new password" 200
SARA=$(jval "$BODY" token)
pub POST /login '{"email":"sara@t.local","password":"oldpassword"}'
check "the old password no longer works" 401

echo
echo "── changing a password you still remember ────────────────────────"
req PUT /api/me/password "$SARA" '{"currentPassword":"wrong","newPassword":"betterpass"}'
check "the current password must be right" 401
req PUT /api/me/password "$SARA" '{"currentPassword":"newpassword","newPassword":"newpassword"}'
check "reusing the same password is refused" 400
req PUT /api/me/password "$SARA" '{"currentPassword":"newpassword","newPassword":"betterpass"}'
check "she changes it herself" 200
pub POST /login '{"email":"sara@t.local","password":"betterpass"}'
check "and signs in with it" 200
SARA=$(jval "$BODY" token)

echo
echo "── deleting your own account ─────────────────────────────────────"
req POST /api/admin/persons "$ADMIN" '{"firstName":"Sara","lastName":"Tesfaye"}'
PERSON=$(jval "$BODY" id)
req POST /api/link-requests "$SARA" "{\"personId\":\"$PERSON\"}"
LR=$(jval "$BODY" id)
req PUT "/api/admin/link-requests/$LR" "$ADMIN" '{"status":"approved"}'
check "Sara is linked to her record first" 200

req DELETE /api/me "$SARA" '{"password":"wrong"}'
check "deleting needs the right password" 401
req DELETE /api/me "$SARA" '{"password":"betterpass"}'
check "she deletes her own account" 200

pub POST /login '{"email":"sara@t.local","password":"betterpass"}'
check "the account is gone" 401

req GET "/api/persons/$PERSON" "$ADMIN" ''
OWNER=$(jval "$BODY" authUserId)
[ -z "$OWNER" ] && ok "her person record stays in the tree, unclaimed" || no "person owner" "still '$OWNER'"

pub POST /register '{"email":"sara@t.local","password":"secret123","name":"Sara Again"}'
check "the email can be registered again" 201

req DELETE /api/me "$ADMIN" '{"password":"secret123"}'
check "the last admin cannot delete themselves" 409
echo "     -> $(jval "$BODY" error)"

echo
echo "── the public routes are rate limited ────────────────────────────"
# Ten attempts a minute per client. Without this an eight-character reset code
# is guessable given enough tries, and so is a six-character password.
limited=0
for _ in $(seq 1 14); do
  pub POST /login '{"email":"nobody@t.local","password":"guessing"}'
  [ "$STATUS" = "429" ] && { limited=1; break; }
done
[ "$limited" = "1" ] && ok "repeated sign-in attempts are refused" \
                     || no "rate limiting" "14 attempts all got through"

summary
