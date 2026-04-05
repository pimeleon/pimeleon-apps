#!/bin/bash
# packages/pihole/build.sh
# Downloads the official pre-compiled pihole binary from GitHub releases.
# This matches what the official pi-hole installer does internally.
set -euo pipefail
source /scripts/common.sh
source /package/package.env

VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/build/build-${PACKAGE_NAME}"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}/usr/bin"

# Map TARGET_ARCH to the binary name used in pi-hole GitHub releases
case "${TARGET_ARCH}" in
    armhf) FTL_BIN="pihole-FTL-armv7" ;;
    arm64) FTL_BIN="pihole-FTL-arm64" ;;
    *)     die "Unsupported TARGET_ARCH: ${TARGET_ARCH}" ;;
esac

DOWNLOAD_URL="https://github.com/pi-hole/FTL/releases/download/v${VERSION}/${FTL_BIN}"
log_info "Downloading pihole ${VERSION} for ${TARGET_ARCH}..."
log_info "URL: ${DOWNLOAD_URL}"

curl -fsSL "${DOWNLOAD_URL}" -o "${INSTALL_DIR}/usr/bin/pihole"
chmod +x "${INSTALL_DIR}/usr/bin/pihole"

log_info "Downloaded: $(file "${INSTALL_DIR}/usr/bin/pihole")"

OUTPUT_ARCHIVE="${OUTPUT_DIR:-/output}/${PACKAGE_NAME}-${VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging..."
tar czf "${OUTPUT_ARCHIVE}" -C "${INSTALL_DIR}" usr/bin/pihole

sha256sum "${OUTPUT_ARCHIVE}" | tee "${OUTPUT_ARCHIVE}.sha256"
log_success "Packed: ${OUTPUT_ARCHIVE}"
