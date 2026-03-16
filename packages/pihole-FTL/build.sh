#!/bin/bash
# packages/pihole-FTL/build.sh
# BUILD_TYPE=source: cross-compile pihole-FTL (The core DNS engine)
set -euo pipefail
source /scripts/common.sh
source /package/package.env
# Preserve logs on exit
cleanup() {
    log_info "Preserving build logs..."
    mkdir -p "${LOGS_DIR}/cmake"
    cp -r build/CMakeFiles/*.log "${LOGS_DIR}/cmake/" 2>/dev/null || true
}
trap cleanup EXIT

VERSION="${1:-$PACKAGE_VERSION}"
WORK_DIR="/build/build-${PACKAGE_NAME}"
SRC_DIR="${WORK_DIR}/FTL-${VERSION#v}"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}" "${INSTALL_DIR}/usr/bin"

# Use git clone to ensure submodules are included (required for v6)
REPO_URL="https://github.com/pi-hole/FTL.git"

# Suppress detached HEAD advice for cleaner logs
git config --global advice.detachedHead false
# Ensure work directory is prepared
mkdir -p "$(dirname "${SRC_DIR}")"
# Create symlink to satisfy CMake path consistency if needed
ln -snf "/build/build-pihole-FTL" "/tmp/build-pihole-FTL"
if [[ ! -d "${SRC_DIR}/.git" ]]; then
    log_info "Cloning pihole-FTL ${VERSION} (including submodules)..."
    git clone --quiet --depth 1 --recursive --branch "${VERSION}" "${REPO_URL}" "${SRC_DIR}"
else
    log_info "Using existing pihole-FTL source tree."
    cd "${SRC_DIR}"
    git reset --hard --quiet || (log_warn "Standard reset failed, attempting resilient reset..." && git checkout HEAD -- . 2>/dev/null || true)
    git clean -fd --quiet
    log_info "Updating submodules..."
    git submodule update --init --recursive --quiet
fi
if [[ ! -f "${SRC_DIR}/src/dnsmasq/CMakeLists.txt" ]]; then
    die "Submodules not correctly initialized"
fi

cd "${SRC_DIR}"

# Determine cross-compilation triple from CC
# CC is arm-linux-gnueabihf-gcc or aarch64-linux-gnu-gcc
HOST_TRIPLE=${CC%-gcc}
log_info "Configuring pihole-FTL for ${TARGET_ARCH} using triple ${HOST_TRIPLE}..."

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
export STATIC=true
export CFLAGS="-Wno-error -Wno-stringop-overread"
export CXXFLAGS="-Wno-error"
# Apply stability patches to FINALIZED source tree
bash /package/patch-sources.sh "${SRC_DIR}"
# Persist CMakeLists.txt for analysis
log_info "Persisting configuration for analysis..."
cp src/CMakeLists.txt "${LOGS_DIR}/pihole-CMakeLists.txt" 2>/dev/null || true
# Clear stale CMake build directory to prevent cross-arch compiler contamination
rm -rf build
mkdir -p build/src
# Generate FTL version header (must be after build/ cleanup)
printf "#define FTL_VERSION \"%s\"\n#define FTL_ARCH \"%s\"\n#define FTL_HASH \"pimeleon\"\n#define FTL_DATE \"%s\"\n" "${VERSION}" "${TARGET_ARCH}" "$(date -u)" > build/src/FTL_version.h
cmake -B build \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CC%-gcc}-g++" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR="${CMAKE_ARCH}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-Wno-stringop-overread -Wno-error" \
    -DCMAKE_CXX_FLAGS="-Wno-error" \
    -DSTATIC=ON \
    -DUPDATE_CHECK=OFF \
    -DGIT_VERSION=OFF \
    -DNET_UBUS=OFF \
    -DFT_TLS=OFF \
    -DLIBMATH=m \

log_info "Building pihole-FTL..."
cmake --build build -- -j1

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
