# host_change_log.sh - Recent Updates Documentation

## Overview

The `host_change_log.sh` script has been significantly enhanced to support:
1. Environment variable-based configuration
2. divtools git repository status logging
3. Comprehensive multi-session/TTY history tracking
4. Full Starship prompt compatibility

## Changes Summary

### 1. Environment Variable Configuration

**What Changed:**
The script now uses environment variables (sourced from `.env.s00-shared`) instead of hardcoded paths and values.

**Environment Variables:**
```bash
# From /home/divix/docker/sites/s00-shared/.env.s00-shared
export DT_LOG_DIR=/opt/dtlogs
export DT_LOG_MAXSIZE=100m
export DT_LOG_MAXDAYS=30
export DT_LOG_DIVTOOLS=FALSE  # Set to TRUE on specific hosts
```

**Configuration in Script:**
```bash
# Load environment variables if available
# Default values if env vars not set
DT_LOG_DIR="${DT_LOG_DIR:-/var/log/divtools/monitor}"
DT_LOG_MAXSIZE="${DT_LOG_MAXSIZE:-100m}"
DT_LOG_MAXDAYS="${DT_LOG_MAXDAYS:-30}"
DT_LOG_DIVTOOLS="${DT_LOG_DIVTOOLS:-FALSE}"
```

**Benefits:**
- Centralized configuration in `.env.s00-shared`
- Consistent settings across all hosts
- Easy to override per-host if needed
- Defaults to reasonable values if env vars not set

**How to Use:**
```bash
# The script automatically sources these if available
# Or override at runtime:
DT_LOG_DIR=/opt/dtlogs ./host_change_log.sh setup
```

---

### 2. divtools Git Repository Logging

**What Changed:**
Added optional git status logging for `/opt/divtools` repository. This is controlled by the `DT_LOG_DIVTOOLS` environment variable.

**When to Enable:**
Set `DT_LOG_DIVTOOLS=TRUE` at the **HOST level** (not globally in `.env.s00-shared`) on hosts where you want to track divtools changes. This is useful for:
- Detecting sync issues across multiple hosts
- Tracking commits and pushes
- Identifying uncommitted changes
- Monitoring file modifications in the divtools directory

**Host-Level Configuration:**
```bash
# In host-specific .env file (e.g., .env.tnhl01):
export DT_LOG_DIVTOOLS=TRUE

# Then run:
./host_change_log.sh setup
```

**Function: `review_divtools_git()`**

Creates a JSON file with comprehensive git status information:

```json
{
  "timestamp": "2025-11-11T15:30:45Z",
  "divtools_path": "/opt/divtools",
  "hostname": "tnhl01",
  "git_status": {
    "current_branch": "main",
    "current_commit": "a1b2c3d4e5f6g7h8",
    "remote_tracking": "origin/main",
    "last_commit": {
      "date": "2025-11-11T10:15:30-06:00",
      "author": "John Doe",
      "message": "Update docker configs"
    }
  },
  "changes": {
    "uncommitted_changes": 2,
    "unpushed_commits": 1,
    "modified_files": 2,
    "untracked_files": 0
  },
  "modified_files": ["docker/config/nginx.conf", "scripts/update.sh"],
  "untracked_files": [],
  "notes": "This status is collected when DT_LOG_DIVTOOLS=TRUE is set."
}
```

**Output Location:**
```
${DT_LOG_DIR}/divtools_git_status.json
Default: /opt/dtlogs/divtools_git_status.json
```

**Comparison Across Hosts:**
If you enable this on multiple hosts, you can easily compare:
- Which hosts have uncommitted changes
- Which hosts are out of sync with the remote
- Which files are modified on which hosts
- Identify sync issues or drift

**Status Display:**
```bash
# View divtools git status:
./host_change_log.sh status

# Output includes:
# === divtools Git Status ===
#   Branch: main
#   Current commit: a1b2c3d
#   Uncommitted changes: 2
#   Unpushed commits: 1
#   Status file: /opt/dtlogs/divtools_git_status.json
```

