#!/bin/bash
# Enhanced docker ps with profile grouping and verbose mode
# Last Updated: 11/7/2025 5:30:00 PM CST

# ANSI Color codes
BRIGHT_BLUE='\033[1;34m'      # Bright blue for column headers
HEADER_BG='\033[48;5;237m'    # Medium-dark gray background (256-color)
HEADER_FG='\033[1;33m'        # Bright yellow foreground
RESET='\033[0m'

# Column widths for standard output (set to 0 to hide column)
STD_COL_ID=14
STD_COL_NAME=25
STD_COL_IMAGE=18
STD_COL_STATUS=14
STD_COL_PORTS=30
STD_COL_IP=0
STD_COL_HEALTH=0

# Column widths for verbose output (set to 0 to hide column)
VERB_COL_ID=14
VERB_COL_NAME=25
VERB_COL_IMAGE=25
VERB_COL_STATUS=14
VERB_COL_PORTS=25
VERB_COL_IP=0
VERB_COL_HEALTH=12

# Default flags
VERBOSE_MODE=0
PROFILE_FILTER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE_MODE=1
            shift
            ;;
        -p|--profile)
            PROFILE_FILTER="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [-v|--verbose] [-p|--profile <profile>]"
            exit 1
            ;;
    esac
done

# Set column widths based on mode
if [[ $VERBOSE_MODE -eq 1 ]]; then
    COL_ID=$VERB_COL_ID
    COL_NAME=$VERB_COL_NAME
    COL_IMAGE=$VERB_COL_IMAGE
    COL_STATUS=$VERB_COL_STATUS
    COL_PORTS=$VERB_COL_PORTS
    COL_IP=$VERB_COL_IP
    COL_HEALTH=$VERB_COL_HEALTH
else
    COL_ID=$STD_COL_ID
    COL_NAME=$STD_COL_NAME
    COL_IMAGE=$STD_COL_IMAGE
    COL_STATUS=$STD_COL_STATUS
    COL_PORTS=$STD_COL_PORTS
    COL_IP=$STD_COL_IP
    COL_HEALTH=$STD_COL_HEALTH
fi

# Calculate total width for profile header
TOTAL_WIDTH=0
[[ $COL_ID -gt 0 ]] && TOTAL_WIDTH=$((TOTAL_WIDTH + COL_ID + 1))
[[ $COL_NAME -gt 0 ]] && TOTAL_WIDTH=$((TOTAL_WIDTH + COL_NAME + 1))
[[ $COL_IMAGE -gt 0 ]] && TOTAL_WIDTH=$((TOTAL_WIDTH + COL_IMAGE + 1))
[[ $COL_STATUS -gt 0 ]] && TOTAL_WIDTH=$((TOTAL_WIDTH + COL_STATUS + 1))
[[ $COL_PORTS -gt 0 ]] && TOTAL_WIDTH=$((TOTAL_WIDTH + COL_PORTS + 1))
[[ $COL_HEALTH -gt 0 ]] && TOTAL_WIDTH=$((TOTAL_WIDTH + COL_HEALTH + 1))
[[ $COL_IP -gt 0 ]] && TOTAL_WIDTH=$((TOTAL_WIDTH + COL_IP + 1))

# Function to build format string based on column widths
build_format() {
    local for_header=${1:-0}
    local fmt=""
    
    # Always use fixed truncation for all columns for consistent alignment
    [[ $COL_ID -gt 0 ]] && fmt="${fmt}%-${COL_ID}.${COL_ID}s "
    [[ $COL_NAME -gt 0 ]] && fmt="${fmt}%-${COL_NAME}.${COL_NAME}s "
    [[ $COL_IMAGE -gt 0 ]] && fmt="${fmt}%-${COL_IMAGE}.${COL_IMAGE}s "
    [[ $COL_STATUS -gt 0 ]] && fmt="${fmt}%-${COL_STATUS}.${COL_STATUS}s "
    [[ $COL_PORTS -gt 0 ]] && fmt="${fmt}%-${COL_PORTS}.${COL_PORTS}s "
    [[ $COL_HEALTH -gt 0 ]] && fmt="${fmt}%-${COL_HEALTH}.${COL_HEALTH}s "
    [[ $COL_IP -gt 0 ]] && fmt="${fmt}%-${COL_IP}.${COL_IP}s "
    
    echo "${fmt}\n"
}

