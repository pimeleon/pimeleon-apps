#!/bin/bash
set -euo pipefail

if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env
fi

: "${CI_PIMELEON_APPS_PUSH_TOKEN:?CI_PIMELEON_APPS_PUSH_TOKEN must be set in .env}"

APT_PROXY="${APT_PROXY:-192.168.76.5:3142}"

docker run --rm \
  -v "$(pwd):/app" \
  -w /app \
  --network host \
  -e APT_PROXY="${APT_PROXY}" \
  -e GITLAB_URL="https://gitlab.pirouter.dev/api/v4" \
  -e CI_PROJECT_ID="20" \
  -e CI_PROJECT_PATH="pimeleon/pi-router-apps" \
  -e GL_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
  -e CI_PIMELEON_APPS_PUSH_TOKEN="${CI_PIMELEON_APPS_PUSH_TOKEN}" \
  -e CI_COMMIT_SHA="$(git rev-parse HEAD)" \
  -e CI_COMMIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)" \
  -e GIT_SSL_NO_VERIFY="1" \
  -e GSG_MINOR_COMMIT_TYPES="feat,perf" \
  -e GSG_PATCH_COMMIT_TYPES="fix" \
  registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1 \
  /bin/sh -c "
set -eu
echo 'Acquire::http::Proxy \"http://${APT_PROXY}/\";' > /etc/apt/apt.conf.d/01proxy
echo 'deb http://archive.debian.org/debian buster main' > /etc/apt/sources.list
echo 'deb http://archive.debian.org/debian-security buster/updates main' >> /etc/apt/sources.list
apt-get update -qq 2>&1 | tail -1
DEBIAN_FRONTEND=noninteractive apt-get install -qq -y bash git jq curl > /dev/null 2>&1
touch /tmp/MOCK_QUERY
./tests/cicd/gitlab/test_suite.sh
rm /tmp/MOCK_QUERY
"
