# providence-bos

First-party container, configuration overlay and deploy path for running
[CollectiveAccess Providence](https://github.com/collectiveaccess/providence) as a hosted,
**single-tenant** instance behind BOS.

Upstream Providence is fetched at build time at an immutable commit, is **not vendored** into
this repository, and is **not modified**. The pin is the only place a version appears:

```
PROVIDENCE_TAG=2.0.11
PROVIDENCE_COMMIT=aedf6fc0e18c55f2184c6d5f5a879eeca13019ce   # released 2026-03-16
```

## Status — read this before trusting anything here

This is a **reviewed scaffold, not a verified deployment.** The design behind it went through two
independent senior security gates, both of which returned a failing verdict on the original plan;
what survives is written down in the BOS repo at
`docs/status/2026-08-18-providence-app-install-design.md`.

The `caUtils` contract has since been **verified against the pinned commit** and the entrypoint
corrected — see `docs/first-install.md` for the flag-by-flag reading. Three things it changed:

- `--overwrite` is a **bare flag** whose own help says all existing data will be deleted. An earlier
  revision of the entrypoint passed `--overwrite 0`, which is not a false value — it is the flag,
  set. Removed.
- `update-database-schema` accepts **no CLI options** and always asks for confirmation on STDIN, so
  running it on container start hangs forever instead of serving. Migration is now an opt-in
  operator step (`CA_AUTO_MIGRATE=1`, or the documented command in `docs/upgrade.md`).
- `caUtils install` has **no `--admin-password`**. That variable is gone from `.env.example`.

Still not done, and load-bearing:

- **No image has been built and no instance has been booted from this tree.** The flags are read
  from source; the install has not been executed end to end.

## What this repo deliberately does NOT do

**There is no single sign-on here.** Users log into Providence with Providence credentials, held in
its own `ca_users` table. BOS does not mint, assert, or revoke identity for this instance.

That is a decision, not an omission. BOS has no shipped lane that embeds an app whose identity does
not live on Supabase: `shared_tenant` mints into a foreign Supabase project, `shared_tenant_native`
requires BOS's own, `isolated_external` is the tier the host deliberately refuses to embed, and
`receipt_backed` is vocabulary with no delivery lane behind it. Building that lane is a platform
project tracked separately; shipping a trusted-header SSO before it exists was reviewed and rejected.

Consequences you should expect and not treat as bugs:

- Providence opens in its own tab. It is not framed inside the BOS canvas.
- Removing someone from a BOS organisation does not remove their Providence access.
- `docker/nginx/providence.conf` clears the `X-Bos-*` identity variables rather than setting them.
  Those lines are the future gateway's foundation, not a half-built feature.

## Licensing boundary

Providence is **GPL-3.0-or-later**. The wrapper in this repository is **Apache-2.0** (`LICENSE`).
That split is deliberate and load-bearing:

- **Hosting is not conveying.** GPL-3.0 obligations attach to conveying a copy. Running the software
  as a network service does not trigger source disclosure — that is the gap AGPL-3.0 §13 closed and
  GPL-3.0 left open.
- **The boundary is derivative-or-not, not "different git repo."** An external process talking HTTP
  to Providence is a separate work. Code loaded *inside* the Providence PHP process — a plugin, an
  auth adapter — is part of the covered work.
- **So integration logic belongs in a gateway, never in `app/plugins/` or `app/lib/Auth/Adapters/`.**
  Nothing in this repository is loaded into the Providence process today, and that should stay true.
- Apache-2.0 is one-way compatible into GPL-3.0, so if a thin shim ever genuinely must live inside
  the Providence tree, it can be carried into the combined work without relicensing gymnastics.
- The moment we hand a customer an image, a clone, or a VM, this changes: that is conveyance, and the
  modified Providence plus anything in-process ships GPL-3.0 with corresponding source.

Upstream copyright headers, `LICENSE`, and in-product notices are carried into the image intact — see
`NOTICE`. Get counsel before any customer-controlled copy.

## Quickstart (local, untested)

```bash
cp .env.example .env      # fill it in; never commit the result
set -a && . ./PROVIDENCE_PIN && set +a
docker compose build
docker compose up -d
```

Providence answers on `127.0.0.1:8080`. It is bound to loopback on purpose: TLS terminates in an
external proxy, which is the only thing that may reach it.

## Layout

| path | what it is |
|---|---|
| `PROVIDENCE_PIN` | the only place an upstream version is named |
| `docker/Dockerfile` | first-party image on `php:8.2-fpm`; fetches upstream at the pinned SHA and verifies it |
| `docker/entrypoint.sh` | renders `setup.php` from env, then installs or migrates once |
| `docker/nginx/providence.conf` | the single ingress to php-fpm; blocks `/install`, makes `media/` internal, clears identity variables |
| `docker/imagemagick-policy.xml` | re-allows the PDF/PS delegates Debian's stock policy denies |
| `compose.yaml` | db, app, web, cron; nothing published beyond loopback |
| `config/local/` | Providence config overlay, mounted read-only |
| `scripts/deploy.sh` | deploy to the instance host |
| `docs/` | first-install and upgrade runbooks |

## Operational notes worth knowing early

- **Search is SqlSearch**, the 2.x default, and is sufficient at pilot scale. ElasticSearch adds a
  JVM container and a second failure domain for no gain here.
- **The stock header adapter stamps `userclass = 1`** — verified at `app/lib/Auth/Adapters/
  HTTPHeaders.php:88`, and `1` is the public class that normally cannot use the Providence
  cataloguing UI at all. The config value that selects it is `HTTPHeader`, singular, even though the
  file is `HTTPHeaders.php` and the class is `HTTPHeaderAuthAdapter`. Its shipped defaults are
  SiteMinder-style (`HTTP_SM_USER`, `HTTP_GIVENNAME`, `HTTP_SN`, `HTTP_MAIL`) and it reads
  `$_SERVER` by that exact key, so the config must name the `$_SERVER` key, not the wire header.
  None of this is live: `CA_AUTH_ADAPTER` stays `CaUsers` until the gateway exists.
- **`group-concat-max-len` is set to 1MB** in `compose.yaml`. At MySQL's 1024-byte default,
  Providence's search indexing truncates silently and you get a quietly incomplete index rather than
  an error.
- **The cron service is not optional.** Media derivatives and search indexing are queued work; without
  it the UI looks healthy while both fall behind.
- **Persistent state** is `mysql-data`, `media`, `app-tmp`, `app-log`. A restore is only consistent if
  the database dump and the media tree are captured as one operation — they drift otherwise.
- **Providence is not multi-tenant.** One install is one cataloguing universe. Separating customers
  with user groups and item ACLs inside one instance is staff permissioning, not tenancy: search,
  browse, reports, batch editors and exports are catalog-global unless every query path is
  ACL-perfect, and admin roles see everything. Do not sell it as isolation.
