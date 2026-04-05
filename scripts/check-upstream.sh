#!/bin/bash
# scripts/check-upstream.sh — query GitHub or GitLab API for latest release/tag version
# Usage: check-upstream.sh <repo> <type> [host] [tag_prefix] [tag_pattern]
# Outputs: clean version string (prefix stripped), or empty on failure
#
# type: "github_release" | "github_tag" | "gitlab" | "gitlab_release" | "gitlab_tag" | "git_tag" | "http_tarball"
# host: only used for gitlab types (default: gitlab.com)

set -euo pipefail

source "$(dirname "$0")/lib.sh"

REPO="${1:?repo required}"
TYPE="${2:?type required}"
UPSTREAM_GITLAB_HOST="${3:-gitlab.com}"
TAG_PREFIX="${4:-}"
# Optional: regex pattern that tag names (after prefix strip) must match. Empty = accept all.
TAG_PATTERN="${5:-}"

case "${TYPE}" in
    github|github_release)
        raw=$(query_with_retry "https://api.github.com/repos/${REPO}/releases/latest") || exit 1
        tag=$(echo "$raw" | jq -r '.tag_name // ""')
        if [ -z "${tag}" ]; then
            exit 1
        fi
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    github_tag)
        raw=$(query_with_retry "https://api.github.com/repos/${REPO}/tags?per_page=1") || exit 1
        tag=$(echo "$raw" | jq -r '.[0].name // ""')
        if [ -z "${tag}" ]; then
            exit 1
        fi
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    gitlab|gitlab_release)
        raw=$(query_with_retry \
            "https://${UPSTREAM_GITLAB_HOST}/api/v4/projects/${REPO}/releases?per_page=1") \
            || exit 1
        tag=$(echo "$raw" | jq -r '.[0].tag_name // ""')
        if [ -z "${tag}" ]; then
            exit 1
        fi
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    gitlab_tag)
        raw=$(query_with_retry \
            "https://${UPSTREAM_GITLAB_HOST}/api/v4/projects/${REPO}/repository/tags?order_by=version&per_page=5") \
            || exit 1
        # Pick first tag matching prefix and optional stable pattern
        tag=$(echo "$raw" | jq -r --arg prefix "${TAG_PREFIX}" --arg pattern "${TAG_PATTERN}" \
            '[.[] |
              select(if $prefix == "" then true else (.name | startswith($prefix)) end) |
              select(if $pattern == "" then true else (.name[($prefix | length):] | test($pattern)) end)
            ] | .[0].name // ""')
        if [ -z "${tag}" ]; then
            exit 1
        fi
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    git_tag)
        # Query remote git tags using git ls-remote
        raw=$(git ls-remote --tags --sort="v:refname" "${REPO}" | cut -f2 | grep -v "\^{}") || exit 1
        # Pick the latest tag matching the prefix and optional pattern
        # Filter: 1. refs/tags/prefix 2. strip refs/tags/ 3. match pattern against stripped tag
        tag=$(echo "$raw" | grep "refs/tags/${TAG_PREFIX}" | sed "s|refs/tags/||" | grep -E "${TAG_PATTERN:-.*}" | tail -n 1)
        if [ -z "${tag}" ]; then
            exit 1
        fi
        version="${tag#"${TAG_PREFIX}"}"
        # Special case: Privoxy tags use underscores (v_3_0_35), convert to dots (3.0.35)
        if [[ "${REPO}" == *"privoxy.git"* ]]; then
            version=$(echo "${version}" | tr '_' '.')
        fi
        echo "${version}"
        ;;
    http_tarball)
        # Specifically handle w1.fi releases (hostapd, wpa_supplicant)
        if [[ "$REPO" == *"w1.fi/releases"* ]]; then
            raw=$(query_with_retry "$REPO") || exit 1
            # Extract versions from links: hostapd-2.11.tar.gz -> 2.11
            # Filter for the specific package prefix and sort numerically
            pkg_prefix=$(echo "${REPO#*/releases/}" | cut -d/ -f1) # This is a bit naive, use package name instead
            # Note: In CI context, we don't have the package name here, so we rely on the URL structure
            # Let's use a more robust regex that looks for version numbers before .tar.gz
            tag=$(echo "$raw" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.gz' | sed 's/\.tar\.gz//' | sort -V | tail -n 1)
            if [ -z "${tag}" ]; then
                exit 1
            fi
            echo "${tag}"
        else
            exit 1
        fi
        ;;
    *)
        echo "[ERROR] Unknown upstream type: ${TYPE}" >&2
        exit 1
        ;;
esac
