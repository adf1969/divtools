#!/bin/bash
# Tests RTSP connectivity for Frigate cameras by parsing config.yaml and testing streams
# Last Updated: 11/5/2025 9:45:00 AM CST

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/logging.sh"

# Default values
CONTAINER_NAME=""
CAMERA_FILTER="*"
STREAM_TYPE="main"
DEBUG_MODE=0
PROGRESS_MODE=0
PING_MODE=0
PING_INTERVAL=5
TEST_MODE=0
FORCE_REBUILD=0

# Global variables
declare -A CAMERA_STREAMS
declare -A CAMERA_ENABLED
declare -A TEST_RESULTS
DIVTOOLS="${DIVTOOLS:-/opt/divtools}"
DB_FILE=""
CONFIG_FILE=""
FFMPEG_PATH=""

# ANSI color codes for table output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

#==============================================================================
# Function: show_usage
# Description: Display script usage information
#==============================================================================
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Test RTSP connectivity for Frigate cameras by parsing config.yaml
Tests are executed INSIDE the frigate container using docker exec.

OPTIONS:
    -cn, --container <name>     Docker container name (default: auto-detect 'frigate')
    -c, --cam <cameras>         Comma-delimited camera list (number or name)
                                Examples: -c 4,9  -c deck_west,garage
                                Wildcards: -c '*'  -c '*deck*'
    -s, --sub <stream>          Stream type: main, detect, view (default: main)
    -p, --progress              Show progress during testing
    -d, --debug                 Enable debug output
    -ping [interval]            Continuous ping mode with delay in seconds (default: 5)
    -r, --rebuild               Force rebuild of camera database (fg_test_cam_rtsp.json)
    -test                       Test mode - shows what would be done
    -h, --help                  Show this help message

DATABASE:
    Camera configuration is cached in fg_test_cam_rtsp.json (next to config.yaml)
    This includes camera streams, enabled status, and the ffmpeg path in the container.
    The cache is automatically rebuilt when config.yaml changes or with -r flag.

EXAMPLES:
    # Test all cameras (main stream)
    $(basename "$0") -c '*'

    # Test specific cameras by number
    $(basename "$0") -c 4,9,12

    # Test cameras with 'deck' in name, using detect stream
    $(basename "$0") -c '*deck*' -s detect

    # Continuous monitoring every 10 seconds with progress
    $(basename "$0") -c '*' -ping 10 -p

    # Test specific container
    $(basename "$0") -cn frigate-test -c '*'

EOF
    exit 0
}

#==============================================================================
# Function: load_environment_vars
# Description: Load divtools environment variables from shared/site/host
#==============================================================================
load_environment_vars() {
    log "DEBUG" "Loading environment variables"
    
    # Try to determine HOSTNAME if not set
    if [[ -z "${HOSTNAME}" ]]; then
        HOSTNAME=$(hostname)
        log "DEBUG" "Detected HOSTNAME: ${HOSTNAME}"
    fi
    
    # Source shared env
    local shared_env="${DIVTOOLS}/docker/sites/s00-shared/.env.s00-shared"
    if [[ -f "${shared_env}" ]]; then
        log "DEBUG" "Sourcing: ${shared_env}"
        source "${shared_env}"
    else
        log "WARN" "Shared env file not found: ${shared_env}"
    fi
    
    # Try to detect SITE_NAME from HOSTNAME
    if [[ -z "${SITE_NAME}" ]]; then
        # Look for site directories containing this hostname
        for site_dir in "${DIVTOOLS}"/docker/sites/s[0-9]*; do
            if [[ -d "${site_dir}/${HOSTNAME}" ]]; then
                SITE_NAME=$(basename "${site_dir}")
                log "DEBUG" "Detected SITE_NAME: ${SITE_NAME}"
                break
            fi
        done
    fi
    
    if [[ -n "${SITE_NAME}" ]]; then
        # Source site env
        local site_env="${DIVTOOLS}/docker/sites/${SITE_NAME}/.env.${SITE_NAME}"
        if [[ -f "${site_env}" ]]; then
            log "DEBUG" "Sourcing: ${site_env}"
            source "${site_env}"
        fi
        
        # Source host env
        local host_env="${DIVTOOLS}/docker/sites/${SITE_NAME}/${HOSTNAME}/.env.${HOSTNAME}"
        if [[ -f "${host_env}" ]]; then
            log "DEBUG" "Sourcing: ${host_env}"
            source "${host_env}"
        fi
    fi
    
    # Export common vars if not already set
    export DOCKERDIR="${DOCKERDIR:-${DIVTOOLS}/docker}"
    export DOCKERDATADIR="${DOCKERDATADIR:-/opt}"
    
    log "DEBUG" "Environment loaded - HOSTNAME=${HOSTNAME}, SITE_NAME=${SITE_NAME}"
}

