# Implementation Details & Code Review

## Script Overview

**File:** `/home/divix/divtools/scripts/util/host_chg_mon/host_change_log.sh`
**Size:** 1,142 lines
**Purpose:** Setup, orchestrate, and maintain host monitoring infrastructure
**Status:** ✅ Fully functional, recently fixed syntax error

---

## Core Components (By Function)

### 1. Environment & Configuration (Lines 1-56)

```bash
DT_LOG_DIR="${DT_LOG_DIR:-/var/log/divtools/monitor}"  # Base directory
DT_LOG_MAXSIZE="${DT_LOG_MAXSIZE:-100m}"               # Size limit
DT_LOG_MAXDAYS="${DT_LOG_MAXDAYS:-30}"                 # Age limit
DT_LOG_DIVTOOLS="${DT_LOG_DIVTOOLS:-FALSE}"            # Enable git tracking
```

**Sourcing Strategy:**
- Tries `/opt/divtools/docker/sites/s00-shared/.env.s00-shared` first (production)
- Falls back to `/home/divix/divtools/docker/sites/s00-shared/.env.s00-shared` (dev)

### 2. Directory Setup (Lines 108-134)

```bash
setup_directories() {
    mkdir -p "${MONITOR_BASE_DIR}"/{history,apt,docker,checksums,logs,bin}
    # Creates 6 subdirectories:
    # - history/    ← User bash histories (POPULATED)
    # - logs/       ← Symlinks to /var/log/* (POPULATED)
    # - checksums/  ← Docker baseline (POPULATED)
    # - apt/        ← Reserved for snapshots (EMPTY)
    # - docker/     ← Reserved for snapshots (EMPTY)
    # - bin/        ← Helper scripts (POPULATED)
}
```

### 3. Bash History Configuration (Lines 136-224)

**Strategy:** Configure PROMPT_COMMAND for real-time history saving

```bash
configure_bash_history() {
    # For each user (root, divix, drupal, syncthing):
    #   1. Enable HISTCONTROL=ignoredups:ignorespace
    #   2. Set HISTSIZE=10000 (in-memory)
    #   3. Set HISTFILESIZE=20000 (on-disk)
    #   4. Add to .bashrc:
    #
    # export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
    #                        ^^^^^^^^
    #                        Append to history after each command
    #
    #   5. Set HISTFILE to: ${MONITOR_BASE_DIR}/history/[user].bash_history.[timestamp]
}
```

**Result:** Every command is saved immediately, not just when shell exits.

### 4. Log File Symlink Creation (Lines 226-272)

```bash
setup_log_links() {
    # Creates symlinks in /opt/dtlogs/logs/ pointing to system logs:
    
    ln -sf /var/log/apt/history.log "${log_dir}/apt-history.log"
    ln -sf /var/log/dpkg.log "${log_dir}/dpkg.log"
    ln -sf /var/log/syslog "${log_dir}/syslog"
    ln -sf /var/log/auth.log "${log_dir}/auth.log"
    
    # Why symlinks not copies?
    # ✓ Real-time (always current)
    # ✓ No duplication
    # ✓ Survives rotation
    # ✓ Single source of truth
}
```

**Symlink Behavior:**
- If `/var/log/apt/history.log` gets rotated to `/var/log/apt/history.log.1`
- The symlink automatically follows the new file
- No need to update symlinks when OS rotates logs

### 5. History File Backup (Lines 276-322)

```bash
backup_current_histories() {
    # Finds all user .bash_history files across the system
    # Copies them to /opt/dtlogs/history/ with timestamp
    
    for user in root divix drupal syncthing; do
        if home_dir=$(eval echo ~$user); then
            cp "${home_dir}/.bash_history" \
               "${MONITOR_BASE_DIR}/history/${user}.bash_history.$(date +%Y%m%d-%H%M%S)"
        fi
    done
    
    # Creates symlinks for latest version:
    ln -sf [user].bash_history.20251111-201942 [user].bash_history.latest
}
```

**How This Works:**
- `.bash_history.20251111-201942` - actual history file with timestamp
- `.bash_history.latest` - always points to newest version
- When next session starts, new timestamped file is created
- Symlink automatically points to the newest one

### 6. Docker Checksum Calculation (Lines 510-527)

```bash
calculate_docker_checksums() {
    # Finds all .yml files in docker directory
    find "$docker_base" -name "*.yml" -type f -exec sha256sum {} \;
    
    # Example output stored in /opt/dtlogs/checksums/docker_configs.sha256:
    # a1b2c3d4e5f6... /home/divix/divtools/docker/docker-compose-core.yml
    # f6e5d4c3b2a1... /home/divix/divtools/docker/docker-compose-frigate.yml
    # e5d4c3b2a1f6... /home/divix/divtools/docker/docker-compose-monitor.yml
    
    # To detect changes later:
    # $ sha256sum /home/divix/divtools/docker/*.yml | diff - checksums.sha256
}
```

