#!/bin/bash
# SSH Utility Script - Passwordless SSH Key Setup and Management
# Last Updated: 01/09/2026 6:15:00 PM CDT
#
# This script configures passwordless SSH authentication by managing SSH keys.
# Supports SSH key generation, copying to remote hosts, and testing connections.
#
# Usage: ./ssh_util.sh [options] [user@host]
# Examples:
#   ./ssh_util.sh -ls                           # List local SSH keys
#   ./ssh_util.sh -lsr divix@10.1.1.111         # List remote SSH keys
#   ./ssh_util.sh -test divix@10.1.1.111        # Test SSH connection
#   ./ssh_util.sh divix@10.1.1.111              # Setup passwordless SSH
#   ./ssh_util.sh -debug divix@10.1.1.111       # Setup with debug output

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# SSH configuration
SSH_USER="${USER}"
SSH_HOST=""
SSH_KEY_TYPE="ed25519"  # Modern, secure default
SSH_KEY_PATH="$HOME/.ssh"
SSH_PORT="22"

# Function to display usage
usage() {
    echo "Usage: $0 [options] [user@host]"
    echo ""
    echo "Options:"
    echo "  -test              Test SSH connection without setup"
    echo "  -debug             Enable debug output during setup"
    echo "  -ls                List local SSH public keys"
    echo "  -lsr [user@host]   List remote SSH authorized keys"
    echo "  -help              Display this help message"
    echo ""
    echo "Arguments:"
    echo "  user@host          Remote user and hostname (e.g., divix@10.1.1.111)"
    echo "                     If not provided, you will be prompted for hostname"
    echo ""
    echo "Examples:"
    echo "  $0 -ls"
    echo "  $0 -test divix@10.1.1.111"
    echo "  $0 divix@10.1.1.111"
    echo "  $0 -debug divix@10.1.1.111"
}

# Function to list local SSH keys
list_local_keys() {
    log "HEAD" "=== Local SSH Public Keys ===" >&2
    
    if [[ ! -d "$SSH_KEY_PATH" ]]; then
        log "WARN" "SSH directory does not exist: $SSH_KEY_PATH" >&2
        return 1
    fi
    
    local key_count=0
    for key in "$SSH_KEY_PATH"/id_*.pub; do
        if [[ -f "$key" ]]; then
            key_count=$((key_count + 1))
            local key_name=$(basename "$key" .pub)
            local key_type=$(head -1 "$key" | awk '{print $1}')
            local key_fingerprint=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $2}')
            
            log "INFO" "Key: $key_name ($key_type)" >&2
            log "DEBUG" "  Path: $key" >&2
            log "DEBUG" "  Fingerprint: $key_fingerprint" >&2
            echo ""
        fi
    done
    
    if [[ $key_count -eq 0 ]]; then
        log "WARN" "No SSH keys found in $SSH_KEY_PATH" >&2
        return 1
    else
        log "INFO" "Total keys: $key_count" >&2
    fi
    return 0
}

# Function to list remote authorized keys
list_remote_keys() {
    local remote_addr="$1"
    
    if [[ -z "$remote_addr" ]]; then
        log "ERROR" "Remote address required (user@host)" >&2
        return 1
    fi
    
    log "HEAD" "=== Remote SSH Authorized Keys ===" >&2
    log "INFO" "Attempting to read authorized_keys from $remote_addr..." >&2
    
    local output
    output=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$remote_addr" \
        "if [[ -f ~/.ssh/authorized_keys ]]; then cat ~/.ssh/authorized_keys; else echo 'NOT_FOUND'; fi" 2>/dev/null)
    
    if [[ "$output" == "NOT_FOUND" ]]; then
        log "WARN" "No authorized_keys file found on remote host" >&2
        return 1
    elif [[ -z "$output" ]]; then
        log "INFO" "authorized_keys file exists but is empty" >&2
        return 0
    fi
    
    log "INFO" "Remote authorized_keys:" >&2
    echo "$output" | while read -r line; do
        # Extract key type and fingerprint
        local key_type=$(echo "$line" | awk '{print $1}')
        local key_data=$(echo "$line" | awk '{print $2}')
        local key_comment=$(echo "$line" | awk '{print $NF}')
        
        log "DEBUG" "Type: $key_type" >&2
        log "DEBUG" "Comment: $key_comment" >&2
        echo ""
    done
    
    return 0
}