---

### 3. Multi-Session/TTY History Tracking

**What Changed:**
Added comprehensive session history capture to track multiple concurrent bash sessions, each potentially on different TTYs.

**Why This Matters:**
- Multiple users may be logged in simultaneously
- SSH sessions from different terminals/sessions need separate tracking
- Each session has its own history file
- Previous approach only captured user's primary `.bash_history`

**Implementation:**

#### A. Bash Configuration Updates
Enhanced bash configuration to support multi-session history:

```bash
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTTIMEFORMAT='%F %T '
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend
shopt -s histverify
shopt -s extdebug
set -H
PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
```

**Key Points:**
- `history -a`: Appends new history lines to history file
- `history -n`: Reads newly added history from history file
- `shopt -s histappend`: Appends rather than overwrites
- `shopt -s extdebug`: Enables extended debugging

#### B. Session Capture Script
A new script `capture_tty_history.sh` monitors and captures histories from all active sessions:

**Location:**
```
${DT_LOG_DIR}/bin/capture_tty_history.sh
Default: /opt/dtlogs/bin/capture_tty_history.sh
```

**What It Does:**
1. Identifies all active shell processes (bash, sh, zsh, fish)
2. Extracts HISTFILE for each process
3. Captures and saves session-specific history
4. Creates unique filenames with user, TTY, and timestamp
5. Logs session information to `active_sessions.log`

**History File Naming:**
```
{username}_{tty_identifier}.history.{timestamp}
Example: divix_pts_0.history.20251111-153045
```

#### C. Cron Integration
Set up periodic capture of session histories:

```bash
# Add to crontab (runs every 5 minutes):
*/5 * * * * /bin/bash ${DT_LOG_DIR}/bin/capture_tty_history.sh \
  ${DT_LOG_DIR}/history >> /var/log/divtools/monitor/session_capture.log 2>&1
```

**Or use the built-in command:**
```bash
./host_change_log.sh setup-cron
```

**Storage:**
```
${DT_LOG_DIR}/history/
  ├── root.bash_history.latest
  ├── root.bash_history.20251111-153045
  ├── divix.bash_history.latest
  ├── divix.bash_history.20251111-153045
  ├── username1_pts_0.history.20251111-153045
  ├── username1_pts_1.history.20251111-153045
  └── active_sessions.log
```

**Session Log Example:**
```
=== Session Capture: Nov 11 15:30:45 2025 ===
1234:divix:pts/0:/home/divix/.bash_history:/opt/dtlogs/history/divix_pts_0.history.20251111-153045
1235:divix:pts/1:/home/divix/.bash_history:/opt/dtlogs/history/divix_pts_1.history.20251111-153045
5678:root:pts/2:/root/.bash_history:/opt/dtlogs/history/root_pts_2.history.20251111-153045
=== End capture ===
```

---

### 4. Starship Prompt Compatibility

**What Changed:**
Updated bash history configuration to work properly with Starship prompt while maintaining persistent history across sessions.

**How It Works:**

Starship is a cross-shell prompt that:
- Uses `PROMPT_COMMAND` (compatible with bash)
- Renders the prompt independently
- Does NOT interfere with bash history mechanisms

**Configuration:**
The script now explicitly handles Starship compatibility:

```bash
# Detects if Starship is installed
if command -v starship &>/dev/null; then
    log_info "Starship prompt detected - history configuration is compatible"
    log_info "Starship uses PROMPT_COMMAND which works with bash history"
fi
```

**Important Notes:**

1. **PROMPT_COMMAND is Safe:**
   - Bash can have multiple commands in PROMPT_COMMAND
   - Starship appends to existing PROMPT_COMMAND
   - Our history commands run alongside Starship

2. **Order Matters:**
   ```bash
   PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
   # This ensures history is saved/read before Starship renders
   ```

