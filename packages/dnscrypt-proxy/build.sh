#!/bin/bash
# packages/dnscrypt-proxy/build.sh
# BUILD_TYPE=source: compile from source using Go toolchain
set -euo pipefail
source /scripts/common.sh
source /package/package.env

# Use version from env if not passed
VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/build/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/dnscrypt-proxy-${VERSION}"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}"

TARBALL="${PACKAGE_NAME}-${VERSION}.tar.gz"
DIST_URL="https://github.com/DNSCrypt/dnscrypt-proxy/archive/refs/tags/${VERSION}.tar.gz"

fetch_source "${PACKAGE_NAME}" "${VERSION}" "${TARBALL}" "${DIST_URL}" "${WORK_DIR}/${TARBALL}"

log_info "Extracting source"
tar xf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
cd "${SRC_DIR}/dnscrypt-proxy"

log_info "Building ${PACKAGE_NAME} v${VERSION} for ${TARGET_ARCH} from source..."

# Build Configuration:
# - CGO_ENABLED=0: Static binary (no libc dependency)
# - -trimpath: Remove local file paths from binary
# - -ldflags="-s -w": Strip symbols and debug info
# - -tags "netgo osusergo": Use Go-native DNS and user lookups
export CGO_ENABLED=0

go build -v \
    -trimpath \
    -ldflags="-s -w" \
    -tags "netgo osusergo" \
    -o "${WORK_DIR}/${OUTPUT_BINARY}"

# Verify the binary properties
log_info "Verifying built binary..."
file "${WORK_DIR}/${OUTPUT_BINARY}"
ldd "${WORK_DIR}/${OUTPUT_BINARY}" || log_info "Binary is statically linked (verified)."

# Repack into standard output format
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging binary..."
tar czf "${OUTPUT_ARCHIVE}" -C "${WORK_DIR}" "${OUTPUT_BINARY}"

# Generate checksum
sha256sum "${OUTPUT_ARCHIVE}" | tee "${OUTPUT_ARCHIVE}.sha256"
log_success "Build complete: ${OUTPUT_ARCHIVE}"
