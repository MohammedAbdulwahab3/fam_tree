#!/usr/bin/env bash
# Notifications reach the right people and nobody else, and preferences hold.
set -u
source "$(dirname "$0")/lib.sh"

count() {
  req GET /api/notifications/unread-count "$1" ''
  jval "$BODY" count
}

titles() {
  req GET /api/notifications "$1" ''
  jpath "$BODY" "', '.join(n['title'] for n in d)"
}

echo "── setup ─────────────────────────────────────────────────────────"
A=$(register anna@t.local "Anna Girma" secret123)
B=$(register bereket@t.local "Bereket Tadesse" secret123)
C=$(register chaltu@t.local "Chaltu Bekele" secret123)
echo "  three members registered"

echo
echo "── a new post notifies the rest of the family ────────────────────"
same "everyone starts with no notifications" "$(count "$B")" "0"

req POST /api/posts "$A" '{"content":"Photos from the wedding"}'
POST_ID=$(jval "$BODY" id)
sleep 1

same "Bereket is told about Anna's post" "$(count "$B")" "1"
same "Chaltu is told too" "$(count "$C")" "1"
same "Anna is not told about her own post" "$(count "$A")" "0"
echo "     -> $(titles "$B")"

echo
echo "── a comment notifies the post's author ──────────────────────────"
req POST "/api/posts/$POST_ID/comments" "$B" '{"text":"She looks so happy"}'
sleep 1
same "Anna hears that Bereket commented" "$(count "$A")" "1"
echo "     -> $(titles "$A")"

req POST "/api/posts/$POST_ID/comments" "$A" '{"text":"Thank you"}'
sleep 1
same "commenting on your own post notifies nobody" "$(count "$A")" "1"

echo
echo "── mentions find people whose names have spaces ──────────────────"
before_c=$(count "$C")
req POST "/api/posts/$POST_ID/comments" "$A" '{"text":"Ask @Chaltu Bekele about the photos"}'
sleep 1
same "Chaltu is told she was mentioned" "$(count "$C")" "$((before_c + 1))"

echo
echo "── preferences are respected ─────────────────────────────────────"
req PUT /api/notifications/preferences "$C" '{"postsEnabled":false}'
check "a member can switch posts off" 200
same "and it is actually stored as off" "$(jpath "$BODY" "str(d['postsEnabled']).lower()")" "false"

req GET /api/notifications/preferences "$C" ''
same "it is still off when read back" "$(jpath "$BODY" "str(d['postsEnabled']).lower()")" "false"
same "the other switches are untouched" "$(jpath "$BODY" "str(d['commentsEnabled']).lower()")" "true"

before_c=$(count "$C")
before_b=$(count "$B")
req POST /api/posts "$A" '{"content":"Another post"}'
sleep 1
same "Chaltu turned posts off and gets nothing" "$(count "$C")" "$before_c"
same "Bereket left them on and gets one" "$(count "$B")" "$((before_b + 1))"

echo
echo "── announcements always get through ──────────────────────────────"
promote anna@t.local
before_c=$(count "$C")
req POST /api/admin/announcements "$A" '{"title":"Reunion","message":"Save the date"}'
check "the admin sends an announcement" 201
same "it reaches even the member who muted posts" "$(count "$C")" "$((before_c + 1))"

echo
echo "── reading and clearing ──────────────────────────────────────────"
req PUT /api/notifications/read-all "$B" '{}'
check "mark all as read" 200
same "the unread count goes to zero" "$(count "$B")" "0"

req GET /api/notifications "$B" ''
same "but the notifications are still listed" \
  "$(jpath "$BODY" "'yes' if len(d) > 0 else 'no'")" "yes"

req DELETE /api/notifications "$B" ''
check "clear the whole list" 200
req GET /api/notifications "$B" ''
same "and now it is empty" "$(jpath "$BODY" "len(d)")" "0"

echo
echo "── one member's notifications are their own ──────────────────────"
req GET /api/notifications "$C" ''
NOTIF_ID=$(jpath "$BODY" "d[0]['id'] if d else ''")
req DELETE "/api/notifications/$NOTIF_ID" "$A" ''
check "you cannot dismiss someone else's notification" 404

summary
