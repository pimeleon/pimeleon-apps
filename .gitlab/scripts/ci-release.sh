#!/bin/bash
set -euo pipefail

# Use the go-semrel-gitlab CLI to handle release tagging
echo "Calculating next version via go-semrel-gitlab..."

# --skip-ssl-verify mirrors the configuration in .gitlab/ci/publish.yml
if release --skip-ssl-verify tag; then
  echo "Successfully created tag"
else
  echo "Release failed"
  exit 1
fi