#==============================================================================
# Function: find_frigate_container
# Description: Detect running frigate container if not specified
#==============================================================================
find_frigate_container() {
    if [[ -n "${CONTAINER_NAME}" ]]; then
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            log "DEBUG" "Using specified container: ${CONTAINER_NAME}"
            return 0
        else
            log "ERROR" "Container '${CONTAINER_NAME}' not found or not running"
            return 1
        fi
    fi
    
    # Auto-detect frigate container
    if docker ps --format '{{.Names}}' | grep -q "^frigate$"; then
        CONTAINER_NAME="frigate"
        log "DEBUG" "Auto-detected container: frigate"
        return 0
    fi
    
    log "ERROR" "No frigate container found. Use -cn to specify container name."
    return 1
}

#==============================================================================
# Function: find_ffmpeg_in_container
# Description: Locate ffmpeg binary inside the container
#==============================================================================
find_ffmpeg_in_container() {
    log "INFO" "Locating ffmpeg in container: ${CONTAINER_NAME}"
    
    # First, try to find it from running processes
    log "DEBUG" "Checking running processes for ffmpeg..."
    local ffmpeg_from_ps
    ffmpeg_from_ps=$(docker exec "${CONTAINER_NAME}" ps aux 2>/dev/null | grep -m1 '[f]fmpeg' | awk '{print $11}')
    
    if [[ -n "${ffmpeg_from_ps}" ]] && docker exec "${CONTAINER_NAME}" test -f "${ffmpeg_from_ps}" 2>/dev/null; then
        FFMPEG_PATH="${ffmpeg_from_ps}"
        log "INFO" "Found ffmpeg from running process: ${FFMPEG_PATH}"
        return 0
    fi
    
    # Try common Frigate locations
    log "DEBUG" "Checking common Frigate ffmpeg locations..."
    local common_paths=(
        "/usr/lib/ffmpeg/7.0/bin/ffmpeg"
        "/usr/lib/ffmpeg/6.1/bin/ffmpeg"
        "/usr/lib/ffmpeg/bin/ffmpeg"
        "/usr/bin/ffmpeg"
        "/usr/local/bin/ffmpeg"
    )
    
    for path in "${common_paths[@]}"; do
        if docker exec "${CONTAINER_NAME}" test -f "${path}" 2>/dev/null; then
            FFMPEG_PATH="${path}"
            log "INFO" "Found ffmpeg at: ${FFMPEG_PATH}"
            return 0
        fi
    done
    
    # Last resort: search /usr/lib
    log "DEBUG" "Searching /usr/lib for ffmpeg binary..."
    local found_path
    found_path=$(docker exec "${CONTAINER_NAME}" find /usr/lib -name ffmpeg -type f 2>/dev/null | head -1)
    
    if [[ -n "${found_path}" ]]; then
        FFMPEG_PATH="${found_path}"
        log "INFO" "Found ffmpeg via search: ${FFMPEG_PATH}"
        return 0
    fi
    
    # Still not found, try which command
    log "DEBUG" "Trying 'which ffmpeg' in container..."
    found_path=$(docker exec "${CONTAINER_NAME}" which ffmpeg 2>/dev/null)
    
    if [[ -n "${found_path}" ]]; then
        FFMPEG_PATH="${found_path}"
        log "INFO" "Found ffmpeg via which: ${FFMPEG_PATH}"
        return 0
    fi
    
    log "ERROR" "Could not locate ffmpeg binary in container"
    return 1
}

