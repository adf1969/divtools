#!/usr/bin/env bash
# vscode_host_colors.sh
# Sets VS Code remote colors based on HOSTNAME_U (or fallback to hostname).
# Merges into ~/.vscode-server/data/User/settings.json on the remote.
# Supports merging to avoid overwriting existing settings.
# Last Updated: 12/6/2025 3:00:00 PM CST

# ============================================================================
# ROOT USER WARNING
# ============================================================================
if [ "$EUID" -eq 0 ] || [ "$USER" = "root" ]; then
    # Red warning banner
    echo ""
    echo -e "\033[1;41;37m ⚠️  WARNING: RUNNING AS ROOT ⚠️  \033[0m"
    echo -e "\033[1;31m This script should be run as the 'divix' user, NOT as root.\033[0m"
    echo ""
    echo -e "\033[1;31m Reason:\033[0m"
    echo -e "\033[1;31m  This script updates ~/.vscode-server/data/User/settings.json\033[0m"
    echo -e "\033[1;31m  When run as root, it modifies /root/.vscode-server/\033[0m"
    echo -e "\033[1;31m  But VS Code connects as 'divix' user, using /home/divix/.vscode-server/\033[0m"
    echo ""
    echo -e "\033[1;31m Solution:\033[0m"
    echo -e "\033[1;33m  Run as the divix user:\033[0m"
    echo -e "\033[1;36m  $ /opt/divtools/scripts/vscode/vscode_host_colors.sh\033[0m"
    echo -e "\033[1;33m  (without sudo)\033[0m"
    echo ""
    exit 1
fi
# ============================================================================

# Flags
TEST_MODE=0
DEBUG_MODE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -test) TEST_MODE=1; shift ;;
        -debug) DEBUG_MODE=1; shift ;;
        *) break ;;
    esac
done

# Source your logging function (from your dotfiles)
source "$DIVTOOLS/dotfiles/logging.sh" 2>/dev/null || {
    # Fallback logging if not found
    log() {
        local level="$1"; shift
        local color; case "$level" in DEBUG) color="\e[37m";; INFO) color="\e[36m";; WARN) color="\e[33m";; ERROR) color="\e[31m";; esac
        echo -e "${color}[$level] $* \e[0m" >&2
    }
}

log "INFO" "Starting VS Code remote color setup..."

