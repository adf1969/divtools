#!/bin/bash
#
# host_change_analyzer.sh - AI-powered host change analysis using local LLM
#
# This script collects host changes and uses a local LLM (Ollama/LM Studio)
# to analyze them for security concerns, configuration drift, and anomalies.
# Results are stored in a persistent audit log.
#
# Requirements:
#   - Ollama installed (curl -fsSL https://ollama.com/install.sh | sh)
#   - A model downloaded (ollama pull llama3.2 or mistral)
#   - jq for JSON processing
#   - curl for API calls
#
# Usage:
#   ./host_change_analyzer.sh analyze    # Run analysis and update log
#   ./host_change_analyzer.sh report     # Show recent analysis results
#   ./host_change_analyzer.sh history    # Show full audit history
#   ./host_change_analyzer.sh setup      # Install Ollama and configure
#

set -euo pipefail

# Configuration
SCRIPT_NAME=$(basename "$0")
MONITOR_BASE_DIR="/var/log/divtools/monitor"
AUDIT_LOG_DIR="${MONITOR_BASE_DIR}/audit"
AUDIT_LOG_FILE="${AUDIT_LOG_DIR}/change_audit.log"
ANALYSIS_DIR="${AUDIT_LOG_DIR}/analyses"
LAST_CHECK_FILE="${AUDIT_LOG_DIR}/last_check.timestamp"

# LLM Configuration
LLM_PROVIDER="${LLM_PROVIDER:-ollama}"  # ollama or lmstudio
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
LMSTUDIO_HOST="${LMSTUDIO_HOST:-http://localhost:1234}"
LLM_MODEL="${LLM_MODEL:-llama3.2}"  # or mistral, phi3, etc.
LLM_TEMPERATURE="${LLM_TEMPERATURE:-0.3}"  # Lower = more focused

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_ai() {
    echo -e "${MAGENTA}[AI]${NC} $*"
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi
    
    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_info "Install with: apt install ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Check if LLM is available
check_llm_available() {
    case "$LLM_PROVIDER" in
        ollama)
            if ! command -v ollama &>/dev/null; then
                log_warning "Ollama not installed"
                return 1
            fi
            
            if ! curl -s "${OLLAMA_HOST}/api/tags" &>/dev/null; then
                log_warning "Ollama service not running"
                log_info "Start with: ollama serve"
                return 1
            fi
            
            # Check if model is available
            if ! curl -s "${OLLAMA_HOST}/api/tags" | jq -e ".models[] | select(.name | contains(\"${LLM_MODEL}\"))" &>/dev/null; then
                log_warning "Model '${LLM_MODEL}' not found"
                log_info "Download with: ollama pull ${LLM_MODEL}"
                return 1
            fi
            ;;
        
        lmstudio)
            if ! curl -s "${LMSTUDIO_HOST}/v1/models" &>/dev/null; then
                log_warning "LM Studio not running at ${LMSTUDIO_HOST}"
                return 1
            fi
            ;;
        
        *)
            log_error "Unknown LLM provider: ${LLM_PROVIDER}"
            return 1
            ;;
    esac
    
    log_success "LLM provider '${LLM_PROVIDER}' is available"
    return 0
}

# Setup directories
setup_directories() {
    mkdir -p "${AUDIT_LOG_DIR}"
    mkdir -p "${ANALYSIS_DIR}"
    chmod 755 "${AUDIT_LOG_DIR}"
    chmod 755 "${ANALYSIS_DIR}"
}

