#!/bin/bash
# packages/tor/build.sh
# BUILD_TYPE=source: cross-compile Tor from the official dist tarball
# Called by /scripts/build-package.sh inside the builder container.
# Environment: PACKAGE_NAME, PACKAGE_VERSION, TARGET_ARCH, OUTPUT_DIR,
#              CROSS_TRIPLE, CC, PKG_CONFIG_PATH, LDFLAGS, HOST_TRIPLE

set -euo pipefail
source /scripts/common.sh
source /package/package.env

WORK_DIR="/tmp/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/tor-${PACKAGE_VERSION}"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}"

TARBALL="tor-${PACKAGE_VERSION}.tar.gz"
DIST_URL="https://dist.torproject.org/${TARBALL}"

log_info "Downloading Tor ${PACKAGE_VERSION} source"
curl -fsSL -o "${WORK_DIR}/${TARBALL}" "${DIST_URL}"

# Verify checksum
if curl -fsSL -o "${WORK_DIR}/${TARBALL}.sha256sum" "${DIST_URL}.sha256sum" 2>/dev/null; then
    (cd "${WORK_DIR}" && sha256sum --check "${TARBALL}.sha256sum") \
        || die "Checksum verification failed for ${TARBALL}"
    log_info "Checksum verified"
fi

log_info "Extracting source"
tar xf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
[[ -d "${SRC_DIR}" ]] || die "Expected source directory ${SRC_DIR} not found after extraction"

cd "${SRC_DIR}"

log_info "Configuring for ${TARGET_ARCH} (host: ${HOST_TRIPLE})"
# shellcheck disable=SC2086
./configure \
    --host="${HOST_TRIPLE}" \
    ${CONFIGURE_FLAGS}

log_info "Building"
make -j"$(nproc)"

log_info "Installing to DESTDIR"
make DESTDIR="${INSTALL_DIR}" install

# Strip binaries
for bin in ${OUTPUT_INCLUDES}; do
    "${STRIP}" "${INSTALL_DIR}/${bin}" 2>/dev/null || true
done

# Repack only the declared output files
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging: ${OUTPUT_INCLUDES}"
# Build tar args from OUTPUT_INCLUDES (relative paths inside INSTALL_DIR)
# shellcheck disable=SC2086
tar czf "${OUTPUT_ARCHIVE}" -C "${INSTALL_DIR}" ${OUTPUT_INCLUDES}
log_info "Packed: ${OUTPUT_ARCHIVE}"