# Function to test SSH connection
test_ssh_connection() {
    local remote_addr="$1"
    
    if [[ -z "$remote_addr" ]]; then
        log "ERROR" "Remote address required (user@host)" >&2
        return 1
    fi
    
    log "INFO" "Testing SSH connection to $remote_addr..." >&2
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Running: ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $remote_addr 'echo SSH_OK'" >&2
    fi
    
    local result
    result=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$remote_addr" "echo SSH_OK" 2>/dev/null)
    
    if [[ "$result" == "SSH_OK" ]]; then
        log "INFO" "✅ SSH connection successful to $remote_addr" >&2
        return 0
    else
        log "WARN" "❌ SSH connection failed to $remote_addr" >&2
        return 1
    fi
}

# Function to generate SSH key locally
generate_local_key() {
    local key_path="$SSH_KEY_PATH/id_$SSH_KEY_TYPE"
    
    log "INFO" "Generating new SSH key pair..." >&2
    log "DEBUG" "Key type: $SSH_KEY_TYPE" >&2
    log "DEBUG" "Key path: $key_path" >&2
    
    if [[ -f "$key_path" ]]; then
        log "WARN" "Key already exists at $key_path" >&2
        return 1
    fi
    
    # Create SSH directory if it doesn't exist
    if [[ ! -d "$SSH_KEY_PATH" ]]; then
        log "INFO" "Creating SSH directory: $SSH_KEY_PATH" >&2
        mkdir -p "$SSH_KEY_PATH"
        chmod 700 "$SSH_KEY_PATH"
    fi
    
    # Generate key with no passphrase
    if ssh-keygen -t "$SSH_KEY_TYPE" -f "$key_path" -N "" -C "$USER@$(hostname)" >/dev/null 2>&1; then
        log "INFO" "✅ SSH key generated successfully" >&2
        log "DEBUG" "Public key: ${key_path}.pub" >&2
        chmod 600 "$key_path"
        chmod 644 "${key_path}.pub"
        return 0
    else
        log "ERROR" "Failed to generate SSH key" >&2
        return 1
    fi
}

# Function to copy public key to remote host
copy_key_to_remote() {
    local remote_addr="$1"
    local key_file="$2"
    
    if [[ -z "$remote_addr" ]] || [[ -z "$key_file" ]]; then
        log "ERROR" "Remote address and key file required" >&2
        return 1
    fi
    
    if [[ ! -f "$key_file" ]]; then
        log "ERROR" "Key file not found: $key_file" >&2
        return 1
    fi
    
    log "INFO" "Copying public key to $remote_addr..." >&2
    log "DEBUG" "Key file: $key_file" >&2
    
    # Create .ssh directory on remote if it doesn't exist
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$remote_addr" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh" 2>/dev/null
    
    # Copy the public key
    if cat "$key_file" | ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$remote_addr" \
        "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null; then
        log "INFO" "✅ Public key copied successfully" >&2
        return 0
    else
        log "ERROR" "Failed to copy public key to remote host" >&2
        return 1
    fi
}

