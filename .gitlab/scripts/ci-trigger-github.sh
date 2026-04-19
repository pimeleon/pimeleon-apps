#!/bin/sh
set -eu

# Triggers the "build" GitHub Actions workflow via workflow_dispatch.
#
# Inputs (CI environment):
#   CI_COMMIT_REF_NAME
#   GITHUB_REGISTRY_PUSH_TOKEN (PAT with repo scope)

# shellcheck source=scripts/lib-logging.sh
source scripts/lib-logging.sh

GITHUB_REPO="pimeleon/pimeleon-apps"
WORKFLOW_FILE="build.yml"

if [ -z "${GITHUB_REGISTRY_PUSH_TOKEN:-}" ]; then
    log_error "GITHUB_REGISTRY_PUSH_TOKEN is not set — cannot trigger GitHub Actions"
    exit 1
fi

log_info "Triggering '${WORKFLOW_FILE}' on ${GITHUB_REPO} (ref: ${CI_COMMIT_REF_NAME})"

HTTP_CODE=$(curl -s -o /tmp/gh-dispatch-response.txt -w "%{http_code}" \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_REGISTRY_PUSH_TOKEN}" \
    "https://api.github.com/repos/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches" \
    -d "{\"ref\": \"${CI_COMMIT_REF_NAME}\"}")

if [ "$HTTP_CODE" = "204" ]; then
    log_success "GitHub Actions workflow triggered successfully."
else
    log_error "GitHub API returned HTTP ${HTTP_CODE}"
    cat /tmp/gh-dispatch-response.txt
    exit 1
fi
