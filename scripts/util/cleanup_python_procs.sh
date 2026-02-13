#!/bin/bash
# Clean up stray Python processes (testing, development, abandoned processes)
# Last Updated: 01/16/2026 03:45:00 PM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Defaults
TEST_MODE=0
DEBUG_MODE=0
FORCE_KILL=0
FILTER_PATTERN=""
SHOW_ONLY=0

show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║           PYTHON PROCESS CLEANUP UTILITY - cleanup_python_procs.sh         ║
║                                                                            ║
║  Helps manage and clean up stray Python processes from testing, dev work, ║
║  or abandoned applications. Supports filtering and safe deletion modes.   ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

USAGE:
    cleanup_python_procs.sh [OPTIONS]

SYNOPSIS:
    Show all Python processes:
        $ cleanup_python_procs.sh
    
    Show only ADS-related processes:
        $ cleanup_python_procs.sh dt_ads
    
    Safely test what would be killed (test mode):
        $ cleanup_python_procs.sh -test dt_ads
    
    Actually kill the processes (requires -force):
        $ cleanup_python_procs.sh -force dt_ads
    
    Kill all Python processes (use with caution):
        $ cleanup_python_procs.sh -force -all

OPTIONS:
    -test, --test           TEST MODE: Show what would be killed without executing
    -force, --force         Actually kill processes (required for killing)
    -all                    Include ALL Python processes (not just testing/dev)
    -show, --show           Show matching processes (default action)
    -debug, --debug         Enable debug output
    -help, --help           Show this help message

FILTER PATTERNS:
    When specified, only processes matching the pattern are shown/killed:
    
    dt_ads              Kill dt_ads_native.py processes
    pytest              Kill pytest and test runner processes
    textual             Kill Textual TUI application processes
    dtpmenu             Kill dtpmenu menu processes
    dtads_setup         Kill dtads_setup processes
    
    You can also specify custom patterns:
    $ cleanup_python_procs.sh -test my_script
    $ cleanup_python_procs.sh -force "pytest|test_"

EXAMPLES:

    # Show all Python processes
    cleanup_python_procs.sh
    
    # Show ADS-related Python processes
    cleanup_python_procs.sh dt_ads
    
    # Show what would be killed (test mode)
    cleanup_python_procs.sh -test dt_ads
    
    # Actually kill matching processes
    cleanup_python_procs.sh -force dt_ads
    
    # Kill pytest and test processes
    cleanup_python_procs.sh -test pytest
    cleanup_python_procs.sh -force pytest
    
    # Kill all stray Python processes (careful!)
    cleanup_python_procs.sh -test -all
    cleanup_python_procs.sh -force -all
    
    # Multiple patterns
    cleanup_python_procs.sh -test "dt_ads|pytest"
    cleanup_python_procs.sh -force "textual|dtpmenu"

SAFETY FEATURES:
    - Test mode (-test) shows what would happen WITHOUT making changes
    - Force flag (-force) required to actually kill processes
    - Processes are killed with TERM signal first (graceful)
    - After 2 seconds, KILL signal is used if needed (forceful)
    - Process tree killing: child processes are also terminated

RETURN CODES:
    0   Successful execution
    1   No matching processes found
    2   Invalid arguments
    127 User cancelled

OUTPUT:
    Processes are shown in a table format with:
    - User: Owner of the process
    - PID: Process ID
    - %CPU: CPU usage percentage
    - %MEM: Memory usage percentage
    - TIME: CPU time consumed
    - COMMAND: Full command line

PROCESS SIGNALS:
    TERM (15)  - Graceful termination (default, waits 2 seconds)
    KILL (9)   - Forceful termination (if TERM doesn't work)

NOTES:
    - Be careful with -force flag without a filter
    - Use -test first to see what would be killed
    - Some system Python processes may be protected
    - Run with -debug for detailed process information

For more information, see:
    /home/divix/divtools/scripts/util/

EOF
}

show_processes() {
    local pattern="$1"
    local cmd="ps aux | grep '[p]ython'"
    
    if [[ -n "$pattern" ]]; then
        cmd="$cmd | grep -i '$pattern'"
    fi
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Command: $cmd"
    fi
    
    local output=$(eval "$cmd")
    
    if [[ -z "$output" ]]; then
        if [[ -n "$pattern" ]]; then
            log "INFO" "No Python processes found matching: $pattern"
        else
            log "INFO" "No Python processes found"
        fi
        return 1
    fi
    
    log "HEAD" "════════════════════════════════════════════════════════════════════════"
    log "HEAD" "Python Processes:"
    log "HEAD" "════════════════════════════════════════════════════════════════════════"
    
    # Format output with headers
    printf "%-8s %-8s %6s %6s %8s %-70s\n" \
        "USER" "PID" "%CPU" "%MEM" "TIME" "COMMAND"
    printf "%-8s %-8s %6s %6s %8s %-70s\n" \
        "────────" "────────" "──────" "──────" "────────" "────────────────────────────────────────────────────────"
    
    eval "$cmd" | awk '{
        user = $1
        pid = $2
        cpu = $3
        mem = $4
        time = $10
        cmd = ""
        for (i=11; i<=NF; i++) cmd = cmd $i " "
        
        # Remove /opt/divtools/ prefix from command (common path for divtools)
        gsub(/\/opt\/divtools\//, "", cmd)
        
        # Trim from the FRONT (beginning) if too long, keeping the useful part at end
        max_len = 70
        if (length(cmd) > max_len) {
            # Keep the last 67 chars and prepend "..." to show it was trimmed
            cmd = "..." substr(cmd, length(cmd) - 66)
        }
        printf "%-8s %-8s %6s %6s %8s %-70s\n", user, pid, cpu, mem, time, cmd
    }'
    
    echo ""
}

