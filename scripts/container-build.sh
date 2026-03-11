#!/bin/bash
# Pimeleon In-Container App Builder
set -euo pipefail
source /scripts/common.sh

if [[ $# -lt 1 ]]; then
    die "Usage: $0 <package_name> [version]"
fi

PKG_NAME="$1"
PKG_VERSION="${2:-latest}"

# Execute the specific package build script
if [[ -f "/package/build.sh" ]]; then
    log_info "Starting build for ${PKG_NAME} v${PKG_VERSION}"
    bash /package/build.sh "${PKG_VERSION}"
else
    die "Build script not found at /package/build.sh"
fi
