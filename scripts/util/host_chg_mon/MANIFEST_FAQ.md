# Quick Reference: Understanding the Manifest

## The Core Insight

The manifest is **NOT a change detector**. It's a **configuration template** that tells external tools what to monitor.

```
host_change_log.sh (What to watch)
         ↓
    monitoring_manifest.json (The instructions)
         ↓
    n8n or other tools (Actually watches the files)
```

---

## What Each Directory Actually Contains

| Directory | Purpose | Content | Status |
|-----------|---------|---------|--------|
| `history/` | User bash commands | `.bash_history` files + `.latest` symlinks | ✅ **ACTIVE** - Gets updated automatically |
| `logs/` | System log shortcuts | Symlinks to `/var/log/*` | ✅ **ACTIVE** - Points to real-time logs |
| `checksums/` | Docker baseline | SHA256 of all docker-compose files | ✅ **ACTIVE** - Regenerated on each `manifest` run |
| `apt/` | APT package snapshots | *Currently empty* | 🟡 **RESERVED** - Feature not yet implemented |
| `docker/` | Docker config snapshots | *Currently empty* | 🟡 **RESERVED** - Feature not yet implemented |
| `bin/` | Helper scripts | `capture_tty_history.sh` | ✅ **ACTIVE** - Can be run via cron |

---

## What's Happening Right Now

### Real-Time Monitoring (No Script Needed)

These files are being tracked automatically:

```
✅ /opt/dtlogs/history/root.bash_history.latest
   → Captures every command you run (via PROMPT_COMMAND)
   → New file each time you open a shell

✅ /opt/dtlogs/history/divix.bash_history.latest
   → Your command history

✅ /var/log/apt/history.log
   → Every package install/remove/upgrade (symlinked from /opt/dtlogs/logs/apt-history.log)

✅ /var/log/dpkg.log
   → Package system changes (symlinked)

✅ /var/log/auth.log
   → All authentication events (symlinked)

✅ /var/log/syslog
   → System events (symlinked)

✅ /opt/dtlogs/checksums/docker_configs.sha256
   → Baseline of all docker-compose files
   → Regenerated each time you run "manifest" command
```

---

## Answering Your Questions

### Q: "Where are the apt install/setup logs?"

**A:** They're in `/var/log/apt/history.log`

The script creates a symlink: `/opt/dtlogs/logs/apt-history.log → /var/log/apt/history.log`

To see them:
```bash
tail -20 /var/log/apt/history.log
# OR via symlink:
tail -20 /opt/dtlogs/logs/apt-history.log
```

**Why no copies in `/opt/dtlogs/apt/`?**
- That feature isn't implemented yet (it's reserved for future use)
- Currently only symlinks exist

---

### Q: "Why are the values in logs/ just LINKS to other files?"

**A:** By design. Symlinks mean:
- ✅ Always up-to-date (real-time)
- ✅ No disk duplication
- ✅ Survives log rotation
- ✅ Single source of truth

The actual logs stay in `/var/log/` where the OS manages them. The symlinks in `/opt/dtlogs/logs/` just point there for easy reference.

---

### Q: "Why is the apt folder EMPTY?"

**A:** Not implemented yet. It could store:
- Snapshots of installed packages
- Timestamped copies of APT logs for comparison
- APT configuration changes

For now, APT tracking is done via the symlink to `/var/log/apt/history.log`

---

### Q: "Why is the docker folder EMPTY?"

**A:** Not implemented yet. It could store:
- Versioned copies of docker-compose files
- Configuration snapshots for change comparison
- Docker network/volume definitions

For now, Docker tracking is done via checksums in `/opt/dtlogs/checksums/docker_configs.sha256`

---

### Q: "I only see ONE monitoring_manifest.json. Does that include ALL the various files if I run it multiple times?"

**A:** The manifest does NOT accumulate. Each run **overwrites** the previous one.

```
Run 1:  monitoring_manifest.json (Nov 11, 20:25)
        ├── Lists all files to watch
        └── Contains checksums from Nov 11

Run 2:  monitoring_manifest.json (Nov 12, 10:30)  ← OVERWRITES Run 1
        ├── Lists same files to watch
        └── Contains NEW checksums from Nov 12
```

