#!/bin/bash
# Creates a lora tag file from ComfyUI lora .safetensors and .json metadata files
# Last Updated: 01/27/2026 10:30:00 AM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0
OUTPUT_FILE=""
SEARCH_PATH="."

# Function to display usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Creates a lora tag reference file from ComfyUI lora .safetensors and .json files

OPTIONS:
    -d, --debug             Enable debug output
    -t, --test              Test mode - simulate run without writing output
    -f, --output-file FILE  Path to output file (default: stdout)
    -p, --path PATH         Path to search for loras (default: current directory)
    -h, --help              Show this help message

EXAMPLES:
    $(basename "$0") -p /opt/ai_models/sd_models/loras
    $(basename "$0") -f loras.txt -p /opt/ai_models
    $(basename "$0") -d -t -p ./loras
    $(basename "$0") --debug --test --path ./loras

EOF

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        cat << 'EOF'

WARNING: jq is not installed
-----------
This script works best with jq installed for robust JSON parsing.
Without jq, the script will fall back to grep/sed which may not handle complex JSON correctly.

Install jq with one of these commands:
    Ubuntu/Debian:  sudo apt-get install -y jq
    CentOS/RHEL:    sudo yum install -y jq
    macOS:          brew install jq
    Alpine:         apk add --no-cache jq

EOF
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test|-t)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no output file will be written"
            shift
            ;;
        -debug|--debug|-d)
            DEBUG_MODE=1
            export DEBUG_MODE
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -output-file|--output-file|-f)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -path|--path|-p)
            SEARCH_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate search path
if [[ ! -d "$SEARCH_PATH" ]]; then
    log "ERROR" "Search path does not exist: $SEARCH_PATH"
    exit 1
fi

log "INFO" "Searching for loras in: $SEARCH_PATH"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE, OUTPUT_FILE=$OUTPUT_FILE"

# Function to extract JSON value using basic tools
# Args: $1 = json_file, $2 = field_path (e.g., "notes", "usage_tips.strength")
extract_json_field() {
    local json_file="$1"
    local field_path="$2"
    
    if [[ ! -f "$json_file" ]]; then
        log "DEBUG" "JSON file not found: $json_file"
        echo ""
        return
    fi
    
    # Check if jq is available
    if command -v jq &> /dev/null; then
        jq -r ".$field_path // empty" "$json_file" 2>/dev/null
    else
        # Fallback to grep/sed for simple fields
        case "$field_path" in
            "notes")
                grep -Po '"notes":\s*"\K[^"]*' "$json_file" 2>/dev/null | sed 's/\\n/\n/g'
                ;;
            "civitai.trainedWords")
                grep -Po '"trainedWords":\s*\[\K[^\]]*' "$json_file" 2>/dev/null | sed 's/"//g' | sed 's/,/, /g'
                ;;
            "usage_tips.strength"|"usage_tips.strength_min"|"usage_tips.strength_max")
                local field="${field_path##*.}"
                grep -Po "\"$field\":\s*\K[0-9.]+" "$json_file" 2>/dev/null
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

# Function to calculate recommended strength
# Args: $1 = strength, $2 = strength_min, $3 = strength_max
calculate_strength() {
    local strength="$1"
    local strength_min="$2"
    local strength_max="$3"
    
    log "DEBUG" "Calculating strength: str=$strength, min=$strength_min, max=$strength_max"
    
    # Both min and max specified
    if [[ -n "$strength_min" && -n "$strength_max" ]]; then
        echo "$strength_min - $strength_max"
        return
    fi
    
    # Only min specified and it's < 1
    if [[ -n "$strength_min" && -z "$strength_max" ]]; then
        if (( $(echo "$strength_min < 1" | bc -l 2>/dev/null || echo 0) )); then
            echo "$strength_min - 1.0"
            return
        fi
    fi
    
    # Only max specified and it's > 1
    if [[ -z "$strength_min" && -n "$strength_max" ]]; then
        if (( $(echo "$strength_max > 1" | bc -l 2>/dev/null || echo 0) )); then
            echo "1.0 - $strength_max"
            return
        fi
    fi
    
    # Use strength if available
    if [[ -n "$strength" ]]; then
        echo "$strength"
        return
    fi
    
    # Default
    echo "1.0"
}

