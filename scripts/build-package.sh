#!/bin/bash
# Pimeleon Package Builder Orchestrator (Single Environment)
# Always builds from production sources.
set -euo pipefail
set -E

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "${SCRIPT_DIR}/common.sh"
echo "[INFO] Orchestrator started..."

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
    # On failure or interruption, remove the specific build directory to prevent stale artifacts
    if [[ $exit_code -ne 0 ]]; then
        log_warn "Removing stalled build directory for ${PKG_NAME}..."
        safe_rm "build/build-${PKG_NAME}" || true
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

# 1. Prepare Container (Command MUST be specified at creation)
IMAGE="pimeleon-builder-${TARGET_ARCH}:latest"
mkdir -p build logs
CONTAINER_ID=$(docker create \
    --privileged \
    --user "$(id -u):$(id -g)" \
    -v /dev:/dev:rw \
    -v "$(pwd)/build:/build" \
    -v "$(pwd)/cache:/cache" \
    -v "$(pwd)/logs:/logs" \
    -e PACKAGE_NAME="${PKG_NAME}" \
    -e PACKAGE_VERSION="${PKG_VERSION}" \
    -e TARGET_ARCH="${TARGET_ARCH}" \
    -e OUTPUT_DIR="${OUTPUT_DIR}" \
    -e LOGS_DIR="/logs" \
    -e PIMELEON_PROFILE="${PIMELEON_PROFILE}" \
    -e APT_CACHE_SERVER="${APT_CACHE_SERVER:-}" \
    -e APT_CACHE_PORT="${APT_CACHE_PORT:-}" \
    "${IMAGE}" /scripts/container-build.sh "${PKG_NAME}" "${PKG_VERSION}")

# 2. Inject Code
log_info "Injecting scripts and package source..."
# Inject scripts directory (containing common.sh and container-build.sh)
docker cp scripts/. "${CONTAINER_ID}:/scripts/"
# Inject package-specific build script and environment
docker cp "packages/${PKG_NAME}/." "${CONTAINER_ID}:/package/"

# 3. Execute Build (Start and Attach)
log_info "Logging build output to logs/${PKG_NAME}-${TARGET_ARCH}.log"
docker start -a "${CONTAINER_ID}" 2>&1 | tee "logs/${PKG_NAME}-${TARGET_ARCH}.log"

# 4. Extract Results
log_info "Extracting results..."
mkdir -p output
docker cp "${CONTAINER_ID}:${OUTPUT_DIR}/." output/
