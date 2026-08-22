#!/usr/bin/env bash
# Phase 2: notifications are recorded again, and reminders actually arrive.
API=${API:-http://localhost:5099}
pass=0; fail=0

ok() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  \033[31mFAIL\033[0m  %s\n     %s\n' "$1" "$2"; fail=$((fail+1)); }
same() { [ "$2" = "$3" ] && ok "$1 ($3)" || no "$1" "got $2 want $3"; }

tok() { curl -s -X POST $API/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\",\"password\":\"secret123\",\"name\":\"$2\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])"; }

get() { curl -s "$API$1" -H "Authorization: Bearer $2"; }
post() { curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
put() { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }

count() { get /api/notifications/unread-count "$1" | python3 -c "import sys,json;print(json.load(sys.stdin)['count'])"; }
titles() { get /api/notifications "$1" | python3 -c "import sys,json;print(' | '.join(n['title'] for n in json.load(sys.stdin)))"; }
jid() { python3 -c "import sys,json;print(json.load(sys.stdin)['id'])"; }

echo "── setup ─────────────────────────────────────────────────────────"
A=$(tok anna@t.local "Anna Girma")
B=$(tok bereket@t.local "Bereket Haile")
C=$(tok chaltu@t.local "Chaltu Bekele")
echo "  three members registered"

echo
echo "── A-03  a new post notifies the rest of the family ──────────────"
same "everyone starts with no notifications" "$(count "$B")" "0"
POST_ID=$(post /api/posts "$A" '{"content":"Photos from the wedding","familyTreeId":"main-family-tree"}' | jid)
sleep 1
same "Bereket is told about Anna's post" "$(count "$B")" "1"
same "Chaltu is told too" "$(count "$C")" "1"
same "Anna is not told about her own post" "$(count "$A")" "0"
echo "     -> $(titles "$B")"

echo
echo "── a comment notifies the post's author ──────────────────────────"
post "/api/posts/$POST_ID/comments" "$B" '{"text":"She looks so happy"}' > /dev/null
sleep 1
same "Anna hears that Bereket commented" "$(count "$A")" "1"
echo "     -> $(titles "$A")"

echo
echo "── chat does not flood the notifications list ────────────────────"
before=$(count "$B")
for i in 1 2 3 4 5; do
  post /api/messages "$A" "{\"text\":\"message $i\",\"familyTreeId\":\"main-family-tree\",\"type\":\"text\"}" > /dev/null
done
sleep 1
same "five chat messages add no notification rows" "$(count "$B")" "$before"

echo
echo "── preferences are respected ─────────────────────────────────────"
put /api/notifications/preferences "$C" \
  '{"eventsEnabled":true,"postsEnabled":false,"messagesEnabled":true,"commentsEnabled":true,"mentionsEnabled":true}' > /dev/null
before_c=$(count "$C")
post /api/posts "$A" '{"content":"Another post","familyTreeId":"main-family-tree"}' > /dev/null
sleep 1
same "Chaltu turned posts off and gets nothing" "$(count "$C")" "$before_c"
before_b=$(count "$B")
same "Bereket left them on and still gets one" "$(count "$B")" "$((before_b))"
[ "$before_b" -gt 1 ] && ok "Bereket's count grew with the second post ($before_b)" \
                      || no "Bereket's count" "expected >1, got $before_b"

echo
echo "── A-03  reminders are actually delivered ────────────────────────"
DUE=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=5)).isoformat().replace('+00:00','Z'))")
post /api/reminders "$B" "{\"entityType\":\"event\",\"entityId\":\"none\",\"scheduledTime\":\"$DUE\",\"reminderType\":\"custom\",\"title\":\"Call grandmother\",\"body\":\"You said you would ring her today\"}" > /dev/null
before_r=$(count "$B")
echo "  waiting up to 100s for the reminder ticker..."
delivered=0
for i in $(seq 1 20); do
  sleep 5
  now=$(count "$B")
  if [ "$now" -gt "$before_r" ]; then delivered=1; break; fi
done
[ "$delivered" = "1" ] && ok "an overdue reminder arrived as a notification" \
                       || no "reminder delivery" "count stayed at $before_r after 100s"
echo "     -> $(titles "$B")"

# GetReminders deliberately lists only pending ones, so check the row itself.
SENT=$(docker exec family-tree-postgres psql -U postgres -d ${TEST_DB:-ft_e2e} -tAc \
  "SELECT is_sent FROM reminders WHERE title='Call grandmother';")
[ "$SENT" = "t" ] && ok "the reminder is marked sent, so it will not repeat" \
                  || no "reminder isSent" "got '$SENT'"
STILL=$(get /api/reminders "$B" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
same "a delivered reminder leaves the pending list" "$STILL" "0"

echo
echo "──────────────────────────────────────────────────────────────────"
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
