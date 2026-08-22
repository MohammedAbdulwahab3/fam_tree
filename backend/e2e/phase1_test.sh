#!/usr/bin/env bash
# End-to-end check of the routes Phase 1 registered.
API=${API:-http://localhost:5099}
pass=0; fail=0

check() { # check <label> <expected-status> <actual-status> [body]
  if [ "$2" = "$3" ]; then
    printf '  \033[32mPASS\033[0m  %-52s %s\n' "$1" "$3"; pass=$((pass+1))
  else
    printf '  \033[31mFAIL\033[0m  %-52s got %s want %s\n     %s\n' "$1" "$3" "$2" "$4"; fail=$((fail+1))
  fi
}

req() { # req <method> <path> <token> <json> -> sets STATUS and BODY
  local out
  if [ -n "$4" ]; then
    out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "$4")
  else
    out=$(curl -s -w $'\n%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3")
  fi
  STATUS=$(echo "$out" | tail -1); BODY=$(echo "$out" | sed '$d')
}

jval() { echo "$1" | python3 -c "import sys,json;print(json.load(sys.stdin).get('$2',''))" 2>/dev/null; }

echo "── setup ─────────────────────────────────────────────────────────"
ADMIN_TOKEN=$(curl -s -X POST $API/register -H 'Content-Type: application/json' \
  -d '{"email":"admin@test.local","password":"secret123","name":"Admin Abebe"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
curl -s -X POST $API/init-admin -H 'Content-Type: application/json' \
  -d '{"email":"admin@test.local","secret_key":"FamilyTree2026AdminSecret"}' > /dev/null

MEMBER_JSON=$(curl -s -X POST $API/register -H 'Content-Type: application/json' \
  -d '{"email":"member@test.local","password":"secret123","name":"Sara Tesfaye"}')
MEMBER_TOKEN=$(echo "$MEMBER_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
MEMBER_ID=$(echo "$MEMBER_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin)['user']['id'])")

OTHER_TOKEN=$(curl -s -X POST $API/register -H 'Content-Type: application/json' \
  -d '{"email":"other@test.local","password":"secret123","name":"Dawit Kebede"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
echo "  admin, member, other registered"

echo
echo "── A-01/A-02  feed posting and deleting ──────────────────────────"
req POST /api/posts "$MEMBER_TOKEN" '{"content":"First family photo","familyTreeId":"main-family-tree","photos":["/uploads/x.jpg"]}'
check "member creates a post" 201 "$STATUS" "$BODY"
POST_ID=$(jval "$BODY" id)
AUTHOR=$(jval "$BODY" userName)
[ "$AUTHOR" = "Sara Tesfaye" ] && { printf '  \033[32mPASS\033[0m  %-52s %s\n' "author taken from token, not body" "$AUTHOR"; pass=$((pass+1)); } \
                              || { printf '  \033[31mFAIL\033[0m  author was %s\n' "$AUTHOR"; fail=$((fail+1)); }

req POST /api/posts "$MEMBER_TOKEN" '{"content":"   ","familyTreeId":"main-family-tree"}'
check "empty post is refused with a reason" 400 "$STATUS" "$BODY"

req DELETE "/api/posts/$POST_ID" "$OTHER_TOKEN" ''
check "someone else cannot delete your post" 403 "$STATUS" "$BODY"

req DELETE "/api/posts/$POST_ID" "$MEMBER_TOKEN" ''
check "author deletes their own post" 200 "$STATUS" "$BODY"

req POST /api/posts "$MEMBER_TOKEN" '{"content":"Second post","familyTreeId":"main-family-tree"}'
POST2=$(jval "$BODY" id)
req DELETE "/api/posts/$POST2" "$ADMIN_TOKEN" ''
check "admin deletes any post" 200 "$STATUS" "$BODY"

echo
echo "── comments ──────────────────────────────────────────────────────"
req POST /api/posts "$MEMBER_TOKEN" '{"content":"Post with comments","familyTreeId":"main-family-tree"}'
POST3=$(jval "$BODY" id)
req POST "/api/posts/$POST3/comments" "$OTHER_TOKEN" '{"text":"Lovely!"}'
check "member comments on a post" 201 "$STATUS" "$BODY"
COMMENT_ID=$(jval "$BODY" id)

req PUT "/api/comments/$COMMENT_ID" "$OTHER_TOKEN" '{"text":"Lovely photo!"}'
check "author edits their own comment" 200 "$STATUS" "$BODY"

req PUT "/api/comments/$COMMENT_ID" "$MEMBER_TOKEN" '{"text":"hijacked"}'
check "nobody can rewrite someone else's comment" 403 "$STATUS" "$BODY"

req DELETE "/api/comments/$COMMENT_ID" "$MEMBER_TOKEN" ''
check "post author can remove a comment on their post" 200 "$STATUS" "$BODY"

echo
echo "── reactions ─────────────────────────────────────────────────────"
req POST "/api/posts/$POST3/reactions" "$OTHER_TOKEN" '{"emoji":"❤️"}'
check "reaction works without a userId in the body" 201 "$STATUS" "$BODY"
req POST "/api/posts/$POST3/reactions" "$OTHER_TOKEN" '{"emoji":"❤️"}'
check "same emoji again removes the reaction" 200 "$STATUS" "$BODY"

echo
echo "── events ────────────────────────────────────────────────────────"
req POST /api/events "$MEMBER_TOKEN" '{"title":"Meskel gathering","location":"Addis","dateTime":"2026-09-27T10:00:00Z","familyTreeId":"main-family-tree"}'
check "member creates an event" 201 "$STATUS" "$BODY"
EVENT_ID=$(jval "$BODY" id)

req POST /api/events "$MEMBER_TOKEN" '{"location":"Addis","dateTime":"2026-09-27T10:00:00Z"}'
check "event with no title is refused" 400 "$STATUS" "$BODY"

req PUT "/api/events/$EVENT_ID" "$MEMBER_TOKEN" '{"title":"Meskel gathering (moved)","dateTime":"2026-09-28T10:00:00Z"}'
check "organiser edits their event" 200 "$STATUS" "$BODY"

req PUT "/api/events/$EVENT_ID" "$OTHER_TOKEN" '{"title":"nope","dateTime":"2026-09-28T10:00:00Z"}'
check "a non-organiser cannot edit it" 403 "$STATUS" "$BODY"

req POST "/api/events/$EVENT_ID/rsvp" "$OTHER_TOKEN" '{"status":"yes"}'
check "member RSVPs" 200 "$STATUS" "$BODY"

req DELETE "/api/events/$EVENT_ID" "$OTHER_TOKEN" ''
check "a non-organiser cannot cancel it" 403 "$STATUS" "$BODY"
req DELETE "/api/events/$EVENT_ID" "$ADMIN_TOKEN" ''
check "admin cancels any event" 200 "$STATUS" "$BODY"

echo
echo "── A-12  notification dismissal ──────────────────────────────────"
req POST /api/admin/announcements "$ADMIN_TOKEN" '{"title":"Reunion","message":"Save the date"}'
check "admin sends an announcement" 201 "$STATUS" "$BODY"

req GET /api/notifications/unread-count "$MEMBER_TOKEN" ''
BEFORE=$(jval "$BODY" count)

req GET /api/notifications "$MEMBER_TOKEN" ''
NOTIF_ID=$(echo "$BODY" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d[0]['id'] if d else '')")
req DELETE "/api/notifications/$NOTIF_ID" "$MEMBER_TOKEN" ''
check "member dismisses a notification" 200 "$STATUS" "$BODY"

req DELETE "/api/notifications/$NOTIF_ID" "$MEMBER_TOKEN" ''
check "dismissing it twice reads as already gone" 404 "$STATUS" "$BODY"

req GET /api/notifications/unread-count "$MEMBER_TOKEN" ''
COUNT=$(jval "$BODY" count)
[ "$COUNT" = "$((BEFORE-1))" ] && { printf '  \033[32mPASS\033[0m  %-52s %s\n' "unread count drops after dismissal" "$BEFORE -> $COUNT"; pass=$((pass+1)); } \
                   || { printf '  \033[31mFAIL\033[0m  count went %s -> %s\n' "$BEFORE" "$COUNT"; fail=$((fail+1)); }

echo
echo "── persons (admin routes the client now uses) ────────────────────"
req POST /api/admin/persons "$ADMIN_TOKEN" '{"firstName":"Mamaduu","lastName":"Ali","familyTreeId":"main-family-tree","gender":"male"}'
check "admin adds a person" 201 "$STATUS" "$BODY"
PERSON_ID=$(jval "$BODY" id)
req DELETE "/api/admin/persons/$PERSON_ID" "$MEMBER_TOKEN" ''
check "a member cannot delete a person" 403 "$STATUS" "$BODY"
req DELETE "/api/admin/persons/$PERSON_ID" "$ADMIN_TOKEN" ''
check "admin deletes a person" 200 "$STATUS" "$BODY"

echo
echo "──────────────────────────────────────────────────────────────────"
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
