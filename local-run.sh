#!/bin/bash
# Local App Runner/Tester for pi-router-apps
set -euo pipefail

PACKAGE=${1:-}

if [[ -z "$PACKAGE" ]]; then
    echo "Usage: $0 <package_name>"
    exit 1
fi

echo "Running $PACKAGE in ARM container..."
# Logic to run the compiled binary via qemu-arm-static container
