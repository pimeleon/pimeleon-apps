#!/bin/bash
set -euo pipefail

echo "[INTEGRATION] Validating real-world upstream resolution..."

# Define a real target known to work
REPO="w1.fi/releases/hostapd-2.11.tar.gz"
TYPE="http_tarball"

# Execute real script logic
VERSION=$(bash scripts/check-upstream.sh "$REPO" "$TYPE" "" "" "")

# Validate the output
if [[ "$VERSION" == "2.11" ]]; then
    echo "  [+] Success: Real resolution for hostapd returned $VERSION"
else
    echo "  [-] Failure: Expected 2.11, but got '$VERSION'"
    exit 1
fi
