# First install — what must be settled before running it

The entrypoint installs only when `ca_users` is absent, and migrates otherwise. Both paths call
`support/bin/caUtils`, and **neither invocation has been verified against the pinned 2.0.11 tree.**

Settle these at `PROVIDENCE_COMMIT` before pointing this at anything that matters:

1. `php support/bin/caUtils --help` — confirm `install` and `update-database-schema` exist under those
   names, and read the real flag spellings. The flags in `docker/entrypoint.sh` are plausible, not
   confirmed.
2. `install/profiles/xml/` — confirm which profiles ship and what `CA_INSTALL_PROFILE=base` resolves
   to. A profile shapes schema, UIs and lists at first install only; it is not a tenant boundary and
   cannot be re-applied as one.
3. Confirm the installer can run non-interactively at all, and what it does when the database is
   reachable but empty versus partially populated.
4. Confirm whether an admin password can be supplied without landing in the process table or a layer.
   If not, provision the admin account as a separate step after install.

Until 1–4 are answered in writing here, treat first install as a manual operation with the entrypoint
as a draft of it.
