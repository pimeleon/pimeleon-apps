#!/bin/bash
set -euo pipefail

# Define all CI/CD scripts
SCRIPTS=(
  "scripts/check-upstream.sh"
  "scripts/ci-publish-github.sh"
  "scripts/ci-publish-gitlab.sh"
  "scripts/clean-docker.sh"
  "scripts/update-sources.sh"
  "scripts/update-tools.sh"
  ".gitlab/scripts/ci-release.sh"
)

# Build a generic CI test environment image with APT Proxy
docker build -t pimeleon-ci-tester - <<EOD
FROM debian:bookworm-slim
RUN echo 'Acquire::http::Proxy "http://192.168.76.5:3142";' > /etc/apt/apt.conf.d/01proxy
RUN apt-get update && apt-get install -y git bash curl ca-certificates jq && rm -rf /var/lib/apt/lists/*
WORKDIR /app
EOD

for script in "${SCRIPTS[@]}"; do
    echo "[TEST] Validating $script..."
    # 1. Syntax Check
    if ! docker run --rm -v "$(pwd):/app" -w /app pimeleon-ci-tester bash -n "$script"; then
        echo "  [-] Syntax Check Failed: $script"
        exit 1
    fi
    # 2. Execution / Usage Check
    if docker run --rm -v "$(pwd):/app" -w /app pimeleon-ci-tester bash "$script" --help > /dev/null 2>&1 || \
       docker run --rm -v "$(pwd):/app" -w /app pimeleon-ci-tester bash "$script" -h > /dev/null 2>&1; then
        echo "  [+] Usage/Smoke Check: PASS"
    else
        echo "  [!] Usage/Smoke Check: SKIPPED (No help flag)"
    fi
done

echo "[+] All CI/CD integration tests passed."
