# Host Monitoring Solution - Quick Start Guide

## Summary

You now have a complete host change monitoring solution with three main components:

### 📋 Files Created

1. **`host_change_log.sh`** (17 KB) - Main setup and configuration script
2. **`example_n8n_checks.sh`** (14 KB) - Ready-to-use monitoring commands for n8n
3. **`N8N_MONITORING_GUIDE.md`** (8 KB) - Complete n8n integration guide
4. **`HOST_MONITORING_README.md`** (12 KB) - Comprehensive documentation

## 🚀 Quick Start (3 Steps)

### Step 1: Setup Your First Host
```bash
# SSH into a host you want to monitor
ssh root@your-host

# Run the setup script
/home/divix/divtools/scripts/util/host_change_log.sh setup
```

**What this does:**
- ✅ Configures bash history to save 10,000+ commands with timestamps
- ✅ Creates `/var/log/divtools/monitor/` directory structure
- ✅ Backs up current history files
- ✅ Calculates checksums for docker configs
- ✅ Generates a JSON manifest describing what to monitor
- ✅ Sets up log file symlinks

**Time:** ~30 seconds per host

### Step 2: Verify It Worked
```bash
# Check the status
/home/divix/divtools/scripts/util/host_change_log.sh status

# View the manifest
cat /var/log/divtools/monitor/monitoring_manifest.json
```

### Step 3: Test the Monitoring Commands
```bash
# Run a comprehensive check
/home/divix/divtools/scripts/util/example_n8n_checks.sh all

# Or get JSON output for n8n
/home/divix/divtools/scripts/util/example_n8n_checks.sh json
```

## 🤖 n8n Integration

### Simple Daily Workflow

Create an n8n workflow with these nodes:

```
[Schedule Trigger: Daily 6 AM]
    ↓
[SSH Node: Connect to host]
    Command: /home/divix/divtools/scripts/util/example_n8n_checks.sh json
    ↓
[AI Agent: Analyze the JSON output]
    Prompt: "Analyze this host monitoring data and identify security concerns..."
    ↓
[IF Node: severity >= "medium"]
    ↓
[Notification: Send alert]
```

### Example SSH Commands for n8n

**Get everything as JSON:**
```bash
/home/divix/divtools/scripts/util/example_n8n_checks.sh json
```

**Check specific items:**
```bash
# Recent commands
/home/divix/divtools/scripts/util/example_n8n_checks.sh root-history

# Package changes
/home/divix/divtools/scripts/util/example_n8n_checks.sh apt-recent

# Docker integrity
/home/divix/divtools/scripts/util/example_n8n_checks.sh docker-check

# Security issues
/home/divix/divtools/scripts/util/example_n8n_checks.sh suspicious
```

## 📊 What Gets Monitored

### ✅ Bash History
- **Root user** commands (last 10,000)
- **divix user** commands (last 10,000)
- **Other users** (uid >= 1000)
- **With timestamps** for precise tracking
- **Preserved across reboots** via PROMPT_COMMAND

### ✅ APT Packages
- All package installations
- Package removals
- Upgrades and downgrades
- Located: `/var/log/apt/history.log` (rotated monthly)

### ✅ Docker Configurations
- All `*.yml` files in `/home/divix/divtools/docker/`
- SHA256 checksums for change detection
- Running containers
- Docker events (last 24 hours)

### ✅ System Logs
- Critical errors from journalctl
- Authentication failures
- Sudo usage
- Service failures
- Disk space warnings

## 🔍 Example Monitoring Scenarios

### Scenario 1: Detect Unauthorized Package Installations
```bash
# In n8n, run daily:
ssh user@host "/home/divix/divtools/scripts/util/example_n8n_checks.sh apt-recent"

# AI Agent analyzes output for unexpected packages
# Alert if non-standard packages appear
```

### Scenario 2: Track Docker Config Changes
```bash
# In n8n, run daily:
ssh user@host "/home/divix/divtools/scripts/util/example_n8n_checks.sh docker-check"

# If checksums don't match, investigate:
ssh user@host "/home/divix/divtools/scripts/util/example_n8n_checks.sh docker-changed"

# Alert on unexpected changes
```

### Scenario 3: Security Monitoring
```bash
# In n8n, run hourly:
ssh user@host "/home/divix/divtools/scripts/util/example_n8n_checks.sh suspicious"

# AI looks for patterns like:
# - curl | sh (downloading and executing scripts)
# - chmod 777 (insecure permissions)
# - rm -rf (dangerous deletions)
# - base64 decode (obfuscated commands)

# Alert on any matches
```

### Scenario 4: Command Audit Trail
```bash
# In n8n, query specific date:
ssh user@host "/home/divix/divtools/scripts/util/example_n8n_checks.sh history-date 2025-11-03"

# AI generates summary of what was done that day
# Useful for incident investigation
```