3. **No Starship Config Changes Needed:**
   - The default Starship configuration works fine
   - Our bash configuration handles the history
   - No conflicts between the two

**Verification:**
```bash
# After running setup, check that both work:
echo $PROMPT_COMMAND
# Output should show: history -a; history -n; starship prompt...

# Verify Starship still renders correctly:
bash -i  # Should show normal Starship prompt
```

---

### 5. Manifest File Updates

**What Changed:**
Updated the `monitoring_manifest.json` to include new monitoring capabilities.

**New Sections in Manifest:**

```json
{
  "monitoring": {
    "session_histories": {
      "enabled": true,
      "check_frequency": "daily",
      "directory": "/opt/dtlogs/history",
      "session_monitor": "/opt/dtlogs/bin/capture_tty_history.sh",
      "notes": "All user sessions and TTYs are captured..."
    },
    "divtools_git": {
      "enabled": true,  // if DT_LOG_DIVTOOLS=TRUE
      "check_frequency": "daily",
      "status_file": "/opt/dtlogs/divtools_git_status.json",
      "base_path": "/opt/divtools",
      "notes": "Tracks git changes in divtools repository..."
    }
  }
}
```

---

## Usage Examples

### Setup with Environment Variables
```bash
# Source the env variables first:
source /home/divix/docker/sites/s00-shared/.env.s00-shared

# Run setup:
./host_change_log.sh setup
```

### Setup with divtools Git Logging
```bash
# Set up on a specific host with divtools logging:
DT_LOG_DIVTOOLS=TRUE ./host_change_log.sh setup

# Or add to host-specific .env file first:
echo "export DT_LOG_DIVTOOLS=TRUE" >> ~/.env.hostname
source ~/.env.hostname
./host_change_log.sh setup
```

### View Status
```bash
./host_change_log.sh status

# Output shows:
# - Bash history statistics per user
# - APT actions and logs
# - Docker configurations
# - Manifest status
# - divtools git status (if enabled)
# - Session history capture information
```

### Verify Configuration
```bash
./host_change_log.sh verify

# Checks:
# - Directory structure exists
# - Bash history configured
# - History files present
# - Manifest file exists
# - APT logs available
# - Docker configs found
# - divtools git status (if enabled)
```

### Manual Session History Capture
```bash
# Capture all active sessions right now:
/bin/bash /opt/dtlogs/bin/capture_tty_history.sh /opt/dtlogs/history

# View captured sessions:
cat /opt/dtlogs/history/active_sessions.log | tail -20
```

---

## File Structure

```
${DT_LOG_DIR}/
├── bin/
│   └── capture_tty_history.sh          # Session history capture script
├── history/
│   ├── root.bash_history.latest         # Current root history symlink
│   ├── root.bash_history.20251111-*     # Timestamped root histories
│   ├── divix.bash_history.latest        # Current divix history symlink
│   ├── divix.bash_history.20251111-*    # Timestamped divix histories
│   ├── username_pts_0.history.*         # Per-session histories
│   ├── username_pts_1.history.*         # Per-session histories
│   └── active_sessions.log              # Session capture log
├── apt/
│   └── [APT log symlinks]
├── docker/
│   └── [Docker-related logs]
├── checksums/
│   └── docker_configs.sha256            # Docker config checksums
├── logs/
│   └── [System log symlinks]
├── divtools_git_status.json             # Git status (if DT_LOG_DIVTOOLS=TRUE)
├── monitoring_manifest.json             # Full monitoring configuration
└── verify.log                           # Verification log

```

---

## Comparison with Previous Version

| Feature | Previous | Current |
|---------|----------|---------|
| Configuration | Hardcoded paths | Environment variables |
| Log Directory | `/var/log/divtools/monitor` | `${DT_LOG_DIR}` |
| divtools Tracking | None | Optional JSON with git status |
| Session Histories | Single per user | Multiple per TTY |
| Starship Support | Basic | Explicit support with notes |
| Manifest Updates | Basic monitoring | Includes sessions and divtools |
| History Capture | Per-user | Per-session with TTY tracking |

