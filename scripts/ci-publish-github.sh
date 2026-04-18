#!/bin/bash
# GitHub Release Uploader
# Purpose: Upload all built binaries to a single GitHub Release for this version.
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ -z "${RELEASE_TAG:-}" ]]; then
    die "RELEASE_TAG environment variable is required (e.g., v1.2.3)"
fi

log_info "Uploading binaries to GitHub Release ${RELEASE_TAG}..."

if ! gh release view "${RELEASE_TAG}" > /dev/null 2>&1; then
    log_info "Release ${RELEASE_TAG} not found. Creating it..."
    gh release create "${RELEASE_TAG}" --generate-notes --title "pimeleon-apps ${RELEASE_TAG}"
fi

for pkg in output/*-pimeleon.tar.gz; do
    [ -f "$pkg" ] || continue
    log_info "Uploading $(basename "$pkg")..."
    gh release upload "${RELEASE_TAG}" "${pkg}" --clobber
    if [ -f "${pkg}.sha256" ]; then
        gh release upload "${RELEASE_TAG}" "${pkg}.sha256" --clobber
    fi
done
