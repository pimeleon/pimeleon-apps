#!/bin/bash
# packages/pihole-FTL/build.sh
# BUILD_TYPE=source: cross-compile pihole-FTL (The core DNS engine)
set -euo pipefail
source /scripts/common.sh
source /package/package.env

VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/tmp/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/FTL-${VERSION#v}"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}/usr/bin"

TARBALL="${VERSION}.tar.gz"
DIST_URL="https://github.com/pi-hole/FTL/archive/refs/tags/${TARBALL}"

log_info "Downloading pihole-FTL ${VERSION} source"
curl -fsSL -o "${WORK_DIR}/${TARBALL}" "${DIST_URL}"

log_info "Extracting source"
tar xf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
cd "${SRC_DIR}"

log_info "Configuring pihole-FTL for ${TARGET_ARCH}..."
HOST_TRIPLE=$(gcc -dumpmachine)

# Determine CMAKE processor name
if [[ "${TARGET_ARCH}" == "armhf" ]]; then
    CMAKE_ARCH="arm"
else
    CMAKE_ARCH="aarch64"
fi

# Set cross-compilation environment for pkg-config (some CMake scripts use it)
export PKG_CONFIG="${HOST_TRIPLE}-pkg-config"
export PKG_CONFIG_LIBDIR="/usr/lib/${HOST_TRIPLE}/pkgconfig"

# FTL uses CMake. Pass recommended flags for static cross-compilation
cmake -B build \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CC%-gcc}-g++" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR="${CMAKE_ARCH}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSTATIC=ON \

log_info "Building pihole-FTL..."
cmake --build build --verbose -- -j"$(nproc)"

log_info "Installing binaries..."
cp build/pihole-FTL "${INSTALL_DIR}/usr/bin/"

# Strip binaries
STRIP_TOOL="${HOST_TRIPLE}-strip"
log_info "Stripping pihole-FTL"
${STRIP_TOOL} "${INSTALL_DIR}/usr/bin/pihole-FTL" || true

# Repack
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging binaries..."
tar czf "${OUTPUT_ARCHIVE}" -C "${INSTALL_DIR}" usr/bin/pihole-FTL

# Generate checksum
sha256sum "${OUTPUT_ARCHIVE}" | tee "${OUTPUT_ARCHIVE}.sha256"
log_success "Packed: ${OUTPUT_ARCHIVE}"
