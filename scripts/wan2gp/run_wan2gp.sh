#!/usr/bin/env bash
# Launches Wan2GP as a systemd service with environment variable support
# Last Updated: 02/07/2026 11:30:00 AM CST

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

# Activate conda environment for wan2gp
if [[ ! -d "$CONDA_DIR/wan2gp" ]]; then
    log "ERROR" "Conda environment not found at $CONDA_DIR/wan2gp"
    log "INFO" "Create it with: cdcr wan2gp"
    exit 1
fi

log "DEBUG" "Using conda environment: $CONDA_DIR/wan2gp"
# Use conda run to execute python in the conda environment
CONDA_CMD="/opt/conda/bin/conda"
if [[ ! -x "$CONDA_CMD" ]]; then
    log "ERROR" "Conda executable not found at $CONDA_CMD"
    exit 1
fi

# Save command-line WAN2GP_DEBUG_LEVEL before sourcing .env
# This allows command-line overrides to work properly
CMDLINE_DEBUG_LEVEL="${WAN2GP_DEBUG_LEVEL:-}"

# Parse command-line flags (-test, -debug)
TEST_MODE=0
DEBUG_MODE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -test|--test)
            TEST_MODE=1
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ $TEST_MODE -eq 1 ]]; then
    log "INFO" "TEST MODE: Command will be shown but NOT executed"
fi

# Wan2GP application directory
WAN2GP_DIR="/opt/wan2gp/Wan2GP"

# Check if Wan2GP directory exists
if [[ ! -d "$WAN2GP_DIR" ]]; then
    log "ERROR" "Wan2GP directory not found: $WAN2GP_DIR"
    exit 1
fi

# Load .env.wan2gp if it exists in the script directory
ENV_FILE="$SCRIPT_DIR/.env.wan2gp"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    set -a; source "$ENV_FILE"; set +a
    log "DEBUG" "Loaded configuration from $ENV_FILE"
    # Debug: Show what was sourced
    log "DEBUG" "WAN2GP_TEACACHE after sourcing .env: '${WAN2GP_TEACACHE}'"
    if [[ -n "$WAN2GP_TEACACHE" ]]; then
        log "DEBUG" "  → WAN2GP_TEACACHE is SET to: $WAN2GP_TEACACHE"
    else
        log "DEBUG" "  → WAN2GP_TEACACHE is EMPTY or UNSET"
    fi
else
    log "ERROR" "Configuration file not found: $ENV_FILE"
fi

# Debug level from environment (0-3): 0=minimal, 1=standard, 2=enhanced, 3=maximum
# Allow command-line WAN2GP_DEBUG_LEVEL to override .env value
if [[ -n "$CMDLINE_DEBUG_LEVEL" ]]; then
    DEBUG_LEVEL="$CMDLINE_DEBUG_LEVEL"
else
    DEBUG_LEVEL="${WAN2GP_DEBUG_LEVEL:-1}"
fi
log "DEBUG" "Debug level set to: $DEBUG_LEVEL"

# Default values (can be overridden by .env.wan2gp)
WAN2GP_SERVER_NAME="${WAN2GP_SERVER_NAME:-0.0.0.0}"
WAN2GP_SERVER_PORT="${WAN2GP_SERVER_PORT:-7860}"
WAN2GP_VERBOSE="${WAN2GP_VERBOSE:-}"

# Explicitly set WAN2GP_TEACACHE (will be overridden from .env.wan2gp if set)
# This ensures the variable is available throughout the script
WAN2GP_TEACACHE="${WAN2GP_TEACACHE:-}"
log "DEBUG" "WAN2GP_TEACACHE initialized: '${WAN2GP_TEACACHE}'"

# Default output directories for new downloads
WAN2GP_CHECKPOINTS_DIR="${WAN2GP_CHECKPOINTS_DIR:-/opt/ai_models/sd_models/checkpoints}"
WAN2GP_DIFFUSION_MODELS_DIR="${WAN2GP_DIFFUSION_MODELS_DIR:-/opt/ai_models/sd_models/diffusion_models}"
WAN2GP_TEXT_ENCODERS_DIR="${WAN2GP_TEXT_ENCODERS_DIR:-/opt/ai_models/sd_models/text_encoders}"
WAN2GP_UNET_DIR="${WAN2GP_UNET_DIR:-/opt/ai_models/sd_models/unet}"
WAN2GP_LORAS_DIR="${WAN2GP_LORAS_DIR:-/opt/ai_models/sd_models/loras}"

