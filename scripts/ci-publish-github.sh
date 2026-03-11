#!/bin/bash
# GitHub Registry Publisher
set -euo pipefail
source "$(dirname "$0")/common.sh"

log_info "Publishing binaries to GitHub Releases..."

for pkg in output/*-pimeleon.tar.gz; do
    [ -f "$pkg" ] || continue
    BASENAME=$(basename "$pkg")
    # Parse name and version
    APP_NAME=$(echo "$BASENAME" | cut -d"-" -f1)
    VERSION=$(echo "$BASENAME" | cut -d"-" -f2)
    ARCH=$(echo "$BASENAME" | grep -oE "arm(hf|64)")
    TAG="${APP_NAME}-${ARCH}-v${VERSION}"

    log_info "Creating GitHub Release ${TAG}..."
    if ! gh release view "${TAG}" > /dev/null 2>&1; then
        gh release create "${TAG}" --target main --title "${APP_NAME} ${ARCH} v${VERSION}" \
            --notes "Automated build of ${APP_NAME} ${VERSION} for ${ARCH}"
    fi
    gh release upload "${TAG}" "${pkg}" --clobber
done
