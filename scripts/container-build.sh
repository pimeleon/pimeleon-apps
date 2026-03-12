#!/bin/bash
# Pimeleon In-Container App Builder
set -euo pipefail
source /scripts/common.sh

# Configure APT proxy if present (e.g. for local builds)
configure_chroot_apt_proxy ""

if [[ $# -lt 1 ]]; then
    die "Usage: $0 <package_name> [version]"
fi

PKG_NAME="$1"
PKG_VERSION="${2:-latest}"

# Source package environment if present
if [[ -f "/package/package.env" ]]; then
    source /package/package.env
    PKG_VERSION="${PACKAGE_VERSION:-latest}"
fi

# Install dependencies if defined
case "${TARGET_ARCH}" in
    armhf) DEPS_VAR="BUILD_DEPS_ARMHF" ;;
    arm64) DEPS_VAR="BUILD_DEPS_ARM64" ;;
    *) DEPS_VAR="" ;;
esac

if [[ -n "${DEPS_VAR}" && -n "${!DEPS_VAR:-}" ]]; then
    log_info "Installing dependencies: ${!DEPS_VAR}"
    apt-get update && apt-get install -yq --no-install-recommends ${!DEPS_VAR}
fi

# Execute the specific package build script
if [[ -f "/package/build.sh" ]]; then
    log_info "Starting build for ${PKG_NAME} v${PKG_VERSION}"
    /bin/bash /package/build.sh "${PKG_VERSION}"
else
    die "Build script not found at /package/build.sh"
fi
