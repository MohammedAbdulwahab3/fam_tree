#!/usr/bin/env bash
# Claiming a record in the tree: requesting, withdrawing, rejection, approval.
set -u
source "$(dirname "$0")/lib.sh"

echo "── setup ─────────────────────────────────────────────────────────"
ADMIN=$(register boss@t.local "Tigist Admin" secret123)
promote boss@t.local
SARA=$(register sara@t.local "Sara Tesfaye" secret123)
DAWIT=$(register dawit@t.local "Dawit Kebede" secret123)

req POST /api/admin/persons "$ADMIN" '{"firstName":"Aster","lastName":"Bekele","gender":"female"}'
ASTER=$(jval "$BODY" id)
req POST /api/admin/persons "$ADMIN" '{"firstName":"Yonas","lastName":"Bekele","gender":"male"}'
YONAS=$(jval "$BODY" id)
echo "  admin, two members, two people in the tree"

echo
echo "── A-04  a claim, and what the member can see about it ───────────"
req GET /api/link-requests/my-status "$SARA" ''
same "before claiming, status is not_linked" "$(jval "$BODY" status)" "not_linked"

req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
check "Sara claims Aster" 201

req GET /api/link-requests/my-status "$SARA" ''
same "her status now reads pending" "$(jval "$BODY" status)" "pending"
same "and names who she claimed" "$(jval "$BODY" personName)" "Aster Bekele"

req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
check "claiming the same person twice is refused" 409
echo "     -> $(jval "$BODY" error)"

req POST /api/link-requests "$SARA" "{\"personId\":\"$YONAS\"}"
check "stacking a second claim is refused" 409
echo "     -> $(jval "$BODY" error)"

echo
echo "── the admin is told there is something to review ────────────────"
req GET /api/notifications "$ADMIN" ''
HAS=$(jpath "$BODY" "any('Sara' in n['body'] for n in d)")
[ "$HAS" = "True" ] && ok "admin was notified about the new claim" || no "admin notification" "not found"

echo
echo "── a member can withdraw their own claim ─────────────────────────"
req DELETE /api/link-requests/mine "$SARA" ''
check "Sara withdraws it" 200
req GET /api/link-requests/my-status "$SARA" ''
same "she is back to not_linked and free to try again" "$(jval "$BODY" status)" "not_linked"
req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
check "and can claim again straight away" 201
SARA_REQ=$(jval "$BODY" id)

echo
echo "── A-04  a rejection says why, and stays visible ─────────────────"
req PUT "/api/admin/link-requests/$SARA_REQ" "$ADMIN" '{"status":"rejected","reason":"That is your aunt, not you — try Meron"}'
check "admin rejects with a reason" 200

req GET /api/link-requests/my-status "$SARA" ''
same "her status is rejected, not not_linked" "$(jval "$BODY" status)" "rejected"
same "and carries the admin's words" "$(jval "$BODY" reason)" "That is your aunt, not you — try Meron"
same "and still names the person" "$(jval "$BODY" personName)" "Aster Bekele"

req GET /api/notifications "$SARA" ''
TOLD=$(jpath "$BODY" "any('not approved' in n['title'] for n in d)")
[ "$TOLD" = "True" ] && ok "Sara was notified of the decision" || no "rejection notification" "not found"
echo "     -> $(jpath "$BODY" "d[0]['body']")"

echo
echo "── approval, and what it locks down ──────────────────────────────"
req POST /api/link-requests "$SARA" "{\"personId\":\"$YONAS\"}"
SARA_REQ2=$(jval "$BODY" id)
req PUT "/api/admin/link-requests/$SARA_REQ2" "$ADMIN" '{"status":"approved"}'
check "admin approves the second claim" 200

req GET /api/link-requests/my-status "$SARA" ''
same "she is verified" "$(jval "$BODY" status)" "verified"
same "and the status names her record" "$(jval "$BODY" personName)" "Yonas Bekele"

req GET /api/notifications "$SARA" ''
TOLD=$(jpath "$BODY" "any('You are linked' in n['title'] for n in d)")
[ "$TOLD" = "True" ] && ok "Sara was told she is linked" || no "approval notification" "not found"

req POST /api/link-requests "$DAWIT" "{\"personId\":\"$YONAS\"}"
check "someone else cannot claim a taken record" 409
echo "     -> $(jval "$BODY" error)"

req POST /api/link-requests "$SARA" "{\"personId\":\"$ASTER\"}"
check "an already-linked member cannot claim again" 409

req POST /api/link-requests "$DAWIT" '{"personId":"does-not-exist"}'
check "claiming a person who is not in the tree is refused" 404

req DELETE /api/link-requests/mine "$DAWIT" ''
check "withdrawing with nothing pending says so" 404

summary
