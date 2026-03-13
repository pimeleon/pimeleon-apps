#!/bin/bash
# packages/tor/build.sh
# BUILD_TYPE=source: cross-compile Tor from the official dist tarball
set -euo pipefail
source /scripts/common.sh
source /package/package.env

# Use version from env if not passed
VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/build/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/tor-${VERSION}"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}"

TARBALL="tor-${VERSION}.tar.gz"
DIST_URL="https://dist.torproject.org/${TARBALL}"

fetch_source "${PACKAGE_NAME}" "${VERSION}" "${TARBALL}" "${DIST_URL}" "${WORK_DIR}/${TARBALL}"

log_info "Extracting source"
tar xf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
cd "${SRC_DIR}"

log_info "Patching configure to force cross-compilation mode..."
# Force cross_compiling=yes to skip execution checks for libevent, openssl, and zlib
sed -i 's/cross_compiling=maybe/cross_compiling=yes/g' configure

log_info "Configuring for ${TARGET_ARCH}"

# Determine cross-compilation triple from CC
# CC is arm-linux-gnueabihf-gcc or aarch64-linux-gnu-gcc
HOST_TRIPLE=${CC%-gcc}

# Workaround for Tor's non-multiarch-aware static library lookup.
# It expects static libraries in $DIR/lib but Debian multiarch puts them in $DIR/lib/$HOST_TRIPLE.
DEPS_DIR="${WORK_DIR}/tor-deps"
log_info "Creating multiarch-aware dependency directory at ${DEPS_DIR}..."
mkdir -p "${DEPS_DIR}/lib"
ln -snf /usr/include "${DEPS_DIR}/include"
# Link all static libraries from multiarch path to the flat lib dir Tor expects
for lib in /usr/lib/${HOST_TRIPLE}/*.a; do
    [ -e "$lib" ] || continue
    ln -sf "$lib" "${DEPS_DIR}/lib/"
done

# Set cross-compilation environment variables for pkg-config
export PKG_CONFIG="${HOST_TRIPLE}-pkg-config"
export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_LIBDIR="/usr/lib/${HOST_TRIPLE}/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_PATH=""

# Clean environment from host contamination
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

log_info "Using HOST_TRIPLE: ${HOST_TRIPLE}"
log_info "Using PKG_CONFIG: $(command -v "${PKG_CONFIG}")"

# Pre-seed configure cache to bypass 'runnable' checks for cross-compiled static libs.
# Tor's configure tries to run a test program to verify the library, which fails on x86_64 host.
export tor_cv_library_libevent_linker_option=""
export tor_cv_library_openssl_linker_option=""
export tor_cv_library_zlib_linker_option=""

./configure \
    --host="${HOST_TRIPLE}" \
    --with-libevent-dir="${DEPS_DIR}" \
    --with-openssl-dir="${DEPS_DIR}" \
    --with-zlib-dir="${DEPS_DIR}" \
    ${CONFIGURE_FLAGS}

log_info "Building Tor..."
make -j"$(nproc)"

log_info "Installing to temp directory..."
make DESTDIR="${INSTALL_DIR}" install

# Strip binaries using arch-specific strip tool
STRIP_TOOL="${HOST_TRIPLE}-strip"
for bin in ${OUTPUT_INCLUDES}; do
    if [[ -f "${INSTALL_DIR}/${bin}" ]]; then
        log_info "Stripping ${bin}"
        ${STRIP_TOOL} "${INSTALL_DIR}/${bin}" || true
    fi
done

# Repack only the declared output files
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging binaries..."
tar czf "${OUTPUT_ARCHIVE}" -C "${INSTALL_DIR}" ${OUTPUT_INCLUDES}

# Generate checksum
sha256sum "${OUTPUT_ARCHIVE}" | tee "${OUTPUT_ARCHIVE}.sha256"
log_info "Packed: ${OUTPUT_ARCHIVE}"
