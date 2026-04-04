#!/bin/bash
# scripts/check-upstream.sh — query GitHub or GitLab API for latest release/tag version
# Usage: check-upstream.sh <repo> <type> [host] [tag_prefix]
# Outputs: clean version string (prefix stripped), or empty on failure
#
# type: "github_release" | "gitlab_tag"
# host: only used for gitlab_tag (default: gitlab.com)

set -euxo pipefail

REPO="${1:?repo required}"
TYPE="${2:?type required}"
UPSTREAM_GITLAB_HOST="${3:-gitlab.com}"
TAG_PREFIX="${4:-}"
# Optional: regex pattern that tag names (after prefix strip) must match. Empty = accept all.
TAG_PATTERN="${5:-}"

query_with_retry() {
    local url="$1"
    local out
    for attempt in 1 2; do
        if out=$(curl -fsSL --max-time 15 "$url" 2>/dev/null); then
            echo "$out"
            return 0
        fi
        local http_code
        http_code=$(curl -o /dev/null -sw '%{http_code}' --max-time 15 "$url" 2>/dev/null || echo "0")
        if [[ "$http_code" == "429" ]] && [[ "$attempt" -eq 1 ]]; then
            echo "[WARN] Rate limited by upstream API, retrying in 5s..." >&2
            sleep 5
            continue
        fi
        echo "[WARN] Failed to query $url (HTTP ${http_code})" >&2
        return 1
    done
    return 1
}

case "${TYPE}" in
    github|github_release)
        raw=$(query_with_retry "https://api.github.com/repos/${REPO}/releases/latest") || exit 1
        tag=$(echo "$raw" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null)
        if [ -z "${tag}" ]; then
            exit 1
        fi
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    github_tag)
        raw=$(query_with_retry "https://api.github.com/repos/${REPO}/tags?per_page=1") || exit 1
        tag=$(echo "$raw" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data[0].get('name','') if data else '')" 2>/dev/null)
        if [ -z "${tag}" ]; then
            exit 1
        fi
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    gitlab_tag)
        encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote('${REPO}', safe=''))")
        raw=$(query_with_retry \
            "https://${UPSTREAM_GITLAB_HOST}/api/v4/projects/${encoded}/repository/tags?order_by=version&per_page=5") \
            || exit 1
        # Pick first tag matching prefix and optional stable pattern
        tag=$(echo "$raw" | python3 -c "import json, sys, re; data = json.load(sys.stdin); prefix = '${TAG_PREFIX}'; pattern = '${TAG_PATTERN}'; print(next((t.get('name', '') for t in data if (not prefix or t.get('name', '').startswith(prefix)) and (not pattern or re.match(pattern, t.get('name', '')[len(prefix):]))), ''))" 2>/dev/null)
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
