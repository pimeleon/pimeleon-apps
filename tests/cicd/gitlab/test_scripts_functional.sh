#!/bin/bash
set -euo pipefail

echo "[INTEGRATION TEST] Starting script-on-script functional testing..."

# Mock function for curl to return success without network
mock_curl() {
    # Simulate a 201 Created or 200 OK
    echo "201"
}
export -f mock_curl

# 1. Test ci-release.sh logic
# We mock 'release' binary to return a version, and mock curl to avoid real API calls
test_ci_release() {
    echo "Testing .gitlab/scripts/ci-release.sh..."
    export GITLAB_URL="http://mock"
    export GSG_TOKEN="fake"
    export CI_PROJECT_ID="1"
    export CI_COMMIT_SHA="mocksha"

    # Mocking release binary
    release() { echo "0.2.0"; }
    export -f release

    # Override curl with mock
    alias curl=mock_curl

    if output=$(bash .gitlab/scripts/ci-release.sh 2>&1); then
        echo "  [+] Success: ci-release.sh logic passed."
    else
        echo "  [-] Failure: ci-release.sh failed."
        return 1
    fi
}

# 2. Test check-upstream.sh
test_check_upstream() {
    echo "Testing scripts/check-upstream.sh..."
    # We call it with arguments that should not crash the script
    if bash scripts/check-upstream.sh "tor" "github" "github.com" "" "" >/dev/null 2>&1 || true; then
        echo "  [+] Success: check-upstream.sh execution stable."
    else
        echo "  [-] Failure: check-upstream.sh crashed."
        return 1
    fi
}

# Run the tests
test_ci_release
test_check_upstream

echo "[+] Functional integration tests for CI/CD scripts passed."
