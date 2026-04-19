#!/bin/sh
apk add --no-cache curl git bash jq 2>/dev/null
[ "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -euo pipefail

# shellcheck source=scripts/lib-logging.sh
source scripts/lib-logging.sh

if [ -z "${CI_PIMELEON_APPS_PUSH_TOKEN:-}" ]; then
  log_error "CI_PIMELEON_APPS_PUSH_TOKEN is not set"
  exit 1
fi

git config user.email "ci-version-bot@pirouter.dev"
git config user.name "CI Version Bot"
git remote set-url origin \
  "https://oauth2:${CI_PIMELEON_APPS_PUSH_TOKEN}@gitlab.pirouter.dev/pimeleon/pi-router-apps.git"

CHANGED=0

./scripts/update-tools.sh

for pkg_dir in packages/*/; do
  [ -f "${pkg_dir}/package.env" ] || continue
  # shellcheck disable=SC1090
  . "${pkg_dir}/package.env"

  LATEST=$(bash scripts/check-upstream.sh \
    "${UPSTREAM_REPO}" \
    "${UPSTREAM_TYPE}" \
    "${UPSTREAM_GITLAB_HOST:-gitlab.com}" \
    "${UPSTREAM_TAG_PREFIX:-}" \
    "${UPSTREAM_TAG_PATTERN:-}" 2>/dev/null || true)

  if [ -z "${LATEST}" ]; then
    log_warn "Could not determine upstream version for ${PACKAGE_NAME}, skipping"
    continue
  fi

  if [ "${LATEST}" != "${PACKAGE_VERSION}" ]; then
    echo "Update: ${PACKAGE_NAME}: ${PACKAGE_VERSION} -> ${LATEST}"
    sed -i "s/^PACKAGE_VERSION=\".*\"/PACKAGE_VERSION=\"${LATEST}\"/" "${pkg_dir}/package.env"
    git add "${pkg_dir}/package.env"
    CHANGED=1
  else
    echo "Up to date: ${PACKAGE_NAME} @ ${LATEST}"
  fi
done

./scripts/update-sources.sh

if [ "${CHANGED}" = "1" ]; then
  git commit -m "chore(versions): update upstream package versions in package.env"
  git push origin HEAD:master
  echo "Pushed version updates — downstream pipeline will build affected packages"
else
  echo "All packages up to date, no changes committed"
fi
