#!/bin/bash
# scripts/publish-builders.sh — Build and push builder images to GitLab Registry
set -euo pipefail
source "$(dirname "$0")/common.sh"

# GitLab Registry Config
REGISTRY_BASE="${CI_REGISTRY_IMAGE:-gitlab.pirouter.dev:5005/pimeleon/pi-router-apps}"
COMMIT_SHA="${CI_COMMIT_SHA:-local}"

publish_builder() {
    local arch=$1
    local image_name="builder-${arch}"
    local tag_latest="${REGISTRY_BASE}/${image_name}:latest"
    local tag_sha="${REGISTRY_BASE}/${image_name}:${COMMIT_SHA}"
    local dockerfile="containers/builder-${arch}/Dockerfile"

    log_info "Building ${image_name}..."

    # Ensure tools are cached for the build
    ./scripts/update-tools.sh

    # Use registry image as cache source to re-use unchanged layers
    docker build \
        --cache-from "${tag_latest}" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --pull \
        -t "${tag_latest}" \
        -t "${tag_sha}" \
        -f "${dockerfile}" .

    if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
        log_info "Pushing ${image_name} to registry..."
        docker push "${tag_latest}"
        docker push "${tag_sha}"
        log_success "Published ${image_name} to registry."
    else
        log_warn "Not in CI, skipping push for ${image_name}."
    fi
}

# Login to registry if in CI
if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
    echo "${CI_JOB_TOKEN}" | docker login "${CI_REGISTRY:-gitlab.pirouter.dev:5005}" -u gitlab-ci-token --password-stdin
fi

# Build and publish for both supported architectures
publish_builder "armhf"
publish_builder "arm64"
