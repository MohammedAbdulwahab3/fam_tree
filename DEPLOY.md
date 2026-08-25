# Deploying to Render

Three resources, all defined in [`render.yaml`](render.yaml) and all on the free
tier:

| Resource | Type | What it is |
|---|---|---|
| `family-tree-db` | Postgres | The database |
| `family-tree-api` | Docker web service | The Go server, from `backend/Dockerfile` |
| `family-tree-web` | Static site | The Flutter web bundle, built by `family_tree/render-build.sh` |

The static site is built against the API's hostname, which Render fills in via
the `fromService` block — you do not have to paste a URL anywhere.

---

## Read this before you start

Three free-tier limits shape the deployment. None of them is a bug to fix later;
decide now whether you can live with them.

**The database is deleted 30 days after it is created.** Render does not warn
twice. Put a reminder in your calendar for day 25 and either upgrade to the $7
plan or dump and recreate. `scripts/dump-local-db.sh` points at the local
container, but the same `pg_dump` line works against Render's external URL.

**Uploads do not survive a deploy.** A free instance has no persistent disk, so
`./uploads` is part of the container filesystem and is discarded every time the
service restarts or redeploys. The photos your database already references are
baked into the image from `backend/seed_uploads/`, so they keep working — but
any photo uploaded *after* deployment disappears at the next deploy. Fixing this
properly means a paid instance with a disk (the commented block in
`render.yaml`) or moving uploads to object storage.

**The API sleeps after 15 minutes idle.** The first request after a quiet spell
waits roughly 50 seconds while the container starts. Logins will feel broken to
anyone who does not know this.

---

## 1. Get the config onto `main`

`render.yaml` must be on the branch Render tracks.

```bash
git checkout main
git merge public-tree-and-person-editor
git push origin main
```

## 2. Create the Blueprint

1. Render Dashboard → **New** → **Blueprint**.
2. Pick the `MohammedAbdulwahab3/fam_tree` repo. Render finds `render.yaml` at
   the root and shows the three resources.
3. **Apply**.

The first build takes a while — the static site clones the Flutter SDK before it
can compile, which is most of the ten-or-so minutes.

When it finishes you will have:

- API: `https://family-tree-api.onrender.com`
- App: `https://family-tree-web.onrender.com`

(Render appends a suffix if those names are taken. Use whatever the dashboard
shows.)

## 3. Check the API before touching the data

```bash
curl https://family-tree-api.onrender.com/ping
# {"message":"pong"}
```

`AutoMigrate` has now created the tables in an otherwise empty database.

## 4. Move your local data across

Grab the external connection string from the `family-tree-db` page in the
dashboard — the **External Database URL**, not the internal one, which is only
reachable from inside Render.

```bash
export RENDER_DB_URL='postgresql://family_tree:...@dpg-....oregon-postgres.render.com/family_tree'

# 1. Dump the local Docker database (11 users, 205 people, 5 posts).
./scripts/dump-local-db.sh family_tree_dump.sql

# 2. Replay it. The dump drops and recreates its own objects, so it is safe
#    over the tables AutoMigrate just made.
psql "$RENDER_DB_URL" -v ON_ERROR_STOP=1 -f family_tree_dump.sql

# 3. Repoint the stored file URLs at the deployed API.
psql "$RENDER_DB_URL" -v ON_ERROR_STOP=1 \
  -v api="https://family-tree-api.onrender.com" \
  -f scripts/rewrite-upload-urls.sql
```

Step 3 is not optional. `ApiService.uploadFile` stores an **absolute** URL
(`'$baseUrl${data['url']}'`) rather than the relative path the server returns,
so eight rows in your database currently point at `http://localhost:5000` and
`http://localhost:8080`. Without the rewrite every one of those images 404s.

Verify:

```bash
curl https://family-tree-api.onrender.com/public/stats
# {"generations":6,"people":205}
```

Four of the referenced files exist and are baked into the image. The other four
(`test.jpg`, `a.png`, `b.png`, `v.mp4`, `doc.pdf`) are leftovers from testing
that were never on disk anywhere; they will 404 whatever you do.

## 5. Open the app

`https://family-tree-web.onrender.com` — sign in with your existing account, the
one that came across in the dump.

If you started from an empty database instead, register, then promote yourself:

```bash
psql "$RENDER_DB_URL" -c "UPDATE users SET role='admin' WHERE email='you@example.com';"
```

---

## Things that will bite you

**Changing the API URL means rebuilding the app.** `AppConfig.apiBaseUrl` is a
`String.fromEnvironment`, resolved at compile time. Editing an environment
variable in the Render dashboard does nothing until the static site rebuilds.

**Do not rotate `JWT_SECRET`.** Render generates it once. Changing it signs new
sessions with a different key and logs every member out.

**`GIN_MODE=release` is load-bearing.** `config.RequireSecret` refuses to boot in
release mode without `JWT_SECRET`, which is the behaviour you want: a missing
secret fails the deploy instead of quietly signing tokens with the dev default
that is public in this repository.

**Region matters.** The database and the API must sit in the same region or the
internal connection string will not resolve. Both are pinned to `oregon` in
`render.yaml`; change them together or not at all.

**`FAMILY_TREE_ID` appears twice** — once for the API, once for the web build.
They must match. Registration files new members under the API's value and the
app only ever reads its own.

## Upgrading off the free tier later

In `render.yaml`, on the `family-tree-api` service, uncomment `plan: starter`
and the `disk:` block together, and change the database's `plan: free` to
`plan: starter`. Once a real disk holds the uploads, drop the
`COPY seed_uploads/` line from `backend/Dockerfile` — it would otherwise
overwrite nothing but is dead weight.
