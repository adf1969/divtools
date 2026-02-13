# host_change_log.sh - Monitoring Architecture & Strategy

## Overview

`host_change_log.sh` is a **change monitoring orchestration script**, not a traditional log aggregation tool. It serves as a **pointer system** that tells external monitoring tools (like n8n) **what to watch and where to find it**.

### Key Insight
The script doesn't copy or move log files. Instead, it:
1. **Discovers** existing log files on the system
2. **Creates symbolic links** to them for easy reference
3. **Generates a JSON manifest** that describes what should be monitored
4. **Provides baseline checksums** for detecting changes

---

## Architecture Overview

```
host_change_log.sh (Orchestrator)
    ├── setup_log_links()
    │   └── Creates symlinks in /opt/dtlogs/logs/ pointing to:
    │       ├── /var/log/apt/history.log (APT installs)
    │       ├── /var/log/dpkg.log (Package changes)
    │       ├── /var/log/syslog (System events)
    │       └── /var/log/auth.log (Auth events)
    │
    ├── Bash history tracking
    │   └── Configures PROMPT_COMMAND in .bashrc files
    │       └── Saves to /opt/dtlogs/history/*.bash_history.*
    │
    ├── calculate_docker_checksums()
    │   └── Generates SHA256 of all docker-compose files
    │       └── Stored in /opt/dtlogs/checksums/docker_configs.sha256
    │
    ├── capture_tty_history.sh (optional cron job)
    │   └── Captures multi-session histories periodically
    │       └── Stored in /opt/dtlogs/history/
    │
    └── generate_manifest()
        └── Creates /opt/dtlogs/monitoring_manifest.json
            └── JSON describing all monitored files & locations
```

---

## Directory Structure Explained

### `/opt/dtlogs/` - Main Monitoring Directory

```
/opt/dtlogs/
├── monitoring_manifest.json     ← Master file describing all monitoring
├── history/                     ← User bash histories (actual files & symlinks)
│   ├── root.bash_history.20251111-201942          (actual history file)
│   ├── root.bash_history.latest                    (symlink to latest)
│   ├── divix.bash_history.20251111-201942         (actual history file)
│   ├── divix.bash_history.latest                   (symlink to latest)
│   ├── drupal.bash_history.20251111-201942        (actual history file)
│   ├── drupal.bash_history.latest                  (symlink to latest)
│   └── [optional] active_sessions.log
│
├── checksums/
│   └── docker_configs.sha256    ← SHA256 checksums of all docker-compose files
│
├── logs/                        ← Symlinks to system logs (for easy monitoring)
│   ├── apt-history.log          → /var/log/apt/history.log
│   ├── dpkg.log                 → /var/log/dpkg.log
│   ├── syslog                   → /var/log/syslog
│   └── auth.log                 → /var/log/auth.log
│
├── apt/                         ← [EMPTY] Unused - for future APT snapshot feature
├── docker/                      ← [EMPTY] Unused - for future Docker config snapshot feature
│
└── bin/
    └── capture_tty_history.sh   ← Script to capture multi-session histories
```

### Why Are Some Directories Empty?

The `apt/` and `docker/` directories are **reserved for future snapshot features**:

- **`apt/`** - Could store periodic snapshots of installed packages (e.g., `dpkg -l > apt/packages_2025-11-11.txt`)
- **`docker/`** - Could store periodic copies of docker-compose files for version comparison

Currently unused, but the structure is prepared for future enhancement.

---

## How Change Monitoring Works

### Single Manifest Approach (Not Dual-Manifest)

The script uses a **single master manifest** rather than comparing two manifests:

```
First Run (Nov 11, 20:25):
  monitoring_manifest.json
  ├── Lists all files to monitor
  ├── Contains checksums for docker configs
  ├── Identifies bash history files
  └── This is the TEMPLATE for n8n

External Tool (n8n) monitors the SAME files:
  1. Check /opt/dtlogs/history/*.latest for new commands
  2. Check /var/log/apt/history.log for new packages
  3. Compare docker-compose checksums vs baseline
  4. Check /var/log/syslog and /var/log/auth.log for events

Second Run (Nov 12, 10:30):
  monitoring_manifest.json
  ├── OVERWRITES the previous manifest
  ├── Updates checksums if docker configs changed
  ├── Updates bash history file references if new sessions started
  └── This serves as an UPDATED BASELINE
```

