-- Repoints stored file URLs at the deployed backend.
--
-- ApiService.uploadFile stores an absolute URL ('$baseUrl${data['url']}'),
-- not the relative /uploads/... path the server returns. So rows carry
-- whichever host the uploader's app was built against — this database has a
-- mix of localhost:5000 and localhost:8080 — and every one of them 404s once
-- the data moves to Render.
--
-- Usage:
--   psql "$RENDER_DB_URL" \
--     -v api="https://family-tree-api.onrender.com" \
--     -f scripts/rewrite-upload-urls.sql
--
-- The pattern matches only the scheme+host, so it works both on columns
-- holding a single URL and on the ones holding a JSON array of them.

\set host_pattern 'https?://(localhost|127\\.0\\.0\\.1)(:[0-9]+)?'

BEGIN;

UPDATE people
   SET profile_photo_url = regexp_replace(profile_photo_url, :'host_pattern', :'api', 'g')
 WHERE profile_photo_url LIKE '%localhost%'
    OR profile_photo_url LIKE '%127.0.0.1%';

UPDATE users
   SET profile_photo_url = regexp_replace(profile_photo_url, :'host_pattern', :'api', 'g')
 WHERE profile_photo_url LIKE '%localhost%'
    OR profile_photo_url LIKE '%127.0.0.1%';

UPDATE posts
   SET photos = regexp_replace(photos, :'host_pattern', :'api', 'g'),
       videos = regexp_replace(videos, :'host_pattern', :'api', 'g'),
       files  = regexp_replace(files,  :'host_pattern', :'api', 'g')
 WHERE photos LIKE '%localhost%' OR photos LIKE '%127.0.0.1%'
    OR videos LIKE '%localhost%' OR videos LIKE '%127.0.0.1%'
    OR files  LIKE '%localhost%' OR files  LIKE '%127.0.0.1%';

-- messages predates the current models and is not in AutoMigrate, but the
-- dump carries it, so leave its URLs consistent with the rest.
UPDATE messages
   SET media_url = regexp_replace(media_url, :'host_pattern', :'api', 'g')
 WHERE media_url LIKE '%localhost%'
    OR media_url LIKE '%127.0.0.1%';

COMMIT;
