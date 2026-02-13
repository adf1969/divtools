# REVIEW SUMMARY: host_change_log.sh Script Analysis

## The Bottom Line

**Your script is NOT broken** - it works exactly as designed, but it's **not a change detector**. It's a **monitoring orchestrator** that tells external tools what to watch.

---

## What You're Actually Seeing

### Directory Structure Makes Sense

```
✅ history/           → Bash commands being captured (ACTIVE)
✅ logs/              → Symlinks to /var/log/* (ACTIVE)
✅ checksums/        → Docker baseline (ACTIVE)
🟡 apt/              → Reserved for future snapshots (EMPTY by design)
🟡 docker/           → Reserved for future snapshots (EMPTY by design)
```

### The Manifest File

It's a **template**, not a change log:
- ✅ Tells n8n what files to monitor
- ✅ Provides file paths and locations
- ✅ Contains baseline checksums
- ❌ **NOT** used for change detection
- ❌ **NOT** accumulated or archived
- ❌ Overwrites itself each time

---

## Answers to Your Questions

### 1. "Where are the APT install/setup logs?"

They're at **`/var/log/apt/history.log`**

The script creates a symlink: `/opt/dtlogs/logs/apt-history.log → /var/log/apt/history.log`

These are managed by your OS and rotated monthly.

**Example:**
```bash
$ tail -5 /var/log/apt/history.log
Start-Date: 2025-11-11  20:19:15
Commandline: apt-get install -y openssh-server
Install: openssl (1.1.1)
End-Date: 2025-11-11  20:20:45
```

---

### 2. "Why are the values in logs/ just LINKS to other files?"

**By design.** Symlinks provide:
- Real-time data (always current)
- No disk duplication
- Automatic survival of log rotation
- Single source of truth

The script doesn't copy logs - it points to where they already are.

---

### 3. "Why is the apt folder EMPTY?"

**Unimplemented feature.** Could be enhanced to store:
- Timestamped package snapshots: `apt/packages_20251111_201942.txt`
- APT configuration changes
- Installation history archives

Currently, APT tracking happens via the symlink to `/var/log/apt/history.log`

---

### 4. "Why is the docker folder EMPTY?"

**Unimplemented feature.** Could be enhanced to store:
- Versioned copies of docker-compose files
- Configuration snapshots for comparison
- Docker network/volume definitions

Currently, Docker tracking happens via checksums in `/opt/dtlogs/checksums/docker_configs.sha256`

---

### 5. "I only see ONE monitoring_manifest.json. Does it include ALL files if I run multiple times?"

**No.**

Each run **completely overwrites** the manifest:

```
Run 1 (Nov 11, 20:25):
  monitoring_manifest.json
  └── Lists what to monitor

Run 2 (Nov 12, 10:30):
  monitoring_manifest.json  ← REPLACES the previous file
  └── Lists same things with new metadata
```

It's **metadata**, not a history log.

---

### 6. "Does the script need TWO manifests for change tracking?"

**No.** The design pattern is:

```
Script (Generates metadata)
    ↓
Manifest (Tells external tool what to watch)
    ↓
External Tool like n8n (Actually detects changes)
    ↓
Compared Against (The actual files it monitors)
```

Change tracking is done by **comparing the actual files**, not manifests:
- Compare checksums: old vs new
- Compare bash history timestamps: what's new?
- Compare APT logs: what packages were added?

---

### 7. "If I run with manifest a 2nd time, what does it do?"

**Two things:**

1. **Regenerates checksums**
   ```bash
   # Recalculates SHA256 of all docker-compose files
   # If they changed: new checksum ≠ old checksum
   # If they didn't change: checksum is identical
   ```

2. **Overwrites metadata**
   ```bash
   # Updates timestamp
   # Updates file references (new history files if you've been using shell)
   # Regenerates the JSON describing what to watch
   ```

**Does NOT:**
- Delete old files
- Archive the old manifest
- Create change reports
- Copy/backup logs

---

## How Monitoring Actually Works

### Real-Time (Automatic, No Script)

```bash
# Every time you run a command, bash saves it
tail -20 /opt/dtlogs/history/root.bash_history.latest
# Shows your recent commands

# Every package install is logged
tail -20 /var/log/apt/history.log
# Shows recent package changes

# Every auth event is logged
tail -20 /var/log/auth.log
# Shows login attempts, sudo usage, etc.
```

### For Change Detection

