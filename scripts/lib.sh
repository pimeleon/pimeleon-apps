#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../.env" ]]; then
    # shellcheck source=../.env
    source "${SCRIPT_DIR}/../.env"
fi

query_with_retry() {
    local url="$1"
    local -a curl_args=(-fsSL --max-time 15)

    # GitHub API — optional Bearer token raises rate limit from 60 to 5000 req/h
    if [[ "$url" == *"api.github.com"* ]]; then
        [[ -n "${GITHUB_TOKEN:-}" ]] && curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
        curl_args+=(-H "X-GitHub-Api-Version: 2022-11-28")
    # GitLab API (any host, matched by path)
    elif [[ "$url" == *"/api/v4/"* ]]; then
        [[ -n "${GITLAB_FETCH_TOKEN:-}" ]] && curl_args+=(-H "PRIVATE-TOKEN: ${GITLAB_FETCH_TOKEN}")
        curl_args+=(-k)  # tolerate self-signed certs on local GitLab instances
    fi

    local out
    for attempt in 1 2; do
        if out=$(curl "${curl_args[@]}" "$url" 2>/dev/null); then
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