# Load env files so DT_COLOR_* values are available (host/site level)
# Try multiple locations for .bash_profile (common when running non-interactively)
if ! declare -f load_env_files >/dev/null 2>&1; then
    [ "$DEBUG_MODE" = 1 ] && log "DEBUG" "Attempting to source ~/.bash_profile for load_env_files..."
    [ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" 2>/dev/null
fi

if ! declare -f load_env_files >/dev/null 2>&1 && [ -n "$DIVTOOLS" ]; then
    [ "$DEBUG_MODE" = 1 ] && log "DEBUG" "Attempting to source $DIVTOOLS/dotfiles/.bash_profile for load_env_files..."
    [ -f "$DIVTOOLS/dotfiles/.bash_profile" ] && source "$DIVTOOLS/dotfiles/.bash_profile" 2>/dev/null
fi

if declare -f load_env_files >/dev/null 2>&1; then
    [ "$DEBUG_MODE" = 1 ] && log "DEBUG" "load_env_files found; invoking..."
    load_env_files
    log "INFO" "Loaded environment files for color lookup."
else
    log "WARN" "load_env_files not found; relying on fallback case map."
fi

# Debug: show loaded DT_COLOR_* vars if debug mode
if [ "$DEBUG_MODE" = 1 ]; then
    log "DEBUG" "DT_COLOR_TITLE_BG=${DT_COLOR_TITLE_BG:-unset}, DT_COLOR_TITLE_FG=${DT_COLOR_TITLE_FG:-unset}"
    log "DEBUG" "DT_COLOR_STATUS_BG=${DT_COLOR_STATUS_BG:-unset}, DT_COLOR_STATUS_FG=${DT_COLOR_STATUS_FG:-unset}"
    log "DEBUG" "DT_COLOR_ACTIVITY_BG=${DT_COLOR_ACTIVITY_BG:-unset}, DT_COLOR_ACTIVITY_FG=${DT_COLOR_ACTIVITY_FG:-unset}"
    log "DEBUG" "DT_COLOR_DARKEN_FACTOR_BG=${DT_COLOR_DARKEN_FACTOR_BG:-unset}, DT_COLOR_DARKEN_FACTOR_FG=${DT_COLOR_DARKEN_FACTOR_FG:-unset}"
fi

# Get host ID (use HOSTNAME_U if set, else fallback)
HOST_ID="${HOSTNAME_U:-$(hostname -s | tr '[:lower:]' '[:upper:]')}"
log "INFO" "Detected host ID: $HOST_ID"

# Map host → colors (edit/add your hosts here)
case "$HOST_ID" in
    "ADS1-98")
        # BG="#166534" FG="#86efac" NAME="ADS1-98"   # Green
        BG="#0a3d62" FG="#6ea8d5" NAME="Windows 10/11"   # Teal/Cyan
        ;;
    "GPU1-75")
        BG="#0f4c5c" FG="#88c0d0" NAME="GPU/Nvidia"   # Teal/Cyan
        ;;
    "TNAPP01")
        BG="#3e3279ff" FG="#be95ff" NAME="App/n8n/Postgres"   # Purple
        ;;
    "TNHL01")
        BG="#461d07ff" FG="#ff8a65" NAME="Proxmox"   # Orange
        ;;
    "TNFS1"|"TNFS2")
        BG="#02445aff" FG="#66c2e0" NAME="TrueNAS Scale"   # Ocean Blue / Aqua
        ;;
    "TRAEFIK")
        BG="#023636ff" FG="#7fffd4" NAME="Traefik"   # Teal
        ;;        
    "MONITOR")
        BG="#2b2d30" FG="#f28a30" NAME="Monitor/Grafana/Prometheus"   # Graphite/Orange
        ;;        
    "FIELDS10"|"FIELDS11")
        #BG="#0a3d62" FG="#6ea8d5" NAME="Windows 10/11"
        BG="#2d3144ff" FG="#d6d5ffff" NAME="LOCAL" # Purple        
        ;;
    *)
        BG="#3d0000" FG="#ff9999" NAME="Unknown"
        log "WARN" "No color map for $HOST_ID; using fallback."
        ;;
esac

# Resolve colors from environment first, then fallback to case defaults
TITLE_BG="${DT_COLOR_TITLE_BG:-$BG}"
TITLE_FG="${DT_COLOR_TITLE_FG:-$FG}"
STATUS_BG="${DT_COLOR_STATUS_BG:-$BG}"
STATUS_FG="${DT_COLOR_STATUS_FG:-$FG}"
ACTIVITY_BG="${DT_COLOR_ACTIVITY_BG:-$BG}"
ACTIVITY_FG="${DT_COLOR_ACTIVITY_FG:-$FG}"

# Debug: show resolved base colors
if [ "$DEBUG_MODE" = 1 ]; then
    log "DEBUG" "Base colors before darken: TITLE=${TITLE_BG}/${TITLE_FG}, STATUS=${STATUS_BG}/${STATUS_FG}, ACTIVITY=${ACTIVITY_BG}/${ACTIVITY_FG}"
fi

# Optional darken factors (0.0–1.0, where 0 = no change, 0.2 = 20% darker). Defaults to 0.
COLOR_DARKEN_FACTOR_BG="${DT_COLOR_DARKEN_FACTOR_BG:-0}"
COLOR_DARKEN_FACTOR_FG="${DT_COLOR_DARKEN_FACTOR_FG:-0}"

