#!/bin/bash
set -euo pipefail

echo "[TEST] Verifying CI variable injection..."

# Mock job script
cat <<'SCRIPT' > /tmp/test_job.sh
if [ -z "${CI_PIMELEON_APPS_PUSH_TOKEN:-}" ]; then
  echo "Token missing"
  exit 1
fi
echo "Token found"
SCRIPT
chmod +x /tmp/test_job.sh

# Run with token as env var
if CI_PIMELEON_APPS_PUSH_TOKEN="test-token" /tmp/test_job.sh | grep -q "Token found"; then
  echo "  [+] Success: Environment variable correctly injected."
else
  echo "  [-] Failure: Environment variable missing."
  exit 1
fi

rm /tmp/test_job.sh
