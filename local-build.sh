#!/bin/bash
# local-build.sh — build builder Docker images locally
# Usage: local-build.sh [armhf|arm64|all] [--no-cache]
#
# Builds the cross-compilation containers used by local-run.sh and CI.

set -euo pipefail
source "$(dirname "$0")/scripts/common.sh"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCH="${1:-all}"
NO_CACHE=""
[[ "${2:-}" == "--no-cache" ]] && NO_CACHE="--no-cache"

APT_CACHE_SERVER="192.168.76.5"
APT_CACHE_PORT="3142"

build_image() {
    local arch="$1"
    local image="pi-router-apps/builder-${arch}:local"
    local dockerfile="${REPO_ROOT}/containers/builder-${arch}/Dockerfile"

    [[ -f "${dockerfile}" ]] || die "Dockerfile not found: ${dockerfile}"

    log_info "Building ${image} ..."
    docker build \
        ${NO_CACHE} \
        --build-arg APT_CACHE_SERVER="${APT_CACHE_SERVER}" \
        --build-arg APT_CACHE_PORT="${APT_CACHE_PORT}" \
        -t "${image}" \
        -f "${dockerfile}" \
        "${REPO_ROOT}"
    log_info "Done: ${image}"
}

case "${ARCH}" in
    armhf) build_image armhf ;;
    arm64) build_image arm64 ;;
    all)   build_image armhf; build_image arm64 ;;
    *)     die "Unknown arch: ${ARCH}. Use: armhf | arm64 | all" ;;
esac
