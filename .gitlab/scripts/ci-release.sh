#!/usr/bin/env sh
set -e

if [ -z "${GSG_TOKEN:-}" ]; then
  echo "[ERROR] GSG_TOKEN is not set — cannot authenticate with GitLab API" >&2
  exit 1
fi

echo "GITLAB_URL: ${GITLAB_URL:-not set}"
echo "GSG_TOKEN:  ${GSG_TOKEN}"
echo ""
echo "Calculating next production version..."
NEXT_VERSION=$(release --skip-ssl-verify next-version --allow-current)
echo "Next version - ${NEXT_VERSION}"

if [ -n "$NEXT_VERSION" ]; then
  echo "Creating production tag v${NEXT_VERSION}..."
  release --skip-ssl-verify tag > /tmp/release.log 2>&1 && RC=0 || RC=$?
  cat /tmp/release.log
  if [ $RC -ne 0 ]; then
    if grep -q "no changes found" /tmp/release.log; then
      echo "No releasable changes - skipping tag"
    else
      exit 1
    fi
  fi
else
  echo "No version bump needed"
fi
