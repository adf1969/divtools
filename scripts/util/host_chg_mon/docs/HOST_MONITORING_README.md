# Host Change Monitoring Solution

A comprehensive system for monitoring and tracking changes across Linux hosts, designed to work with n8n AI-powered monitoring workflows.

## Overview

This solution provides:
- **Automated setup** of host monitoring configuration
- **Preservation** of critical files (history, logs, configs)
- **Change detection** for packages, docker configs, and user activity
- **n8n integration** with example checks and AI agent prompts
- **JSON manifests** describing what to monitor on each host

## Components

### 1. `host_change_log.sh` - Main Setup Script

The primary script that configures a host for monitoring.

**Key Features:**
- Configures enhanced bash history (10,000 commands, timestamped)
- Sets up monitoring directory structure
- Creates backup copies of history files
- Calculates checksums for docker configurations
- Generates JSON manifest for monitoring tools
- Provides verification and status commands

**Usage:**
```bash
# Initial setup (run as root on each host)
sudo ./host_change_log.sh setup

# Verify configuration
sudo ./host_change_log.sh verify

# Check monitoring status
./host_change_log.sh status

# Regenerate manifest
sudo ./host_change_log.sh manifest

# Add to cron for periodic verification
sudo ./host_change_log.sh setup-cron
```

**What It Monitors:**
- Bash command history (root, divix, and other users)
- APT package installations/removals
- Docker compose configuration files
- System logs (syslog, auth.log)
- Docker events and container changes

### 2. `example_n8n_checks.sh` - n8n Integration Commands

A collection of ready-to-use commands for n8n SSH nodes.

**Usage:**
```bash
# Run comprehensive check
./example_n8n_checks.sh all

# Generate JSON for AI processing
./example_n8n_checks.sh json

# Check specific items
./example_n8n_checks.sh root-history
./example_n8n_checks.sh apt-recent
./example_n8n_checks.sh docker-check
./example_n8n_checks.sh suspicious
```

**Available Checks:**
- History monitoring (root, divix, by-date, suspicious patterns)
- APT activity (recent installs, manual packages, updates)
- Docker integrity (checksums, changes, events, containers)
- System health (errors, disk, memory, services)
- Security (auth failures, sudo usage, users, ports, cron)

### 3. `N8N_MONITORING_GUIDE.md` - Integration Documentation

Complete guide for setting up n8n workflows, including:
- Workflow design patterns
- SSH command examples
- AI agent prompts
- Monitoring frequency recommendations
- Troubleshooting tips

## Quick Start

### Step 1: Setup a Host

```bash
# SSH into the target host
ssh user@target-host

# Run the setup script (as root)
sudo /home/divix/divtools/scripts/util/host_change_log.sh setup

# Verify it worked
/home/divix/divtools/scripts/util/host_change_log.sh status
```

### Step 2: Review the Manifest

```bash
cat /var/log/divtools/monitor/monitoring_manifest.json
```

This JSON file describes everything being monitored on this host.

### Step 3: Configure n8n

In your n8n workflow:

1. **Add SSH Node** - Connect to the host
2. **Read Manifest** - `cat /var/log/divtools/monitor/monitoring_manifest.json`
3. **Run Checks** - Use commands from `example_n8n_checks.sh`
4. **AI Analysis** - Process the output with an AI agent
5. **Alert** - Notify on significant changes

**Example n8n SSH Command:**
```bash
/home/divix/divtools/scripts/util/example_n8n_checks.sh all
```

