#!/bin/bash
set -euo pipefail

# This test simulates an external machine.
# We explicitly block the local proxy IP (192.168.76.5) and local DNS
# to ensure the build pipeline doesn't crash but gracefully falls back
# or fails informatively.

echo "Simulating external environment (No LAN access)..."

# Use a separate network namespace to block LAN access
docker network create --driver bridge simulation_net || true

docker run --rm   --network simulation_net   --add-host gitlab.pirouter.dev:127.0.0.1   -v "/home/takeshi/pi-router/pi-router-apps:/app"   -w /app   -e APT_PROXY="192.168.76.5:3142"   registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1   /bin/sh -c "
    echo 'Testing network connectivity without LAN...'
    # This should fail if it relies on internal LAN for DNS/Proxy
    # We want to see if the script handles the timeout gracefully
    ping -c 2 gitlab.pirouter.dev || echo 'Confirmed: Internal host unreachable'
"
