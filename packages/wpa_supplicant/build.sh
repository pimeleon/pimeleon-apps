#!/bin/bash
# packages/wpa_supplicant/build.sh
# BUILD_TYPE=source: cross-compile wpa_supplicant from official sources
set -euo pipefail
source /scripts/common.sh
source /package/package.env

VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/build/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/wpa_supplicant-${VERSION}/wpa_supplicant"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}/usr/local/sbin" "${INSTALL_DIR}/usr/local/bin"

TARBALL="wpa_supplicant-${VERSION}.tar.gz"
DIST_URL="https://w1.fi/releases/${TARBALL}"

fetch_source "${PACKAGE_NAME}" "${VERSION}" "${TARBALL}" "${DIST_URL}" "${WORK_DIR}/${TARBALL}"

log_info "Extracting source"
tar xf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
cd "${SRC_DIR}"

log_info "Configuring wpa_supplicant..."
cp defconfig .config

# Enable requested options in .config
for opt in ${CONFIG_OPTS}; do
    echo "${opt}" >> .config
done
echo "CFLAGS += -DOPENSSL_API_COMPAT=0x10100000L" >> .config

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
log_info "Building wpa_supplicant for ${TARGET_ARCH} using triple ${HOST_TRIPLE}..."

# wpa_supplicant Makefile uses CC, set it to the cross-compiler
# Use pkg-config to get correct CFLAGS/LIBS for libnl, openssl, and dbus
SSL_CFLAGS=$(${PKG_CONFIG} --cflags openssl)
SSL_LIBS=$(${PKG_CONFIG} --libs openssl)
LIBNL_CFLAGS=$(${PKG_CONFIG} --cflags libnl-3.0 libnl-genl-3.0 libnl-route-3.0)
LIBNL_LIBS=$(${PKG_CONFIG} --libs libnl-3.0 libnl-genl-3.0 libnl-route-3.0)
DBUS_CFLAGS=$(${PKG_CONFIG} --cflags dbus-1)
DBUS_LIBS=$(${PKG_CONFIG} --libs dbus-1)

make -j"$(nproc)" CC="${CC}" EXTRA_CFLAGS="${LIBNL_CFLAGS} ${SSL_CFLAGS} ${DBUS_CFLAGS} -O1" LIBS="${LIBNL_LIBS} ${SSL_LIBS} ${DBUS_LIBS}"

log_info "Installing binaries..."
cp wpa_supplicant "${INSTALL_DIR}/usr/local/sbin/"
cp wpa_cli wpa_passphrase "${INSTALL_DIR}/usr/local/bin/"

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
