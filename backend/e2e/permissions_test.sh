#!/usr/bin/env bash
# Who may do what: posting, commenting, reacting, and managing people.
set -u
source "$(dirname "$0")/lib.sh"

echo "── setup ─────────────────────────────────────────────────────────"
ADMIN_TOKEN=$(register admin@test.local "Admin Abebe" secret123)
promote admin@test.local
# The token was minted before the promotion, but the role is read from the
# database on every request, so it is already an admin's token.

read -r MEMBER_TOKEN MEMBER_ID <<<"$(register_full member@test.local "Sara Tesfaye" secret123)"
OTHER_TOKEN=$(register other@test.local "Dawit Kebede" secret123)
echo "  admin, member, other registered"

echo
echo "── the feed ──────────────────────────────────────────────────────"
req POST /api/posts "$MEMBER_TOKEN" '{"content":"First family photo","photos":["/uploads/x.jpg"]}'
check "member creates a post" 201
POST_ID=$(jval "$BODY" id)
same "author taken from the token, not the body" "$(jval "$BODY" userName)" "Sara Tesfaye"

req POST /api/posts "$MEMBER_TOKEN" '{"content":"   "}'
check "empty post is refused with a reason" 400

req POST /api/posts "$MEMBER_TOKEN" '{"content":"spoofed","userId":"someone-else","userName":"Someone Else"}'
same "an author in the body is ignored" "$(jval "$BODY" userName)" "Sara Tesfaye"

req DELETE "/api/posts/$POST_ID" "$OTHER_TOKEN" ''
check "someone else cannot delete your post" 403

req DELETE "/api/posts/$POST_ID" "$MEMBER_TOKEN" ''
check "author deletes their own post" 200

req POST /api/posts "$MEMBER_TOKEN" '{"content":"Second post"}'
POST2=$(jval "$BODY" id)
req DELETE "/api/posts/$POST2" "$ADMIN_TOKEN" ''
check "admin deletes any post" 200

echo
echo "── paging ────────────────────────────────────────────────────────"
for i in 1 2 3 4 5; do
  req POST /api/posts "$MEMBER_TOKEN" "{\"content\":\"post $i\"}" >/dev/null
done
req GET "/api/posts?limit=2" "$MEMBER_TOKEN" ''
check "the feed answers a page" 200
same "the page holds the requested number" "$(jpath "$BODY" "len(d['posts'])")" "2"
same "and says more remain" "$(jpath "$BODY" "str(d['hasMore']).lower()")" "true"
CURSOR=$(jval "$BODY" nextCursor)
[ -n "$CURSOR" ] && ok "a cursor is offered" || no "a cursor is offered" "nextCursor was empty"

req GET "/api/posts?limit=2&before=$CURSOR" "$MEMBER_TOKEN" ''
check "the cursor fetches the next page" 200

req GET "/api/posts?before=not-a-timestamp" "$MEMBER_TOKEN" ''
check "a malformed cursor is refused" 400

echo
echo "── comments ──────────────────────────────────────────────────────"
req POST /api/posts "$MEMBER_TOKEN" '{"content":"Post with comments"}'
POST3=$(jval "$BODY" id)
req POST "/api/posts/$POST3/comments" "$OTHER_TOKEN" '{"text":"Lovely!"}'
check "member comments on a post" 201
COMMENT_ID=$(jval "$BODY" id)

req GET "/api/posts/$POST3/comments" "$MEMBER_TOKEN" ''
same "comments come back with a total" "$(jpath "$BODY" "d['total']")" "1"

req PUT "/api/comments/$COMMENT_ID" "$OTHER_TOKEN" '{"text":"Lovely photo!"}'
check "author edits their own comment" 200

req PUT "/api/comments/$COMMENT_ID" "$MEMBER_TOKEN" '{"text":"hijacked"}'
check "nobody can rewrite someone else's comment" 403

req PUT "/api/comments/$COMMENT_ID" "$ADMIN_TOKEN" '{"text":"admin rewrite"}'
check "not even an admin can rewrite it" 403

req DELETE "/api/comments/$COMMENT_ID" "$MEMBER_TOKEN" ''
check "the post's author can remove a comment on it" 200

