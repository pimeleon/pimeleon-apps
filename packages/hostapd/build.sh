#!/bin/bash
# packages/hostapd/build.sh
# BUILD_TYPE=source: cross-compile hostapd from official sources
set -euo pipefail
source /scripts/common.sh
source /package/package.env

VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/tmp/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/hostapd-${VERSION}/hostapd"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}/usr/local/bin"

TARBALL="hostapd-${VERSION}.tar.gz"
DIST_URL="https://w1.fi/releases/${TARBALL}"

log_info "Downloading hostapd ${VERSION} source"
curl -fsSL -o "${WORK_DIR}/${TARBALL}" "${DIST_URL}"

log_info "Extracting source"
tar xf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
cd "${SRC_DIR}"

log_info "Configuring hostapd..."
cp defconfig .config

# Enable requested options in .config
for opt in ${CONFIG_OPTS}; do
    echo "${opt}" >> .config
echo "CFLAGS += -DOPENSSL_API_COMPAT=0x10100000L" >> .config
done

# Ensure libnl3 is used
sed -i "s|^#CONFIG_LIBNL32=y|CONFIG_LIBNL32=y|" .config

# Determine cross-compilation triple from CC
HOST_TRIPLE=${CC%-gcc}

# Set cross-compilation environment variables for pkg-config
export PKG_CONFIG="${HOST_TRIPLE}-pkg-config"
export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_LIBDIR="/usr/lib/${HOST_TRIPLE}/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_PATH=""
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
log_info "Building hostapd for ${TARGET_ARCH}..."
HOST_TRIPLE=$(gcc -dumpmachine)

# hostapd Makefile uses CC, set it to the cross-compiler
# Use pkg-config to get correct CFLAGS/LIBS for libnl
SSL_CFLAGS=$(${PKG_CONFIG} --cflags openssl)
SSL_LIBS=$(${PKG_CONFIG} --libs openssl)
LIBNL_CFLAGS=$(${PKG_CONFIG} --cflags libnl-3.0 libnl-genl-3.0)
LIBNL_LIBS=$(${PKG_CONFIG} --libs libnl-3.0 libnl-genl-3.0)

make -j"$(nproc)" CC="${CC}" EXTRA_CFLAGS="${LIBNL_CFLAGS} ${SSL_CFLAGS}" LIBS="${LIBNL_LIBS} ${SSL_LIBS}"

log_info "Installing binaries..."
cp hostapd hostapd_cli "${INSTALL_DIR}/usr/local/bin/"

# Strip binaries
STRIP_TOOL="${HOST_TRIPLE}-strip"
for bin in ${OUTPUT_INCLUDES}; do
    if [[ -f "${INSTALL_DIR}/${bin}" ]]; then
        log_info "Stripping ${bin}"
        ${STRIP_TOOL} "${INSTALL_DIR}/${bin}" || true
    fi
done

# Repack
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging binaries..."
tar czf "${OUTPUT_ARCHIVE}" -C "${INSTALL_DIR}" ${OUTPUT_INCLUDES}

# Generate checksum
sha256sum "${OUTPUT_ARCHIVE}" | tee "${OUTPUT_ARCHIVE}.sha256"
log_info "Packed: ${OUTPUT_ARCHIVE}"