**Option A: Manual**
```bash
# Save baseline
cp /opt/dtlogs/checksums/docker_configs.sha256 baseline.sha256

# Later, regenerate checksums
./host_change_log.sh manifest

# Compare
diff baseline.sha256 /opt/dtlogs/checksums/docker_configs.sha256
```

**Option B: Automated with n8n**
```json
{
  "watch_files": [
    "/opt/dtlogs/history/*.latest",
    "/var/log/apt/history.log",
    "/opt/dtlogs/checksums/docker_configs.sha256"
  ],
  "check_daily": true,
  "alert_on": "file_modified"
}
```

---

## What's Being Tracked Right Now

| File | Updated | Tracked By | How Often |
|------|---------|-----------|-----------|
| `/opt/dtlogs/history/root.bash_history.latest` | Every command | PROMPT_COMMAND | Real-time |
| `/opt/dtlogs/history/divix.bash_history.latest` | Every command | PROMPT_COMMAND | Real-time |
| `/var/log/apt/history.log` | Each package change | APT system | On demand |
| `/var/log/dpkg.log` | Each package change | DPKG system | On demand |
| `/var/log/auth.log` | Each login/auth event | PAM/SSH | Real-time |
| `/var/log/syslog` | System events | Syslog | Real-time |
| `/opt/dtlogs/checksums/docker_configs.sha256` | When you run `manifest` | Script | Manual only |

---

## Recommended Enhancements to Make Script Better

If you want better change tracking capabilities, these additions would help:

### 1. **Auto-save baseline checksums**
```bash
# During setup:
calculate_docker_checksums() {
    # ... existing code ...
    cp docker_configs.sha256 docker_configs.baseline.sha256
}
```

### 2. **Create timestamped manifests instead of overwriting**
```bash
# Instead of:
MANIFEST_FILE="${MONITOR_BASE_DIR}/monitoring_manifest.json"

# Use:
MANIFEST_FILE="${MONITOR_BASE_DIR}/monitoring_manifest_$(date +%Y%m%d_%H%M%S).json"

# Then the latest symlink:
ln -sf monitoring_manifest_*.json monitoring_manifest.json
```

### 3. **Add APT snapshot feature**
```bash
apt_snapshot() {
    dpkg -l > "${MONITOR_BASE_DIR}/apt/packages_$(date +%s).txt"
    apt-cache stats > "${MONITOR_BASE_DIR}/apt/stats_$(date +%s).txt"
}

# Call from do_setup() and do_manifest()
```

### 4. **Add Docker config snapshot feature**
```bash
docker_snapshot() {
    local snapshot_dir="${MONITOR_BASE_DIR}/docker/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$snapshot_dir"
    cp /home/divix/divtools/docker/*.yml "$snapshot_dir/"
}

# Call from do_setup() and do_manifest()
```

### 5. **Generate change report**
```bash
change_report() {
    echo "=== Docker Config Changes ==="
    diff docker_configs.baseline.sha256 docker_configs.sha256 || true
    
    echo "=== New APT Packages ==="
    diff <(sort apt/packages_*.txt | head -1 | cut -d' ' -f1) \
         <(sort apt/packages_*.txt | tail -1 | cut -d' ' -f1) || true
}
```

These would transform the script from "monitoring setup" to "change tracking system."

---

## Files Created to Help You Understand

I've created two detailed documents in `/home/divix/divtools/scripts/util/host_chg_mon/`:

1. **ARCHITECTURE_AND_MONITORING_STRATEGY.md**
   - In-depth explanation of design
   - Directory structure breakdown
   - Change tracking workflows
   - Recommended enhancements

2. **MANIFEST_FAQ.md**
   - Quick reference
   - Q&A format
   - Quick answers to your specific questions
   - How-to examples

Both are in the same directory as the script.

---

## TL;DR

| Your Question | The Answer |
|---|---|
| Where are APT logs? | `/var/log/apt/history.log` (symlinked in `/opt/dtlogs/logs/`) |
| Why symlinks not copies? | Real-time data, no duplication, survives rotation |
| Why are apt/ and docker/ empty? | Features not yet implemented |
| One manifest or multiple? | One. It overwrites itself each run. |
| How does change detection work? | External tools compare the FILES, not the manifest |
| What does 2nd run do? | Regenerates checksums, updates metadata, overwrites manifest |
| Do I need dual manifests? | No. Manifest is a template. External tool does comparison. |

**The script is working correctly. You just need external tools (like n8n) to actually detect and alert on changes.**