# Additional search directories (space-separated paths)
# These are searched in addition to the default directories
WAN2GP_ADDITIONAL_LORAS_DIRS="${WAN2GP_ADDITIONAL_LORAS_DIRS:-}"
WAN2GP_ADDITIONAL_CHECKPOINTS_DIRS="${WAN2GP_ADDITIONAL_CHECKPOINTS_DIRS:-}"
WAN2GP_ADDITIONAL_DIFFUSION_MODELS_DIRS="${WAN2GP_ADDITIONAL_DIFFUSION_MODELS_DIRS:-}"
WAN2GP_ADDITIONAL_TEXT_ENCODERS_DIRS="${WAN2GP_ADDITIONAL_TEXT_ENCODERS_DIRS:-}"
WAN2GP_ADDITIONAL_UNET_DIRS="${WAN2GP_ADDITIONAL_UNET_DIRS:-}"

# Initialize all LoRA directory variables (use empty string if not set)
# This ensures they're all defined, even if not configured
WAN2GP_LORA_WAN_DEFAULT="${WAN2GP_LORA_WAN_DEFAULT:-}"
WAN2GP_LORA_DIR_WAN_5B="${WAN2GP_LORA_DIR_WAN_5B:-}"
WAN2GP_LORA_DIR_WAN_1_3B="${WAN2GP_LORA_DIR_WAN_1_3B:-}"
WAN2GP_LORA_DIR_I2V="${WAN2GP_LORA_DIR_I2V:-}"
WAN2GP_LORA_DIR_WAN_I2V="${WAN2GP_LORA_DIR_WAN_I2V:-}"
WAN2GP_LORA_DIR_HUNYUAN="${WAN2GP_LORA_DIR_HUNYUAN:-}"
WAN2GP_LORA_DIR_HUNYUAN_I2V="${WAN2GP_LORA_DIR_HUNYUAN_I2V:-}"
WAN2GP_LORA_DIR_LTXV="${WAN2GP_LORA_DIR_LTXV:-}"
WAN2GP_LORA_DIR_LTX2="${WAN2GP_LORA_DIR_LTX2:-}"
WAN2GP_LORA_DIR_FLUX="${WAN2GP_LORA_DIR_FLUX:-}"
WAN2GP_LORA_DIR_FLUX2="${WAN2GP_LORA_DIR_FLUX2:-}"
WAN2GP_LORA_DIR_FLUX2_KLEIN_4B="${WAN2GP_LORA_DIR_FLUX2_KLEIN_4B:-}"
WAN2GP_LORA_DIR_FLUX2_KLEIN_9B="${WAN2GP_LORA_DIR_FLUX2_KLEIN_9B:-}"
WAN2GP_LORA_DIR_QWEN="${WAN2GP_LORA_DIR_QWEN:-}"
WAN2GP_LORA_DIR_Z_IMAGE="${WAN2GP_LORA_DIR_Z_IMAGE:-}"
WAN2GP_LORA_DIR_TTS="${WAN2GP_LORA_DIR_TTS:-}"

# Initialize all additional LoRA directory variables
WAN2GP_ADDITIONAL_LORA_DIR="${WAN2GP_ADDITIONAL_LORA_DIR:-}"
WAN2GP_ADDITIONAL_LORA_DIR_WAN_5B="${WAN2GP_ADDITIONAL_LORA_DIR_WAN_5B:-}"
WAN2GP_ADDITIONAL_LORA_DIR_WAN_1_3B="${WAN2GP_ADDITIONAL_LORA_DIR_WAN_1_3B:-}"
WAN2GP_ADDITIONAL_LORA_DIR_I2V="${WAN2GP_ADDITIONAL_LORA_DIR_I2V:-}"
WAN2GP_ADDITIONAL_LORA_DIR_WAN_I2V="${WAN2GP_ADDITIONAL_LORA_DIR_WAN_I2V:-}"
WAN2GP_ADDITIONAL_LORA_DIR_HUNYUAN="${WAN2GP_ADDITIONAL_LORA_DIR_HUNYUAN:-}"
WAN2GP_ADDITIONAL_LORA_DIR_HUNYUAN_I2V="${WAN2GP_ADDITIONAL_LORA_DIR_HUNYUAN_I2V:-}"
WAN2GP_ADDITIONAL_LORA_DIR_LTXV="${WAN2GP_ADDITIONAL_LORA_DIR_LTXV:-}"
WAN2GP_ADDITIONAL_LORA_DIR_LTX2="${WAN2GP_ADDITIONAL_LORA_DIR_LTX2:-}"
WAN2GP_ADDITIONAL_LORA_DIR_FLUX="${WAN2GP_ADDITIONAL_LORA_DIR_FLUX:-}"
WAN2GP_ADDITIONAL_LORA_DIR_FLUX2="${WAN2GP_ADDITIONAL_LORA_DIR_FLUX2:-}"
WAN2GP_ADDITIONAL_LORA_DIR_FLUX2_KLEIN_4B="${WAN2GP_ADDITIONAL_LORA_DIR_FLUX2_KLEIN_4B:-}"
WAN2GP_ADDITIONAL_LORA_DIR_FLUX2_KLEIN_9B="${WAN2GP_ADDITIONAL_LORA_DIR_FLUX2_KLEIN_9B:-}"
WAN2GP_ADDITIONAL_LORA_DIR_QWEN="${WAN2GP_ADDITIONAL_LORA_DIR_QWEN:-}"
WAN2GP_ADDITIONAL_LORA_DIR_Z_IMAGE="${WAN2GP_ADDITIONAL_LORA_DIR_Z_IMAGE:-}"
WAN2GP_ADDITIONAL_LORA_DIR_TTS="${WAN2GP_ADDITIONAL_LORA_DIR_TTS:-}"

