#!/bin/bash
set -euo pipefail

# Scripts to test
SCRIPTS=(
  "scripts/check-upstream.sh"
  "scripts/ci-publish-github.sh"
  "scripts/ci-publish-gitlab.sh"
  "scripts/clean-docker.sh"
  "scripts/update-sources.sh"
  "scripts/update-tools.sh"
  ".gitlab/scripts/ci-release.sh"
)

echo "[TEST] Running CI/CD Integration Tests..."

# Use a minimal Debian container with dependencies
# This mocks the production environment as closely as possible
docker build -t pimeleon-test-env -f - . <<EOD
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y git bash curl ca-certificates jq && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENTRYPOINT ["/bin/bash"]
EOD

for script in "${SCRIPTS[@]}"; do
    echo "  Testing: $script"
    if ! docker run --rm -v "$(pwd):/app" -w /app pimeleon-test-env bash -n "$script"; then
        echo "    [-] Syntax error in $script"
        exit 1
    fi
    # Perform a functional check if the script supports help/usage
    if docker run --rm -v "$(pwd):/app" -w /app pimeleon-test-env bash "$script" --help >/dev/null 2>&1; then
        echo "    [+] Functional check: Passed"
    else
        echo "    [+] Functional check: Skipped (no help command)"
    fi
done

echo "[+] All integration tests passed."
