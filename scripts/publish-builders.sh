#!/bin/bash
# scripts/publish-builders.sh — Build and push a specific builder image to GitLab Registry
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ $# -lt 1 ]]; then
    die "Usage: $0 <arch>"
fi

ARCH=$1
REGISTRY_BASE="${CI_REGISTRY_IMAGE:-gitlab.pirouter.dev:5005/pimeleon/pi-router-apps}"
COMMIT_SHA="${CI_COMMIT_SHA:-local}"

IMAGE_NAME="builder-${ARCH}"
TAG_LATEST="${REGISTRY_BASE}/${IMAGE_NAME}:latest"
TAG_SHA="${REGISTRY_BASE}/${IMAGE_NAME}:${COMMIT_SHA}"
DOCKERFILE="Dockerfile.builder"

log_info "Building ${IMAGE_NAME}..."

# Ensure tools are cached for the build
./scripts/update-tools.sh

# Use registry image as cache source to re-use unchanged layers
docker build \
    --cache-from "${TAG_LATEST}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --pull \
    -t "${TAG_LATEST}" \
    -t "${TAG_SHA}" \
    -f "${DOCKERFILE}" .

if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
    log_info "Pushing ${IMAGE_NAME} to registry..."
    echo "${CI_JOB_TOKEN}" | docker login "${CI_REGISTRY:-gitlab.pirouter.dev:5005}" -u gitlab-ci-token --password-stdin >/dev/null 2>&1
    docker push "${TAG_LATEST}"
    docker push "${TAG_SHA}"
    log_success "Published ${IMAGE_NAME} to registry."
else
    log_warn "Not in CI, skipping push for ${IMAGE_NAME}."
fi