## 💡 Key Insights

### Files Are Preserved Across Reboots
**YES!** All monitored files persist:
- History files use `PROMPT_COMMAND` to write after each command
- Monitoring directory is in `/var/log/divtools/` (persistent)
- APT logs are standard system logs (rotated but kept)
- Docker configs are in user home directory

### History Retention
- **10,000 commands in memory** (vs default ~500)
- **20,000 commands on disk** (vs default ~1,000)
- **Several months** of typical usage
- **Timestamped backups** created during setup
- **No more history loss** on crash/reboot

### Monitoring Frequency
**Daily checks are sufficient** for most scenarios:
- Configuration changes are infrequent
- Packages don't install themselves
- 24-hour detection window is acceptable

**Hourly checks** for security-critical items:
- Authentication failures
- Suspicious command patterns
- Port/service changes

## 🎯 AI Agent Prompt for n8n

When using an AI agent in n8n to analyze the monitoring data:

```
You are a Linux system administrator monitoring host changes.

Analyze this monitoring report from {{ $json.hostname }}:

{{ $json }}

Identify:
1. Security concerns (unauthorized access, suspicious commands)
2. Configuration drift (unexpected package/config changes)
3. Operational issues (disk space, failed services)
4. Anything requiring immediate action

Respond with JSON:
{
  "severity": "low|medium|high|critical",
  "summary": "Brief description",
  "concerns": ["specific issues found"],
  "recommendations": ["suggested actions"],
  "notify": true/false
}

Be thorough but practical. Focus on actionable issues.
```

## 📁 Directory Structure Created

```
/var/log/divtools/monitor/
├── monitoring_manifest.json          # Complete monitoring configuration
├── history/
│   ├── root.bash_history.20250104-120000      # Timestamped backup
│   ├── root.bash_history.latest               # Current (symlink)
│   ├── divix.bash_history.20250104-120000
│   └── divix.bash_history.latest
├── checksums/
│   └── docker_configs.sha256         # For change detection
├── logs/
│   ├── apt-history.log → /var/log/apt/history.log
│   ├── dpkg.log → /var/log/dpkg.log
│   ├── syslog → /var/log/syslog
│   └── auth.log → /var/log/auth.log
└── verify.log                        # Verification output (if using cron)
```

## 🔧 Maintenance

### Run Verification Periodically
```bash
# Check that monitoring is still working
sudo /home/divix/divtools/scripts/util/host_change_log.sh verify
```

### Add to Cron (Optional)
```bash
# Runs verification daily at 2 AM
sudo /home/divix/divtools/scripts/util/host_change_log.sh setup-cron
```

### Regenerate Checksums
```bash
# After making docker config changes
sudo /home/divix/divtools/scripts/util/host_change_log.sh manifest
```

## 🎓 Learning More

- **Full Documentation**: `HOST_MONITORING_README.md`
- **n8n Integration**: `N8N_MONITORING_GUIDE.md`
- **Available Commands**: `./example_n8n_checks.sh help`
- **Setup Options**: `./host_change_log.sh help`

## 🚨 Common Issues & Solutions

### Issue: "Permission denied"
**Solution**: Run as root for setup
```bash
sudo /home/divix/divtools/scripts/util/host_change_log.sh setup
```

### Issue: "History not being saved"
**Solution**: Reload your shell config
```bash
source ~/.bashrc
```

### Issue: "Docker checksums don't match"
**Solution**: This means docker configs changed - investigate then regenerate
```bash
# See what changed
./example_n8n_checks.sh docker-changed

# If changes are expected, update checksums
sudo ./host_change_log.sh manifest
```

### Issue: "n8n can't connect"
**Solution**: Test SSH connection manually
```bash
ssh user@host "cat /var/log/divtools/monitor/monitoring_manifest.json"
```

## ✨ Next Steps

1. **Setup all your hosts**
   ```bash
   for host in host1 host2 host3; do
     ssh root@$host "/home/divix/divtools/scripts/util/host_change_log.sh setup"
   done
   ```

2. **Create n8n workflow**
   - Import the example workflow from `N8N_MONITORING_GUIDE.md`
   - Configure SSH credentials
   - Set up AI agent with the provided prompt
   - Add notification nodes (email, Slack, Pushover, etc.)

3. **Test it**
   - Make a change on a host (install a package, edit a docker file)
   - Wait for next n8n check
   - Verify you get notified

4. **Refine**
   - Adjust AI prompt based on false positives
   - Tune notification thresholds
   - Add more hosts

## 🎉 You're Done!

You now have:
- ✅ Automated host configuration
- ✅ Persistent command history
- ✅ Change detection system
- ✅ n8n integration tools
- ✅ AI-powered analysis
- ✅ Complete documentation

**Happy Monitoring!** 🚀
