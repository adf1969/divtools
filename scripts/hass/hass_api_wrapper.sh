#!/bin/bash
# Home Assistant API Wrapper Script
# Provides bash interface to query Home Assistant entities and devices
# Last Updated: 11/20/2025 11:45:00 AM CDT

# Initialize environment variables from divtools configuration
DIVTOOLS="${DIVTOOLS:-/opt/divtools}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# Source bash_profile to access load_env_files function
if [[ -f "$DIVTOOLS/dotfiles/.bash_profile" ]]; then
    source "$DIVTOOLS/dotfiles/.bash_profile" 2>/dev/null || true
else
    # Fallback: try to find bash_profile in parent paths
    for try_path in /opt/divtools /usr/local/opt/divtools ~/divtools; do
        if [[ -f "$try_path/dotfiles/.bash_profile" ]]; then
            source "$try_path/dotfiles/.bash_profile" 2>/dev/null || true
            break
        fi
    done
fi

# Load environment files (this will populate HASS_API_TOKEN from docker/sites/$SITE_NAME/.env.$SITE_NAME)
if declare -f load_env_files > /dev/null 2>&1; then
    load_env_files 2>/dev/null || true
fi

# Configuration
HASS_URL="${HASS_URL:-http://10.1.1.215:8123}"
HASS_API_TOKEN="${HASS_API_TOKEN}"

# Source logging if available
if [[ -f "$SCRIPT_DIR/../util/logging.sh" ]]; then
    source "$SCRIPT_DIR/../util/logging.sh"
else
    # Simple fallback logging
    log() { local level=$1; shift; echo "[$level] $*" >&2; }
fi

# Parse global flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no permanent changes will be made"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Verify token is set
if [[ -z "$HASS_API_TOKEN" ]]; then
    log "ERROR" "HASS_API_TOKEN environment variable not set"
    log "ERROR" "Make sure HASS_API_TOKEN is defined in docker/sites/\$SITE_NAME/.env.\$SITE_NAME"
    exit 1
fi

# Helper: Make HTTP request to Home Assistant API
hass_api_call() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="$3"
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "API Call: $method $endpoint"
    fi
    
    local curl_opts=(
        -s
        -H "Authorization: Bearer $HASS_API_TOKEN"
        -H "Content-Type: application/json"
    )
    
    if [[ "$method" != "GET" ]]; then
        curl_opts+=(-X "$method")
    fi
    
    if [[ -n "$data" ]]; then
        curl_opts+=(-d "$data")
    fi
    
    local url="${HASS_URL}/api${endpoint}"
    local response=$(curl "${curl_opts[@]}" "$url")
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Response length: ${#response} bytes"
    fi
    
    echo "$response"
}

# Get all entities/states
hass_get_entities() {
    local filter="${1:-}"
    
    local response=$(hass_api_call "/states")
    
    if [[ -n "$filter" ]]; then
        echo "$response" | jq --raw-output ".[] | select(.entity_id | contains(\"$filter\")) | .entity_id"
    else
        echo "$response" | jq --raw-output ".[].entity_id"
    fi
}

# Get state of a specific entity
hass_get_entity_state() {
    local entity_id="$1"
    
    if [[ -z "$entity_id" ]]; then
        log "ERROR" "entity_id required"
        return 1
    fi
    
    hass_api_call "/states/$entity_id" | jq '.'
}

# List entities by type with optional area and output format filter
hass_list_entities_by_type() {
    local entity_type="$1"
    local area_filter=""
    local output_format="text"
    
    if [[ -z "$entity_type" ]]; then
        log "ERROR" "entity_type required (e.g., 'light', 'switch', 'sensor')"
        return 1
    fi
    
    # Parse optional arguments
    shift 2>/dev/null
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --area)
                area_filter="${2,,}"  # Convert to lowercase
                shift 2
                ;;
            --format)
                output_format="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "hass_list_entities_by_type: type=$entity_type, area=$area_filter, format=$output_format"
    fi
    
    local response=$(hass_api_call "/states")
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "States response length: ${#response}"
    fi
    
    # Build jq filter - filter by entity type
    local jq_string=".[] | select(.entity_id | startswith(\"${entity_type}.\"))"
    
    if [[ -n "$area_filter" ]]; then
        # Try to filter by area (may be in attributes.area or area_id)
        jq_string="${jq_string} | select((.attributes.area // .area_id // \"\") | ascii_downcase | contains(\"$area_filter\"))"
    fi
    
    # Process with jq based on output format
    case "$output_format" in
        json)
            printf '%s' "$response" | jq "[$jq_string]" 2>/dev/null || echo "[]"
            ;;
        csv)
            echo "entity_id,friendly_name,state"
            printf '%s' "$response" | jq -r "$jq_string | [.entity_id, (.attributes.friendly_name // .entity_id), .state] | @csv" 2>/dev/null
            ;;
        *)
            # Default: plain text, one per line
            printf '%s' "$response" | jq -r "$jq_string | .entity_id" 2>/dev/null
            ;;
    esac
}

