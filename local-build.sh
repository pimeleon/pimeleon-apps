#!/bin/bash
# Local App Builder for pi-router-apps
set -euo pipefail

# Available packages list
PACKAGES=("dnscrypt-proxy" "hostapd" "pihole" "privoxy" "tor" "wpa_supplicant")
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

    # Source the package environment to get the version
    if [ ! -f "packages/${pkg}/package.env" ]; then
        log_error "Package environment not found: packages/${pkg}/package.env"
        return 1
    fi
    source "packages/${pkg}/package.env"
    local version="${PACKAGE_VERSION}"

    if [[ -z "${version}" ]]; then
        log_info "No version specified in package.env for $pkg. Resolving..."
        # Optional: Sync sources if no version exists, or to update
        ./scripts/update-sources.sh "$pkg"
    fi

    if [[ -z "${version}" ]]; then
        log_error "Could not resolve version for ${pkg}"
        return 1
    fi

    # Check if image already exists in registry (pi-router-apps project ID: 20)
    local registry_url="https://gitlab.pirouter.dev/api/v4/projects/20/packages/generic"
    local gl_version="${target_arch}-${version}"
    local package_url="${registry_url}/${pkg}/${gl_version}/${pkg}-${version}-${target_arch}-pimeleon.tar.gz"

    # Check registry with auth if in CI
    local curl_opts=("-fsSL" "-k" "-I")
    if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
        curl_opts+=("-H" "JOB-TOKEN: ${CI_JOB_TOKEN}")
    fi

    if curl "${curl_opts[@]}" "${package_url}" >/dev/null 2>&1; then
        log_info "✓ ${pkg} v${version} for ${target_arch} already in registry — skipping build"
        return 0
    fi

    log_info "Building $pkg v${version} for $target_arch (Local Mode)..."
    mkdir -p output logs

    # Launch build via Docker
    TARGET_ARCH=$target_arch \
    SOURCES=local \
    APT_PROXY="${APT_PROXY:-}" \
    QUIET="${QUIET:-1}" \
    ./scripts/build-package.sh "$pkg" "$version"
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
