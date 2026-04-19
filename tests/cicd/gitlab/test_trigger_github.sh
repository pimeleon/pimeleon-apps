#!/bin/bash
# Simulate the trigger:github CI job locally using the exact same Docker image.
#
# Usage:
#   ./tests/cicd/gitlab/test_trigger_github.sh
#
# Requires: GITHUB_REGISTRY_PUSH_TOKEN in .env (or exported in current shell)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
fi

: "${GITHUB_REGISTRY_PUSH_TOKEN:?GITHUB_REGISTRY_PUSH_TOKEN must be set in .env or environment}"

CI_COMMIT_REF_NAME="${CI_COMMIT_REF_NAME:-$(git -C "${REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "master")}"
IMAGE="alpine:latest"

echo "=== Simulating trigger:github CI job ==="
echo "    ref: ${CI_COMMIT_REF_NAME}"

docker run --rm \
  -v "${REPO_ROOT}:/app" \
  -w /app \
  -e CI_COMMIT_REF_NAME="${CI_COMMIT_REF_NAME}" \
  -e GITHUB_REGISTRY_PUSH_TOKEN="${GITHUB_REGISTRY_PUSH_TOKEN}" \
  --network host \
  "${IMAGE}" \
  /bin/sh -c "
apk add --no-cache curl bash > /dev/null 2>&1
chmod +x .gitlab/scripts/ci-trigger-github.sh
.gitlab/scripts/ci-trigger-github.sh
"