# Get full entity details with state information
hass_get_entity_details() {
    local entity_type="$1"
    local area_filter=""
    local output_format="text"
    
    if [[ -z "$entity_type" ]]; then
        log "ERROR" "entity_type required"
        return 1
    fi
    
    # Parse optional arguments
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --area)
                area_filter="${2,,}"  # Convert to lowercase
                shift 2
                ;;
            --format)
                output_format="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "hass_get_entity_details: type=$entity_type, area=$area_filter, format=$output_format"
    fi
    
    local response=$(hass_api_call "/states")
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "States response length: ${#response}"
    fi
    
    case "$output_format" in
        json)
            # Extract relevant fields and format as JSON array - filter by entity type only
            if [[ -n "$area_filter" ]]; then
                printf '%s' "$response" | jq "[.[] | select(.entity_id | startswith(\"${entity_type}.\")) | select(.entity_id | contains(\"${area_filter}\")) | {friendly_name: (.attributes.friendly_name // .entity_id), entity_id, state, brightness: (.attributes.brightness // null), color_temp: (.attributes.color_temp // null), rgb_color: (.attributes.rgb_color // null)}] | sort_by(.friendly_name)" 2>/dev/null || echo "[]"
            else
                printf '%s' "$response" | jq "[.[] | select(.entity_id | startswith(\"${entity_type}.\")) | {friendly_name: (.attributes.friendly_name // .entity_id), entity_id, state, brightness: (.attributes.brightness // null), color_temp: (.attributes.color_temp // null), rgb_color: (.attributes.rgb_color // null)}] | sort_by(.friendly_name)" 2>/dev/null || echo "[]"
            fi
            ;;
        csv)
            echo "Friendly Name,Entity ID,State,Brightness,Color Temp,RGB Color"
            if [[ -n "$area_filter" ]]; then
                printf '%s' "$response" | jq -r ".[] | select(.entity_id | startswith(\"${entity_type}.\")) | select(.entity_id | contains(\"${area_filter}\")) | [(.attributes.friendly_name // .entity_id), .entity_id, .state, (.attributes.brightness // \"\"), (.attributes.color_temp // \"\"), (.attributes.rgb_color // \"\")] | @csv" 2>/dev/null
            else
                printf '%s' "$response" | jq -r ".[] | select(.entity_id | startswith(\"${entity_type}.\")) | [(.attributes.friendly_name // .entity_id), .entity_id, .state, (.attributes.brightness // \"\"), (.attributes.color_temp // \"\"), (.attributes.rgb_color // \"\")] | @csv" 2>/dev/null
            fi
            ;;
        text|*)
            # Markdown table format
            echo "| Friendly Name | Entity ID | State | Brightness | Color |"
            echo "|---|---|---|---|---|"
            if [[ -n "$area_filter" ]]; then
                printf '%s' "$response" | jq -r "[.[] | select(.entity_id | startswith(\"${entity_type}.\")) | select(.entity_id | contains(\"${area_filter}\"))] | sort_by(.attributes.friendly_name // .entity_id) | .[] | \"| \(.attributes.friendly_name // .entity_id) | \(.entity_id) | \(.state) | \(if .state == \"on\" and .attributes.brightness then ((.attributes.brightness / 255) * 100 | round | tostring + \"%\") else \"N/A\" end) | \(if .attributes.rgb_color then \"RGB\" elif .attributes.color_temp then (.attributes.color_temp | tostring) + \"K\" else \"N/A\" end) |\"" 2>/dev/null
            else
                printf '%s' "$response" | jq -r "[.[] | select(.entity_id | startswith(\"${entity_type}.\"))] | sort_by(.attributes.friendly_name // .entity_id) | .[] | \"| \(.attributes.friendly_name // .entity_id) | \(.entity_id) | \(.state) | \(if .state == \"on\" and .attributes.brightness then ((.attributes.brightness / 255) * 100 | round | tostring + \"%\") else \"N/A\" end) | \(if .attributes.rgb_color then \"RGB\" elif .attributes.color_temp then (.attributes.color_temp | tostring) + \"K\" else \"N/A\" end) |\"" 2>/dev/null
            fi
            ;;
    esac
}

# Print usage
print_usage() {
    cat <<EOF
Home Assistant API Wrapper Script

Usage: $0 [--debug|--test] <command> [arguments]

Global Options:
  --debug, -debug        Enable debug mode (shows API calls and responses)
  --test, -test          Enable test mode (no permanent changes)

Commands:
  entities [filter]                    List all entities (optionally filter by string)
  entity-state <entity_id>             Get state and attributes of an entity
  entities-by-type <type>              List entities by type (e.g., 'light', 'switch')
  entities-by-type <type> [--area <area>] [--format json|csv|text]
                                       List entities filtered by type and optionally by area
  entity-details <type> [--area <area>] [--format json|csv|text]
                                       Get full details for entities (state, brightness, color, etc.)

Environment Variables:
  HASS_URL                             Home Assistant URL (default: http://10.1.1.215:8123)
  HASS_API_TOKEN                       Home Assistant long-lived access token (loaded from docker/sites/\$SITE_NAME/.env.\$SITE_NAME)

Examples:
  # List all lights
  $0 entities-by-type light

  # List lights in Shop area
  $0 entities-by-type light --area shop --format json

  # Get full details of all lights in markdown table format
  $0 entity-details light --format text

  # Get full details of lights in Shop area as CSV
  $0 entity-details light --area shop --format csv

  # Get state of a specific entity
  $0 entity-state light.living_room

  # Debug mode - see all API calls
  $0 --debug entity-details light --area shop

EOF
}

# Main command dispatcher
main() {
    local cmd="${1:-}"
    
    if [[ -z "$cmd" ]] || [[ "$cmd" == "help" ]] || [[ "$cmd" == "--help" ]] || [[ "$cmd" == "-h" ]]; then
        print_usage
        [[ -n "$cmd" ]] && exit 0 || exit 1
    fi
    
    case "$cmd" in
        entities)
            shift
            hass_get_entities "$@"
            ;;
        entity-state)
            shift
            hass_get_entity_state "$@"
            ;;
        entities-by-type)
            shift
            hass_list_entities_by_type "$@"
            ;;
        entity-details)
            shift
            hass_get_entity_details "$@"
            ;;
        *)
            log "ERROR" "Unknown command: $cmd"
            print_usage
            exit 1
            ;;
    esac
}

main "$@"
