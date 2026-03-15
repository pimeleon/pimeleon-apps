#!/bin/bash
# scripts/check-upstream-versions.sh — query upstreams and commit updates
set -euo pipefail

# Source common functions for logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Determine target branch
TARGET_BRANCH="${CI_COMMIT_BRANCH:-${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-}}"
if [ -z "${TARGET_BRANCH}" ]; then
    log_error "Could not determine target branch for push. Skipping update."
    exit 1
fi
log_info "CI Environment: TARGET_BRANCH=${TARGET_BRANCH}, CI_COMMIT_BRANCH=${CI_COMMIT_BRANCH:-none}"

CHANGED=0
# Check for Go version updates
"${SCRIPT_DIR}/update-tools.sh"

for pkg_dir in packages/*/; do
    [ -f "${pkg_dir}/package.env" ] || continue
    # shellcheck source=/dev/null
    source "${pkg_dir}/package.env"

    LATEST=$(bash "${SCRIPT_DIR}/check-upstream.sh" \
        "${UPSTREAM_REPO}" \
        "${UPSTREAM_TYPE}" \
        "${UPSTREAM_GITLAB_HOST:-gitlab.com}" \
        "${UPSTREAM_TAG_PREFIX:-}" \
        "${UPSTREAM_TAG_PATTERN:-}" 2>/dev/null || true)

    if [ -z "${LATEST}" ]; then
        log_error "Could not determine upstream version for ${PACKAGE_NAME}. Check scripts/check-upstream.sh or package.env."
        exit 1
    fi

    for arch in ${SUPPORTED_ARCHES}; do
        VERSION_FILE="versions/${PACKAGE_NAME}-${arch}.version"
        CURRENT=$(cat "${VERSION_FILE}" 2>/dev/null || echo "none")
        if [ "${LATEST}" != "${CURRENT}" ]; then
            log_info "Update detected: ${PACKAGE_NAME} ${arch}: ${CURRENT} -> ${LATEST}"
            echo "${LATEST}" > "${VERSION_FILE}"
            git add "${VERSION_FILE}"
            CHANGED=1
        else
            log_info "Up to date: ${PACKAGE_NAME} ${arch} @ ${LATEST}"
        fi
    done
done

if [ "${CHANGED}" = "1" ]; then
    # Ensure all new sources are pre-downloaded and cached in registry
    "${SCRIPT_DIR}/update-sources.sh"

    # Sync with remote branch and apply changes on top
    log_info "Synchronizing with remote branch ${TARGET_BRANCH}..."
    git fetch origin "${TARGET_BRANCH}"
    git checkout -B "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}"

    # Apply changes to the fresh branch
    git add versions/*.version
    git commit -m "chore(versions): update upstream package versions [skip ci]"

    log_info "Pushing updated versions to ${TARGET_BRANCH}..."
    git push origin "${TARGET_BRANCH}"
    log_success "Pushed version updates to ${TARGET_BRANCH}"
else
    # Always ensure current sources are cached
    "${SCRIPT_DIR}/update-sources.sh"
    log_info "All packages up to date, no changes committed"
fi
