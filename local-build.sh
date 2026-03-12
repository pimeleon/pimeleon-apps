#!/bin/bash
# Local App Builder for pi-router-apps
set -euo pipefail

PACKAGE=${1:-}
ARCH=${2:-${TARGET_ARCH:-armhf}}

if [[ -z "$PACKAGE" ]]; then
    echo "Usage: $0 <package_name> [arch]"
    exit 1
fi

log_info() { echo -e "[0;32m[INFO][0m $*"; }

log_info "Building $PACKAGE for $ARCH (Local Mode)..."
mkdir -p output

# Launch build via Docker without registry push
TARGET_ARCH=$ARCH \
SOURCES=local \
APT_PROXY="${APT_PROXY:-}" \
./scripts/build-package.sh "$PACKAGE"