#==============================================================================
# Function: find_config_file
# Description: Locate the Frigate config.yaml file
#==============================================================================
find_config_file() {
    local config_path="${DIVTOOLS}/docker/sites/${SITE_NAME}/${HOSTNAME}/frigate/config/config.yaml"
    
    if [[ ! -f "${config_path}" ]]; then
        log "ERROR" "Config file not found: ${config_path}"
        return 1
    fi
    
    CONFIG_FILE="${config_path}"
    DB_FILE="${config_path%/*}/fg_test_cam_rtsp.json"
    
    log "DEBUG" "Config file: ${CONFIG_FILE}"
    log "DEBUG" "Database file: ${DB_FILE}"
    return 0
}

#==============================================================================
# Function: parse_config_yaml
# Description: Parse config.yaml for camera streams and enabled status
#==============================================================================
parse_config_yaml() {
    log "INFO" "Parsing config.yaml for camera configuration"
    
    local in_go2rtc=0
    local in_cameras=0
    local current_camera=""
    local current_stream=""
    local stream_prefix=""
    
    while IFS= read -r line; do
        # Detect go2rtc section
        if [[ "${line}" =~ ^go2rtc: ]]; then
            in_go2rtc=1
            in_cameras=0
            continue
        fi
        
        # Detect cameras section
        if [[ "${line}" =~ ^cameras: ]]; then
            in_cameras=1
            in_go2rtc=0
            continue
        fi
        
        # Exit sections when we hit another top-level key
        if [[ "${line}" =~ ^[a-z_]+: ]] && [[ ! "${line}" =~ ^\ \ ]]; then
            if [[ ! "${line}" =~ ^(go2rtc|cameras): ]]; then
                in_go2rtc=0
                in_cameras=0
            fi
        fi
        
        # Parse go2rtc streams
        if [[ ${in_go2rtc} -eq 1 ]] && [[ "${line}" =~ ^\ \ \ \ ([a-z0-9_]+)_(main|detect|view): ]]; then
            stream_prefix="${BASH_REMATCH[1]}"
            current_stream="${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
        elif [[ ${in_go2rtc} -eq 1 ]] && [[ -n "${current_stream}" ]] && [[ "${line}" =~ ^\ \ \ \ \ \ -\ (rtsp://.+)$ ]]; then
            local rtsp_url="${BASH_REMATCH[1]}"
            CAMERA_STREAMS["${current_stream}"]="${rtsp_url}"
            log "DEBUG" "Found stream: ${current_stream} -> ${rtsp_url:0:50}..."
        fi
        
        # Parse cameras section for enabled status
        if [[ ${in_cameras} -eq 1 ]]; then
            if [[ "${line}" =~ ^\ \ ([A-Z0-9_]+): ]]; then
                current_camera="${BASH_REMATCH[1]}"
                log "DEBUG" "Found camera: ${current_camera}"
            elif [[ -n "${current_camera}" ]] && [[ "${line}" =~ ^\ \ \ \ enabled:\ (true|false) ]]; then
                CAMERA_ENABLED["${current_camera}"]="${BASH_REMATCH[1]}"
                log "DEBUG" "Camera ${current_camera} enabled: ${BASH_REMATCH[1]}"
            fi
        fi
    done < "${CONFIG_FILE}"
    
    log "INFO" "Parsed ${#CAMERA_STREAMS[@]} streams and ${#CAMERA_ENABLED[@]} cameras"
}

#==============================================================================
# Function: save_database
# Description: Save parsed camera data and container info to JSON database
#==============================================================================
save_database() {
    log "DEBUG" "Saving database to: ${DB_FILE}"
    
    # Start JSON structure
    cat > "${DB_FILE}" << EOF
{
  "metadata": {
    "generated": "$(date -Iseconds)",
    "config_file": "${CONFIG_FILE}",
    "container": "${CONTAINER_NAME}",
    "ffmpeg_path": "${FFMPEG_PATH}"
  },
  "streams": {
EOF
    
    # Add streams
    local first_stream=1
    for stream in "${!CAMERA_STREAMS[@]}"; do
        [[ ${first_stream} -eq 0 ]] && echo "," >> "${DB_FILE}"
        printf '    "%s": "%s"' "${stream}" "${CAMERA_STREAMS[$stream]}" >> "${DB_FILE}"
        first_stream=0
    done
    
    # Add camera enabled status
    cat >> "${DB_FILE}" << EOF

  },
  "cameras": {
EOF
    
    local first_camera=1
    for camera in "${!CAMERA_ENABLED[@]}"; do
        [[ ${first_camera} -eq 0 ]] && echo "," >> "${DB_FILE}"
        printf '    "%s": %s' "${camera}" "${CAMERA_ENABLED[$camera]}" >> "${DB_FILE}"
        first_camera=0
    done
    
    # Close JSON
    cat >> "${DB_FILE}" << EOF

  }
}
EOF
    
    log "DEBUG" "Database saved successfully"
}

#==============================================================================
# Function: load_database
# Description: Load camera data and container info from JSON database
#==============================================================================
load_database() {
    log "DEBUG" "Loading database from: ${DB_FILE}"
    
    # Check if jq is available, if not parse manually
    if command -v jq &> /dev/null; then
        # Load using jq
        FFMPEG_PATH=$(jq -r '.metadata.ffmpeg_path // empty' "${DB_FILE}" 2>/dev/null)
        
        # Load streams
        while IFS= read -r line; do
            local key=$(echo "${line}" | cut -d: -f1 | tr -d ' "')
            local value=$(echo "${line}" | cut -d: -f2- | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')
            [[ -n "${key}" ]] && CAMERA_STREAMS["${key}"]="${value}"
        done < <(jq -r '.streams | to_entries[] | "\(.key):\(.value)"' "${DB_FILE}" 2>/dev/null)
        
        # Load camera status
        while IFS= read -r line; do
            local key=$(echo "${line}" | cut -d: -f1 | tr -d ' "')
            local value=$(echo "${line}" | cut -d: -f2 | tr -d ' ')
            [[ -n "${key}" ]] && CAMERA_ENABLED["${key}"]="${value}"
        done < <(jq -r '.cameras | to_entries[] | "\(.key):\(.value)"' "${DB_FILE}" 2>/dev/null)
    else
        # Parse JSON manually (basic parser)
        local in_streams=0
        local in_cameras=0
        
        while IFS= read -r line; do
            # Detect ffmpeg_path
            if [[ "${line}" =~ \"ffmpeg_path\":\ \"([^\"]+)\" ]]; then
                FFMPEG_PATH="${BASH_REMATCH[1]}"
            fi
            
            # Detect sections
            [[ "${line}" =~ \"streams\": ]] && in_streams=1 && in_cameras=0 && continue
            [[ "${line}" =~ \"cameras\": ]] && in_cameras=1 && in_streams=0 && continue
            [[ "${line}" =~ ^[[:space:]]*\} ]] && in_streams=0 && in_cameras=0
            
            # Parse streams
            if [[ ${in_streams} -eq 1 ]] && [[ "${line}" =~ \"([^\"]+)\":\ \"([^\"]+)\" ]]; then
                CAMERA_STREAMS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
            fi
            
            # Parse cameras
            if [[ ${in_cameras} -eq 1 ]] && [[ "${line}" =~ \"([^\"]+)\":\ (true|false) ]]; then
                CAMERA_ENABLED["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
            fi
        done < "${DB_FILE}"
    fi
    
    log "DEBUG" "Loaded ${#CAMERA_STREAMS[@]} streams and ${#CAMERA_ENABLED[@]} cameras from database"
    [[ -n "${FFMPEG_PATH}" ]] && log "DEBUG" "Loaded ffmpeg path: ${FFMPEG_PATH}"
}

#==============================================================================
# Function: check_database_freshness
# Description: Check if database is newer than config file
#==============================================================================
check_database_freshness() {
    if [[ ${FORCE_REBUILD} -eq 1 ]]; then
        log "INFO" "Force rebuild requested"
        return 1
    fi
    
    if [[ ! -f "${DB_FILE}" ]]; then
        log "DEBUG" "Database file does not exist"
        return 1
    fi
    
    if [[ "${CONFIG_FILE}" -nt "${DB_FILE}" ]]; then
        log "INFO" "Config file is newer than database, rebuilding"
        return 1
    fi
    
    log "INFO" "Using cached database (newer than config)"
    return 0
}

#==============================================================================
# Function: substitute_env_vars
# Description: Replace {ENV_VAR} placeholders with actual values
#==============================================================================
substitute_env_vars() {
    local url="$1"
    
    # Replace common Frigate env vars
    url="${url//\{FRIGATE_CAM_U\}/${FRIGATE_CAM_U}}"
    url="${url//\{FRIGATE_CAM_P\}/${FRIGATE_CAM_P}}"
    url="${url//\{FRIGATE_CAM_ADMIN_U\}/${FRIGATE_CAM_ADMIN_U}}"
    url="${url//\{FRIGATE_CAM_ADMIN_P\}/${FRIGATE_CAM_ADMIN_P}}"
    
    echo "${url}"
}

#==============================================================================
# Function: get_camera_list
# Description: Build list of cameras to test based on filter
#==============================================================================
get_camera_list() {
    local filter="$1"
    local cameras=()
    
    # If filter contains comma, split it
    if [[ "${filter}" == *,* ]]; then
        IFS=',' read -ra filters <<< "${filter}"
    else
        filters=("${filter}")
    fi
    
    for f in "${filters[@]}"; do
        f=$(echo "${f}" | xargs) # Trim whitespace
        
        # Check if it's a number (camera ID)
        if [[ "${f}" =~ ^[0-9]+$ ]]; then
            local cam_id=$(printf "c%02d" "${f}")
            log "DEBUG" "Looking for camera ID: ${cam_id}"
            
            for camera in "${!CAMERA_ENABLED[@]}"; do
                local cam_lower=$(echo "${camera}" | tr '[:upper:]' '[:lower:]')
                if [[ "${cam_lower}" == ${cam_id}* ]]; then
                    cameras+=("${camera}")
                    log "DEBUG" "Matched camera by ID: ${camera}"
                fi
            done
        else
            # It's a name/pattern
            log "DEBUG" "Looking for camera pattern: ${f}"
            
            for camera in "${!CAMERA_ENABLED[@]}"; do
                local cam_lower=$(echo "${camera}" | tr '[:upper:]' '[:lower:]')
                local filter_lower=$(echo "${f}" | tr '[:upper:]' '[:lower:]')
                
                # Remove wildcards for matching
                filter_lower="${filter_lower//\*/}"
                
                if [[ "${cam_lower}" == *"${filter_lower}"* ]]; then
                    cameras+=("${camera}")
                    log "DEBUG" "Matched camera by pattern: ${camera}"
                fi
            done
        fi
    done
    
    # Remove duplicates
    local unique_cameras=($(printf '%s\n' "${cameras[@]}" | sort -u))
    
    echo "${unique_cameras[@]}"
}

#==============================================================================
# Function: test_rtsp_stream
# Description: Test RTSP connection using ffmpeg inside container
#==============================================================================
test_rtsp_stream() {
    local stream_url="$1"
    local retry="${2:-0}"
    
    log "DEBUG" "Testing stream in container: ${stream_url:0:60}..."
    
    if [[ -z "${FFMPEG_PATH}" ]]; then
        log "ERROR" "ffmpeg path not set"
        echo "FAILED|ffmpeg not found||||${retry}"
        return 1
    fi
    
    # Test connection and get stream info using docker exec
    local output
    output=$(timeout 10 docker exec "${CONTAINER_NAME}" "${FFMPEG_PATH}" -rtsp_transport tcp -i "${stream_url}" -frames:v 1 -f null - 2>&1)
    local result=$?
    
    local resolution="N/A"
    local fps="N/A"
    local codec="N/A"
    
    if [[ ${result} -eq 0 ]]; then
        # Extract resolution
        if [[ "${output}" =~ ([0-9]+x[0-9]+) ]]; then
            resolution="${BASH_REMATCH[1]}"
        fi
        
        # Extract FPS
        if [[ "${output}" =~ ([0-9.]+)\ fps ]]; then
            fps="${BASH_REMATCH[1]}"
        fi
        
        # Extract codec
        if [[ "${output}" =~ Video:\ ([a-z0-9]+) ]]; then
            codec="${BASH_REMATCH[1]}"
        fi
        
        echo "SUCCESS|${resolution}|${fps}|${codec}|${retry}"
    else
        local error_msg="Connection failed"
        if [[ "${output}" =~ (Connection\ refused|timed\ out|404\ Not\ Found|401\ Unauthorized|No\ route\ to\ host) ]]; then
            error_msg="${BASH_REMATCH[1]}"
        elif [[ "${output}" =~ (Invalid\ data|End\ of\ file) ]]; then
            error_msg="${BASH_REMATCH[1]}"
        fi
        echo "FAILED|${error_msg}||||${retry}"
    fi
}

#==============================================================================
# Function: print_table_header
# Description: Print formatted table header
#==============================================================================
print_table_header() {
    printf "\n"
    printf "%-25s %-10s %-10s %-12s %-8s %-8s %-8s\n" \
        "CAMERA" "STREAM" "STATUS" "RESOLUTION" "FPS" "CODEC" "RETRY"
    printf "%s\n" "$(printf '=%.0s' {1..85})"
}

#==============================================================================
# Function: print_table_row
# Description: Print formatted table row with color
#==============================================================================
print_table_row() {
    local camera="$1"
    local stream="$2"
    local status="$3"
    local resolution="$4"
    local fps="$5"
    local codec="$6"
    local retry="$7"
    
    local color="${GREEN}"
    [[ "${status}" == "FAILED" ]] && color="${RED}"
    [[ "${retry}" -gt 0 ]] && color="${YELLOW}"
    
    printf "${color}%-25s %-10s %-10s %-12s %-8s %-8s %-8s${NC}\n" \
        "${camera:0:24}" "${stream}" "${status}" "${resolution}" "${fps}" "${codec}" "${retry}"
}

#==============================================================================
# Function: run_tests
# Description: Execute RTSP tests for selected cameras
#==============================================================================
run_tests() {
    local cameras_to_test="$1"
    
    if [[ -z "${cameras_to_test}" ]]; then
        log "WARN" "No cameras matched the filter"
        return 1
    fi
    
    [[ ${PROGRESS_MODE} -eq 0 ]] && [[ ${PING_MODE} -eq 0 ]] && print_table_header
    
    for camera in ${cameras_to_test}; do
        # Check if camera is enabled
        if [[ "${CAMERA_ENABLED[${camera}]}" != "true" ]]; then
            log "DEBUG" "Skipping disabled camera: ${camera}"
            continue
        fi
        
        # Build stream name
        local cam_lower=$(echo "${camera}" | tr '[:upper:]' '[:lower:]')
        local stream_name="${cam_lower}_${STREAM_TYPE}"
        
        # Get stream URL
        local stream_url="${CAMERA_STREAMS[${stream_name}]}"
        
        if [[ -z "${stream_url}" ]]; then
            log "WARN" "No ${STREAM_TYPE} stream found for ${camera}"
            continue
        fi
        
        # Substitute environment variables
        stream_url=$(substitute_env_vars "${stream_url}")
        
        [[ ${PROGRESS_MODE} -eq 1 ]] && log "INFO" "Testing ${camera} (${STREAM_TYPE} stream)..."
        
        # Test the stream
        local result
        result=$(test_rtsp_stream "${stream_url}" 0)
        
        IFS='|' read -r status resolution fps codec retry <<< "${result}"
        
        # Retry once if failed and not in ping mode
        if [[ "${status}" == "FAILED" ]] && [[ ${PING_MODE} -eq 0 ]]; then
            [[ ${PROGRESS_MODE} -eq 1 ]] && log "WARN" "Test failed, retrying..."
            sleep 2
            result=$(test_rtsp_stream "${stream_url}" 1)
            IFS='|' read -r status resolution fps codec retry <<< "${result}"
        fi
        
        # Store result
        TEST_RESULTS["${camera}"]="${result}"
        
        # Print result
        if [[ ${PING_MODE} -eq 1 ]]; then
            print_table_row "${camera}" "${STREAM_TYPE}" "${status}" "${resolution}" "${fps}" "${codec}" "${retry}"
        elif [[ ${PROGRESS_MODE} -eq 0 ]]; then
            print_table_row "${camera}" "${STREAM_TYPE}" "${status}" "${resolution}" "${fps}" "${codec}" "${retry}"
        fi
    done
    
    return 0
}

#==============================================================================
# Function: main
# Description: Main script execution
#==============================================================================
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -cn|--container)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            -c|--cam)
                CAMERA_FILTER="$2"
                shift 2
                ;;
            -s|--sub)
                STREAM_TYPE="$2"
                shift 2
                ;;
            -p|--progress)
                PROGRESS_MODE=1
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=1
                shift
                ;;
            -ping)
                PING_MODE=1
                if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    PING_INTERVAL="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -r|--rebuild)
                FORCE_REBUILD=1
                shift
                ;;
            -test|--test)
                TEST_MODE=1
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                ;;
        esac
    done
    
    # Validate stream type
    if [[ ! "${STREAM_TYPE}" =~ ^(main|detect|view)$ ]]; then
        log "ERROR" "Invalid stream type: ${STREAM_TYPE}. Must be: main, detect, or view"
        exit 1
    fi
    
    log "INFO" "Frigate RTSP Camera Test Utility"
    [[ ${TEST_MODE} -eq 1 ]] && log "INFO" "Running in TEST mode"
    
    # Load environment
    load_environment_vars
    
    # Find container
    find_frigate_container || exit 1
    
    # Find config file
    find_config_file || exit 1
    
    # Load or build database
    if check_database_freshness; then
        load_database
        # Verify ffmpeg path is still valid
        if [[ -n "${FFMPEG_PATH}" ]]; then
            if ! docker exec "${CONTAINER_NAME}" test -f "${FFMPEG_PATH}" 2>/dev/null; then
                log "WARN" "Cached ffmpeg path no longer valid, searching again..."
                FFMPEG_PATH=""
            fi
        fi
    else
        parse_config_yaml
    fi
    
    # Find ffmpeg if not already found
    if [[ -z "${FFMPEG_PATH}" ]]; then
        find_ffmpeg_in_container || exit 1
        # Save database with updated ffmpeg path
        save_database
    fi
    
    # Get camera list
    local cameras_to_test
    cameras_to_test=$(get_camera_list "${CAMERA_FILTER}")
    
    if [[ -z "${cameras_to_test}" ]]; then
        log "ERROR" "No cameras found matching filter: ${CAMERA_FILTER}"
        exit 1
    fi
    
    log "INFO" "Testing ${STREAM_TYPE} stream for cameras: ${cameras_to_test// /, }"
    
    [[ ${TEST_MODE} -eq 1 ]] && exit 0
    
    # Run tests
    if [[ ${PING_MODE} -eq 1 ]]; then
        log "INFO" "Continuous ping mode enabled (interval: ${PING_INTERVAL}s). Press Ctrl+C to stop."
        while true; do
            print_table_header
            run_tests "${cameras_to_test}"
            sleep "${PING_INTERVAL}"
        done
    else
        run_tests "${cameras_to_test}"
    fi
    
    # Print summary
    local total=0
    local failed=0
    for camera in ${cameras_to_test}; do
        [[ "${CAMERA_ENABLED[${camera}]}" != "true" ]] && continue
        ((total++))
        if [[ "${TEST_RESULTS[${camera}]}" == FAILED* ]]; then
            ((failed++))
        fi
    done
    
    printf "\n"
    log "INFO" "Test Summary: ${total} cameras tested, $((total - failed)) successful, ${failed} failed"
}

# Execute main function
main "$@"
