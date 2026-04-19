#!/bin/bash
set -euo pipefail

# Prep PATH to use our mock curl
export PATH="$(pwd)/tests/integration:$PATH"

echo "[INTEGRATION] Testing check-upstream.sh with real-world hostapd response..."

# Execute script with mocked curl
# We point the repository to w1.fi/releases/ to trigger the listing logic
VERSION=$(bash scripts/check-upstream.sh "w1.fi/releases/" "http_tarball" "" "" "")

if [[ "$VERSION" == "2.11" ]]; then
    echo "  [+] Success: Version resolved to $VERSION"
else
    echo "  [-] Failure: Expected 2.11, got '$VERSION'"
    exit 1
fi
