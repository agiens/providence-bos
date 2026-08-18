#!/usr/bin/env bash
# purpose: deploy the pinned instance to its host. Secrets come from the host's own
# environment; this script never reads or writes a credential in this repo.
set -euo pipefail

: "${DEPLOY_HOST:?set DEPLOY_HOST (user@host)}"
: "${DEPLOY_PATH:=/opt/providence-bos}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The pin is the contract: refuse to deploy a tree whose pin is not committed.
if ! git -C "$here" diff --quiet -- PROVIDENCE_PIN; then
  echo "deploy: PROVIDENCE_PIN is modified but not committed — refusing" >&2
  exit 1
fi

commit="$(git -C "$here" rev-parse HEAD)"
echo "deploy: ${commit} -> ${DEPLOY_HOST}:${DEPLOY_PATH}"

rsync -a --delete \
  --exclude '.git' --exclude '.env' --exclude 'media' --exclude 'mysql-data' \
  "$here"/ "${DEPLOY_HOST}:${DEPLOY_PATH}/"

# .env already exists on the host and is NOT shipped from here.
ssh "$DEPLOY_HOST" "cd '${DEPLOY_PATH}' && test -f .env || { echo 'deploy: no .env on host' >&2; exit 1; }
  set -a && . ./PROVIDENCE_PIN && set +a
  docker compose build && docker compose up -d && docker compose ps"
