#!/bin/bash
# Local App Runner/Tester for pi-router-apps
set -euo pipefail

# Available packages list
PACKAGES=("dnscrypt-proxy" "hostapd" "pihole-FTL" "privoxy" "tor" "wpa_supplicant")

show_help() {
    cat << EOF
Usage: $(basename "$0") <package_name>

Run/test a compiled package in an ARM container using qemu-arm-static.

Arguments:
  package_name    One of: ${PACKAGES[*]}

Options:
  -h, --help      Show this help message and exit

Examples:
  $(basename "$0") tor
  $(basename "$0") pihole-FTL
EOF
}

# Handle help flags
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

PACKAGE=${1:-}

if [[ -z "$PACKAGE" ]]; then
    echo "Error: Package name is required."
    show_help
    exit 1
fi

echo "Running $PACKAGE in ARM container..."
# Logic to run the compiled binary via qemu-arm-static container
