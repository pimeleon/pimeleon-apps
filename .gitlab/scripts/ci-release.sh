#!/usr/bin/env sh
set -e

echo "Calculating next production version..."
NEXT_VERSION=$(release --skip-ssl-verify next-version --allow-current)
echo "Next version - ${NEXT_VERSION}"

if [ -n "$NEXT_VERSION" ]; then
  echo "Creating release tag v${NEXT_VERSION}..."
  if ! release --skip-ssl-verify tag 2>&1 | tee /tmp/release.log; then
    if grep -q "no changes found" /tmp/release.log; then
      echo "No releasable changes - skipping tag"
    else
      cat /tmp/release.log
      exit 1
    fi
  fi
else
  echo "No version bump needed"
fi
