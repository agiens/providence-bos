# First install — the verified contract

Everything below was read from the upstream tree at the pinned commit
(`aedf6fc0e18c55f2184c6d5f5a879eeca13019ce`, tag 2.0.11), not inferred.

## How caUtils dispatches

`support/bin/caUtils` line 62: `$cmd_proc = strtolower(str_replace("-", "_", $cmd))`.

So hyphenated and underscored spellings are equivalent — `update-database-schema` and
`update_database_schema` both reach `CLIUtils::update_database_schema`. Commands are public static
methods on `CLIUtils`, assembled from 17 traits under `app/lib/Utils/CLIUtils/`.

## `install` — verified flags

From `CLIUtils::installParamList()` (`app/lib/Utils/CLIUtils/Configuration.php:177`):

| flag | short | notes |
|---|---|---|
| `--profile-name` | `-n` | REQUIRED. Filename in the profile directory, minus `.xml`. |
| `--profile-directory` | `-p` | Code default is `install/profiles`, but `base.xml` and `profile.xsd` are in `install/profiles/xml`. **Pass it explicitly.** |
| `--admin-email` | `-e` | REQUIRED when installing. |
| `--overwrite` | — | **BARE FLAG. Its own help: "all existing data will be deleted (use with caution!)".** Also gated on the `__CA_ALLOW_INSTALLER_TO_OVERWRITE_EXISTING_INSTALLS__` global. Never pass it from the entrypoint. |
| `--debug` | `-d` | |
| `--skip-roles` | `-s` | Faster install when access control has many roles. |

**There is no `--admin-password`.** Anything that claimed to set one was wrong. Provision the admin
password out of band after the first install.

Install fails if the schema already exists, unless `--overwrite` is set. The entrypoint therefore
only calls it when `ca_users` is absent.

Profiles shipped at 2.0.11 (`install/profiles/xml/`): `base`, `default`, `cdwalite`, `dacs`,
`darwincore`, `dublincore_qualif_2018`, `ebucore`, `isad_g`, `maxwell`, `pbcore`, `pp5_complete`,
`testing`, `ummaa-lsa`, `vracore`.

## `update-database-schema` — why it is NOT a boot step

`CLIUtils::update_database_schema` (`app/lib/Utils/CLIUtils/Migration.php:156`) does two things that
make it unusable from an unattended entrypoint:

1. `update_database_schemaParamList()` returns an **empty array** — the command accepts no CLI
   options whatsoever.
2. It calls `CLIUtils::confirm(...)` unless a `dontConfirm` option is set, and that option is the
   second **PHP argument**, which the CLI has no way to supply.

So running it on container start blocks on STDIN forever: the container hangs instead of serving.

The entrypoint therefore does not migrate by default. Set `CA_AUTO_MIGRATE=1` to opt in, which
answers the prompt with `yes y |` and exits non-zero rather than serving a half-migrated instance.
Prefer the deliberate operator path in `docs/upgrade.md`.

The migration bodies themselves are the 224 files in `support/sql/migrations/`, applied by
`\System\Updater::performDatabaseSchemaUpdate()` (`app/lib/System/Updater.php:46`).

## Still unverified

No image has been built and no instance booted from this tree. The flags above are read from
source; the install has not been executed end to end. Until it has, treat first install as a
supervised operation.