WAN2GP_EXTRA_ARGS="${WAN2GP_EXTRA_ARGS:-}"
WAN2GP_LORAS_ROOT="${WAN2GP_LORAS_ROOT:-}"  # Root loras directory (optional, for auto-discovery)

# Function to expand directory paths with subdirectories
# If a directory path contains subdirectories, this will add them all
# Used for additional model directories that might have subdirectories
expand_model_dirs() {
    local base_dir="$1"
    local include_root="${2:-true}"  # Include the root directory by default
    
    # Always include the root directory if requested, regardless of existence
    # Let Wan2GP handle missing directories
    if [[ "$include_root" == "true" ]]; then
        echo "$base_dir"
    fi
    
    # If directory exists, also include immediate subdirectories (excluding hidden dirs like .cache)
    if [[ -d "$base_dir" ]]; then
        # Find all subdirectories (one level deep, excluding hidden directories starting with .)
        find "$base_dir" -maxdepth 1 -mindepth 1 -type d ! -name ".*" -printf '%p\n' 2>/dev/null | sort
    fi
}
CMD=("$WAN2GP_DIR/wgp.py")

# Add network configuration
[[ -n "$WAN2GP_SERVER_NAME" ]] && CMD+=(--server-name "$WAN2GP_SERVER_NAME")
[[ -n "$WAN2GP_SERVER_PORT" ]] && CMD+=(--server-port "$WAN2GP_SERVER_PORT")

# Helper function to add LoRA directories with subdirectory expansion
add_lora_arg() {
    local lora_arg="$1"
    local lora_path="$2"
    local additional_paths="$3"
    local debug_name="$4"  # For logging purposes
    
    if [[ -z "$lora_path" && -z "$additional_paths" ]]; then
        return
    fi
    
    # Build list with subdirectories expanded
    local paths_to_add=""
    
    # Add main path with subdirectories
    if [[ -n "$lora_path" ]]; then
        while IFS= read -r expanded_dir; do
            [[ -n "$expanded_dir" ]] && paths_to_add="$paths_to_add:$expanded_dir"
        done < <(expand_model_dirs "$lora_path" "true")
    fi
    
    # Add additional paths with subdirectories
    if [[ -n "$additional_paths" ]]; then
        while IFS=':' read -r add_path; do
            if [[ -n "$add_path" ]]; then
                while IFS= read -r expanded_dir; do
                    [[ -n "$expanded_dir" ]] && paths_to_add="$paths_to_add:$expanded_dir"
                done < <(expand_model_dirs "$add_path" "true")
            fi
        done <<< "$additional_paths"
    fi
    
    # Remove leading colon and add argument
    paths_to_add="${paths_to_add#:}"
    if [[ -n "$paths_to_add" ]]; then
        CMD+=("$lora_arg" "$paths_to_add")
        # Log what was added - make it visible at DEBUG_LEVEL 1+
        if [[ -n "$debug_name" ]]; then
            {
                echo "  ✓ $debug_name"
                if [[ $DEBUG_LEVEL -ge 2 ]]; then
                    echo "      Paths: $paths_to_add"
                fi
            } >&2
        fi
    elif [[ $DEBUG_LEVEL -ge 2 && -n "$debug_name" ]]; then
        # Show at debug level 2+ even if not set (to understand why a model isn't configured)
        {
            echo "  ✗ $debug_name (no directory configured)"
        } >&2
    fi
}

