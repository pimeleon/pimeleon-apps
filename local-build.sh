#!/bin/bash
# Local App Builder for pi-router-apps
set -euo pipefail

# Available packages list
PACKAGES=("dnscrypt-proxy" "hostapd" "pihole-FTL" "privoxy" "tor" "wpa_supplicant")
ARCHS=("armhf" "arm64")

show_help() {
    cat << EOF
Usage: $(basename "$0") <package_name>|all [arch]

Build a specific package or all packages for a target architecture locally using Docker.

Arguments:
  package_name    One of: ${PACKAGES[*]} or "all"
  arch            Target architecture: ${ARCHS[*]} (default: armhf)

Options:
  -h, --help      Show this help message and exit

Examples:
  $(basename "$0") tor
  $(basename "$0") all arm64
  $(basename "$0") dnscrypt-proxy armhf
EOF
}

# Handle help flags
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

PACKAGE=${1:-}
ARCH=${2:-${TARGET_ARCH:-armhf}}

if [[ -z "$PACKAGE" ]]; then
    echo "Error: Package name is required."
    show_help
    exit 1
fi

# Source common for logging and proxy setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "${SCRIPT_DIR}/scripts/common.sh"
trap "cleanup_on_exit" INT TERM

build_single_package() {
    local pkg=$1
    local target_arch=$2
    export CURRENT_PKG=$pkg

    log_info "Synchronizing sources for $pkg..."
    # This will check upstream, download if newer or missing, and update the version file
    ./scripts/update-sources.sh "$pkg"

    log_info "Building $pkg for $target_arch (Local Mode)..."
    mkdir -p output logs

    # Launch build via Docker
    TARGET_ARCH=$target_arch \
    SOURCES=local \
    APT_PROXY="${APT_PROXY:-}" \
    ./scripts/build-package.sh "$pkg"
}

if [[ "$PACKAGE" == "all" ]]; then
    log_info "Building all packages for $ARCH..."
    for pkg in "${PACKAGES[@]}"; do
        build_single_package "$pkg" "$ARCH" || {
            ret=$?
            if [[ $ret -eq 130 ]]; then
                log_warn "Build process interrupted."
                break
            fi
            exit $ret
        }
    done
else
    build_single_package "$PACKAGE" "$ARCH"
fi

