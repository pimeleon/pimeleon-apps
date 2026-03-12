#!/bin/bash
# scripts/check-upstream.sh — query GitHub or GitLab API for latest release/tag version
# Usage: check-upstream.sh <repo> <type> [host] [tag_prefix]
# Outputs: clean version string (prefix stripped), or empty on failure
#
# type: "github_release" | "gitlab_tag"
# host: only used for gitlab_tag (default: gitlab.com)

set -euo pipefail

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
    github_release)
        raw=$(query_with_retry "https://api.github.com/repos/${REPO}/releases/latest") || exit 0
        tag=$(echo "$raw" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null)
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    gitlab_tag)
        encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote('${REPO}', safe=''))")
        raw=$(query_with_retry \
            "https://${UPSTREAM_GITLAB_HOST}/api/v4/projects/${encoded}/repository/tags?order_by=version&per_page=5") \
            || exit 0
        # Pick first tag matching prefix and optional stable pattern
        tag=$(echo "$raw" | python3 -c "import json, sys, re; data = json.load(sys.stdin); prefix = '${TAG_PREFIX}'; pattern = '${TAG_PATTERN}'; print(next((t.get('name', '') for t in data if (not prefix or t.get('name', '').startswith(prefix)) and (not pattern or re.match(pattern, t.get('name', '')[len(prefix):]))), ''))" 2>/dev/null)
        echo "${tag#"${TAG_PREFIX}"}"
        ;;
    *)
        echo "[ERROR] Unknown upstream type: ${TYPE}" >&2
        exit 1
        ;;
esac
