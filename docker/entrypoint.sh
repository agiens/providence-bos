#!/bin/sh
# purpose: render setup.php from the environment, then install-or-migrate exactly once.
# Secrets arrive as env at run time and are never baked into a layer.
set -eu

APP=/var/www/providence
SETUP="$APP/setup.php"

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
  # NOTE: not yet exercised end to end. The installer's exact non-interactive invocation
  # and profile path are UNVERIFIED against 2.0.11; see docs/first-install.md before
  # pointing this at anything that matters.
  php "$APP/support/bin/caUtils" install \
      --profile-name "${CA_INSTALL_PROFILE:-base}" \
      --admin-email "${CA_ADMIN_EMAIL:?CA_ADMIN_EMAIL required on first install}" \
      --overwrite 0
else
  echo "entrypoint: schema present — applying pending schema migrations"
  php "$APP/support/bin/caUtils" update-database-schema || {
    echo "entrypoint: schema update FAILED — refusing to serve a half-migrated instance" >&2
    exit 1
  }
fi

exec "$@"