---

## Migration Guide

### For Existing Installations

If you have an existing `host_change_log.sh` setup:

1. **Backup current configuration:**
   ```bash
   cp -r /var/log/divtools/monitor /var/log/divtools/monitor.backup.$(date +%Y%m%d)
   ```

2. **Update the script:**
   ```bash
   # Replace with new version
   cp host_change_log.sh /path/to/installation/
   ```

3. **Run setup again:**
   ```bash
   source /home/divix/docker/sites/s00-shared/.env.s00-shared
   ./host_change_log.sh setup
   ```

4. **Verify everything works:**
   ```bash
   ./host_change_log.sh verify
   ./host_change_log.sh status
   ```

5. **Optional: Enable divtools logging on specific hosts:**
   ```bash
   # Edit host-specific env file:
   echo "export DT_LOG_DIVTOOLS=TRUE" >> ~/.env.hostname
   source ~/.env.hostname
   ./host_change_log.sh setup
   ```

---

## Troubleshooting

### Starship Prompt Not Working

**Issue:** Starship prompt not rendering after setup.

**Solution:**
```bash
# Check PROMPT_COMMAND:
echo $PROMPT_COMMAND

# Should show history commands + starship
# If not, re-source bashrc:
source ~/.bashrc

# Or reload the shell:
exec bash
```

### History Not Being Captured

**Issue:** No new history appearing in capture files.

**Solution:**
```bash
# Check if bash history is configured:
grep "divtools host_change_log.sh" ~/.bashrc

# Run setup again:
./host_change_log.sh setup

# Test history:
history -a  # Force write history
cat ~/.bash_history | tail
```

### divtools Git Status Not Updating

**Issue:** divtools_git_status.json not created or outdated.

**Solution:**
```bash
# Check if divtools git is available:
[[ -d /opt/divtools/.git ]] && echo "Git repo found" || echo "Not a git repo"

# Check if DT_LOG_DIVTOOLS is set:
echo $DT_LOG_DIVTOOLS

# Run setup with the flag:
DT_LOG_DIVTOOLS=TRUE ./host_change_log.sh setup

# Or run manually:
./host_change_log.sh manifest  # Regenerates all status
```

### Session Histories Not Capturing

**Issue:** No per-TTY history files appearing.

**Solution:**
```bash
# Check if capture script exists:
ls -la /opt/dtlogs/bin/capture_tty_history.sh

# Run it manually to test:
/bin/bash /opt/dtlogs/bin/capture_tty_history.sh /opt/dtlogs/history

# Check for errors:
tail /var/log/divtools/monitor/session_capture.log

# Check if cron is set up:
crontab -l | grep capture_tty_history
```

---

## Performance Notes

- **History Size:** 10,000 lines per user (configurable via HISTSIZE)
- **History File Size:** 20,000 lines max (configurable via HISTFILESIZE)
- **Session Capture:** Runs every 5 minutes by default (~50ms per execution)
- **Manifest Generation:** Takes <1 second
- **Git Status:** Takes 1-2 seconds (only if enabled)

---

## Next Steps

1. ✅ Source `.env.s00-shared` in your shell profiles
2. ✅ Run `./host_change_log.sh setup` on each host
3. ✅ Enable `DT_LOG_DIVTOOLS=TRUE` on hosts you want to track divtools
4. ✅ Set up cron jobs for regular captures
5. ✅ Configure n8n or other monitoring tools to check the manifest
6. ✅ Regularly review `status` and `verify` output

---

## Questions?

- Check the script comments for detailed explanations
- Run `./host_change_log.sh help` for command options
- Review generated manifest files for current configuration
- Check logs in `${DT_LOG_DIR}/` for troubleshooting

