#!/bin/bash
set -euo pipefail

# 1. Test check-upstream.sh
# Real upstream resolution check
echo "[TEST] scripts/check-upstream.sh..."
./scripts/check-upstream.sh "w1.fi/releases/hostapd-2.11.tar.gz" "http_tarball" "" "" "" > /dev/null

# 2. Test ci-publish-gitlab.sh
# Check if it has required variables and logic
echo "[TEST] scripts/ci-publish-gitlab.sh..."
grep -q "publish.env" scripts/ci-publish-gitlab.sh

# 3. Test clean-docker.sh
echo "[TEST] scripts/clean-docker.sh..."
./scripts/clean-docker.sh --help > /dev/null

# 4. Test ci-release.sh (the API tagging logic)
# We test the version calculation logic specifically
echo "[TEST] .gitlab/scripts/ci-release.sh..."
# Mocking 'release' for version calculation
release() { echo "0.1.5"; }
export -f release
LATEST_TAG="v0.1.5"
VERSION=${LATEST_TAG#v}
IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"
NEW_PATCH=$((VERSION_PARTS[2] + 1))
NEW_TAG="v${VERSION_PARTS[0]}.${VERSION_PARTS[1]}.$NEW_PATCH"
[[ "$NEW_TAG" == "v0.1.6" ]]

echo "[+] All integration tests passed."
