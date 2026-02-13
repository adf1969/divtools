#!/usr/bin/env bash
# Wrapper for ComfyUI - loads env vars and passes to comfy command or systemctl service
# Last Updated: 01/27/2026 11:00:00 AM CST
#
# Usage: 
#   comfy_run.sh [comfy-args...]           - Run comfy directly with venv
#   comfy_run.sh start|stop|restart|status - Control systemd service

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# Source logging utilities
if [[ -f "$REPO_ROOT/scripts/util/logging.sh" ]]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/scripts/util/logging.sh"
fi

# Load divtools environment
if [[ -f "$REPO_ROOT/dotfiles/.bash_profile" ]]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/dotfiles/.bash_profile"
    load_env_files 2>/dev/null || true
fi

# Default workspace candidates
DEFAULT_WORKSPACES=("${COMFY_WORKSPACE:-}" "/opt/comfy" "$HOME/comfy/ComfyUI")

# Detect workspace
WORKSPACE=""
for candidate in "${DEFAULT_WORKSPACES[@]}"; do
    [[ -z "$candidate" ]] && continue
    if [[ -d "$candidate" ]]; then
        WORKSPACE="$candidate"
        break
    fi
done

# Load .env.comfy if it exists
if [[ -n "$WORKSPACE" && -f "$WORKSPACE/.env.comfy" ]]; then
    # shellcheck source=/dev/null
    set -a; source "$WORKSPACE/.env.comfy"; set +a
    log_msg "DEBUG" "Loaded env from $WORKSPACE/.env.comfy"
fi

# ComfyUI output directory (edit this path as needed)
COMFY_OUTPUT_DIR="/mnt/nas1-91/nfs_test/nsfw/output"
COMFY_INPUT_DIR="/mnt/nas1-91/nfs_test/nsfw/input"

# Parse script-specific options
USE_SAGE_ATTENTION=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--sage-attention)
            USE_SAGE_ATTENTION=1
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Check if first arg is a systemctl command
case "${1:-}" in
    start|stop|restart|status|enable|disable)
        SYSTEMCTL_CMD="$1"
        shift
        log_msg "INFO" "Running: systemctl $SYSTEMCTL_CMD comfy.service"
        exec sudo systemctl "$SYSTEMCTL_CMD" comfy.service "$@"
        ;;
    -h|--help)
        cat <<EOF
Usage: $(basename "$0") [OPTIONS] [comfy-args...]

Wrapper for ComfyUI that loads environment variables and manages execution.

SYSTEMCTL MODE:
  start                 Start the comfy systemd service
  stop                  Stop the comfy systemd service  
  restart               Restart the comfy systemd service
  status                Show comfy systemd service status
  enable                Enable comfy service to start on boot
  disable               Disable comfy service autostart

DIRECT MODE (runs comfy command with venv):
  -s, --sage-attention  Enable SageAttention for improved performance
  [comfy-args...]       Any other args are passed to 'comfy launch'

ENVIRONMENT VARIABLES (.env.comfy):
  COMFY_WORKSPACE       Path to ComfyUI workspace (default: /opt/comfy)
  COMFY_LISTEN          Listen address (default: 0.0.0.0)
  COMFY_PORT            Listen port (default: 8188)
  COMFY_USE_SAGE_ATTENTION  Enable SageAttention (set to 1 to enable)
  COMFY_EXTRA_ARGS      Additional args to pass to comfy launch

Examples:
  $(basename "$0") start                    # Start via systemd
  $(basename "$0") status                   # Check service status
  $(basename "$0") --sage-attention         # Run directly with SageAttention
  $(basename "$0")                          # Run directly with env defaults

Configuration:
  Edit $WORKSPACE/.env.comfy to set variables
  Service file: /etc/systemd/system/comfy.service
EOF
        exit 0
        ;;
esac

# DIRECT MODE: Run comfy command with venv activation
log_msg "INFO" "Running comfy in direct mode with venv activation"

# Activate venv
if type pvact >/dev/null 2>&1; then
    pvact comfy-env || exit 1
elif declare -f python_venv_activate >/dev/null 2>&1; then
    python_venv_activate comfy-env || exit 1
else
    log_msg "ERROR" "No python venv activation function available"
    exit 1
fi

# Verify comfy command exists
if ! command -v comfy >/dev/null 2>&1; then
    log_msg "ERROR" "'comfy' command not found in PATH after activating comfy-env"
    exit 2
fi

# Build command with workspace and env vars
CMD=(comfy)
[[ -n "$WORKSPACE" ]] && CMD+=(--workspace "$WORKSPACE")
CMD+=(launch)

# Build extra args array (these go after -- for comfy launch)
EXTRA_ARGS=()

# Add SageAttention if enabled via flag or environment variable
if [[ $USE_SAGE_ATTENTION -eq 1 ]] || [[ "${COMFY_USE_SAGE_ATTENTION:-0}" == "1" ]]; then
    EXTRA_ARGS+=(--use-sage-attention)
    log_msg "INFO" "SageAttention enabled for improved performance"
fi

# Add args from environment variables
[[ -n "${COMFY_LISTEN:-}" ]] && EXTRA_ARGS+=(--listen "$COMFY_LISTEN")
[[ -n "${COMFY_PORT:-}" ]] && EXTRA_ARGS+=(--port "$COMFY_PORT")

# Add input and output directories if set
[[ -n "${COMFY_INPUT_DIR:-}" ]] && EXTRA_ARGS+=(--input-directory "$COMFY_INPUT_DIR")
[[ -n "${COMFY_OUTPUT_DIR:-}" ]] && EXTRA_ARGS+=(--output-directory "$COMFY_OUTPUT_DIR")

# Add extra args from .env.comfy
if [[ -n "${COMFY_EXTRA_ARGS:-}" ]]; then
    read -r -a extra_from_env <<< "$COMFY_EXTRA_ARGS"
    EXTRA_ARGS+=("${extra_from_env[@]}")
fi

# Add any args passed to this script
[[ $# -gt 0 ]] && EXTRA_ARGS+=("$@")

# If we have extra args, add them after --
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    CMD+=(-- "${EXTRA_ARGS[@]}")
fi

log_msg "INFO" "Executing: ${CMD[*]}"

# Print friendly URL with primary IP if listening on 0.0.0.0
effective_listen="${COMFY_LISTEN:-0.0.0.0}"
if [[ "$effective_listen" == "0.0.0.0" ]]; then
    primary_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -n "$primary_ip" ]]; then
        effective_port="${COMFY_PORT:-8188}"
        echo "ComfyUI will be accessible at: http://${primary_ip}:${effective_port}" >&2
    fi
fi

exec "${CMD[@]}"
