#!/bin/bash
# scripts/build-package.sh — orchestrator that runs inside the builder container
# Environment variables expected:
#   PACKAGE_NAME    - package to build (must match a packages/ directory)
#   PACKAGE_VERSION - version string to build
#   TARGET_ARCH     - armhf or arm64
#   APT_CACHE_SERVER, APT_CACHE_PORT - optional APT proxy

set -euo pipefail
source /scripts/common.sh

: "${PACKAGE_NAME:?PACKAGE_NAME required}"
: "${PACKAGE_VERSION:?PACKAGE_VERSION required}"
: "${TARGET_ARCH:?TARGET_ARCH required}"

PACKAGE_DIR="/package"
OUTPUT_DIR="/output"

[[ -f "${PACKAGE_DIR}/package.env" ]] || die "Missing ${PACKAGE_DIR}/package.env"
[[ -f "${PACKAGE_DIR}/build.sh" ]]    || die "Missing ${PACKAGE_DIR}/build.sh"

# shellcheck source=/dev/null
source "${PACKAGE_DIR}/package.env"

log_info "Building ${PACKAGE_NAME} ${PACKAGE_VERSION} for ${TARGET_ARCH}"
log_info "Build type: ${BUILD_TYPE}"

mkdir -p "${OUTPUT_DIR}"

# Configure cross-compilation toolchain (for source builds)
if [[ "${BUILD_TYPE}" == "source" ]]; then
    if [[ "${TARGET_ARCH}" == "armhf" ]]; then
        export CROSS_TRIPLE="arm-linux-gnueabihf"
    else
        export CROSS_TRIPLE="aarch64-linux-gnu"
    fi
    export CC="${CROSS_TRIPLE}-gcc"
    export CXX="${CROSS_TRIPLE}-g++"
    export AR="${CROSS_TRIPLE}-ar"
    export STRIP="${CROSS_TRIPLE}-strip"
    export PKG_CONFIG_PATH="/usr/lib/${CROSS_TRIPLE}/pkgconfig:/usr/share/pkgconfig"
    export PKG_CONFIG_LIBDIR="/usr/lib/${CROSS_TRIPLE}/pkgconfig"
    export LDFLAGS="-L/usr/lib/${CROSS_TRIPLE}"
    export HOST_TRIPLE="${CROSS_TRIPLE}"
fi

# Install package-specific build deps
if [[ "${TARGET_ARCH}" == "armhf" ]] && [[ -n "${BUILD_DEPS_ARMHF:-}" ]]; then
    log_info "Installing armhf build deps: ${BUILD_DEPS_ARMHF}"
    # shellcheck disable=SC2086
    apt_install ${BUILD_DEPS_ARMHF}
elif [[ "${TARGET_ARCH}" == "arm64" ]] && [[ -n "${BUILD_DEPS_ARM64:-}" ]]; then
    log_info "Installing arm64 build deps: ${BUILD_DEPS_ARM64}"
    # shellcheck disable=SC2086
    apt_install ${BUILD_DEPS_ARM64}
fi

# Run the package-specific build script
bash "${PACKAGE_DIR}/build.sh"

# Verify output was produced
OUTPUT_ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}-${TARGET_ARCH}-pimeleon.tar.gz"
[[ -f "${OUTPUT_ARCHIVE}" ]] || die "Build script did not produce ${OUTPUT_ARCHIVE}"

# Generate checksum
sha256sum "${OUTPUT_ARCHIVE}" > "${OUTPUT_ARCHIVE}.sha256"
log_info "Done: ${OUTPUT_ARCHIVE}"
ls -lh "${OUTPUT_DIR}/"