**Change Detection:**
- Run on first setup: creates baseline
- Run again after changes: detects what changed
- If checksums match: files unchanged
- If checksums differ: files were modified

### 7. Manifest Generation (Lines 657-726)

```bash
generate_manifest() {
    # Creates a JSON file describing what to monitor
    
    cat > monitoring_manifest.json <<EOF
    {
      "generated": "2025-11-12T02:25:09Z",
      "hostname": "TNHL01",
      "monitoring": {
        "bash_history": {
          "files": [
            {"path": "/opt/dtlogs/history/root.bash_history.latest"},
            {"path": "/opt/dtlogs/history/divix.bash_history.latest"}
          ]
        },
        "apt_packages": {
          "files": [
            {"path": "/var/log/apt/history.log"},
            {"path": "/var/log/dpkg.log"}
          ]
        },
        "docker_configs": {
          "checksum_file": "/opt/dtlogs/checksums/docker_configs.sha256"
        }
      }
    }
    EOF
}
```

**This manifest is:**
- ✅ A template for external tools (n8n)
- ✅ A human-readable description of what's monitored
- ❌ NOT for change detection
- ❌ NOT compared between runs
- ❌ Overwrites itself each run

### 8. Log Cleanup (Lines 399-493)

```bash
cleanup_old_logs() {
    # Step 1: Remove files older than DT_LOG_MAXDAYS
    find "$history_dir" -maxdepth 1 -type f -mtime "+${max_days}"
    # Removes .history.* files older than 30 days (default)
    
    # Step 2: If directory exceeds DT_LOG_MAXSIZE, remove oldest
    current_size=$(du -sb "$history_dir")
    if [[ $current_size -gt $max_size_bytes ]]; then
        # Find all files sorted by modification time (oldest first)
        find ... -printf '%T@ %p\n' | sort -n | awk '{print $2}'
        # Remove oldest files until under limit
    fi
}
```

**Two-Stage Cleanup:**
1. **Age-based:** Delete if older than 30 days
2. **Size-based:** Delete oldest if directory > 100m

### 9. Session History Capture (Lines 326-361)

```bash
capture_session_histories() {
    # Creates /opt/dtlogs/bin/capture_tty_history.sh
    # This script can be run via cron to capture multi-session histories
    
    # Queries all active bash/sh/zsh processes
    ps aux | grep -E '(bash|sh|zsh|fish)'
    
    # For each process, tries to get its HISTFILE
    # Copies it to /opt/dtlogs/history/
    
    # Recommended cron job:
    # */5 * * * * /bin/bash /opt/dtlogs/bin/capture_tty_history.sh
}
```

**Why Separate?**
- bash history is configured via PROMPT_COMMAND (automatic)
- But PROMPT_COMMAND only captures the current session
- This script captures all active sessions periodically
- Useful for multi-user/multi-session tracking

### 10. Optional: divtools Git Tracking (Lines 529-627)

```bash
review_divtools_git() {
    # If DT_LOG_DIVTOOLS=TRUE:
    #   1. Check /opt/divtools git status
    #   2. Get current branch, last commit, uncommitted changes
    #   3. Store in /opt/dtlogs/divtools_git_status.json
    
    # Useful for tracking if divtools config is in sync across hosts
}
```

**Disabled by default** because:
- Requires git
- May not be relevant on all hosts
- Can be enabled with `DT_LOG_DIVTOOLS=TRUE`

---

## Command Dispatcher (Lines 1106-1142)

```bash
case "${1:-help}" in
    setup)      do_setup                    # Initial setup
    verify)     verify_configuration        # Check config is valid
    manifest)   generate_manifest           # Create/update manifest
    status)     show_status                 # Show what's monitored
    cleanup)    cleanup_old_logs            # Remove old files
    setup-cron) setup_cron                  # Configure cron job
esac
```

### What Each Command Does

| Command | Root? | One-time? | Output | Purpose |
|---------|-------|-----------|--------|---------|
| `setup` | Yes | Yes | None | Initial host setup |
| `verify` | Yes | No | Report | Check config valid |
| `manifest` | Yes | No | JSON | Generate manifest for n8n |
| `status` | No | No | Report | Show monitoring status |
| `cleanup` | Yes | No | Report | Remove old log files |
| `setup-cron` | Yes | Yes | Cron | Configure cron job |
| `-test` | No | No | Dry-run | See what would happen |
| `-debug` | No | No | Verbose | Show detailed output |

---

## Test Mode Implementation

Every function that writes files has:

```bash
if [[ $TEST_MODE -eq 1 ]]; then
    log_warning "[TEST MODE] Would create directory..."
    return  # ← Don't actually do it
fi
# ... actual code here ...
```

