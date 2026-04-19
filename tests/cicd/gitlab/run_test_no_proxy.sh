#!/bin/bash
set -euo pipefail

# This script simulates a build environment where the LAN proxy is unavailable.
# It sets a dead-end IP for the proxy to verify build failure when proxy configuration is invalid.

export APT_PROXY="10.255.255.1:3142"

echo "Simulating build environment without valid LAN proxy..."

docker run --rm \
  -v "$(pwd):/app" \
  -w /app \
  -e APT_PROXY="$APT_PROXY" \
  registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1 \
  /bin/sh -c "
    echo 'Acquire::http::Proxy \"http://'"$APT_PROXY"'/\";' > /etc/apt/apt.conf.d/01proxy
    echo 'deb http://archive.debian.org/debian buster main' > /etc/apt/sources.list

    # This should timeout or fail if it actually tries to use the invalid proxy
    apt-get update -o Acquire::http::Proxy='http://'"$APT_PROXY"'/';
"
