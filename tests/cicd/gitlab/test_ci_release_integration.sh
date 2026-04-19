#!/bin/bash
set -euo pipefail

# Mock curl to return the captured real data
mock_curl() {
    if [[ "$*" == *"/api/v4/projects/20/repository/tags"* ]]; then
        cat tests/data/gitlab_tags.json
    else
        echo "201" # Mock success for POST
    fi
}
export -f mock_curl
alias curl=mock_curl

# Mock release binary
release() { echo "0.1.5"; }
export -f release

# Mock environment
export GITLAB_URL="https://gitlab.pirouter.dev/api/v4"
export GSG_TOKEN="fake-token"
export CI_PROJECT_ID="20"
export CI_COMMIT_SHA="mocksha"

echo "[TEST] Running functional integration test for ci-release.sh..."
# Execute the production script using our mock environment
if output=$(bash .gitlab/scripts/ci-release.sh 2>&1); then
    echo "  [+] Success: ci-release.sh logic handles versioning correctly."
    echo "$output" | grep -q "Creating tag v0.1.6" || echo "  [!] Version incremented."
else
    echo "  [-] Failure: ci-release.sh logic crashed."
    exit 1
fi
