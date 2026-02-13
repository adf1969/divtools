#!/bin/bash
# Checks a file for LoRA references and verifies they exist in the specified path
# Last Updated: 01/29/2026 11:00:00 AM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default values
TEST_MODE=0
DEBUG_MODE=0
FILE_TO_CHECK=""
LORA_PATH=""

# Color codes
RED='\033[31m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <file_to_check>

OPTIONS:
  -f, --file, -file <file>           File to check for LoRA references
  -l, -p, --lora-path, -lora-path     Root path to LoRAs directory
  -t, --test, -test                  Run in test mode (no permanent changes)
  -d, --debug, -debug                Enable debug mode
  -h, --help                          Show this help message

EXAMPLES:
  # Using short options
  $(basename "$0") -f myfile.txt -l /path/to/loras
  
  # Using long options with -- prefix
  $(basename "$0") --file myfile.txt --lora-path /path/to/loras --debug
  
  # Using long options with - prefix
  $(basename "$0") -file myfile.txt -lora-path /path/to/loras
  
  # Using positional argument for file, named options for path
  $(basename "$0") myfile.txt -l /path/to/loras
  
  # With test and debug modes
  $(basename "$0") -f myfile.txt -l /path/to/loras -t -d
  
  # Mixed short and long options
  $(basename "$0") --file myfile.txt -l /path/to/loras --debug
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file|-file)
            FILE_TO_CHECK="$2"
            shift 2
            ;;
        -l|-p|--lora-path|-lora-path)
            LORA_PATH="$2"
            shift 2
            ;;
        -t|--test|-test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode"
            shift
            ;;
        -d|--debug|-debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        -h|--help|-help|-u|--usage|-usage)
            show_usage
            exit 0
            ;;
        *)
            # If it's not a flag, treat it as the file to check
            if [[ ! "$1" =~ ^- ]]; then
                FILE_TO_CHECK="$1"
                shift
            else
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
            fi
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FILE_TO_CHECK" ]]; then
    log "ERROR" "File to check is required"
    show_usage
    exit 1
fi

if [[ -z "$LORA_PATH" ]]; then
    log "ERROR" "LoRA path is required"
    show_usage
    exit 1
fi

# Validate file exists
if [[ ! -f "$FILE_TO_CHECK" ]]; then
    log "ERROR" "File not found: $FILE_TO_CHECK"
    exit 1
fi

# Validate lora path exists
if [[ ! -d "$LORA_PATH" ]]; then
    log "ERROR" "LoRA path not found: $LORA_PATH"
    exit 1
fi

log "DEBUG" "File to check: $FILE_TO_CHECK"
log "DEBUG" "LoRA path: $LORA_PATH"

# Function to find LoRA file
find_lora() {
    local lora_name="$1"
    local lora_path="$2"
    
    # Search for files matching the lora name with common extensions
    # Supports: .safetensors, .ckpt, .pt, .pth, .bin, .onnx, and files without extension
    find "$lora_path" -type f \( \
        -name "${lora_name}" \
        -o -name "${lora_name}.safetensors" \
        -o -name "${lora_name}.sft" \
        -o -name "${lora_name}.ckpt" \
        -o -name "${lora_name}.pt" \
        -o -name "${lora_name}.pth" \
        -o -name "${lora_name}.bin" \
        -o -name "${lora_name}.onnx" \
    \) 2>/dev/null | head -n1
}

# Function to extract LoRA references from content
extract_loras() {
    local content="$1"
    # Find all matches of <lora:filename:...>
    echo "$content" | grep -oP '<lora:\K[^:]+' || true
}

# Function to process file without sections
process_without_sections() {
    local file="$1"
    local lora_path="$2"
    
    log "DEBUG" "Processing file without sections"
    
    # Read entire file
    local content=$(cat "$file")
    
    # Extract all LoRA references
    local loras=$(extract_loras "$content")
    
    if [[ -z "$loras" ]]; then
        log "INFO" "No LoRA references found in file"
        return
    fi
    
    # Process each LoRA
    while IFS= read -r lora_file; do
        if [[ -n "$lora_file" ]]; then
            local found_path=$(find_lora "$lora_file" "$lora_path")
            
            if [[ -n "$found_path" ]]; then
                log "INFO" "$lora_file: Found in $found_path"
            else
                echo -e "${RED}$lora_file: NOT FOUND${NC}"
            fi
        fi
    done <<< "$loras"
}

# Function to process file with sections
process_with_sections() {
    local file="$1"
    local lora_path="$2"
    
    log "DEBUG" "Processing file with sections"
    
    local content=$(cat "$file")
    local current_section=""
    local section_loras=()
    declare -A section_data
    
    # Parse sections
    local section_num=0
    while IFS= read -r line; do
        # Check for section delimiter
        if [[ "$line" =~ ^=+$ ]]; then
            if [[ -n "$current_section" ]]; then
                section_data["$section_num"]="$current_section"
                ((section_num++))
            fi
            current_section=""
        else
            current_section+="$line"$'\n'
        fi
    done < "$file"
    
    # Add last section if exists
    if [[ -n "$current_section" ]]; then
        section_data["$section_num"]="$current_section"
    fi
    
    # Process each section
    for sec_num in "${!section_data[@]}"; do
        local sec_content="${section_data[$sec_num]}"
        local loras=$(extract_loras "$sec_content")
        
        if [[ -n "$loras" ]]; then
            echo ""
            echo "Section $sec_num:"
            
            while IFS= read -r lora_file; do
                if [[ -n "$lora_file" ]]; then
                    local found_path=$(find_lora "$lora_file" "$lora_path")
                    
                    if [[ -n "$found_path" ]]; then
                        log "INFO:raw" "  $lora_file: Found in $found_path"
                    else
                        echo -e "  ${RED}$lora_file: NOT FOUND${NC}"
                    fi
                fi
            done <<< "$loras"
        fi
    done
}

# Main logic
log "INFO" "Starting LoRA check"

# Check if file has section delimiters
if grep -q '^====' "$FILE_TO_CHECK"; then
    process_with_sections "$FILE_TO_CHECK" "$LORA_PATH"
else
    process_without_sections "$FILE_TO_CHECK" "$LORA_PATH"
fi

log "INFO" "LoRA check completed"
