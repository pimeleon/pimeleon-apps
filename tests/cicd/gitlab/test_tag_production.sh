#!/bin/bash
# Simulate the tag:production CI job locally using the exact same Docker image.
#
# Usage:
#   ./tests/cicd/gitlab/test_tag_production.sh          # dry run (next-version only)
#   ./tests/cicd/gitlab/test_tag_production.sh --tag    # actually push the tag (LIVE)
#   ./tests/cicd/gitlab/test_tag_production.sh --debug  # token auth probe only
#
# Requires:
#   CI_PIMELEON_APPS_PUSH_TOKEN in .env (or exported in current shell)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
fi

: "${CI_PIMELEON_APPS_PUSH_TOKEN:?CI_PIMELEON_APPS_PUSH_TOKEN must be set in .env or environment}"

APT_PROXY="${APT_PROXY:-192.168.76.5:3142}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.pirouter.dev/api/v4}"
CI_PROJECT_ID="${CI_PROJECT_ID:-20}"
CI_PROJECT_PATH="${CI_PROJECT_PATH:-pimeleon/pi-router-apps}"
CI_COMMIT_SHA="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
CI_COMMIT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
IMAGE="registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1"

MODE="${1:-}"

BOOTSTRAP='
set -eu
echo "Acquire::http::Proxy \"http://'"${APT_PROXY}"'/\";" > /etc/apt/apt.conf.d/01proxy
echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list
echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list
apt-get update -qq 2>&1 | tail -1
DEBIAN_FRONTEND=noninteractive apt-get install -qq -y bash git curl jq > /dev/null 2>&1
'

case "${MODE}" in

  --debug)
    echo "=== Token auth probe (does not push any tag) ==="
    docker run --rm \
      -v "${REPO_ROOT}:/app" \
      -w /app \
      -e GL_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
      -e GITLAB_URL="${GITLAB_URL}" \
      --network host \
      "${IMAGE}" \
      /bin/sh -c "${BOOTSTRAP}
echo ''
echo '--- PRIVATE-TOKEN header ---'
curl -sk -o /tmp/pt.json -w '%{http_code}' \
  -H \"PRIVATE-TOKEN: \${GL_TOKEN}\" \
  \"\${GITLAB_URL}/version\" | xargs -I{} echo 'HTTP {}'
cat /tmp/pt.json 2>/dev/null || echo '(no response body)'; echo ''

echo '--- Bearer (OAuth2) header ---'
curl -sk -o /tmp/bearer.json -w '%{http_code}' \
  -H \"Authorization: Bearer \${GL_TOKEN}\" \
  \"\${GITLAB_URL}/version\" | xargs -I{} echo 'HTTP {}'
cat /tmp/bearer.json 2>/dev/null || echo '(no response body)'; echo ''
"
    ;;

  --sim)
    echo "=== SIMULATE: full ci-release.sh in container (WILL push tag if changes found) ==="
    echo "    Branch: ${CI_COMMIT_BRANCH}  SHA: ${CI_COMMIT_SHA}"

    docker run --rm \
      -v "${REPO_ROOT}:/app" \
      -w /app \
      -e APT_PROXY="${APT_PROXY}" \
      -e GITLAB_URL="${GITLAB_URL}" \
      -e CI_PROJECT_ID="${CI_PROJECT_ID}" \
      -e CI_PROJECT_PATH="${CI_PROJECT_PATH}" \
      -e CI_COMMIT_SHA="${CI_COMMIT_SHA}" \
      -e CI_COMMIT_BRANCH="${CI_COMMIT_BRANCH}" \
      -e CI_PIMELEON_APPS_PUSH_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
      -e GL_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
      -e GIT_SSL_NO_VERIFY="1" \
      -e GSG_MINOR_COMMIT_TYPES="feat,perf" \
      -e GSG_PATCH_COMMIT_TYPES="fix" \
      --network host \
      "${IMAGE}" \
      /bin/sh -c "${BOOTSTRAP}
bash .gitlab/scripts/ci-release.sh
"
    ;;

  --tag)
    echo "=== LIVE: tag:production simulation — will push a real tag if changes found ==="
    echo "    Branch: ${CI_COMMIT_BRANCH}  SHA: ${CI_COMMIT_SHA}"
    read -r -p "    Continue? [y/N] " CONFIRM </dev/tty
    [[ "${CONFIRM}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

    docker run --rm \
      -v "${REPO_ROOT}:/app" \
      -w /app \
      -e APT_PROXY="${APT_PROXY}" \
      -e GITLAB_URL="${GITLAB_URL}" \
      -e CI_PROJECT_ID="${CI_PROJECT_ID}" \
      -e CI_PROJECT_PATH="${CI_PROJECT_PATH}" \
      -e CI_COMMIT_SHA="${CI_COMMIT_SHA}" \
      -e CI_COMMIT_BRANCH="${CI_COMMIT_BRANCH}" \
      -e CI_PIMELEON_APPS_PUSH_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
      -e GL_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
      -e GIT_SSL_NO_VERIFY="1" \
      -e GSG_MINOR_COMMIT_TYPES="feat,perf" \
      -e GSG_PATCH_COMMIT_TYPES="fix" \
      --network host \
      "${IMAGE}" \
      /bin/sh -c "${BOOTSTRAP}
bash .gitlab/scripts/ci-release.sh
"
    ;;

  *)
    echo "=== DRY RUN: next-version only, no tag pushed ==="
    echo "    Branch: ${CI_COMMIT_BRANCH}  SHA: ${CI_COMMIT_SHA}"

    docker run --rm \
      -v "${REPO_ROOT}:/app" \
      -w /app \
      -e APT_PROXY="${APT_PROXY}" \
      -e GITLAB_URL="${GITLAB_URL}" \
      -e CI_PROJECT_ID="${CI_PROJECT_ID}" \
      -e CI_PROJECT_PATH="${CI_PROJECT_PATH}" \
      -e CI_COMMIT_SHA="${CI_COMMIT_SHA}" \
      -e CI_COMMIT_BRANCH="${CI_COMMIT_BRANCH}" \
      -e CI_PIMELEON_APPS_PUSH_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
      -e GL_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
      -e GIT_SSL_NO_VERIFY="1" \
      -e GSG_MINOR_COMMIT_TYPES="feat,perf" \
      -e GSG_PATCH_COMMIT_TYPES="fix" \
      --network host \
      "${IMAGE}" \
      /bin/sh -c "${BOOTSTRAP}
echo 'Probing token...'
HTTP=\$(curl -sk -o /dev/null -w '%{http_code}' \
  -H \"Authorization: Bearer \${GL_TOKEN}\" \
  \"\${GITLAB_URL}/version\")
echo \"  Bearer auth → HTTP \${HTTP}\"
echo ''
echo 'Calculating next version (no tag created)...'
release --skip-ssl-verify next-version --allow-current || true
"
    ;;
esac
bad_func() { echo $(( 1 + 1 )); }
