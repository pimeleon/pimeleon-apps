#!/bin/bash
# Pimeleon App Factory - Selective Docker Cleanup
# Optimized for individual package builds and registry management

set -euxo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

echo -e "${BLUE}⌛ Pimeleon App Factory - Selective Docker Cleanup${NC}"
echo "============================================================"

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Defaults
PRESERVE_CACHE=true
PRESERVE_VOLUMES=true
CLEAN_MOUNTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --full) PRESERVE_CACHE=false; PRESERVE_VOLUMES=false; CLEAN_MOUNTS=true; shift ;;
        --clean-mounts) CLEAN_MOUNTS=true; shift ;;
        --no-cache) PRESERVE_CACHE=false; shift ;;
        --no-volumes) PRESERVE_VOLUMES=false; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --full           Full cleanup (removes everything)"
            echo "  --clean-mounts   Clean up stale /tmp/build mounts and loop devices"
            echo "  --no-cache       Remove local cache directory"
            echo "  --no-volumes     Remove Docker volumes"
            exit 0
            ;;
        *) print_error "Unknown option: $1"; exit 1 ;;
    esac
done

# 1. Handle mount cleanup (Critical for Ctrl+C recovery)
if [[ "$CLEAN_MOUNTS" == "true" ]]; then
    print_warning "Checking for stale mounts and loop devices..."

    # Unmount anything under /tmp/build (in reverse order)
    STALE_MOUNTS=$(mount | grep -E "/tmp/build|pimeleon" | awk '{print $3}' | sort -r || true)
    if [[ -n "$STALE_MOUNTS" ]]; then
        for mnt in $STALE_MOUNTS; do
            print_info "Unmounting $mnt..."
            umount -l "$mnt" 2>/dev/null || true
        done
    fi

    # Detach pimeleon loop devices
    STALE_LOOPS=$(losetup -l -n -O NAME,BACK-FILE 2>/dev/null | grep -E "pimeleon|/tmp/build" | awk '{print $1}' || true)
    if [[ -n "$STALE_LOOPS" ]]; then
        for loop in $STALE_LOOPS; do
            print_info "Detaching loop device $loop..."
            kpartx -d "$loop" 2>/dev/null || true
            losetup -d "$loop" 2>/dev/null || true
        done
    fi

    # Clean up partial images/tarballs
    print_info "Cleaning up potential partial artifacts..."
    find ./output -name "*.tar.gz" -mmin -15 -delete 2>/dev/null || true
    find ./output -name "*.img" -mmin -15 -delete 2>/dev/null || true
fi

# 2. Stop Docker resources
print_info "Stopping active containers..."
docker compose down 2>/dev/null || true

if [[ "$PRESERVE_CACHE" == "false" ]]; then
    print_warning "Removing local cache directory..."
    rm -rf ./cache/*
fi

if [[ "$PRESERVE_VOLUMES" == "false" ]]; then
    print_warning "Removing all Docker volumes..."
    docker volume prune -af
fi

print_success "Cleanup completed!"