darken_hex() {
    # Darken a hex color by factor (0-1). Expects #RRGGBB. Returns #RRGGBB.
    local hex="$1"; local factor="$2"
    # Strip leading '#'
    hex="${hex#\#}"
    if [[ ! "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "#$hex"; return
    fi
    local r=${hex:0:2} g=${hex:2:2} b=${hex:4:2}
    local r_dec=$((16#${r}))
    local g_dec=$((16#${g}))
    local b_dec=$((16#${b}))
    # factor is 0..1; darken means reduce by factor*value
    local r_new=$(printf "%02x" $(awk -v v="$r_dec" -v f="$factor" 'BEGIN { printf int(v*(1-f)+0.5) }'))
    local g_new=$(printf "%02x" $(awk -v v="$g_dec" -v f="$factor" 'BEGIN { printf int(v*(1-f)+0.5) }'))
    local b_new=$(printf "%02x" $(awk -v v="$b_dec" -v f="$factor" 'BEGIN { printf int(v*(1-f)+0.5) }'))
    echo "#$r_new$g_new$b_new"
}

apply_darken_if_needed() {
    local color="$1"
    local factor="$2"
    
    # Strip alpha channel if present (8-digit hex codes like #RRGGBBaa)
    if [[ "$color" =~ ^#[0-9a-fA-F]{8}$ ]]; then
        color="${color:0:7}"  # Keep only first 7 chars (#RRGGBB)
    fi
    
    if [[ "$factor" == "0" || "$factor" == "0.0" ]]; then
        echo "$color"
    else
        darken_hex "$color" "$factor"
    fi
}

# Apply darken factors to backgrounds and foregrounds
TITLE_BG=$(apply_darken_if_needed "$TITLE_BG" "$COLOR_DARKEN_FACTOR_BG")
TITLE_FG=$(apply_darken_if_needed "$TITLE_FG" "$COLOR_DARKEN_FACTOR_FG")
STATUS_BG=$(apply_darken_if_needed "$STATUS_BG" "$COLOR_DARKEN_FACTOR_BG")
STATUS_FG=$(apply_darken_if_needed "$STATUS_FG" "$COLOR_DARKEN_FACTOR_FG")
ACTIVITY_BG=$(apply_darken_if_needed "$ACTIVITY_BG" "$COLOR_DARKEN_FACTOR_BG")
ACTIVITY_FG=$(apply_darken_if_needed "$ACTIVITY_FG" "$COLOR_DARKEN_FACTOR_FG")

# Debug: show final colors after darken
if [ "$DEBUG_MODE" = 1 ]; then
    log "DEBUG" "Final colors after darken: TITLE=${TITLE_BG}/${TITLE_FG}, STATUS=${STATUS_BG}/${STATUS_FG}, ACTIVITY=${ACTIVITY_BG}/${ACTIVITY_FG}"
fi

# Log colors with darken info only if factors > 0
darken_info=""
if [[ "$COLOR_DARKEN_FACTOR_BG" != "0" && "$COLOR_DARKEN_FACTOR_BG" != "0.0" ]]; then
    darken_info="darken_bg=${COLOR_DARKEN_FACTOR_BG}"
fi
if [[ "$COLOR_DARKEN_FACTOR_FG" != "0" && "$COLOR_DARKEN_FACTOR_FG" != "0.0" ]]; then
    if [[ -n "$darken_info" ]]; then
        darken_info="${darken_info}, darken_fg=${COLOR_DARKEN_FACTOR_FG}"
    else
        darken_info="darken_fg=${COLOR_DARKEN_FACTOR_FG}"
    fi
fi
if [[ -n "$darken_info" ]]; then
    log "INFO" "Using colors → TITLE: ${TITLE_BG}/${TITLE_FG}, STATUS: ${STATUS_BG}/${STATUS_FG}, ACTIVITY: ${ACTIVITY_BG}/${ACTIVITY_FG}"
    log "INFO" "Darken info: ${darken_info}"
else
    log "INFO" "Using colors → TITLE: ${TITLE_BG}/${TITLE_FG}, STATUS: ${STATUS_BG}/${STATUS_FG}, ACTIVITY: ${ACTIVITY_BG}/${ACTIVITY_FG}"
fi

# Settings file on remote
SETTINGS_DIR="$HOME/.vscode-server/data/Machine"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
mkdir -p "$SETTINGS_DIR"

## window.title options:
# Available variables for customizing the VS Code window title:
#
# File-related:
#   ${activeEditorShort}: the file name (e.g. myFile.txt)
#   ${activeEditorMedium}: the path of the file relative to the workspace folder (e.g. myFolder/myFileFolder/myFile.txt)
#   ${activeEditorLong}: the full path of the file (e.g. /Users/Development/myProject/myFolder/myFileFolder/myFile.txt)
#   ${activeFolderShort}: the name of the folder the file is contained in (e.g. myFileFolder)
#   ${activeFolderMedium}: the path of the folder the file is contained in, relative to the workspace folder (e.g. myFolder/myFileFolder)
#   ${activeFolderLong}: the full path of the folder the file is contained in (e.g. /Users/Development/myProject/myFolder/myFileFolder)
#
# Workspace/Folder-related:
#   ${folderName}: name of the workspace folder the file is contained in (e.g. myProject)
#   ${folderPath}: file path of the workspace folder the file is contained in (e.g. /Users/Development/myProject)
#   ${rootName}: name of the opened workspace or folder (e.g. myProject)
#   ${rootPath}: file path of the opened workspace or folder (e.g. /Users/Development/myProject)
#
# Application/Environment:
#   ${appName}: e.g. Visual Studio Code
#   ${remoteName}: e.g. SSH (shows the remote connection type)
#   ${dirty}: a dirty indicator (*) if the active editor is dirty
#   ${separator}: conditional separator (' - ')
#
# Examples:
#   "${remoteName}${separator}${folderName}${separator}${activeEditorShort}${separator}${appName}"
#   "${rootName} - ${activeEditorShort} ${dirty}"
#   "${remoteName}: ${folderPath}/${activeEditorShort}"
#
# NOTE: $ must be escaped as \$ in JSON strings to avoid variable expansion when VS Code reads the settings file.
#       In bash, use \${variable} in the heredoc.

# JSON override snippet (add your test title here for verification)
JSON_SNIPPET=$(cat <<EOF
{
  "workbench.colorCustomizations": {
        "activityBar.background": "$ACTIVITY_BG",
        "activityBar.foreground": "$ACTIVITY_FG",
        "statusBar.background": "$STATUS_BG",
        "statusBar.foreground": "$STATUS_FG",
        "titleBar.activeBackground": "$TITLE_BG",
        "titleBar.activeForeground": "$TITLE_FG",
        "statusBarItem.remoteBackground": "$STATUS_BG",
        "statusBarItem.remoteForeground": "$STATUS_FG"
  },
  "window.title": "\${folderName} [\${remoteName}]\${separator}\${activeEditorShort}"
}
EOF
)

if [ "$TEST_MODE" = 1 ]; then
    log "INFO" "TEST MODE: Would merge colors for $NAME ($HOST_ID) → $BG"
    echo "$JSON_SNIPPET"
    exit 0
fi

# Debug: show JSON snippet
if [ "$DEBUG_MODE" = 1 ]; then
    log "DEBUG" "JSON snippet to merge:"
    echo "$JSON_SNIPPET" | jq . 2>/dev/null || echo "$JSON_SNIPPET"
fi

# Backup existing if present
[ -f "$SETTINGS_FILE" ] && cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak.$(date +%s)"
log "INFO" "Backed up existing settings (if any)."

# Merge with jq (install if missing: sudo apt install jq)
if ! command -v jq >/dev/null; then
    log "ERROR" "jq not installed. Install with 'sudo apt install jq' and retry."
    exit 1
fi

# Merge: Load existing (or empty {}), overlay snippet
( [ -f "$SETTINGS_FILE" ] && cat "$SETTINGS_FILE" || echo '{}' ) | jq --argjson overlay "$JSON_SNIPPET" '. * $overlay' > "$SETTINGS_FILE.tmp"
mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

log "INFO" "Merged VS Code remote settings for $NAME ($HOST_ID) → ${TITLE_BG}"
log "INFO" "Reload VS Code window to apply (Ctrl+Shift+P → Developer: Reload Window)."
log "INFO" "Check title bar for '[OVERRIDE LOADED!]' and activity bar for color change."