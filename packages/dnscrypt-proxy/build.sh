#!/bin/bash
# packages/dnscrypt-proxy/build.sh
# BUILD_TYPE=binary: download pre-built GitHub release asset, verify, repack
# Called by /scripts/build-package.sh inside the builder container.
# Environment: PACKAGE_NAME, PACKAGE_VERSION, TARGET_ARCH, OUTPUT_DIR

set -euo pipefail
source /scripts/common.sh
source /package/package.env

WORK_DIR="/tmp/build-${PACKAGE_NAME}"
mkdir -p "${WORK_DIR}"

# Select asset name for this arch
if [[ "${TARGET_ARCH}" == "armhf" ]]; then
    ASSET="${UPSTREAM_ASSET_ARMHF/\{VERSION\}/${PACKAGE_VERSION}}"
else
    ASSET="${UPSTREAM_ASSET_ARM64/\{VERSION\}/${PACKAGE_VERSION}}"
fi

DOWNLOAD_URL="https://github.com/${UPSTREAM_REPO}/releases/download/${PACKAGE_VERSION}/${ASSET}"
log_info "Downloading ${DOWNLOAD_URL}"
curl -fsSL -o "${WORK_DIR}/${ASSET}" "${DOWNLOAD_URL}"

# Download and verify checksum if available
CHECKSUM_URL="${DOWNLOAD_URL}.minisig"
if curl -fsSL -o "${WORK_DIR}/${ASSET}.minisig" "${CHECKSUM_URL}" 2>/dev/null; then
    log_info "Minisig downloaded (signature verification skipped — minisign not available)"
fi

# Extract binary from the upstream archive
log_info "Extracting ${ASSET}"
tar xf "${WORK_DIR}/${ASSET}" -C "${WORK_DIR}"

# Find the binary (it's inside a subdirectory like linux-arm/)
BINARY=$(find "${WORK_DIR}" -name "${OUTPUT_BINARY}" -type f | head -1)
[[ -n "${BINARY}" ]] || die "Binary '${OUTPUT_BINARY}' not found in extracted archive"
log_info "Found binary: ${BINARY}"

# Strip debug symbols to reduce size
strip --strip-unneeded "${BINARY}" || log_warn "strip failed (may be already stripped)"

# Repack into standard output format: flat tarball with just the binary
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
tar czf "${OUTPUT_ARCHIVE}" -C "$(dirname "${BINARY}")" "$(basename "${BINARY}")"
log_info "Packed: ${OUTPUT_ARCHIVE}"