### What Actually Happens on Second Run?

When you run `./host_change_log.sh manifest` a second time:

1. **Overwrites** `monitoring_manifest.json` with new timestamp
2. **Regenerates** docker checksum file (detects if configs changed)
3. **Updates** bash history file references (new timestamp files created if shells active)
4. **Preserves** old history files (stored with timestamps)

**This is NOT for change detection.** The external tool (n8n) does the actual change detection by:
- Comparing timestamps of files
- Detecting new entries in append-only logs
- Computing new checksums and comparing to baseline

---

## How to Track Changes

### Scenario: You Need to Know What Changed on This Host

**Option 1: Using the Manifest as a Reading List**
```bash
# Run this to see what you should monitor
./scripts/util/host_chg_mon/host_change_log.sh manifest

# Then manually check each location listed in monitoring_manifest.json
cat /opt/dtlogs/monitoring_manifest.json | jq .
```

**Option 2: Monitor Individual Files with Timestamps**
```bash
# Check bash history for new commands
tail -20 /opt/dtlogs/history/root.bash_history.latest

# Check APT for package changes
tail -10 /var/log/apt/history.log

# Check for auth changes
grep -i "authentication\|failure\|sudo" /var/log/auth.log | tail -10
```

**Option 3: Configure External Monitoring (n8n)**

Use the manifest to configure n8n to watch these files and alert you to changes:
- Set up a daily job that compares file checksums
- Monitor append-only logs for new entries
- Track bash history for suspicious commands
- Watch auth.log for failed logins or privilege escalation

### Tracking Docker Configuration Changes

This is the only area with BASELINE comparison:

```bash
# Current baseline
cat /opt/dtlogs/checksums/docker_configs.sha256
# sha256sum /home/divix/divtools/docker/docker-compose-*.yml > new.sha256

# To detect changes:
diff docker_configs.sha256 new.sha256
# Shows which docker-compose files changed
```

---

## Missing Features You Identified

### 1. "Where are the apt install/setup logs?"

**Current Behavior:**
- Script creates symlink: `/opt/dtlogs/logs/apt-history.log → /var/log/apt/history.log`
- APT logs are managed by the OS (rotated monthly)
- Script doesn't copy them, only points to them

**Why it's empty in `/opt/dtlogs/apt/`:**
- The `apt/` directory was created but no feature populates it yet
- This could be enhanced to store:
  ```bash
  # Option A: Periodic package snapshots
  dpkg -l > /opt/dtlogs/apt/installed_packages_$(date +%s).txt
  
  # Option B: Copy rotating logs
  cp /var/log/apt/history.log /opt/dtlogs/apt/history_$(date +%Y%m%d).log
  ```

### 2. "Why are values in logs/ just LINKS to other files?"

**By Design** - The script creates **symlinks, not copies**:

```bash
ln -sf /var/log/apt/history.log "${log_dir}/apt-history.log"
#     ↑
#     Symbolic link (not copy)
```

**Advantages:**
- ✅ Real-time data (always points to latest log)
- ✅ No disk duplication
- ✅ Single source of truth
- ✅ Works with log rotation (symlink automatically follows)

**Alternative:** Could copy instead of symlink for archival purposes

### 3. "Why is the apt folder EMPTY?"

**Reserved for future use.** Could implement:
```bash
# Add to do_setup():
apt_snapshot() {
    dpkg -l > "${MONITOR_BASE_DIR}/apt/packages_$(date +%s).txt"
    apt-cache stats > "${MONITOR_BASE_DIR}/apt/stats_$(date +%s).txt"
}

# Add to do_manifest():
# Compare current package list to previous snapshots
```

### 4. "Why is the docker folder EMPTY?"

**Reserved for future use.** Could implement:
```bash
# Add to do_setup():
docker_snapshot() {
    cp /home/divix/divtools/docker/docker-compose-*.yml \
       "${MONITOR_BASE_DIR}/docker/compose_$(date +%s)/"
}

# Store versioned copies for comparison
```

---

## Manifest Behavior - Key Points

