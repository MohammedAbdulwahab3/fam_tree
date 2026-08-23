# Family Tree

A private app for one extended family to keep its own history: who everyone is,
how they are related, and the things worth not losing.

It is built for a family, not for the public. There is no sign-up link to share,
no discovery, no feed of strangers. Somebody adds you to the tree, you create an
account, you point at which person in the tree is you, and an admin confirms it.
From then on the record is yours to fill in.

Two languages, English and አማርኛ, including per-person names in each. The people
using it are not all confident with phones, which is the constraint that shapes
most of the interface: large controls, one thing per screen, plain language, and
nothing destructive without a question first.

## What is here

```
backend/       Go + Postgres API
family_tree/   Flutter app — Android, iOS, web
```

Two halves of one product. Read `backend/README.md` for the API and how to run
it; the rest of this file is orientation.

## Running it

You need Go 1.24, Flutter 3.6 or newer, and Postgres.

```bash
# 1. A database
cd backend
docker compose up -d

# 2. The API, on :8080
export JWT_SECRET="$(openssl rand -base64 48)"
export DATABASE_URL="host=127.0.0.1 port=5433 user=postgres password=postgres dbname=family_tree sslmode=disable"
go run .

# 3. Optionally, a family to look at
go run . --seed

# 4. The app
cd ../family_tree
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Then register in the app, and make yourself an admin:

```bash
cd backend && go run ./cmd/make_admin you@example.com
```

That is the only way to create the first admin, and it is deliberate: an HTTP
route that grants admin is a route anybody can call.

### Building for real

`API_BASE_URL` must be HTTPS in a release build — the app carries a session
token on every request, and a debug assertion will stop you shipping one that
does not.

```bash
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

## How it fits together

**Accounts and people are separate.** An account is a login. A person is a
record in the family's history. They are joined when an admin confirms a claim,
and they come apart again when somebody deletes their account — the person stays
in the tree, unclaimed, because it belongs to the family rather than to a login.

**Descent is stored one way.** A person names their parents; the server derives
everybody's children on read. Both directions used to be written by the app in
two separate requests, and a failure between them left somebody who had a parent
and simultaneously counted as a root.

**One tree per deployment.** The app has no tree picker, so there is nothing to
switch between. `FAMILY_TREE_ID` sets it on both sides.

**The app polls.** There are no websockets. The tree is fetched with an ETag, so
an unchanged poll costs a round trip and no body, and hands the canvas back the
identical list so it does not relayout.

**The type is bundled, not fetched.** Manrope and Noto Sans Ethiopic are
committed under `family_tree/assets/fonts` rather than downloaded on first
launch. A face that arrives over the network arrives late on a poor connection,
and until it does, Amharic renders in whatever the device happens to have —
which is the thing choosing one bilingual family was meant to prevent.

**Notifications are in-app only.** There is no push channel and no mail server.
An admin reaching somebody by phone is what stands in for a verification email —
which is why a forgotten password is recovered with a code an admin issues, and
why the screen that asks for one explains where it comes from.

## Who can do what

|                               | Anybody signed in | Linked member | Admin |
|-------------------------------|:-----------------:|:-------------:|:-----:|
| See the family tree           | ● | ● | ● |
| Read and write the feed       | ● | ● | ● |
| Ask to be linked to a person  | ● | — | ● |
| Edit their own person record  | — | ● | ● |
| Add, move and remove people   | — | — | ● |
| Set parents and marriages     | — | — | ● |
| Confirm who is who            | — | — | ● |
| Manage accounts and roles     | — | — | ● |
| Suspend an account            | — | — | ● |
| Announce something            | — | — | ● |

Every one of these is enforced by the server. The app hides what you cannot do
so you are not looking for it, which is honesty rather than security.

## Tests

```bash
cd backend
go test ./...          # unit and handler tests, no database needed
./e2e/run.sh           # end-to-end, needs the Postgres container

cd ../family_tree
flutter analyze
flutter test test/     # unit and widget tests
```

`family_tree/test/integration/` talks to a running backend and skips unless you
give it one:

```bash
flutter test test/integration \
  --dart-define=TEST_API_URL=http://localhost:8080 \
  --dart-define=TEST_ADMIN_EMAIL=you@example.com \
  --dart-define=TEST_ADMIN_PASSWORD=...
```

CI runs everything except that last suite, on every push and pull request.
