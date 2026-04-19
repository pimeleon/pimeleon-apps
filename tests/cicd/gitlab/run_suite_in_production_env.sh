#!/bin/bash
set -euo pipefail

# Pull and use the production image, but we need to ensure it has the tools to run the test suite.
# Since it's a minimal image, we might need to install bash and git first.

docker run --rm -v "/home/takeshi/pi-router/pi-router-apps:/app" -w /app registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1 /bin/sh -c "
  # Install necessary tools for tests
  echo 'deb http://archive.debian.org/debian buster main' > /etc/apt/sources.list
  echo 'deb http://archive.debian.org/debian-security buster/updates main' >> /etc/apt/sources.list
  apt-get update -o Acquire::http::Proxy=http://192.168.76.5:3142/
  apt-get install -y bash git jq -o Acquire::http::Proxy=http://192.168.76.5:3142/

  # Run the test suite
  ./tests/cicd/gitlab/test_suite.sh
"
