#!/bin/bash
# GitHub Release Uploader
# Purpose: Create GitHub releases (if missing) and upload built binaries to them.
set -euo pipefail
source "$(dirname "$0")/common.sh"

log_info "Uploading binaries to GitHub Releases..."

for pkg in output/*-pimeleon.tar.gz; do
    [ -f "$pkg" ] || continue
    BASENAME=$(basename "$pkg")

    # Parse name, version, and arch
    # Format: {package}-{version}-{arch}-pimeleon.tar.gz
    TEMP="${BASENAME%-pimeleon.tar.gz}"
    ARCH="${TEMP##*-}"
    TEMP2="${TEMP%-*}"
    VERSION="${TEMP2##*-}"
    APP_NAME="${TEMP2%-*}"

    TAG="${APP_NAME}-${ARCH}-v${VERSION}"

    log_info "Verifying release ${TAG} exists on GitHub..."
    if ! gh release view "${TAG}" > /dev/null 2>&1; then
        log_info "Release ${TAG} not found. Creating it..."
        gh release create "${TAG}" --generate-notes --title "${TAG}"
    fi

    log_info "Uploading ${BASENAME} to GitHub Release ${TAG}..."
    gh release upload "${TAG}" "${pkg}" --clobber

    if [ -f "${pkg}.sha256" ]; then
        gh release upload "${TAG}" "${pkg}.sha256" --clobber
    fi
done
