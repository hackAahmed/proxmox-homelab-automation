#!/bin/bash

# =================================================================
#             Shared Helper Functions for Homelab Automation
# =================================================================
# This file contains all common utility functions to follow DRY principle.
# All scripts should source this file instead of duplicating functions.
#
# Usage: source "$WORK_DIR/scripts/helper-functions.sh"
#

# === LOGGING FUNCTIONS ===
# Colored output functions used throughout all scripts

print_info() { 
    echo -e "\033[36m[INFO]\033[0m $1" 
}

print_success() { 
    echo -e "\033[32m[SUCCESS]\033[0m $1" 
}

print_error() { 
    echo -e "\033[31m[ERROR]\033[0m $1" 
}

print_warning() { 
    echo -e "\033[33m[WARNING]\033[0m $1" 
}

# === USER INTERACTION FUNCTIONS ===
# Common user input and interaction patterns

press_enter_to_continue() {
    echo
    read -p "Press Enter to continue..."
}

prompt_password() {
    local prompt="${1:-Enter password: }"
    local min_length="${2:-8}"
    local pass
    local confirm_pass
    
    while true; do
        echo -n "$prompt" >&2
        read -s pass
        echo >&2
        
        if [[ -z "$pass" ]]; then
            print_warning "Password cannot be empty."
            continue
        fi
        
        if [[ ${#pass} -lt $min_length ]]; then
            print_warning "Password must be at least $min_length characters long."
            continue
        fi
        
        echo -n "Confirm password: " >&2
        read -s confirm_pass
        echo >&2
        
        if [[ "$pass" != "$confirm_pass" ]]; then
            print_warning "Passwords do not match. Please try again."
            continue
        fi
        
        break
    done
    
    printf '%s' "$pass"
}

prompt_env_passphrase() {
    local pass
    while true; do
        echo -n "Enter encryption passphrase: " >&2
        read -s pass
        echo >&2
        
        if [[ -z "$pass" ]]; then
            print_warning "Passphrase cannot be empty."
            continue
        fi
        
        break
    done
    
    printf '%s' "$pass"
}

# === SYSTEM UTILITIES ===
# Common system-level utility functions

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        print_error "This script must be run as root!"
        exit 1
    fi
}

ensure_packages() {
    print_info "Ensuring packages '$*' are installed..."
    apt-get update -q >/dev/null 2>&1 || true
    apt-get install -y "$@" >/dev/null 2>&1
}

ensure_yq() {
    if ! command -v yq >/dev/null 2>&1; then
        print_info "Installing yq (YAML processor)..."
        apt-get update -q >/dev/null 2>&1 || true
        apt-get install -y yq >/dev/null 2>&1 || true
    fi
}

# === CONFIGURATION MANAGEMENT ===
# Unified configuration parsing and validation

get_stack_config() {
    local stack="$1"
    local stacks_file="${2:-$WORK_DIR/stacks.yaml}"
    
    # Ensure required tools
    ensure_yq
    
    # Validate stacks file exists
    if [[ ! -f "$stacks_file" ]]; then
        print_error "Stacks file not found: $stacks_file"
        exit 1
    fi
    
    # Read configuration - all common fields in one place
    CT_ID=$(yq -r ".stacks.$stack.ct_id" "$stacks_file" 2>/dev/null)
    CT_HOSTNAME=$(yq -r ".stacks.$stack.hostname" "$stacks_file" 2>/dev/null)
    CT_IP_OCTET=$(yq -r ".stacks.$stack.ip_octet" "$stacks_file" 2>/dev/null)
    CT_CPU_CORES=$(yq -r ".stacks.$stack.cpu_cores" "$stacks_file" 2>/dev/null)
    CT_MEMORY_MB=$(yq -r ".stacks.$stack.memory_mb" "$stacks_file" 2>/dev/null)
    CT_DISK_GB=$(yq -r ".stacks.$stack.disk_gb" "$stacks_file" 2>/dev/null)
    
    # Network configuration
    NETWORK_GATEWAY=$(yq -r ".network.gateway" "$stacks_file" 2>/dev/null)
    NETWORK_BRIDGE=$(yq -r ".network.bridge" "$stacks_file" 2>/dev/null)
    NETWORK_IP_BASE=$(yq -r ".network.ip_base" "$stacks_file" 2>/dev/null)
    
    # Storage configuration
    STORAGE_POOL=$(yq -r ".storage.pool" "$stacks_file" 2>/dev/null)
    
    # Backup-specific configuration (if needed)
    if [[ "$stack" == "backup" ]]; then
        PBS_DATASTORE_NAME=$(yq -r ".stacks.$stack.pbs_datastore_name" "$stacks_file" 2>/dev/null)
        PBS_REPO_SUITE=$(yq -r ".stacks.$stack.pbs_repo_suite" "$stacks_file" 2>/dev/null)
        PBS_PRUNE_SCHEDULE=$(yq -r ".stacks.$stack.pbs_prune_schedule" "$stacks_file" 2>/dev/null)
        PBS_GC_SCHEDULE=$(yq -r ".stacks.$stack.pbs_gc_schedule" "$stacks_file" 2>/dev/null)
        PBS_VERIFY_SCHEDULE=$(yq -r ".stacks.$stack.pbs_verify_schedule" "$stacks_file" 2>/dev/null)
    fi
    
    # Validate required fields
    if [[ -z "$CT_ID" || "$CT_ID" == "null" ]]; then
        print_error "Stack '$stack' not found or incomplete in $stacks_file"
        exit 1
    fi
    
    # Construct derived values
    CT_IP="$NETWORK_IP_BASE.$CT_IP_OCTET"
    
    # Export all variables for use in calling scripts
    export CT_ID CT_HOSTNAME CT_IP_OCTET CT_CPU_CORES CT_MEMORY_MB CT_DISK_GB
    export NETWORK_GATEWAY NETWORK_BRIDGE NETWORK_IP_BASE STORAGE_POOL CT_IP
    export PBS_DATASTORE_NAME PBS_REPO_SUITE PBS_PRUNE_SCHEDULE PBS_GC_SCHEDULE PBS_VERIFY_SCHEDULE
}

# === CONTAINER MANAGEMENT ===
# Common LXC container operations

check_container_exists() {
    local ct_id="$1"
    pct status "$ct_id" >/dev/null 2>&1
}

check_container_running() {
    local ct_id="$1"
    [[ "$(pct status "$ct_id" 2>/dev/null)" == "status: running" ]]
}

wait_for_container() {
    local ct_id="$1"
    local max_wait="${2:-30}"
    local count=0
    
    print_info "Waiting for container $ct_id to be ready..."
    
    while ! check_container_running "$ct_id" && [[ $count -lt $max_wait ]]; do
        sleep 2
        count=$((count + 2))
        echo -n "."
    done
    echo
    
    if [[ $count -ge $max_wait ]]; then
        print_error "Container $ct_id failed to start within ${max_wait} seconds"
        return 1
    fi
    
    print_success "Container $ct_id is ready"
    return 0
}

exec_in_container() {
    local ct_id="$1"
    shift
    pct exec "$ct_id" -- "$@"
}

# === MENU UTILITIES ===
# Common menu display patterns

show_menu_header() {
    local title="$1"
    clear
    echo "======================================="
    echo "      $title"
    echo "======================================="
    echo
}

show_menu_footer() {
    echo "---------------------------------------"
    echo "   b) Back to Main Menu"
    echo "   q) Quit"
    echo
}

# === FILE AND DIRECTORY UTILITIES ===
# Common file operations and validations

ensure_directory() {
    local dir_path="$1"
    local owner="${2:-}"
    
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
        print_info "Created directory: $dir_path"
    fi
    
    if [[ -n "$owner" ]]; then
        chown "$owner" "$dir_path" 2>/dev/null || print_warning "Could not set ownership for $dir_path"
    fi
}

backup_file() {
    local file_path="$1"
    
    if [[ -f "$file_path" ]]; then
        cp "$file_path" "$file_path.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backup created: $file_path.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# === VALIDATION FUNCTIONS ===
# Common validation patterns

validate_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ $ip =~ $regex ]]; then
        for octet in $(echo "$ip" | tr '.' ' '); do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

validate_container_id() {
    local ct_id="$1"
    
    if [[ "$ct_id" =~ ^[0-9]+$ ]] && [[ $ct_id -ge 100 ]] && [[ $ct_id -le 999 ]]; then
        return 0
    else
        return 1
    fi
}