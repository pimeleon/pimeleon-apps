#!/bin/bash
set -euo pipefail

# Load environment from .env file
if [[ -f .env ]]; then
    source .env
fi

# Mock environment using variables from .env
export GITLAB_URL="https://gitlab.pirouter.dev/api/v4"
export GSG_TOKEN="${GITLAB_TOKEN}"
export CI_PROJECT_ID="20"
export CI_COMMIT_SHA="$(git rev-parse HEAD)"

# Mock the release binary
release() { echo "0.1.5"; }
export -f release

# Mock curl: return a success code without printing everything
curl() { echo "201"; }
export -f curl

# Capture output
OUTPUT=$(bash .gitlab/scripts/ci-release.sh)
echo "$OUTPUT"

# Verify logic: 0.1.5 -> 0.1.6
if echo "$OUTPUT" | grep -q "Successfully created tag"; then
    echo "[+] SUCCESS"
else
    echo "[-] FAILURE"
    exit 1
fi
