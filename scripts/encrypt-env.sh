#!/bin/bash

# Encrypt .env files from LXC containers
# Usage: encrypt-env.sh [stack-name]

set -e

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

# --- Load Shared Functions ---
source "$WORK_DIR/scripts/helper-functions.sh"

# --- Encrypt function ---
encrypt_container_env() {
    local stack="$1"
    get_stack_config "$stack"
    
    print_info "Encrypting .env file from container [$CT_HOSTNAME] (ID: $CT_ID)..."
    
    # Check if container is running
    if ! pct status "$CT_ID" | grep -q "running"; then
        print_error "Container $CT_ID is not running. Please start it first."
        exit 1
    fi
    
    # Check if .env exists in container
    if ! pct exec "$CT_ID" -- test -f "/root/.env"; then
        print_error "No .env file found in container $CT_ID at /root/.env"
        exit 1
    fi
    
    # Create output directory
    local output_dir="$WORK_DIR/docker/$stack"
    mkdir -p "$output_dir"
    
    # Get .env from container
    local temp_env="/tmp/.env.temp"
    pct exec "$CT_ID" -- cat "/root/.env" > "$temp_env"
    
    # Get passphrase
    local pass=$(prompt_env_passphrase)
    
    # Encrypt - fail fast, no retries
    local encrypted_file="$output_dir/.env.enc"
    if printf '%s' "$pass" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass stdin -in "$temp_env" -out "$encrypted_file" 2>/dev/null; then
        print_success "Environment file encrypted successfully: docker/$stack/.env.enc"
        print_info "Next steps:"
        print_info "1. Copy docker/$stack/.env.enc to your development environment"
        print_info "2. git add docker/$stack/.env.enc"
        print_info "3. git commit -m 'Update $stack environment'"
        print_info "4. git push"
    else
        print_error "Encryption failed."
        rm -f "$encrypted_file"
        exit 1
    fi
    
    # Clean up temp file
    rm -f "$temp_env"
}

# --- Interactive menu ---
show_encrypt_menu() {
    while true; do
        clear
        echo "==============================================="
        echo "      Environment File Encryption Menu"
        echo "==============================================="
        echo
        echo "   1) Encrypt [proxy]      .env (LXC 100)"
        echo "   2) Encrypt [media]      .env (LXC 101)"
        echo "   3) Encrypt [files]      .env (LXC 102)"
        echo "   4) Encrypt [webtools]   .env (LXC 103)"
        echo "   5) Encrypt [monitoring] .env (LXC 104)"
        echo "   6) Encrypt [gameservers] .env (LXC 105)"
        echo "   7) Encrypt [development] .env (LXC 151)"
        echo
        echo "   q) Back to Main Menu"
        echo
        read -p "   Enter your choice: " choice
        
        case $choice in
            1) encrypt_container_env "proxy" ; break ;;
            2) encrypt_container_env "media" ; break ;;
            3) encrypt_container_env "files" ; break ;;
            4) encrypt_container_env "webtools" ; break ;;
            5) encrypt_container_env "monitoring" ; break ;;
            6) encrypt_container_env "gameservers" ; break ;;
            7) encrypt_container_env "development" ; break ;;
            q|Q) echo "Returning to main menu..."; exit 0 ;;
            *) echo "Invalid choice. Please try again." ; sleep 2 ;;
        esac
        echo
        read -p "Press Enter to continue..."
    done
}

# --- Main execution ---
if [ -n "$1" ]; then
    # Direct stack name provided
    encrypt_container_env "$1"
else
    # Show interactive menu
    show_encrypt_menu
fi