echo
echo "── reactions ─────────────────────────────────────────────────────"
req POST "/api/posts/$POST3/reactions" "$OTHER_TOKEN" '{"emoji":"❤️"}'
check "reaction works without a userId in the body" 200
req POST "/api/posts/$POST3/reactions" "$OTHER_TOKEN" '{"emoji":"👍"}'
check "changing the emoji replaces it" 200
req POST "/api/posts/$POST3/reactions" "$OTHER_TOKEN" '{"emoji":"👍"}'
check "the same emoji again takes it back" 200
req POST "/api/posts/$POST3/reactions" "$OTHER_TOKEN" '{"emoji":"🎉"}'
check "and reacting again afterwards still works" 200
req POST "/api/posts/does-not-exist/reactions" "$OTHER_TOKEN" '{"emoji":"❤️"}'
check "reacting to a missing post is a 404" 404

echo
echo "── people ────────────────────────────────────────────────────────"
req POST /api/admin/persons "$ADMIN_TOKEN" '{"firstName":"Mamaduu","lastName":"Ali","gender":"male"}'
check "admin adds a person" 201
ROOT_ID=$(jval "$BODY" id)
same "a new person is unclaimed" "$(jval "$BODY" authUserId)" ""

req POST /api/admin/persons "$MEMBER_TOKEN" '{"firstName":"Nope"}'
check "a member cannot add a person" 403

req POST /api/admin/persons "$ADMIN_TOKEN" '{"firstName":"Ghost","relationships":{"parents":["not-a-real-id"]}}'
check "a parent who is not in the tree is refused" 400

req POST /api/admin/persons "$ADMIN_TOKEN" "{\"firstName\":\"Issa\",\"relationships\":{\"parents\":[\"$ROOT_ID\"]}}"
check "admin adds a child in one request" 201
CHILD_ID=$(jval "$BODY" id)

req GET /api/persons "$ADMIN_TOKEN" ''
same "the parent's children are derived on read" \
  "$(jpath "$BODY" "[p for p in d if p['id']=='$ROOT_ID'][0]['relationships']['children'][0]")" \
  "$CHILD_ID"

req DELETE "/api/admin/persons/$ROOT_ID" "$ADMIN_TOKEN" ''
check "deleting a parent with children is refused" 409

req DELETE "/api/admin/persons/$ROOT_ID" "$MEMBER_TOKEN" ''
check "a member cannot delete a person" 403

req DELETE "/api/admin/persons/$ROOT_ID?cascade=true" "$ADMIN_TOKEN" ''
check "cascade removes the whole subtree in one request" 200
same "and reports both" "$(jval "$BODY" count)" "2"

echo
echo "── admin edits do not wipe what they omit ────────────────────────"
req POST /api/admin/persons "$ADMIN_TOKEN" '{"firstName":"Kulsum","lastName":"Issa","birthPlace":"Harar","occupation":"Teacher","photos":["/uploads/k.jpg"]}'
PERSON_ID=$(jval "$BODY" id)
req PUT "/api/admin/persons/$PERSON_ID" "$ADMIN_TOKEN" '{"bio":"Loved gardening"}'
check "admin updates one field" 200
same "the new field is saved" "$(jval "$BODY" bio)" "Loved gardening"
same "the name survives" "$(jval "$BODY" firstName)" "Kulsum"
same "the birthplace survives" "$(jval "$BODY" birthPlace)" "Harar"
same "the photos survive" "$(jpath "$BODY" "len(d['photos'])")" "1"

echo
echo "── notifications ─────────────────────────────────────────────────"
req POST /api/admin/announcements "$ADMIN_TOKEN" '{"title":"Reunion","message":"Save the date"}'
check "admin sends an announcement" 201

req POST /api/admin/announcements "$MEMBER_TOKEN" '{"title":"Nope","message":"Nope"}'
check "a member cannot send one" 403

req GET /api/notifications/unread-count "$MEMBER_TOKEN" ''
BEFORE=$(jval "$BODY" count)

req GET /api/notifications "$MEMBER_TOKEN" ''
NOTIF_ID=$(jpath "$BODY" "d[0]['id'] if d else ''")
req DELETE "/api/notifications/$NOTIF_ID" "$MEMBER_TOKEN" ''
check "member dismisses a notification" 200

req DELETE "/api/notifications/$NOTIF_ID" "$MEMBER_TOKEN" ''
check "dismissing it twice reads as already gone" 404

req GET /api/notifications/unread-count "$MEMBER_TOKEN" ''
same "the unread count drops" "$(jval "$BODY" count)" "$((BEFORE - 1))"

summary
