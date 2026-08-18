# Upgrading the pinned Providence

1. Bump `PROVIDENCE_TAG` and `PROVIDENCE_COMMIT` in `PROVIDENCE_PIN`. Nothing else names a version.
2. **Back up first.** The migration is one-way. Capture the database dump and the media tree as one
   operation — captured separately they drift.
3. Rebuild: `docker compose build --no-cache app`.
4. Bring up only the database, then run the migration deliberately:

   ```
   docker compose up -d db
   docker compose run --rm app sh -c 'yes y | php support/bin/caUtils update-database-schema'
   ```

   The `yes y` is not optional. `update-database-schema` accepts no CLI flags and always asks for
   confirmation on STDIN; its `dontConfirm` bypass is a PHP argument the CLI cannot pass. Without a
   piped answer the command waits forever.

5. Bring the rest up: `docker compose up -d`.
6. Re-verify after every bump, because a point release can move any of these: the PHP extension set,
   `caUtils` subcommand names, the search index schema, and whether a full `rebuild-search-index` is
   required.
7. Record the outcome here: which commit, when, what broke.

## Why `/install` stays 404

`docker/nginx/providence.conf` returns 404 for `/install` so the web installer is unreachable on a
running instance. The CLI path above is the supported upgrade route and does not need it. If a
future release moves migration back behind the web installer, re-opening that path is a security
decision that needs its own review — not an edit to the nginx file.