# Add LoRA directories for each model type (with subdirectory expansion)
# Log a section header when debug level is 1+
if [[ $DEBUG_LEVEL -ge 1 ]]; then
    {
        echo "╔════════════════════════════════════════════════════════════════════════════════╗"
        echo "║                    CONFIGURING LORA DIRECTORIES                               ║"
        echo "╚════════════════════════════════════════════════════════════════════════════════╝"
        echo ""
    } >&2
fi

# Root loras directory (optional - used for auto-discovery of model-specific subfolders)
if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
    CMD+=(--loras "$WAN2GP_LORAS_ROOT")
    if [[ $DEBUG_LEVEL -ge 1 ]]; then
        echo "  ✓ Root LoRAs (--loras)"
    fi
fi

# Wan t2v (default loras/wan)
add_lora_arg "--lora-dir" "$WAN2GP_LORA_WAN_DEFAULT" "$WAN2GP_ADDITIONAL_LORA_DIR" "Wan t2v (--lora-dir)"

# Wan 5B (default loras/wan_5B)
add_lora_arg "--lora-dir-wan-5b" "$WAN2GP_LORA_DIR_WAN_5B" "$WAN2GP_ADDITIONAL_LORA_DIR_WAN_5B" "Wan 5B (--lora-dir-wan-5b)"

# Wan 1.3B (default loras/wan_1.3B)
add_lora_arg "--lora-dir-wan-1-3b" "$WAN2GP_LORA_DIR_WAN_1_3B" "$WAN2GP_ADDITIONAL_LORA_DIR_WAN_1_3B" "Wan 1.3B (--lora-dir-wan-1-3b)"

# Wan i2v (default loras/wan_i2v)
add_lora_arg "--lora-dir-i2v" "$WAN2GP_LORA_DIR_I2V" "$WAN2GP_ADDITIONAL_LORA_DIR_I2V" "Wan i2v (--lora-dir-i2v)"

# Wan i2v alternate (default loras/wan_i2v)
add_lora_arg "--lora-dir-wan-i2v" "$WAN2GP_LORA_DIR_WAN_I2V" "$WAN2GP_ADDITIONAL_LORA_DIR_WAN_I2V" "Wan i2v Alt (--lora-dir-wan-i2v)"

# Hunyuan t2v (default loras/hunyuan)
add_lora_arg "--lora-dir-hunyuan" "$WAN2GP_LORA_DIR_HUNYUAN" "$WAN2GP_ADDITIONAL_LORA_DIR_HUNYUAN" "Hunyuan t2v (--lora-dir-hunyuan)"

# Hunyuan i2v (default loras/hunyuan_i2v)
add_lora_arg "--lora-dir-hunyuan-i2v" "$WAN2GP_LORA_DIR_HUNYUAN_I2V" "$WAN2GP_ADDITIONAL_LORA_DIR_HUNYUAN_I2V" "Hunyuan i2v (--lora-dir-hunyuan-i2v)"

# LTX Video (default loras/ltxv)
add_lora_arg "--lora-dir-ltxv" "$WAN2GP_LORA_DIR_LTXV" "$WAN2GP_ADDITIONAL_LORA_DIR_LTXV" "LTX Video (--lora-dir-ltxv)"

# LTX-2 (default loras/ltx2)
add_lora_arg "--lora-dir-ltx2" "$WAN2GP_LORA_DIR_LTX2" "$WAN2GP_ADDITIONAL_LORA_DIR_LTX2" "LTX-2 (--lora-dir-ltx2)"

# Flux (default loras/flux)
add_lora_arg "--lora-dir-flux" "$WAN2GP_LORA_DIR_FLUX" "$WAN2GP_ADDITIONAL_LORA_DIR_FLUX" "Flux (--lora-dir-flux)"

# Flux2 (default loras/flux2)
add_lora_arg "--lora-dir-flux2" "$WAN2GP_LORA_DIR_FLUX2" "$WAN2GP_ADDITIONAL_LORA_DIR_FLUX2" "Flux2 (--lora-dir-flux2)"

# Flux2 Klein 4B (default loras/flux2_klein_4b)
add_lora_arg "--lora-dir-flux2-klein-4b" "$WAN2GP_LORA_DIR_FLUX2_KLEIN_4B" "$WAN2GP_ADDITIONAL_LORA_DIR_FLUX2_KLEIN_4B" "Flux2 Klein 4B (--lora-dir-flux2-klein-4b)"

