#!/bin/bash
# Common functions for Pimeleon build scripts
set -E
# Ensure a robust system path is available to all scripts
export PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

SUDO=""
# if command -v sudo >/dev/null 2>&1; then
#     SUDO="sudo"
# fi

# Project name for cache keys and output naming
PIMELEON_PROJECT_NAME="${PIMELEON_PROJECT_NAME:-pimeleon}"

# Ownership configuration
PIMELEON_USER="${PIMELEON_USER:-$(/usr/bin/id -u 2>/dev/null || echo 0)}"
PIMELEON_GROUP="${PIMELEON_GROUP:-docker}"
# Support APT_PROXY environment variable (e.g., 192.168.76.5:3142)
if [[ -n "${APT_PROXY:-}" ]]; then
    export APT_CACHE_SERVER="${APT_PROXY%:*}"
    export APT_CACHE_PORT="${APT_PROXY##*:}"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_section() {
    echo -e "\n${BLUE}==>${NC} $*"
}

# Error handling
die() {
    log_error "$*"
    exit 1
}

# Global cleanup tracking
CLEANUP_MOUNT_POINT="${CLEANUP_MOUNT_POINT:-}"
CLEANUP_LOOP_DEVICE="${CLEANUP_LOOP_DEVICE:-}"
CLEANUP_CHROOT_ACTIVE="${CLEANUP_CHROOT_ACTIVE:-false}"
CLEANUP_IMAGE_PATH="${CLEANUP_IMAGE_PATH:-}"
declare -a MOUNT_STACK=()

