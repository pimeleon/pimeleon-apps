#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/lib-logging.sh
source scripts/lib-logging.sh

if [ -z "${GL_TOKEN:-}" ]; then
  log_error "GL_TOKEN is not set — cannot authenticate with GitLab API"
  exit 1
fi

echo "GITLAB_URL: ${GITLAB_URL:-not set}"
echo "GL_TOKEN:   ${GL_TOKEN:0:6}..."
echo ""
echo "Calculating next production version..."
NEXT_VERSION=$(release --skip-ssl-verify next-version --allow-current)
echo "Next version - ${NEXT_VERSION}"

trigger_tag_pipeline() {
  local tag="$1"
  log_info "Triggering pipeline for tag ${tag}..."
  HTTP=$(curl -sk -o /tmp/trigger.json -w "%{http_code}" \
    -X POST \
    -H "PRIVATE-TOKEN: ${GL_TOKEN}" \
    "${GITLAB_URL}/projects/${CI_PROJECT_ID}/pipeline?ref=${tag}")
  if [ "$HTTP" = "201" ]; then
    log_success "Tag pipeline triggered successfully."
  else
    log_warn "Failed to trigger tag pipeline (HTTP ${HTTP}):"
    cat /tmp/trigger.json
  fi
}

if [ -n "$NEXT_VERSION" ]; then
  TAG="v${NEXT_VERSION}"
  echo "Creating production tag ${TAG}..."
  release --skip-ssl-verify tag > /tmp/release.log 2>&1 && RC=0 || RC=$?
  cat /tmp/release.log
  if [ $RC -ne 0 ]; then
    if grep -q "no changes found" /tmp/release.log; then
      echo "No releasable changes - skipping tag"
    elif grep -q "Release already exists" /tmp/release.log; then
      echo "Release already exists - skipping"
      trigger_tag_pipeline "${TAG}"
    else
      exit 1
    fi
  else
    trigger_tag_pipeline "${TAG}"
  fi
else
  echo "No version bump needed"
fi