# Flux2 Klein 9B (default loras/flux2_klein_9b)
add_lora_arg "--lora-dir-flux2-klein-9b" "$WAN2GP_LORA_DIR_FLUX2_KLEIN_9B" "$WAN2GP_ADDITIONAL_LORA_DIR_FLUX2_KLEIN_9B" "Flux2 Klein 9B (--lora-dir-flux2-klein-9b)"

# Qwen (default loras/qwen)
add_lora_arg "--lora-dir-qwen" "$WAN2GP_LORA_DIR_QWEN" "$WAN2GP_ADDITIONAL_LORA_DIR_QWEN" "Qwen (--lora-dir-qwen)"

# Z-Image (default loras/z_image)
add_lora_arg "--lora-dir-z-image" "$WAN2GP_LORA_DIR_Z_IMAGE" "$WAN2GP_ADDITIONAL_LORA_DIR_Z_IMAGE" "Z-Image (--lora-dir-z-image)"

# TTS (default loras/tts)
add_lora_arg "--lora-dir-tts" "$WAN2GP_LORA_DIR_TTS" "$WAN2GP_ADDITIONAL_LORA_DIR_TTS" "TTS (--lora-dir-tts)"

# Optional: Load a specific LoRA preset on startup
[[ -n "$WAN2GP_LORA_PRESET" ]] && CMD+=(--lora-preset "$WAN2GP_LORA_PRESET")

# Optional: Check LoRAs for compatibility (slower startup)
[[ -n "$WAN2GP_CHECK_LORAS" && "$WAN2GP_CHECK_LORAS" == "1" ]] && CMD+=(--check-loras)

# Performance options (if set in environment)
[[ -n "$WAN2GP_PROFILE" ]] && CMD+=(--profile "$WAN2GP_PROFILE")
[[ -n "$WAN2GP_ATTENTION" ]] && CMD+=(--attention "$WAN2GP_ATTENTION")
[[ -n "$WAN2GP_FP16" && "$WAN2GP_FP16" == "1" ]] && CMD+=(--fp16)
[[ -n "$WAN2GP_COMPILE" && "$WAN2GP_COMPILE" == "1" ]] && CMD+=(--compile)

# TeaCache optimization (if set)
if [[ -n "$WAN2GP_TEACACHE" ]]; then
    CMD+=(--teacache "$WAN2GP_TEACACHE")
    log "DEBUG" "✓ Added TeaCache: --teacache $WAN2GP_TEACACHE"
    log "DEBUG" "CMD array now has ${#CMD[@]} elements"
else
    log "DEBUG" "✗ TeaCache not set (WAN2GP_TEACACHE is empty or not defined)"
    log "DEBUG" "CMD array has ${#CMD[@]} elements"
fi

# Generation defaults (if set)
[[ -n "$WAN2GP_SEED" && "$WAN2GP_SEED" != "-1" ]] && CMD+=(--seed "$WAN2GP_SEED")
[[ -n "$WAN2GP_STEPS" && "$WAN2GP_STEPS" != "0" ]] && CMD+=(--steps "$WAN2GP_STEPS")
[[ -n "$WAN2GP_FRAMES" && "$WAN2GP_FRAMES" != "0" ]] && CMD+=(--frames "$WAN2GP_FRAMES")

# Add verbose flag for Wan2GP if set
if [[ -n "$WAN2GP_VERBOSE" ]]; then
    CMD+=(--verbose "$WAN2GP_VERBOSE")
fi

# Add any additional arguments from environment variable
if [[ -n "$WAN2GP_EXTRA_ARGS" ]]; then
    # shellcheck disable=SC2206
    CMD+=($WAN2GP_EXTRA_ARGS)
fi

# Show constructed command arguments in debug mode
if [[ $DEBUG_LEVEL -ge 2 ]]; then
    {
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════════╗"
        echo "║                    CONSTRUCTED PYTHON ARGUMENTS                               ║"
        echo "╚════════════════════════════════════════════════════════════════════════════════╝"
        echo "Total arguments: ${#CMD[@]}"
        echo ""
        local i
        for i in "${!CMD[@]}"; do
            printf "  [%3d] %s\n" "$i" "${CMD[$i]}"
        done
        echo ""
    } >&2
fi

# Log the startup information
log "INFO" "=================================================================================="
log "INFO" "Starting Wan2GP from $WAN2GP_DIR"
log "INFO" "Server: $WAN2GP_SERVER_NAME:$WAN2GP_SERVER_PORT"
log "INFO" "=================================================================================="

