#!/bin/bash
# GitLab Registry Publisher
set -euo pipefail
source "$(dirname "$0")/common.sh"

log_info "Publishing binaries to GitLab Registry..."

for pkg in output/*-pimeleon.tar.gz; do
    [ -f "$pkg" ] || continue
    BASENAME=$(basename "$pkg")
    # Parse name and version
    APP_NAME=$(echo "$BASENAME" | cut -d"-" -f1)
    VERSION=$(echo "$BASENAME" | cut -d"-" -f2)
    
    log_info "Uploading ${APP_NAME} v${VERSION} to project ${CI_PROJECT_ID}..."
    curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
         --upload-file "${pkg}" \
         "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${APP_NAME}/${VERSION}/${BASENAME}"
done
