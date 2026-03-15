#!/bin/bash
# packages/privoxy/build.sh
# BUILD_TYPE=source: cross-compile privoxy from official sources
set -euo pipefail
source /scripts/common.sh
source /package/package.env

VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/build/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/privoxy-${VERSION}"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}/usr/local/sbin" "${INSTALL_DIR}/etc/privoxy/templates"

# Handle Source (Git or Tarball)
if [[ "${UPSTREAM_REPO}" == *.git ]]; then
    log_info "Cloning Privoxy from ${UPSTREAM_REPO}..."
    rm -rf "${SRC_DIR}"
    # Git tags use underscores: v_4_1_0
    TAG_NAME="v_$(echo ${VERSION} | tr '.' '_')"
    git clone --depth 1 --branch "${TAG_NAME}" "${UPSTREAM_REPO}" "${SRC_DIR}"
else
    TARBALL="privoxy-${VERSION}-stable-src.tar.gz"
    DIST_URL="https://www.privoxy.org/sf-download-mirror/Sources/${VERSION}%20(stable)/${TARBALL}"
    fetch_source "${PACKAGE_NAME}" "${VERSION}" "${TARBALL}" "${DIST_URL}" "${WORK_DIR}/${TARBALL}"
    log_info "Extracting source"
    tar xf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}"
    # SourceForge tarballs extract to privoxy-X.Y.Z-stable
    mv "${WORK_DIR}/privoxy-${VERSION}-stable" "${SRC_DIR}" 2>/dev/null || true
fi

cd "${SRC_DIR}"

log_info "Generating configure script"
autoheader
autoconf

log_info "Configuring privoxy..."

# Determine cross-compilation triple from CC
HOST_TRIPLE=${CC%-gcc}

# Set cross-compilation environment variables for pkg-config
export PKG_CONFIG="${HOST_TRIPLE}-pkg-config"
export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_LIBDIR="/usr/lib/${HOST_TRIPLE}/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_PATH=""
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

log_info "Building privoxy for ${TARGET_ARCH} using triple ${HOST_TRIPLE}..."

./configure --host="${HOST_TRIPLE}" ${CONFIGURE_FLAGS}

make -j"$(nproc)"

log_info "Installing binaries and configs..."
cp privoxy "${INSTALL_DIR}/usr/local/sbin/"
cp config default.action match-all.action trust user.action default.filter user.filter "${INSTALL_DIR}/etc/privoxy/"
cp -r templates/* "${INSTALL_DIR}/etc/privoxy/templates/"

# Strip binaries
STRIP_TOOL="${HOST_TRIPLE}-strip"
bin="usr/local/sbin/privoxy"
if [[ -f "${INSTALL_DIR}/${bin}" ]]; then
    log_info "Stripping ${bin}"
    ${STRIP_TOOL} "${INSTALL_DIR}/${bin}" || true
fi

# Repack
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
log_info "Packaging binaries..."
tar czf "${OUTPUT_ARCHIVE}" -C "${INSTALL_DIR}" ${OUTPUT_INCLUDES}

# Generate checksum
sha256sum "${OUTPUT_ARCHIVE}" | tee "${OUTPUT_ARCHIVE}.sha256"
log_info "Packed: ${OUTPUT_ARCHIVE}"
