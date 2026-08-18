# Upgrading the pinned Providence

1. Bump `PROVIDENCE_TAG` and `PROVIDENCE_COMMIT` in `PROVIDENCE_PIN`. Nothing else names a version.
2. Take a backup that is consistent across the database and the media tree — they drift if captured
   separately.
3. Rebuild: `docker compose build --no-cache app`.
4. The entrypoint sees an existing schema and runs the schema migration. **It exits non-zero rather
   than serving a half-migrated instance**; that is the intended behaviour, not a crash loop to work
   around.
5. Re-verify after every bump, because a point release can move any of them: PHP extension set,
   `caUtils` subcommand names, the search index schema, and whether a full
   `rebuild-search-index` is required.
6. Record the outcome here: which commit, when, what broke.