# Safe remove helper - prevents accidental deletion outside build directory
safe_rm() {
    local work_dir_base="/tmp/build"
    local output_dir_base="/output"
    local local_build_dir
    local_build_dir="$(pwd)/build"
    local local_output_dir
    local_output_dir="$(pwd)/output"

    if [[ $# -eq 0 ]]; then
        log_warn "safe_rm: no paths provided, ignoring"
        return
    fi

    for path in "$@"; do
        if [[ -z "$path" ]]; then
            continue
        fi

        # Resolve relative paths to absolute for check
        local abs_path
        abs_path=$(realpath -m "$path" 2>/dev/null || echo "$path")

        # Only allow deletion within sanctioned directories
        if [[ "$abs_path" == "${work_dir_base}"* ]] || \
           [[ "$abs_path" == "${local_build_dir}"* ]] || \
           [[ "$abs_path" == "${output_dir_base}"* ]] || \
           [[ "$abs_path" == "${local_output_dir}"* ]] || \
           [[ -n "${WORK_DIR:-}" && "$abs_path" == "${WORK_DIR}"* ]] || \
           [[ -n "${OUTPUT_DIR:-}" && "$abs_path" == "${OUTPUT_DIR}"* ]]; then

            # Proactively find and unmount any sub-mounts under this path
            # Only if path is a directory
            if [[ -d "$path" ]]; then
                local nested_mounts
                nested_mounts=$(findmnt -n -o TARGET -R "$path" 2>/dev/null | sort -r || true)
                if [[ -n "$nested_mounts" ]]; then
                    log_warn "safe_rm: Found active mounts under $path, unmounting..."
                    for mnt in $nested_mounts; do
                        ${SUDO} umount "$mnt" 2>/dev/null || ${SUDO} umount -l "$mnt" 2>/dev/null || true
                    done
                fi
            fi

            # We allow glob expansion here by not quoting $path in the final command
            # shellcheck disable=SC2086
            ${SUDO} rm -rf $path
        else
            die "CRITICAL: Attempted to delete path outside sanctioned directories: $path"
        fi
    done
}
# Track original PID to ensure only the main process runs cleanup
PIMELEON_MAIN_PID=$$

# Cleanup function for trap handlers
cleanup_on_exit() {
    local exit_code=$?
    # Only run cleanup in the main process
    if [[ $$ -ne $PIMELEON_MAIN_PID ]]; then
        return
    fi

    # Clear traps to prevent recursive calls during cleanup
    trap - EXIT ERR INT TERM
    set +e # Don't exit on error during cleanup

    # Comprehensive cleanup for 'all' mode at exit (success or failure)
    if [[ "${PACKAGE:-}" == "all" ]]; then
        log_warn "Cleaning up all build artifacts..."
        safe_rm build/* || true
    fi

    # On failure (non-zero exit code)
    if [[ $exit_code -ne 0 ]]; then
        if [[ $exit_code -eq 130 ]]; then
            log_warn "Build interrupted by user (Ctrl+C). Cleaning up..."
        elif [[ $exit_code -eq 143 ]]; then
            log_warn "Build terminated by signal (SIGTERM). Cleaning up..."
        else
            log_error "Failure detected (exit code: $exit_code). Cleaning up..."
        fi
    fi

    # Only cleanup if we have something to clean
    if [[ -n "$CLEANUP_MOUNT_POINT" ]] || [[ -n "$CLEANUP_LOOP_DEVICE" ]] || [[ ${#MOUNT_STACK[@]} -gt 0 ]]; then
        # Cleanup chroot first if active
        if [[ "$CLEANUP_CHROOT_ACTIVE" == "true" ]]; then
            log_info "Cleaning up chroot before exit..."
            cleanup_chroot "$CLEANUP_MOUNT_POINT" || true
        fi

        # Unmount image
        if [[ -n "$CLEANUP_MOUNT_POINT" ]] && [[ -n "$CLEANUP_LOOP_DEVICE" ]]; then
            log_info "Unmounting image and detaching loop device..."
            unmount_image "$CLEANUP_MOUNT_POINT" "$CLEANUP_LOOP_DEVICE" || true
        fi
    fi

    if [[ $exit_code -ne 0 ]]; then
        if [[ -n "${CURRENT_PKG:-}" ]]; then
            log_warn "Removing stalled build directory for ${CURRENT_PKG}..."
            safe_rm "build/build-${CURRENT_PKG}" || true
        fi
        if [[ -n "${LOG_FILE:-}" ]]; then
            log_info "Detailed build log: ${LOG_FILE}"
        fi
        if [[ -n "${CLEANUP_IMAGE_PATH:-}" ]]; then
            if [[ -f "$CLEANUP_IMAGE_PATH" ]]; then
                log_warn "Removing partial image: $CLEANUP_IMAGE_PATH"
                ${SUDO} rm -f "$CLEANUP_IMAGE_PATH" || true
                ${SUDO} rm -f "${CLEANUP_IMAGE_PATH}.xz" || true
                ${SUDO} rm -f "${CLEANUP_IMAGE_PATH}.sha256" || true
            fi
        fi
    fi

    # Exit with original code
    exit $exit_code
}

# Check if a service is enabled in the current profile
is_service_enabled() {
    local service_name=$1
    local ansible_dir="${ANSIBLE_DIR:-/ansible}"
    local profile_path="${ansible_dir}/vars/common/profiles/${PIMELEON_PROFILE:-development}.yml"

    if [[ ! -f "$profile_path" ]]; then
        die "FATAL: Profile file not found: $profile_path"
    fi

    # Use Python for robust YAML parsing (available in builder image)
    if python3 -c "import yaml; import os; profile = yaml.safe_load(open('$profile_path')) if os.path.exists('$profile_path') else {}; exit(0 if profile.get('services_enabled', {}).get('$service_name') == True else 1)" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if a service should be built from source in the current profile
is_build_from_source_enabled() {
    local service_name=$1
    local ansible_dir="${ANSIBLE_DIR:-/ansible}"
    local profile_path="${ansible_dir}/vars/common/profiles/${PIMELEON_PROFILE:-development}.yml"
    local versions_path="${ansible_dir}/vars/common/versions.yml"

    # Tor source build logic:
    # - Local: Build from source if PIMELEON_PROFILE=production
    # - CI: Build from source ONLY if PIMELEON_PROFILE=production AND (tagged release OR merged to release/*)
    if [[ "$service_name" == "tor" ]]; then
        if [[ "${PIMELEON_PROFILE:-}" == "production" ]]; then
            if [[ -n "${CI:-}" ]]; then
                # 1. Check for tagged release
                if [[ -n "${CI_COMMIT_TAG:-}" ]] || [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
                    return 0
                fi
                # 2. Check for release branch (current or merge target)
                if [[ "${CI_COMMIT_REF_NAME:-}" == release/* ]] || \
                   [[ "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}" == release/* ]] || \
                   [[ "${GITHUB_REF_NAME:-}" == release/* ]] || \
                   [[ "${GITHUB_BASE_REF:-}" == release/* ]]; then
                    return 0
                fi
                # CI but not a sanctioned release path -> use APT
                return 1
            fi
            # Local production build
            return 0
        fi
        # Development profile or other -> use APT
        return 1
    fi

    if [[ ! -f "$profile_path" ]]; then
        die "FATAL: Profile file not found: $profile_path"
    fi

    # Check profile first, then fallback to versions.yml
    if python3 -c "
import yaml
import sys
import os

def get_val(path, section, key):
    try:
        if not os.path.exists(path): return None
        with open(path, 'r') as f:
            data = yaml.safe_load(f)
            return data.get(section, {}).get(key)
    except Exception: return None

# Try profile override
val = get_val('$profile_path', 'build_from_source', '$service_name')
if val is not None: sys.exit(0 if val == True else 1)

# Fallback to versions.yml
val = get_val('$versions_path', 'build_from_source', '$service_name')
sys.exit(0 if val == True else 1)
" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if the build should use the APT cache proxy and persistent caches
should_use_apt_proxy() {
    [[ -n "${APT_CACHE_SERVER:-}" ]]
}

# Cleanup stale mounts from previous failed builds
cleanup_stale_mounts() {
    log_info "Checking for stale mounts from previous builds..."
    local work_dir_base="/tmp/build"

    # Find and unmount any work-dir related mounts (in reverse order for nested mounts)
    # Use || true to prevent script exit if no mounts are found
    local stale_mounts
    stale_mounts=$(mount | grep "${work_dir_base}" | awk '{print $3}' | sort -r || true)
    if [[ -n "$stale_mounts" ]]; then
        for mnt in $stale_mounts; do
            log_warn "Unmounting stale mount: $mnt"
            ${SUDO} umount -l "$mnt" 2>/dev/null || true
        done
    fi

    # Find and detach any leftover loop devices with pimeleon images
    # Check for both the image name and the mount point path
    local stale_loops
    stale_loops=$(losetup -l -n -O NAME,BACK-FILE 2>/dev/null | grep -E "pimeleon|${work_dir_base}" | awk '{print $1}' || true)
    if [[ -n "$stale_loops" ]]; then
        for loop in $stale_loops; do
            log_warn "Detaching stale loop device: $loop"
            ${SUDO} kpartx -d "$loop" 2>/dev/null || true
            ${SUDO} losetup -d "$loop" 2>/dev/null || true
        done
    fi
}
# Check if running as root or with sudo
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root or with sudo"
    fi
}

# Get the QEMU static binary name for the target architecture
get_qemu_binary() {
    case "${RPI_ARCH:-armhf}" in
        arm64|aarch64) echo "qemu-aarch64-static" ;;
        armhf|arm)     echo "qemu-arm-static" ;;
        *)             die "Unsupported architecture: ${RPI_ARCH}" ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    local qemu_binary
    qemu_binary=$(get_qemu_binary)

    local required_commands=(
        "debootstrap"
        "${qemu_binary}"
        "parted"
        "kpartx"
        "mkfs.vfat"
        "mkfs.ext4"
        "ansible-playbook"
    )

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            die "Required command not found: $cmd"
        fi
    done

    # Check for qemu-user-static
    if [[ ! -f "/usr/bin/${qemu_binary}" ]]; then
        die "${qemu_binary} not found. Please install qemu-user-static package."
    fi

    # Check binfmt support
    if [[ ! -d /proc/sys/fs/binfmt_misc ]]; then
        die "binfmt_misc not mounted. Please enable binfmt support."
    fi
}

# Mount image partitions
mount_image() {
    local image_path=$1
    local mount_point=$2

    log_info "Mounting image: $image_path"

    # Create loop device
    local loop_device
    loop_device=$(${SUDO} losetup -f --show "$image_path")

    # Scan for partitions
    ${SUDO} kpartx -av "$loop_device"
    sleep 2

    # Get partition devices
    local loop_name
    loop_name=$(basename "$loop_device")
    local boot_part="/dev/mapper/${loop_name}p1"
    local root_part="/dev/mapper/${loop_name}p2"

    # Mount partitions (Track in stack for reverse cleanup)
    ${SUDO} mkdir -p "$mount_point"
    ${SUDO} mount "$root_part" "$mount_point"
    MOUNT_STACK+=("$mount_point")

    ${SUDO} mkdir -p "$mount_point/boot"
    ${SUDO} mount "$boot_part" "$mount_point/boot"
    MOUNT_STACK+=("$mount_point/boot")

    # Register for cleanup on error
    CLEANUP_MOUNT_POINT="$mount_point"
    CLEANUP_LOOP_DEVICE="$loop_device"

    echo "$loop_device"
}

# Unmount image partitions
unmount_image() {
    local mount_point=$1
    local loop_device=$2

    log_info "Unmounting image stack..."

    # Check for any sub-mounts not in our stack (e.g. from failed manual checks)
    if [[ -d "$mount_point" ]]; then
        local extra_mounts
        extra_mounts=$(findmnt -n -o TARGET -R "$mount_point" | sort -r | grep -v "^${mount_point}$" || true)
        if [[ -n "$extra_mounts" ]]; then
            log_warn "Found extra mounts under $mount_point, cleaning up..."
            for mnt in $extra_mounts; do
                ${SUDO} umount "$mnt" 2>/dev/null || ${SUDO} umount -l "$mnt" 2>/dev/null || true
            done
        fi
    fi

    # Unmount everything in reverse order from the stack
    for ((i=${#MOUNT_STACK[@]}-1; i>=0; i--)); do
        local mnt="${MOUNT_STACK[$i]}"
        if mountpoint -q "$mnt" 2>/dev/null; then
            # Try standard umount first, then lazy
            ${SUDO} umount "$mnt" 2>/dev/null || ${SUDO} umount -l "$mnt" || log_warn "Failed to unmount $mnt"
        fi
    done
    MOUNT_STACK=()

    # Remove partition mappings
    if [[ -n "$loop_device" ]]; then
        # Ensure kpartx removes mappings
        ${SUDO} kpartx -d "$loop_device" 2>/dev/null || true
        ${SUDO} losetup -d "$loop_device" 2>/dev/null || true
    fi

    # Clear cleanup tracking
    CLEANUP_MOUNT_POINT=""
    CLEANUP_LOOP_DEVICE=""
}

# Setup chroot environment
setup_chroot() {
    local chroot_dir=$1

    log_info "Setting up chroot environment"

    # Copy qemu static binary for target architecture
    local qemu_binary
    qemu_binary=$(get_qemu_binary)
    ${SUDO} cp "/usr/bin/${qemu_binary}" "$chroot_dir/usr/bin/"

    # Mount special filesystems
    ${SUDO} mount -t proc proc "$chroot_dir/proc"
    ${SUDO} mount -t sysfs sys "$chroot_dir/sys"
    ${SUDO} mount -t devtmpfs dev "$chroot_dir/dev"
    ${SUDO} mount -t devpts devpts "$chroot_dir/dev/pts"

    # Write resolv.conf with real DNS servers (Docker's 127.0.0.11 doesn't work in chroot)
    # Ensure it's a regular file, not a symlink
    ${SUDO} rm -f "$chroot_dir/etc/resolv.conf"
    ${SUDO} tee "$chroot_dir/etc/resolv.conf" > /dev/null <<EOF
# DNS for chroot build environment
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

    # Copy host file to prevent 'unable to resolve host' warnings
    ${SUDO} cp /etc/hosts "$chroot_dir/etc/hosts"
    # Copy nsswitch.conf to ensure getent works correctly in chroot
    ${SUDO} cp /etc/nsswitch.conf "$chroot_dir/etc/nsswitch.conf"

    # Pre-populate /etc/hosts with GitHub IPs to bypass DNS resolution checks during build
    # These match current global IPs for github.com and raw.githubusercontent.com
    ${SUDO} tee -a "$chroot_dir/etc/hosts" > /dev/null <<EOF
140.82.121.3 github.com
140.82.121.4 github.com
185.199.108.133 raw.githubusercontent.com
185.199.109.133 raw.githubusercontent.com
185.199.110.133 raw.githubusercontent.com
185.199.111.133 raw.githubusercontent.com
EOF

    # Prevent services from starting in chroot
    ${SUDO} tee "$chroot_dir/usr/sbin/policy-rc.d" > /dev/null <<EOF
#!/bin/sh
exit 101
EOF
    ${SUDO} chmod +x "$chroot_dir/usr/sbin/policy-rc.d"

    # Track chroot state for cleanup
    CLEANUP_CHROOT_ACTIVE=true
}

# Cleanup chroot environment
cleanup_chroot() {
    local chroot_dir=$1

    log_info "Cleaning up chroot environment"

    # Remove policy-rc.d
    ${SUDO} rm -f "$chroot_dir/usr/sbin/policy-rc.d"

    # Unmount special filesystems (reverse order)
    ${SUDO} umount "$chroot_dir/dev/pts" 2>/dev/null || true
    ${SUDO} umount "$chroot_dir/dev" 2>/dev/null || true
    ${SUDO} umount "$chroot_dir/sys" 2>/dev/null || true
    ${SUDO} umount "$chroot_dir/proc" 2>/dev/null || true

    # Remove qemu static binary
    local qemu_binary
    qemu_binary=$(get_qemu_binary)
    ${SUDO} rm -f "$chroot_dir/usr/bin/${qemu_binary}"

    # Clear chroot tracking
    CLEANUP_CHROOT_ACTIVE=false
}

# Validate build environment and variables
validate_build_environment() {
    log_info "Validating build environment..."

    local required_vars=(
        "TARGET_PLATFORM"
        "PIMELEON_RPI_MODEL"
        "RPI_ARCH"
        "RASPBIAN_VERSION"
        "OUTPUT_DIR"
        "CACHE_DIR"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            die "Required environment variable not set: $var"
        fi
    done

    # Check for minimum disk space (5GB recommended for build)
    local free_space
    free_space=$(df -m /tmp | tail -1 | awk '{print $4}')
    if [[ "$free_space" -lt 5000 ]]; then
        log_warn "Low disk space on /tmp ($free_space MB). Build might fail."
    fi

    # Verify network connectivity (Prioritize Cache Server, then Internet)
    local reachable=false
    if timeout 1 bash -c "cat < /dev/null > /dev/tcp/${APT_CACHE_SERVER}/${APT_CACHE_PORT:-3142}" 2>/dev/null; then
        log_info "APT Cache Server (${APT_CACHE_SERVER}) is reachable."
        reachable=true
    fi

    if [[ "$reachable" == "false" ]]; then
        # Fallback to checking DNS or HTTP port instead of ICMP ping
        if timeout 1 bash -c "cat < /dev/null > /dev/tcp/8.8.8.8/53" 2>/dev/null || \
           timeout 1 bash -c "cat < /dev/null > /dev/tcp/google.com/80" 2>/dev/null; then
            log_info "Internet connectivity detected."
            reachable=true
        fi
    fi
}

# Verify stage completion by checking for critical artifacts
verify_stage() {
    local stage=$1
    local mount_point=$2
    log_info "Verifying Stage $stage..."

    case "$stage" in
        1)
            [[ -f "${mount_point}/etc/fstab" ]] || die "Stage 1 verification failed: /etc/fstab missing"
            [[ -f "${mount_point}/boot/config.txt" ]] || die "Stage 1 verification failed: /boot/config.txt missing"
            ;;
        2)
            [[ -f "${mount_point}/etc/shadow" ]] || die "Stage 2 verification failed: Base system compromised"
            [[ -x "${mount_point}/usr/bin/python3" ]] || die "Stage 2 verification failed: python3 missing"
            # Check for at least one critical service file
            [[ -f "${mount_point}/lib/systemd/system/ssh.service" ]] || [[ -f "${mount_point}/usr/lib/systemd/system/ssh.service" ]] || die "Stage 2 verification failed: ssh.service missing"
            ;;
        3)
            # Verify cleanup was successful
            [[ ! -d "${mount_point}/var/lib/apt/lists/partial" ]] || log_warn "Stage 3 warning: APT partial lists still exist"
            ;;
    esac
    log_info "Stage $stage verified successfully."
}

# Configure APT cache for chroot environment
configure_chroot_apt_proxy() {
    local mount_point=$1
    if should_use_apt_proxy; then
        log_info "Configuring APT cache for chroot: ${APT_CACHE_SERVER}:${APT_CACHE_PORT:-3142}"
        ${SUDO} mkdir -p "${mount_point}/etc/apt/apt.conf.d"
        ${SUDO} tee "${mount_point}/etc/apt/apt.conf.d/01proxy" > /dev/null <<EOF
# APT Cache Configuration for Build Process
Acquire::http::Proxy "http://${APT_CACHE_SERVER}:${APT_CACHE_PORT:-3142}";
# Longer timeouts for slow cache/upstream responses
Acquire::http::Timeout "120";
Acquire::https::Timeout "120";
EOF
    fi
}

# Remove APT cache proxy from chroot
remove_chroot_apt_proxy() {
    local mount_point=$1
    if [[ -f "${mount_point}/etc/apt/apt.conf.d/01proxy" ]]; then
        log_info "Removing APT cache configuration from chroot"
        ${SUDO} rm -f "${mount_point}/etc/apt/apt.conf.d/01proxy"
    fi
}

# Migrate legacy APT keyring to modern format (prevents deprecation warnings)
migrate_apt_keyring() {
    local mount_point=$1
    if [ -f "${mount_point}/etc/apt/trusted.gpg" ]; then
        log_info "Migrating legacy APT keyring to modern format"
        ${SUDO} mkdir -p "${mount_point}/etc/apt/trusted.gpg.d"
        ${SUDO} gpg --no-default-keyring \
            --keyring "${mount_point}/etc/apt/trusted.gpg" \
            --export 2>/dev/null | \
            ${SUDO} gpg --no-default-keyring \
                --keyring "gnupg-ring:${mount_point}/etc/apt/trusted.gpg.d/raspbian-archive-keyring.gpg" \
                --import 2>/dev/null || true
        ${SUDO} chmod 644 "${mount_point}/etc/apt/trusted.gpg.d/raspbian-archive-keyring.gpg" 2>/dev/null || true
        ${SUDO} rm -f "${mount_point}/etc/apt/trusted.gpg"
        log_info "Legacy keyring migrated and removed"
    fi
}

# Run command in chroot with proxy support
chroot_run() {
    local chroot_dir=$1
    shift

    # Construct proxy environment if available
    local -a proxy_args=()
    if timeout 1 bash -c "cat < /dev/null > /dev/tcp/${APT_CACHE_SERVER}/${APT_CACHE_PORT:-3142}" 2>/dev/null; then
        log_info "APT Cache Server (${APT_CACHE_SERVER}) is reachable."
        reachable=true
    fi

    # Use env to pass the proxy variables into the chroot environment
    if [[ ${#proxy_args[@]} -gt 0 ]]; then
        ${SUDO} DEBIAN_FRONTEND=noninteractive chroot "$chroot_dir" env "${proxy_args[@]}" "$@"
    else
        ${SUDO} DEBIAN_FRONTEND=noninteractive chroot "$chroot_dir" "$@"
    fi
}

# Generate image metadata
generate_metadata() {
    local image_path=$1
    local metadata_file="${image_path}.metadata.json"

    log_info "Generating metadata: $metadata_file"

    # Calculate checksums
    local md5sum
    md5sum=$(md5sum "$image_path" | cut -d' ' -f1)
    local sha256sum
    sha256sum=$(sha256sum "$image_path" | cut -d' ' -f1)
    local size
    size=$(stat -c%s "$image_path")

    # Create metadata JSON
    cat > "$metadata_file" <<EOF
{
    "version": "$(date +%Y%m%d-%H%M%S)",
    "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "image_name": "$(basename "$image_path")",
    "image_size": $size,
    "checksums": {
        "md5": "$md5sum",
        "sha256": "$sha256sum"
    },
    "build_info": {
        "rpi_model": "${PIMELEON_RPI_MODEL:-3B+}",
        "raspbian_version": "${RASPBIAN_VERSION:-buster}",
        "builder_version": "1.0.0"
    }
}
EOF
}

# =============================================================================
# App Configuration Functions (Monorepo)
# =============================================================================

# Parse app name to derive build configuration
# Format: {platform}-{debian_version}  e.g., rpi3-bookworm, rpi4-bookworm
load_app_config() {
    local app_name=$1
    local workspace_dir="${WORKSPACE_DIR:-/workspace}"
    local app_dir="${workspace_dir}/apps/${app_name}"

    if [[ -z "$app_name" ]]; then
        die "App name is required"
    fi

    if [[ ! -d "$app_dir" ]]; then
        log_error "App not found: $app_name"
        list_apps
        die "Please specify a valid app name"
    fi

    # Parse app name: {device}-{debian}
    local device="${app_name%%-*}"      # rpi3, rpi4
    local debian="${app_name##*-}"      # bookworm

    # Derive configuration from device
    case "$device" in
        rpi3)
            export PIMELEON_RPI_MODEL="3B+"
            export RPI_ARCH="armhf"
            export PIMELEON_IMAGE_SIZE="${PIMELEON_IMAGE_SIZE:-3G}"
            ;;
        rpi4)
            export PIMELEON_RPI_MODEL="4B"
            export RPI_ARCH="arm64"
            export PIMELEON_IMAGE_SIZE="${PIMELEON_IMAGE_SIZE:-4G}"
            ;;
        *)
            die "Unknown device: $device (expected rpi3, rpi4)"
            ;;
    esac

    export RASPBIAN_VERSION="$debian"

    log_info "App: ${app_name}"
    log_info "  Model: ${PIMELEON_RPI_MODEL}, Arch: ${RPI_ARCH}, Debian: ${RASPBIAN_VERSION}"
}

# List available apps
list_apps() {
    local workspace_dir="${WORKSPACE_DIR:-/workspace}"
    local apps_dir="${workspace_dir}/apps"

    if [[ ! -d "$apps_dir" ]]; then
        die "FATAL: No apps directory found at: $apps_dir"
    fi

    echo ""
    echo "Available apps:"
    echo "==============="
    for app_dir in "$apps_dir"/*/; do
        [[ -d "$app_dir" ]] || continue
        local name
        name=$(basename "$app_dir")
        local device="${name%%-*}"
        local debian="${name##*-}"
        printf "  %-20s (%s, %s)\n" "$name" "$device" "$debian"
    done
    echo ""
}

# =============================================================================
# Cache management
# =============================================================================

get_cache_path() {
    local cache_key=$1
    echo "${CACHE_DIR}/${cache_key}"
}

cache_exists() {
    local cache_key=$1
    local cache_path
    cache_path=$(get_cache_path "$cache_key")
    [[ -f "$cache_path" ]]
}

cache_get() {
    local cache_key=$1
    local destination=$2
    local cache_path
    cache_path=$(get_cache_path "$cache_key")

    if cache_exists "$cache_key"; then
        log_info "Using cached file: $cache_key"
        ${SUDO} cp "$cache_path" "$destination"
        ${SUDO} chown "${PIMELEON_USER}:${PIMELEON_GROUP}" "$destination"
        return 0
    else
        return 1
    fi
}

cache_put() {
    local source=$1
    local cache_key=$2
    local cache_path
    cache_path=$(get_cache_path "$cache_key")

    log_info "Caching file: $cache_key"
    ${SUDO} mkdir -p "$(dirname "$cache_path")"
    ${SUDO} cp "$source" "$cache_path"
    ${SUDO} chown "${PIMELEON_USER}:${PIMELEON_GROUP}" "$cache_path"
}

# Fetch source tarball from the registry (falling back to upstream if needed).
# Usage: fetch_source <package> <version> <tarball_name> <upstream_url> <target_path>
fetch_source() {
    local pkg_name="$1"
    local version="$2"
    local tarball_name="$3"
    local upstream_url="$4"
    local target_path="$5"
    local local_cache_dir="/cache/pimeleon-downloads"
    local project_id="${PIMELEON_APPS_PROJECT_ID:-20}"
    local reg="https://gitlab.pirouter.dev/api/v4/projects/${project_id}/packages/generic/sources"

    # 0. Try Local Container Cache (mounted from host's cache/)
    if [[ -f "${local_cache_dir}/${tarball_name}" ]]; then
        log_info "Using locally cached ${tarball_name} from ${local_cache_dir}"
        cp "${local_cache_dir}/${tarball_name}" "${target_path}"
        return 0
    fi

    # 1. Try Local Registry (if JOB-TOKEN or PIMELEON_APPS_READ_TOKEN is set)
    local token="${CI_JOB_TOKEN:-${PIMELEON_APPS_READ_TOKEN:-}}"
    if [[ -n "${token}" ]]; then
        local registry_url="${reg}/${pkg_name}/${version}/${tarball_name}"
        log_info "Attempting to fetch ${pkg_name} ${version} source from registry..."
        
        # Determine header based on token type
        local auth_header="JOB-TOKEN: ${token}"
        if [[ -z "${CI_JOB_TOKEN:-}" ]]; then
            auth_header="PRIVATE-TOKEN: ${token}"
        fi

        if curl -fsSL -k -H "${auth_header}" -o "${target_path}" "${registry_url}"; then
            log_success "Fetched ${pkg_name} ${version} from registry."
            return 0
        fi
        log_warn "Source not found in registry, falling back to upstream."
    fi

    # 2. Try Upstream
    log_info "Downloading ${pkg_name} ${version} from upstream: ${upstream_url}"
    if curl -fsSL -o "${target_path}" "${upstream_url}"; then
        log_success "Downloaded ${pkg_name} ${version} from upstream."
        return 0
    else
        log_error "Failed to download ${pkg_name} from upstream."
        return 1
    fi
}

# Fetch a pre-built binary package from the pi-router-apps Generic Package Registry.
# Usage: fetch_pimeleon_apps <package> <arch> <download_dir>
# Saves as <download_dir>/<package>.tar.gz (matching existing Ansible task expectations).
# Non-fatal: logs a warning and returns 1 on failure so the caller can decide.
fetch_pimeleon_apps() {
    local package="$1"
    local arch="$2"
    local download_dir="$3"
    local project_id="${PIMELEON_APPS_PROJECT_ID:-0}"
    local token="${PIMELEON_APPS_READ_TOKEN:-}"
    local reg="https://gitlab.pirouter.dev/api/v4/projects/${project_id}/packages/generic"

    if [[ "${project_id}" == "0" ]] || [[ -z "${project_id}" ]]; then
        log_warn "PIMELEON_APPS_PROJECT_ID not set, skipping registry fetch for ${package}"
        return 1
    fi

    local version
    version=$(curl -fsSLk \
        -H "PRIVATE-TOKEN: ${token}" \
        "${reg}/${package}?per_page=1&order_by=created_at&sort=desc" 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); v=next((p.get('version','') for p in d if p.get('version','').startswith('${arch}-')),''); print(v.replace('${arch}-','',1)) if v else None" \
        2>/dev/null || true)

    if [[ -z "${version}" ]]; then
        log_warn "No published version found for ${package}/${arch} in pi-router-apps registry"
        return 1
    fi

    local fname="${package}-${version}-${arch}-pimeleon.tar.gz"
    local url="${reg}/${package}/${arch}-${version}/${fname}"
    log_info "Fetching ${package} ${version} (${arch}) from pi-router-apps registry"

    if curl -fsSLk -H "PRIVATE-TOKEN: ${token}" -o "${download_dir}/${package}.tar.gz" "${url}"; then
        log_info "Fetched ${package} ${version} -> ${download_dir}/${package}.tar.gz"
        return 0
    else
        log_warn "Failed to fetch ${package} from pi-router-apps registry"
        return 1
    fi
}
trap "cleanup_on_exit" EXIT ERR INT TERM