# Debug level 1+ : Log ALL environment variables (set or not) with clear formatting
if [[ $DEBUG_LEVEL -ge 1 ]]; then
    {
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════════╗"
        echo "║                      WAN2GP ENVIRONMENT CONFIGURATION                         ║"
        echo "╚════════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "DEBUG LEVEL: $DEBUG_LEVEL (set WAN2GP_DEBUG_LEVEL for values: 0=minimal, 1=info, 2=enhanced, 3=max)"
        echo "VERBOSE:     $WAN2GP_VERBOSE"
        echo ""
        echo "┌─ LoRA Directories (Model-Specific) ─────────────────────────────────────────────┐"
        echo "│                                                                                 │"
        
        # Show Root LoRAs at the top
        if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
            echo -e "\033[32m│ ✓ Root LoRAs (--loras)\033[0m"
            echo -e "\033[32m│   → $WAN2GP_LORAS_ROOT\033[0m"
        fi
        
        echo "│"
        
        # Show each LoRA directory with clear status
        if [[ -n "$WAN2GP_LORA_WAN_DEFAULT" ]]; then
            echo -e "\033[33m│ ✓ Wan t2v (WAN2GP_LORA_WAN_DEFAULT)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_WAN_DEFAULT\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Wan t2v - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/wan)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Wan t2v (WAN2GP_LORA_WAN_DEFAULT) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_WAN_5B" ]]; then
            echo -e "\033[33m│ ✓ Wan 5B (WAN2GP_LORA_DIR_WAN_5B)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_WAN_5B\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Wan 5B - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/wan_5b)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Wan 5B (WAN2GP_LORA_DIR_WAN_5B) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_WAN_1_3B" ]]; then
            echo -e "\033[33m│ ✓ Wan 1.3B (WAN2GP_LORA_DIR_WAN_1_3B)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_WAN_1_3B\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Wan 1.3B - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/wan_1.3b)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Wan 1.3B (WAN2GP_LORA_DIR_WAN_1_3B) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_I2V" ]]; then
            echo -e "\033[33m│ ✓ Wan i2v (WAN2GP_LORA_DIR_I2V)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_I2V\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Wan i2v - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/wan_i2v)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Wan i2v (WAN2GP_LORA_DIR_I2V) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_WAN_I2V" ]]; then
            echo -e "\033[33m│ ✓ Wan i2v Alt (WAN2GP_LORA_DIR_WAN_I2V)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_WAN_I2V\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Wan i2v Alt - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/wan_i2v)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Wan i2v Alt (WAN2GP_LORA_DIR_WAN_I2V) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_HUNYUAN" ]]; then
            echo -e "\033[33m│ ✓ Hunyuan t2v (WAN2GP_LORA_DIR_HUNYUAN)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_HUNYUAN\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Hunyuan t2v - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/hunyuan)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Hunyuan t2v (WAN2GP_LORA_DIR_HUNYUAN) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_HUNYUAN_I2V" ]]; then
            echo -e "\033[33m│ ✓ Hunyuan i2v (WAN2GP_LORA_DIR_HUNYUAN_I2V)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_HUNYUAN_I2V\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Hunyuan i2v - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/hunyuan_i2v)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Hunyuan i2v (WAN2GP_LORA_DIR_HUNYUAN_I2V) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_LTXV" ]]; then
            echo -e "\033[33m│ ✓ LTX Video (WAN2GP_LORA_DIR_LTXV)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_LTXV\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ LTX Video - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/ltxv)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ LTX Video (WAN2GP_LORA_DIR_LTXV) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_FLUX" ]]; then
            echo -e "\033[33m│ ✓ Flux (WAN2GP_LORA_DIR_FLUX)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_FLUX\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Flux - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/flux)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Flux (WAN2GP_LORA_DIR_FLUX) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_FLUX2" ]]; then
            echo -e "\033[33m│ ✓ Flux2 (WAN2GP_LORA_DIR_FLUX2)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_FLUX2\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Flux2 - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/flux2)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Flux2 (WAN2GP_LORA_DIR_FLUX2) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_LTX2" ]]; then
            echo -e "\033[33m│ ✓ LTX-2 (WAN2GP_LORA_DIR_LTX2)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_LTX2\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ LTX-2 - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/ltx2)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ LTX-2 (WAN2GP_LORA_DIR_LTX2) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_FLUX2_KLEIN_4B" ]]; then
            echo -e "\033[33m│ ✓ Flux2 Klein 4B (WAN2GP_LORA_DIR_FLUX2_KLEIN_4B)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_FLUX2_KLEIN_4B\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Flux2 Klein 4B - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/flux2_klein_4b)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Flux2 Klein 4B (WAN2GP_LORA_DIR_FLUX2_KLEIN_4B) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_FLUX2_KLEIN_9B" ]]; then
            echo -e "\033[33m│ ✓ Flux2 Klein 9B (WAN2GP_LORA_DIR_FLUX2_KLEIN_9B)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_FLUX2_KLEIN_9B\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Flux2 Klein 9B - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/flux2_klein_9b)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Flux2 Klein 9B (WAN2GP_LORA_DIR_FLUX2_KLEIN_9B) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_QWEN" ]]; then
            echo -e "\033[33m│ ✓ Qwen (WAN2GP_LORA_DIR_QWEN)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_QWEN\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Qwen - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/qwen)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Qwen (WAN2GP_LORA_DIR_QWEN) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_Z_IMAGE" ]]; then
            echo -e "\033[33m│ ✓ Z-Image (WAN2GP_LORA_DIR_Z_IMAGE)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_Z_IMAGE\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ Z-Image - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/z_image)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ Z-Image (WAN2GP_LORA_DIR_Z_IMAGE) - NOT SET\033[0m"
            fi
        fi
        
        if [[ -n "$WAN2GP_LORA_DIR_TTS" ]]; then
            echo -e "\033[33m│ ✓ TTS (WAN2GP_LORA_DIR_TTS)\033[0m"
            echo -e "\033[33m│   → $WAN2GP_LORA_DIR_TTS\033[0m"
        else
            if [[ -n "$WAN2GP_LORAS_ROOT" ]]; then
                echo -e "\033[32m│ ○ TTS - Using LoRA Root Default ($WAN2GP_LORAS_ROOT/tts)\033[0m"
            else
                echo -e "\033[38;5;208m│ ✗ TTS (WAN2GP_LORA_DIR_TTS) - NOT SET\033[0m"
            fi
        fi
        
        echo "│                                                                                 │"
        echo "└─────────────────────────────────────────────────────────────────────────────────┘"
        echo ""
        
        # Show other settings
        echo "Server Configuration:"
        echo "  Name: $WAN2GP_SERVER_NAME"
        echo "  Port: $WAN2GP_SERVER_PORT"
        echo ""
        
        # Show optional settings if set
        if [[ -n "$WAN2GP_PROFILE" ]]; then echo "  Profile: $WAN2GP_PROFILE"; fi
        if [[ -n "$WAN2GP_ATTENTION" ]]; then echo "  Attention: $WAN2GP_ATTENTION"; fi
        if [[ "$WAN2GP_FP16" == "1" ]]; then echo "  FP16: ENABLED"; fi
        if [[ "$WAN2GP_COMPILE" == "1" ]]; then echo "  Compile: ENABLED"; fi
        if [[ -n "$WAN2GP_TEACACHE" ]]; then echo "  TeaCache: $WAN2GP_TEACACHE"; fi
        
        if [[ -n "$WAN2GP_EXTRA_ARGS" ]]; then
            echo ""
            echo "Extra Arguments: $WAN2GP_EXTRA_ARGS"
        fi
        
        echo ""
        echo "────────────────────────────────────────────────────────────────────────────────────"
        echo ""
    } >&2
