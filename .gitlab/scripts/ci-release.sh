#!/bin/bash
set -euo pipefail

# Calculate version based on latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.1.3")
VERSION=${LATEST_TAG#v}
IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"
NEW_PATCH=$((VERSION_PARTS[2] + 1))
NEW_TAG="v${VERSION_PARTS[0]}.${VERSION_PARTS[1]}.$NEW_PATCH"

echo "Creating tag ${NEW_TAG} via API..."

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "PRIVATE-TOKEN: ${GSG_TOKEN}" \
  "${GITLAB_URL}/projects/${CI_PROJECT_ID}/repository/tags?tag_name=${NEW_TAG}&ref=master")

if [ "$RESPONSE" -eq 201 ]; then
  echo "Successfully created tag ${NEW_TAG}"
elif [ "$RESPONSE" -eq 409 ]; then
  echo "Tag ${NEW_TAG} already exists"
else
  echo "Failed to create tag (HTTP $RESPONSE)"
  exit 1
fi