kill_processes() {
    local pattern="$1"
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "kill_processes() called with pattern: '${pattern:-'(none)'}'"
    fi
    
    local cmd="pgrep -f '[p]ython.*$pattern'"
    
    if [[ -n "$pattern" && "$pattern" != "-all" ]]; then
        cmd="pgrep -f '[p]ython.*$pattern'"
    else
        cmd="pgrep -f '[p]ython'"
    fi
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Getting processes: $cmd"
        log "DEBUG" "Excluding: cleanup_python_procs script (self) and own PID $$"
    fi
    
    # Get PIDs but exclude this script and cleanup script processes
    local pids=$(eval "$cmd" 2>/dev/null | grep -v "cleanup_python_procs" | grep -v "^$$\$" || echo "")
    
    if [[ -z "$pids" ]]; then
        if [[ -n "$pattern" ]]; then
            log "WARN" "No Python processes found matching: $pattern"
        else
            log "WARN" "No Python processes found"
        fi
        return 1
    fi
    
    # Count processes
    local count=$(echo "$pids" | wc -l)
    log "HEAD" "Found $count Python process(es) to terminate"
    echo ""
    
    # Show processes being killed
    for pid in $pids; do
        local proc_info=$(ps -p "$pid" -o user=,pid=,cmd= 2>/dev/null)
        log "INFO" "  [$pid] $proc_info"
    done
    
    echo ""
    
    if [[ $TEST_MODE -eq 1 ]]; then
        log "INFO" "TEST MODE: Would terminate these processes (run without -test to execute)"
        return 0
    fi
    
    # Ask for confirmation ONLY if -force flag is NOT set
    if [[ $FORCE_KILL -eq 0 ]]; then
        log "WARN" "About to terminate these processes. Continue? [y/N]"
        read -r -n 1 -t 10 response
        echo ""
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "INFO" "Cancelled by user"
            return 127
        fi
    else
        log "INFO" "Force kill enabled - proceeding without confirmation"
        echo ""
    fi
    
    # Kill processes gracefully first
    log "INFO" "Sending TERM signal (graceful termination)..."
    term_count=0
    for pid in $pids; do
        if [[ $DEBUG_MODE -eq 1 ]]; then
            log "DEBUG" "kill -15 $pid"
        fi
        kill -15 "$pid" 2>/dev/null || true
        ((term_count++))
    done
    log "INFO" "Sent TERM to $term_count process(es)"
    
    # Wait a bit for graceful shutdown
    log "INFO" "Waiting 2 seconds for graceful termination..."
    sleep 2
    
    # Check if any are still running and use KILL if needed
    remaining=$(pgrep -f "[p]ython.*${FILTER_PATTERN}" 2>/dev/null || true)
    if [[ -z "$remaining" ]]; then
        log "INFO" "All processes terminated gracefully"
        log "HEAD" "✅ All matching Python processes have been terminated"
        return 0
    fi
    
    # Kill remaining processes with SIGKILL
    log "WARN" "Processes did not terminate gracefully. Sending KILL signal (9)..."
    kill_count=$(echo "$remaining" | wc -l)
    log "INFO" "Sending KILL to $kill_count process(es)..."
    echo "$remaining" | while read pid; do
        if [[ -n "$pid" ]]; then
            if [[ $DEBUG_MODE -eq 1 ]]; then
                log "DEBUG" "kill -9 $pid (FORCE)"
            fi
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
    sleep 1
    
    # Final verification
    remaining=$(pgrep -f "[p]ython.*${FILTER_PATTERN}" 2>/dev/null || true)
    if [[ -z "$remaining" ]]; then
        log "HEAD" "✅ All matching Python processes have been terminated"
        return 0
    else
        log "ERROR" "⚠️  Some processes could not be terminated (may be in uninterruptible sleep)"
        log "ERROR" "Remaining PIDs: $remaining"
        return 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -test|--test)
                TEST_MODE=1
                log "INFO" "Running in TEST mode - no processes will be killed"
                shift
                ;;
            -force|--force)
                FORCE_KILL=1
                shift
                ;;
            -show|--show)
                SHOW_ONLY=1
                shift
                ;;
            -all)
                FILTER_PATTERN="-all"
                shift
                ;;
            -debug|--debug)
                DEBUG_MODE=1
                shift
                ;;
            -help|--help|-h)
                show_help
                exit 0
                ;;
            *)
                # Treat as filter pattern
                FILTER_PATTERN="$1"
                shift
                ;;
        esac
    done
}

main() {
    # Parse arguments
    parse_args "$@"
    
    log "HEAD" "╔════════════════════════════════════════════════════════════════════════╗"
    log "HEAD" "║           PYTHON PROCESS CLEANUP UTILITY                              ║"
    log "HEAD" "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Force Kill: $FORCE_KILL"
        log "DEBUG" "Test Mode: $TEST_MODE"
        log "DEBUG" "Filter Pattern: ${FILTER_PATTERN:-'(none - all processes)'}"
    fi
    
    # Show processes first
    if ! show_processes "$FILTER_PATTERN"; then
        return 1
    fi
    
    # Kill if requested and force flag is set
    if [[ $FORCE_KILL -eq 1 ]]; then
        if [[ $DEBUG_MODE -eq 1 ]]; then
            log "DEBUG" "FORCE_KILL is set, calling kill_processes with pattern: ${FILTER_PATTERN:-'(all)'}"
        fi
        kill_processes "$FILTER_PATTERN"
        return $?
    else
        if [[ $DEBUG_MODE -eq 1 ]]; then
            log "DEBUG" "FORCE_KILL not set, skipping kill (only showing processes)"
        fi
    fi
    
    return 0
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