fi

# Debug level 2+ : Enhanced configuration logging
if [[ $DEBUG_LEVEL -ge 2 ]]; then
    {
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════════╗"
        echo "║                    ENHANCED DEBUG INFORMATION                                 ║"
        echo "╚════════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Conda Environment: $CONDA_DIR/wan2gp"
        echo "Working Directory: $WAN2GP_DIR"
        echo "Config File: $ENV_FILE"
        echo ""
        echo "Runtime Configuration:"
        echo "  Verbose Level: ${WAN2GP_VERBOSE:-not set (default)}"
        echo "  Server Port: $WAN2GP_SERVER_PORT"
        echo "  Server Name: $WAN2GP_SERVER_NAME"
        echo ""
        
        if [[ -n "$WAN2GP_PROFILE" || -n "$WAN2GP_ATTENTION" || -n "$WAN2GP_FP16" || -n "$WAN2GP_COMPILE" || -n "$WAN2GP_TEACACHE" ]]; then
            echo "Performance Settings:"
            [[ -n "$WAN2GP_PROFILE" ]] && echo "  Profile: $WAN2GP_PROFILE"
            [[ -n "$WAN2GP_ATTENTION" ]] && echo "  Attention: $WAN2GP_ATTENTION"
            [[ "$WAN2GP_FP16" == "1" ]] && echo "  FP16: ENABLED"
            [[ "$WAN2GP_COMPILE" == "1" ]] && echo "  Compile: ENABLED"
            [[ -n "$WAN2GP_TEACACHE" ]] && echo "  TeaCache: $WAN2GP_TEACACHE"
            echo ""
        fi
        
        if [[ -n "$WAN2GP_SEED" && "$WAN2GP_SEED" != "-1" ]]; then
            echo "Generation Defaults:"
            echo "  Seed: $WAN2GP_SEED"
            [[ -n "$WAN2GP_STEPS" && "$WAN2GP_STEPS" != "0" ]] && echo "  Steps: $WAN2GP_STEPS"
            [[ -n "$WAN2GP_FRAMES" && "$WAN2GP_FRAMES" != "0" ]] && echo "  Frames: $WAN2GP_FRAMES"
            echo ""
        fi
        
        echo "────────────────────────────────────────────────────────────────────────────────────"
        echo ""
    } >&2