# Function to get relative folder path
# Args: $1 = full_file_path, $2 = base_search_path
get_folder_name() {
    local file_path="$1"
    local base_path="$(cd "$2" && pwd)"
    local file_dir="$(dirname "$file_path")"
    local abs_file_dir="$(cd "$file_dir" && pwd)"
    
    if [[ "$abs_file_dir" == "$base_path" ]]; then
        echo "."
    else
        echo "${abs_file_dir#$base_path/}"
    fi
}

# Function to write header
write_header() {
    cat << 'EOF'
The following is a list of lora tags that can be used when building prompts.
Use the <lora> tags to indicate that lora.
Use the strength indicated to specify the default strength.
Review the Notes to see any special instructions about the lora and when they should be used.
When adding Loras to a prompt, adjust the strength as needed based on your prompt and desired effect.
Do not add more than 2 loras to a single prompt to avoid overloading the model.
In most cases, adding 1 is best.

EOF
}

# Function to process a single lora file
# Args: $1 = safetensors_file
process_lora() {
    local safetensors_file="$1"
    local base_name="${safetensors_file%.safetensors}"
    local json_file="${base_name}.metadata.json"
    local file_name="$(basename "$base_name")"
    local folder_name=$(get_folder_name "$safetensors_file" "$SEARCH_PATH")
    
    log "DEBUG" "Processing: $safetensors_file"
    log "DEBUG" "  JSON file: $json_file"
    log "DEBUG" "  Folder: $folder_name"
    
    # Check if JSON file exists
    if [[ ! -f "$json_file" ]]; then
        log "WARN" "No JSON metadata found for: $safetensors_file"
        return
    fi
    
    # Extract metadata
    local trained_words=$(extract_json_field "$json_file" "civitai.trainedWords")
    local notes=$(extract_json_field "$json_file" "notes")
    local strength=$(extract_json_field "$json_file" "usage_tips.strength")
    local strength_min=$(extract_json_field "$json_file" "usage_tips.strength_min")
    local strength_max=$(extract_json_field "$json_file" "usage_tips.strength_max")
    
    # Calculate recommended strength
    local recommended_strength=$(calculate_strength "$strength" "$strength_min" "$strength_max")
    
    log "DEBUG" "  Trained words: $trained_words"
    log "DEBUG" "  Recommended strength: $recommended_strength"
    
    # Output the lora entry
    cat << EOF
# $folder_name
<lora:$file_name:$recommended_strength>
Trained Words: $trained_words
Notes: $notes

EOF
}

# Main execution
main() {
    log "INFO" "Script execution started"
    
    # Find all .safetensors files
    local safetensors_files=()
    while IFS= read -r -d '' file; do
        safetensors_files+=("$file")
    done < <(find "$SEARCH_PATH" -type f -name "*.safetensors" -print0)
    
    log "INFO" "Found ${#safetensors_files[@]} lora files"
    
    if [[ ${#safetensors_files[@]} -eq 0 ]]; then
        log "WARN" "No .safetensors files found in $SEARCH_PATH"
        exit 0
    fi
    
    # Prepare output
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "TEST MODE: Output would be written to ${OUTPUT_FILE:-stdout}"
        log "INFO" "Processing files..."
        
        # Write to stdout in test mode
        write_header
        for lora_file in "${safetensors_files[@]}"; do
            process_lora "$lora_file"
        done
        
    elif [[ -z "$OUTPUT_FILE" ]]; then
        # Output to stdout
        log "DEBUG" "Writing to stdout"
        write_header
        for lora_file in "${safetensors_files[@]}"; do
            process_lora "$lora_file"
        done
        
    else
        # Output to file
        log "INFO" "Writing output to: $OUTPUT_FILE"
        {
            write_header
            for lora_file in "${safetensors_files[@]}"; do
                process_lora "$lora_file"
            done
        } > "$OUTPUT_FILE"
        
        log "INFO" "Output written successfully to: $OUTPUT_FILE"
    fi
    
    log "INFO" "Script execution completed"
}

# Run main function
main
