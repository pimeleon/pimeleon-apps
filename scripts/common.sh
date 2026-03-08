#!/bin/bash
# scripts/common.sh — shared helpers for build and check scripts

set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
die()      { echo "[ERROR] $*" >&2; exit 1; }

# Install packages via apt-get with optional proxy
apt_install() {
    local args=()
    if [[ -n "${APT_CACHE_SERVER:-}" ]]; then
        args+=(-o "Acquire::http::Proxy=http://${APT_CACHE_SERVER}:${APT_CACHE_PORT:-3142}")
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
        "${args[@]}" "$@"
}

# Strip a version prefix from a raw upstream tag (e.g. "tor-0.4.8.21" -> "0.4.8.21")
strip_version_prefix() {
    local raw="$1" prefix="${2:-}"
    echo "${raw#"${prefix}"}"
}
