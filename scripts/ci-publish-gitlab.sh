#!/bin/bash
# GitLab Registry Publisher
# Optimized for compatibility with pi-router-build fetch logic
set -euo pipefail
source "$(dirname "$0")/common.sh"

log_info "Publishing binaries to GitLab Registry..."

# Expected structure by pi-router-build:
# ${reg}/${package}/${arch}-${version}/${package}-${version}-${arch}-pimeleon.tar.gz

PUBLISH_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

for pkg in output/*-pimeleon.tar.gz; do
    [ -f "$pkg" ] || continue
    BASENAME=$(basename "$pkg")

    # Robust parsing of filename: {package}-{version}-{arch}-pimeleon.tar.gz
    # Example: dnscrypt-proxy-2.1.15-armhf-pimeleon.tar.gz

    # 1. Remove suffix
    TEMP="${BASENAME%-pimeleon.tar.gz}" # dnscrypt-proxy-2.1.15-armhf

    # 2. Extract Arch (last part)
    ARCH="${TEMP##*-}" # armhf

    # 3. Remove Arch to get package and version
    TEMP2="${TEMP%-*}" # dnscrypt-proxy-2.1.15

    # 4. Extract Version (new last part)
    VERSION="${TEMP2##*-}" # 2.1.15

    # 5. Remaining is the App Name
    APP_NAME="${TEMP2%-*}" # dnscrypt-proxy

    # GitLab Package Version must be {arch}-{version} for pi-router-build compatibility
    PACKAGE_VERSION="${ARCH}-${VERSION}"
    UPLOAD_URL="${CI_API_V4_URL}/projects/20/packages/generic/${APP_NAME}/${PACKAGE_VERSION}/${BASENAME}"

    log_info "Uploading ${APP_NAME} v${VERSION} (${ARCH})..."
    HTTP_STATUS=$(curl -o /dev/null -w "%{http_code}" -fsSLk \
        --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
        --upload-file "${pkg}" \
        "${UPLOAD_URL}" 2>&1) && CURL_EXIT=0 || CURL_EXIT=$?

    if [[ $CURL_EXIT -eq 0 ]]; then
        log_success "  -> ${BASENAME} [HTTP ${HTTP_STATUS}]"
        PUBLISH_COUNT=$((PUBLISH_COUNT + 1))
    else
        log_error "  -> Failed to upload ${BASENAME} (curl exit: ${CURL_EXIT}, HTTP: ${HTTP_STATUS})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    # Also upload the checksum if it exists
    if [ -f "${pkg}.sha256" ]; then
        CHECKSUM_STATUS=$(curl -o /dev/null -w "%{http_code}" -fsSLk \
            --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
            --upload-file "${pkg}.sha256" \
            "${UPLOAD_URL}.sha256" 2>&1) && CHECKSUM_EXIT=0 || CHECKSUM_EXIT=$?

        if [[ $CHECKSUM_EXIT -eq 0 ]]; then
            log_info "  -> ${BASENAME}.sha256 [HTTP ${CHECKSUM_STATUS}]"
        else
            log_warn "  -> Failed to upload checksum for ${BASENAME} (curl exit: ${CHECKSUM_EXIT})"
        fi
    fi
done

if [[ $PUBLISH_COUNT -eq 0 && $FAIL_COUNT -eq 0 ]]; then
    log_warn "No artifacts found in output/. Contents:"
    ls -lh output/ 2>/dev/null || log_warn "  output/ directory does not exist"
fi

log_info "Publish summary: ${PUBLISH_COUNT} uploaded, ${FAIL_COUNT} failed"
if [[ $FAIL_COUNT -gt 0 ]]; then
    die "One or more uploads failed"
fi