# Function to print header
print_header() {
    local args=()
    [[ $COL_ID -gt 0 ]] && args+=("ContainerID")
    [[ $COL_NAME -gt 0 ]] && args+=("Name")
    [[ $COL_IMAGE -gt 0 ]] && args+=("Image")
    [[ $COL_STATUS -gt 0 ]] && args+=("Status")
    [[ $COL_PORTS -gt 0 ]] && args+=("Ports")
    [[ $COL_HEALTH -gt 0 ]] && args+=("Health")
    [[ $COL_IP -gt 0 ]] && args+=("IP Address")
    
    printf "${BRIGHT_BLUE}"
    printf "$(build_format 1)" "${args[@]}"
    printf "${RESET}"
}

# Function to get container health status
get_health() {
    local id=$1
    local health=$(docker inspect -f '{{.State.Health.Status}}' "$id" 2>/dev/null)
    if [[ -z "$health" || "$health" == "<no value>" ]]; then
        echo "n/a"
    else
        echo "$health"
    fi
}

# Function to format image name - prioritize text after last /
format_image() {
    local image=$1
    local max_width=$2
    
    # If image contains /, extract the part after the last /
    if [[ "$image" == */* ]]; then
        local image_name="${image##*/}"  # Get everything after last /
        local prefix="${image%/*}"       # Get everything before last /
        
        # If the image name itself fits, use it
        if [[ ${#image_name} -le $max_width ]]; then
            echo "$image_name"
        # If full image fits, use it
        elif [[ ${#image} -le $max_width ]]; then
            echo "$image"
        else
            # Truncate prefix with ... and show as much of image_name as possible
            local available=$((max_width - 3))  # Reserve 3 chars for ...
            if [[ ${#image_name} -le $available ]]; then
                # Image name fits with ..., show part of prefix
                local prefix_len=$((available - ${#image_name} - 1))  # -1 for /
                if [[ $prefix_len -gt 0 ]]; then
                    echo "...${prefix: -$prefix_len}/$image_name"
                else
                    echo ".../$image_name"
                fi
            else
                # Even image name doesn't fit, truncate it
                echo "...${image_name:0:$available}"
            fi
        fi
    else
        # No /, just return the image (will be truncated by printf)
        echo "$image"
    fi
}

# Function to get published ports
get_ports() {
    local id=$1
    local ports=$(docker port "$id" 2>/dev/null | awk '{
        split($0, a, " -> ");
        if (a[2]) {
            gsub(/0\.0\.0\.0/, "0", a[2]);
            gsub(/\[::\]/, "[6]", a[2]);
            printf "%s->%s,", a[1], a[2];
        }
    }')
    # Remove trailing comma
    ports=${ports%,}
    echo "$ports"
}

# Function to print container info
print_container() {
    local id=$1
    local name=$2
    local image=$3
    local status=$4
    local ports=$5
    local ip=$6
    local health=$7
    local is_continuation=${8:-0}
    
    # Build args array based on visible columns
    local args=()
    
    if [[ $is_continuation -eq 1 ]]; then
        # For continuation lines (additional ports), print spaces for non-port columns
        [[ $COL_ID -gt 0 ]] && args+=("")
        [[ $COL_NAME -gt 0 ]] && args+=("")
        [[ $COL_IMAGE -gt 0 ]] && args+=("")
        [[ $COL_STATUS -gt 0 ]] && args+=("")
        [[ $COL_PORTS -gt 0 ]] && args+=("$ports")
        [[ $COL_HEALTH -gt 0 ]] && args+=("")
        [[ $COL_IP -gt 0 ]] && args+=("")
    else
        [[ $COL_ID -gt 0 ]] && args+=("$id")
        [[ $COL_NAME -gt 0 ]] && args+=("$name")
        [[ $COL_IMAGE -gt 0 ]] && args+=("$(format_image "$image" $COL_IMAGE)")
        [[ $COL_STATUS -gt 0 ]] && args+=("$status")
        [[ $COL_PORTS -gt 0 ]] && args+=("$ports")
        [[ $COL_HEALTH -gt 0 ]] && args+=("$health")
        [[ $COL_IP -gt 0 ]] && args+=("$ip")
    fi
    
    printf "$(build_format)" "${args[@]}"
}

# Fetch all container information
declare -A containers_by_profile
declare -a all_profiles

while IFS=$'\t' read -r id name image status project group; do
    # Use divtools.group if available, otherwise fall back to com.docker.compose.project
    if [[ -n "$group" ]]; then
        profile="$group"
    elif [[ -n "$project" ]]; then
        profile="$project"
    else
        profile="no-profile"
    fi
    
    # Skip if profile filter is set and doesn't match
    if [[ -n "$PROFILE_FILTER" && "$profile" != "$PROFILE_FILTER" ]]; then
        continue
    fi
    
    # Get IP address
    ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$id")
    
    # Get health status
    health=$(get_health "$id")
    
    # Get published ports
    ports=$(get_ports "$id")
    
    # Store container info
    container_info="$id|$name|$image|$status|$ports|$ip|$health"
    
    # Add to profile group
    if [[ -z "${containers_by_profile[$profile]}" ]]; then
        all_profiles+=("$profile")
        containers_by_profile[$profile]="$container_info"
    else
        containers_by_profile[$profile]="${containers_by_profile[$profile]}"$'\n'"$container_info"
    fi
done < <(docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Label \"com.docker.compose.project\"}}\t{{.Label \"divtools.group\"}}")

# Print output grouped by profile
for profile in "${all_profiles[@]}"; do
    # Print profile header with bright black background and dark blue text spanning full width
    echo ""
    header_text="=== Profile: $profile ==="
    padding=$((TOTAL_WIDTH - ${#header_text}))
    [[ $padding -lt 0 ]] && padding=0
    printf "${HEADER_BG}${HEADER_FG}%s%${padding}s${RESET}\n" "$header_text" ""
    print_header
    
    # Print containers in this profile
    while IFS= read -r container_line; do
        [[ -z "$container_line" ]] && continue
        
        IFS='|' read -r id name image status ports ip health <<< "$container_line"
        
        if [[ $VERBOSE_MODE -eq 1 && $COL_PORTS -gt 0 ]]; then
            # In verbose mode, split ports by comma and print each on its own line
            if [[ -n "$ports" ]]; then
                first_port=1
                IFS=',' read -ra port_array <<< "$ports"
                for port in "${port_array[@]}"; do
                    port=$(echo "$port" | xargs)  # trim whitespace
                    if [[ $first_port -eq 1 ]]; then
                        print_container "$id" "$name" "$image" "$status" "$port" "$ip" "$health" 0
                        first_port=0
                    else
                        print_container "" "" "" "" "$port" "" "" 1
                    fi
                done
            else
                print_container "$id" "$name" "$image" "$status" "" "$ip" "$health" 0
            fi
        else
            # Standard mode or ports column hidden - truncate ports if needed
            if [[ $COL_PORTS -gt 0 ]]; then
                ports=$(echo "$ports" | cut -c1-$COL_PORTS)
            fi
            print_container "$id" "$name" "$image" "$status" "$ports" "$ip" "$health" 0
        fi
    done <<< "${containers_by_profile[$profile]}"
done

echo ""