### Single Manifest, Not Dual-Manifest

```
❌ WRONG: Comparing two manifests to detect changes
   manifest_v1.json vs manifest_v2.json
   (The script doesn't do this)

✅ CORRECT: Manifest is a TEMPLATE for external tools
   - It tells n8n/other tools WHAT to monitor
   - It provides BASELINE checksums for docker files
   - External tools do the actual change detection
```

### When You Run `manifest` Again

```
BEFORE: /opt/dtlogs/monitoring_manifest.json (Nov 11, 20:25)
AFTER:  /opt/dtlogs/monitoring_manifest.json (Nov 12, 10:30)
        ↓
        File is completely replaced with NEW metadata
        
        But the REFERENCED FILES are unchanged:
        - /var/log/apt/history.log (still there)
        - /opt/dtlogs/history/root.bash_history.latest (still points to latest)
        - docker_configs.sha256 (recalculated)
```

The manifest is **ephemeral metadata**, not the actual data being monitored.

---

## Proper Change Tracking Workflow

### For a Complete Audit Trail:

```bash
# 1. Initial baseline
sudo ./scripts/util/host_chg_mon/host_change_log.sh setup
sudo ./scripts/util/host_chg_mon/host_change_log.sh manifest

# 2. Save baseline checksums
cp /opt/dtlogs/checksums/docker_configs.sha256 \
   /opt/dtlogs/checksums/baseline_docker_configs.sha256

# 3. Later: Generate new checksums
sudo ./scripts/util/host_chg_mon/host_change_log.sh manifest

# 4. Compare
diff /opt/dtlogs/checksums/baseline_docker_configs.sha256 \
     /opt/dtlogs/checksums/docker_configs.sha256

# 5. Check other logs manually
tail -100 /opt/dtlogs/history/root.bash_history.latest
tail -100 /var/log/apt/history.log
tail -100 /var/log/auth.log
```

### For Automated Monitoring (n8n):

Configure n8n to run daily:
```json
{
  "watches": [
    {
      "path": "/opt/dtlogs/history/root.bash_history.latest",
      "type": "timestamp",
      "action": "alert if newer than yesterday"
    },
    {
      "path": "/var/log/apt/history.log",
      "type": "content",
      "action": "alert if new entries added"
    },
    {
      "path": "/opt/dtlogs/checksums/docker_configs.sha256",
      "type": "checksum_compare",
      "baseline": "/opt/dtlogs/checksums/baseline_docker_configs.sha256",
      "action": "alert if different"
    }
  ]
}
```

---

## Summary

| Aspect | Answer |
|--------|--------|
| **One manifest or two?** | One master manifest. It's a template, not for comparison. |
| **What does second run do?** | Overwrites manifest with new metadata, regenerates checksums |
| **How does change detection work?** | External tool (n8n) monitors the REFERENCED files, not the manifest |
| **Empty directories (apt/, docker/)?** | Reserved for future snapshot features |
| **Symlinks vs copies?** | Symlinks by design - always point to real-time data |
| **APT logs?** | Pointed to, not copied. Check `/var/log/apt/history.log` directly |
| **How to audit changes?** | Save baseline checksums, compare referenced files, check logs manually or with n8n |

---

## Recommended Enhancements

To make this script more complete for change tracking:

1. **Add snapshot feature for APT:**
   ```bash
   dpkg -l > /opt/dtlogs/apt/packages_$(date +%Y%m%d_%H%M%S).txt
   ```

2. **Add snapshot feature for docker-compose files:**
   ```bash
   mkdir -p /opt/dtlogs/docker/$(date +%Y%m%d_%H%M%S)
   cp /home/divix/divtools/docker/*.yml /opt/dtlogs/docker/$(date +%Y%m%d_%H%M%S)/
   ```

3. **Add baseline checksum file:**
   ```bash
   cp docker_configs.sha256 baseline_docker_configs.sha256
   ```

4. **Add manifest comparison report:**
   ```bash
   # Compare docker checksums between runs
   # Generate diff report of what changed
   ```

5. **Document in manifest itself:**
   Add to JSON: `"baseline_created": "2025-11-11T20:25:09Z"` to track baseline version

This would allow true before/after change analysis rather than just pointing to live logs.
