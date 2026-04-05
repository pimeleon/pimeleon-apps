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
        if [[ -f "logs/${PKG_NAME}-${TARGET_ARCH}.log" ]]; then
            log_error "Build failed! Last 100 lines of logs/${PKG_NAME}-${TARGET_ARCH}.log:"
            echo "--------------------------------------------------------------------------------"
            tail -n 100 "logs/${PKG_NAME}-${TARGET_ARCH}.log"
            echo "--------------------------------------------------------------------------------"
        fi
        log_warn "Removing stalled build directory for ${PKG_NAME}..."
        # Target the architecture-specific subdirectory
        safe_rm "build/${TARGET_ARCH}/build-${PKG_NAME}" || true
    fi
    exit "$exit_code"
}
trap "cleanup_handler" EXIT ERR INT TERM PIPE

check_package_in_registry() {
    local pkg_name="$1"
    local pkg_version="$2"
    local arch="$3"
    local registry_url="https://gitlab.pirouter.dev/api/v4/projects/20/packages/generic"
    local gl_version="${arch}-${pkg_version}"
    local package_url="${registry_url}/${pkg_name}/${gl_version}/${pkg_name}-${pkg_version}-${arch}-pimeleon.tar.gz"

    local curl_opts=("-fsSL" "-k" "-I" "--max-time" "10")
    if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
        curl_opts+=("-H" "JOB-TOKEN: ${CI_JOB_TOKEN}")
    fi

    curl "${curl_opts[@]}" "${package_url}" >/dev/null 2>&1
}

if [[ $# -lt 1 ]]; then
    die "Usage: $0 <package_name> [version]"
fi

PKG_NAME="$1"
PKG_VERSION="${2:-}"

# JIT Version Resolution
if [[ -z "${PKG_VERSION}" ]] || [[ "${PKG_VERSION}" == "latest" ]]; then
    log_info "No version specified for ${PKG_NAME}. Resolving JIT from environment or upstream..."
    # shellcheck source=/dev/null
    source "packages/${PKG_NAME}/package.env"

    # Use PACKAGE_VERSION from env as primary source
    PKG_VERSION="${PACKAGE_VERSION:-}"

    if [[ -z "${PKG_VERSION}" ]] || [[ "${PKG_VERSION}" == "latest" ]]; then
        PKG_VERSION=$(bash scripts/check-upstream.sh \
            "${UPSTREAM_REPO}" \
            "${UPSTREAM_TYPE}" \
            "${UPSTREAM_GITLAB_HOST:-gitlab.com}" \
            "${UPSTREAM_TAG_PREFIX:-}" \
            "${UPSTREAM_TAG_PATTERN:-}" 2>/dev/null) || \
            die "Cannot resolve version for ${PKG_NAME}: upstream query failed and no version specified in package.env"
    fi
    log_info "Resolved ${PKG_NAME} to version ${PKG_VERSION}"
fi

# Skip build if matching version already exists in registry
if [[ "${FORCE_BUILD:-0}" != "1" ]]; then
    if check_package_in_registry "${PKG_NAME}" "${PKG_VERSION}" "${TARGET_ARCH}"; then
        log_info "✓ ${PKG_NAME} v${PKG_VERSION} [${TARGET_ARCH}] already in registry — skipping build"
        exit 0
    fi
fi

log_section "Building ${PKG_NAME} (${PKG_VERSION}) [Arch: ${TARGET_ARCH}, Source: ${SOURCES}]"

# 1. Prepare Container (Command MUST be specified at creation)
# Allow package.env to override the builder image via BUILD_IMAGE
_pkg_build_image=$(grep -m1 '^BUILD_IMAGE=' "packages/${PKG_NAME}/package.env" 2>/dev/null \
    | sed 's/^BUILD_IMAGE=//' | tr -d '"'"'" || true)

if [[ -n "${_pkg_build_image:-}" ]]; then
    IMAGE="${_pkg_build_image}"
elif [[ -n "${CI_REGISTRY_IMAGE:-}" ]]; then
    IMAGE="${CI_REGISTRY_IMAGE}/builder-${TARGET_ARCH}:latest"
else
    IMAGE="pimeleon-builder-${TARGET_ARCH}:latest"
fi

# Isolate build path by architecture to prevent parallel build contamination
LOCAL_BUILD_DIR="$(pwd)/build/${TARGET_ARCH}"
mkdir -p "${LOCAL_BUILD_DIR}" logs output
CONTAINER_ID=$(docker create \
    --privileged \
    --user "$(id -u):$(id -g)" \
    -v /dev:/dev:rw \
    -v "${LOCAL_BUILD_DIR}:/build" \
    -v "$(pwd)/cache:/cache" \
    -v "$(pwd)/logs:/logs" \
    -v "$(pwd)/output:${OUTPUT_DIR}" \
    -e PACKAGE_NAME="${PKG_NAME}" \
    -e PACKAGE_VERSION="${PKG_VERSION}" \
    -e TARGET_ARCH="${TARGET_ARCH}" \
    -e OUTPUT_DIR="${OUTPUT_DIR}" \
    -e LOGS_DIR="/logs" \
    -e PIMELEON_PROFILE="${PIMELEON_PROFILE}" \
    -e APT_CACHE_SERVER="${APT_CACHE_SERVER:-}" \
    -e APT_CACHE_PORT="${APT_CACHE_PORT:-}" \
    -e GOCACHE=/build/.cache/go-build \
    -e GOMODCACHE=/build/.cache/go-mod \
    -e HOME=/build \
    "${IMAGE}" /scripts/container-build.sh "${PKG_NAME}" "${PKG_VERSION}")

# 2. Inject Code
log_info "Injecting scripts and package source..."
# Inject scripts directory (containing common.sh and container-build.sh)
docker cp scripts/. "${CONTAINER_ID}:/scripts/"
# Inject package-specific build script and environment
docker cp "packages/${PKG_NAME}/." "${CONTAINER_ID}:/package/"

# 3. Execute Build (Start and Attach)
# Remove stale log file (may be root-owned from a pre-`--user` run)
rm -f "logs/${PKG_NAME}-${TARGET_ARCH}.log" 2>/dev/null || true
log_info "Logging build output to logs/${PKG_NAME}-${TARGET_ARCH}.log"
if [[ "${QUIET:-0}" == "1" ]]; then
    docker start -a "${CONTAINER_ID}" > "logs/${PKG_NAME}-${TARGET_ARCH}.log" 2>&1
else
    docker start -a "${CONTAINER_ID}" 2>&1 | tee "logs/${PKG_NAME}-${TARGET_ARCH}.log"
fi

# 4. Results are written directly to the mounted output volume — no copy needed
log_info "Build complete. Output written to $(pwd)/output/"