**Affected Functions:**
- `setup_directories()` - Would create directories
- `setup_log_links()` - Would create symlinks
- `configure_bash_history()` - Would edit .bashrc files
- `capture_session_histories()` - Would create script
- `backup_current_histories()` - Would copy history files
- `calculate_docker_checksums()` - Would write checksums
- `generate_manifest()` - Would write JSON
- `cleanup_old_logs()` - Would delete files

**Result:** You can run `-test` flag to see what would happen without making changes.

---

## Recent Bug Fix (Line 496)

**The Issue:**
```bash
# BEFORE (Missing function declaration):
# Calculate checksums for docker config files
    log_info "Calculating checksums..."    # ← No function name!

# AFTER (Fixed):
# Calculate checksums for docker config files
calculate_docker_checksums() {
    log_info "Calculating checksums..."
```

**What Happened:**
- When `cleanup_old_logs()` was added, it accidentally removed the function declaration
- Caused syntax error: "unexpected token `}'" at line 519
- Fix: Re-added `calculate_docker_checksums() {`

---

## Current Limitations & Reserved Features

### Not Yet Implemented

| Feature | Current Status | In Which Directory |
|---------|---|---|
| APT package snapshots | ❌ Not implemented | `apt/` (empty) |
| Docker config snapshots | ❌ Not implemented | `docker/` (empty) |
| Change detection reports | ❌ Not implemented | N/A |
| Dual-manifest comparison | ❌ Not needed | N/A |
| Manifest archival | ❌ Not needed | N/A |
| APT log copying | ❌ By design (uses symlinks) | N/A |

### Why These Limitations?

1. **Symlinks instead of copies** - Keep logs in single location, reduce duplication
2. **apt/ and docker/ empty** - Reserved for enhancement, but symlinks/checksums currently sufficient
3. **No dual-manifest** - External tools (n8n) do comparison, not script
4. **Manifest overwrites** - It's metadata, not a change log

---

## How This Script Fits Into Larger Ecosystem

```
┌─────────────────────────────────────────────────────┐
│ host_change_log.sh                                  │
│ (Orchestrates monitoring setup)                     │
└─────────────────────────────────────────────────────┘
                      │
    ┌─────────────────┼─────────────────┐
    │                 │                 │
    ▼                 ▼                 ▼
 Setup          Manifest             Verify
 (Once)         (As needed)           (Periodic)
    │                 │                 │
    └─────────────────┼─────────────────┘
                      │
                      ▼
         /opt/dtlogs/
         (Monitoring infrastructure)
                      │
                      ▼
         n8n or similar external tool
         (Detects and alerts on changes)
```

---

## Recommended Next Steps

### 1. Run Setup
```bash
sudo /home/divix/divtools/scripts/util/host_chg_mon/host_change_log.sh setup
# Sets up everything, configures bash history
```

### 2. Generate Baseline
```bash
sudo /home/divix/divtools/scripts/util/host_chg_mon/host_change_log.sh manifest
# Creates monitoring_manifest.json
# Saves docker checksum baseline
```

### 3. Save Baseline Checksums
```bash
cp /opt/dtlogs/checksums/docker_configs.sha256 \
   /opt/dtlogs/checksums/docker_configs.baseline.sha256
```

### 4. Configure n8n Monitoring
Use manifest as template to configure n8n to watch files daily

### 5. Later, Detect Changes
```bash
# Run again to get new checksums
sudo /home/divix/divtools/scripts/util/host_chg_mon/host_change_log.sh manifest

# Compare to baseline
diff /opt/dtlogs/checksums/docker_configs.baseline.sha256 \
     /opt/dtlogs/checksums/docker_configs.sha256
```

---

## Files in This Directory

After running setup, you should have:

```
/opt/dtlogs/
├── monitoring_manifest.json           (metadata template)
├── history/
│   ├── root.bash_history.*           (real files)
│   ├── root.bash_history.latest      (symlink)
│   ├── divix.bash_history.*          (real files)
│   ├── divix.bash_history.latest     (symlink)
│   └── ...
├── logs/
│   ├── apt-history.log → /var/log/apt/history.log
│   ├── dpkg.log → /var/log/dpkg.log
│   ├── syslog → /var/log/syslog
│   └── auth.log → /var/log/auth.log
├── checksums/
│   └── docker_configs.sha256
├── bin/
│   └── capture_tty_history.sh
├── apt/                              (empty - reserved)
└── docker/                           (empty - reserved)
```

---

## Conclusion

The script is well-designed for its purpose:
- ✅ Orchestrates monitoring setup
- ✅ Configures real-time bash history capture
- ✅ Creates symlinks to important logs
- ✅ Generates docker checksum baseline
- ✅ Produces manifest for external tools
- ✅ Supports test mode for safe exploration

It's **not** a change detector itself, but rather **prepares infrastructure** for external tools to detect changes.