The manifest is **metadata**, not a log. It describes what to monitor, not the history of changes.

---

### Q: "Does the script need TWO manifests to do that [change tracking]?"

**A:** No. The script uses ONE manifest plus the ACTUAL FILES it points to.

**Here's the actual workflow:**

```
1st Run (baseline):
   Generate checksums → /opt/dtlogs/checksums/docker_configs.sha256
   Create manifest → /opt/dtlogs/monitoring_manifest.json
   
   [Your system runs for a week, things change]
   
2nd Run (detect changes):
   Generate NEW checksums → /opt/dtlogs/checksums/docker_configs.sha256
   Create NEW manifest → /opt/dtlogs/monitoring_manifest.json
   
   [External tool compares:
    - Old checksum vs new checksum
    - Old history files vs new history files
    - Old APT log vs new APT log]
```

The external tool (n8n) does the comparison, not the script.

---

### Q: "If I run with manifest a 2nd time, what does it do?"

**A:** Two things:

1. **Regenerates checksums**
   ```bash
   # Old: docker_configs.sha256 (from Nov 11)
   # New: docker_configs.sha256 (from Nov 12, recalculated)
   
   # If docker-compose files changed: checksums will differ
   # If docker-compose files haven't changed: checksums will be identical
   ```

2. **Overwrites metadata**
   ```bash
   # Old: monitoring_manifest.json (timestamp: Nov 11, 20:25)
   # New: monitoring_manifest.json (timestamp: Nov 12, 10:30)
   
   # Updates file references (new history files if sessions were active)
   # Updates docker config base path info
   ```

**Does NOT:**
- ❌ Delete anything
- ❌ Archive the old manifest
- ❌ Create a change report
- ❌ Copy old logs

---

## How to Actually Track Changes

### Option 1: Manual Comparison
```bash
# Save baseline
cp /opt/dtlogs/checksums/docker_configs.sha256 \
   /opt/dtlogs/checksums/docker_configs.baseline.sha256

# Later, check what changed
sha256sum /home/divix/divtools/docker/docker-compose-*.yml | \
  diff - /opt/dtlogs/checksums/docker_configs.baseline.sha256
```

### Option 2: Configure n8n to Monitor
Use the manifest as a guide for what to watch:
```json
{
  "monitor": [
    "/opt/dtlogs/history/root.bash_history.latest",
    "/var/log/apt/history.log",
    "/opt/dtlogs/checksums/docker_configs.sha256",
    "/var/log/auth.log"
  ]
}
```

### Option 3: Check Timestamps
```bash
# What changed in the last 24 hours?
find /opt/dtlogs /var/log -type f -mtime 0 2>/dev/null | sort

# When was the manifest last updated?
stat /opt/dtlogs/monitoring_manifest.json | grep Modify

# What's in the current bash history?
tail -50 /opt/dtlogs/history/root.bash_history.latest
```

---

## The Real Purpose of This Script

✅ **Sets up structured monitoring directories**
✅ **Configures bash history capture**
✅ **Creates symlinks to important logs**
✅ **Calculates baseline checksums**
✅ **Generates a manifest for external tools**

❌ **NOT** a change detector itself
❌ **NOT** a backup tool
❌ **NOT** a log aggregator (copies data)

It's an **orchestrator** that prepares the host for monitoring by external tools.

---

## Suggested Improvements

If you want better change tracking, the script could:

1. **Save baseline checksums automatically**
   ```bash
   # During setup:
   cp docker_configs.sha256 docker_configs.baseline.sha256
   ```

2. **Generate change reports**
   ```bash
   # During manifest:
   diff baseline_docker_configs.sha256 docker_configs.sha256 > changes.txt
   ```

3. **Archive APT snapshots**
   ```bash
   # During setup/manifest:
   dpkg -l > /opt/dtlogs/apt/packages_$(date +%s).txt
   ```

4. **Create timestamp-marked manifests**
   ```bash
   # Instead of overwriting:
   monitoring_manifest_2025-11-11_20-25-09.json
   monitoring_manifest_2025-11-12_10-30-15.json
   # Then compare manifests directly
   ```

These could be added without breaking existing functionality.
