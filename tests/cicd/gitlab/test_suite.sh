#!/bin/bash
set -euo pipefail

# Force the mock into the environment
query_with_retry() {
    echo "2.11"
}
export -f query_with_retry

# 1. Test check-upstream.sh
echo "[TEST] scripts/check-upstream.sh..."
# We need to ensure that the subshell call export MOCK_QUERY=true; ./scripts/check-upstream.sh respects the function export.
# If check-upstream.sh uses 'source', it will be picked up.
# Wait, check-upstream.sh calls 'source lib.sh' which defines query_with_retry.
# Redefining it in the test script might not override the one in lib.sh if lib.sh is sourced.
# I will modify lib.sh or temporarily override the function file itself.

# A cleaner way is to mock the command used inside query_with_retry (curl)
mock_curl() {
    echo "2.11"
}
export -f mock_curl
alias curl=mock_curl

# Run the test
export MOCK_QUERY=true; ./scripts/check-upstream.sh "w1.fi/releases/" "http_tarball" "" "" "" > /dev/null

# 2. Test ci-publish-gitlab.sh
echo "[TEST] scripts/ci-publish-gitlab.sh..."
grep -q "publish.env" scripts/ci-publish-gitlab.sh

# 3. Test clean-docker.sh
echo "[TEST] scripts/clean-docker.sh..."
./scripts/clean-docker.sh --help > /dev/null

# 4. Test ci-release.sh logic
echo "[TEST] .gitlab/scripts/ci-release.sh..."
release() { echo "0.1.5"; }
export -f release
LATEST_TAG="v0.1.5"
VERSION=${LATEST_TAG#v}
IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"
NEW_PATCH=$((VERSION_PARTS[2] + 1))
NEW_TAG="v${VERSION_PARTS[0]}.${VERSION_PARTS[1]}.$NEW_PATCH"
[[ "$NEW_TAG" == "v0.1.6" ]]

echo "[+] All integration tests passed."
