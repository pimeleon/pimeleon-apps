#!/bin/bash
set -euo pipefail

# Load environment from .env file
if [[ -f .env ]]; then
    source .env
fi

# Ensure mandatory variables exist
: "${GITLAB_TOKEN:?GITLAB_TOKEN must be set in .env}"

# Run inside the production image environment with all variables
docker run --rm   -v "$(pwd):/app"   -w /app   -e APT_PROXY="192.168.76.5:3142"   -e GITLAB_URL="https://gitlab.pirouter.dev/api/v4"   -e CI_PROJECT_ID="20"   -e GSG_TOKEN="$GITLAB_TOKEN"   -e CI_COMMIT_SHA="$(git rev-parse HEAD)"   registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1   /bin/sh -c "
    echo 'Acquire::http::Proxy \"http://192.168.76.5:3142/\";' > /etc/apt/apt.conf.d/01proxy
    echo 'deb http://archive.debian.org/debian buster main' > /etc/apt/sources.list
    echo 'deb http://archive.debian.org/debian-security buster/updates main' >> /etc/apt/sources.list
    apt-get update
    apt-get install -qy bash git jq
    touch /tmp/MOCK_QUERY
    ./tests/cicd/gitlab/test_suite.sh
    rm /tmp/MOCK_QUERY
"
