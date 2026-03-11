#!/bin/bash
# Pimeleon Package Builder Orchestrator (Single Environment)
# Always builds from production sources.
set -euo pipefail
set -E

# Source common functions
source "$(dirname "$0")/common.sh"

# Default variables
export SOURCES="${SOURCES:-github}"
export TARGET_ARCH="${TARGET_ARCH:-armhf}"
export OUTPUT_DIR="${OUTPUT_DIR:-/output}"
export PIMELEON_PROFILE="production" # Strictly production

# Cleanup handler for Docker containers
cleanup_handler() {
    local exit_code=$?
    trap - EXIT ERR INT TERM PIPE
    if [[ -n "${CONTAINER_ID:-}" ]]; then
        log_warn "Cleaning up build container..."
        docker rm -f "${CONTAINER_ID}" >/dev/null 2>&1 || true
    fi
    exit $exit_code
}
trap "cleanup_handler" EXIT ERR INT TERM PIPE

if [[ $# -lt 1 ]]; then
    die "Usage: $0 <package_name> [version]"
fi

PKG_NAME="$1"
PKG_VERSION="${2:-latest}"

log_section "Building ${PKG_NAME} (${PKG_VERSION}) [Arch: ${TARGET_ARCH}, Source: ${SOURCES}]"

# 1. Prepare Container
IMAGE="ghcr.io/pimeleon/builder-${TARGET_ARCH}:latest"
CONTAINER_ID=$(docker create \
    --privileged \
    -v /dev:/dev:rw \
    -e PACKAGE_NAME="${PKG_NAME}" \
    -e PACKAGE_VERSION="${PKG_VERSION}" \
    -e TARGET_ARCH="${TARGET_ARCH}" \
    -e OUTPUT_DIR="${OUTPUT_DIR}" \
    -e PIMELEON_PROFILE="${PIMELEON_PROFILE}" \
    "${IMAGE}")

# 2. Inject Code
if [[ "${SOURCES}" == "local" ]]; then
    log_info "Injecting LOCAL sources from packages/${PKG_NAME}"
    docker cp "packages/${PKG_NAME}/." "${CONTAINER_ID}:/package/"
else
    log_info "Injecting REMOTE sources logic"
    docker cp "packages/${PKG_NAME}/." "${CONTAINER_ID}:/package/"
fi

# Inject shared scripts and common libs
docker cp scripts/. "${CONTAINER_ID}:/scripts/"

# 3. Execute Build
docker start -a "${CONTAINER_ID}"

# 4. Extract Results
mkdir -p output
docker cp "${CONTAINER_ID}:${OUTPUT_DIR}/." output/
