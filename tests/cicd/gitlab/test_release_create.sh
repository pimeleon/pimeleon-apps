#!/bin/bash
# Simulate the release:create CI job locally in Docker using curl + GitLab API.
#
# Usage:
#   ./tests/cicd/gitlab/test_release_create.sh [TAG]
#
# Requires: CI_PIMELEON_APPS_PUSH_TOKEN in .env (or exported in current shell)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
fi

: "${CI_PIMELEON_APPS_PUSH_TOKEN:?CI_PIMELEON_APPS_PUSH_TOKEN must be set in .env or environment}"

CI_COMMIT_TAG="${1:-$(git -C "${REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.pirouter.dev/api/v4}"
CI_PROJECT_ID="${CI_PROJECT_ID:-20}"
IMAGE="alpine:latest"

echo "=== Simulating release:create CI job ==="
echo "    tag: ${CI_COMMIT_TAG}"

docker run --rm \
  -v "${REPO_ROOT}:/app" \
  -w /app \
  -e CI_COMMIT_TAG="${CI_COMMIT_TAG}" \
  -e CI_PROJECT_ID="${CI_PROJECT_ID}" \
  -e GITLAB_URL="${GITLAB_URL}" \
  -e GL_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
  -e GIT_SSL_NO_VERIFY="1" \
  --network host \
  "${IMAGE}" \
  /bin/sh -c '
apk add --no-cache curl > /dev/null 2>&1

echo "Creating GitLab Release for ${CI_COMMIT_TAG}..."

HTTP=$(curl -sk -o /tmp/release.json -w "%{http_code}" \
  -X POST \
  -H "PRIVATE-TOKEN: ${GL_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"tag_name\": \"${CI_COMMIT_TAG}\",
    \"name\": \"pi-router-apps ${CI_COMMIT_TAG}\",
    \"description\": \"Release **${CI_COMMIT_TAG}**\n\nPackages available in the [Generic Package Registry](https://gitlab.pirouter.dev/pimeleon/pi-router-apps/-/packages).\"
  }" \
  "${GITLAB_URL}/projects/${CI_PROJECT_ID}/releases")

cat /tmp/release.json
echo ""

if [ "$HTTP" = "201" ]; then
  echo "[SUCCESS] Release created."
elif [ "$HTTP" = "409" ]; then
  echo "[SKIP] Release already exists."
else
  echo "[ERROR] HTTP ${HTTP}"
  exit 1
fi
'
