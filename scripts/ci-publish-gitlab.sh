#!/bin/bash
# GitLab Registry Publisher
# Optimized for compatibility with pi-router-build fetch logic
set -euo pipefail
source "$(dirname "$0")/common.sh"

log_info "Publishing binaries to GitLab Registry..."

# Expected structure by pi-router-build:
# ${reg}/${package}/${arch}-${version}/${package}-${version}-${arch}-pimeleon.tar.gz

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
    GL_VERSION="${ARCH}-${VERSION}"

    log_info "Uploading ${APP_NAME} v${VERSION} (${ARCH}) to project 20..."
    curl -fsSLk --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
         --upload-file "${pkg}" \
         "${CI_API_V4_URL}/projects/20/packages/generic/${APP_NAME}/${GL_VERSION}/${BASENAME}"

    # Also upload the checksum if it exists
    if [ -f "${pkg}.sha256" ]; then
        curl -fsSLk --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
             --upload-file "${pkg}.sha256" \
             "${CI_API_V4_URL}/projects/20/packages/generic/${APP_NAME}/${GL_VERSION}/${BASENAME}.sha256"
    fi
done