# Collect system changes since last check
collect_changes() {
    local since_date=""
    
    if [[ -f "$LAST_CHECK_FILE" ]]; then
        since_date=$(cat "$LAST_CHECK_FILE")
        log_info "Collecting changes since: ${since_date}"
    else
        since_date=$(date -d '1 day ago' '+%Y-%m-%d %H:%M:%S')
        log_info "First run - checking last 24 hours"
    fi
    
    local changes_file="${ANALYSIS_DIR}/changes_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$changes_file" <<EOF
{
  "hostname": "$(hostname)",
  "collection_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "since": "${since_date}",
  "changes": {
EOF
    
    # Collect bash history changes
    log_info "Collecting command history..."
    echo '    "command_history": {' >> "$changes_file"
    
    local first_user=true
    for histfile in "${MONITOR_BASE_DIR}"/history/*.latest; do
        if [[ -f "$histfile" ]]; then
            local user=$(basename "$histfile" .bash_history.latest)
            [[ "$first_user" != true ]] && echo "," >> "$changes_file"
            echo -n "      \"${user}\": " >> "$changes_file"
            
            # Get commands since last check
            if [[ -f "$LAST_CHECK_FILE" ]]; then
                grep "^${since_date:0:10}" "$histfile" 2>/dev/null | tail -50 | jq -R . | jq -s . >> "$changes_file"
            else
                tail -50 "$histfile" | jq -R . | jq -s . >> "$changes_file"
            fi
            first_user=false
        fi
    done
    [[ "$first_user" == true ]] && echo -n "null" >> "$changes_file"
    echo >> "$changes_file"
    echo '    },' >> "$changes_file"
    
    # Collect APT changes
    log_info "Collecting package changes..."
    echo '    "apt_changes": ' >> "$changes_file"
    if [[ -f /var/log/dpkg.log ]]; then
        awk -v date="${since_date}" '$0 > date && / (install|remove|upgrade) / {print}' /var/log/dpkg.log 2>/dev/null | tail -20 | jq -R . | jq -s . >> "$changes_file"
    else
        echo "[]" >> "$changes_file"
    fi
    echo ',' >> "$changes_file"
    
    # Collect docker changes
    log_info "Checking docker configurations..."
    echo '    "docker_changes": {' >> "$changes_file"
    echo -n '      "config_integrity": ' >> "$changes_file"
    
    if [[ -f "${MONITOR_BASE_DIR}/checksums/docker_configs.sha256" ]]; then
        cd /home/divix/divtools 2>/dev/null || cd /
        local checksum_result=$(sha256sum -c "${MONITOR_BASE_DIR}/checksums/docker_configs.sha256" 2>&1 | grep -v "OK$" || echo "OK")
        if [[ "$checksum_result" == "OK" ]]; then
            echo '"verified",' >> "$changes_file"
        else
            echo '"MODIFIED",' >> "$changes_file"
        fi
        echo -n '      "modified_files": ' >> "$changes_file"
        echo "$checksum_result" | grep -v "^OK$" | awk '{print $1}' | jq -R . | jq -s . >> "$changes_file"
    else
        echo '"unknown",' >> "$changes_file"
        echo '      "modified_files": []' >> "$changes_file"
    fi
    echo '    },' >> "$changes_file"
    
    # Collect security events
    log_info "Collecting security events..."
    echo '    "security_events": {' >> "$changes_file"
    echo -n '      "auth_failures": ' >> "$changes_file"
    grep "Failed password" /var/log/auth.log 2>/dev/null | \
        awk -v date="${since_date}" '$0 > date {print}' | tail -20 | jq -R . | jq -s . >> "$changes_file"
    echo ',' >> "$changes_file"
    
    echo -n '      "sudo_usage": ' >> "$changes_file"
    grep "sudo:" /var/log/auth.log 2>/dev/null | \
        awk -v date="${since_date}" '$0 > date {print}' | tail -20 | jq -R . | jq -s . >> "$changes_file"
    echo ',' >> "$changes_file"
    
    echo -n '      "new_logins": ' >> "$changes_file"
    grep "Accepted" /var/log/auth.log 2>/dev/null | \
        awk -v date="${since_date}" '$0 > date {print}' | tail -20 | jq -R . | jq -s . >> "$changes_file"
    echo >> "$changes_file"
    echo '    },' >> "$changes_file"
    
    # System health
    log_info "Collecting system health..."
    echo '    "system_health": {' >> "$changes_file"
    echo -n '      "disk_usage": ' >> "$changes_file"
    df -h | awk 'NR>1 {print}' | jq -R . | jq -s . >> "$changes_file"
    echo ',' >> "$changes_file"
    
    echo -n '      "failed_services": ' >> "$changes_file"
    systemctl --failed --no-pager 2>/dev/null | jq -R . | jq -s . >> "$changes_file"
    echo ',' >> "$changes_file"
    
    echo -n '      "critical_errors": ' >> "$changes_file"
    journalctl --since "${since_date}" --priority=err --no-pager 2>/dev/null | tail -20 | jq -R . | jq -s . >> "$changes_file"
    echo >> "$changes_file"
    echo '    }' >> "$changes_file"
    
    # Close JSON
    echo '  }' >> "$changes_file"
    echo '}' >> "$changes_file"
    
    log_success "Changes collected: ${changes_file}"
    echo "$changes_file"
}

# Call LLM for analysis
call_llm() {
    local prompt="$1"
    local response_file="${2:-/tmp/llm_response.json}"
    
    case "$LLM_PROVIDER" in
        ollama)
            log_ai "Analyzing with Ollama (${LLM_MODEL})..."
            curl -s "${OLLAMA_HOST}/api/generate" \
                -d "{
                    \"model\": \"${LLM_MODEL}\",
                    \"prompt\": $(echo "$prompt" | jq -Rs .),
                    \"stream\": false,
                    \"options\": {
                        \"temperature\": ${LLM_TEMPERATURE}
                    }
                }" | jq -r '.response' > "$response_file"
            ;;
        
        lmstudio)
            log_ai "Analyzing with LM Studio..."
            curl -s "${LMSTUDIO_HOST}/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -d "{
                    \"messages\": [
                        {\"role\": \"system\", \"content\": \"You are a Linux system administrator security analyst.\"},
                        {\"role\": \"user\", \"content\": $(echo "$prompt" | jq -Rs .)}
                    ],
                    \"temperature\": ${LLM_TEMPERATURE}
                }" | jq -r '.choices[0].message.content' > "$response_file"
            ;;
    esac
    
    if [[ -s "$response_file" ]]; then
        log_success "Analysis complete"
        return 0
    else
        log_error "Failed to get response from LLM"
        return 1
    fi
}

# Analyze changes with LLM
analyze_changes() {
    local changes_file="$1"
    
    if [[ ! -f "$changes_file" ]]; then
        log_error "Changes file not found: ${changes_file}"
        return 1
    fi
    
    log_info "Analyzing changes with AI..."
    
    # Build the prompt
    local prompt="You are a Linux system administrator analyzing host changes for security and operational concerns.

Analyze the following system changes and provide a structured assessment.

HOST DATA:
$(cat "$changes_file")

Analyze the data and respond in this EXACT JSON format (no markdown, just JSON):
{
  \"severity\": \"low|medium|high|critical\",
  \"summary\": \"Brief one-line summary of findings\",
  \"concerns\": [
    {\"type\": \"security|config|operational\", \"issue\": \"description\", \"severity\": \"low|medium|high|critical\"}
  ],
  \"recommendations\": [\"actionable recommendation 1\", \"actionable recommendation 2\"],
  \"suspicious_activity\": true/false,
  \"requires_immediate_action\": true/false,
  \"details\": \"Detailed explanation of findings\"
}

Focus on:
1. Unauthorized access attempts or suspicious commands
2. Unexpected package installations or configuration changes
3. Security vulnerabilities or policy violations
4. System health issues requiring attention
5. Unusual patterns in command history

Be thorough but practical. Only flag genuine concerns."

    # Call LLM
    local analysis_file="${changes_file%.json}_analysis.json"
    local raw_response="${changes_file%.json}_raw_response.txt"
    
    if ! call_llm "$prompt" "$raw_response"; then
        return 1
    fi
    
    # Try to extract JSON from response (in case LLM adds markdown formatting)
    if echo "$(<"$raw_response")" | jq empty 2>/dev/null; then
        # Already valid JSON
        cat "$raw_response" > "$analysis_file"
    else
        # Try to extract JSON from markdown code blocks
        sed -n '/^```json/,/^```/p' "$raw_response" | sed '1d;$d' > "$analysis_file" 2>/dev/null || \
        sed -n '/^{/,/^}/p' "$raw_response" > "$analysis_file"
    fi
    
    # Validate JSON
    if ! jq empty "$analysis_file" 2>/dev/null; then
        log_warning "LLM response is not valid JSON, saving as text"
        mv "$raw_response" "${analysis_file%.json}.txt"
        return 1
    fi
    
    log_success "Analysis saved: ${analysis_file}"
    
    # Add to audit log
    append_to_audit_log "$changes_file" "$analysis_file"
    
    # Update last check timestamp
    date '+%Y-%m-%d %H:%M:%S' > "$LAST_CHECK_FILE"
    
    echo "$analysis_file"
}

# Append analysis to audit log
append_to_audit_log() {
    local changes_file="$1"
    local analysis_file="$2"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local severity=$(jq -r '.severity // "unknown"' "$analysis_file" 2>/dev/null)
    local summary=$(jq -r '.summary // "Analysis completed"' "$analysis_file" 2>/dev/null)
    
    # Create audit log entry
    cat >> "$AUDIT_LOG_FILE" <<EOF

================================================================================
AUDIT ENTRY: ${timestamp}
================================================================================
Hostname: $(hostname)
Severity: ${severity}
Summary: ${summary}

Analysis File: ${analysis_file}
Changes File: ${changes_file}

$(jq -r '.concerns[]? | "- [\(.severity | ascii_upcase)] \(.type): \(.issue)"' "$analysis_file" 2>/dev/null || echo "No concerns listed")

Recommendations:
$(jq -r '.recommendations[]? | "- \(.)"' "$analysis_file" 2>/dev/null || echo "None")

Requires Immediate Action: $(jq -r '.requires_immediate_action // false' "$analysis_file" 2>/dev/null)
Suspicious Activity Detected: $(jq -r '.suspicious_activity // false' "$analysis_file" 2>/dev/null)

Details:
$(jq -r '.details // "No additional details"' "$analysis_file" 2>/dev/null)

EOF
    
    log_success "Audit log updated: ${AUDIT_LOG_FILE}"
}

# Display analysis results
show_analysis() {
    local analysis_file="$1"
    
    if [[ ! -f "$analysis_file" ]]; then
        log_error "Analysis file not found: ${analysis_file}"
        return 1
    fi
    
    local severity=$(jq -r '.severity' "$analysis_file")
    local summary=$(jq -r '.summary' "$analysis_file")
    local requires_action=$(jq -r '.requires_immediate_action' "$analysis_file")
    local suspicious=$(jq -r '.suspicious_activity' "$analysis_file")
    
    echo
    echo "================================================================================"
    echo -e "${CYAN}HOST CHANGE ANALYSIS REPORT${NC}"
    echo "================================================================================"
    echo -e "Hostname:    ${GREEN}$(hostname)${NC}"
    echo -e "Timestamp:   $(date)"
    
    # Color-code severity
    case "$severity" in
        critical) echo -e "Severity:    ${RED}CRITICAL${NC}" ;;
        high)     echo -e "Severity:    ${YELLOW}HIGH${NC}" ;;
        medium)   echo -e "Severity:    ${YELLOW}MEDIUM${NC}" ;;
        low)      echo -e "Severity:    ${GREEN}LOW${NC}" ;;
        *)        echo -e "Severity:    ${severity}" ;;
    esac
    
    echo -e "Summary:     ${summary}"
    echo
    
    if [[ "$requires_action" == "true" ]]; then
        echo -e "${RED}⚠️  IMMEDIATE ACTION REQUIRED${NC}"
    fi
    
    if [[ "$suspicious" == "true" ]]; then
        echo -e "${RED}🚨 SUSPICIOUS ACTIVITY DETECTED${NC}"
    fi
    
    echo
    echo "Concerns:"
    jq -r '.concerns[]? | "  [\(.severity | ascii_upcase)] \(.type): \(.issue)"' "$analysis_file" | \
        while read -r line; do
            if [[ "$line" =~ CRITICAL|HIGH ]]; then
                echo -e "${RED}${line}${NC}"
            elif [[ "$line" =~ MEDIUM ]]; then
                echo -e "${YELLOW}${line}${NC}"
            else
                echo "$line"
            fi
        done
    
    echo
    echo "Recommendations:"
    jq -r '.recommendations[]? | "  - \(.)"' "$analysis_file"
    
    echo
    echo "Details:"
    jq -r '.details' "$analysis_file" | fold -s -w 78 | sed 's/^/  /'
    
    echo
    echo "================================================================================"
    echo
}

# Show recent audit history
show_recent_reports() {
    local count="${1:-10}"
    
    if [[ ! -f "$AUDIT_LOG_FILE" ]]; then
        log_warning "No audit log found"
        return 1
    fi
    
    echo
    echo "Recent Analysis Reports (last ${count}):"
    echo "================================================================================"
    
    # Extract last N entries
    awk '/^AUDIT ENTRY:/ {if (count++ >= '"$count"') exit} {print}' "$AUDIT_LOG_FILE" | tail -200
}

# Show full audit history
show_full_history() {
    if [[ ! -f "$AUDIT_LOG_FILE" ]]; then
        log_warning "No audit log found"
        return 1
    fi
    
    less "$AUDIT_LOG_FILE"
}

# Run complete analysis workflow
run_analysis() {
    log_info "Starting host change analysis..."
    echo
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    # Check LLM availability
    if ! check_llm_available; then
        log_error "LLM not available. Run './$(basename "$0") setup' to install and configure."
        return 1
    fi
    
    # Setup directories
    setup_directories
    
    # Collect changes
    local changes_file=$(collect_changes)
    
    echo
    
    # Analyze with LLM
    local analysis_file=$(analyze_changes "$changes_file")
    
    if [[ -n "$analysis_file" && -f "$analysis_file" ]]; then
        echo
        show_analysis "$analysis_file"
        
        # Check if action required
        if jq -e '.requires_immediate_action == true' "$analysis_file" &>/dev/null; then
            log_error "IMMEDIATE ACTION REQUIRED - Review the analysis above"
            return 2
        fi
        
        return 0
    else
        log_error "Analysis failed"
        return 1
    fi
}

# Setup function - install Ollama and configure
setup_ollama() {
    log_info "Setting up Ollama for local LLM analysis..."
    
    # Check if Ollama is already installed
    if command -v ollama &>/dev/null; then
        log_success "Ollama is already installed"
    else
        log_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    # Start Ollama service
    if ! systemctl is-active --quiet ollama 2>/dev/null; then
        log_info "Starting Ollama service..."
        if command -v systemctl &>/dev/null; then
            sudo systemctl start ollama 2>/dev/null || ollama serve &
        else
            ollama serve &
        fi
        sleep 3
    fi
    
    # Pull recommended model
    log_info "Downloading recommended model (${LLM_MODEL})..."
    log_warning "This may take a few minutes..."
    ollama pull "${LLM_MODEL}"
    
    log_success "Setup complete!"
    echo
    echo "Available models:"
    ollama list
    echo
    echo "You can now run: $0 analyze"
}

# Usage
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
  analyze              Run analysis on recent changes
  report [N]           Show last N analysis reports (default: 10)
  history              Show full audit history
  setup                Install and configure Ollama
  test-llm             Test LLM connection
  
Environment Variables:
  LLM_PROVIDER         ollama (default) or lmstudio
  LLM_MODEL            Model to use (default: llama3.2)
  OLLAMA_HOST          Ollama API endpoint (default: http://localhost:11434)
  LMSTUDIO_HOST        LM Studio API endpoint (default: http://localhost:1234)
  LLM_TEMPERATURE      Response creativity 0-1 (default: 0.3)

Examples:
  # Initial setup
  $SCRIPT_NAME setup
  
  # Run analysis
  $SCRIPT_NAME analyze
  
  # View recent reports
  $SCRIPT_NAME report 5
  
  # Use different model
  LLM_MODEL=mistral $SCRIPT_NAME analyze
  
  # Use LM Studio instead
  LLM_PROVIDER=lmstudio $SCRIPT_NAME analyze

Recommended Models:
  - llama3.2 (3B) - Fast, good for analysis
  - mistral (7B) - More detailed analysis
  - phi3 (3.8B) - Efficient, good reasoning
  
Audit Log Location:
  ${AUDIT_LOG_FILE}

EOF
}

# Main
main() {
    case "${1:-help}" in
        analyze)
            run_analysis
            ;;
        
        report)
            show_recent_reports "${2:-10}"
            ;;
        
        history)
            show_full_history
            ;;
        
        setup)
            setup_ollama
            ;;
        
        test-llm)
            check_dependencies && check_llm_available
            ;;
        
        help|--help|-h)
            usage
            ;;
        
        *)
            log_error "Unknown command: $1"
            echo
            usage
            exit 1
            ;;
    esac
}

main "$@"
