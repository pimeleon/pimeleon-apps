#!/bin/bash
# scripts/update-sources.sh — download and cache source tarballs/repos
# Used by GitLab CI Cron to ensure sources are available in the local registry.
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "${SCRIPT_DIR}/common.sh"

CACHE_DIR="${CACHE_DIR:-cache/pimeleon-downloads}"
mkdir -p "${CACHE_DIR}"

PROJECT_ID="20"  # pi-router-apps project
REGISTRY_URL="https://gitlab.pirouter.dev/api/v4/projects/${PROJECT_ID}/packages/generic/sources"

download_and_cache_tarball() {
    local pkg_name="$1"
    local version="$2"
    local dist_url="$3"
    local tarball_name="$4"
    local local_path="${CACHE_DIR}/${tarball_name}"
    local pkg_registry_url="${REGISTRY_URL}/${pkg_name}/${version}/${tarball_name}"

    log_info "Processing source for ${pkg_name} ${version}..."

    # Check if already in registry (only in CI)
    if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
        if curl -fsSL -k -I -H "JOB-TOKEN: ${CI_JOB_TOKEN}" "${pkg_registry_url}" >/dev/null 2>&1; then
            log_info "[SKIP] ${pkg_name} ${version} already in registry."
            return 0
        fi
    fi

    # Download from upstream
    log_info "Downloading ${pkg_name} ${version} from ${dist_url}..."
    if ! curl -fsSL -o "${local_path}" "${dist_url}"; then
        log_error "Failed to download ${pkg_name} from upstream."
        return 1
    fi

    # Upload to registry (only in CI)
    if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
        log_info "Uploading ${pkg_name} ${version} to registry..."
        curl -sSL -k --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
            --upload-file "${local_path}" "${pkg_registry_url}"
    fi

    log_success "Source for ${pkg_name} ${version} updated."
}

process_package() {
    local pkg_dir="$1"
    [ -f "${pkg_dir}/package.env" ] || return 0

    # Clean env for each package
    (
        # shellcheck source=/dev/null
        source "${pkg_dir}/package.env"

        # Determine latest version from upstream
        log_info "Checking upstream for ${PACKAGE_NAME}..."
        local latest_version
        latest_version=$(bash scripts/check-upstream.sh \
            "${UPSTREAM_REPO}" \
            "${UPSTREAM_TYPE}" \
            "${UPSTREAM_GITLAB_HOST:-gitlab.com}" \
            "${UPSTREAM_TAG_PREFIX:-}" \
            "${UPSTREAM_TAG_PATTERN:-}" 2>/dev/null || echo "${PACKAGE_VERSION}")

        if [[ -z "${latest_version}" ]]; then
            log_warn "Could not determine upstream version for ${PACKAGE_NAME}, falling back to ${PACKAGE_VERSION}"
            latest_version="${PACKAGE_VERSION}"
        fi

        # Determine version (use tracking file if exists, otherwise package.env)
        local current_version="${PACKAGE_VERSION}"
        local version_file="versions/${PACKAGE_NAME}-armhf.version"
        if [ -f "${version_file}" ]; then
            current_version=$(cat "${version_file}")
        fi

        case "${PACKAGE_NAME}" in
            tor)
                local tarball="tor-${latest_version}.tar.gz"
                local url="https://dist.torproject.org/${tarball}"
                download_and_cache_tarball "${PACKAGE_NAME}" "${latest_version}" "${url}" "${tarball}"
                ;;
            hostapd)
                local tarball="hostapd-${latest_version}.tar.gz"
                local url="https://w1.fi/releases/${tarball}"
                download_and_cache_tarball "${PACKAGE_NAME}" "${latest_version}" "${url}" "${tarball}"
                ;;
            wpa_supplicant)
                local tarball="wpa_supplicant-${latest_version}.tar.gz"
                local url="https://w1.fi/releases/${tarball}"
                download_and_cache_tarball "${PACKAGE_NAME}" "${latest_version}" "${url}" "${tarball}"
                ;;
            privoxy)
                log_info "Package ${PACKAGE_NAME} uses official Git repository, skipping registry upload for now."
                ;;
            pihole-FTL)
                log_info "Package ${PACKAGE_NAME} uses git clone, skipping registry upload for now."
                ;;
            dnscrypt-proxy)
                log_info "Package ${PACKAGE_NAME} is Go-based, skipping registry upload."
                ;;
            *)
                log_warn "Unknown package type for source update: ${PACKAGE_NAME}"
                ;;
        esac

        # Update tracking files if version changed
        if [[ "${latest_version}" != "${current_version}" ]]; then
            log_info "Updating version files for ${PACKAGE_NAME}: ${current_version} -> ${latest_version}"
            for arch in ${SUPPORTED_ARCHES}; do
                echo "${latest_version}" > "versions/${PACKAGE_NAME}-${arch}.version"
            done
        fi
    )
}

if [[ $# -gt 0 ]]; then
    process_package "packages/$1"
else
    for pkg_dir in packages/*/; do
        process_package "${pkg_dir%/}"
    done
fi
