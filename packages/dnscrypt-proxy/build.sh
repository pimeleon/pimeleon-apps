#!/bin/bash
# packages/dnscrypt-proxy/build.sh
# BUILD_TYPE=binary: download pre-built GitHub release asset, verify, repack
set -euo pipefail
source /scripts/common.sh
source /package/package.env

# Use version from env if not passed
VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/tmp/build-${PACKAGE_NAME}"
mkdir -p "${WORK_DIR}"

# Select asset name for this arch
if [[ "${TARGET_ARCH}" == "armhf" ]]; then
    ASSET="${UPSTREAM_ASSET_ARMHF/\{VERSION\}/${VERSION}}"
else
    ASSET="${UPSTREAM_ASSET_ARM64/\{VERSION\}/${VERSION}}"
fi

DOWNLOAD_URL="https://github.com/${UPSTREAM_REPO}/releases/download/${VERSION}/${ASSET}"
log_info "Downloading ${DOWNLOAD_URL}"
curl -fsSL -o "${WORK_DIR}/${ASSET}" "${DOWNLOAD_URL}"

# Extract binary from the upstream archive
log_info "Extracting ${ASSET}"
tar xf "${WORK_DIR}/${ASSET}" -C "${WORK_DIR}"

# Find the binary (it's inside a subdirectory like linux-arm/)
BINARY=$(find "${WORK_DIR}" -name "${OUTPUT_BINARY}" -type f | head -1)
[[ -n "${BINARY}" ]] || die "Binary '${OUTPUT_BINARY}' not found in extracted archive"
log_info "Found binary: ${BINARY}"

# Use arch-specific strip tool
HOST_TRIPLE=${CC%-gcc}
STRIP_TOOL="${HOST_TRIPLE}-strip"

# Strip debug symbols to reduce size (using host native strip)
${STRIP_TOOL} --strip-unneeded "${BINARY}" || log_warn "strip failed (may be already stripped)"

# Repack into standard output format: flat tarball with just the binary
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging binary..."
tar czf "${OUTPUT_ARCHIVE}" -C "$(dirname "${BINARY}")" "$(basename "${BINARY}")"

# Generate checksum
sha256sum "${OUTPUT_ARCHIVE}" | tee "${OUTPUT_ARCHIVE}.sha256"
log_success "Packed: ${OUTPUT_ARCHIVE}"
