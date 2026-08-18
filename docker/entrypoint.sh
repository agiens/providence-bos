#!/bin/sh
# purpose: render setup.php from the environment, then install once. Schema migration is a
# deliberate operator step, never a side effect of a container restart — see below.
# Secrets arrive as env at run time and are never baked into a layer.
set -eu

APP=/var/www/providence
SETUP="$APP/setup.php"
# Verified at the pinned commit: base.xml and profile.xsd live in install/profiles/xml, while
# CLIUtils::install() defaults --profile-directory to install/profiles. Pass it explicitly.
PROFILE_DIR="$APP/install/profiles/xml"

require() {
  eval "v=\${$1:-}"
  [ -n "$v" ] || { echo "entrypoint: $1 is required but empty" >&2; exit 1; }
}

require MYSQL_HOST
require MYSQL_DATABASE
require MYSQL_USER
require MYSQL_PASSWORD
require PROVIDENCE_BASE_URL

# setup.php is configuration the program reads, not a modification of the program.
cat > "$SETUP" <<SETUPEOF
<?php
define("__CA_DB_HOST__", "${MYSQL_HOST}");
define("__CA_DB_USER__", "${MYSQL_USER}");
define("__CA_DB_PASSWORD__", "${MYSQL_PASSWORD}");
define("__CA_DB_DATABASE__", "${MYSQL_DATABASE}");
define("__CA_DB_TYPE__", "mysqli");
define("__CA_SITE_HOSTNAME__", "${PROVIDENCE_HOSTNAME:-localhost}");
define("__CA_URL_ROOT__", "");
define("__CA_BASE_DIR__", "${APP}");
define("__CA_APP_NAME__", "providence");
define("__CA_AUTH_ADAPTER__", "${CA_AUTH_ADAPTER:-CaUsers}");
SETUPEOF

echo "entrypoint: waiting for ${MYSQL_HOST}:${MYSQL_PORT:-3306}"
until mysqladmin ping -h"$MYSQL_HOST" -P"${MYSQL_PORT:-3306}" --silent 2>/dev/null; do sleep 2; done

schema_present() {
  mysql -h"$MYSQL_HOST" -P"${MYSQL_PORT:-3306}" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -N -B -e "select count(*) from information_schema.tables \
              where table_schema='${MYSQL_DATABASE}' and table_name='ca_users';" 2>/dev/null
}

if [ "$(schema_present || echo 0)" = "0" ]; then
  echo "entrypoint: no schema — first install with profile '${CA_INSTALL_PROFILE:-base}'"
  # Flags verified against CLIUtils::installParamList() at the pinned commit: --profile-name,
  # --profile-directory, --admin-email, --overwrite, --debug, --skip-roles.
  # --overwrite is a BARE FLAG whose own help says all existing data will be deleted. It is
  # never passed here and must never be: this branch only runs when there is no schema at all.
  # There is NO --admin-password option. Provision the admin password out of band after install.
  php "$APP/support/bin/caUtils" install \
      --profile-name "${CA_INSTALL_PROFILE:-base}" \
      --profile-directory "$PROFILE_DIR" \
      --admin-email "${CA_ADMIN_EMAIL:?CA_ADMIN_EMAIL required on first install}"
else
  # Schema migration is NOT run on boot. `caUtils update-database-schema` accepts no CLI options
  # (update_database_schemaParamList() returns an empty array) and calls CLIUtils::confirm();
  # its only bypass is a PHP-level `dontConfirm` argument the CLI cannot supply. Unattended it
  # blocks on STDIN forever, so an ordinary restart would hang instead of serving. Upgrades are
  # an operator step taken after a backup — see docs/upgrade.md.
  if [ "${CA_AUTO_MIGRATE:-0}" = "1" ]; then
    echo "entrypoint: CA_AUTO_MIGRATE=1 — answering the migration confirmation automatically"
    yes y | php "$APP/support/bin/caUtils" update-database-schema || {
      echo "entrypoint: schema update FAILED — refusing to serve a half-migrated instance" >&2
      exit 1
    }
  else
    echo "entrypoint: schema present — not migrating (set CA_AUTO_MIGRATE=1 to opt in)"
  fi
fi

exec "$@"
