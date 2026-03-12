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

# If version is latest, try to get it from package.env
if [[ "${PKG_VERSION}" == "latest" && -f "/package/package.env" ]]; then
    source /package/package.env
    PKG_VERSION="${PACKAGE_VERSION:-latest}"
fi

# Execute the specific package build script
if [[ -f "/package/build.sh" ]]; then
    log_info "Starting build for ${PKG_NAME} v${PKG_VERSION}"
    /bin/bash /package/build.sh "${PKG_VERSION}"
else
    die "Build script not found at /package/build.sh"
fi
