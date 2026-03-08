#!/bin/bash
# scripts/local-run.sh — run a single package build locally using Docker
# Usage: local-run.sh <package> <arch> [--shell]
#
# Options:
#   --shell   Open an interactive shell in the container instead of running the build

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "${REPO_ROOT}/scripts/common.sh"

PACKAGE="${1:?Usage: local-run.sh <package> <arch> [--shell]}"
ARCH="${2:?Usage: local-run.sh <package> <arch> [--shell]}"
MODE="${3:-}"
PKG_DIR="${REPO_ROOT}/packages/${PACKAGE}"
OUTPUT_DIR="${REPO_ROOT}/output"
BUILD_IMAGE="pi-router-apps/builder-${ARCH}:local"

[[ -d "${PKG_DIR}" ]]          || die "Unknown package: ${PACKAGE} (no packages/${PACKAGE}/ directory)"
[[ -f "${PKG_DIR}/package.env" ]] || die "Missing packages/${PACKAGE}/package.env"

VERSION_FILE="${REPO_ROOT}/versions/${PACKAGE}-${ARCH}.version"
[[ -f "${VERSION_FILE}" ]] || die "Missing versions/${PACKAGE}-${ARCH}.version"
VERSION=$(cat "${VERSION_FILE}")

# Ensure builder image exists
if ! docker image inspect "${BUILD_IMAGE}" >/dev/null 2>&1; then
    log_warn "Builder image ${BUILD_IMAGE} not found — building it now"
    docker build \
        --build-arg APT_CACHE_SERVER=192.168.76.5 \
        --build-arg APT_CACHE_PORT=3142 \
        -t "${BUILD_IMAGE}" \
        -f "${REPO_ROOT}/containers/builder-${ARCH}/Dockerfile" "${REPO_ROOT}"
fi

mkdir -p "${OUTPUT_DIR}"

log_info "Package : ${PACKAGE} ${VERSION} (${ARCH})"
log_info "Image   : ${BUILD_IMAGE}"
log_info "Output  : ${OUTPUT_DIR}"

CONTAINER_ID=$(docker create \
    -e PACKAGE_NAME="${PACKAGE}" \
    -e PACKAGE_VERSION="${VERSION}" \
    -e TARGET_ARCH="${ARCH}" \
    -e APT_CACHE_SERVER=192.168.76.5 \
    -e APT_CACHE_PORT=3142 \
    -e OUTPUT_DIR=/output \
    ${MODE:+--entrypoint bash} \
    ${MODE:+-it} \
    "${BUILD_IMAGE}" \
    ${MODE:+})

docker cp "${PKG_DIR}/."               "${CONTAINER_ID}:/package/"
docker cp "${REPO_ROOT}/scripts/."    "${CONTAINER_ID}:/scripts/"

if [[ "${MODE}" == "--shell" ]]; then
    docker start -ai "${CONTAINER_ID}" || true
else
    docker start -a "${CONTAINER_ID}"
    EXIT_CODE=$(docker inspect "${CONTAINER_ID}" --format='{{.State.ExitCode}}')
    docker cp "${CONTAINER_ID}:/output/." "${OUTPUT_DIR}/" 2>/dev/null || true
    docker rm "${CONTAINER_ID}"
    if [[ "${EXIT_CODE}" -ne 0 ]]; then
        die "Build failed with exit code ${EXIT_CODE}"
    fi
    log_info "Output files:"
    ls -lh "${OUTPUT_DIR}/${PACKAGE}"* 2>/dev/null || log_warn "No output files found"
    return 0
fi

docker rm "${CONTAINER_ID}" 2>/dev/null || true
