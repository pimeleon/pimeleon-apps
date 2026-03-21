#!/bin/bash
# Pimeleon Tools Downloader (Registry-Aware)
set -euo pipefail

CACHE_DIR="${CACHE_DIR:-cache}"
TOOLS_FILE="versions/tools.yml"
mkdir -p "${CACHE_DIR}/tools"

# Get Go version
GO_VER=$(grep "go:" "$TOOLS_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
GO_TARBALL="go${GO_VER}.linux-amd64.tar.gz"
LOCAL_PATH="${CACHE_DIR}/tools/${GO_TARBALL}"

# Clean up old Go versions to avoid Docker COPY issues with globbing
find "${CACHE_DIR}/tools" -name "go*.tar.gz" ! -name "${GO_TARBALL}" -type f -exec rm -f {} +

# Registry Config
PROJECT_ID="20"  # pi-router-apps project
REGISTRY_URL="https://gitlab.pirouter.dev/api/v4/projects/${PROJECT_ID}/packages/generic/build-tools/${GO_VER}/${GO_TARBALL}"

if [[ -f "$LOCAL_PATH" ]]; then
    echo "[INFO] Go ${GO_VER} found in local cache."
    exit 0
fi

# Attempt Registry Download (if in CI)
if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
    echo "[INFO] Attempting to fetch Go from local GitLab registry..."
    if curl -fsSL -k -H "JOB-TOKEN: ${CI_JOB_TOKEN}" -o "$LOCAL_PATH" "$REGISTRY_URL"; then
        echo "[SUCCESS] Go ${GO_VER} fetched from registry."
        exit 0
    fi
fi

# Fallback to Upstream
echo "[WARN] Go not found in registry. Downloading from upstream go.dev..."
GO_URL="https://go.dev/dl/${GO_TARBALL}"
curl -fsSL -o "$LOCAL_PATH" "$GO_URL"

# Upload back to registry if in CI (to seed it for next time)
if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
    echo "[INFO] Seeding registry with Go ${GO_VER}..."
    curl -sSL -k --header "JOB-TOKEN: ${CI_JOB_TOKEN}" --upload-file "$LOCAL_PATH" "$REGISTRY_URL"
fi