fi

# Debug level 3+ : Maximum logging with full command
if [[ $DEBUG_LEVEL -ge 3 ]]; then
    {
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════════╗"
        echo "║                    MAXIMUM DEBUG INFORMATION                                  ║"
        echo "╚════════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Full Python command array (${#CMD[@]} arguments):"
        local i
        for i in "${!CMD[@]}"; do
            printf "  [%2d] %s\n" "$i" "${CMD[$i]}"
        done
        echo ""
        echo "Environment Paths:"
        echo "  CONDA_DIR=$CONDA_DIR"
        echo "  REPO_ROOT=$REPO_ROOT"
        echo "  SCRIPT_DIR=$SCRIPT_DIR"
        echo "  WAN2GP_DIR=$WAN2GP_DIR"
        echo ""
        echo "Conda Environment Details:"
        echo "  Conda Path: $CONDA_CMD"
        echo "  Env Name: wan2gp"
        echo "  Will execute: $CONDA_CMD run -p $CONDA_DIR/wan2gp python ..."
        echo ""
        echo "────────────────────────────────────────────────────────────────────────────────────"
        echo ""
    } >&2
fi

# ============================================================================
# TEST MODE: Exit early if test mode is enabled - DO NOT EXECUTE ANYTHING
# ============================================================================
if [[ $TEST_MODE -eq 1 ]]; then
    {
        echo ""
        echo "════════════════════════════════════════════════════════════════════════════════════"
        echo "[TEST MODE] Script in test mode - command will NOT be executed"
        echo "════════════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Command that would be executed:"
        echo ""
        echo "  $CONDA_CMD run -p $CONDA_DIR/wan2gp python ${CMD[*]}"
        echo ""
        echo "════════════════════════════════════════════════════════════════════════════════════"
        echo ""
    } >&2
    log "INFO" "TEST MODE: Exiting without execution"
    exit 0
fi

# ============================================================================
# PRODUCTION MODE: Only code below this point executes in production
# ============================================================================

# Execute Wan2GP using conda run
cd "$WAN2GP_DIR" || {
    log "ERROR" "Failed to change to Wan2GP directory: $WAN2GP_DIR"
    exit 1
}

{
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════════"
    echo "Starting Wan2GP server at http://$WAN2GP_SERVER_NAME:$WAN2GP_SERVER_PORT"
    if [[ $DEBUG_LEVEL -ge 1 ]]; then
        echo "[DEBUG MODE ENABLED - Level $DEBUG_LEVEL]"
        echo ""
        echo "EXECUTING COMMAND:"
        echo "  $CONDA_CMD run -p $CONDA_DIR/wan2gp python ${CMD[*]}"
        echo ""
        if [[ $DEBUG_LEVEL -ge 2 ]]; then
            echo "CMD Array Contents (${#CMD[@]} elements total):"
            for i in "${!CMD[@]}"; do
                echo "  [$i]: '${CMD[$i]}'"
            done
            echo ""
        fi
    fi
    echo "════════════════════════════════════════════════════════════════════════════════════"
    echo ""
} >&2

log "DEBUG" "About to execute with CMD array containing ${#CMD[@]} elements"
# Verify teacache is in the array
if [[ " ${CMD[*]} " =~ " --teacache " ]]; then
    log "DEBUG" "✓ CONFIRMED: --teacache is in CMD array"
else
    log "DEBUG" "✗ ERROR: --teacache is NOT in CMD array!"
fi

exec "$CONDA_CMD" run -p "$CONDA_DIR/wan2gp" python "${CMD[@]}"