Or for JSON output:
```bash
/home/divix/divtools/scripts/util/example_n8n_checks.sh json
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Target Host                                                 │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │ /var/log/divtools/monitor/                   │          │
│  │  ├── monitoring_manifest.json  ◄─────────────┼──────────┤
│  │  ├── history/                                 │          │
│  │  │   ├── root.bash_history.latest           │          │
│  │  │   └── divix.bash_history.latest          │          │
│  │  ├── checksums/                              │          │
│  │  │   └── docker_configs.sha256               │          │
│  │  └── logs/                                    │          │
│  │      ├── apt-history.log → /var/log/apt/...  │          │
│  │      └── syslog → /var/log/syslog            │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ SSH
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  n8n Workflow                                                │
│                                                              │
│  [Schedule] → [SSH Connect] → [Run Checks]                  │
│                                      ↓                       │
│                              [AI Agent Analysis]             │
│                                      ↓                       │
│                          [Notify if Important]               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## File Persistence & Retention

### What Persists Across Reboots?
✅ **YES** - All monitored files persist:
- `/var/log/divtools/monitor/` - Monitoring directory
- `/var/log/apt/history.log` - APT logs (rotated but kept ~12 months)
- User `.bash_history` files (with our configuration)
- Docker config files in `/home/divix/divtools/docker/`
- System logs in `/var/log/` (rotated but persistent)

### History Retention
- **In Memory**: 10,000 commands (HISTSIZE)
- **On Disk**: 20,000 commands (HISTFILESIZE)
- **Backup Copies**: Created with timestamps, kept indefinitely
- **Estimated Duration**: Several months of typical usage

### Log Rotation
- **APT logs**: Rotated monthly, kept ~12 months
- **System logs**: Rotated daily/weekly, kept 4-12 weeks
- **Docker logs**: Can grow unbounded (manage separately)

## Monitoring Frequency Recommendations

| Check Type | Frequency | Reasoning |
|------------|-----------|-----------|
| Bash History | Daily | Commands accumulate gradually |
| APT Packages | Daily | Infrequent but important changes |
| Docker Configs | Daily | Manual changes are rare |
| System Errors | Daily | Timely but not urgent |
| Auth Failures | Hourly | Security-sensitive |
| Disk Space | Hourly | Can fill quickly |

**Recommendation**: Start with **daily checks at 6 AM** for most items. Add hourly checks for security events if needed.

## Security Considerations

### What the Script Does:
- ✅ Enables command history with timestamps
- ✅ Preserves history after each command
- ✅ Creates monitoring directories with appropriate permissions
- ✅ Tracks configuration file changes
- ✅ Provides audit trail of package installations

### What to Watch For:
- Suspicious commands in history (the script checks for common patterns)
- Unauthorized package installations
- Changes to docker configurations
- Failed authentication attempts
- New user accounts
- Unexpected sudo usage

## Troubleshooting

### Setup Issues

**Problem**: Permission denied
```bash
# Solution: Run as root
sudo ./host_change_log.sh setup
```

**Problem**: Monitoring directory missing
```bash
# Solution: Re-run setup
sudo ./host_change_log.sh setup
```

### Verification Issues

**Problem**: History not configured
```bash
# Solution: Re-run setup and reload shell
sudo ./host_change_log.sh setup
source ~/.bashrc
```

**Problem**: Checksums don't match
```bash
# Solution: Regenerate checksums
sudo ./host_change_log.sh manifest
```

### n8n Integration Issues

**Problem**: SSH connection fails
```bash
# Test SSH connection
ssh user@host "cat /var/log/divtools/monitor/monitoring_manifest.json"
```

**Problem**: Command not found
```bash
# Ensure scripts are executable
chmod +x /home/divix/divtools/scripts/util/*.sh
```

**Problem**: Permission denied reading files
```bash
# Fix permissions
sudo chmod -R 755 /var/log/divtools/monitor
```

## Advanced Usage

### Custom Monitoring Locations

Edit the script configuration:
```bash
MONITOR_BASE_DIR="/var/log/divtools/monitor"  # Change this
```

### Additional Users

The script automatically configures all users with UID >= 1000. To add specific users, modify the `configure_bash_history()` function.

### Real-time Monitoring

For immediate alerts, add inotify watches:
```bash
inotifywait -m /home/divix/divtools/docker -e modify |
while read path action file; do
    # Send webhook to n8n
    curl -X POST https://n8n.example.com/webhook/config-change
done
```

### Integration with Git

Track docker configs in git for better change detection:
```bash
cd /home/divix/divtools
git init
git add docker/
git commit -m "Initial docker configs"

# In n8n checks:
git diff HEAD docker/
```

## Maintenance

### Weekly Tasks
- Review monitoring reports from n8n
- Verify critical hosts are checking in
- Update n8n workflows as needed

### Monthly Tasks
- Run verification on all hosts: `./host_change_log.sh verify`
- Review disk space for log files
- Update AI agent prompts based on findings

### When Adding New Hosts
1. Run `./host_change_log.sh setup`
2. Add to n8n host list
3. Run test check from n8n
4. Verify first report looks correct

## Files Created

```
/var/log/divtools/monitor/
├── monitoring_manifest.json          # What to monitor
├── history/
│   ├── root.bash_history.TIMESTAMP   # Timestamped backups
│   ├── root.bash_history.latest      # Symlink to latest
│   ├── divix.bash_history.TIMESTAMP
│   └── divix.bash_history.latest
├── checksums/
│   └── docker_configs.sha256         # Docker config checksums
└── logs/
    ├── apt-history.log → /var/log/apt/history.log
    ├── dpkg.log → /var/log/dpkg.log
    ├── syslog → /var/log/syslog
    └── auth.log → /var/log/auth.log

/etc/divtools/                        # Reserved for future config
```

## License

Part of divtools. See LICENSE file.

## Support

For issues or questions:
1. Check the `N8N_MONITORING_GUIDE.md` for n8n-specific help
2. Run `./host_change_log.sh verify` to diagnose issues
3. Review `/var/log/divtools/monitor/verify.log`
4. Check individual script help: `./script.sh help`

## Future Enhancements

Potential additions:
- [ ] Integration with Prometheus/Grafana
- [ ] Webhook support for real-time alerts
- [ ] Database of historical changes
- [ ] Compliance reporting (PCI, SOC2, etc.)
- [ ] Integration with configuration management (Ansible)
- [ ] Machine learning for anomaly detection
- [ ] Container-level monitoring
- [ ] Network traffic analysis