# Function to setup passwordless SSH
setup_passwordless_ssh() {
    local remote_addr="$1"
    
    if [[ -z "$remote_addr" ]]; then
        log "ERROR" "Remote address required (user@host)" >&2
        return 1
    fi
    
    log "HEAD" "=== Setting up Passwordless SSH ===" >&2
    log "INFO" "Target: $remote_addr" >&2
    
    # Check if local keys exist
    local available_keys=()
    for key in "$SSH_KEY_PATH"/id_*.pub; do
        if [[ -f "$key" ]]; then
            available_keys+=("$key")
        fi
    done
    
    local chosen_key=""
    
    if [[ ${#available_keys[@]} -gt 0 ]]; then
        log "INFO" "Found ${#available_keys[@]} local SSH key(s)" >&2
        
        if [[ ${#available_keys[@]} -eq 1 ]]; then
            # Use the only key available
            chosen_key="${available_keys[0]}"
            log "INFO" "Using existing key: $(basename $chosen_key .pub)" >&2
        else
            # Multiple keys, show options
            log "INFO" "Available keys:" >&2
            for i in "${!available_keys[@]}"; do
                echo "  $((i+1))) $(basename ${available_keys[$i]} .pub)" >&2
            done
            echo "  $((${#available_keys[@]}+1))) Generate new key" >&2
            
            read -p "Select key (1-$((${#available_keys[@]}+1))): " key_choice
            
            if [[ $key_choice -le ${#available_keys[@]} ]] && [[ $key_choice -gt 0 ]]; then
                chosen_key="${available_keys[$((key_choice-1))]}"
                log "INFO" "Using key: $(basename $chosen_key .pub)" >&2
            elif [[ $key_choice -eq $((${#available_keys[@]}+1)) ]]; then
                # Generate new key
                if generate_local_key; then
                    chosen_key="$SSH_KEY_PATH/id_$SSH_KEY_TYPE.pub"
                else
                    log "ERROR" "Failed to generate new key" >&2
                    return 1
                fi
            else
                log "ERROR" "Invalid selection" >&2
                return 1
            fi
        fi
    else
        # No keys exist, generate one
        log "INFO" "No local SSH keys found" >&2
        log "INFO" "Generating new SSH key..." >&2
        
        if generate_local_key; then
            chosen_key="$SSH_KEY_PATH/id_$SSH_KEY_TYPE.pub"
        else
            log "ERROR" "Failed to generate SSH key" >&2
            return 1
        fi
    fi
    
    # Copy the chosen key to remote
    if copy_key_to_remote "$remote_addr" "$chosen_key"; then
        log "INFO" "Testing new connection..." >&2
        if test_ssh_connection "$remote_addr"; then
            log "HEAD" "✅ Passwordless SSH setup complete!" >&2
            return 0
        else
            log "WARN" "Key copied but connection test failed" >&2
            return 1
        fi
    else
        log "ERROR" "Failed to copy key to remote host" >&2
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            shift
            ;;
        -ls|--list)
            list_local_keys
            exit $?
            ;;
        -lsr|--list-remote)
            shift
            if [[ $# -gt 0 ]]; then
                list_remote_keys "$1"
            else
                log "ERROR" "-lsr requires user@host argument" >&2
                exit 1
            fi
            exit $?
            ;;
        -help|--help|-h)
            usage
            exit 0
            ;;
        *@*)
            # Parse user@host format
            SSH_USER="${1%@*}"
            SSH_HOST="${1#*@}"
            shift
            ;;
        *)
            # Check if it looks like a hostname/IP (no leading dash)
            if [[ ! "$1" =~ ^- ]]; then
                # Treat as hostname, use current user
                SSH_HOST="$1"
                SSH_USER="${USER}"
                shift
            else
                log "ERROR" "Unknown option: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
done

# If no host provided, check if we're in interactive mode
if [[ -z "$SSH_HOST" ]]; then
    # Check if stdin is a terminal (interactive mode)
    if [[ -t 0 ]]; then
        read -p "Enter remote hostname (or IP): " SSH_HOST
    fi
fi

if [[ -z "$SSH_HOST" ]]; then
    log "ERROR" "Remote hostname required" >&2
    usage
    exit 1
fi

# Build full remote address
REMOTE_ADDR="$SSH_USER@$SSH_HOST"

if [[ $DEBUG_MODE -eq 1 ]]; then
    log "DEBUG" "SSH_USER=$SSH_USER" >&2
    log "DEBUG" "SSH_HOST=$SSH_HOST" >&2
    log "DEBUG" "REMOTE_ADDR=$REMOTE_ADDR" >&2
    log "DEBUG" "SSH_KEY_PATH=$SSH_KEY_PATH" >&2
    log "DEBUG" "SSH_KEY_TYPE=$SSH_KEY_TYPE" >&2
fi

# Execute appropriate action
if [[ $TEST_MODE -eq 1 ]]; then
    test_ssh_connection "$REMOTE_ADDR"
    exit $?
else
    setup_passwordless_ssh "$REMOTE_ADDR"
    exit $?
fi



