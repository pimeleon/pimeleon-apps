#!/bin/bash
set -euo pipefail

# Load environment from .env file
if [[ -f .env ]]; then
    source .env
fi

# Define environment variables
export APT_PROXY="192.168.76.5:3142"
export GITLAB_URL="https://gitlab.pirouter.dev/api/v4"
export CI_PROJECT_ID="20"
export GSG_TOKEN="${GITLAB_TOKEN}"
export CI_COMMIT_SHA="$(git rev-parse HEAD)"

# Run inside the production image environment
docker run --rm   -v "$(pwd):/app"   -w /app   -e APT_PROXY="$APT_PROXY"   -e GITLAB_URL="$GITLAB_URL"   -e CI_PROJECT_ID="$CI_PROJECT_ID"   -e GSG_TOKEN="$GSG_TOKEN"   -e CI_COMMIT_SHA="$CI_COMMIT_SHA"   registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1   /bin/sh -c "
    echo 'Acquire::http::Proxy \"http://$APT_PROXY/\";' > /etc/apt/apt.conf.d/01proxy
    echo 'deb http://archive.debian.org/debian buster main' > /etc/apt/sources.list
    echo 'deb http://archive.debian.org/debian-security buster/updates main' >> /etc/apt/sources.list
    apt-get update
    apt-get install -qy bash git jq
    ./tests/cicd/gitlab/test_suite.sh
"
